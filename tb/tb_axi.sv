module tb_axi;
    timeunit 1ns;
    timeprecision 1ps;

    logic clk = 1'b0;
    always #5 clk = ~clk;

    axi_interface vif(clk);

    dut dut_inst (
        .clk(clk), .rst(vif.rst),
        .start_read(vif.start_read), .start_write(vif.start_write),
        .addr(vif.addr), .wdata(vif.wdata), .rdata(vif.rdata),

        .M_ARVALID(vif.M_ARVALID), .M_RREADY(vif.M_RREADY),
        .RADDR(vif.RADDR), .S_ARREADY(vif.S_ARREADY),
        .S_RVALID(vif.S_RVALID), .S_RRESP(vif.S_RRESP),
        .RDATA(vif.RDATA),

        .M_AWVALID(vif.M_AWVALID), .M_WVALID(vif.M_WVALID),
        .M_BREADY(vif.M_BREADY), .WADDR(vif.WADDR),
        .WDATA(vif.WDATA), .S_AWREADY(vif.S_AWREADY),
        .S_WREADY(vif.S_WREADY), .S_BVALID(vif.S_BVALID)
    );

    // ------------------------------------------------------------
    // Transaction
    // ------------------------------------------------------------
    class axi_transaction;
        rand bit is_write;
        rand bit [7:0] addr;
        rand bit [7:0] wdata;
        bit [7:0] rdata;

        function void display(string tag);
            $display("[%0t] %s op=%s addr=%02h wdata=%02h rdata=%02h",
                     $time, tag, is_write ? "WRITE" : "READ",
                     addr, wdata, rdata);
        endfunction
    endclass

    // ------------------------------------------------------------
    // Generator: two directed transactions + 50 randomized
    // ------------------------------------------------------------
    class axi_generator;
        mailbox #(axi_transaction) gen2drv;

        function new(mailbox #(axi_transaction) mbx);
            gen2drv = mbx;
        endfunction

        task run();
            axi_transaction tr;

            tr = new();
            tr.is_write = 1'b1;
            tr.addr = 8'h20;
            tr.wdata = 8'hA5;
            gen2drv.put(tr);

            tr = new();
            tr.is_write = 1'b0;
            tr.addr = 8'h20;
            tr.wdata = 8'h00;
            gen2drv.put(tr);

            repeat (50) begin
                tr = new();
                if (!tr.randomize())
                    $fatal(1, "Transaction randomization failed");
                gen2drv.put(tr);
            end
        endtask
    endclass

    // ------------------------------------------------------------
    // Driver: serializes transactions and uses response handshakes
    // ------------------------------------------------------------
    class axi_driver;
        virtual axi_interface vif;
        mailbox #(axi_transaction) gen2drv;

        int completed_reads = 0;
        int completed_writes = 0;

        function new(virtual axi_interface vif,
                     mailbox #(axi_transaction) mbx);
            this.vif = vif;
            gen2drv = mbx;
        endfunction

        task run();
            axi_transaction tr;
            bit done;

            forever begin
                gen2drv.get(tr);

                @(negedge vif.clk);
                vif.addr = tr.addr;
                vif.wdata = tr.wdata;
                vif.start_read = !tr.is_write;
                vif.start_write = tr.is_write;

                @(negedge vif.clk);
                vif.start_read = 1'b0;
                vif.start_write = 1'b0;

                done = 1'b0;
                while (!done) begin
                    @(posedge vif.clk);
                    if (tr.is_write)
                        done = vif.S_BVALID && vif.M_BREADY;
                    else
                        done = vif.S_RVALID && vif.M_RREADY;
                end

                // Sample read data on the handshake edge.
                if (!tr.is_write)
                    tr.rdata = vif.RDATA;

                if (tr.is_write)
                    completed_writes++;
                else
                    completed_reads++;

                tr.display("DRIVER COMPLETE");
            end
        endtask
    endclass

    // ------------------------------------------------------------
    // Monitor: records actual bus handshakes on rising edges
    // ------------------------------------------------------------
    class axi_monitor;
        virtual axi_interface vif;
        mailbox #(axi_transaction) mon2scb;

        bit [7:0] read_addr;
        bit [7:0] write_addr;
        bit [7:0] write_data;

        function new(virtual axi_interface vif,
                     mailbox #(axi_transaction) mbx);
            this.vif = vif;
            mon2scb = mbx;
        endfunction

        task run();
            axi_transaction tr;

            forever begin
                @(posedge vif.clk);

                if (vif.rst) begin
                    read_addr = 8'h00;
                    write_addr = 8'h00;
                    write_data = 8'h00;
                end else begin
                    if (vif.M_ARVALID && vif.S_ARREADY)
                        read_addr = vif.RADDR;

                    if (vif.M_AWVALID && vif.S_AWREADY)
                        write_addr = vif.WADDR;

                    if (vif.M_WVALID && vif.S_WREADY)
                        write_data = vif.WDATA;

                    if (vif.S_RVALID && vif.M_RREADY) begin
                        tr = new();
                        tr.is_write = 1'b0;
                        tr.addr = read_addr;
                        tr.rdata = vif.RDATA;
                        mon2scb.put(tr);
                        tr.display("MONITOR READ");
                    end

                    if (vif.S_BVALID && vif.M_BREADY) begin
                        tr = new();
                        tr.is_write = 1'b1;
                        tr.addr = write_addr;
                        tr.wdata = write_data;
                        mon2scb.put(tr);
                        tr.display("MONITOR WRITE");
                    end
                end
            end
        endtask
    endclass

    // ------------------------------------------------------------
    // Scoreboard: independent reference memory
    // ------------------------------------------------------------
    class axi_scoreboard;
        mailbox #(axi_transaction) mon2scb;
        bit [7:0] ref_mem [0:255];

        int reads = 0;
        int writes = 0;
        int errors = 0;

        function new(mailbox #(axi_transaction) mbx);
            mon2scb = mbx;
            foreach (ref_mem[i])
                ref_mem[i] = 8'h00;
        endfunction

        task run();
            axi_transaction tr;

            forever begin
                mon2scb.get(tr);

                if (tr.is_write) begin
                    ref_mem[tr.addr] = tr.wdata;
                    writes++;
                    $display("[%0t] SCOREBOARD WRITE addr=%02h data=%02h",
                             $time, tr.addr, tr.wdata);
                end else begin
                    reads++;
                    if (tr.rdata === ref_mem[tr.addr]) begin
                        $display("[%0t] PASS addr=%02h expected=%02h actual=%02h",
                                 $time, tr.addr, ref_mem[tr.addr], tr.rdata);
                    end else begin
                        errors++;
                        $error("[%0t] FAIL addr=%02h expected=%02h actual=%02h",
                               $time, tr.addr, ref_mem[tr.addr], tr.rdata);
                    end
                end
            end
        endtask
    endclass

    // ------------------------------------------------------------
    // Environment
    // ------------------------------------------------------------
    class axi_environment;
        mailbox #(axi_transaction) gen2drv;
        mailbox #(axi_transaction) mon2scb;

        axi_generator gen;
        axi_driver drv;
        axi_monitor mon;
        axi_scoreboard scb;

        function new(virtual axi_interface vif);
            gen2drv = new();
            mon2scb = new();

            gen = new(gen2drv);
            drv = new(vif, gen2drv);
            mon = new(vif, mon2scb);
            scb = new(mon2scb);
        endfunction

        task run();
            fork
                gen.run();
                drv.run();
                mon.run();
                scb.run();
            join_none
        endtask
    endclass

    axi_environment env;

    initial begin
        vif.rst = 1'b1;
        vif.start_read = 1'b0;
        vif.start_write = 1'b0;
        vif.addr = 8'h00;
        vif.wdata = 8'h00;

        repeat (3) @(negedge clk);
        vif.rst = 1'b0;

        env = new(vif);
        env.run();

        // 52 transactions should finish well within this window.
        repeat (1500) @(negedge clk);

        $display("");
        $display("========== VERIFICATION SUMMARY ==========");
        $display("Driver reads completed  : %0d", env.drv.completed_reads);
        $display("Driver writes completed : %0d", env.drv.completed_writes);
        $display("Scoreboard reads        : %0d", env.scb.reads);
        $display("Scoreboard writes       : %0d", env.scb.writes);
        $display("Read mismatches         : %0d", env.scb.errors);

        if ((env.drv.completed_reads + env.drv.completed_writes == 52) &&
            (env.scb.reads + env.scb.writes == 52) &&
            (env.scb.errors == 0)) begin
            $display("TEST PASSED");
        end else begin
            $display("TEST FAILED: incomplete transactions or data mismatches");
        end

        $finish;
    end

    initial begin
        #200000;
        $fatal(1, "Global simulation timeout");
    end

endmodule

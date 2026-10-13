module dut (
    input  wire       clk,
    input  wire       rst,
    input  wire       start_read,
    input  wire       start_write,
    input  wire [7:0] addr,
    input  wire [7:0] wdata,
    output wire [7:0] rdata,

    // Exposed bus signals for testbench observation
    output wire       M_ARVALID,
    output wire       M_RREADY,
    output wire [7:0] RADDR,
    output wire       S_ARREADY,
    output wire       S_RVALID,
    output wire [1:0] S_RRESP,
    output wire [7:0] RDATA,

    output wire       M_AWVALID,
    output wire       M_WVALID,
    output wire       M_BREADY,
    output wire [7:0] WADDR,
    output wire [7:0] WDATA,
    output wire       S_AWREADY,
    output wire       S_WREADY,
    output wire       S_BVALID
);

    axi_master u_master (
        .clk(clk), .rst(rst),
        .start_read(start_read), .start_write(start_write),
        .addr(addr), .wdata(wdata), .rdata(rdata),
        .S_ARREADY(S_ARREADY), .S_RVALID(S_RVALID),
        .S_RRESP(S_RRESP), .RDATA(RDATA),
        .S_AWREADY(S_AWREADY), .S_WREADY(S_WREADY),
        .S_BVALID(S_BVALID),
        .M_ARVALID(M_ARVALID), .M_RREADY(M_RREADY),
        .RADDR(RADDR),
        .M_AWVALID(M_AWVALID), .M_WVALID(M_WVALID),
        .M_BREADY(M_BREADY), .WADDR(WADDR), .WDATA(WDATA)
    );

    axi_slave u_slave (
        .clk(clk), .rst(rst),
        .M_ARVALID(M_ARVALID), .M_RREADY(M_RREADY), .RADDR(RADDR),
        .M_AWVALID(M_AWVALID), .M_WVALID(M_WVALID),
        .M_BREADY(M_BREADY), .WADDR(WADDR), .WDATA(WDATA),
        .S_ARREADY(S_ARREADY), .S_RVALID(S_RVALID),
        .S_RRESP(S_RRESP), .RDATA(RDATA),
        .S_AWREADY(S_AWREADY), .S_WREADY(S_WREADY),
        .S_BVALID(S_BVALID)
    );

endmodule

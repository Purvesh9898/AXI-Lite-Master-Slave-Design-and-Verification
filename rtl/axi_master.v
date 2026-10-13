module axi_master (
    input  wire       clk,
    input  wire       rst,
    input  wire       start_read,
    input  wire       start_write,
    input  wire [7:0] addr,
    input  wire [7:0] wdata,
    output reg  [7:0] rdata,

    input  wire       S_ARREADY,
    input  wire       S_RVALID,
    input  wire [1:0] S_RRESP,
    input  wire [7:0] RDATA,

    input  wire       S_AWREADY,
    input  wire       S_WREADY,
    input  wire       S_BVALID,

    output reg        M_ARVALID,
    output reg        M_RREADY,
    output reg  [7:0] RADDR,

    output reg        M_AWVALID,
    output reg        M_WVALID,
    output reg        M_BREADY,
    output reg  [7:0] WADDR,
    output reg  [7:0] WDATA
);

    localparam [2:0] IDLE       = 3'd0,
                     READ_ADDR  = 3'd1,
                     READ_DATA  = 3'd2,
                     WRITE_DATA = 3'd3,
                     WRITE_RESP = 3'd4;

    reg [2:0] state;
    reg [7:0] addr_reg, wdata_reg;
    reg aw_done, w_done;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state     <= IDLE;
            addr_reg  <= 8'h00;
            wdata_reg <= 8'h00;
            rdata     <= 8'h00;
            aw_done   <= 1'b0;
            w_done    <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    aw_done <= 1'b0;
                    w_done  <= 1'b0;
                    if (start_read) begin
                        addr_reg <= addr;
                        state    <= READ_ADDR;
                    end else if (start_write) begin
                        addr_reg  <= addr;
                        wdata_reg <= wdata;
                        state     <= WRITE_DATA;
                    end
                end

                READ_ADDR: begin
                    if (M_ARVALID && S_ARREADY)
                        state <= READ_DATA;
                end

                READ_DATA: begin
                    if (S_RVALID && M_RREADY) begin
                        rdata <= (S_RRESP == 2'b00) ? RDATA : 8'h00;
                        state <= IDLE;
                    end
                end

                WRITE_DATA: begin
                    if (M_AWVALID && S_AWREADY)
                        aw_done <= 1'b1;
                    if (M_WVALID && S_WREADY)
                        w_done <= 1'b1;

                    if ((aw_done || (M_AWVALID && S_AWREADY)) &&
                        (w_done  || (M_WVALID  && S_WREADY))) begin
                        state <= WRITE_RESP;
                    end
                end

                WRITE_RESP: begin
                    if (S_BVALID && M_BREADY) begin
                        state   <= IDLE;
                        aw_done <= 1'b0;
                        w_done  <= 1'b0;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

    always @* begin
        M_ARVALID = (state == READ_ADDR);
        M_RREADY  = (state == READ_DATA);
        RADDR     = (state == READ_ADDR) ? addr_reg : 8'h00;

        M_AWVALID = (state == WRITE_DATA) && !aw_done;
        M_WVALID  = (state == WRITE_DATA) && !w_done;
        M_BREADY  = (state == WRITE_RESP);

        WADDR = (state == WRITE_DATA) ? addr_reg  : 8'h00;
        WDATA = (state == WRITE_DATA) ? wdata_reg : 8'h00;
    end

endmodule

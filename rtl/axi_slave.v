module axi_slave (
    input  wire       clk,
    input  wire       rst,

    input  wire       M_ARVALID,
    input  wire       M_RREADY,
    input  wire [7:0] RADDR,

    input  wire       M_AWVALID,
    input  wire       M_WVALID,
    input  wire       M_BREADY,
    input  wire [7:0] WADDR,
    input  wire [7:0] WDATA,

    output reg        S_ARREADY,
    output reg        S_RVALID,
    output reg  [1:0] S_RRESP,
    output reg  [7:0] RDATA,

    output reg        S_AWREADY,
    output reg        S_WREADY,
    output reg        S_BVALID
);

    localparam [1:0] IDLE       = 2'd0,
                     READ_DATA  = 2'd1,
                     WRITE_RESP = 2'd2;

    reg [1:0] state;
    reg [7:0] mem [0:255];
    reg [7:0] read_addr;
    reg [7:0] saved_waddr, saved_wdata;
    reg aw_seen, w_seen;
    integer i;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state       <= IDLE;
            read_addr   <= 8'h00;
            saved_waddr <= 8'h00;
            saved_wdata <= 8'h00;
            aw_seen     <= 1'b0;
            w_seen      <= 1'b0;
            for (i = 0; i < 256; i = i + 1)
                mem[i] <= 8'h00;
        end else begin
            case (state)
                IDLE: begin
                    if (M_ARVALID && S_ARREADY) begin
                        read_addr <= RADDR;
                        state     <= READ_DATA;
                    end

                    if (M_AWVALID && S_AWREADY) begin
                        saved_waddr <= WADDR;
                        aw_seen     <= 1'b1;
                    end

                    if (M_WVALID && S_WREADY) begin
                        saved_wdata <= WDATA;
                        w_seen      <= 1'b1;
                    end

                    if ((aw_seen || (M_AWVALID && S_AWREADY)) &&
                        (w_seen  || (M_WVALID  && S_WREADY))) begin
                        mem[(aw_seen ? saved_waddr : WADDR)] <=
                            (w_seen ? saved_wdata : WDATA);
                        aw_seen <= 1'b0;
                        w_seen  <= 1'b0;
                        state   <= WRITE_RESP;
                    end
                end

                READ_DATA: begin
                    if (S_RVALID && M_RREADY)
                        state <= IDLE;
                end

                WRITE_RESP: begin
                    if (S_BVALID && M_BREADY)
                        state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    always @* begin
        S_ARREADY = (state == IDLE) && !aw_seen && !w_seen;
        S_RVALID  = (state == READ_DATA);
        S_RRESP   = 2'b00;
        RDATA     = (state == READ_DATA) ? mem[read_addr] : 8'h00;

        S_AWREADY = (state == IDLE) && !aw_seen;
        S_WREADY  = (state == IDLE) && !w_seen;
        S_BVALID  = (state == WRITE_RESP);
    end

endmodule

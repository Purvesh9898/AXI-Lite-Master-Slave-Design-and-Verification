interface axi_interface(input logic clk);
    logic rst;
    logic start_read, start_write;
    logic [7:0] addr, wdata;
    logic [7:0] rdata;

    logic M_ARVALID, M_RREADY;
    logic [7:0] RADDR;
    logic S_ARREADY, S_RVALID;
    logic [1:0] S_RRESP;
    logic [7:0] RDATA;

    logic M_AWVALID, M_WVALID, M_BREADY;
    logic [7:0] WADDR, WDATA;
    logic S_AWREADY, S_WREADY, S_BVALID;
endinterface

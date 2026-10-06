// Vivado 2022.2 module-reference adapter must be Verilog; implementation is SystemVerilog.
`timescale 1ns/1ps
module frodokem_pio_bd_bridge (
  (* X_INTERFACE_INFO="xilinx.com:signal:clock:1.0 clk CLK",
     X_INTERFACE_PARAMETER="XIL_INTERFACENAME clk, ASSOCIATED_BUSIF s_axi, ASSOCIATED_RESET aresetn" *)
  input wire clk,
  (* X_INTERFACE_INFO="xilinx.com:signal:reset:1.0 aresetn RST",
     X_INTERFACE_PARAMETER="XIL_INTERFACENAME aresetn, POLARITY ACTIVE_LOW" *)
  input wire aresetn,
  (* X_INTERFACE_INFO="xilinx.com:interface:aximm:1.0 s_axi AWADDR",
     X_INTERFACE_PARAMETER="XIL_INTERFACENAME s_axi, PROTOCOL AXI4LITE, DATA_WIDTH 32, ADDR_WIDTH 12" *)
  input wire [11:0] s_axi_awaddr,
  input wire s_axi_awvalid,
  output wire s_axi_awready,
  input wire [31:0] s_axi_wdata,
  input wire [3:0] s_axi_wstrb,
  input wire s_axi_wvalid,
  output wire s_axi_wready,
  output wire [1:0] s_axi_bresp,
  output wire s_axi_bvalid,
  input wire s_axi_bready,
  input wire [11:0] s_axi_araddr,
  input wire s_axi_arvalid,
  output wire s_axi_arready,
  output wire [31:0] s_axi_rdata,
  output wire [1:0] s_axi_rresp,
  output wire s_axi_rvalid,
  input wire s_axi_rready,
  output wire irq
);
  frodokem_pio_top core(
    .clk(clk),.aresetn(aresetn),
    .s_axi_awaddr(s_axi_awaddr),.s_axi_awvalid(s_axi_awvalid),.s_axi_awready(s_axi_awready),
    .s_axi_wdata(s_axi_wdata),.s_axi_wstrb(s_axi_wstrb),.s_axi_wvalid(s_axi_wvalid),.s_axi_wready(s_axi_wready),
    .s_axi_bresp(s_axi_bresp),.s_axi_bvalid(s_axi_bvalid),.s_axi_bready(s_axi_bready),
    .s_axi_araddr(s_axi_araddr),.s_axi_arvalid(s_axi_arvalid),.s_axi_arready(s_axi_arready),
    .s_axi_rdata(s_axi_rdata),.s_axi_rresp(s_axi_rresp),.s_axi_rvalid(s_axi_rvalid),.s_axi_rready(s_axi_rready),
    .irq(irq));
endmodule

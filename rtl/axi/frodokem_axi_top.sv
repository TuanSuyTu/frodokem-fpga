`timescale 1ns/1ps
`include "main.v"
module frodokem_axi_top (
  (* X_INTERFACE_INFO="xilinx.com:signal:clock:1.0 clk CLK",
     X_INTERFACE_PARAMETER="XIL_INTERFACENAME clk, ASSOCIATED_BUSIF s_axi:s_axis:m_axis, ASSOCIATED_RESET aresetn, FREQ_HZ 62500000" *)
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
  input wire [63:0] s_axis_tdata,
  input wire [7:0] s_axis_tkeep,
  input wire s_axis_tvalid,s_axis_tlast,
  output wire s_axis_tready,
  output wire [63:0] m_axis_tdata,
  output wire [7:0] m_axis_tkeep,
  output wire m_axis_tvalid,m_axis_tlast,
  input wire m_axis_tready,
  output wire irq
);
  wire [2:0] native_cmd;
  wire native_cmd_valid,native_cmd_ready,native_in_valid,native_in_ready;
  wire [63:0] native_in,native_out;
  wire native_out_valid,native_out_ready,native_rst;
  frodokem_axi_shell wrapper(.*);
  main core(.clk(clk),.rst(native_rst),.cmd(native_cmd),.cmd_isReady(native_cmd_valid),
    .cmd_canReceive(native_cmd_ready),.in(native_in),.in_isReady(native_in_valid),.in_canReceive(native_in_ready),
    .out(native_out),.out_isReady(native_out_valid),.out_canReceive(native_out_ready));
endmodule

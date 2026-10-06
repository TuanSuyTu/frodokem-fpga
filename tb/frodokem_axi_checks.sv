`timescale 1ns/1ps
module frodokem_axi_checks (
  input logic clk,aresetn,native_rst,
  input logic m_axis_tvalid,m_axis_tready,m_axis_tlast,
  input logic [63:0] m_axis_tdata,
  input logic [7:0] m_axis_tkeep,
  input logic s_axi_bvalid,s_axi_bready,
  input logic [1:0] s_axi_bresp,s_axi_rresp,
  input logic s_axi_rvalid,s_axi_rready,
  input logic [31:0] s_axi_rdata
);
  assert property (@(posedge clk) disable iff(!aresetn||native_rst)
    m_axis_tvalid && !m_axis_tready |=> m_axis_tvalid && $stable({m_axis_tdata,m_axis_tkeep,m_axis_tlast}))
    else $fatal(1,"AXIS_OUTPUT_STALL_STABILITY");
  assert property (@(posedge clk) disable iff(!aresetn)
    s_axi_bvalid && !s_axi_bready |=> s_axi_bvalid && $stable(s_axi_bresp))
    else $fatal(1,"AXIL_B_STALL_STABILITY");
  assert property (@(posedge clk) disable iff(!aresetn)
    s_axi_rvalid && !s_axi_rready |=> s_axi_rvalid && $stable({s_axi_rdata,s_axi_rresp}))
    else $fatal(1,"AXIL_R_STALL_STABILITY");
endmodule
bind frodokem_axi_shell frodokem_axi_checks protocol_checks(.*);

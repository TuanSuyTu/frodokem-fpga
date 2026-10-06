`timescale 1ns/1ps
// Native-core-independent wrapper. Production entropy is intentionally not exposed.
module frodokem_axi_shell #(parameter bit PIO = 0) (
  input logic clk, aresetn,
  input logic [11:0] s_axi_awaddr,
  input logic s_axi_awvalid,
  output wire s_axi_awready,
  input logic [31:0] s_axi_wdata,
  input logic [3:0] s_axi_wstrb,
  input logic s_axi_wvalid,
  output wire s_axi_wready,
  output wire [1:0] s_axi_bresp,
  output wire s_axi_bvalid,
  input logic s_axi_bready,
  input logic [11:0] s_axi_araddr,
  input logic s_axi_arvalid,
  output wire s_axi_arready,
  output wire [31:0] s_axi_rdata,
  output wire [1:0] s_axi_rresp,
  output wire s_axi_rvalid,
  input logic s_axi_rready,
  input logic [63:0] s_axis_tdata,
  input logic [7:0] s_axis_tkeep,
  input logic s_axis_tvalid, s_axis_tlast,
  output wire s_axis_tready,
  output wire [63:0] m_axis_tdata,
  output wire [7:0] m_axis_tkeep,
  output wire m_axis_tvalid, m_axis_tlast,
  input logic m_axis_tready,
  output wire irq,
  output logic [2:0] native_cmd,
  output logic native_cmd_valid,
  input logic native_cmd_ready,
  output wire [63:0] native_in,
  output wire native_in_valid,
  input logic native_in_ready,
  input logic [63:0] native_out,
  input logic native_out_valid,
  output wire native_out_ready,
  output wire native_rst
);
  localparam [3:0] IDLE=0, PARAM_CMD=1, SETUP_CMD=2, BOOT=3,
    BOOT_DONE=4, OP_CMD=5, RUN=6, DONE=7, ERROR=8;
  logic [3:0] state;
  wire [31:0] operation;
  logic [31:0] job_op, boot_count, in_count, out_count, in_seen, boot_seen, out_captured;
  logic [31:0] error_code;
  logic [63:0] cycles;
  logic done_event,error_event;
  wire prepare_pulse,start_pulse,data_reset_pulse;
  logic [2:0] reset_count;
  logic [31:0] status, expected_inputs, expected_outputs, in_bytes, out_bytes;
  wire active_boot=state==BOOT;
  wire active_run=state==RUN;
  wire reset_active=!aresetn || data_reset_pulse || reset_count!=0;
  wire in_fifo_ready,in_fifo_valid,out_fifo_ready,out_fifo_valid;
  wire [63:0] pio_tx_data;
  wire pio_tx_valid,pio_tx_last,pio_rx_ready;
  wire [63:0] ingress_data=PIO ? pio_tx_data : s_axis_tdata;
  wire ingress_valid=PIO ? pio_tx_valid : s_axis_tvalid;
  wire ingress_last=PIO ? pio_tx_last : s_axis_tlast;
  wire [7:0] ingress_keep=PIO ? 8'hff : s_axis_tkeep;
  wire egress_ready=PIO ? pio_rx_ready : m_axis_tready;
  wire [63:0] in_fifo_data;
  wire [64:0] out_fifo_data;
  wire in_fifo_pop=in_fifo_valid && native_in_ready && (active_boot||active_run) && !reset_active;
  wire [31:0] receive_index=active_boot ? boot_seen : in_seen;
  wire [31:0] receive_limit=active_boot ? 32'd12 : expected_inputs;
  wire accept_phase=(active_boot||active_run) && receive_index<receive_limit && !reset_active;
  assign s_axis_tready=accept_phase && in_fifo_ready;
  wire axis_in_fire=ingress_valid && s_axis_tready;
  wire input_bad=axis_in_fire && (ingress_keep!=8'hff || ingress_last!=(receive_index+1==receive_limit));
  wire core_out_fire=native_out_valid && native_out_ready;
  wire axis_out_fire=m_axis_tvalid && egress_ready;
  assign native_rst=reset_active;
  assign native_in=in_fifo_data[63:0];
  assign native_in_valid=in_fifo_pop;
  assign native_out_ready=active_run && !reset_active && out_captured<expected_outputs && out_fifo_ready;
  assign m_axis_tdata=out_fifo_data[63:0];
  assign m_axis_tlast=out_fifo_data[64];
  assign m_axis_tkeep=8'hff;
  assign m_axis_tvalid=out_fifo_valid && !reset_active;
  frodokem_word_fifo #(.WIDTH(64)) input_fifo(.clk(clk),.rst(reset_active),
    .in_data(ingress_data),.in_valid(axis_in_fire&&!input_bad),.in_ready(in_fifo_ready),
    .out_data(in_fifo_data),.out_valid(in_fifo_valid),.out_ready(in_fifo_pop));
  frodokem_word_fifo output_fifo(.clk(clk),.rst(reset_active),
    .in_data({out_captured+1==expected_outputs,native_out}),.in_valid(core_out_fire),.in_ready(out_fifo_ready),
    .out_data(out_fifo_data),.out_valid(out_fifo_valid),.out_ready(egress_ready&&!reset_active));
  always_comb begin
    case(operation)
      0: begin in_bytes=0; out_bytes=19888; end
      1: begin in_bytes=9616; out_bytes=9768; end
      default: begin in_bytes=29640; out_bytes=16; end
    endcase
    case(job_op)
      0: begin expected_inputs=0; expected_outputs=2486; end
      1: begin expected_inputs=1202; expected_outputs=1221; end
      default: begin expected_inputs=3705; expected_outputs=2; end
    endcase
    status=0;
    status[0]=state==IDLE && !reset_active;
    status[1]=state==PARAM_CMD || state==SETUP_CMD;
    status[2]=active_boot;
    status[3]=state==BOOT_DONE;
    status[4]=state==OP_CMD || active_run;
    status[5]=state==DONE;
    status[6]=state==ERROR;
    native_cmd=state==PARAM_CMD ? 3'd5 : state==SETUP_CMD ? 3'd3 : job_op[2:0];
    native_cmd_valid=(state==PARAM_CMD||state==SETUP_CMD||state==OP_CMD) && native_cmd_ready && !reset_active;
  end
  frodokem_axil_regs #(.PIO(PIO)) registers(.*,
    .pio_tx_ready(s_axis_tready),.pio_rx_data(m_axis_tdata),
    .pio_rx_valid(m_axis_tvalid),.pio_rx_last(m_axis_tlast),
    .data_reset_safe(!out_fifo_valid && (!PIO || !pio_tx_valid)));
  always_ff @(posedge clk) begin
    if(!aresetn) reset_count<=4;
    else if(data_reset_pulse) reset_count<=4;
    else if(reset_count!=0) reset_count<=reset_count-1'b1;
    if(reset_active) begin
      state<=IDLE; job_op<=0; boot_count<=0; in_count<=0; out_count<=0;
      boot_seen<=0; in_seen<=0; out_captured<=0; cycles<=0;
      error_code<=0; done_event<=0; error_event<=0;
    end else begin
      done_event<=0; error_event<=0;
      if(active_run) cycles<=cycles+1'b1;
      if(axis_in_fire) begin
        if(active_boot) boot_seen<=boot_seen+1'b1;
        else in_seen<=in_seen+1'b1;
      end
      if(in_fifo_pop) begin
        if(active_boot) boot_count<=boot_count+1'b1;
        else in_count<=in_count+1'b1;
      end
      if(core_out_fire) out_captured<=out_captured+1'b1;
      if(axis_out_fire) out_count<=out_count+1'b1;
      case(state)
        IDLE: if(prepare_pulse) begin state<=PARAM_CMD; job_op<=operation; end
        PARAM_CMD: if(native_cmd_valid) state<=SETUP_CMD;
        SETUP_CMD: if(native_cmd_valid) state<=BOOT;
        BOOT: if(in_fifo_pop && boot_count==11) state<=BOOT_DONE;
        BOOT_DONE: if(start_pulse) state<=OP_CMD;
        OP_CMD: if(native_cmd_valid) begin state<=RUN; cycles<=0; end
        RUN: if(axis_out_fire && m_axis_tlast) begin
          if(in_count==expected_inputs || (in_fifo_pop && in_count+1==expected_inputs)) begin
            state<=DONE; done_event<=1;
          end else begin state<=ERROR; error_code<=3; error_event<=1; end
        end
        default: begin end
      endcase
      if(input_bad) begin state<=ERROR; error_code<=ingress_keep!=8'hff ? 1 : 2; error_event<=1; done_event<=0; end
    end
  end
endmodule

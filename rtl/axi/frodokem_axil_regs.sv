`timescale 1ns/1ps
module frodokem_axil_regs #(parameter bit PIO = 0) (
  input logic clk, aresetn,
  input logic [11:0] s_axi_awaddr,
  input logic s_axi_awvalid,
  output logic s_axi_awready,
  input logic [31:0] s_axi_wdata,
  input logic [3:0] s_axi_wstrb,
  input logic s_axi_wvalid,
  output logic s_axi_wready,
  output logic [1:0] s_axi_bresp,
  output logic s_axi_bvalid,
  input logic s_axi_bready,
  input logic [11:0] s_axi_araddr,
  input logic s_axi_arvalid,
  output logic s_axi_arready,
  output logic [31:0] s_axi_rdata,
  output logic [1:0] s_axi_rresp,
  output logic s_axi_rvalid,
  input logic s_axi_rready,
  input logic [31:0] status, in_bytes, out_bytes, in_count, out_count, boot_count, error_code,
  input logic [63:0] cycles,
  input logic done_event, error_event, data_reset_safe,
  output logic [31:0] operation,
  output logic prepare_pulse, start_pulse, data_reset_pulse,
  output logic irq,
  output logic [63:0] pio_tx_data,
  output logic pio_tx_valid, pio_tx_last,
  input logic pio_tx_ready,
  input logic [63:0] pio_rx_data,
  input logic pio_rx_valid, pio_rx_last,
  output wire pio_rx_ready
);
  logic aw_full,w_full;
  logic [11:0] aw_addr;
  logic [31:0] w_data, parameter_reg, irq_enable, irq_status;
  logic [3:0] w_strb;
  logic [31:0] masked, merged, clear_bits;
  logic write_bad;
  logic tx_low_full, tx_last_next, rx_held, rx_last_held;
  logic [31:0] tx_low;
  logic [63:0] rx_word;
  // RX is popped exactly once when HIGH is requested, not when RREADY arrives.
  // The captured RDATA then remains stable throughout AXI read backpressure.
  assign pio_rx_ready=PIO && aresetn && s_axi_arvalid && s_axi_arready &&
                      s_axi_araddr==12'h10c && rx_held;
  assign s_axi_awready=aresetn && !aw_full && !s_axi_bvalid;
  assign s_axi_wready=aresetn && !w_full && !s_axi_bvalid;
  assign s_axi_arready=aresetn && !s_axi_rvalid;
  assign irq=|(irq_status[1:0]&irq_enable[1:0]);
  function automatic [31:0] byte_merge(input [31:0] old_value,new_value,input [3:0] strb);
    integer b;
    begin
      byte_merge=old_value;
      for(b=0;b<4;b=b+1) if(strb[b]) byte_merge[b*8+:8]=new_value[b*8+:8];
    end
  endfunction
  always_comb begin
    masked=byte_merge(0,w_data,w_strb);
    merged=byte_merge(operation,w_data,w_strb);
    clear_bits=0;
    write_bad=aw_addr[1:0]!=0;
    if(aw_full && w_full && !s_axi_bvalid && aw_addr[1:0]==0) begin
      case(aw_addr)
        12'h008: begin
          if(masked!=0 && masked!=1 && masked!=2 && masked!=4 && masked!=8) write_bad=1;
          else if(masked==1 && !status[0]) write_bad=1;
          else if(masked==2 && !status[3]) write_bad=1;
          else if(masked==8 && (!(status[0]||status[5]||status[6]) || !data_reset_safe)) write_bad=1;
          else if(masked==4) clear_bits=3;
        end
        12'h010: if(!status[0] || merged>2) write_bad=1;
        12'h014: if(!status[0] || byte_merge(parameter_reg,w_data,w_strb)!=640) write_bad=1;
        12'h030: if((byte_merge(irq_enable,w_data,w_strb)&32'hfffffffc)!=0) write_bad=1;
        12'h034: clear_bits=masked&3;
        12'h100: if(!PIO || w_strb!=4'hf || tx_low_full || pio_tx_valid) write_bad=1;
        12'h104: if(!PIO || w_strb!=4'hf || !tx_low_full || pio_tx_valid) write_bad=1;
        12'h114: if(!PIO || w_strb!=4'hf || masked>1 || tx_low_full || pio_tx_valid) write_bad=1;
        default: write_bad=1;
      endcase
    end
  end
  always_ff @(posedge clk) begin
    if(!aresetn) begin
      aw_full<=0; w_full<=0; s_axi_bvalid<=0; s_axi_bresp<=0;
      s_axi_rvalid<=0; s_axi_rdata<=0; s_axi_rresp<=0;
      operation<=0; parameter_reg<=640; irq_enable<=0; irq_status<=0;
      prepare_pulse<=0; start_pulse<=0; data_reset_pulse<=0;
      pio_tx_data<=0; pio_tx_valid<=0; pio_tx_last<=0;
      tx_low_full<=0; tx_low<=0; tx_last_next<=0;
      rx_held<=0; rx_word<=0; rx_last_held<=0;
    end else begin
      prepare_pulse<=0; start_pulse<=0; data_reset_pulse<=0;
      if(pio_tx_valid && pio_tx_ready) pio_tx_valid<=0;
      if(data_reset_pulse) begin
        pio_tx_valid<=0; tx_low_full<=0; tx_last_next<=0; rx_held<=0;
      end
      irq_status<=(irq_status&~clear_bits)|{30'b0,error_event,done_event};
      if(s_axi_awvalid && s_axi_awready) begin aw_full<=1; aw_addr<=s_axi_awaddr; end
      if(s_axi_wvalid && s_axi_wready) begin w_full<=1; w_data<=s_axi_wdata; w_strb<=s_axi_wstrb; end
      if(s_axi_bvalid && s_axi_bready) s_axi_bvalid<=0;
      if(aw_full && w_full && !s_axi_bvalid) begin
        aw_full<=0; w_full<=0; s_axi_bvalid<=1; s_axi_bresp<=write_bad ? 2'b10 : 2'b00;
        if(!write_bad) case(aw_addr)
          12'h008: begin
            prepare_pulse<=masked==1;
            start_pulse<=masked==2;
            data_reset_pulse<=masked==8;
          end
          12'h010: operation<=merged;
          12'h014: parameter_reg<=byte_merge(parameter_reg,w_data,w_strb);
          12'h030: irq_enable<=byte_merge(irq_enable,w_data,w_strb);
          12'h100: begin tx_low<=w_data; tx_low_full<=1; end
          12'h104: begin
            pio_tx_data<={w_data,tx_low}; pio_tx_valid<=1;
            pio_tx_last<=tx_last_next; tx_low_full<=0; tx_last_next<=0;
          end
          12'h114: tx_last_next<=w_data[0];
          default: begin end
        endcase
      end
      if(s_axi_rvalid && s_axi_rready) s_axi_rvalid<=0;
      if(s_axi_arvalid && s_axi_arready) begin
        s_axi_rvalid<=1; s_axi_rresp<=0;
        case(s_axi_araddr)
          12'h000: s_axi_rdata<=PIO ? 32'h46524f32 : 32'h46524f31;
          12'h004: s_axi_rdata<=PIO ? 32'h0000001f : 32'h0000000f;
          12'h008: s_axi_rdata<=0;
          12'h00c: s_axi_rdata<=status;
          12'h010: s_axi_rdata<=operation;
          12'h014: s_axi_rdata<=parameter_reg;
          12'h018: s_axi_rdata<=in_bytes;
          12'h01c: s_axi_rdata<=out_bytes;
          12'h020: s_axi_rdata<=in_count;
          12'h024: s_axi_rdata<=out_count;
          12'h028: s_axi_rdata<=cycles[31:0];
          12'h02c: s_axi_rdata<=cycles[63:32];
          12'h030: s_axi_rdata<=irq_enable;
          12'h034: s_axi_rdata<=irq_status;
          12'h038: s_axi_rdata<=error_code;
          12'h03c: s_axi_rdata<=boot_count;
          12'h040: s_axi_rdata<=96;
          12'h108: begin
            if(!PIO || rx_held || !pio_rx_valid) begin s_axi_rdata<=0; s_axi_rresp<=2'b10; end
            else begin
              s_axi_rdata<=pio_rx_data[31:0]; rx_word<=pio_rx_data;
              rx_last_held<=pio_rx_last; rx_held<=1;
            end
          end
          12'h10c: begin
            if(!PIO || !rx_held) begin s_axi_rdata<=0; s_axi_rresp<=2'b10; end
            else begin s_axi_rdata<=rx_word[63:32]; rx_held<=0; end
          end
          12'h110: begin
            if(!PIO) begin s_axi_rdata<=0; s_axi_rresp<=2'b10; end
            else s_axi_rdata<={27'b0,(rx_held ? rx_last_held : (pio_rx_valid && pio_rx_last)),rx_held,
                              (pio_rx_valid && !rx_held),(tx_low_full && !pio_tx_valid),
                              (!tx_low_full && !pio_tx_valid)};
          end
          default: begin s_axi_rdata<=0; s_axi_rresp<=2'b10; end
        endcase
      end
    end
  end
endmodule

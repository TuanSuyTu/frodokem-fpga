`timescale 1ns/1ps
// Two-entry elastic FIFO; valid/data remain stable under downstream stalls.
module frodokem_word_fifo #(parameter integer WIDTH=65) (
  input logic clk, rst,
  input logic [WIDTH-1:0] in_data,
  input logic in_valid,
  output logic in_ready,
  output logic [WIDTH-1:0] out_data,
  output logic out_valid,
  input logic out_ready
);
  logic [WIDTH-1:0] mem[0:1];
  logic wr_ptr, rd_ptr;
  logic [1:0] count;
  wire pop=out_valid && out_ready;
  wire push=in_valid && in_ready;
  assign out_valid=count!=0;
  assign out_data=mem[rd_ptr];
  assign in_ready=count<2 || pop;
  always_ff @(posedge clk) begin
    if(rst) begin count<=0; wr_ptr<=0; rd_ptr<=0; end
    else begin
      if(push) begin mem[wr_ptr]<=in_data; wr_ptr<=~wr_ptr; end
      if(pop) rd_ptr<=~rd_ptr;
      case({push,pop})
        2'b10: count<=count+1'b1;
        2'b01: count<=count-1'b1;
        default: count<=count;
      endcase
    end
  end
endmodule

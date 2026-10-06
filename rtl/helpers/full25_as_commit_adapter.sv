`timescale 1ns/1ps
// Convert two row-pair results into LightSec's 8x4 logical B word.
// Read existing E through the parallel B view, then commit (AS+E) mod 2^16.
// Memory return has exactly two registered stages. No secret-value control.
module full25_as_commit_adapter(
  input logic clk,rst,
  input logic pair_valid,
  output wire pair_ready,
  input logic [8:0] pair_index,
  input logic [255:0] pair_data,
  output wire read_valid,
  output wire [13:0] read_index,
  input logic [511:0] read_data_d2,
  output wire write_valid,
  output wire [13:0] write_index,
  output wire [511:0] write_data,
  output wire busy
);
  typedef enum logic [2:0] {IDLE,ISSUE,WAIT_RETURN,CAPTURE,WRITE} state_t;
  state_t state;
  logic [255:0] first_pair;
  logic [511:0] product_word,result_word;
  logic [7:0] address;
  assign pair_ready=state==IDLE;
  assign busy=state!=IDLE;
  assign read_valid=state==ISSUE;
  assign read_index={6'd0,address};
  assign write_valid=state==WRITE;
  assign write_index={6'd0,address};
  assign write_data=result_word;
  always_ff @(posedge clk) begin
    if(rst) begin
      state<=IDLE; first_pair<=0; product_word<=0; result_word<=0; address<=0;
    end else begin
      case(state)
        IDLE: if(pair_valid) begin
          if(!pair_index[0]) first_pair<=pair_data;
          else begin
            for(integer k=0;k<8;k=k+1) begin
              product_word[64*k+:16]<=first_pair[16*k+:16];
              product_word[64*k+16+:16]<=first_pair[128+16*k+:16];
              product_word[64*k+32+:16]<=pair_data[16*k+:16];
              product_word[64*k+48+:16]<=pair_data[128+16*k+:16];
            end
            address<=pair_index[8:1];
            state<=ISSUE;
          end
        end
        ISSUE: state<=WAIT_RETURN;
        WAIT_RETURN: state<=CAPTURE;
        CAPTURE: begin
          for(integer n=0;n<32;n=n+1)
            result_word[16*n+:16]<=product_word[16*n+:16]+read_data_d2[16*n+:16];
          state<=WRITE;
        end
        WRITE: state<=IDLE;
        default: state<=IDLE;
      endcase
    end
  end
endmodule

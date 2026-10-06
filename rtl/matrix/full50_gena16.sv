`timescale 1ns/1ps
// Complete 16A frontend. done waits for final aligned output consumption.
module full50_gena16 (
    input logic clk,rst,start,
    input logic [9:0] row_base,
    input logic [127:0] seedA,
    input logic out_ready,
    output logic busy,done,out_valid,
    output logic [255:0] a_data,
    output logic [15:0] a_mask,
    output logic [9:0] out_row,col_base,
    output logic [5:0] queued_packets
);
    logic producer_finished;
    logic [9:0] base_q;
    wire start_accept=start && !busy;
    wire raw_done,raw_valid,raw_ready;
    wire [255:0] raw_data;
    wire [15:0] raw_mask;
    wire [9:0] raw_row,raw_col;
    full50_gena_ring12 producer (
        .clk(clk),.rst(rst),.start(start_accept),.row_base(row_base),.seedA(seedA),
        .out_ready(raw_ready),.busy(),.done(raw_done),.out_valid(raw_valid),
        .a_data(raw_data),.a_mask(raw_mask),.out_row(raw_row),.col_base(raw_col),
        .out_block(),.queued_packets(queued_packets)
    );
    full50_carry16 aligner (
        .clk(clk),.rst(rst),.clear(start_accept),.row_base(base_q),
        .in_valid(raw_valid),.in_ready(raw_ready),.in_data(raw_data),
        .in_mask(raw_mask),.in_row(raw_row),.in_col(raw_col),
        .out_valid(out_valid),.out_ready(out_ready),.out_data(a_data),
        .out_row(out_row),.out_col(col_base)
    );
    assign a_mask=16'hffff;
    always_ff @(posedge clk) begin
        if(rst) begin busy<=0;done<=0;producer_finished<=0;base_q<=0;end
        else begin
            done<=0;
            if(start_accept) begin busy<=1;producer_finished<=0;base_q<=row_base;end
            if(raw_done) producer_finished<=1;
            if(busy && producer_finished && !out_valid) begin busy<=0;done<=1;end
        end
    end
endmodule

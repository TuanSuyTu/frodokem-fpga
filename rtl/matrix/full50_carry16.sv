`timescale 1ns/1ps
// Per-row public 0/4/8/12 coefficient carry. Never combine different rows.
// One elastic output register; all emitted beats have sixteen coefficients.
module full50_carry16 (
    input logic clk,rst,clear,
    input logic [9:0] row_base,
    input logic in_valid,
    output logic in_ready,
    input logic [255:0] in_data,
    input logic [15:0] in_mask,
    input logic [9:0] in_row,in_col,
    output logic out_valid,
    input logic out_ready,
    output logic [255:0] out_data,
    output logic [9:0] out_row,out_col
);
    logic [191:0] carry [0:11];
    logic [3:0] count [0:11];
    wire [9:0] index_row=in_row-row_base;
    wire [3:0] c=count[index_row];
    wire [4:0] incoming=in_mask==16'hffff ? 5'd16 :5'd4;
    wire [5:0] total={2'b0,c}+{1'b0,incoming};
    wire [255:0] useful_input=in_mask==16'hffff ? in_data :{192'd0,in_data[63:0]};
    wire [447:0] prefix=c==0 ? 448'd0 : {256'd0,carry[index_row]};
    wire [447:0] merged=prefix | ({192'd0,useful_input} << (c*16));
    assign in_ready=!out_valid || out_ready;
    always_ff @(posedge clk) begin
        if(rst || clear) begin
            out_valid<=0;out_data<=0;out_row<=0;out_col<=0;
            for(int r=0;r<12;r++) count[r]<=0;
        end else begin
            if(out_valid && out_ready) out_valid<=0;
            if(in_valid && in_ready) begin
                if(total>=16) begin
                    out_valid<=1;out_data<=merged[255:0];out_row<=in_row;
                    out_col<=in_col-10'(c);
                    carry[index_row]<=merged[447:256];count[index_row]<=4'(total-16);
                end else begin
                    carry[index_row]<=merged[191:0];count[index_row]<=4'(total);
                end
            end
        end
    end
`ifndef SYNTHESIS
    always_ff @(posedge clk) if(!rst && !clear && in_valid && in_ready) begin
        if(index_row>=12 || (in_mask!=16'hffff && in_mask!=16'h000f))
            $fatal(1,"Invalid public carry input row/mask");
    end
`endif
endmodule

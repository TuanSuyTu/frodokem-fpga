`timescale 1ns/1ps
module full50_gena_matrix16 (
    input logic clk,rst,start,mode_sa,load_as,
    input logic [9:0] row_base,
    input logic [127:0] seedA,
    input logic [1535:0] as_init,
    input logic as_secret_we,
    input logic [5:0] as_secret_addr,
    input logic [639:0] as_secret_data,
    input logic sa_secret_we,
    input logic [9:0] sa_secret_addr,
    input logic [39:0] sa_secret_data,
    input logic sa_acc_we,sa_rd_en,
    input logic [5:0] sa_acc_addr,sa_rd_addr,
    input logic [2047:0] sa_acc_data,
    output logic [2047:0] sa_rd_data,
    output logic [1535:0] as_out,
    output logic busy,done
);
    logic mode_q,finished;
    logic [9:0] base_q;
    wire start_accept=start && !busy;
    wire producer_done,valid,ready,drained;
    wire [255:0] a_data;
    wire [9:0] in_row,col_base;
    full50_gena16 producer (
        .clk(clk),.rst(rst),.start(start_accept),.row_base(row_base),.seedA(seedA),
        .out_ready(ready),.busy(),.done(producer_done),.out_valid(valid),
        .a_data(a_data),.a_mask(),.out_row(in_row),.col_base(col_base),.queued_packets()
    );
    full50_matrix16 matrix (
        .clk(clk),.rst(rst),.mode_sa(mode_q),.load_as(load_as),.as_init(as_init),.row_base(base_q),
        .as_secret_we(as_secret_we),.as_secret_addr(as_secret_addr),.as_secret_data(as_secret_data),
        .sa_secret_we(sa_secret_we),.sa_secret_addr(sa_secret_addr),.sa_secret_data(sa_secret_data),
        .sa_acc_we(sa_acc_we),.sa_rd_en(sa_rd_en),.sa_acc_addr(sa_acc_addr),.sa_rd_addr(sa_rd_addr),
        .sa_acc_data(sa_acc_data),.sa_rd_data(sa_rd_data),.in_valid(valid),.in_ready(ready),
        .a_data(a_data),.in_row(in_row),.col_base(col_base),.as_out(as_out),.drained(drained)
    );
    always_ff @(posedge clk) begin
        if(rst) begin busy<=0;done<=0;mode_q<=0;finished<=0;base_q<=0;end
        else begin
            done<=0;
            if(start_accept) begin busy<=1;mode_q<=mode_sa;finished<=0;base_q<=row_base;end
            if(producer_done) finished<=1;
            if(busy && finished && drained) begin busy<=0;done<=1;end
        end
    end
endmodule

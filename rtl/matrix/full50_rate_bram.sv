`timescale 1ns/1ps
// Twenty-one independent 64-bit SDP banks, 24 packet slots. No payload reset.
// Packet-slot ownership is external: do not overwrite a live slot. Synchronous
// read-first semantics; returned word group is valid one clock after rd_en.
// Read four selected banks only. Bank indices >=21 return zero, not aliases.
module full50_rate_bram (
    input logic clk, rst,
    input logic wr_en,
    input logic [4:0] wr_slot,
    input logic [2:0] wr_block,
    input logic [1343:0] wr_rate,
    input logic rd_en,
    input logic [4:0] rd_slot,
    input logic [4:0] rd_word_base,
    output logic rd_valid,
    output logic [255:0] rd_words
);
    wire [63:0] bank_q [0:20];
    logic [4:0] base_q;
    for (genvar b=0;b<21;b++) begin : banks
        (* ram_style="block" *) logic [63:0] memory [0:23];
        logic [63:0] data_q;
        wire selected = rd_word_base<=b && (6'(b)-{1'b0,rd_word_base})<4;
        always_ff @(posedge clk) begin
            // Last block has only 52 useful coefficients = thirteen words.
            if(wr_en && (wr_block!=7 || b<13)) memory[wr_slot]<=wr_rate[b*64 +:64];
            if(rd_en && selected) data_q<=memory[rd_slot];
        end
        assign bank_q[b]=data_q;
    end
    always_ff @(posedge clk) begin
        if(rst) rd_valid<=0;
        else begin
            rd_valid<=rd_en;
            if(rd_en) base_q<=rd_word_base;
        end
    end
    always_comb begin
        rd_words='0;
        for(int w=0;w<4;w++) begin
            if(int'(base_q)+w<21) rd_words[w*64 +:64]=bank_q[int'(base_q)+w];
        end
    end
endmodule

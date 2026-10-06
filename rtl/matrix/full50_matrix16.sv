`timescale 1ns/1ps
// ONE bank of 128 registered DSP products shared between AS and S'A.
// Input columns are aligned to sixteen. Secret bit0=sign, bits4:1=magnitude.
// Preload/initialization/readback belong to drained public phases only.
module full50_matrix16 (
    input logic clk,rst,mode_sa,load_as,
    input logic [1535:0] as_init,
    input logic [9:0] row_base,
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
    input logic in_valid,
    output logic in_ready,
    input logic [255:0] a_data,
    input logic [9:0] in_row,col_base,
    output logic [1535:0] as_out,
    output logic drained
);
    logic v1,v2,sa1,sa2;
    logic [3:0] ctx1,ctx2;
    logic [5:0] addr1,addr2;
    logic [255:0] a1;
    logic [39:0] as_read [0:15];
    (* ram_style="block" *) logic [39:0] sa_secret [0:639];
    logic [39:0] sa_read;
    wire hazard=(v1 && sa1 && addr1==col_base[9:4]) || (v2 && sa2 && addr2==col_base[9:4]);
    assign in_ready=!rst && !load_as && !as_secret_we && !sa_secret_we && !sa_acc_we && !sa_rd_en && !(mode_sa && hazard);
    wire accept=in_valid && in_ready;
    assign drained=!v1 && !v2;
    wire [15:0] product [0:15][0:7];
    (* use_dsp="no" *) logic [15:0] as_acc [0:11][0:7];
    for(genvar b=0;b<16;b++) begin : as_secret_banks
        (* ram_style="block" *) logic [39:0] memory [0:39];
        always_ff @(posedge clk) begin
            if(as_secret_we) memory[as_secret_addr]<=as_secret_data[b*40 +:40];
            if(rst) as_read[b]<=0;
            else if(accept && !mode_sa) as_read[b]<=memory[col_base[9:4]];
        end
    end
    always_ff @(posedge clk) begin
        if(sa_secret_we) sa_secret[sa_secret_addr]<=sa_secret_data;
        if(rst) sa_read<=0;
        else if(accept && mode_sa) sa_read<=sa_secret[in_row];
        if(rst || load_as) begin
            v1<=0;v2<=0;sa1<=0;sa2<=0;ctx1<=0;ctx2<=0;addr1<=0;addr2<=0;a1<=0;
        end else begin
            v1<=accept;v2<=v1;
            if(accept) begin
                sa1<=mode_sa;ctx1<=4'(in_row-row_base);addr1<=col_base[9:4];a1<=a_data;
            end
            if(v1) begin sa2<=sa1;ctx2<=ctx1;addr2<=addr1;end
        end
    end
    for(genvar b=0;b<16;b++) begin : shared_lanes
        for(genvar k=0;k<8;k++) begin : products
            wire [4:0] compact=sa1 ? sa_read[k*5 +:5] : as_read[b][k*5 +:5];
            wire signed [4:0] s=compact[0] ? -$signed({1'b0,compact[4:1]}) : $signed({1'b0,compact[4:1]});
            wire signed [16:0] a=$signed({1'b0,a1[b*16 +:16]});
            wire signed [21:0] result;
            // Preserve the single product boundary shared by both consumers.
            // Without it synthesis extracts additional MACs from the fanout.
            (* dont_touch="yes" *) full50_shared_product multiply (
                .clk(clk),.rst(rst),.enable(v1),.a(a),.s(s),.result(result)
            );
            assign product[b][k]=result[15:0];
        end
        logic [127:0] read1,base2;
        (* use_dsp="no" *) wire [127:0] updated;
        for(genvar k=0;k<8;k++) assign updated[k*16 +:16]=base2[k*16 +:16]+product[b][k];
        // Explicit 64-bit halves make the intended 2xRAMB36 SDP geometry clear.
        for(genvar h=0;h<2;h++) begin : acc_halves
            (* ram_style="block" *) logic [63:0] memory [0:39];
            logic [63:0] read_q;
            wire write_en=sa_acc_we || (v2 && sa2);
            wire [5:0] write_addr=sa_acc_we ? sa_acc_addr : addr2;
            wire [63:0] write_data=sa_acc_we ? sa_acc_data[b*128+h*64 +:64] : updated[h*64 +:64];
            wire read_en=!rst && (sa_rd_en || (accept && mode_sa));
            wire [5:0] read_addr=sa_rd_en ? sa_rd_addr : col_base[9:4];
            logic read_seen;
            always_ff @(posedge clk) begin
                if(write_en) memory[write_addr]<=write_data;
                if(read_en) read_q<=memory[read_addr];
            end
            // Reset validity, not the RAM output register; retain SDP inference.
            always_ff @(posedge clk)
                if(rst) read_seen<=0;
                else if(read_en) read_seen<=1;
            assign read1[h*64 +:64]=read_seen ? read_q : 64'b0;
        end
        always_ff @(posedge clk)
            if(rst) base2<=0;
            else if(v1 && sa1) base2<=read1;
        assign sa_rd_data[b*128 +:128]=read1;
    end
    for(genvar k=0;k<8;k++) begin : as_reducers
        (* use_dsp="no" *) wire [15:0] level1 [0:7];
        (* use_dsp="no" *) wire [15:0] level2 [0:3];
        (* use_dsp="no" *) wire [15:0] level3 [0:1];
        for(genvar j=0;j<8;j++) assign level1[j]=product[2*j][k]+product[2*j+1][k];
        for(genvar j=0;j<4;j++) assign level2[j]=level1[2*j]+level1[2*j+1];
        for(genvar j=0;j<2;j++) assign level3[j]=level2[2*j]+level2[2*j+1];
        (* use_dsp="no" *) wire [15:0] sum=level3[0]+level3[1];
        always_ff @(posedge clk) begin
            if(load_as) for(int c=0;c<12;c++) as_acc[c][k]<=as_init[(c*8+k)*16 +:16];
            else if(v2 && !sa2) as_acc[ctx2][k]<=as_acc[ctx2][k]+sum;
        end
        for(genvar c=0;c<12;c++) assign as_out[(c*8+k)*16 +:16]=as_acc[c][k];
    end
`ifndef SYNTHESIS
    always_ff @(posedge clk) if(!rst) begin
        if(accept && (col_base[3:0]!=0 || col_base>=640 || in_row>=640 || (!mode_sa && in_row-row_base>=12)))
            $fatal(1,"Invalid matrix16 public address");
        if((load_as || as_secret_we || sa_secret_we || sa_acc_we || sa_rd_en) && !drained)
            $fatal(1,"Matrix16 external access before drain");
    end
`endif
endmodule

module full50_shared_product (
    input logic clk,rst,enable,
    input logic signed [16:0] a,
    input logic signed [4:0] s,
    output logic signed [21:0] result
);
    (* use_dsp="yes" *) logic signed [21:0] product_q;
    always_ff @(posedge clk)
        if(rst) product_q<=0;
        else if(enable) product_q<=a*s;
    assign result=product_q;
endmodule

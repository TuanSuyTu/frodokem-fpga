`timescale 1ns/1ps
// Source-selected replacement for the proven full25 logical-memory interface.
// 12-row batches, 16A shared compute; all memory control is public/fixed.
module full25_keygen_memory_path (
    input logic clk,rst,start,mode_sa,
    input logic [127:0] seed,
    output logic done,
    output wire owner,
    output wire [13:0] r_index,w_index,
    output wire r_secret,r_secret_col,r_b,w_b,
    output wire [511:0] w_data,
    input logic [159:0] s_data,
    input logic [39:0] s_col_data,
    input logic [511:0] b_data
);
    typedef enum logic [3:0] {IDLE,PRE_ISSUE,PRE_WAIT1,PRE_CAPTURE,
        SA_CLEAR,BATCH_INIT,BATCH_START,COMPUTE,AS_PAIRS,AS_WAIT,
        SA_ISSUE,SA_WAIT1,SA_CAPTURE,SA_WRITE} phase_t;
    phase_t phase;
    logic mode;
    logic [127:0] seed_reg;
    logic [9:0] pre_idx,base;
    logic [5:0] clear_addr;
    logic [2:0] pair_slot;
    logic [7:0] commit_word;
    logic [479:0] secret_prefix;
    logic [511:0] sa_write_data;
    wire [639:0] as_preload;
    for(genvar lane=0;lane<16;lane++) begin : secret_pack
        for(genvar k=0;k<8;k++) begin : column
            if(lane<12) assign as_preload[lane*40+k*5 +:5]=secret_prefix[(lane/4)*160+(k*4+lane%4)*5 +:5];
            else assign as_preload[lane*40+k*5 +:5]=s_data[(k*4+lane-12)*5 +:5];
        end
    end
    wire compute_done,compute_busy;
    wire [1535:0] as_results;
    wire [2047:0] sa_read;
    full50_gena_matrix16 compute (
        .clk(clk),.rst(rst),.start(phase==BATCH_START),.mode_sa(mode),
        .row_base(base),.seedA(seed_reg),.busy(compute_busy),.done(compute_done),
        .load_as(phase==BATCH_INIT && !mode),.as_init(1536'd0),
        .as_secret_we(phase==PRE_CAPTURE && !mode && pre_idx[1:0]==3),
        .as_secret_addr(pre_idx[7:2]),.as_secret_data(as_preload),
        .sa_secret_we(phase==PRE_CAPTURE && mode),.sa_secret_addr(pre_idx),.sa_secret_data(s_col_data),
        .sa_acc_we(phase==SA_CLEAR),.sa_acc_addr(clear_addr),.sa_acc_data(2048'd0),
        .sa_rd_en(phase==SA_ISSUE),.sa_rd_addr(commit_word[7:2]),
        .sa_rd_data(sa_read),.as_out(as_results)
    );
    wire pair_ready,as_read,as_write,as_busy;
    wire [13:0] as_read_idx,as_write_idx;
    wire [511:0] as_write_data;
    full25_as_commit_adapter as_commit (
        .clk(clk),.rst(rst),.pair_valid(phase==AS_PAIRS),.pair_ready(pair_ready),
        .pair_index(9'(base/2)+9'(pair_slot)),.pair_data(as_results[pair_slot*256 +:256]),
        .read_valid(as_read),.read_index(as_read_idx),.read_data_d2(b_data),
        .write_valid(as_write),.write_index(as_write_idx),.write_data(as_write_data),.busy(as_busy)
    );
    assign owner=phase!=IDLE;
    assign r_secret=phase==PRE_ISSUE && !mode;
    assign r_secret_col=phase==PRE_ISSUE && mode;
    assign r_b=mode ? phase==SA_ISSUE : as_read;
    assign r_index=phase==PRE_ISSUE ? {4'd0,pre_idx} : (mode ? {6'd0,commit_word} : as_read_idx);
    assign w_b=mode ? phase==SA_WRITE : as_write;
    assign w_index=mode ? {6'd0,commit_word} : as_write_idx;
    assign w_data=mode ? sa_write_data : as_write_data;
    always_ff @(posedge clk) begin
        if(rst) begin
            phase<=IDLE;done<=0;mode<=0;seed_reg<=0;pre_idx<=0;base<=0;
            clear_addr<=0;pair_slot<=0;commit_word<=0;secret_prefix<=0;sa_write_data<=0;
        end else begin
            done<=0;
            case(phase)
                IDLE: if(start) begin mode<=mode_sa;seed_reg<=seed;pre_idx<=0;base<=0;phase<=PRE_ISSUE;end
                PRE_ISSUE: phase<=PRE_WAIT1;
                PRE_WAIT1: phase<=PRE_CAPTURE;
                PRE_CAPTURE: begin
                    if(!mode && pre_idx[1:0]!=3) secret_prefix[pre_idx[1:0]*160 +:160]<=s_data;
                    if(pre_idx==(mode ?639:159)) begin clear_addr<=0;phase<=mode ?SA_CLEAR:BATCH_INIT;end
                    else begin pre_idx<=pre_idx+1;phase<=PRE_ISSUE;end
                end
                SA_CLEAR: if(clear_addr==39) phase<=BATCH_INIT;
                          else clear_addr<=clear_addr+1;
                BATCH_INIT: phase<=BATCH_START;
                BATCH_START: phase<=COMPUTE;
                COMPUTE: if(compute_done) begin pair_slot<=0;phase<=mode ?AS_WAIT:AS_PAIRS;end
                AS_PAIRS: if(pair_ready) begin
                    if(pair_slot==(base==636 ?1:5)) phase<=AS_WAIT;
                    else pair_slot<=pair_slot+1;
                end
                AS_WAIT: if(!compute_busy && !as_busy) begin
                    if(base==636) begin
                        if(mode) begin commit_word<=0;phase<=SA_ISSUE;end
                        else begin done<=1;phase<=IDLE;end
                    end else begin base<=base+12;phase<=BATCH_INIT;end
                end
                SA_ISSUE: phase<=SA_WAIT1;
                SA_WAIT1: phase<=SA_CAPTURE;
                SA_CAPTURE: begin
                    // Four 512-bit logical words per 16-column accumulator tile.
                    for(int k=0;k<8;k++) for(int lane=0;lane<4;lane++)
                        sa_write_data[(k*4+lane)*16 +:16]<=
                            sa_read[((int'(commit_word[1:0])*4+lane)*8+k)*16 +:16]+
                            b_data[(k*4+lane)*16 +:16];
                    phase<=SA_WRITE;
                end
                SA_WRITE: if(commit_word==159) begin done<=1;phase<=IDLE;end
                          else begin commit_word<=commit_word+1;phase<=SA_ISSUE;end
                default: phase<=IDLE;
            endcase
        end
    end
endmodule

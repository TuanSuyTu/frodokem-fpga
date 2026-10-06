`timescale 1ns/1ps
// Real SHAKE row initialization, continuous ring, 24-slot rate FIFO and
// synchronous selective BRAM reader. Emits raw 16A chunks plus public masks.
// Carry alignment across 84-coefficient packets is the NEXT consumer stage.
module full50_gena_ring12 (
    input logic clk,rst,start,
    input logic [9:0] row_base,
    input logic [127:0] seedA,
    input logic out_ready,
    output logic busy,done,out_valid,
    output logic [255:0] a_data,
    output logic [15:0] a_mask,
    output logic [9:0] out_row,col_base,
    output logic [2:0] out_block,
    output logic [5:0] queued_packets
);
    typedef enum logic [1:0] {IDLE,LAUNCH,RUN,DRAIN} phase_t;
    phase_t phase;
    logic [9:0] base_q;
    logic [127:0] seed_q;
    wire [1599:0] init_state,ring_state;
    wire ring_valid,ring_done;
    wire [3:0] input_context,ring_context;
    wire [2:0] ring_block;
    wire [15:0] init_row={6'b0,base_q}+16'(input_context);
    gena_shake128_row_init init_row_state(.row_index(init_row),.seedA(seed_q),.init_state(init_state));
    wire real_row=({1'b0,base_q}+11'(ring_context))<640;
    wire ring_step=!ring_valid || !real_row || queued_packets<24;
    full50_ring4_permute ring (
        .clk(clk),.rst(rst),.start(phase==LAUNCH),.step(ring_step),.in_state(init_state),
        .input_ready(),.input_context(input_context),.out_state(ring_state),
        .out_valid(ring_valid),.out_context(ring_context),.out_block(ring_block),
        .busy(),.done(ring_done)
    );
    logic [4:0] write_slot,read_slot,word_base;
    logic [3:0] context_slots [0:23];
    logic [2:0] block_slots [0:23];
    logic [5:0] unissued_packets;
    logic output_last_chunk;
    wire push=ring_valid && ring_step && real_row;
    // BRAM data_q is already a synchronous output register. Use it directly
    // as the elastic output stage instead of request/return/copy bubbles.
    wire request_read=unissued_packets!=0 && (!out_valid || out_ready);
    wire [255:0] mem_words;
    full50_rate_bram rates (
        .clk(clk),.rst(rst),.wr_en(push),.wr_slot(write_slot),.wr_block(ring_block),
        .wr_rate(ring_state[1343:0]),.rd_en(request_read),.rd_slot(read_slot),
        .rd_word_base(word_base),.rd_valid(),.rd_words(mem_words)
    );
    wire accepted=out_valid && out_ready;
    wire issue_last=word_base==(block_slots[read_slot]==7 ? 12 : 20);
    wire issued_packet=request_read && issue_last;
    wire pop=accepted && output_last_chunk;
    assign busy=phase!=IDLE;
    assign a_data=mem_words;
    always_ff @(posedge clk) begin
        if(rst) begin
            phase<=IDLE;done<=0;out_valid<=0;unissued_packets<=0;output_last_chunk<=0;
            write_slot<=0;read_slot<=0;word_base<=0;queued_packets<=0;
            base_q<=0;seed_q<=0;a_mask<=0;out_row<=0;col_base<=0;out_block<=0;
        end else begin
            done<=0;
            if(start && phase==IDLE) begin
                base_q<=row_base;seed_q<=seedA;phase<=LAUNCH;
            end else if(phase==LAUNCH) phase<=RUN;
            if(ring_done && phase==RUN) phase<=DRAIN;
            if(phase==DRAIN && queued_packets==0 && !out_valid) begin phase<=IDLE;done<=1;end
            case({push,pop})
                2'b10: queued_packets<=queued_packets+1;
                2'b01: queued_packets<=queued_packets-1;
                default: ;
            endcase
            case({push,issued_packet})
                2'b10: unissued_packets<=unissued_packets+1;
                2'b01: unissued_packets<=unissued_packets-1;
                default: ;
            endcase
            if(push) begin
                context_slots[write_slot]<=ring_context;block_slots[write_slot]<=ring_block;
                write_slot<=write_slot==23 ? 5'd0 : write_slot+1;
            end
            if(request_read) begin
                out_valid<=1;output_last_chunk<=issue_last;
                out_row<=base_q+10'(context_slots[read_slot]);out_block<=block_slots[read_slot];
                col_base<=10'(block_slots[read_slot])*84+10'(word_base)*4;
                a_mask<=word_base==(block_slots[read_slot]==7 ? 12 : 20) ? 16'h000f :16'hffff;
                if(issue_last) begin word_base<=0;read_slot<=read_slot==23 ? 5'd0 : read_slot+1;end
                else word_base<=word_base+4;
            end else if(accepted) out_valid<=0;
        end
    end
endmodule

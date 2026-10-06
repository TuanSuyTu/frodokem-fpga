`timescale 1ns/1ps
// Twelve contexts live ONLY in four cascaded P3 round pipelines.
// Supply twelve input states on the first twelve accepted busy clocks.
// Eight consecutive squeezes per context without external state reloading.
// Outputs stream after each six laps. Public step freezes data and all tags.
// No input/output shadow state bank. Caller owns squeeze rate storage.
module full50_ring4_permute (
    input logic clk, rst, start, step,
    input logic [1599:0] in_state,
    output logic input_ready,
    output logic [3:0] input_context,
    output logic [1599:0] out_state,
    output logic out_valid,
    output logic [3:0] out_context,
    output logic [2:0] out_block,
    output logic busy, done
);
    logic [3:0] injected, retired;
    logic [3:0] ctx [0:11];
    logic [2:0] lap [0:11];
    logic [2:0] block_tag [0:11];
    wire [1599:0] state_wire [0:4];
    wire valid_wire [0:4];
    wire advance = busy && step;
    wire initial_input = injected < 12;
    wire final_block = lap[11]==5 && block_tag[11]==7;
    wire feedback = valid_wire[4] && !final_block;
    wire [2:0] launch_lap = initial_input || lap[11]==5 ? 3'd0 : lap[11]+3'd1;
    wire [2:0] launch_block = initial_input ? 3'd0 :
        (lap[11]==5 ? block_tag[11]+3'd1 : block_tag[11]);
    wire [3:0] launch_ctx = initial_input ? injected : ctx[11];
    assign input_ready = busy && initial_input;
    assign input_context = injected;
    assign state_wire[0] = initial_input ? in_state : state_wire[4];
    assign valid_wire[0] = busy && (initial_input || feedback);
    assign out_state = state_wire[4];
    assign out_context = ctx[11];
    assign out_block = block_tag[11];
    assign out_valid = busy && valid_wire[4] && lap[11] == 5;
    for (genvar g=0; g<4; g++) begin : rounds
        wire [2:0] stage_lap;
        wire [4:0] round_idx;
        wire [6:0] rc;
        if (g==0) assign stage_lap = launch_lap;
        else assign stage_lap = lap[3*g-1];
        // Invalid bubbles must never address unsupported constants.
        assign round_idx = valid_wire[g] ? {stage_lap,2'b00} + 5'(g) : 5'd0;
        keccak_rc_indexed constants (.round_idx(round_idx), .rc(rc));
        full50_keccak_round #(.PIPE_STAGES(3)) round_pipe (
            .clk(clk), .rst(rst || !busy), .step(advance),
            .in_valid(valid_wire[g]), .in_state(state_wire[g]), .in_rc(rc),
            .out_valid(valid_wire[g+1]), .out_state(state_wire[g+1])
        );
    end
    always_ff @(posedge clk) begin
        if (rst) begin
            busy<=0; done<=0; injected<=0; retired<=0;
            for (int j=0;j<12;j++) begin ctx[j]<=0; lap[j]<=0; block_tag[j]<=0; end
        end else begin
            done<=0;
            if (start && !busy) begin
                busy<=1; injected<=0; retired<=0;
            end else if (advance) begin
                ctx[0]<=launch_ctx; lap[0]<=launch_lap; block_tag[0]<=launch_block;
                for (int j=1;j<12;j++) begin
                    ctx[j]<=ctx[j-1]; lap[j]<=lap[j-1]; block_tag[j]<=block_tag[j-1];
                end
                if (initial_input) injected<=injected+1;
                if (out_valid && final_block) begin
                    retired<=retired+1;
                    if (retired==11) begin busy<=0; done<=1; end
                end
            end
        end
    end
endmodule

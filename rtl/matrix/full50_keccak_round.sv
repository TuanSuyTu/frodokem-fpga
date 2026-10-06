`timescale 1ns/1ps
// One complete, exact Keccak round. PIPE_STAGES=3 cuts INSIDE the round.
// Public step freezes the entire pipeline; invalid data is never consumed.
// Datapath registers need no reset: control validity is synchronously reset.
module full50_keccak_round #(
    parameter integer PIPE_STAGES = 3
)(
    input  logic clk, rst, step, in_valid,
    input  logic [1599:0] in_state,
    input  logic [6:0] in_rc,
    output logic out_valid,
    output logic [1599:0] out_state
);
    generate
        if (PIPE_STAGES == 1) begin : r1
            wire [1599:0] next_state;
            keccak_fn u_round (.si(in_state), .rc(in_rc), .so(next_state));
            always_ff @(posedge clk) begin
                if (rst) out_valid <= 1'b0;
                else if (step) begin
                    out_valid <= in_valid;
                    if (in_valid) out_state <= next_state;
                end
            end
        end else if (PIPE_STAGES == 3) begin : p3
            wire [319:0] c, d;
            logic [1599:0] a1, pi2;
            logic [319:0] d1;
            logic [6:0] rc1, rc2;
            logic v1, v2;
            wire [1599:0] theta, rho, pi, chi, result;
            for (genvar x = 0; x < 5; x++) begin : column
                for (genvar z = 0; z < 64; z++) begin : bit_index
                    assign c[x*64+z] = in_state[(0*5+x)*64+z]
                                       ^ in_state[(1*5+x)*64+z]
                                       ^ in_state[(2*5+x)*64+z]
                                       ^ in_state[(3*5+x)*64+z]
                                       ^ in_state[(4*5+x)*64+z];
                    assign d[x*64+z] = c[((x+4)%5)*64+z]
                                       ^ c[((x+1)%5)*64+(z+63)%64];
                    for (genvar y = 0; y < 5; y++) begin : row
                        assign theta[(y*5+x)*64+z] = a1[(y*5+x)*64+z] ^ d1[x*64+z];
                    end
                end
            end
            // Existing fixed wiring and chi/iota semantics, unchanged.
            keccak_rho u_rho (.si(theta), .so(rho));
            keccak_pi u_pi (.si(rho), .so(pi));
            keccak_chi u_chi (.si(pi2), .so(chi));
            keccak_iota u_iota (.si(chi), .rc(rc2), .so(result));
            always_ff @(posedge clk) begin
                if (rst) begin
                    v1 <= 1'b0;
                    v2 <= 1'b0;
                    out_valid <= 1'b0;
                end else if (step) begin
                    v1 <= in_valid;
                    v2 <= v1;
                    out_valid <= v2;
                    if (in_valid) begin a1 <= in_state; d1 <= d; rc1 <= in_rc; end
                    if (v1) begin pi2 <= pi; rc2 <= rc1; end
                    if (v2) out_state <= result;
                end
            end
        end else begin : invalid_parameter
            initial $fatal(1, "PIPE_STAGES must be 1 or 3");
        end
    endgenerate
endmodule

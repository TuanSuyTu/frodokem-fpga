`timescale 1ns/1ps

module keccak_rc_indexed (
    input  logic [4:0] round_idx,
    output logic [6:0] rc
);

    always_comb begin
        case (round_idx)
            5'd0:  rc = 7'h01;
            5'd1:  rc = 7'h1a;
            5'd2:  rc = 7'h5e;
            5'd3:  rc = 7'h70;
            5'd4:  rc = 7'h1f;
            5'd5:  rc = 7'h21;
            5'd6:  rc = 7'h79;
            5'd7:  rc = 7'h55;
            5'd8:  rc = 7'h0e;
            5'd9:  rc = 7'h0c;
            5'd10: rc = 7'h35;
            5'd11: rc = 7'h26;
            5'd12: rc = 7'h3f;
            5'd13: rc = 7'h4f;
            5'd14: rc = 7'h5d;
            5'd15: rc = 7'h53;
            5'd16: rc = 7'h52;
            5'd17: rc = 7'h48;
            5'd18: rc = 7'h16;
            5'd19: rc = 7'h66;
            5'd20: rc = 7'h79;
            5'd21: rc = 7'h58;
            5'd22: rc = 7'h21;
            5'd23: rc = 7'h74;
            default: rc = 7'h00;
        endcase
    end

    // synopsys translate_off
    always_comb begin
        if (round_idx > 5'd23) begin
            assert (rc == 7'h00)
                else $error("keccak_rc_indexed: invalid round_idx %0d did not produce 0", round_idx);
            assert (round_idx <= 5'd23)
                else $error("keccak_rc_indexed: invalid round_idx %0d (> 23)", round_idx);
        end
    end

    initial begin
        logic [63:0] canonical_rc[0:23];
        logic [63:0] reconstructed;
        int r;

        canonical_rc[ 0] = 64'h0000000000000001;
        canonical_rc[ 1] = 64'h0000000000008082;
        canonical_rc[ 2] = 64'h800000000000808a;
        canonical_rc[ 3] = 64'h8000000080008000;
        canonical_rc[ 4] = 64'h000000000000808b;
        canonical_rc[ 5] = 64'h0000000080000001;
        canonical_rc[ 6] = 64'h8000000080008081;
        canonical_rc[ 7] = 64'h8000000000008009;
        canonical_rc[ 8] = 64'h000000000000008a;
        canonical_rc[ 9] = 64'h0000000000000088;
        canonical_rc[10] = 64'h0000000080008009;
        canonical_rc[11] = 64'h000000008000000a;
        canonical_rc[12] = 64'h000000008000808b;
        canonical_rc[13] = 64'h800000000000008b;
        canonical_rc[14] = 64'h8000000000008089;
        canonical_rc[15] = 64'h8000000000008003;
        canonical_rc[16] = 64'h8000000000008002;
        canonical_rc[17] = 64'h8000000000000080;
        canonical_rc[18] = 64'h000000000000800a;
        canonical_rc[19] = 64'h800000008000000a;
        canonical_rc[20] = 64'h8000000080008081;
        canonical_rc[21] = 64'h8000000000008080;
        canonical_rc[22] = 64'h0000000080000001;
        canonical_rc[23] = 64'h8000000080008008;

        for (r = 0; r < 24; r++) begin
            logic [6:0] test_rc;
            case (r[4:0])
                5'd0:  test_rc = 7'h01;
                5'd1:  test_rc = 7'h1a;
                5'd2:  test_rc = 7'h5e;
                5'd3:  test_rc = 7'h70;
                5'd4:  test_rc = 7'h1f;
                5'd5:  test_rc = 7'h21;
                5'd6:  test_rc = 7'h79;
                5'd7:  test_rc = 7'h55;
                5'd8:  test_rc = 7'h0e;
                5'd9:  test_rc = 7'h0c;
                5'd10: test_rc = 7'h35;
                5'd11: test_rc = 7'h26;
                5'd12: test_rc = 7'h3f;
                5'd13: test_rc = 7'h4f;
                5'd14: test_rc = 7'h5d;
                5'd15: test_rc = 7'h53;
                5'd16: test_rc = 7'h52;
                5'd17: test_rc = 7'h48;
                5'd18: test_rc = 7'h16;
                5'd19: test_rc = 7'h66;
                5'd20: test_rc = 7'h79;
                5'd21: test_rc = 7'h58;
                5'd22: test_rc = 7'h21;
                5'd23: test_rc = 7'h74;
                default: test_rc = 7'h00;
            endcase

            reconstructed = 64'd0;
            reconstructed[0]  = test_rc[0];
            reconstructed[1]  = test_rc[1];
            reconstructed[3]  = test_rc[2];
            reconstructed[7]  = test_rc[3];
            reconstructed[15] = test_rc[4];
            reconstructed[31] = test_rc[5];
            reconstructed[63] = test_rc[6];

            assert (reconstructed == canonical_rc[r])
                else $fatal(1, "keccak_rc_indexed: Round %0d reconstructed constant 0x%016x != canonical 0x%016x",
                            r, reconstructed, canonical_rc[r]);
        end
    end
    // synopsys translate_on

endmodule

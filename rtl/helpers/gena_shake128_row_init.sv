`timescale 1ns/1ps

// ==============================================================================
// Module: gena_shake128_row_init
// Description:
//   Construct the exact SHAKE128 absorb/pad state for `row_index || seedA`
//   using LightSec / FrodoKEM byte and bit ordering.
//
// Message:
//   row_index (16-bit little-endian) || seedA (128-bit, 16 bytes)
//   Total message = 18 bytes (144 bits).
// Rate for SHAKE128:
//   1344 bits (168 bytes).
// Padding (domain separation + pad10*1):
//   Byte 18: 8'h1F (domain 1111 followed by first pad bit 1)
//   Bytes 19..166 (148 bytes): 8'h00
//   Byte 167: 8'h80 (last pad bit 1 at bit 1343)
//   Bytes 168..199 (32 bytes = 256 bits): 8'h00 (capacity)
// ==============================================================================

module gena_shake128_row_init (
    input  logic [15:0]   row_index,
    input  logic [127:0]  seedA,
    output logic [1599:0] init_state
);

    assign init_state = {
        256'd0,                         // [1599:1344] Capacity: 32 bytes of zeros
        8'h80,                          // [1343:1336] Byte 167: end of rate padding (MSB = 1)
        1184'd0,                        // [1335:152]  Bytes 19..166: 148 bytes of zeros
        8'h1F,                          // [151:144]   Byte 18: SHAKE128 domain separator
        seedA,                          // [143:16]    Bytes 2..17: 128-bit seedA
        row_index                       // [15:0]      Bytes 0..1: 16-bit row_index
    };

endmodule

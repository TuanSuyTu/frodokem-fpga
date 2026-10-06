////    ////////////    Copyright (C) 2025 Giuseppe Manzoni, Barkhausen Institut
////    ////////////    
////                    This source describes Open Hardware and is licensed under the
////                    CERN-OHL-W v2 (https://cern.ch/cern-ohl)
////////////    ////    
////////////    ////    
////    ////    ////    
////    ////    ////    
////////////            Authors:
////////////            Giuseppe Manzoni (giuseppe.manzoni@barkhauseninstitut.org)


`ifndef ADAPTED_KECCAK_V
`define ADAPTED_KECCAK_V


// This file provides the module: adapted_keccak
// It contains the keccak implementation, with the additional option to inject bytes/zeros into the input of the keccak, and do the sampling on the output.


`include "keccak.v"
`include "seedAStorage.v"


`define KeccakInCMD_sendByte     3'b000
`define KeccakInCMD_sendZeros    3'b001
`define KeccakInCMD_forward      3'b010
`define KeccakInCMD_sendSeedA    3'b011
`define KeccakInCMD_receiveSeedA 3'b100

`define KeccakInCMD_SIZE  (8+1+3)


module adapted_keccak__in(
    output fast_idle,
    output [127:0] fast_seed,
    input [`KeccakInCMD_SIZE-1:0] cmd,  // {byteVal:8bits, skipIsLast:1bit, CMD:3bit}
    input cmd_isReady,
    output cmd_canReceive,

    input [64-1:0] h__out,
    input h__out_isReady,
    output h__out_canReceive,
    output h__out_isLast_in,
    input h__out_isLast_out,

    output [64-1:0] k__in,
    output k__in_isSingleByte,
    output k__in_isLast,
    output k__in_isReady,
    input k__in_canReceive,

    input rst,
    input clk
  );
  wire [`KeccakInCMD_SIZE-1:0] cmdB;
  wire cmdB_hasAny;
  wire cmdB_consume;
  assign fast_idle = !cmdB_hasAny && !cmd_isReady;
  bus_delayFull_fromstd #(.BusSize(`KeccakInCMD_SIZE), .N(4)) cmdBuf (
    .i(cmd),
    .i_isReady(cmd_isReady),
    .i_canReceive(cmd_canReceive),
    .o(cmdB),
    .o_hasAny(cmdB_hasAny),
    .o_consume(cmdB_consume),
    .rst(rst),
    .clk(clk)
  );
  wire cmdB_sendByte     = cmdB[0+:3] == `KeccakInCMD_sendByte & cmdB_hasAny;
  wire cmdB_sendZeros    = cmdB[0+:3] == `KeccakInCMD_sendZeros & cmdB_hasAny;
  wire cmdB_forward      = cmdB[0+:3] == `KeccakInCMD_forward & cmdB_hasAny;
  wire cmdB_sendSeedA    = cmdB[0+:3] == `KeccakInCMD_sendSeedA & cmdB_hasAny;
  wire cmdB_receiveSeedA = cmdB[0+:3] == `KeccakInCMD_receiveSeedA & cmdB_hasAny;
  wire cmdB_skipIsLast   = cmdB[3];
  wire [8-1:0] cmdB_byteVal = cmdB[4+:8];

  wire zerosCounter__restart_consume, zerosCounter__canReceive, zerosCounter__canReceive_isLast;
  wire isReady = zerosCounter__canReceive & k__in_canReceive;
  counter_bus_diff #(.N(8)) zerosCounter (
    .restart(cmdB_sendZeros),
    .numSteps(cmdB_byteVal),
    .restart_consume(zerosCounter__restart_consume),
    .canReceive(zerosCounter__canReceive),
    .canReceive_isLast(zerosCounter__canReceive_isLast),
    .isReady(isReady),
    .rst(rst),
    .clk(clk)
  );

  wire seedA__cmd_canReceive, seedA__in_canReceive, seedA__out_isReady;
  wire [64-1:0] seedA__out;
  wire seedA__cmdDisableSend;
  wire seedA__cmd_isReady = seedA__cmd_canReceive & ~seedA__cmdDisableSend & (cmdB_sendSeedA | cmdB_receiveSeedA);
  wire seedA__cmdDisableSend__set = seedA__cmd_isReady;
  wire seedA__cmdDisableSend__reset = cmdB_consume;
  ff_rs_next seedA__cmdDisableSend__ff(seedA__cmdDisableSend__reset, seedA__cmdDisableSend__set, seedA__cmdDisableSend, rst, clk);

  wire seedA__in_isReady = seedA__in_canReceive & h__out_isReady;
  wire seedA__out_canReceive = k__in_canReceive & cmdB_sendSeedA;
  seedAStorage seedA (
    .fast_seed(fast_seed),
    .cmd(cmdB_receiveSeedA),
    .cmd_isReady(seedA__cmd_isReady),
    .cmd_canReceive(seedA__cmd_canReceive),
    .in(h__out),
    .in_isReady(seedA__in_isReady),
    .in_canReceive(seedA__in_canReceive),
    .in_isLast(seedA__in_isLast),
    .out(seedA__out),
    .out_isReady(seedA__out_isReady),
    .out_canReceive(seedA__out_canReceive),
    .out_isLast(seedA__out_isLast),
    .rst(rst),
    .clk(clk)
  );

  assign cmdB_consume = cmdB_sendByte & k__in_canReceive
                      | cmdB_forward & h__out_isLast_out
                      | cmdB_sendZeros & zerosCounter__restart_consume
                      | cmdB_sendSeedA & seedA__out_isLast
                      | cmdB_receiveSeedA & seedA__in_isLast;

  assign h__out_isLast_in = seedA__in_isLast; // disabled
  assign h__out_canReceive = cmdB_forward & k__in_canReceive
                           | seedA__in_canReceive;

  assign k__in_isLast = ~cmdB_skipIsLast & cmdB_sendByte  & k__in_canReceive
                      | ~cmdB_skipIsLast & cmdB_forward   & h__out_isLast_out
                      | ~cmdB_skipIsLast & cmdB_sendZeros & zerosCounter__canReceive_isLast
                      | ~cmdB_skipIsLast & cmdB_sendSeedA & seedA__out_isLast;

  assign k__in_isSingleByte = cmdB_sendByte;
  assign k__in = (cmdB_sendByte ? {56'b0, cmdB_byteVal} : 64'b0)
               | (cmdB_forward ? h__out : 64'b0)
               | (cmdB_sendSeedA ? seedA__out : 64'b0);
  assign k__in_isReady = cmdB_sendByte & k__in_canReceive
                       | cmdB_forward & h__out_isReady
                       | cmdB_sendZeros & isReady
                       | cmdB_sendSeedA & seedA__out_isReady;
endmodule


`define KeccakOutCMD_SIZE  2

`define FRODO_0T0 15'd04643
`define FRODO_0T1 15'd13363
`define FRODO_0T2 15'd20579
`define FRODO_0T3 15'd25843
`define FRODO_0T4 15'd29227
`define FRODO_0T5 15'd31145
`define FRODO_0T6 15'd32103
`define FRODO_0T7 15'd32525
`define FRODO_0T8 15'd32689
`define FRODO_0T9 15'd32745
`define FRODO_0T10 15'd32762
`define FRODO_0T11 15'd32766

`define FRODO_1T0 15'd05638
`define FRODO_1T1 15'd15915
`define FRODO_1T2 15'd23689
`define FRODO_1T3 15'd28571
`define FRODO_1T4 15'd31116
`define FRODO_1T5 15'd32217
`define FRODO_1T6 15'd32613
`define FRODO_1T7 15'd32731
`define FRODO_1T8 15'd32760
`define FRODO_1T9 15'd32766

`define FRODO_2T0 15'd09142
`define FRODO_2T1 15'd23462
`define FRODO_2T2 15'd30338
`define FRODO_2T3 15'd32361
`define FRODO_2T4 15'd32725
`define FRODO_2T5 15'd32765


`define SamplerCONF_SIZE 3



module sampler_single(
    input [`SamplerCONF_SIZE-1:0] config_whichSampling,
    input [16-1:0] in,
    output [16-1:0] out
  );
  wire [15-1:0] val = in[15:1];

  wire isNeg = in[0];

  assign out[3:0] = (config_whichSampling[0] ? isNeg ? val <= `FRODO_0T0  ? -4'd0
                                                     : val <= `FRODO_0T1  ? -4'd1
                                                     : val <= `FRODO_0T2  ? -4'd2
                                                     : val <= `FRODO_0T3  ? -4'd3
                                                     : val <= `FRODO_0T4  ? -4'd4
                                                     : val <= `FRODO_0T5  ? -4'd5
                                                     : val <= `FRODO_0T6  ? -4'd6
                                                     : val <= `FRODO_0T7  ? -4'd7
                                                     : val <= `FRODO_0T8  ? -4'd8
                                                     : val <= `FRODO_0T9  ? -4'd9
                                                     : val <= `FRODO_0T10 ? -4'd10
                                                     : val <= `FRODO_0T11 ? -4'd11
                                                                          : -4'd12
                                                     : val <= `FRODO_0T0  ? 4'd0
                                                     : val <= `FRODO_0T1  ? 4'd1
                                                     : val <= `FRODO_0T2  ? 4'd2
                                                     : val <= `FRODO_0T3  ? 4'd3
                                                     : val <= `FRODO_0T4  ? 4'd4
                                                     : val <= `FRODO_0T5  ? 4'd5
                                                     : val <= `FRODO_0T6  ? 4'd6
                                                     : val <= `FRODO_0T7  ? 4'd7
                                                     : val <= `FRODO_0T8  ? 4'd8
                                                     : val <= `FRODO_0T9  ? 4'd9
                                                     : val <= `FRODO_0T10 ? 4'd10
                                                     : val <= `FRODO_0T11 ? 4'd11
                                                                          : 4'd12
                                             : 4'd0)
                  | (config_whichSampling[1] ? isNeg ? val <= `FRODO_1T0 ? -4'd0
                                                     : val <= `FRODO_1T1 ? -4'd1
                                                     : val <= `FRODO_1T2 ? -4'd2
                                                     : val <= `FRODO_1T3 ? -4'd3
                                                     : val <= `FRODO_1T4 ? -4'd4
                                                     : val <= `FRODO_1T5 ? -4'd5
                                                     : val <= `FRODO_1T6 ? -4'd6
                                                     : val <= `FRODO_1T7 ? -4'd7
                                                     : val <= `FRODO_1T8 ? -4'd8
                                                     : val <= `FRODO_1T9 ? -4'd9
                                                                         : -4'd10
                                                     : val <= `FRODO_1T0 ? 4'd0
                                                     : val <= `FRODO_1T1 ? 4'd1
                                                     : val <= `FRODO_1T2 ? 4'd2
                                                     : val <= `FRODO_1T3 ? 4'd3
                                                     : val <= `FRODO_1T4 ? 4'd4
                                                     : val <= `FRODO_1T5 ? 4'd5
                                                     : val <= `FRODO_1T6 ? 4'd6
                                                     : val <= `FRODO_1T7 ? 4'd7
                                                     : val <= `FRODO_1T8 ? 4'd8
                                                     : val <= `FRODO_1T9 ? 4'd9
                                                                         : 4'd10
                                             : 4'd0)
                  | (config_whichSampling[2] ? isNeg ? val <= `FRODO_2T0 ? -4'd0
                                                     : val <= `FRODO_2T1 ? -4'd1
                                                     : val <= `FRODO_2T2 ? -4'd2
                                                     : val <= `FRODO_2T3 ? -4'd3
                                                     : val <= `FRODO_2T4 ? -4'd4
                                                     : val <= `FRODO_2T5 ? -4'd5
                                                                         : -4'd6
                                                     : val <= `FRODO_2T0 ? 4'd0
                                                     : val <= `FRODO_2T1 ? 4'd1
                                                     : val <= `FRODO_2T2 ? 4'd2
                                                     : val <= `FRODO_2T3 ? 4'd3
                                                     : val <= `FRODO_2T4 ? 4'd4
                                                     : val <= `FRODO_2T5 ? 4'd5
                                                                         : 4'd6
                                             : 4'd0);
  assign out[15:4] = {12{isNeg & (out[3:0] != 0) }};
endmodule


module sampler(
    input [`SamplerCONF_SIZE-1:0] config_whichSampling,
    input enable,
    input [64-1:0] in,
    output [64-1:0] out
  );
  wire [64-1:0] out_sampled;
  sampler_single s0(config_whichSampling, in[16*0+:16], out_sampled[16*0+:16]);
  sampler_single s1(config_whichSampling, in[16*1+:16], out_sampled[16*1+:16]);
  sampler_single s2(config_whichSampling, in[16*2+:16], out_sampled[16*2+:16]);
  sampler_single s3(config_whichSampling, in[16*3+:16], out_sampled[16*3+:16]);
  assign out = enable ? out_sampled : in;
endmodule


module adapted_keccak__out(
    output fast_idle,
    input [`KeccakOutCMD_SIZE-1:0] cmd, // {skipIsLast:1bit, sample:1bit}
    input cmd_isReady,
    output cmd_canReceive,
    input [`SamplerCONF_SIZE-1:0] config_whichSampling,

    output [64-1:0] h__in,
    output h__in_isReady,
    input h__in_canReceive,
    output h__in_isLast_in,
    input h__in_isLast_out,

    input [64-1:0] k__out,
    input k__out_isReady,
    output k__out_canReceive,
    output k__out_isLast,

    input rst,
    input clk
  );

  wire [`KeccakOutCMD_SIZE-1:0] cmdB;
  wire cmdB_hasAny;
  wire cmdB_consume;
  assign fast_idle = !cmdB_hasAny && !cmd_isReady;
  bus_delay_fromstd #(.BusSize(`KeccakOutCMD_SIZE), .N(3)) cmdBuf (
    .i(cmd),
    .i_isReady(cmd_isReady),
    .i_canReceive(cmd_canReceive),
    .o(cmdB),
    .o_hasAny(cmdB_hasAny),
    .o_consume(cmdB_consume),
    .rst(rst),
    .clk(clk)
  );
  wire cmdB_forward = cmdB_hasAny; // the only primary command
  wire cmdB_skipIsLast = cmdB[1];
  wire cmdB_sample = cmdB[0];

  assign cmdB_consume = h__in_isLast_out;

  sampler sampler(config_whichSampling, cmdB_sample, k__out, h__in);

  assign h__in_isReady = cmdB_forward & k__out_isReady;
  assign h__in_isLast_in = 1'b0; // disabled
  assign k__out_canReceive = cmdB_forward & h__in_canReceive;
  assign k__out_isLast = ~cmdB_skipIsLast & cmdB_forward & h__in_isLast_out;
endmodule

`define KeccakAdaptedCMD_SIZE  (4 + `Keccak_BlockCounterSize + 1)


module adapted_keccak (
    output fast_idle,
    output [127:0] fast_seed,
    input [`KeccakInCMD_SIZE-1:0] k_in__cmd,  // {byteVal:8bits, skipIsLast:1bit, CMD:1bit}
    input k_in__cmd_isReady,
    output k_in__cmd_canReceive,

    input [`KeccakOutCMD_SIZE-1:0] k_out__cmd, // {skipIsLast:1bit, sample:1bit}
    input k_out__cmd_isReady,
    output k_out__cmd_canReceive,

    input [`KeccakAdaptedCMD_SIZE-1:0] k__cmd, // { is128else256:1bit, inState:1bit, outState:1bit, mainIsInElseOut:1bit, mainNumBlocks:9bits, secondaryNumBlocks:1bits }
    input k__cmd_isReady,
    output k__cmd_canReceive,

    input [`SamplerCONF_SIZE-1:0] config_whichSampling,

    input [64-1:0] h__out,
    input h__out_isReady,
    output h__out_canReceive,
    output h__out_isLast_in,
    input h__out_isLast_out,

    output [64-1:0] h__in,
    output h__in_isReady,
    input h__in_canReceive,
    output h__in_isLast_in,
    input h__in_isLast_out,

    input rst,
    input clk
  );

  wire [64-1:0] k__in;
  wire k__in_isSingleByte;
  wire k__in_isLast;
  wire k__in_isReady;
  wire k__in_canReceive;
  wire [64-1:0] k__out;
  wire k__out_isReady;
  wire k__out_canReceive;
  wire k__out_isLast;

  wire [`KeccakAdaptedCMD_SIZE-1:0] k__cmdB;
  wire k__cmdB_isReady;
  wire k__cmdB_canReceive;
  bus_delay_std #(.BusSize(`KeccakAdaptedCMD_SIZE), .N(1)) k__buffer (
    .i(k__cmd),
    .i_isReady(k__cmd_isReady),
    .i_canReceive(k__cmd_canReceive),
    .o(k__cmdB),
    .o_isReady(k__cmdB_isReady),
    .o_canReceive(k__cmdB_canReceive),
    .rst(rst),
    .clk(clk)
  );

  wire [`Keccak_BlockCounterSize-1:0] k__cmd__secondaryNumBlocks = {{`Keccak_BlockCounterSize-1{1'b0}}, k__cmdB[0]};
  wire [`Keccak_BlockCounterSize-1:0] k__cmd__mainNumBlocks = k__cmdB[1+:`Keccak_BlockCounterSize];
  wire k__cmd__mainIsInElseOut = k__cmdB[1+`Keccak_BlockCounterSize];
  wire [3-1:0] k__cmd__param = k__cmdB[1+`Keccak_BlockCounterSize+1+:3];
  wire [`KeccakCMD_SIZE-1:0] k__cmd__expanded = k__cmd__mainIsInElseOut ? { k__cmd__param, k__cmd__mainNumBlocks,      k__cmd__secondaryNumBlocks }
                                                                        : { k__cmd__param, k__cmd__secondaryNumBlocks, k__cmd__mainNumBlocks      };

  keccak k(
    .cmd(k__cmd__expanded),
    .cmd_isReady(k__cmdB_isReady),
    .cmd_canReceive(k__cmdB_canReceive),
    .in(k__in),
    .in_isSingleByte(k__in_isSingleByte),
    .in_isLast(k__in_isLast),
    .in_isReady(k__in_isReady),
    .in_canReceive(k__in_canReceive),
    .out(k__out),
    .out_isReady(k__out_isReady),
    .out_canReceive(k__out_canReceive),
    .out_isLast(k__out_isLast),
    .rst(rst),
    .clk(clk)
  );

  wire fast_input_idle, fast_output_idle;
  assign fast_idle = fast_input_idle && fast_output_idle && !k__cmdB_isReady;
  adapted_keccak__in k_in(
    .fast_idle(fast_input_idle),
    .fast_seed(fast_seed),
    .cmd(k_in__cmd),
    .cmd_isReady(k_in__cmd_isReady),
    .cmd_canReceive(k_in__cmd_canReceive),
    .h__out(h__out),
    .h__out_isReady(h__out_isReady),
    .h__out_canReceive(h__out_canReceive),
    .h__out_isLast_in(h__out_isLast_in),
    .h__out_isLast_out(h__out_isLast_out),
    .k__in(k__in),
    .k__in_isSingleByte(k__in_isSingleByte), 
    .k__in_isLast(k__in_isLast),
    .k__in_isReady(k__in_isReady),
    .k__in_canReceive(k__in_canReceive),
    .rst(rst),
    .clk(clk)
  );

  adapted_keccak__out k_out(
    .fast_idle(fast_output_idle),
    .cmd(k_out__cmd),
    .cmd_isReady(k_out__cmd_isReady),
    .cmd_canReceive(k_out__cmd_canReceive),
    .config_whichSampling(config_whichSampling),
    .h__in(h__in),
    .h__in_isReady(h__in_isReady),
    .h__in_canReceive(h__in_canReceive),
    .h__in_isLast_in(h__in_isLast_in),
    .h__in_isLast_out(h__in_isLast_out),
    .k__out(k__out),
    .k__out_isReady(k__out_isReady),
    .k__out_canReceive(k__out_canReceive),
    .k__out_isLast(k__out_isLast),
    .rst(rst),
    .clk(clk)
  );

endmodule


`endif // ADAPTED_KECCAK_V

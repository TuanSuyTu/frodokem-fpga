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


`ifndef KECCAK_V
`define KECCAK_V


// This file provides the module: keccak
// It contains the keccak implementation


`include "lib.v"


module keccak_rc(
  input	  cycle_first,
  output  [7-1:0] rc, // the first rc is outputted in the same cycle as cycle_first
  input rst,
  input clk
);
  wire [8-1:0] r__d1;

  reg [8-1:0] r;
  reg [7-1:0] rc__r;
  integer i;
  always @* begin
    r = r__d1;
    for(i = 0; i < 7; i = i+1) begin
      if(i == 0 && cycle_first)
        r = 8'b1;
      else
        r = r << 1 ^ 8'b0111_0001 & {8{r[7]}};
      rc__r[i] = r[0];
    end
  end
  
  assign rc = rc__r;
  delay #(8) r_exp__ff (r, r__d1, rst, clk);
endmodule

`define KECCAK_INDEX(x,y,z)  ( 64*(5*y+x) + z )


module keccak_theta(
  input	  [1600-1:0] si,
  output  [1600-1:0] so
);
  wire [64*5-1:0] sum;

  genvar x;
  genvar y;
  genvar z;
  generate
    for (x = 0; x < 5; x=x+1) begin
      for (z = 0; z < 64; z=z+1) begin
        assign sum[64*x+z] = si[`KECCAK_INDEX(x,0,z)]
                           ^ si[`KECCAK_INDEX(x,1,z)]
                           ^ si[`KECCAK_INDEX(x,2,z)]
                           ^ si[`KECCAK_INDEX(x,3,z)]
                           ^ si[`KECCAK_INDEX(x,4,z)];	
      end
    end
    for (x = 0; x < 5; x=x+1) begin
      for (y = 0; y < 5; y=y+1) begin
        for (z = 0; z < 64; z=z+1) begin
          assign so[`KECCAK_INDEX(x,y,z)] = si[`KECCAK_INDEX(x,y,z)]
                                          ^ sum[64*((x-1+5)%5) +      z     ]
                                          ^ sum[64*((x+1  )%5) + (z-1+64)%64];
        end
      end
    end
  endgenerate
endmodule

`define keccak_rho_op(x,y,shift,z)    assign so[`KECCAK_INDEX(x,y,(z + shift) % 64)] = si[`KECCAK_INDEX(x,y,z)]


module keccak_rho(
  input	  [1600-1:0] si,
  output  [1600-1:0] so
);
  genvar z;
  generate
    for (z = 0; z < 64; z=z+1) begin
      `keccak_rho_op(3,2, 25,z);
      `keccak_rho_op(3,1, 55,z);
      `keccak_rho_op(3,0, 28,z);
      `keccak_rho_op(3,4, 56,z);
      `keccak_rho_op(3,3, 21,z);

      `keccak_rho_op(4,2, 39,z);
      `keccak_rho_op(4,1, 20,z);
      `keccak_rho_op(4,0, 27,z);
      `keccak_rho_op(4,4, 14,z);
      `keccak_rho_op(4,3,  8,z);

      `keccak_rho_op(0,2, 3,z);
      `keccak_rho_op(0,1,36,z);
      `keccak_rho_op(0,0, 0,z);
      `keccak_rho_op(0,4,18,z);
      `keccak_rho_op(0,3,41,z);

      `keccak_rho_op(1,2,10,z);
      `keccak_rho_op(1,1,44,z);
      `keccak_rho_op(1,0, 1,z);
      `keccak_rho_op(1,4, 2,z);
      `keccak_rho_op(1,3,45,z);

      `keccak_rho_op(2,2,43,z);
      `keccak_rho_op(2,1, 6,z);
      `keccak_rho_op(2,0,62,z);
      `keccak_rho_op(2,4,61,z);
      `keccak_rho_op(2,3,15,z);
    end
  endgenerate
endmodule


module keccak_pi(
  input	  [1600-1:0] si,
  output  [1600-1:0] so
);
  genvar x;
  genvar y;
  genvar z;
  generate
    for (x = 0; x < 5; x=x+1) begin
      for (y = 0; y < 5; y=y+1) begin
        for (z = 0; z < 64; z=z+1) begin
          assign so[`KECCAK_INDEX(x,y,z)] = si[`KECCAK_INDEX((x+3*y)%5,x,z)];
        end
      end
    end
  endgenerate
endmodule


module keccak_chi(
  input	  [1600-1:0] si,
  output  [1600-1:0] so
);
  genvar x;
  genvar y;
  genvar z;
  generate
    for (x = 0; x < 5; x=x+1) begin
      for (y = 0; y < 5; y=y+1) begin
        for (z = 0; z < 64; z=z+1) begin
          assign so[`KECCAK_INDEX(x,y,z)] = si[`KECCAK_INDEX(x,y,z)]
                                          ^ ~si[`KECCAK_INDEX((x+1) % 5,y,z)] & si[`KECCAK_INDEX((x+2) % 5,y,z)];
        end
      end
    end
  endgenerate
endmodule


module keccak_iota(
  input	  [1600-1:0] si,
  input   [6:0] rc,
  output  [1600-1:0] so
);
  wor [64-1:0] rce;
  assign rce = 64'b0;

  genvar i;
  generate
    for (i = 0; i <= 6; i=i+1) begin
      assign rce[2**i-1] = rc[i];
    end
  endgenerate

  genvar x;
  genvar y;
  genvar z;
  generate
    for (x = 0; x < 5; x=x+1) begin
      for (y = 0; y < 5; y=y+1) begin
        for (z = 0; z < 64; z=z+1) begin
          if(x == 0 && y == 0)
            assign so[`KECCAK_INDEX(x,y,z)] = si[`KECCAK_INDEX(x,y,z)] ^ rce[z];
          else
            assign so[`KECCAK_INDEX(x,y,z)] = si[`KECCAK_INDEX(x,y,z)];
        end
      end
    end
  endgenerate
endmodule


module keccak_fn(
  input	  [1600-1:0] si,
  input   [6:0] rc,
  output  [1600-1:0] so
);
  wire [0:1600-1] s1,s2,s3,s4;

  keccak_theta theta(si, s1);
  keccak_rho rho(s1, s2);
  keccak_pi pi(s2, s3);
  keccak_chi chi(s3, s4);
  keccak_iota iota(s4, rc, so);
endmodule


module keccak_iter(
  input cmd_start,
  input cmd_continue,
  output cmd_canReceive,
  input isTransparent,
  input isTransparent_merge,
  input [1600-1:0] in_data,
  output [1600-1:0] out_data__d1, // the last valid output is during the clk when the next cmd_ is sent
  
  input rst,
  input clk
);
  assign cmd_isFirst = cmd_start | cmd_continue;

  wire counter__canReceive;
  wire counter__restart = cmd_isFirst & ~isTransparent;
  counter_bus_fixed #(24) counter (
    .restart(counter__restart),
    .canRestart(cmd_canReceive),
    .canReceive(counter__canReceive),
    .isReady(counter__canReceive),
    .rst(rst),
    .clk(clk)
  );

  wire [7-1:0] rc;
  keccak_rc rcGenerator(cmd_isFirst, rc, rst, clk);

  wire [1600-1:0] statePrev;
  wire [1600-1:0] body__si = {1600{~cmd_start}} & statePrev
                           ^ {1600{cmd_isFirst}} & in_data;

  wire [1600-1:0] body__so;
  keccak_fn body(body__si, rc, body__so);

  wire [1600-1:0] statePost = (isTransparent_merge ? body__si : 1600'b0)
                            | (~isTransparent_merge & isTransparent ? in_data : 1600'b0)
                            | (~isTransparent & counter__canReceive ? body__so : 1600'b0)
                            | (~isTransparent & ~counter__canReceive ? statePrev : 1600'b0);
  delay #(1600) state__ff(statePost, statePrev, rst, clk);

  assign out_data__d1 = statePrev;
endmodule



module keccak_busInConverter_addTerminator(
  input [64-1:0] in, // the unused must be 0
  input in_isSingleByte,
  input in_isLast,
  input in_isReady,
  output in_canReceive,

  output [64-1:0] out,
  output out_isSingleByte,
  output out_isLast__imm,
  output out_isReady,
  input out_canReceive,

  input rst,
  input clk
);
  ff_sr_next out_isLast__ff(in_isLast, out_canReceive, out_isLast__imm, rst, clk);

  assign in_canReceive = out_canReceive & ~out_isLast__imm;
  assign out = out_isLast__imm ? 64'h1F : in;
  assign out_isSingleByte = in_isSingleByte | out_isLast__imm;
  assign out_isReady = in_isReady | out_isLast__imm & out_canReceive;
endmodule


module keccak_busInConverter_align(
  input [64-1:0] in, // the unused must be 0
  input in_isSingleByte,
  input in_isLast__imm,
  input in_isReady,
  output in_canReceive,

  output [64-1:0] out,
  output out_isReady,
  output out_isLast__imm,
  input out_canReceive,

  input rst,
  input clk
);
  wire [64-1:0] excess__a1, excess; // unused are 0s
  wire [3-1:0] usedBytes__a1, usedBytes;
  delay #(64) excess__ff (excess__a1, excess, rst, clk);
  delay #(3) usedBytes__ff (usedBytes__a1, usedBytes, rst, clk);

  wire [128-1:0] composed = in << 8*usedBytes | excess;
  wire composed_isFirstWordFull = ~in_isSingleByte | usedBytes == 3'd7;
  wire composed_hasAnySecondWord = ~in_isSingleByte & usedBytes != 3'd0;

  wire needAddFrame;
  wire needAddFrame__set = in_isReady & in_isLast__imm & composed_hasAnySecondWord;
  ff_sr_next needAddFrame__ff (needAddFrame__set, out_canReceive, needAddFrame, rst, clk);

  assign out = composed[0+:64];
  assign in_canReceive = out_canReceive & ~needAddFrame;

  assign out_isLast__imm = in_isReady & in_isLast__imm & ~composed_hasAnySecondWord
                         | out_canReceive & needAddFrame;
  assign out_isReady = in_isReady & composed_isFirstWordFull | out_isLast__imm;

  assign excess__a1 = out_isReady ? composed[64+:64]
                    : in_isReady  ? composed[ 0+:64]
                                  : excess;
  assign usedBytes__a1 = out_isLast__imm              ? 3'd0
                       : in_isReady & in_isSingleByte ? usedBytes + 3'd1
                                                      : usedBytes;
endmodule


module keccak_busInConverter_padEndingAndEnd(
  input [64-1:0] in,
  input in_isReady,
  input in_isLast__imm,
  output in_canReceive,

  output [64-1:0] out,
  output out_isReady,
  input out_canReceive,
  input out_lastOfBlock,

  input rst,
  input clk
);
  wire in_isEnded__set = in_isLast__imm & in_isReady;
  wire in_isEnded__reset = out_lastOfBlock & out_canReceive;
  wire in_isEnded;
  ff_rs_next in_isEnded__ff(in_isEnded__reset, in_isEnded__set, in_isEnded, rst, clk);

  assign in_canReceive = out_canReceive & ~in_isEnded;
  assign out = (~in_isEnded ? in : 64'b0)
             | ((in_isEnded | in_isEnded__set) & out_lastOfBlock ? 64'h1 << 63 : 64'h0);
  assign out_isReady = in_isReady
                     | in_isEnded & out_canReceive;
endmodule

`define SHAKE128_R64 21 /*1344 bits*/
`define SHAKE256_R64 17 /*1088 bits*/
`define SHAKESTATE_R64 25 /* to output the whole state*/


module keccak_busInConverter_padCycle(
  input start128,  // can't interrupt
  input start256,

  input [64-1:0] in,
  input in_isReady,
  output in_canReceive,
  output in_lastOfBlock,

  output [64-1:0] out,
  output out_isReady,
  input out_canReceive,

  input rst,
  input clk
);
  wire canRestart;
  wire startAny = (start128 | start256) & canRestart;

  wire is256else128;
  ff_en_imm is256else128__ff(startAny, start256, is256else128, rst, clk);
  
  wire c256__canRestart, c256__canReceive;
  wire c256__isLast;
  wire c256__isReady = in_isReady & c256__canReceive;
  counter_bus_fixed #(`SHAKE256_R64) c256 (
    .restart(startAny),
    .canRestart(c256__canRestart),
    .canReceive(c256__canReceive),
    .canReceive_isLast(c256__isLast),
    .isReady(c256__isReady),
    .rst(rst),
    .clk(clk)
  );

  wire cDiff__restart;
  delay cDiff__ff(c256__isLast, cDiff__restart, rst, clk);
  wire cDiff__canRestart, cDiff__canReceive, cDiff__canReceive_isLast;
  wire cDiff__isReady = cDiff__canReceive & (is256else128 ? out_canReceive : in_isReady);
  counter_bus_fixed #(`SHAKE128_R64 - `SHAKE256_R64) cDiff (
    .restart(cDiff__restart),
    .canRestart(cDiff__canRestart),
    .canReceive(cDiff__canReceive),
    .canReceive_isLast(cDiff__canReceive_isLast),
    .isReady(cDiff__isReady),
    .rst(rst),
    .clk(clk)
  );

  assign canRestart = c256__canRestart & cDiff__canRestart;

  wire counters_canReceive = c256__canReceive | cDiff__canReceive & ~is256else128;
  assign in_canReceive = out_canReceive & counters_canReceive;
  
  assign in_lastOfBlock = is256else128 ? c256__isLast : cDiff__canReceive_isLast;
  assign out_isReady = in_isReady
                     | (out_canReceive & cDiff__canReceive & is256else128);
  assign out = in & {64{in_isReady}};
endmodule


module keccak_busInConverter(
  input start128,  // can't interrupt
  input start256,

  input [64-1:0] in, // the unused must be 0
  input in_isSingleByte,
  input in_isLast,
  input in_isReady,
  output in_canReceive,

  output [64-1:0] out,
  output out_isReady,
  input out_canReceive,

  input rst,
  input clk
);

  wire [64-1:0] s1;
  wire s1_isSingleByte;
  wire s1_isLast__imm;
  wire s1_isReady;
  wire s1_canReceive;
  keccak_busInConverter_addTerminator addTerm(
    .in(in),
    .in_isSingleByte(in_isSingleByte),
    .in_isLast(in_isLast),
    .in_isReady(in_isReady),
    .in_canReceive(in_canReceive),

    .out(s1),
    .out_isSingleByte(s1_isSingleByte),
    .out_isLast__imm(s1_isLast__imm),
    .out_isReady(s1_isReady),
    .out_canReceive(s1_canReceive),

    .rst(rst),
    .clk(clk)
  );

  wire [64-1:0] s2;
  wire s2_isLast__imm;
  wire s2_isReady;
  wire s2_canReceive;
  keccak_busInConverter_align align(
    .in(s1),
    .in_isSingleByte(s1_isSingleByte),
    .in_isLast__imm(s1_isLast__imm),
    .in_isReady(s1_isReady),
    .in_canReceive(s1_canReceive),

    .out(s2),
    .out_isLast__imm(s2_isLast__imm),
    .out_isReady(s2_isReady),
    .out_canReceive(s2_canReceive),

    .rst(rst),
    .clk(clk)
  );

  wire [64-1:0] s3;
  wire s3_isReady;
  wire s3_canReceive;
  wire s3_lastOfBlock;
  keccak_busInConverter_padEndingAndEnd paddingEnd(
    .in(s2),
    .in_isLast__imm(s2_isLast__imm),
    .in_isReady(s2_isReady),
    .in_canReceive(s2_canReceive),

    .out(s3),
    .out_isReady(s3_isReady),
    .out_canReceive(s3_canReceive),
    .out_lastOfBlock(s3_lastOfBlock),

    .rst(rst),
    .clk(clk)
  );

  keccak_busInConverter_padCycle padCycle(
    .start128(start128),
    .start256(start256),

    .in(s3),
    .in_isReady(s3_isReady),
    .in_canReceive(s3_canReceive),
    .in_lastOfBlock(s3_lastOfBlock),

    .out(out),
    .out_isReady(out_isReady),
    .out_canReceive(out_canReceive),

    .rst(rst),
    .clk(clk)
  );
endmodule


module keccak_busOutConverter(
  input start128,  // can't interrupt
  input start256,
  input startState,
  output canRestart,

  input [64-1:0] in,
  input in_isReady,
  output in_canReceive,

  output [64-1:0] out,
  output out_isReady,
  input out_canReceive,
  input out_isLast,

  input rst,
  input clk
);
  wire startAny = (start128 | start256 | startState) & canRestart;

  wire is256else128;
  ff_en_imm is256else128__ff(startAny, start256, is256else128, rst, clk);
  wire isState;
  ff_en_imm isState__ff(startAny, startState, isState, rst, clk);

  wire c256__canRestart, c256__canReceive;
  wire c256__isLast;
  wire c256__isReady = in_isReady & c256__canReceive;
  counter_bus_fixed #(`SHAKE256_R64) c256 (
    .restart(startAny),
    .canRestart(c256__canRestart),
    .canReceive(c256__canReceive),
    .canReceive_isLast(c256__isLast),
    .isReady(c256__isReady),
    .rst(rst),
    .clk(clk)
  );

  wire cDiff__restart;
  delay cDiff__ff(c256__isLast, cDiff__restart, rst, clk);
  wire cDiff__canRestart, cDiff__canReceive;
  wire cDiff__isReady = in_isReady & cDiff__canReceive;
  wire cDiff__canReceive_isLast;
  counter_bus_fixed #(`SHAKE128_R64 - `SHAKE256_R64) cDiff (
    .restart(cDiff__restart),
    .canRestart(cDiff__canRestart),
    .canReceive(cDiff__canReceive),
    .canReceive_isLast(cDiff__canReceive_isLast),
    .isReady(cDiff__isReady),
    .rst(rst),
    .clk(clk)
  );

  wire cStateDiff__restart;
  wire cStateDiff__restart__a1 = isState & cDiff__canReceive_isLast;
  delay cStateDiff__ff(cStateDiff__restart__a1, cStateDiff__restart, rst, clk);
  wire cStateDiff__canRestart, cStateDiff__canReceive;
  wire cStateDiff__isReady = in_isReady & cStateDiff__canReceive;
  wire cStateDiff__canReceive_isLast;
  counter_bus_fixed #(`SHAKESTATE_R64 - `SHAKE128_R64) cStateDiff (
    .restart(cStateDiff__restart),
    .canRestart(cStateDiff__canRestart),
    .canReceive(cStateDiff__canReceive),
    .canReceive_isLast(cStateDiff__canReceive_isLast),
    .isReady(cStateDiff__isReady),
    .rst(rst),
    .clk(clk)
  );

  assign canRestart = c256__canRestart & cDiff__canRestart & cStateDiff__canRestart;
  assign out = in;

  wire noMoreOut;
  wire noMoreOut__reset = isState ? cStateDiff__canReceive_isLast : cDiff__canReceive_isLast;
  ff_rs_next noMoreOut__ff (noMoreOut__reset, out_isLast, noMoreOut, rst, clk);

  assign in_canReceive = (c256__canReceive | cDiff__canReceive | cStateDiff__canReceive) & (out_canReceive | noMoreOut) | cDiff__canReceive & is256else128;
  assign out_isReady = (c256__canReceive | cDiff__canReceive & ~is256else128 | cStateDiff__canReceive) & in_isReady & ~noMoreOut;
endmodule


module keccak_busTwoIn(
  input startA,
  input startB,

  input [64-1:0] inA,
  input inA_isReady,
  output inA_canReceive,

  input [64-1:0] inB,
  input inB_isReady,
  output inB_canReceive,

  output [64-1:0] out,
  output out_isReady,
  input out_canReceive,

  input rst,
  input clk
);
  wire startAny = startA | startB;

  wire isA, isB;
  ff_en_imm isA__ff(startAny, startA, isA, rst, clk);
  ff_en_imm isB__ff(startAny, startB, isB, rst, clk);

  assign inA_canReceive = out_canReceive & isA;
  assign inB_canReceive = out_canReceive & isB;
  assign out = (isA ? inA : 64'b0)
             | (isB ? inB : 64'b0);
  assign out_isReady = inA_isReady | inB_isReady;
endmodule


module keccak_busTwoOut(
  input startA,
  input startB,

  input [64-1:0] in,
  input in_isSingleByte,
  input in_isLast,
  input in_isReady,
  output in_canReceive,

  output [64-1:0] outA,
  output outA_isSingleByte,
  output outA_isLast,
  output outA_isReady,
  input outA_canReceive,

  output [64-1:0] outB,
  output outB_isSingleByte,
  output outB_isLast,
  output outB_isReady,
  input outB_canReceive,

  input rst,
  input clk
);
  wire startAny = startA | startB;

  wire isA, isB;
  ff_en_imm isA__ff(startAny, startA, isA, rst, clk);
  ff_en_imm isB__ff(startAny, startB, isB, rst, clk);

  assign in_canReceive = isA & outA_canReceive
                       | isB & outB_canReceive;
  assign outA = in;
  assign outA_isSingleByte = in_isSingleByte & isA;
  assign outA_isLast = in_isLast & isA;
  assign outA_isReady = in_isReady & isA;
  assign outB = in;
  assign outB_isSingleByte = in_isSingleByte & isB;
  assign outB_isLast = in_isLast & isB;
  assign outB_isReady = in_isReady & isB;
endmodule

//    /++-++\
//       ../+-\
//           /-\
//            /-+\
//             ./-\
//                |-\

module keccak_block(
  output cmd_canReceive,
  // the various commands for a given block must be set together during the first cycle
  // only one of the doDes* can be set
  // only one of the doSer* can be set
  // only one of do*State and doKeccak* can be set 
  input cmd_des128,
  input cmd_des256,
  input cmd_desState,
  input cmd_ser128,
  input cmd_ser256,
  input cmd_serState,
  input cmd_keccakStart,
  input cmd_keccakContinue,

  input [64-1:0] in,
  input in_isSingleByte,
  input in_isReady,
  input in_isLast, // only used to pad the input data
  output in_canReceive,

  output [64-1:0] out,
  output out_isReady,
  input out_canReceive,
  input out_isLast, // only used to drop the remaining output of the block

  input rst,
  input clk
);
  wire cmd_desBuf = cmd_des128 | cmd_des256;
  wire cmd_serBuf = cmd_ser128 | cmd_ser256;
  wire cmd_anyBuf = cmd_serBuf | cmd_desBuf;
  wire cmd_anyState = cmd_serState | cmd_desState;
  wire cmd_anySer = cmd_serBuf | cmd_serState;
  wire cmd_keccakAny = (cmd_keccakStart | cmd_keccakContinue) & ~cmd_serState;
  wire cmd_any = cmd_anyBuf | cmd_anyState | cmd_keccakAny;

  wire isAnyState, isAnyState__d1, isAnyBuf__d1, isKeccakAny__d1, isAnySer__d1;
  ff_en_imm isAnyState__ff1(cmd_any, cmd_anyState, isAnyState, rst, clk);
  delay isAnyState__ff2(isAnyState, isAnyState__d1, rst, clk);
  ff_en_next isAnyBuf__ff(cmd_any, cmd_anyBuf, isAnyBuf__d1, rst, clk);
  ff_en_next isKeccakAny__ff(cmd_any, cmd_keccakAny, isKeccakAny__d1, rst, clk);
  ff_en_next isAnySer__ff(cmd_any, cmd_anySer, isAnySer__d1, rst, clk);





  wire [64-1:0] inB;
  wire inB_isSingleByte;
  wire inB_isLast__i;
  wire inB_isReady__i;
  wire inB_canReceive;
  wire inB_isLast;
  wire inB_isReady;
  bus_delayFull_std #(.BusSize(64+1), .N(1)) inDelay (
    .i({ in_isSingleByte, in }),
    .i_isReady(in_isReady),
    .i_canReceive(in_canReceive),
    .i_isLast(in_isLast),
    .o({ inB_isSingleByte, inB }),
    .o_isReady(inB_isReady),
    .o_canReceive(inB_canReceive),
    .o_isLast(inB_isLast),
    .rst(rst),
    .clk(clk)
  );

  wire [64-1:0] inRawBuf;
  wire inRawBuf_isSingleByte;
  wire inRawBuf_isLast;
  wire inRawBuf_isReady;
  wire inRawBuf_canReceive;
  wire [64-1:0] inSta;
  wire inSta_isReady;
  wire inSta_canReceive;
  wire ignore1;
  wire ignore2;
  keccak_busTwoOut twoOut(
    .startA(cmd_desBuf),
    .startB(cmd_desState),
    .in(inB),
    .in_isSingleByte(inB_isSingleByte),
    .in_isLast(inB_isLast),
    .in_isReady(inB_isReady),
    .in_canReceive(inB_canReceive),
    .outA(inRawBuf),
    .outA_isSingleByte(inRawBuf_isSingleByte),
    .outA_isLast(inRawBuf_isLast),
    .outA_isReady(inRawBuf_isReady),
    .outA_canReceive(inRawBuf_canReceive),
    .outB(inSta),
    .outB_isReady(inSta_isReady),
    .outB_canReceive(inSta_canReceive),
    .outB_isSingleByte(ignore1),
    .outB_isLast(ignore2),
    .rst(rst),
    .clk(clk)
  );

  wire [64-1:0] inBuf;
  wire inBuf_isReady;
  wire inBuf_canReceive;
  keccak_busInConverter inConv(
    .start128(cmd_des128),
    .start256(cmd_des256),
    .in(inRawBuf),
    .in_isSingleByte(inRawBuf_isSingleByte),
    .in_isLast(inRawBuf_isLast),
    .in_isReady(inRawBuf_isReady),
    .in_canReceive(inRawBuf_canReceive),
    .out(inBuf),
    .out_isReady(inBuf_isReady),
    .out_canReceive(inBuf_canReceive),
    .rst(rst),
    .clk(clk)
  );


  wire [64-1:0] outB;
  wire outB_isReady;
  wire outB_canReceive;
  wire outConv_canRestart;
  keccak_busOutConverter outConv(
    .start128(cmd_ser128),
    .start256(cmd_ser256),
    .startState(cmd_serState),
    .canRestart(outConv_canRestart),
    .in(outB),
    .in_isReady(outB_isReady),
    .in_canReceive(outB_canReceive),
    .out(out),
    .out_isReady(out_isReady),
    .out_canReceive(out_canReceive),
    .out_isLast(out_isLast),
    .rst(rst),
    .clk(clk)
  );

  wire [64-1:0] outC;
  wire outC_isReady;
  wire outC_canReceive;
  wire ignore;
  bus_delayFull_std #(.BusSize(64), .N(1)) outDelay (
    .i(outC),
    .i_isReady(outC_isReady),
    .i_canReceive(outC_canReceive),
    .i_isLast(1'b0),
    .o(outB),
    .o_isReady(outB_isReady),
    .o_canReceive(outB_canReceive),
    .o_isLast(ignore),
    .rst(rst),
    .clk(clk)
  );

  wire [64-1:0] outBuf;
  wire outBuf_isReady;
  wire outBuf_canReceive;
  wire [64-1:0] outSta;
  wire outSta_isReady;
  wire outSta_canReceive;
  keccak_busTwoIn twoIn(
    .startA(cmd_serBuf),
    .startB(cmd_serState),
    .inA(outBuf),
    .inA_isReady(outBuf_isReady),
    .inA_canReceive(outBuf_canReceive),
    .inB(outSta),
    .inB_isReady(outSta_isReady),
    .inB_canReceive(outSta_canReceive),
    .out(outC),
    .out_isReady(outC_isReady),
    .out_canReceive(outC_canReceive),
    .rst(rst),
    .clk(clk)
  );
  
  
  wire cmd_serState__d1;
  delay cmd_serState__ff (cmd_serState, cmd_serState__d1, rst, clk);

  wire state__cmd_canReceive;
  wire [1600-1:0] state__buffer_write;
  wire [1600-1:0] state__buffer_read;
  serdes #(1600/64) state (
    .cmd_canReceive(state__cmd_canReceive),
    .buffer_write(state__buffer_write),
    .buffer_read(state__buffer_read),
    .cmd_startDes(cmd_desState),
    .cmd_startSer(cmd_serState__d1),
    .des(inSta),
    .des_isReady(inSta_isReady),
    .des_canReceive(inSta_canReceive),
    .ser(outSta),
    .ser_isReady(outSta_isReady),
    .ser_canReceive(outSta_canReceive),
    .rst(rst),
    .clk(clk)
  );

  wire buff__cmd_canReceive;
  wire [`SHAKE128_R64*64-1:0] buff__buffer_read;
  wire [`SHAKE128_R64*64-1:0] buff__buffer_write;
  serdes #(`SHAKE128_R64) buff (
    .cmd_canReceive(buff__cmd_canReceive),
    .buffer_write(buff__buffer_write),
    .buffer_read(buff__buffer_read),
    .cmd_startSer(cmd_serBuf),
    .cmd_startDes(cmd_desBuf),
    .des(inBuf),
    .des_isReady(inBuf_isReady),
    .des_canReceive(inBuf_canReceive),
    .ser(outBuf),
    .ser_isReady(outBuf_isReady),
    .ser_canReceive(outBuf_canReceive),
    .rst(rst),
    .clk(clk)
  );

  wire [1600-1:0] core__in;
  wire [1600-1:0] core__out__d1;
  wire core__cmd_canReceive;
  keccak_iter core(
    .cmd_start(cmd_keccakStart),
    .cmd_continue(cmd_keccakContinue),
    .cmd_canReceive(core__cmd_canReceive),
    .isTransparent(isAnyState),
    .isTransparent_merge(cmd_serState),
    .in_data(core__in),
    .out_data__d1(core__out__d1),
    .rst(rst),
    .clk(clk)
  );

  wire cmd_desBuf__d1, isDesBuf__d;
  ff_en_next cmd_desBuf__ff1(cmd_any, cmd_desBuf, cmd_desBuf__d1, rst, clk);
  ff_en_imm cmd_desBuf__ff2(cmd_any, cmd_desBuf__d1, isDesBuf__d, rst, clk); // delay the cmd_desBuf of one block, and keep it active the whole block
  wire cmd_desBuf__d = isDesBuf__d & cmd_any; // delay the cmd_desBuf of one block

  wire [`SHAKE128_R64*64-1:0] buff__buffer;
  delay #(`SHAKE128_R64*64) buff__buffer__ff (buff__buffer_write, buff__buffer, rst, clk);
  assign buff__buffer_read = cmd_serBuf ? core__out__d1[`SHAKE128_R64*64-1:0] : buff__buffer;
  assign state__buffer_read = core__out__d1;

  assign core__in = cmd_desBuf__d ? { {1600-`SHAKE128_R64*64{1'b0}} , buff__buffer }
                  : isAnyState ? state__buffer_write
                  : 1600'b0;

  assign cmd_canReceive = (~isKeccakAny__d1 | core__cmd_canReceive)
                        & (~isAnyBuf__d1 | buff__cmd_canReceive)
                        & (~isAnyState__d1 | state__cmd_canReceive)
                        & (~isAnySer__d1 | outConv_canRestart);
endmodule


module keccak_planToFree #(parameter BUFF = 3) (
  input [BUFF-1:0] plan,
  output [BUFF-1:0] free
);
  wire [BUFF-1:0] anyThisOrAfterIsScheduled;
  genvar i;
  generate
    for (i = 0; i < BUFF; i=i+1) begin
      if(i == BUFF-1)
        assign anyThisOrAfterIsScheduled[i] = plan[i];
      else
        assign anyThisOrAfterIsScheduled[i] = plan[i] | anyThisOrAfterIsScheduled[i+1];
    end
  endgenerate
  
  assign free = ~anyThisOrAfterIsScheduled;
endmodule


module keccak_delayWithShift #(parameter BUFF = 3) (
  input doShift,
  input [BUFF-1:0] in,
  output [BUFF-1:0] out,
  input rst,
  input clk
);
  wire [BUFF-1:0] out__a1 = doShift ? in >> 1 : in;
  delay #(BUFF) d (out__a1, out, rst, clk);
endmodule

`define Keccak_BlockCounterSize  9


module keccak_ctrl #(parameter BUFF=3) (
  output in_cmd_canReceive,
  input in_cmd_isReady, // ready for a new command
  input in_cmd_is128else256,
  input in_cmd_inState, // before any inputs, input the keccak state
  input in_cmd_outState, // after any output, output the keccak state. the last I/O cycle is repeated, to allow the remeaning input/out to be used. If the input has not finished, it needs to be aligned to the data rate and have no isLast. There must be at least one full input cycle.
  input [`Keccak_BlockCounterSize-1:0] in_cmd_numInBlocks,
  input [`Keccak_BlockCounterSize-1:0] in_cmd_numOutBlocks,

  input out_cmd_canReceive,
  output out_cmd_des128,
  output out_cmd_des256,
  output out_cmd_desState,
  output out_cmd_ser128,
  output out_cmd_ser256,
  output out_cmd_serState,
  output out_cmd_keccakStart,
  output out_cmd_keccakContinue,

  input rst,
  input clk
);
  wire is128else256;
  ff_en_imm is128else256__ff(in_cmd_isReady, in_cmd_is128else256, is128else256, rst, clk);
  wire preventOverlapping;
  wire preventOverlapping__shouldSet = (in_cmd_numInBlocks == 0) & (in_cmd_numOutBlocks == 0) & ~in_cmd_inState & ~in_cmd_outState;
  ff_en_next preventOverlapping__ff(in_cmd_isReady, preventOverlapping__shouldSet, preventOverlapping, rst, clk);

  wire ignore1;
  wire firstK__reset, firstK;
  wire firstK__set = in_cmd_isReady & ~in_cmd_inState & (in_cmd_outState | (in_cmd_numInBlocks != 0) | (in_cmd_numOutBlocks != 0));
  ff_s_r firstK__ff(firstK__set, firstK__reset, firstK, ignore1, rst, clk);

  wire ignore2;
  wire inState__reset, inState;
  wire inState__set = in_cmd_isReady & in_cmd_inState;
  ff_s_r inState__ff(inState__set, inState__reset, inState, ignore2, rst, clk);
  wire inState__canNotRestart;
  ff_rs_next inState__canNotRestart__ff(inState__reset, inState__set, inState__canNotRestart, rst, clk);

  wire ignore3;
  wire outState__reset, outState;
  wire outState__set = in_cmd_isReady & in_cmd_outState;
  ff_s_r outState__ff(outState__set, outState__reset, outState, ignore3, rst, clk);
  wire outState__canNotRestart;
  ff_sr_next outState__canNotRestart__ff(outState__set, outState__reset, outState__canNotRestart, rst, clk);

  wire numInBlocks__isReady, numInBlocks__canRestart, numInBlocks__canReceive, numInBlocks__isLast;
  counter_bus #(`Keccak_BlockCounterSize) numInBlocks (
    .restart(in_cmd_isReady),
    .numSteps(in_cmd_numInBlocks),
    .canRestart(numInBlocks__canRestart),
    .canReceive(numInBlocks__canReceive),
    .canReceive_isLast(numInBlocks__isLast),
    .isReady(numInBlocks__isReady),
    .rst(rst),
    .clk(clk)
  );

  wire numOutBlocks__canReceive;
  wire numOutBlocks__canRestart, numOutBlocks__isReady;
  counter_bus #(`Keccak_BlockCounterSize) numOutBlocks (
    .restart(in_cmd_isReady),
    .numSteps(in_cmd_numOutBlocks),
    .canRestart(numOutBlocks__canRestart),
    .canReceive(numOutBlocks__canReceive),
    .isReady(numOutBlocks__isReady),
    .rst(rst),
    .clk(clk)
  );

  wire ignore4;
  wire postInState__reset, postInState; 
  wire postInState__set = in_cmd_isReady & in_cmd_inState;
  ff_s_r postInState__ff(postInState__set, postInState__reset, postInState, ignore4, rst, clk);

  wire anyPlanned__d1;
  assign in_cmd_canReceive = numInBlocks__canRestart & numOutBlocks__canRestart & ~inState__canNotRestart & ~outState__canNotRestart & (~preventOverlapping | ~anyPlanned__d1);
  
  wire [BUFF-1:0] plan_des128__d1;
  wire [BUFF-1:0] plan_des256__d1;
  wire [BUFF-1:0] plan_desState__d1;
  wire [BUFF-1:0] plan_ser128__d1;
  wire [BUFF-1:0] plan_ser256__d1;
  wire [BUFF-1:0] plan_serState__d1;
  wire [BUFF-1:0] plan_keccakStart__d1;
  wire [BUFF-1:0] plan_keccakContinue__d1;

  wire [BUFF-1:0] plan_desAny__d1 = plan_des128__d1 | plan_des256__d1 | plan_desState__d1;
  wire [BUFF-1:0] plan_keccakAny__d1 = plan_keccakStart__d1 | plan_keccakContinue__d1 | plan_desState__d1 | plan_serState__d1 | plan_desAny__d1;
  wire [BUFF-1:0] plan_serAny__d1 = plan_ser128__d1 | plan_ser256__d1 | plan_serState__d1 | plan_keccakAny__d1;
  assign anyPlanned__d1 = | (plan_desAny__d1 | plan_keccakAny__d1 | plan_serAny__d1);

  wire [BUFF-1:0] free_keccak__d1;
  wire [BUFF-1:0] free_des__d1;
  wire [BUFF-1:0] free_ser__d1;
  keccak_planToFree #(BUFF) p2f_doKeccak (plan_keccakAny__d1, free_keccak__d1);
  keccak_planToFree #(BUFF) p2f_doDes (plan_desAny__d1, free_des__d1);
  keccak_planToFree #(BUFF) p2f_doSer (plan_serAny__d1, free_ser__d1);


  wire des_doKeccak = ~numInBlocks__isLast & ~postInState;
  wire ser_doKeccak = ~postInState;

  wire [BUFF-1:0] free_desState__d1 = free_des__d1 & free_keccak__d1;
//wire [BUFF-1:0] free_desBlock__d1 = free_des__d1 & (des_doKeccak ? free_keccak__d1 >> 1 : {BUFF{1'b1}}); // TODO: this is an optimization that for some reason is not working, I'm not investing time in fixing it as we shouldn't really need it.
  wire [BUFF-1:0] free_desBlock__d1 = free_des__d1 & (free_keccak__d1 >> 1);
  wire [BUFF-1:0] free_serBlock__d1 = (ser_doKeccak ? free_keccak__d1 : {BUFF{1'b1}}) & (free_ser__d1 >> 1);
  wire [BUFF-1:0] free_serState__d1 = free_ser__d1 & free_keccak__d1;

  wire [BUFF-1:0] firstFree_desState__d1 = free_desState__d1 & ~(free_desState__d1 << 1);
  wire [BUFF-1:0] firstFree_desBlock__d1 = free_desBlock__d1 & ~(free_desBlock__d1 << 1);
  wire [BUFF-1:0] firstFree_serBlock__d1 = free_serBlock__d1 & ~(free_serBlock__d1 << 1);
  wire [BUFF-1:0] firstFree_serState__d1 = free_serState__d1 & ~(free_serState__d1 << 1);

  assign inState__reset        = inState                  & |free_desState__d1;
  assign numInBlocks__isReady  = numInBlocks__canReceive  & ~inState & |free_desBlock__d1;
  assign numOutBlocks__isReady = numOutBlocks__canReceive & ~inState & ~numInBlocks__canReceive & |free_serBlock__d1;
  assign outState__reset       = outState                 & ~inState & ~numInBlocks__canReceive & ~numOutBlocks__canReceive & |free_serState__d1;
  assign firstK__reset         = numInBlocks__isReady & ~numInBlocks__isLast | numOutBlocks__isReady | outState__reset; // the first execution of the keccak for a single block of input is skeduled with the next (either generation of the output or the output of the state)
  assign postInState__reset    = numInBlocks__isReady | numOutBlocks__isReady | outState__reset;


  wor [BUFF-1:0] plan_des128 = plan_des128__d1;
  wor [BUFF-1:0] plan_des256 = plan_des256__d1;
  wor [BUFF-1:0] plan_desState = plan_desState__d1;
  wor [BUFF-1:0] plan_ser128 = plan_ser128__d1;
  wor [BUFF-1:0] plan_ser256 = plan_ser256__d1;
  wor [BUFF-1:0] plan_serState = plan_serState__d1;
  wor [BUFF-1:0] plan_keccakStart = plan_keccakStart__d1;
  wor [BUFF-1:0] plan_keccakContinue = plan_keccakContinue__d1;

  assign plan_desState = plan_desState__d1
                       | (inState__reset                        ? firstFree_desState__d1      : {BUFF{1'b0}});
  assign plan_des128   = plan_des128__d1
                       | (numInBlocks__isReady  &  is128else256 ? firstFree_desBlock__d1      : {BUFF{1'b0}});
  assign plan_des256   = plan_des256__d1
                       | (numInBlocks__isReady  & ~is128else256 ? firstFree_desBlock__d1      : {BUFF{1'b0}});
  assign plan_ser128   = plan_ser128__d1
                       | (numOutBlocks__isReady &  is128else256 ? firstFree_serBlock__d1 << 1 : {BUFF{1'b0}});
  assign plan_ser256   = plan_ser256__d1
                       | (numOutBlocks__isReady & ~is128else256 ? firstFree_serBlock__d1 << 1 : {BUFF{1'b0}});
  assign plan_serState = plan_serState__d1
                       | (outState__reset                       ? firstFree_serState__d1      : {BUFF{1'b0}});
  wire [BUFF-1:0] addPlan_keccakAny = (numInBlocks__isReady  & des_doKeccak ? firstFree_desBlock__d1 << 1 : {BUFF{1'b0}})
                                    | (numOutBlocks__isReady & ser_doKeccak ? firstFree_serBlock__d1      : {BUFF{1'b0}})
                                    | (outState__reset                      ? firstFree_serState__d1      : {BUFF{1'b0}});  // it doesn't actually run keccak, it serves to tell it how to merge the previous state with the input/output if any.
  assign plan_keccakStart    = plan_keccakStart__d1 | (firstK ? addPlan_keccakAny : {BUFF{1'b0}});
  assign plan_keccakContinue = plan_keccakContinue__d1 | (~firstK ? addPlan_keccakAny : {BUFF{1'b0}});
  
  assign out_cmd_des128 = out_cmd_canReceive & plan_des128[0];
  assign out_cmd_des256 = out_cmd_canReceive & plan_des256[0];
  assign out_cmd_desState = out_cmd_canReceive & plan_desState[0];
  assign out_cmd_ser128 = out_cmd_canReceive & plan_ser128[0];
  assign out_cmd_ser256 = out_cmd_canReceive & plan_ser256[0];
  assign out_cmd_serState = out_cmd_canReceive & plan_serState[0];
  assign out_cmd_keccakStart = out_cmd_canReceive & plan_keccakStart[0];
  assign out_cmd_keccakContinue = out_cmd_canReceive & plan_keccakContinue[0];

  keccak_delayWithShift #(BUFF) dws_des128 (out_cmd_canReceive, plan_des128, plan_des128__d1, rst, clk);
  keccak_delayWithShift #(BUFF) dws_des256 (out_cmd_canReceive, plan_des256, plan_des256__d1, rst, clk);
  keccak_delayWithShift #(BUFF) dws_desState (out_cmd_canReceive, plan_desState, plan_desState__d1, rst, clk);
  keccak_delayWithShift #(BUFF) dws_ser128 (out_cmd_canReceive, plan_ser128, plan_ser128__d1, rst, clk);
  keccak_delayWithShift #(BUFF) dws_ser256 (out_cmd_canReceive, plan_ser256, plan_ser256__d1, rst, clk);
  keccak_delayWithShift #(BUFF) dws_serState (out_cmd_canReceive, plan_serState, plan_serState__d1, rst, clk);
  keccak_delayWithShift #(BUFF) dws_keccakStart (out_cmd_canReceive, plan_keccakStart, plan_keccakStart__d1, rst, clk);
  keccak_delayWithShift #(BUFF) dws_keccakContinue (out_cmd_canReceive, plan_keccakContinue, plan_keccakContinue__d1, rst, clk);
endmodule

`define KeccakCMD_SIZE  (3+2*`Keccak_BlockCounterSize)


module keccak(
    input [`KeccakCMD_SIZE-1:0] cmd, // { is128else256: 1bit, inState:1bit, outState:1bit, numInBlocks:9bits, numOutBlocks:9bits }
    input cmd_isReady,
    output cmd_canReceive,

    input [64-1:0] in,
    input in_isSingleByte, // if inState, this must be false
    input in_isLast, // if outState and no out, the size of the input data must be a multiple of the rate, and this must not be set.
    input in_isReady,
    output in_canReceive,

    output [64-1:0] out,
    output out_isReady,
    input out_canReceive,
    input out_isLast,

    input rst,
    input clk
  );
  wire rst__d1;
  delay rst__ff (rst, rst__d1, 1'b0, clk);

  wire c__canReceive;
  wire c__des128;
  wire c__des256;
  wire c__desState;
  wire c__ser128;
  wire c__ser256;
  wire c__serState;
  wire c__keccakStart;
  wire c__keccakContinue;
  keccak_ctrl ctrl(
    .in_cmd_canReceive(cmd_canReceive),
    .in_cmd_isReady(cmd_isReady),
    .in_cmd_is128else256(cmd[2+2*`Keccak_BlockCounterSize]),
    .in_cmd_inState(cmd[1+2*`Keccak_BlockCounterSize]), // before any inputs, input the full keccak state
    .in_cmd_outState(cmd[0+2*`Keccak_BlockCounterSize]),// after any output, output the full keccak state
    .in_cmd_numInBlocks(cmd[`Keccak_BlockCounterSize+:`Keccak_BlockCounterSize]),
    .in_cmd_numOutBlocks(cmd[0+:`Keccak_BlockCounterSize]),
    .out_cmd_canReceive(c__canReceive),
    .out_cmd_des128(c__des128),
    .out_cmd_des256(c__des256),
    .out_cmd_desState(c__desState),
    .out_cmd_ser128(c__ser128),
    .out_cmd_ser256(c__ser256),
    .out_cmd_serState(c__serState),
    .out_cmd_keccakStart(c__keccakStart),
    .out_cmd_keccakContinue(c__keccakContinue),
    .rst(rst__d1),
    .clk(clk)
  );
  wire c__isReady = c__des128 | c__des256 | c__desState | c__ser128 | c__ser256 | c__serState | c__keccakStart | c__keccakContinue;

  wire d__isReady;
  wire d__canReceive;
  wire [8-1:0] d;
  bus_delay_std #(.BusSize(8), .N(1)) cmdDelay (
    .i({c__des128, c__des256, c__desState, c__ser128, c__ser256, c__serState, c__keccakStart, c__keccakContinue}),
    .i_isReady(c__isReady),
    .i_canReceive(c__canReceive),
    .o(d),
    .o_isReady(d__isReady),
    .o_canReceive(d__canReceive),
    .rst(rst__d1),
    .clk(clk)
  );

  wire d__des128;
  wire d__des256;
  wire d__desState;
  wire d__ser128;
  wire d__ser256;
  wire d__serState;
  wire d__keccakStart;
  wire d__keccakContinue;
  assign {d__des128, d__des256, d__desState, d__ser128, d__ser256, d__serState, d__keccakStart, d__keccakContinue} = d & {8{d__isReady}};

  keccak_block block(
    .cmd_canReceive(d__canReceive),
    .cmd_des128(d__des128),
    .cmd_des256(d__des256),
    .cmd_desState(d__desState),
    .cmd_ser128(d__ser128),
    .cmd_ser256(d__ser256),
    .cmd_serState(d__serState),
    .cmd_keccakStart(d__keccakStart),
    .cmd_keccakContinue(d__keccakContinue),
    .in(in),
    .in_isSingleByte(in_isSingleByte),
    .in_isReady(in_isReady),
    .in_isLast(in_isLast),
    .in_canReceive(in_canReceive),
    .out(out),
    .out_isReady(out_isReady),
    .out_canReceive(out_canReceive),
    .out_isLast(out_isLast),
    .rst(rst__d1),
    .clk(clk)
  );
endmodule


`endif // KECCAK_V

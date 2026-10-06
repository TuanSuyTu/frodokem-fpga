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


`ifndef FRODOMUL_V
`define FRODOMUL_V


// This file provides the module: frodoMul
// It contains the module to do the multiplication.
// it has two configurations of how to use the multipliers:
//   mul1: *'  outVec = accVec + \sum_i sMat_i * a_i
//   mul2: *"  outMat_i = accMat_i + sCol * a_i.


`include "lib.v"


module frodoMulSingle(
    input [5-1:0] s,
    input [16-1:0] a,
    output [16-1:0] z
  );

  wire [16-1:0] r = (s[1] ? a << 0 : 16'b0)
                  + (s[2] ? a << 1 : 16'b0)
                  + (s[3] ? a << 2 : 16'b0)
                  + (s[4] ? a << 3 : 16'b0);

  assign z = s[0] ? -r : r;
endmodule


module frodoMul #(
    parameter A=4,
    parameter S=8
  )(
    input [16*A-1:0] a, // 16b1x4 | 16b4x1
    input [16*S-1:0] accVec, // 16b8x1
    input [5*S-1:0] sCol, // 5b8x1
    input [5*A*S-1:0] sMat, // 5b8x4
    input [16*A*S-1:0] accMat, // 16b8x4
    output [16*A*S-1:0] outMat, // 16b8x4
    output [16*S-1:0] outVec, // 16b8x1

    input isMatrixMul1,
    input isPos,
// tt:  outVec = accVec + sMat * a
// tf:  outVec = accVec - sMat * a
// ft:  outMat = accMat + sCol * a
// ff:  outMat = accMat - sCol * a
    input setStorage, // store either accVec or sCol
    input doOp,
    
    input rst,
    input clk
  );
  genvar j;
  genvar i;

  wire  [16*S-1:0] state; // 5b or 16b vals that are 16b aligned
  wire  [16*S-1:0] state__init;
  wire  [16*S-1:0] state__new;
  wire  [16*S-1:0] state__a1 = setStorage          ? state__init
                             : doOp & isMatrixMul1 ? state__new
                                                   : state;
  delay #(16*S) state__ff (state__a1, state, rst, clk);

  generate
    for (j = 0; j < S; j=j+1) begin
      assign state__init[j*16+:16] = isMatrixMul1 ? accVec[j*16+:16] : {11'b0, sCol[j*5+:5]};
    end
  endgenerate

  wire [5*A*S-1:0] mul_op1; // b5 mul_op1[S][A]
  wire [16*A-1:0] mul_op2 = a;
  wire [16*A*S-1:0] mul_out;

  wire [5-1:0] optionalSignInverter = {4'b0, ~isPos};

  generate
    for (j = 0; j < S; j=j+1) begin
      for (i = 0; i < A; i=i+1) begin
        assign mul_op1[(j*A+i)*5+:5] = (isMatrixMul1 ? sMat[(j*A+i)*5+:5] : state[j*16+:5]) ^ optionalSignInverter;
        frodoMulSingle mul(mul_op1[(j*A+i)*5+:5], mul_op2[i*16+:16], mul_out[(j*A+i)*16+:16]);
      end
    end
  endgenerate


  wire [16*(A+1)*S-1:0] partSum;

  generate
    for (j = 0; j < S; j=j+1) begin
      assign partSum [j*(A+1)*16+:16] = state[j*16+:16];

      for (i = 0; i < A; i=i+1) begin
        assign partSum [j*(A+1)*16 + (i+1)*16+:16] = ( isMatrixMul1 ? partSum[j*(A+1)*16 + i*16+:16] : accMat[j*A*16 + i*16+:16] ) + mul_out[j*A*16 + i*16+:16];
      end

      assign state__new [j*16+:16] = partSum[j*(A+1)*16 + A*16+:16];

      assign outVec [j*16+:16] = state[j*16+:16];
      for (i = 0; i < A; i=i+1) begin
        assign outMat [(j*A+i)*16+:16] = partSum [(j*(A+1)+i+1)*16+:16];
      end
    end
  endgenerate
endmodule


`endif // FRODOMUL_V

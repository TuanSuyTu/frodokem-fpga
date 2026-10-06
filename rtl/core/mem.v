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


`ifndef MEM_V
`define MEM_V


// This file provides the module: mainMem
// It allows to select which value to read/write, which index, which bus size... and it carries out the operation


`include "lib.v"


// module's sizes configuration.
`define MemCONF_matrixNumBlocks_size 8
`define MemCONF_lenSec_size 3
`define MemCONF_lenSE_size 3
`define MemCONF_lenSalt_size 3


// verilog module describing a Xilinx BRAM
module bram(
  input doRead,
  input [9-1:0] read_index, // 512 values
  output [64-1:0] read_value__d2,

  input doWrite,
  input [8-1:0] write_byteEnable,
  input [9-1:0] write_index,
  input [64-1:0] write_value,

  input clk
);
  reg [64-1:0] mem [512-1:0];
  reg [64-1:0] out__d1;
  reg [64-1:0] out__d2;

  always @ (posedge clk) if(doWrite) begin
    if(write_byteEnable[0]) mem[write_index][0*8+:8] <= write_value[0*8+:8];
    if(write_byteEnable[1]) mem[write_index][1*8+:8] <= write_value[1*8+:8];
    if(write_byteEnable[2]) mem[write_index][2*8+:8] <= write_value[2*8+:8];
    if(write_byteEnable[3]) mem[write_index][3*8+:8] <= write_value[3*8+:8];
    if(write_byteEnable[4]) mem[write_index][4*8+:8] <= write_value[4*8+:8];
    if(write_byteEnable[5]) mem[write_index][5*8+:8] <= write_value[5*8+:8];
    if(write_byteEnable[6]) mem[write_index][6*8+:8] <= write_value[6*8+:8];
    if(write_byteEnable[7]) mem[write_index][7*8+:8] <= write_value[7*8+:8];
  end
  
  always @ (posedge clk) if(doRead)
    out__d1 <= mem[read_index];

  always @ (posedge clk)
    out__d2 <= out__d1;

  assign read_value__d2 = out__d2;
endmodule

// two ports: Read, Write
module bram8(
  input [9-1:0] r_index, // 512 values
  input [8*8-1:0] r_enable,
  input [8-1:0] r_fromNextIndex, // if selected, the BRAM's index is the next one
  output [64*8-1:0] r_value__d2,

  input [9-1:0] w_index,
  input [8*8-1:0] w_enable,
  input [64*8-1:0] w_value,

  input rst,
  input clk
);
  genvar col;
  genvar row;

  wire [8*8-1:0] r_enable__d1;
  delay #(8*8) r_enable__ff1 (r_enable, r_enable__d1, rst, clk);
  wire [8*8-1:0] r_enable__d2;
  delay #(8*8) r_enable__ff2 (r_enable__d1, r_enable__d2, rst, clk);

  wire [8-1:0] r_bramEnable;
  wire [8-1:0] w_bramEnable;

  wire [9*8-1:0] r_indexes;
  wire [64*8-1:0] r_rawValue__d2;
  generate
    for (row = 0; row < 8; row=row+1) begin
      assign r_indexes[row*9+:9] = r_fromNextIndex[row] ? r_index + 1 : r_index;
      assign r_bramEnable[row] = | r_enable[row*8+:8];
      assign w_bramEnable[row] = | w_enable[row*8+:8];
      
      bram mem(
        .doRead(r_bramEnable[row]),
        .read_index(r_indexes[row*9+:9]),
        .read_value__d2(r_rawValue__d2[row*64+:64]),
        .doWrite(w_bramEnable[row]),
        .write_byteEnable(w_enable[row*8+:8]),
        .write_index(w_index),
        .write_value(w_value[row*64+:64]),
        .clk(clk)
      );

      for (col = 0; col < 8; col=col+1) begin
        assign r_value__d2[row*64+col*8+:8] = r_rawValue__d2[row*64+col*8+:8] & {8{ r_enable__d2[row*8+col] }};
      end
    end
  endgenerate
endmodule


module mem_elementIndexToByteEnable(
  input [2-1:0] elemIndex,
  output [8-1:0] byteEnable
);
  genvar i;
  generate
    for (i = 0; i < 8; i=i+1) begin
      assign byteEnable[i] = elemIndex == (i >> 1);
    end
  endgenerate
endmodule


module mem_byteIndexToByteEnable(
  input [3-1:0] byteIndex,
  output [8-1:0] byteEnable
);
  genvar i;
  generate
    for (i = 0; i < 8; i=i+1) begin
      assign byteEnable[i] = byteIndex == i;
    end
  endgenerate
endmodule


// offsets of the various elements stored in the brams.
`define MainMem_OFF_SSState	9'd0
`define MainMem_OFF_C		(`MainMem_OFF_SSState + 9'd4)
`define MainMem_OFF_RNGState	(`MainMem_OFF_C + 9'd2)
`define MainMem_OFF_salt	(`MainMem_OFF_RNGState + 9'd1)
`define MainMem_OFF_seedSE	(`MainMem_OFF_salt + 9'd1)
`define MainMem_OFF_pkh		(`MainMem_OFF_seedSE + 9'd1)
`define MainMem_OFF_U		(`MainMem_OFF_pkh + 9'd1)
`define MainMem_OFF_k		(`MainMem_OFF_U + 9'd1)
`define MainMem_OFF_B		(`MainMem_OFF_k + 9'd1)
`define MainMem_OFF_S		(`MainMem_OFF_B + 9'd336)


module mainMem_readConnector(
    input [14-1:0] i_index,
    output [14-1:0] i_index_next,
    output i_index_hasNext,

    input i_bus_B_row, // row first, 16b1x4
    input i_bus_B_col, // col first, 16b4x1
    input i_bus_C_row, // row first, 16b1x4
    input i_bus_SSState, // 64b
    input i_bus_RNGState, // 64b
    input i_bus_salt, // 64b
    input i_bus_seedSE, // 64b
    input i_bus_pkh, // 64b
    input i_bus_k, // 64b
    input i_bus_u, // 64b
    input i_bus_S_row_DBG, // row first, the internal encoding of 5b1x4
    output [16*4-1:0] i_bus__d2,

    input i_dubBus_B_col, // 16b8x1
    input i_dubBus_C_col, // 16b8x1
    input i_dubBus_C_row, // 16b1x8
    output [16*8-1:0] i_dubBus__d2,

    input i_paralSBus_S_mat, // 5b8x4
    output [5*4*8-1:0] i_paralSBus__d2,

    input i_paral_B_mat, // 16b8x4
    input i_paral_C_mat, // 16b8x4
    output [16*4*8-1:0] i_paral__d2,

    input i_SBus_S_col, // 5b8x1.
    output [5*8-1:0] i_SBus__d2,

    input i_quarterBus_U_halfRow, // 2b1x4, 3b1x4, 4b1x4, each value 4 bit aligned
    output [4*4-1:0] i_quarterBus__d2,

    output [9-1:0] o_index, // 512 values
    output [8*8-1:0] o_enable,
    output [8-1:0] o_fromNextIndex, // if selected, the BRAM's index is the next one
    input [64*8-1:0] o_value__d2,

    input [9-1:0] config_matrixNumCellsMin1, // how many 8x4 matrixes are in B and S minus 1. The FrodoKEM parameter/4-1.
    input [14-1:0] config_matrixNumCellsTimes8Min1, // how many 1x4 matrixes are in B and S minus 1. The FrodoKEM parameter*2-1.
    input [14-1:0] config_matrixNumCellsTimes4Min1, // how many 8x1 matrixes are in B and S minus 1. The FrodoKEM parameter-1.
    input config_SUseHalfByte,
    input [`MemCONF_lenSec_size-1:0] config_lenSec,
    input [14-1:0] config_lenSecMin1,
    input [14-1:0] config_lenSEMin1,
    input [14-1:0] config_lenSaltMin1,

    input rst,
    input clk
);
  wire [8-1:0] o_bramEnable;
  wire [8-1:0] o_byteEnable;
  wor [8*8-1:0] o_enable__w;

  genvar col;
  genvar row;
  generate
    for (col = 0; col < 8; col=col+1) begin
      for (row = 0; row < 8; row=row+1) begin
        assign o_enable__w[col*8+row] = o_bramEnable[col] & o_byteEnable[row];
      end
    end
  endgenerate
  assign o_enable = o_enable__w;


  wire [9-1:0] column_offset = (i_bus_B_row | i_bus_B_col | i_dubBus_B_col | i_paral_B_mat) ? `MainMem_OFF_B : 9'd0
                             | (i_bus_S_row_DBG | i_paralSBus_S_mat | i_SBus_S_col) ? `MainMem_OFF_S : 9'd0
                             | i_bus_SSState ? `MainMem_OFF_SSState : 9'd0
                             | (i_bus_C_row | i_dubBus_C_col | i_dubBus_C_row | i_paral_C_mat) ? `MainMem_OFF_C : 9'd0
                             | i_bus_RNGState ? `MainMem_OFF_RNGState : 9'd0
                             | i_bus_salt ? `MainMem_OFF_salt : 9'd0
                             | i_bus_seedSE ? `MainMem_OFF_seedSE : 9'd0
                             | i_bus_pkh ? `MainMem_OFF_pkh : 9'd0
                             | (i_bus_u | i_quarterBus_U_halfRow) ? `MainMem_OFF_U : 9'd0
                             | i_bus_k ? `MainMem_OFF_k : 9'd0;

  assign i_index_next = ((i_bus_B_row | i_bus_S_row_DBG) & (i_index[0+:9] == config_matrixNumCellsMin1)) ? { i_index[14-1:9] + 5'd1, 9'b0 }
                                                                                                         : i_index + 14'd1;

  assign i_index_hasNext = ((i_bus_B_row | i_bus_S_row_DBG) ? i_index != {5'd7, config_matrixNumCellsMin1} : 1'b0)
                         | (i_bus_B_col ? i_index != config_matrixNumCellsTimes8Min1 : 1'b0) 
                         | ((i_bus_C_row | i_quarterBus_U_halfRow) ? i_index != 14'd15 : 1'b0) 
                         | (i_bus_SSState ? i_index != 14'd24 : 1'b0) 
                         | (i_bus_RNGState ? i_index != 14'd7 : 1'b0) 
                         | (i_bus_salt ? i_index != config_lenSaltMin1 : 1'b0)
                         | (i_bus_seedSE ? i_index != config_lenSEMin1 : 1'b0)
                         | (i_bus_pkh ? i_index != config_lenSecMin1 : 1'b0)
                         | (i_bus_k ? i_index != config_lenSecMin1 : 1'b0)
                         | ((i_dubBus_B_col | i_SBus_S_col) ? i_index != config_matrixNumCellsTimes4Min1 : 1'b0)
                         | ((i_dubBus_C_col | i_dubBus_C_row) ? i_index != 14'd7 : 1'b0)
                         | (i_bus_u ? i_index != config_lenSecMin1 : 1'b0) 
                         | (i_paral_C_mat ? i_index != 14'd1 : 1'b0)
                         | ((i_paral_B_mat | i_paralSBus_S_mat) ? i_index != {5'd0, config_matrixNumCellsMin1} : 1'b0);


  wire i_bus_anyCell = i_bus_SSState
                     | i_bus_RNGState
                     | i_bus_salt
                     | i_bus_seedSE
                     | i_bus_pkh
                     | i_bus_k
                     | i_bus_u;

  wire i_dubBus_anyCol = i_dubBus_C_col
                       | i_dubBus_B_col
                       | i_paralSBus_S_mat & config_SUseHalfByte
                       | i_bus_S_row_DBG & config_SUseHalfByte;

  wire i_dubBus_anyTwoCol = i_paralSBus_S_mat & ~config_SUseHalfByte
                          | i_bus_S_row_DBG & ~config_SUseHalfByte;

  wire [9-1:0] unoff_index_col = (i_bus_B_row | i_paral_B_mat | i_paral_C_mat) ? i_index[0+:9] : 9'b0
                               | i_bus_C_row ? {8'b0, i_index[0+:1]} : 9'b0
                               | i_dubBus_anyCol ? (i_bus_S_row_DBG ? {2'b0, i_index[2+:7]} : i_index[2+:9]) : 9'b0
                               | i_dubBus_anyTwoCol ? (i_bus_S_row_DBG ? {1'b0, i_index[1+:8]} : i_index[1+:9]) : 9'b0
                               | (i_bus_B_col | i_bus_anyCell) ? i_index[3+:9] : 9'b0
                               | (i_SBus_S_col & config_SUseHalfByte) ? i_index[4+:9] : 9'b0
                               | (i_SBus_S_col & ~config_SUseHalfByte) ? i_index[3+:9] : 9'b0;

  assign o_index = unoff_index_col + column_offset;


  wire [2-1:0] o_byteEnable_elemIndex = (i_dubBus_anyCol ? i_index[0+:2] : 2'b0)
                                      | (i_bus_B_col ? i_index[1+:2] : 2'b0);
  wire [8-1:0] o_byteEnable_elem;
  mem_elementIndexToByteEnable o_byteEnable_elem__c (o_byteEnable_elemIndex, o_byteEnable_elem);
  
  wire [3-1:0] o_byteEnable_byteIndex = (i_SBus_S_col & config_SUseHalfByte) ? i_index[1+:3] : 3'b0
                                      | (i_SBus_S_col & ~config_SUseHalfByte) ? i_index[0+:3] : 3'b0;
  wire [8-1:0] o_byteEnable_byte;
  mem_byteIndexToByteEnable o_byteEnable_byte__c (o_byteEnable_byteIndex, o_byteEnable_byte);

  assign o_byteEnable = (i_bus_B_row | i_bus_C_row | i_paral_B_mat | i_paral_C_mat | i_bus_anyCell | i_dubBus_C_row) ? 8'hFF : 8'b0
                      | (i_dubBus_anyCol | i_bus_B_col) ? o_byteEnable_elem : 8'b0
                      | i_dubBus_anyTwoCol ? (i_index[0] == 1'b0 ? 8'h0F : 8'hF0) : 8'b0
                      | i_SBus_S_col ? o_byteEnable_byte : 8'b0;


  wire [2-1:0] o_bramEnable_elemIndex = (i_dubBus_C_row ? i_index[1+:2] : 2'b0);
  wire [8-1:0] o_bramEnable_elem;
  mem_elementIndexToByteEnable o_bramEnable_elem__c (o_bramEnable_elemIndex, o_bramEnable_elem);
  
  wire [3-1:0] o_bramEnable_byteIndex = ((i_bus_B_row | i_bus_S_row_DBG) ? i_index[9+:3] : 3'b0)
                                      | (i_bus_C_row ? (i_index[1+:3] ^ {2'b0, i_index[0]}) : 3'b0)
                                      | (i_bus_anyCell ? i_index[0+:3] : 3'b0);
  wire [8-1:0] o_bramEnable_byte;
  mem_byteIndexToByteEnable o_bramEnable_byte__c (o_bramEnable_byteIndex, o_bramEnable_byte);

  assign o_bramEnable = (i_SBus_S_col | i_dubBus_B_col | i_dubBus_C_col | i_paralSBus_S_mat | i_paral_B_mat | i_paral_C_mat) ? 8'b11111111 : 8'b0
                      | i_bus_B_col ? (i_index[0] == 1'b0 ? 8'b00001111 : 8'b11110000) : 8'b0
                      | i_dubBus_C_row ? o_bramEnable_elem : 8'b0
                      | (i_bus_B_row | i_bus_C_row | i_bus_anyCell | i_bus_S_row_DBG) ? o_bramEnable_byte : 8'b0;

  assign o_fromNextIndex = {8{i_dubBus_C_row}} & {4{ {~i_index[0], i_index[0]} }};

  assign o_enable__w = i_quarterBus_U_halfRow & config_lenSec[0] ? ( 64'b1 << (i_index) ) : 0;
  assign o_enable__w = i_quarterBus_U_halfRow & config_lenSec[1] ? (i_index[0] == 0 ? 64'b011 : 64'b110) << (3*i_index[1+:3]) : 0;
  assign o_enable__w = i_quarterBus_U_halfRow & config_lenSec[2] ? ( 64'b11 << (2*i_index) ) : 0;


  wire [64*8-1:0] o_value_swapped__d2;
  generate
    for (row = 0; row < 8; row=row+1) begin
      assign o_value_swapped__d2[row*64+:64] = o_value__d2[(row^1)*64+:64];
    end
  endgenerate

  wor [32*8-1:0] mergeTwoCol__d2;
  wor [16*8-1:0] mergeCol__d2;
  wire [16*8-1:0] mergeCol_swapped__d2; // swap following pairs of rows in the column
  wor [16*4*2-1:0] mergeTwoRows__d2;
  generate
    for (row = 0; row < 8; row=row+1) begin
      assign mergeTwoCol__d2[row*32+:32] = o_value__d2[row*64+:32] | o_value__d2[row*64+32+:32];
      assign mergeCol__d2[row*16+:16] = mergeTwoCol__d2[row*32+:16] | mergeTwoCol__d2[row*32+16+:16];
      assign mergeCol_swapped__d2[row*16+:16] = mergeCol__d2[(row^1)*16+:16];
    end

    for (row = 0; row < 4; row=row+1) begin
      assign mergeTwoRows__d2 = o_value__d2[row*128+:128];
    end
  endgenerate

  wire i_dubBus_C_row__d1;
  delay i_dubBus_C_row__ff1 (i_dubBus_C_row, i_dubBus_C_row__d1, rst, clk);
  wire i_dubBus_C_row__d2;
  delay i_dubBus_C_row__ff2 (i_dubBus_C_row__d1, i_dubBus_C_row__d2, rst, clk);
  wire i_dubBus_C_col__d1;
  delay i_dubBus_C_col__ff1 (i_dubBus_C_col, i_dubBus_C_col__d1, rst, clk);
  wire i_dubBus_C_col__d2;
  delay i_dubBus_C_col__ff2 (i_dubBus_C_col__d1, i_dubBus_C_col__d2, rst, clk);
  wire i_paral_C_mat__d1;
  delay i_paral_C_mat__ff1 (i_paral_C_mat, i_paral_C_mat__d1, rst, clk);
  wire i_paral_C_mat__d2;
  delay i_paral_C_mat__ff2 (i_paral_C_mat__d1, i_paral_C_mat__d2, rst, clk);
  
  wire i_index__d1__0;
  wire i_index__d1__2;
  delay i_index__ff1__0 (i_index[0], i_index__d1__0, rst, clk);
  delay i_index__ff1__2 (i_index[2], i_index__d1__2, rst, clk);
  wire i_index__d2__0;
  wire i_index__d2__2;
  delay i_index__ff2__0 (i_index__d1__0, i_index__d2__0, rst, clk);
  delay i_index__ff2__2 (i_index__d1__2, i_index__d2__2, rst, clk);

  assign i_paral__d2 = (i_paral_C_mat__d2 & i_index__d2__0) ? o_value_swapped__d2 : o_value__d2;

  assign i_dubBus__d2 = i_dubBus_C_row__d2 & ~i_index__d2__0 ? mergeTwoRows__d2
                      : i_dubBus_C_row__d2                   ? {mergeTwoRows__d2[0+:64], mergeTwoRows__d2[64+:64]}
                      : i_dubBus_C_col__d2 &  i_index__d2__2 ? mergeCol_swapped__d2
                                                             : mergeCol__d2;

  generate
    for (row = 0; row < 8; row=row+1) begin
      for (col = 0; col < 4; col=col+1) begin
        assign i_paralSBus__d2[row*20+col*5+:5] = config_SUseHalfByte ? mergeCol__d2[row*16+col*4+:4] : mergeTwoCol__d2[row*32+col*8+:5];
      end
    end
  endgenerate

  wire i_bus_B_col__d1;
  delay i_bus_B_col__ff1 (i_bus_B_col, i_bus_B_col__d1, rst, clk);
  wire i_bus_B_col__d2;
  delay i_bus_B_col__ff2 (i_bus_B_col__d1, i_bus_B_col__d2, rst, clk);
  wire [64-1:0] mergeRow__d2 = mergeTwoRows__d2[0+:64] | mergeTwoRows__d2[64+:64];
  wire [32-1:0] mergeHalfRow__d2 = mergeRow__d2[0+:32] | mergeRow__d2[32+:32];
  wire [16-1:0] mergeQuarterRow__d2 = mergeHalfRow__d2[0+:16] | mergeHalfRow__d2[16+:16];
  wire [8-1:0] mergeEighthRow__d2 = mergeQuarterRow__d2[0+:8] | mergeQuarterRow__d2[8+:8];

  wor [24-1:0] mergeMul3B__d2;
  generate
    for (row = 0; row < 8; row=row+1) begin
      assign mergeMul3B__d2 = o_value__d2[row*24+:24];
    end
  endgenerate
  wire [12-1:0] mergeMul3B_half__d2 = mergeMul3B__d2[(i_index__d2__0 == 0 ? 0 : 12) +:12];

  generate
    for (row = 0; row < 4; row=row+1) begin
      assign i_quarterBus__d2[row*4+:4] = config_lenSec[2] ? mergeQuarterRow__d2[row*4+:4] : 4'b0
                                        | config_lenSec[1] ? {1'b0, mergeMul3B_half__d2[row*3+:3]} : 16'b0
                                        | config_lenSec[0] ? {2'b0, mergeEighthRow__d2[row*2+:2]} : 16'b0;
    end
  endgenerate

  wire i_bus_S_row_DBG__d1;
  delay i_bus_S_row_DBG__ff1 (i_bus_S_row_DBG, i_bus_S_row_DBG__d1, rst, clk);
  wire i_bus_S_row_DBG__d2;
  delay i_bus_S_row_DBG__ff2 (i_bus_S_row_DBG__d1, i_bus_S_row_DBG__d2, rst, clk);
  assign i_bus__d2 = i_bus_B_col__d2     ? (mergeCol__d2[0+:16*4] | mergeCol__d2[16*4+:16*4])
                   : i_bus_S_row_DBG__d2 ? config_SUseHalfByte ? mergeQuarterRow__d2
                                                               : mergeHalfRow__d2
                                         : mergeRow__d2;

  wire i_SBus_shift__d2 = i_index__d2__0;
  wire [8*8-1:0] mergeByteCol__d2;
  generate
    for (row = 0; row < 8; row=row+1) begin
      assign mergeByteCol__d2[row*8+:8] = mergeCol__d2[row*16+:8] | mergeCol__d2[row*16+8+:8];
      assign i_SBus__d2[row*5+:5] = config_SUseHalfByte ? mergeByteCol__d2[row*8+i_SBus_shift__d2*4+:4] : mergeByteCol__d2[row*8+:5];
    end
  endgenerate
endmodule


module stdToCompact_single(
    input [16-1:0] in,
    output [4-1:0] out4,
    output [8-1:0] out8
);
  wire isNeg = in[15];
  wire ignore = | in[14:4];
  
  assign out8[7:5] = 0;
  assign out8[4:1] = isNeg ? -in[3:0] : in[3:0];
  assign out8[0] = isNeg;
  
  assign out4 = out8[0+:4];
endmodule


module stdToCompact(
    input config_SUseHalfByte,
    input [64-1:0] in,
    output [32-1:0] out
  );

  wire [4*4-1:0] out4;
  wire [8*4-1:0] out8;

  stdToCompact_single s0(in[16*0+:16], out4[4*0+:4], out8[8*0+:8]);
  stdToCompact_single s1(in[16*1+:16], out4[4*1+:4], out8[8*1+:8]);
  stdToCompact_single s2(in[16*2+:16], out4[4*2+:4], out8[8*2+:8]);
  stdToCompact_single s3(in[16*3+:16], out4[4*3+:4], out8[8*3+:8]);
  
  assign out = config_SUseHalfByte ? { out4, out4 } : out8;
endmodule



module mainMem_writeConnector(
    input [14-1:0] i_index,
    output [14-1:0] i_index_next,
    output i_index_hasNext,

    input i_bus_B_row, // row first, 16b1x4
    input i_bus_B_col, // col first, 16b4x1
    input i_bus_C_row, // row first, 16b1x4
    input i_bus_SSState, // 64b
    input i_bus_RNGState, // 64b
    input i_bus_salt, // 64b
    input i_bus_seedSE, // 64b
    input i_bus_pkh, // 64b
    input i_bus_k, // 64b
    input i_bus_u, // 64b
    input i_bus_S_row, // row first, 16b1x4 (internally encoded into 4b1x4)
    input [16*4-1:0] i_bus, 

    input i_dubBus_B_col, // 16b8x1
    input i_dubBus_C_col, // 16b8x1
    input [16*8-1:0] i_dubBus,

    input i_paral_B_mat, // 16b8x4
    input i_paral_C_mat, // 16b8x4
    input [16*4*8-1:0] i_paral,

    input i_halfBus_U_row, // 2b1x8, 3b1x8, 4b1x8, each value 4 bit aligned
    input [4*8-1:0] i_halfBus,

    output [9-1:0] o_index, // 512 values
    output [8*8-1:0] o_enable,
    output [64*8-1:0] o_value,
    
    input [9-1:0] config_matrixNumCellsMin1, // how many 8x4 matrixes are in B and S minus 1. The FrodoKEM parameter/4-1.
    input [14-1:0] config_matrixNumCellsTimes8Min1, // how many 1x4 matrixes are in B and S minus 1. The FrodoKEM parameter*2-1.
    input [14-1:0] config_matrixNumCellsTimes4Min1, // how many 8x1 matrixes are in B and S minus 1. The FrodoKEM parameter-1.
    input config_SUseHalfByte,
    input [`MemCONF_lenSec_size-1:0] config_lenSec,
    input [14-1:0] config_lenSecMin1,
    input [14-1:0] config_lenSEMin1,
    input [14-1:0] config_lenSaltMin1
);
  wor [8*8-1:0] o_enable__w;
  wire [8-1:0] o_bramEnable;
  wire [8-1:0] o_byteEnable;

  genvar col;
  genvar row;
  generate
    for (col = 0; col < 8; col=col+1) begin
      for (row = 0; row < 8; row=row+1) begin
        assign o_enable__w[col*8+row] = o_bramEnable[col] & o_byteEnable[row];
      end
    end
  endgenerate
  assign o_enable = o_enable__w;


  wire [9-1:0] column_offset = (i_bus_B_row | i_bus_B_col | i_dubBus_B_col | i_paral_B_mat) ? `MainMem_OFF_B : 9'd0
                             | i_bus_S_row ? `MainMem_OFF_S : 9'd0
                             | i_bus_SSState ? `MainMem_OFF_SSState : 9'd0
                             | (i_bus_C_row | i_dubBus_C_col | i_paral_C_mat) ? `MainMem_OFF_C : 9'd0
                             | i_bus_RNGState ? `MainMem_OFF_RNGState : 9'd0
                             | i_bus_salt ? `MainMem_OFF_salt : 9'd0
                             | i_bus_seedSE ? `MainMem_OFF_seedSE : 9'd0
                             | i_bus_pkh ? `MainMem_OFF_pkh : 9'd0
                             | (i_halfBus_U_row | i_bus_u) ? `MainMem_OFF_U : 9'd0
                             | i_bus_k ? `MainMem_OFF_k : 9'd0;

  assign i_index_next = ((i_bus_B_row | i_bus_S_row) & (i_index[0+:9] == config_matrixNumCellsMin1)) ? { i_index[14-1:9] + 5'd1, 9'b0 }
                                                                                                     : i_index + 14'b1;

  assign i_index_hasNext = ((i_bus_S_row | i_bus_B_row) ? i_index != {5'd7, config_matrixNumCellsMin1} : 1'b0)
                         | (i_bus_B_col ? i_index != config_matrixNumCellsTimes8Min1 : 1'b0) 
                         | (i_bus_C_row ? i_index != 14'd15 : 1'b0) 
                         | (i_bus_SSState ? i_index != 14'd24 : 1'b0) 
                         | (i_bus_RNGState ? i_index != 14'd7 : 1'b0) 
                         | (i_bus_salt ? i_index != config_lenSaltMin1 : 1'b0)
                         | (i_bus_seedSE ? i_index != config_lenSEMin1 : 1'b0)
                         | (i_bus_pkh ? i_index != config_lenSecMin1 : 1'b0)
                         | (i_bus_k ? i_index != config_lenSecMin1 : 1'b0)
                         | (i_dubBus_B_col ? i_index != config_matrixNumCellsTimes4Min1 : 1'b0)
                         | ((i_dubBus_C_col | i_halfBus_U_row) ? i_index != 14'd7 : 1'b0)
                         | (i_bus_u ? i_index != config_lenSecMin1 : 1'b0) 
                         | (i_paral_C_mat ? i_index != 14'd1 : 1'b0)
                         | (i_paral_B_mat ? i_index != {5'd0, config_matrixNumCellsMin1} : 1'b0);

  wire i_bus_anyCell = i_bus_SSState
                     | i_bus_RNGState
                     | i_bus_salt
                     | i_bus_seedSE
                     | i_bus_pkh
                     | i_bus_k
                     | i_bus_u;

  wire i_dubBus_anyCol = i_dubBus_C_col
                       | i_dubBus_B_col;

  wire [9-1:0] unoff_index_col = (i_bus_B_row | i_paral_B_mat | i_paral_C_mat) ? i_index[0+:9] : 9'b0
                               | i_bus_C_row ? {8'b0, i_index[0+:1]} : 9'b0
                               | i_dubBus_anyCol ? i_index[2+:9] : 9'b0
                               | (i_bus_S_row & config_SUseHalfByte) ? {2'b0, i_index[2+:7]} : 9'b0
                               | (i_bus_S_row & ~config_SUseHalfByte) ? {1'b0, i_index[1+:8]} : 9'b0
                               | (i_bus_B_col | i_bus_anyCell) ? i_index[3+:9] : 9'b0;


  assign o_index = unoff_index_col + column_offset;


  wire [2-1:0] o_byteEnable_elemIndex = ((i_dubBus_anyCol | i_bus_S_row) ? i_index[0+:2] : 2'b0)
                                      | (i_bus_B_col ? i_index[1+:2] : 2'b0);
  wire [8-1:0] o_byteEnable_elem;
  mem_elementIndexToByteEnable o_byteEnable_elem__c(o_byteEnable_elemIndex, o_byteEnable_elem);
  
  assign o_byteEnable = (i_bus_B_row | i_bus_C_row | i_paral_B_mat | i_paral_C_mat | i_bus_anyCell) ? 8'hFF : 8'b0
                      | (i_bus_S_row & ~config_SUseHalfByte) ? (i_index[0] == 1'b0 ? 8'h0F : 8'hF0) : 8'b0
                      | (i_dubBus_anyCol | i_bus_S_row & config_SUseHalfByte | i_bus_B_col) ? o_byteEnable_elem : 8'b0;


  wire [3-1:0] o_bramEnable_byteIndex = ((i_bus_B_row | i_bus_S_row) ? i_index[9+:3] : 3'b0)
                                      | (i_bus_C_row ? (i_index[1+:3] ^ {2'b0, i_index[0]}) : 3'b0)
                                      | (i_bus_anyCell ? i_index[0+:3] : 3'b0);
  wire [8-1:0] o_bramEnable_byte;
  mem_byteIndexToByteEnable o_bramEnable_byte__c(o_bramEnable_byteIndex, o_bramEnable_byte);

  assign o_bramEnable = (i_dubBus_B_col | i_dubBus_C_col | i_paral_B_mat | i_paral_C_mat) ? 8'hFF : 8'b0
                      | i_bus_B_col ? (i_index[0] == 1'b0 ? 8'h0F : 8'hF0) : 8'b0
                      | (i_bus_B_row | i_bus_C_row | i_bus_anyCell | i_bus_S_row) ? o_bramEnable_byte : 8'b0;

  assign o_enable__w = i_halfBus_U_row & config_lenSec[0] ? ( 64'b11 << (2*i_index) ) : 0;
  assign o_enable__w = i_halfBus_U_row & config_lenSec[1] ? ( 64'b111 << (3*i_index) ) : 0;
  assign o_enable__w = i_halfBus_U_row & config_lenSec[2] ? ( 64'b1111 << (4*i_index) ) : 0;


  wor [64*8-1:0] o_value__w;
  assign o_value = o_value__w;

  generate
    for (row = 0; row < 8; row=row+1) begin
      assign o_value__w[row*64+:64] = i_dubBus_B_col ? {4{i_dubBus[row*16+:16]}} : 64'b0;
      assign o_value__w[row*64+:64] = i_dubBus_C_col ? (i_index[2] ? {4{i_dubBus[(row^1)*16+:16]}} : {4{i_dubBus[row*16+:16]}}) : 64'b0;
      assign o_value__w[row*64+:64] = i_paral_C_mat ? (i_index[0] ? i_paral[(row^1)*64+:64] : i_paral[row*64+:64]) : 64'b0;
    end
  endgenerate

  assign o_value__w = i_paral_B_mat ? i_paral : 512'b0;
  assign o_value__w = (i_bus_B_row | i_bus_C_row | i_bus_anyCell) ? {8{i_bus}} : 512'b0;

  generate
    for (row = 0; row < 4; row=row+1) begin
      assign o_value__w[0*64+row*64+:64] = i_bus_B_col ? {4{i_bus[row*16+:16]}} : 64'b0;
      assign o_value__w[4*64+row*64+:64] = i_bus_B_col ? {4{i_bus[row*16+:16]}} : 64'b0;
    end
  endgenerate


  assign o_value__w = i_halfBus_U_row & config_lenSec[2] ? { 256'b0, {8{i_halfBus}} } : 512'b0;
  
  wire [3*8-1:0] i_halfBus__3;
  generate
    for (row = 0; row < 8; row=row+1) begin
      assign i_halfBus__3[row*3+:3] = i_halfBus[row*4+:3];
    end
  endgenerate
  assign o_value__w = i_halfBus_U_row & config_lenSec[1] ? { 320'b0, {8{i_halfBus__3}} } : 512'b0;
  
  wire [2*8-1:0] i_halfBus__2;
  generate
    for (row = 0; row < 8; row=row+1) begin
      assign i_halfBus__2[row*2+:2] = i_halfBus[row*4+:2];
    end
  endgenerate
  assign o_value__w = i_halfBus_U_row & config_lenSec[0] ? { 384'b0, {8{i_halfBus__2}} } : 512'b0;
  
  
  
  wire [32-1:0] i_bus_sampledCompact;
  stdToCompact i_bus_sampledCompact__c (config_SUseHalfByte, i_bus, i_bus_sampledCompact);
  
  assign o_value__w = i_bus_S_row ? {2*8{i_bus_sampledCompact}} : 512'b0;
endmodule

`define MainMemCMD_bus_B_row 0
`define MainMemCMD_bus_B_col 1
`define MainMemCMD_bus_C_row 2
`define MainMemCMD_bus_SSState 3
`define MainMemCMD_bus_RNGState 4
`define MainMemCMD_bus_salt 5
`define MainMemCMD_bus_seedSE 6
`define MainMemCMD_bus_pkh 7
`define MainMemCMD_bus_k 8
`define MainMemCMD_bus_u 9
`define MainMemCMD_bus_S_row 10 /* only the lowest 16bits are used, only for writing */

`define MainMemCMD_SIZE 11


// two ports: Read, Write
module mainMem(
    input [14-1:0] r_index,
    output [14-1:0] r_index_next,
    output r_index_hasNext,

    input [`MainMemCMD_SIZE-1:0] r_bus_cmd, // no MainMemCMD_bus_S_row!
    output [16*4-1:0] r_bus__d2,

    input r_dubBus_B_col, // 16b8x1
    input r_dubBus_C_col, // 16b8x1
    input r_dubBus_C_row, // 16b1x8
    output [16*8-1:0] r_dubBus__d2,

    input r_paralSBus_S_mat, // 5b8x4
    output [5*4*8-1:0] r_paralSBus__d2,

    input r_paral_B_mat, // 16b8x4
    input r_paral_C_mat, // 16b8x4
    output [16*4*8-1:0] r_paral__d2,

    input r_SBus_S_col, // 5b8x1
    output [5*8-1:0] r_SBus__d2,

    input r_quarterBus_U_halfRow, // 4b4x1
    output [4*4-1:0] r_quarterBus__d2,
 

    input [14-1:0] w_index,
    output [14-1:0] w_index_next,
    output w_index_hasNext,

    input [`MainMemCMD_SIZE-1:0] w_bus_cmd,
    input [16*4-1:0] w_bus, 

    input w_dubBus_B_col, // 16b8x1
    input w_dubBus_C_col, // 16b8x1
    input [16*8-1:0] w_dubBus,

    input w_paral_B_mat, // 16b8x4
    input w_paral_C_mat, // 16b8x4
    input [16*4*8-1:0] w_paral,

    input w_halfBus_U_row, // 4b1x8
    input [4*8-1:0] w_halfBus,

    input [`MemCONF_matrixNumBlocks_size-1:0] config_matrixNumBlocks, // how many 8x8 matrixes are in B and S. The FrodoKEM parameter/8.
    input config_SUseHalfByte,
    input [`MemCONF_lenSec_size-1:0] config_lenSec,
    input [`MemCONF_lenSE_size-1:0] config_lenSE,
    input [`MemCONF_lenSalt_size-1:0] config_lenSalt,
    
    input rst,
    input clk
  );
  wire [ 9-1:0] config_matrixNumCellsMin1       = (config_matrixNumBlocks << 1) -  9'd1;
  wire [14-1:0] config_matrixNumCellsTimes8Min1 = (config_matrixNumBlocks << 4) - 14'd1;
  wire [14-1:0] config_matrixNumCellsTimes4Min1 = (config_matrixNumBlocks << 3) - 14'd1;
  wire [14-1:0] config_lenSecMin1 = config_lenSec[0] ? 14'd1
                                  : config_lenSec[1] ? 14'd2
                                                     : 14'd3;
  wire [14-1:0] config_lenSEMin1 = config_lenSE[0] ? 14'd3
                                 : config_lenSE[1] ? 14'd5
                                                   : 14'd7;
  wire [14-1:0] config_lenSaltMin1 = config_lenSalt[0] ? 14'd3
                                   : config_lenSalt[1] ? 14'd5
                                                       : 14'd7;


  wire [9-1:0] b__r_index;
  wire [8*8-1:0] b__r_enable;
  wire [8-1:0] b__r_fromNextIndex;
  wire [64*8-1:0] b__r_value__d2;
  wire [9-1:0] b__w_index;
  wire [8*8-1:0] b__w_enable;
  wire [64*8-1:0] b__w_value;
  bram8 b(
    .r_index(b__r_index),
    .r_enable(b__r_enable),
    .r_fromNextIndex(b__r_fromNextIndex),
    .r_value__d2(b__r_value__d2),
    .w_index(b__w_index),
    .w_enable(b__w_enable),
    .w_value(b__w_value),
    .rst(rst),
    .clk(clk)
  );

  mainMem_readConnector r(
    .i_index(r_index),
    .i_index_next(r_index_next),
    .i_index_hasNext(r_index_hasNext),
    .i_bus_B_row(r_bus_cmd[`MainMemCMD_bus_B_row]),
    .i_bus_B_col(r_bus_cmd[`MainMemCMD_bus_B_col]),
    .i_bus_C_row(r_bus_cmd[`MainMemCMD_bus_C_row]),
    .i_bus_SSState(r_bus_cmd[`MainMemCMD_bus_SSState]),
    .i_bus_RNGState(r_bus_cmd[`MainMemCMD_bus_RNGState]),
    .i_bus_salt(r_bus_cmd[`MainMemCMD_bus_salt]),
    .i_bus_seedSE(r_bus_cmd[`MainMemCMD_bus_seedSE]),
    .i_bus_pkh(r_bus_cmd[`MainMemCMD_bus_pkh]),
    .i_bus_k(r_bus_cmd[`MainMemCMD_bus_k]),
    .i_bus_u(r_bus_cmd[`MainMemCMD_bus_u]),
    .i_bus_S_row_DBG(r_bus_cmd[`MainMemCMD_bus_S_row]),
    .i_bus__d2(r_bus__d2),
    .i_dubBus_B_col(r_dubBus_B_col),
    .i_dubBus_C_col(r_dubBus_C_col),
    .i_dubBus_C_row(r_dubBus_C_row),
    .i_dubBus__d2(r_dubBus__d2),
    .i_paralSBus_S_mat(r_paralSBus_S_mat),
    .i_paralSBus__d2(r_paralSBus__d2),
    .i_paral_B_mat(r_paral_B_mat),
    .i_paral_C_mat(r_paral_C_mat),
    .i_paral__d2(r_paral__d2),
    .i_SBus_S_col(r_SBus_S_col),
    .i_SBus__d2(r_SBus__d2),
    .i_quarterBus_U_halfRow(r_quarterBus_U_halfRow),
    .i_quarterBus__d2(r_quarterBus__d2),
    .o_index(b__r_index),
    .o_enable(b__r_enable),
    .o_fromNextIndex(b__r_fromNextIndex),
    .o_value__d2(b__r_value__d2),
    .config_matrixNumCellsMin1(config_matrixNumCellsMin1),
    .config_matrixNumCellsTimes8Min1(config_matrixNumCellsTimes8Min1),
    .config_matrixNumCellsTimes4Min1(config_matrixNumCellsTimes4Min1),
    .config_SUseHalfByte(config_SUseHalfByte),
    .config_lenSec(config_lenSec),
    .config_lenSecMin1(config_lenSecMin1),
    .config_lenSEMin1(config_lenSEMin1),
    .config_lenSaltMin1(config_lenSaltMin1),
    .rst(rst),
    .clk(clk)
  );

  mainMem_writeConnector w(
    .i_index(w_index),
    .i_index_next(w_index_next),
    .i_index_hasNext(w_index_hasNext),
    .i_bus_B_row(w_bus_cmd[`MainMemCMD_bus_B_row]),
    .i_bus_B_col(w_bus_cmd[`MainMemCMD_bus_B_col]),
    .i_bus_C_row(w_bus_cmd[`MainMemCMD_bus_C_row]),
    .i_bus_SSState(w_bus_cmd[`MainMemCMD_bus_SSState]),
    .i_bus_RNGState(w_bus_cmd[`MainMemCMD_bus_RNGState]),
    .i_bus_salt(w_bus_cmd[`MainMemCMD_bus_salt]),
    .i_bus_seedSE(w_bus_cmd[`MainMemCMD_bus_seedSE]),
    .i_bus_pkh(w_bus_cmd[`MainMemCMD_bus_pkh]),
    .i_bus_k(w_bus_cmd[`MainMemCMD_bus_k]),
    .i_bus_u(w_bus_cmd[`MainMemCMD_bus_u]),
    .i_bus_S_row(w_bus_cmd[`MainMemCMD_bus_S_row]),
    .i_bus(w_bus),
    .i_dubBus_B_col(w_dubBus_B_col),
    .i_dubBus_C_col(w_dubBus_C_col),
    .i_dubBus(w_dubBus),
    .i_paral_B_mat(w_paral_B_mat),
    .i_paral_C_mat(w_paral_C_mat),
    .i_paral(w_paral),
    .i_halfBus_U_row(w_halfBus_U_row),
    .i_halfBus(w_halfBus),
    .o_index(b__w_index),
    .o_enable(b__w_enable),
    .o_value(b__w_value),
    .config_matrixNumCellsMin1(config_matrixNumCellsMin1),
    .config_matrixNumCellsTimes8Min1(config_matrixNumCellsTimes8Min1),
    .config_matrixNumCellsTimes4Min1(config_matrixNumCellsTimes4Min1),
    .config_SUseHalfByte(config_SUseHalfByte),
    .config_lenSec(config_lenSec),
    .config_lenSecMin1(config_lenSecMin1),
    .config_lenSEMin1(config_lenSEMin1),
    .config_lenSaltMin1(config_lenSaltMin1)
  );

endmodule

`endif // MEM_V

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


`ifndef MAIN_CORE_V
`define MAIN_CORE_V


// This file provides the module: main_core
// It contains the main module, with the exception of the controller, which is handled separately to ease the testing.


`include "adapted_keccak.v"
`include "busHubAndAdapters.v"
`include "memAndMul.v"


`define CmdHubCMD_keccak    3'b100
`define CmdHubCMD_memAndMul 3'b010
`define CmdHubCMD_outer     3'b001

`define CmdHubCMD_SIZE  6



`define MainCoreCMD_NO_o_in  {`OuterInCMD_SIZE{1'b0}}
`define MainCoreCMD_NO_o_out {`OuterOutCMD_SIZE{1'b0}}
`define MainCoreCMD_NO_k_in  {`KeccakInCMD_SIZE{1'b0}}
`define MainCoreCMD_NO_k_out {`KeccakOutCMD_SIZE{1'b0}}
`define MainCoreCMD_NO_h     {`CmdHubCMD_SIZE{1'b0}}
`define MainCoreCMD_NO_m     {`MemAndMulCMD_SIZE{1'b0}}
`define MainCoreCMD_NO_k     {`KeccakAdaptedCMD_SIZE{1'b0}}

//                             15                   15                11                  2                       6                  7                    14
`define MainCoreCMD_SIZE  (`OuterInCMD_SIZE + `OuterOutCMD_SIZE + `KeccakInCMD_SIZE + `KeccakOutCMD_SIZE + `CmdHubCMD_SIZE + `MemAndMulCMD_SIZE + `KeccakAdaptedCMD_SIZE)


`define MainCoreCMD_which_o_in   (8'b1 << 0)
`define MainCoreCMD_which_o_out  (8'b1 << 1)
`define MainCoreCMD_which_k_in   (8'b1 << 2)
`define MainCoreCMD_which_k_out  (8'b1 << 3)
`define MainCoreCMD_which_h      (8'b1 << 4)
`define MainCoreCMD_which_m      (8'b1 << 5)
`define MainCoreCMD_which_k      (8'b1 << 6)

`define MainCoreCMD_which_SIZE  7

//                                   8                       3                   3                        3                    3
`define MainCoreCONF_SIZE   (`MemCONF_matrixNumBlocks_size + `SamplerCONF_SIZE + `MemCONF_lenSec_size + `MemCONF_lenSE_size + `MemCONF_lenSalt_size)



module main_core(
    input fast_start,
    input fast_mode_sa,
    output fast_done,
    output fast_ready,
    // o_in:  { size:15bits }
    // o_out: { size:15bits }
    // k_in:  { byteVal:8bits, skipIsLast:1bit, CMD:3bit } 
    // k_out: { skipIsLast:1bit, sample:1bit }
    // h:     { destination:3bit, source:3bit }  each is: { keccak:1bit, memAndMul:1bit, outer:1bit } 
    // m:     { isPack:1bit, mainCmd:6bit }
    // k:     { is128else256:1bit, inState:1bit, outState:1bit, mainIsInElseOut:1bit, mainNumBlocks:9bits, secondaryNumBlocks:1bits }
    input [`MainCoreCMD_SIZE-1:0] cmd,
    input [`MainCoreCMD_which_SIZE-1:0] cmd_hasAny,
    output cmd_consume,

    input [64-1:0] in,
    input in_isReady,
    output in_canReceive,

    output [64-1:0] out,
    output out_isReady,
    input out_canReceive,

    input [`MainCoreCONF_SIZE-1:0] conf, // { The FrodoKEM parameter/8 : 8bits, which sampling distribution : 3bits, which lenSec : 3bits, which lenSE : 3bits, which lenSalt : 3bits }.   distr 0,1 have max FrodoKEM param of 1344.  distr 2 has max FrodoKEM param of 1330.

    input rst,
    input clk
  );
  wor ignore;

  wire [`MemCONF_matrixNumBlocks_size-1:0] config_matrixNumBlocks;
  wire [`SamplerCONF_SIZE-1:0] config_whichSampling;
  wire [`MemCONF_lenSec_size-1:0] config_lenSec;
  wire [`MemCONF_lenSE_size-1:0] config_lenSE;
  wire [`MemCONF_lenSalt_size-1:0] config_lenSalt;

  assign {config_matrixNumBlocks, config_whichSampling, config_lenSec, config_lenSE, config_lenSalt} = conf;


  wire config_SUseHalfByte = config_whichSampling[2];

  wire o_in__cmd_canReceive;
  wire o_out__cmd_canReceive;
  wire k_in__cmd_canReceive;
  wire k_out__cmd_canReceive;
  wire h__cmd_canReceive;
  wire m__cmd_canReceive;
  wire k__cmd_canReceive;
  assign cmd_consume = ((cmd_hasAny & `MainCoreCMD_which_o_in) == 0 | o_in__cmd_canReceive)
                     & ((cmd_hasAny & `MainCoreCMD_which_o_out) == 0 | o_out__cmd_canReceive)
                     & ((cmd_hasAny & `MainCoreCMD_which_k_in) == 0 | k_in__cmd_canReceive)
                     & ((cmd_hasAny & `MainCoreCMD_which_k_out) == 0 | k_out__cmd_canReceive)
                     & ((cmd_hasAny & `MainCoreCMD_which_h) == 0 | h__cmd_canReceive)
                     & ((cmd_hasAny & `MainCoreCMD_which_m) == 0 | m__cmd_canReceive)
                     & ((cmd_hasAny & `MainCoreCMD_which_k) == 0 | k__cmd_canReceive)
                     & cmd_hasAny != 0;

  wire o_in__cmd_isReady  = (cmd_hasAny & `MainCoreCMD_which_o_in) != 0 & o_in__cmd_canReceive & cmd_consume;
  wire o_out__cmd_isReady = (cmd_hasAny & `MainCoreCMD_which_o_out) != 0 & o_out__cmd_canReceive & cmd_consume;
  wire k_in__cmd_isReady  = (cmd_hasAny & `MainCoreCMD_which_k_in) != 0 & k_in__cmd_canReceive & cmd_consume;
  wire k_out__cmd_isReady = (cmd_hasAny & `MainCoreCMD_which_k_out) != 0 & k_out__cmd_canReceive & cmd_consume;
  wire h__cmd_isReady = (cmd_hasAny & `MainCoreCMD_which_h) != 0 & h__cmd_canReceive & cmd_consume;
  wire m__cmd_isReady = (cmd_hasAny & `MainCoreCMD_which_m) != 0 & m__cmd_canReceive & cmd_consume;
  wire k__cmd_isReady = (cmd_hasAny & `MainCoreCMD_which_k) != 0 & k__cmd_canReceive & cmd_consume;

  wire [`OuterInCMD_SIZE-1:0] o_in__cmd    = cmd[`OuterOutCMD_SIZE + `KeccakInCMD_SIZE + `KeccakOutCMD_SIZE + `CmdHubCMD_SIZE + `MemAndMulCMD_SIZE + `KeccakAdaptedCMD_SIZE +:`OuterInCMD_SIZE];
  wire [`OuterOutCMD_SIZE-1:0] o_out__cmd  = cmd[`KeccakInCMD_SIZE + `KeccakOutCMD_SIZE + `CmdHubCMD_SIZE + `MemAndMulCMD_SIZE + `KeccakAdaptedCMD_SIZE +:`OuterOutCMD_SIZE];
  wire [`KeccakInCMD_SIZE-1:0] k_in__cmd   = cmd[`KeccakOutCMD_SIZE + `CmdHubCMD_SIZE + `MemAndMulCMD_SIZE + `KeccakAdaptedCMD_SIZE +:`KeccakInCMD_SIZE];
  wire [`KeccakOutCMD_SIZE-1:0] k_out__cmd = cmd[`CmdHubCMD_SIZE + `MemAndMulCMD_SIZE + `KeccakAdaptedCMD_SIZE +:`KeccakOutCMD_SIZE];
  wire [`CmdHubCMD_SIZE-1:0] h__cmd        = cmd[`MemAndMulCMD_SIZE + `KeccakAdaptedCMD_SIZE +:`CmdHubCMD_SIZE];
  wire [`MemAndMulCMD_SIZE-1:0] m__cmd     = cmd[`KeccakAdaptedCMD_SIZE +:`MemAndMulCMD_SIZE];
  wire [`KeccakAdaptedCMD_SIZE-1:0] k__cmd = cmd[0 +:`KeccakAdaptedCMD_SIZE];


  wire [64*3-1:0] h__in;
  wire [3-1:0] h__in_isReady;
  wire [3-1:0] h__in_canReceive;
  wire [3-1:0] h__in_isLast_in;
  wire [3-1:0] h__in_isLast_out;
  wire [64*3-1:0] h__out;
  wire [3-1:0] h__out_isReady;
  wire [3-1:0] h__out_canReceive;
  wire [3-1:0] h__out_isLast_in;
  wire [3-1:0] h__out_isLast_out;
  busSwitch #(3) hub (
    .cmd(h__cmd),
    .cmd_isReady(h__cmd_isReady),
    .cmd_canReceive(h__cmd_canReceive),
    .in(h__in),
    .in_isReady(h__in_isReady),
    .in_canReceive(h__in_canReceive),
    .in_isLast_in(h__in_isLast_in),
    .in_isLast_out(h__in_isLast_out),
    .out(h__out),
    .out_isReady(h__out_isReady),
    .out_canReceive(h__out_canReceive),
    .out_isLast_in(h__out_isLast_in),
    .out_isLast_out(h__out_isLast_out),
    .rst(rst),
    .clk(clk)
  );

  main_adapter_outer_in o_in(
    .cmd(o_in__cmd),
    .cmd_isReady(o_in__cmd_isReady),
    .cmd_canReceive(o_in__cmd_canReceive),
    .h__in(h__in[64*0+:64]),
    .h__in_isReady(h__in_isReady[0]),
    .h__in_canReceive(h__in_canReceive[0]),
    .h__in_isLast_in(h__in_isLast_in[0]),
    .h__in_isLast_out(h__in_isLast_out[0]),
    .o__in(in),
    .o__in_isReady(in_isReady),
    .o__in_canReceive(in_canReceive),
    .rst(rst),
    .clk(clk)
  );

  main_adapter_outer_out o_out(
    .cmd(o_out__cmd),
    .cmd_isReady(o_out__cmd_isReady),
    .cmd_canReceive(o_out__cmd_canReceive),
    .h__out(h__out[64*0+:64]),
    .h__out_isReady(h__out_isReady[0]),
    .h__out_canReceive(h__out_canReceive[0]),
    .h__out_isLast_in(h__out_isLast_in[0]),
    .h__out_isLast_out(h__out_isLast_out[0]),
    .o__out(out),
    .o__out_isReady(out_isReady),
    .o__out_canReceive(out_canReceive),
    .rst(rst),
    .clk(clk)
  );

  wire [127:0] fast_seed;
  wire fast_keccak_idle;
  adapted_keccak keccak(
    .fast_idle(fast_keccak_idle),
    .fast_seed(fast_seed),
    .k_in__cmd(k_in__cmd),
    .k_in__cmd_isReady(k_in__cmd_isReady),
    .k_in__cmd_canReceive(k_in__cmd_canReceive),
    .k_out__cmd(k_out__cmd),
    .k_out__cmd_isReady(k_out__cmd_isReady),
    .k_out__cmd_canReceive(k_out__cmd_canReceive),
    .config_whichSampling(config_whichSampling),
    .k__cmd(k__cmd),
    .k__cmd_isReady(k__cmd_isReady),
    .k__cmd_canReceive(k__cmd_canReceive),
    .h__out(h__out[2*64+:64]),
    .h__out_isReady(h__out_isReady[2]),
    .h__out_canReceive(h__out_canReceive[2]),
    .h__out_isLast_in(h__out_isLast_in[2]),
    .h__out_isLast_out(h__out_isLast_out[2]),
    .h__in(h__in[2*64+:64]),
    .h__in_isReady(h__in_isReady[2]),
    .h__in_canReceive(h__in_canReceive[2]),
    .h__in_isLast_in(h__in_isLast_in[2]),
    .h__in_isLast_out(h__in_isLast_out[2]),
    .rst(rst),
    .clk(clk)
  );

  assign ignore = h__out_isLast_out[1] | h__in_isLast_out[1];
  wire fast_owner, fast_r_secret, fast_r_secret_col, fast_r_b, fast_w_b;
  wire [13:0] fast_r_index, fast_w_index;
  wire [511:0] fast_w_data, fast_b_data;
  wire [159:0] fast_s_data;
  wire [39:0] fast_s_col_data;
  // FIFO readiness does not imply the last sampled C write has retired.
  // Fixed public-phase drain: exceeds the two memory-return and two write-index
  // stages plus command adaptation. No data/secret-dependent decision.
  wire fast_handoff_eligible = fast_keccak_idle && k__cmd_canReceive && k_in__cmd_canReceive && k_out__cmd_canReceive && m__cmd_canReceive && h__cmd_canReceive && o_out__cmd_canReceive && cmd_hasAny==0;
  reg [3:0] fast_drain_count;
  always @(posedge clk) begin
    if(rst || !fast_handoff_eligible) fast_drain_count<=0;
    else if(fast_drain_count<4'd8) fast_drain_count<=fast_drain_count+1'b1;
  end
  assign fast_ready = fast_handoff_eligible && fast_drain_count==4'd8;
  full25_keygen_memory_path fast_path(
    .clk(clk), .rst(rst), .start(fast_start), .mode_sa(fast_mode_sa), .seed(fast_seed), .done(fast_done),
    .owner(fast_owner), .r_index(fast_r_index), .w_index(fast_w_index),
    .r_secret(fast_r_secret), .r_secret_col(fast_r_secret_col), .r_b(fast_r_b), .w_b(fast_w_b),
    .w_data(fast_w_data), .s_data(fast_s_data), .s_col_data(fast_s_col_data), .b_data(fast_b_data));
  memAndMul memAndMul(
    .fast_owner(fast_owner), .fast_r_index(fast_r_index), .fast_w_index(fast_w_index),
    .fast_r_secret(fast_r_secret), .fast_r_secret_col(fast_r_secret_col), .fast_s_col_data(fast_s_col_data), .fast_r_b(fast_r_b), .fast_w_b(fast_w_b),
    .fast_w_data(fast_w_data), .fast_s_data(fast_s_data), .fast_b_data(fast_b_data),

    .cmd(m__cmd),
    .cmd_isReady(m__cmd_isReady),
    .cmd_canReceive(m__cmd_canReceive),
    .in_isReady(h__out_isReady[1]),
    .in(h__out[1*64+:64]),
    .in_canReceive(h__out_canReceive[1]),
    .in_isLast(h__out_isLast_in[1]),
    .out_isReady(h__in_isReady[1]),
    .out_isLast(h__in_isLast_in[1]),
    .out(h__in[1*64+:64]),
    .out_canReceive(h__in_canReceive[1]),
    .config_matrixNumBlocks(config_matrixNumBlocks),
    .config_SUseHalfByte(config_SUseHalfByte),
    .config_lenSec(config_lenSec),
    .config_lenSE(config_lenSE),
    .config_lenSalt(config_lenSalt),
    .rst(rst),
    .clk(clk)
  );
endmodule


`endif // MAIN_CORE_V

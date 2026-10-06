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


`ifndef MEMANDMUL_V
`define MEMANDMUL_V


// This file provides the module: memAndMul
// It carries out all the memory and operations outside the keccak module and the seed_A storage
// In the paper it's called Memory-Integrated Computational Block (MICB)


`include "frodoMul.v"
`include "mem.v"


`define MemAndMulIndexCMD_in               5'h01
`define MemAndMulIndexCMD_out              5'h02
`define MemAndMulIndexCMD_updateSync       5'h04 /* Read from one var and write to another, with same indexes. */
`define MemAndMulIndexCMD_updateSyncIn     5'h08 /* Read from one var and write to another, with same indexes. Using a variable from input */
`define MemAndMulIndexCMD_updateSyncMem    5'h0C /* Read from two vars and write to another, all with same indexes, */
`define MemAndMulIndexCMD_updateSlowMemIn  5'h10 /* Read from one vars and write to another, with same indexes, using a variable from input. Before each of this blocks, read the next of another variable and repeat. */
`define MemAndMulIndexCMD_updateFastMemIn  5'h14 /* Read from one var and write to another, with same indexes, In between the r/w, read another variable and the input. */
`define MemAndMulIndexCMD_updateFastMemMem 5'h18 /* Read from one var and write to another, with same indexes, In between the r/w, read two variables, with the second's index a combination of the other two */

`define MemAndMulIndexCMD_SIZE 5



module memAndMul__indexHandler(
    input [`MemAndMulIndexCMD_SIZE-1:0] currentCmd,
    input currentCmd_in_isFirstCycle,
    input currentCmd_out_isFirstCycle,
    output currentCmd_in_isLastCycle,
    output currentCmd_out_isLastCycle, // the bus_out__d2 can output after this is active as this is to start new commands
    input currentCmd_inOp_splitIn, // if the input matrix is split into multiple inputs.

    input bus_in_isReady,
    output bus_in_canReceive,
    output bus_in_isLast,
    input bus_out_canReceive,

    output [14-1:0] r_index,
    input [14-1:0] r_index_next,
    input r_index_hasNext,
    output [14-1:0] w_index,
    input [14-1:0] w_index_next,
    input w_index_hasNext,

    output r_index__useIndex1,
    output index1__toggle,
    output r_enable,
    output r_enable__d2,
    output w_enable,

    input rst,
    input clk
  );

  wire currentCmd_in = (currentCmd & `MemAndMulIndexCMD_in) != 0;
  wire currentCmd_out = (currentCmd & `MemAndMulIndexCMD_out) != 0;
  wire currentCmd_updateSync = currentCmd == `MemAndMulIndexCMD_updateSync;
  wire currentCmd_updateSyncIn = currentCmd == `MemAndMulIndexCMD_updateSyncIn;
  wire currentCmd_updateSyncMem = currentCmd == `MemAndMulIndexCMD_updateSyncMem;
  wire currentCmd_updateSlowMemIn = currentCmd == `MemAndMulIndexCMD_updateSlowMemIn;
  wire currentCmd_updateFastMemIn = currentCmd == `MemAndMulIndexCMD_updateFastMemIn;
  wire currentCmd_updateFastMemMem = currentCmd == `MemAndMulIndexCMD_updateFastMemMem;

  wire currentCmd_updateSyncAny = currentCmd_updateSync || currentCmd_updateSyncIn || currentCmd_updateSyncMem;
  wire currentCmd_updateFSAnyIn = currentCmd_updateFastMemIn || currentCmd_updateSlowMemIn;
  wire currentCmd_updateFSAny = currentCmd_updateFSAnyIn || currentCmd_updateFastMemMem;
  wire currentCmd_updateFastAny = currentCmd_updateFastMemIn || currentCmd_updateFastMemMem;
  wire currentCmd_updateAnyIn = currentCmd_updateSyncIn || currentCmd_updateFSAnyIn;
  wire currentCmd_updateAnyMem = currentCmd_updateSyncMem || currentCmd_updateFastMemMem;


  // index1 is: read or the only one or fast
  // index2 is: write or             or slow


  // index reset
  wire currentCmd_in_isFirstCycle__d1;
  delay currentCmd_in_isFirstCycle__ff1 (currentCmd_in_isFirstCycle, currentCmd_in_isFirstCycle__d1, rst, clk);

  wire currentCmd_op_isLastCycles_2;
  wire index1_isLast__d2;
  wire index2_has_val;
  wire index2_has_val__d1;
  delay index2_has_val__ff(index2_has_val, index2_has_val__d1, rst, clk);
  wire index1_reset = currentCmd_out & currentCmd_out_isFirstCycle
                    | currentCmd_updateSyncAny & currentCmd_in_isFirstCycle
                    | currentCmd_updateFastAny & (currentCmd_in_isFirstCycle__d1 | index1_isLast__d2) & ~currentCmd_op_isLastCycles_2
                    | currentCmd_updateSlowMemIn & index2_has_val__d1 & (currentCmd_in_isFirstCycle__d1 | index1_isLast__d2);
  wire index2_reset = currentCmd_in & currentCmd_in_isFirstCycle
                    | currentCmd_updateFSAny & currentCmd_in_isFirstCycle;


  // index update
  wire index1__toggle__d1;
  assign index1__toggle = index1_reset ? 1'b0 : ~index1__toggle__d1;
  delay index1__toggle__ff(index1__toggle, index1__toggle__d1, rst, clk);

  wire index1_has_next;
  wire index1_has_next__d1;
  delay index1_has_next__ff1 (index1_has_next, index1_has_next__d1, rst, clk);
  wire index1_has_val__a1 = index1_has_next; // in theory it needs to be '| index1_reset__a1' but we're only using this to create the '_isLast' and we never have a value with a single cell.
  wire index1_has_val = index1_reset | index1_has_next__d1;
  wire index1_has_val__d1;
  delay index1_has_val__ff1 (index1_has_val, index1_has_val__d1, rst, clk);
  wire index1_has_val__d2;
  delay index1_has_val__ff2 (index1_has_val__d1, index1_has_val__d2, rst, clk);
  wire index1_isLast = index1_has_val & ~index1_has_val__a1;
  wire index1_isLast__d1 = index1_has_val__d1 & ~index1_has_val;
  assign index1_isLast__d2 = index1_has_val__d2 & ~index1_has_val__d1;

  wire index2_has_next__d1;
  wire index2_has_next;
  delay index2_has_next__ff(index2_has_next, index2_has_next__d1, rst, clk);
  assign index2_has_val = index2_reset | index2_has_next__d1;

  wire index1_update = currentCmd_out & bus_out_canReceive
                     | currentCmd_updateAnyMem & index1__toggle
                     | currentCmd_updateAnyIn & bus_in_isReady
                     | currentCmd_updateSync;
  wire index2_update = currentCmd_in & bus_in_isReady
                     | currentCmd_updateFastAny & index1_isLast
                     | currentCmd_updateSlowMemIn & (index1_isLast__d1 | currentCmd_in_isFirstCycle);


  // indexes
  wire [14-1:0] index1_next_input = r_index_next;
  wire [14-1:0] index2_next_input = currentCmd_in | currentCmd_updateFastAny ? w_index_next : r_index_next;

  wire [14-1:0] index1_next__d1;
  wire [14-1:0] index1 = index1_reset ? 14'b0 : index1_next__d1;
  wire [14-1:0] index1_next = index1_update & index1_has_next ? index1_next_input : index1;
  delay #(14) index1_next__ff (index1_next, index1_next__d1, rst, clk);
  wire [14-1:0] index2_next__d1;
  wire [14-1:0] index2 = index2_reset ? 14'b0 : index2_next__d1;
  wire [14-1:0] index2_next = index2_update & index2_has_next ? index2_next_input : index2;
  delay #(14) index2_next__ff (index2_next, index2_next__d1, rst, clk);


  // _isLastCycle
  wire index2_update__d1;
  delay index2_update__ff (index2_update, index2_update__d1, rst, clk);

  assign index1_has_next = index1_reset | (~index1_update ? index1_has_next__d1 : r_index_hasNext);
  assign index2_has_next = index2_reset | (~(currentCmd_updateFastAny ? index2_update__d1 : index2_update) ? index2_has_next__d1 : (currentCmd_in ? w_index_hasNext : r_index_hasNext));

  wire currentCmd_op_isLastCycle__a2_set = currentCmd_updateSyncMem & index1__toggle & ~index1_has_next
                                         | currentCmd_updateSyncIn & bus_in_isReady & ~index1_has_next
                                         | currentCmd_updateSync & ~index1_has_next
                                         | currentCmd_updateFSAny & ~(index1_has_next | index1_has_next__d1 | index2_has_next | index2_has_next__d1);
  wire currentCmd_op_isLastCycle;
  wire currentCmd_op_isLastCycle__a1;
  wire currentCmd_op_isLastCycle__a2 = currentCmd_op_isLastCycle__a2_set & ~currentCmd_op_isLastCycle__a1 & ~currentCmd_op_isLastCycle;
  delay currentCmd_op_isLastCycle__ff2 (currentCmd_op_isLastCycle__a2, currentCmd_op_isLastCycle__a1, rst, clk);
  delay currentCmd_op_isLastCycle__ff1 (currentCmd_op_isLastCycle__a1, currentCmd_op_isLastCycle, rst, clk);
  assign currentCmd_in_isLastCycle = currentCmd_in ? bus_in_isReady & ~w_index_hasNext : currentCmd_op_isLastCycle;
  assign currentCmd_out_isLastCycle = currentCmd_out ? bus_out_canReceive & ~r_index_hasNext : currentCmd_op_isLastCycle;
  assign currentCmd_op_isLastCycles_2 = currentCmd_op_isLastCycle | currentCmd_op_isLastCycle__a1;
  
  // bus_in_
  assign bus_in_canReceive = currentCmd_in
                           | (currentCmd_updateSyncIn | currentCmd_updateFSAnyIn) & index1_has_val;
  assign bus_in_isLast = currentCmd_in              ? bus_in_isReady & ~w_index_hasNext
                       : currentCmd_inOp_splitIn    ? index1_has_val & ~index1_has_next
                       : currentCmd_updateFastMemIn ? index1_has_val & ~index1_has_next & ~index2_has_next
                       : currentCmd_updateAnyIn     ? currentCmd_op_isLastCycle__a2
                                                    : 1'b0;

  // r index
  assign r_index__useIndex1 = currentCmd_out | currentCmd_updateSyncAny | (currentCmd_updateFSAny & index1_has_val);
  assign r_index = ~r_index__useIndex1                           ? index2
                 : currentCmd_updateFastMemMem & ~index1__toggle ? { index2[0+:5], index1[0+:9] }
                                                                 : index1;

  wire r_enable_op = currentCmd_updateFastMemMem & (index1_has_val | index2_has_val)
                   | currentCmd_updateFastMemIn  & (index1_has_val ? bus_in_isReady : index2_has_val)
                   | currentCmd_updateSlowMemIn  & (index1_has_val ? bus_in_isReady : index2_has_val)
                   | currentCmd_updateSyncMem    & index1_has_val
                   | currentCmd_updateSyncIn     & index1_has_val & bus_in_isReady
                   | currentCmd_updateSync       & index1_has_val;
  assign r_enable = currentCmd_out & bus_out_canReceive
                  | r_enable_op;
  wire r_enable__d1;
  delay r_enable_op__ff1 (r_enable, r_enable__d1, rst, clk);
  delay r_enable_op__ff2 (r_enable__d1, r_enable__d2, rst, clk);

  // w_enable
  wire w_enable_op__a2 = currentCmd_updateFastMemIn  & index1_isLast__d1
                       | currentCmd_updateFastMemMem & index1_isLast__d1
                       | currentCmd_updateSyncMem    & index1__toggle & index1_has_val
                       | currentCmd_updateSyncIn     & bus_in_isReady
                       | currentCmd_updateSync       & index1_has_val
                       | currentCmd_updateSlowMemIn  & bus_in_isReady;
  wire w_enable_op__a1;
  delay w_enable_op__ff2 (w_enable_op__a2, w_enable_op__a1, rst, clk);
  wire w_enable_op;
  delay w_enable_op__ff1 (w_enable_op__a1, w_enable_op, rst, clk);
  assign w_enable = currentCmd_in & bus_in_isReady
                  | w_enable_op;

  // w index
  wire [14-1:0] index2__d1;
  delay #(14) index2__ff (index2, index2__d1, rst, clk);
  wire w_index_op__useIndex1 = currentCmd_updateSyncAny | currentCmd_updateSlowMemIn;

  wire [14-1:0] w_index_op__a2 = w_index_op__useIndex1    ? index1
                               : currentCmd_updateFastAny ? index2__d1
                                                          : index2;
  wire [14-1:0] w_index_op__a1;
  delay #(14) w_index_op__ff2 (w_index_op__a2, w_index_op__a1, rst, clk);
  wire [14-1:0] w_index_op;
  delay #(14) w_index_op__ff1 (w_index_op__a1, w_index_op, rst, clk);

  assign w_index = currentCmd_in ? index2 : w_index_op;
endmodule





`define MemAndMulCMD_op_CpleqStimesBT  6'd0 /* BRAM.C = BRAM.C + BRAM.S' *' BRAM.B'^T */
`define MemAndMulCMD_op_UeqCminBtimesS 6'd1 /* BRAM.u = decode(BRAM.C - (BRAM.S' *' BRAM.B'^T)^T) */
`define MemAndMulCMD_op_CeqUminC       6'd2 /* BRAM.C = Encode(BRAM.u) - BRAM.C */
`define MemAndMulCMD_op_CeqU           6'd3 /* BRAM.C = Encode(BRAM.u) */
`define MemAndMulCMD_op_Erase1         6'd4 /* BRAM.S' = 0 */
`define MemAndMulCMD_op_Erase2         6'd5 /* BRAM.u = 0 ; BRAM.seedSE = 0 ; BRAM.k = 0 */
`define MemAndMulCMD_op_Erase3         6'd6 /* BRAM.B' = 0 ; BRAM.C = 0 */

`define MemAndMulCMD_inOp_BpleqStimesInAT 6'd7 /* BRAM.B' = BRAM.B'+ BRAM.S' *' _A^T */
`define MemAndMulCMD_inOp_BpleqStimesInA  6'd8 /* BRAM.B' = BRAM.B' + BRAM.S' *'' _A */
`define MemAndMulCMD_inOp_CpleqStimesInBT 6'd9 /* BRAM.C = BRAM.C + BRAM.S' *' _B^T */
`define MemAndMulCMD_inOp_addCRowFirst    6'd10 /* BRAM.C = BRAM.C + _C */
`define MemAndMulCMD_inOp_selectKey       6'd11 /* BRAM.k = BRAM.B' == 0 && BRAM.C == 0 ? BRAM.k : _s */
`define MemAndMulCMD_inOp_BeqInMinB       6'd12 /* BRAM.B' = _B - BRAM.B' */

`define MemAndMulCMD_in_BRowFirst 6'd13
`define MemAndMulCMD_in_BColFirst 6'd14
`define MemAndMulCMD_in_SRowFirst 6'd15 /* it changes the encoding when storing, to save space */
`define MemAndMulCMD_in_CRowFirst 6'd16
`define MemAndMulCMD_in_SSState   6'd17
`define MemAndMulCMD_in_RNGState  6'd18
`define MemAndMulCMD_in_salt      6'd19
`define MemAndMulCMD_in_seedSE    6'd20
`define MemAndMulCMD_in_pkh       6'd21
`define MemAndMulCMD_in_u         6'd22
`define MemAndMulCMD_in_k         6'd23

`define MemAndMulCMD_out_BRowFirst 6'd24
`define MemAndMulCMD_out_BColFirst 6'd25
`define MemAndMulCMD_out_SRowFirst_DBG 6'd26 /* only 16b of the bus are used, it outputs the internal representation for debug. There is no other way to get any info on the value stored in S, otherwise. */
`define MemAndMulCMD_out_CRowFirst 6'd27
`define MemAndMulCMD_out_SSState   6'd28
`define MemAndMulCMD_out_RNGState  6'd29
`define MemAndMulCMD_out_salt      6'd30
`define MemAndMulCMD_out_seedSE    6'd31
`define MemAndMulCMD_out_pkh       6'd32
`define MemAndMulCMD_out_u         6'd33
`define MemAndMulCMD_out_k         6'd34

`define MemAndMulCMD_SIZE       7 /* 1 bit isPack + 6 bit main cmd */
`define MemAndMulCMD_FULLSIZE  35
`define MemAndMulCMD_mask_op       35'h00000007F
`define MemAndMulCMD_mask_inOp     35'h000001F80
`define MemAndMulCMD_mask_opMul1   35'h000000283
`define MemAndMulCMD_mask_opMul    35'h000000383
`define MemAndMulCMD_mask_opNoMul  35'h000001C7C
`define MemAndMulCMD_mask_in       35'h000FFE000
`define MemAndMulCMD_mask_out      35'h7FF000000
`define MemAndMulCMD_mask_conflictIn   (`MemAndMulCMD_mask_in  | `MemAndMulCMD_mask_op | `MemAndMulCMD_mask_inOp)
`define MemAndMulCMD_mask_conflictOut  (`MemAndMulCMD_mask_out | `MemAndMulCMD_mask_op | `MemAndMulCMD_mask_inOp)
`define MemAndMulCMD_mask_zero     35'h0




module encode(
    input [4-1:0] in,
    output [16-1:0] out,
    input [`MemCONF_lenSec_size-1:0] config_lenSec
  );
  assign out = (config_lenSec[0] ? {1'b0, in[0+:2], 13'b0} : 16'b0)
             | (config_lenSec[1] ? {      in[0+:3], 13'b0} : 16'b0)
             | (config_lenSec[2] ? {      in[0+:4], 12'b0} : 16'b0);
endmodule


module encode4(
    input [4*4-1:0] in,
    output [16*4-1:0] out,
    input [`MemCONF_lenSec_size-1:0] config_lenSec
  );
  encode e0(in[0*4+:4], out[0*16+:16], config_lenSec);
  encode e1(in[1*4+:4], out[1*16+:16], config_lenSec);
  encode e2(in[2*4+:4], out[2*16+:16], config_lenSec);
  encode e3(in[3*4+:4], out[3*16+:16], config_lenSec);
endmodule


module decode(
    input [16-1:0] in,
    output [4-1:0] out,
    input [`MemCONF_lenSec_size-1:0] config_lenSec
  );
  wire ignore = in[11-1:0];

  assign out = (config_lenSec[0] ? {2'b0, (in[14:12] + 3'b1) >> 1} : 4'b0)
             | (config_lenSec[1] ? {1'b0, (in[15:12] + 4'b1) >> 1} : 4'b0)
             | (config_lenSec[2] ? {      (in[15:11] + 5'b1) >> 1} : 4'b0);
endmodule

module decode8(
    input [16*8-1:0] in,
    output [4*8-1:0] out,
    input [`MemCONF_lenSec_size-1:0] config_lenSec
  );
  decode d0(in[0*16+:16], out[0*4+:4], config_lenSec);
  decode d1(in[1*16+:16], out[1*4+:4], config_lenSec);
  decode d2(in[2*16+:16], out[2*4+:4], config_lenSec);
  decode d3(in[3*16+:16], out[3*4+:4], config_lenSec);
  decode d4(in[4*16+:16], out[4*4+:4], config_lenSec);
  decode d5(in[5*16+:16], out[5*4+:4], config_lenSec);
  decode d6(in[6*16+:16], out[6*4+:4], config_lenSec);
  decode d7(in[7*16+:16], out[7*4+:4], config_lenSec);
endmodule

`define MEMANDMUL__CORE__MAX_NUM_STATES 3


module memAndMul__core(
    input fast_owner,
    input [13:0] fast_r_index, fast_w_index,
    input fast_r_secret, fast_r_secret_col, fast_r_b, fast_w_b,
    output [39:0] fast_s_col_data,
    input [511:0] fast_w_data,
    output [159:0] fast_s_data,
    output [511:0] fast_b_data,

    input [`MemAndMulCMD_FULLSIZE-1:0] currentCmd,
    input currentCmd_in_isFirstCycle,
    input currentCmd_out_isFirstCycle,
    output currentCmd_in_isLastCycle,
    output currentCmd_out_isLastCycle, // the bus_out__d2 can output after this is active as this is to start new commands

    input bus_in_isReady,
    input [64-1:0] bus_in,
    output bus_in_canReceive,
    output bus_in_isLast,

    input bus_out_canReceive,
    output [64-1:0] bus_out__d2,

    input [`MemCONF_matrixNumBlocks_size-1:0] config_matrixNumBlocks, // how many 8x8 matrixes are in B and S. The FrodoKEM parameter/8.
    input config_SUseHalfByte,
    input [`MemCONF_lenSec_size-1:0] config_lenSec,
    input [`MemCONF_lenSE_size-1:0] config_lenSE,
    input [`MemCONF_lenSalt_size-1:0] config_lenSalt,

    input rst,
    input clk
  );

  wire isAnyOP = | (currentCmd & ~`MemAndMulCMD_mask_in & ~`MemAndMulCMD_mask_out);
  
  
  // state
  wire [`MEMANDMUL__CORE__MAX_NUM_STATES-1:0] state;
  wor [$clog2(`MEMANDMUL__CORE__MAX_NUM_STATES+1)-1:0] state__numStates;
  wire state__isLast;
  wire state__hasAny;
  wire state__consume;
  counter_bus_state #(.MAX_NUM_STEPS(`MEMANDMUL__CORE__MAX_NUM_STATES)) state__counter (
    .restart(isAnyOP),
    .numStates(state__numStates),
    .isLast(state__isLast),
    .hasAny(state__hasAny),
    .state(state),
    .consume(state__consume),
    .rst(rst),
    .clk(clk)
  );
  wire state__consume__d1;
  delay state__consume__ff (state__consume, state__consume__d1, rst, clk);
  wire state__isFirstCycle = isAnyOP & currentCmd_in_isFirstCycle
                           | state__consume__d1 & state__hasAny;


  // index handler module
  wor [`MemAndMulIndexCMD_SIZE-1:0] indexHandler__currentCmd;
  wor indexHandler__currentCmd_in_isFirstCycle = isAnyOP ? state__isFirstCycle : currentCmd_in_isFirstCycle;
  wor indexHandler__currentCmd_out_isFirstCycle = isAnyOP ? state__isFirstCycle : currentCmd_out_isFirstCycle;
  wire indexHandler__currentCmd_in_isLastCycle;
  wire indexHandler__currentCmd_out_isLastCycle;
  wire [14-1:0] indexHandler__r_index;
  wire [14-1:0] indexHandler__r_index_next;
  wire indexHandler__r_index_hasNext;
  wire [14-1:0] indexHandler__w_index;
  wire [14-1:0] indexHandler__w_index_next;
  wire indexHandler__w_index_hasNext;
  wire indexHandler__r_index__useIndex1;
  wire indexHandler__index1__toggle;
  wire indexHandler__r_enable;
  wire indexHandler__r_enable__d2;
  wire indexHandler__w_enable;
  wor indexHandler__bus_in_isReady = bus_in_isReady;
  wor indexHandler__bus_out_canReceive = bus_out_canReceive;
  wor indexHandler__currentCmd_inOp_splitIn;
  wire indexHandler__bus_in_canReceive;
  wire indexHandler__bus_in_isLast;
  wor bus_in_canReceive__disable;
  assign bus_in_canReceive = indexHandler__bus_in_canReceive & ~ bus_in_canReceive__disable;
  assign bus_in_isLast = indexHandler__bus_in_isLast & ~ bus_in_canReceive__disable;
  memAndMul__indexHandler indexHandler(
    .currentCmd(indexHandler__currentCmd),
    .currentCmd_in_isFirstCycle(indexHandler__currentCmd_in_isFirstCycle),
    .currentCmd_out_isFirstCycle(indexHandler__currentCmd_out_isFirstCycle),
    .currentCmd_in_isLastCycle(indexHandler__currentCmd_in_isLastCycle),
    .currentCmd_out_isLastCycle(indexHandler__currentCmd_out_isLastCycle),
    .currentCmd_inOp_splitIn(indexHandler__currentCmd_inOp_splitIn),

    .bus_in_canReceive(indexHandler__bus_in_canReceive),
    .bus_in_isLast(indexHandler__bus_in_isLast),
    .bus_in_isReady(indexHandler__bus_in_isReady),
    .bus_out_canReceive(indexHandler__bus_out_canReceive),

    .r_index(indexHandler__r_index),
    .r_index_next(indexHandler__r_index_next),
    .r_index_hasNext(indexHandler__r_index_hasNext),
    .w_index(indexHandler__w_index),
    .w_index_next(indexHandler__w_index_next),
    .w_index_hasNext(indexHandler__w_index_hasNext),

    .r_index__useIndex1(indexHandler__r_index__useIndex1),
    .index1__toggle(indexHandler__index1__toggle),
    .r_enable(indexHandler__r_enable),
    .r_enable__d2(indexHandler__r_enable__d2),
    .w_enable(indexHandler__w_enable),

    .rst(rst),
    .clk(clk)
  );
  assign currentCmd_in_isLastCycle = isAnyOP ? state__isLast : indexHandler__currentCmd_in_isLastCycle;
  assign currentCmd_out_isLastCycle = isAnyOP ? state__isLast : indexHandler__currentCmd_out_isLastCycle;
  assign state__consume = isAnyOP & (indexHandler__currentCmd_in_isLastCycle | indexHandler__currentCmd_out_isLastCycle);

  // adder
  wor [64-1:0] adder__op1;
  wor [64-1:0] adder__op2;
  wor adder__neg2;
  wire [64-1:0] adder__ret;
  genvar j;
  generate
    for (j = 0; j < 4; j=j+1) begin
      assign adder__ret[j*16+:16] = adder__op1[j*16+:16] + (adder__neg2 ? -adder__op2[j*16+:16] : adder__op2[j*16+:16]);
    end
  endgenerate

  // isZero
  wor isNotZero__isFirst;
  wor isNotZero__set;
  wire isNotZero__d1;
  wire isNotZero = isNotZero__set | isNotZero__d1 & ~ isNotZero__isFirst;
  delay isNotZero__ff(isNotZero, isNotZero__d1, rst, clk);
  wor [64-1:0] isNotZero__onTrue;
  wor [64-1:0] isNotZero__onFalse;
  wire [64-1:0] isNotZero__ret = isNotZero ? isNotZero__onTrue : isNotZero__onFalse;

  // main memory module
  wor mainMemory__w_bus__useAdder;
  wor mainMemory__w_bus__toZero;
  wor mainMemory__w_bus__useIsNotZero;
  wire [64-1:0] mainMemory__w_bus = mainMemory__w_bus__useAdder               ? adder__ret
                                  : mainMemory__w_bus__useIsNotZero           ? isNotZero__ret
                                  : mainMemory__w_bus__toZero                 ? 64'b0
                                                                              : bus_in;

  wor [`MainMemCMD_SIZE-1:0] mainMemory__r_bus_cmd;
  wor [`MainMemCMD_SIZE-1:0] mainMemory__w_bus_cmd;

  wire [16*4-1:0] mainMemory__r_bus__d2;
  assign bus_out__d2 = mainMemory__r_bus__d2;

  wor mainMemory__r_dubBus_B_col;
  wor mainMemory__r_dubBus_C_col;
  wor mainMemory__r_dubBus_C_row;
  wor mainMemory__r_paralSBus_S_mat;
  wor mainMemory__r_paral_B_mat;
  wor mainMemory__r_paral_C_mat;
  wor mainMemory__r_SBus_S_col;
  wor mainMemory__r_quarterBus_U_halfRow;
  wor mainMemory__w_dubBus_B_col;
  wor mainMemory__w_dubBus_C_col;
  wor mainMemory__w_paral_B_mat;
  wor mainMemory__w_paral_C_mat;
  wor mainMemory__w_halfBus_U_row;

  wire [16*8-1:0] mainMemory__r_dubBus__d2;
  wire [16*4*8-1:0] mainMemory__r_paral__d2;
  wire [5*4*8-1:0] mainMemory__r_paralSBus__d2;
  wire [5*8-1:0] mainMemory__r_SBus__d2;
  wire [4*4-1:0] mainMemory__r_quarterBus__d2;
  wire [16*8-1:0] mainMemory__w_dubBus;
  wire [16*4*8-1:0] mainMemory__w_paral;
  wire [4*8-1:0] mainMemory__w_halfBus;
  assign fast_s_data = mainMemory__r_paralSBus__d2;
  assign fast_s_col_data = mainMemory__r_SBus__d2;
  assign fast_b_data = mainMemory__r_paral__d2;
  mainMem mainMemory(
    .r_bus__d2(mainMemory__r_bus__d2),
    .w_bus(fast_owner ? 64'd0 : mainMemory__w_bus),

    .r_index(fast_owner ? fast_r_index : indexHandler__r_index),
    .r_index_next(indexHandler__r_index_next),
    .r_index_hasNext(indexHandler__r_index_hasNext),
    .w_index(fast_owner ? fast_w_index : indexHandler__w_index),
    .w_index_next(indexHandler__w_index_next),
    .w_index_hasNext(indexHandler__w_index_hasNext),

    .r_bus_cmd(fast_owner ? 0 : mainMemory__r_bus_cmd),
    .w_bus_cmd(fast_owner ? 0 : mainMemory__w_bus_cmd),

    .r_dubBus_B_col(fast_owner ? 1'b0 : mainMemory__r_dubBus_B_col),
    .r_dubBus_C_col(fast_owner ? 1'b0 : mainMemory__r_dubBus_C_col),
    .r_dubBus_C_row(fast_owner ? 1'b0 : mainMemory__r_dubBus_C_row),
    .r_paralSBus_S_mat(fast_owner ? fast_r_secret : mainMemory__r_paralSBus_S_mat),
    .r_paral_B_mat(fast_owner ? fast_r_b : mainMemory__r_paral_B_mat),
    .r_paral_C_mat(fast_owner ? 1'b0 : mainMemory__r_paral_C_mat),
    .r_SBus_S_col(fast_owner ? fast_r_secret_col : mainMemory__r_SBus_S_col),
    .r_quarterBus_U_halfRow(fast_owner ? 1'b0 : mainMemory__r_quarterBus_U_halfRow),

    .r_dubBus__d2(mainMemory__r_dubBus__d2),
    .r_paral__d2(mainMemory__r_paral__d2),
    .r_SBus__d2(mainMemory__r_SBus__d2),
    .r_paralSBus__d2(mainMemory__r_paralSBus__d2),
    .r_quarterBus__d2(mainMemory__r_quarterBus__d2),

    .w_dubBus_B_col(fast_owner ? 1'b0 : mainMemory__w_dubBus_B_col),
    .w_dubBus_C_col(fast_owner ? 1'b0 : mainMemory__w_dubBus_C_col),
    .w_paral_B_mat(fast_owner ? fast_w_b : mainMemory__w_paral_B_mat),
    .w_paral_C_mat(fast_owner ? 1'b0 : mainMemory__w_paral_C_mat),
    .w_halfBus_U_row(fast_owner ? 1'b0 : mainMemory__w_halfBus_U_row),

    .w_dubBus(mainMemory__w_dubBus),
    .w_paral(fast_owner ? fast_w_data : mainMemory__w_paral),
    .w_halfBus(mainMemory__w_halfBus),

    .config_matrixNumBlocks(config_matrixNumBlocks),
    .config_SUseHalfByte(config_SUseHalfByte),
    .config_lenSec(config_lenSec),
    .config_lenSE(config_lenSE),
    .config_lenSalt(config_lenSalt),

    .rst(rst),
    .clk(clk)
  );

  //  mul module
  wor [16*4-1:0] m__a__d2;
  wire [128-1:0] m__outVec;
  wor m__isMatrixMul2__d2;
  wire m__isMatrixMul1__d2 = ~m__isMatrixMul2__d2;
  wor m__isNeg__d2;
  wire m__isPos__d2 = ~m__isNeg__d2;
  
  wor m__doOp;
  wire m__doOp__d1;
  delay m__doOp__ff1 (m__doOp, m__doOp__d1, rst, clk);
  wire m__doOp__d2;
  delay m__doOp__ff2 (m__doOp__d1, m__doOp__d2, rst, clk);

  wire m__setStorage = ~indexHandler__r_index__useIndex1;
  wire m__setStorage__d1;
  delay m__setStorage__ff2 (m__setStorage, m__setStorage__d1, rst, clk);
  wire m__setStorage__d2;
  delay m__setStorage__ff1 (m__setStorage__d1, m__setStorage__d2, rst, clk);
  frodoMul m(
    .a(m__a__d2),
    .accVec(mainMemory__r_dubBus__d2),
    .sCol(mainMemory__r_SBus__d2),
    .sMat(mainMemory__r_paralSBus__d2),
    .accMat(mainMemory__r_paral__d2),
    .outMat(mainMemory__w_paral),
    .outVec(m__outVec),
    .isMatrixMul1(m__isMatrixMul1__d2),
    .isPos(m__isPos__d2),
    .setStorage(m__setStorage__d2),
    .doOp(m__doOp__d2),
    .rst(rst),
    .clk(clk)
  );
  assign mainMemory__w_dubBus = m__outVec;
  decode8 decode(m__outVec, mainMemory__w_halfBus, config_lenSec);

  // encoding and delayed in bus
  wor r_encoded_U__d2d3__doDelay;
  wire [4*4-1:0] r_quarterBus__d2d3;
  optionalDelay #(16) r_quarterBus__ff (r_encoded_U__d2d3__doDelay, mainMemory__r_quarterBus__d2, r_quarterBus__d2d3, rst, clk);
  wire [16*4-1:0] r_encoded_U__d2d3;
  encode4 encode(r_quarterBus__d2d3, r_encoded_U__d2d3, config_lenSec);

  wire [64-1:0] bus_in__d1;
  delay #(64) bus_inOp__ff1 (bus_in, bus_in__d1, rst, clk);
  wire [64-1:0] bus_in__d2;
  delay #(64) bus_inOp__ff2 (bus_in__d1, bus_in__d2, rst, clk);

  wire [64-1:0] mainMemory__r_bus__d3;
  delay #(64) mainMemory__r_bus__ff (mainMemory__r_bus__d2, mainMemory__r_bus__d3, rst, clk);

  assign indexHandler__currentCmd = (currentCmd & `MemAndMulCMD_mask_in) != 0 ? `MemAndMulIndexCMD_in : {`MemAndMulIndexCMD_SIZE{1'b0}};
  assign mainMemory__w_bus_cmd[`MainMemCMD_bus_B_row] = currentCmd[`MemAndMulCMD_in_BRowFirst] & bus_in_isReady;
  assign mainMemory__w_bus_cmd[`MainMemCMD_bus_B_col] = currentCmd[`MemAndMulCMD_in_BColFirst] & bus_in_isReady;
  assign mainMemory__w_bus_cmd[`MainMemCMD_bus_C_row] = currentCmd[`MemAndMulCMD_in_CRowFirst] & bus_in_isReady;
  assign mainMemory__w_bus_cmd[`MainMemCMD_bus_S_row] = currentCmd[`MemAndMulCMD_in_SRowFirst] & bus_in_isReady;
  assign mainMemory__w_bus_cmd[`MainMemCMD_bus_SSState] = currentCmd[`MemAndMulCMD_in_SSState] & bus_in_isReady;
  assign mainMemory__w_bus_cmd[`MainMemCMD_bus_RNGState] = currentCmd[`MemAndMulCMD_in_RNGState] & bus_in_isReady;
  assign mainMemory__w_bus_cmd[`MainMemCMD_bus_salt] = currentCmd[`MemAndMulCMD_in_salt] & bus_in_isReady;
  assign mainMemory__w_bus_cmd[`MainMemCMD_bus_seedSE] = currentCmd[`MemAndMulCMD_in_seedSE] & bus_in_isReady;
  assign mainMemory__w_bus_cmd[`MainMemCMD_bus_pkh] = currentCmd[`MemAndMulCMD_in_pkh] & bus_in_isReady;
  assign mainMemory__w_bus_cmd[`MainMemCMD_bus_k] = currentCmd[`MemAndMulCMD_in_k] & bus_in_isReady;
  assign mainMemory__w_bus_cmd[`MainMemCMD_bus_u] = currentCmd[`MemAndMulCMD_in_u] & bus_in_isReady;

  assign indexHandler__currentCmd = (currentCmd & `MemAndMulCMD_mask_out) != 0 ? `MemAndMulIndexCMD_out : {`MemAndMulIndexCMD_SIZE{1'b0}};
  assign mainMemory__r_bus_cmd[`MainMemCMD_bus_B_row] = currentCmd[`MemAndMulCMD_out_BRowFirst] & bus_out_canReceive;
  assign mainMemory__r_bus_cmd[`MainMemCMD_bus_B_col] = currentCmd[`MemAndMulCMD_out_BColFirst] & bus_out_canReceive;
  assign mainMemory__r_bus_cmd[`MainMemCMD_bus_C_row] = currentCmd[`MemAndMulCMD_out_CRowFirst] & bus_out_canReceive;
  assign mainMemory__r_bus_cmd[`MainMemCMD_bus_S_row] = currentCmd[`MemAndMulCMD_out_SRowFirst_DBG] & bus_out_canReceive;
  assign mainMemory__r_bus_cmd[`MainMemCMD_bus_SSState] = currentCmd[`MemAndMulCMD_out_SSState] & bus_out_canReceive;
  assign mainMemory__r_bus_cmd[`MainMemCMD_bus_RNGState] = currentCmd[`MemAndMulCMD_out_RNGState] & bus_out_canReceive;
  assign mainMemory__r_bus_cmd[`MainMemCMD_bus_salt] = currentCmd[`MemAndMulCMD_out_salt] & bus_out_canReceive;
  assign mainMemory__r_bus_cmd[`MainMemCMD_bus_seedSE] = currentCmd[`MemAndMulCMD_out_seedSE] & bus_out_canReceive;
  assign mainMemory__r_bus_cmd[`MainMemCMD_bus_pkh] = currentCmd[`MemAndMulCMD_out_pkh] & bus_out_canReceive;
  assign mainMemory__r_bus_cmd[`MainMemCMD_bus_k] = currentCmd[`MemAndMulCMD_out_k] & bus_out_canReceive;
  assign mainMemory__r_bus_cmd[`MainMemCMD_bus_u] = currentCmd[`MemAndMulCMD_out_u] & bus_out_canReceive;

  assign state__numStates                             = currentCmd[`MemAndMulCMD_op_CpleqStimesBT] ? 1 : 0;
  assign indexHandler__currentCmd                     = currentCmd[`MemAndMulCMD_op_CpleqStimesBT] ? `MemAndMulIndexCMD_updateFastMemMem : {`MemAndMulIndexCMD_SIZE{1'b0}};
  assign mainMemory__w_dubBus_C_col                   = currentCmd[`MemAndMulCMD_op_CpleqStimesBT] & indexHandler__w_enable;
  assign mainMemory__r_dubBus_C_col                   = currentCmd[`MemAndMulCMD_op_CpleqStimesBT] & ~indexHandler__r_index__useIndex1;
  assign mainMemory__r_bus_cmd[`MainMemCMD_bus_B_row] = currentCmd[`MemAndMulCMD_op_CpleqStimesBT] & indexHandler__r_index__useIndex1 & ~indexHandler__index1__toggle;
  assign mainMemory__r_paralSBus_S_mat                = currentCmd[`MemAndMulCMD_op_CpleqStimesBT] & indexHandler__r_index__useIndex1 & indexHandler__index1__toggle;
  assign m__doOp                                      = currentCmd[`MemAndMulCMD_op_CpleqStimesBT] & indexHandler__r_index__useIndex1 & indexHandler__index1__toggle & indexHandler__r_enable;
  assign m__a__d2                                     = currentCmd[`MemAndMulCMD_op_CpleqStimesBT] ? mainMemory__r_bus__d3 : 64'b0;

  assign state__numStates                             = currentCmd[`MemAndMulCMD_op_UeqCminBtimesS] ? 1 : 0;
  assign indexHandler__currentCmd                     = currentCmd[`MemAndMulCMD_op_UeqCminBtimesS] ? `MemAndMulIndexCMD_updateFastMemMem : {`MemAndMulIndexCMD_SIZE{1'b0}};
  assign mainMemory__w_halfBus_U_row                  = currentCmd[`MemAndMulCMD_op_UeqCminBtimesS] & indexHandler__w_enable;
  assign mainMemory__r_dubBus_C_row                   = currentCmd[`MemAndMulCMD_op_UeqCminBtimesS] & ~indexHandler__r_index__useIndex1;
  assign mainMemory__r_bus_cmd[`MainMemCMD_bus_B_row] = currentCmd[`MemAndMulCMD_op_UeqCminBtimesS] & indexHandler__r_index__useIndex1 & ~indexHandler__index1__toggle;
  assign mainMemory__r_paralSBus_S_mat                = currentCmd[`MemAndMulCMD_op_UeqCminBtimesS] & indexHandler__r_index__useIndex1 & indexHandler__index1__toggle;
  assign m__doOp                                      = currentCmd[`MemAndMulCMD_op_UeqCminBtimesS] & indexHandler__r_index__useIndex1 & indexHandler__index1__toggle & indexHandler__r_enable;
  assign m__isNeg__d2                                 = currentCmd[`MemAndMulCMD_op_UeqCminBtimesS];
  assign m__a__d2                                     = currentCmd[`MemAndMulCMD_op_UeqCminBtimesS] ? mainMemory__r_bus__d3 : 64'b0;

  assign state__numStates              = currentCmd[`MemAndMulCMD_inOp_BpleqStimesInAT] ? 1 : 0;
  assign indexHandler__currentCmd      = currentCmd[`MemAndMulCMD_inOp_BpleqStimesInAT] ? `MemAndMulIndexCMD_updateFastMemIn : {`MemAndMulIndexCMD_SIZE{1'b0}};
  assign mainMemory__w_dubBus_B_col    = currentCmd[`MemAndMulCMD_inOp_BpleqStimesInAT] & indexHandler__w_enable;
  assign mainMemory__r_dubBus_B_col    = currentCmd[`MemAndMulCMD_inOp_BpleqStimesInAT] & ~indexHandler__r_index__useIndex1;
  assign mainMemory__r_paralSBus_S_mat = currentCmd[`MemAndMulCMD_inOp_BpleqStimesInAT] & indexHandler__r_index__useIndex1;
  assign m__doOp                       = currentCmd[`MemAndMulCMD_inOp_BpleqStimesInAT] & indexHandler__r_index__useIndex1 & indexHandler__r_enable;
  assign m__a__d2                      = currentCmd[`MemAndMulCMD_inOp_BpleqStimesInAT] ? bus_in__d2 : 64'b0;
  assign indexHandler__currentCmd_inOp_splitIn = currentCmd[`MemAndMulCMD_inOp_BpleqStimesInAT];

  assign state__numStates              = currentCmd[`MemAndMulCMD_inOp_CpleqStimesInBT] ? 1 : 0;
  assign indexHandler__currentCmd      = currentCmd[`MemAndMulCMD_inOp_CpleqStimesInBT] ? `MemAndMulIndexCMD_updateSlowMemIn : {`MemAndMulIndexCMD_SIZE{1'b0}};
  assign mainMemory__w_paral_C_mat     = currentCmd[`MemAndMulCMD_inOp_CpleqStimesInBT] & indexHandler__w_enable;
  assign mainMemory__r_SBus_S_col      = currentCmd[`MemAndMulCMD_inOp_CpleqStimesInBT] & ~indexHandler__r_index__useIndex1;
  assign mainMemory__r_paral_C_mat     = currentCmd[`MemAndMulCMD_inOp_CpleqStimesInBT] & indexHandler__r_index__useIndex1;
  assign m__doOp                       = currentCmd[`MemAndMulCMD_inOp_CpleqStimesInBT] & indexHandler__r_index__useIndex1;
  assign m__a__d2                      = currentCmd[`MemAndMulCMD_inOp_CpleqStimesInBT] ? bus_in__d2 : 64'b0;
  assign m__isMatrixMul2__d2           = currentCmd[`MemAndMulCMD_inOp_CpleqStimesInBT];

  assign state__numStates            = currentCmd[`MemAndMulCMD_inOp_BpleqStimesInA] ? 1 : 0;
  assign indexHandler__currentCmd    = currentCmd[`MemAndMulCMD_inOp_BpleqStimesInA] ? `MemAndMulIndexCMD_updateSlowMemIn : {`MemAndMulIndexCMD_SIZE{1'b0}};
  assign mainMemory__w_paral_B_mat   = currentCmd[`MemAndMulCMD_inOp_BpleqStimesInA] & indexHandler__w_enable;
  assign mainMemory__r_SBus_S_col    = currentCmd[`MemAndMulCMD_inOp_BpleqStimesInA] & ~indexHandler__r_index__useIndex1;
  assign mainMemory__r_paral_B_mat   = currentCmd[`MemAndMulCMD_inOp_BpleqStimesInA] & indexHandler__r_index__useIndex1;
  assign m__doOp                     = currentCmd[`MemAndMulCMD_inOp_BpleqStimesInA] & indexHandler__r_index__useIndex1;
  assign m__isMatrixMul2__d2         = currentCmd[`MemAndMulCMD_inOp_BpleqStimesInA];
  assign m__a__d2                    = currentCmd[`MemAndMulCMD_inOp_BpleqStimesInA] ? bus_in__d2 : 64'b0;
  assign indexHandler__currentCmd_inOp_splitIn = currentCmd[`MemAndMulCMD_inOp_BpleqStimesInA];

  assign state__numStates                             = currentCmd[`MemAndMulCMD_op_CeqUminC] ? 1 : 0;
  assign indexHandler__currentCmd                     = currentCmd[`MemAndMulCMD_op_CeqUminC] ? `MemAndMulIndexCMD_updateSyncMem : {`MemAndMulIndexCMD_SIZE{1'b0}};
  assign mainMemory__w_bus_cmd[`MainMemCMD_bus_C_row] = currentCmd[`MemAndMulCMD_op_CeqUminC] & indexHandler__w_enable;
  assign mainMemory__r_bus_cmd[`MainMemCMD_bus_C_row] = currentCmd[`MemAndMulCMD_op_CeqUminC] & indexHandler__index1__toggle;
  assign mainMemory__r_quarterBus_U_halfRow           = currentCmd[`MemAndMulCMD_op_CeqUminC] & ~indexHandler__index1__toggle;
  assign mainMemory__w_bus__useAdder                  = currentCmd[`MemAndMulCMD_op_CeqUminC];
  assign r_encoded_U__d2d3__doDelay                   = currentCmd[`MemAndMulCMD_op_CeqUminC];
  assign adder__op1                                   = currentCmd[`MemAndMulCMD_op_CeqUminC] ? r_encoded_U__d2d3 : 64'b0;
  assign adder__op2                                   = currentCmd[`MemAndMulCMD_op_CeqUminC] ? mainMemory__r_bus__d2 : 64'b0;
  assign adder__neg2                                  = currentCmd[`MemAndMulCMD_op_CeqUminC];

  assign state__numStates                             = currentCmd[`MemAndMulCMD_op_CeqU] ? 1 : 0;
  assign indexHandler__currentCmd                     = currentCmd[`MemAndMulCMD_op_CeqU] ? `MemAndMulIndexCMD_updateSync : {`MemAndMulIndexCMD_SIZE{1'b0}};
  assign mainMemory__w_bus_cmd[`MainMemCMD_bus_C_row] = currentCmd[`MemAndMulCMD_op_CeqU] & indexHandler__w_enable;
  assign mainMemory__r_quarterBus_U_halfRow           = currentCmd[`MemAndMulCMD_op_CeqU];
  assign mainMemory__w_bus__useAdder                  = currentCmd[`MemAndMulCMD_op_CeqU];
  assign adder__op1                                   = currentCmd[`MemAndMulCMD_op_CeqU] ? r_encoded_U__d2d3 : 64'b0;

  assign state__numStates                             = currentCmd[`MemAndMulCMD_inOp_BeqInMinB] ? 1 : 0;
  assign indexHandler__currentCmd                     = currentCmd[`MemAndMulCMD_inOp_BeqInMinB] ? `MemAndMulIndexCMD_updateSyncIn : {`MemAndMulIndexCMD_SIZE{1'b0}};
  assign mainMemory__w_bus_cmd[`MainMemCMD_bus_B_row] = currentCmd[`MemAndMulCMD_inOp_BeqInMinB] & indexHandler__w_enable;
  assign mainMemory__r_bus_cmd[`MainMemCMD_bus_B_row] = currentCmd[`MemAndMulCMD_inOp_BeqInMinB];
  assign mainMemory__w_bus__useAdder                  = currentCmd[`MemAndMulCMD_inOp_BeqInMinB];
  assign adder__op1                                   = currentCmd[`MemAndMulCMD_inOp_BeqInMinB] ? bus_in__d2 : 64'b0;
  assign adder__op2                                   = currentCmd[`MemAndMulCMD_inOp_BeqInMinB] ? mainMemory__r_bus__d2 : 64'b0;
  assign adder__neg2                                  = currentCmd[`MemAndMulCMD_inOp_BeqInMinB];

  assign state__numStates                             = currentCmd[`MemAndMulCMD_inOp_addCRowFirst] ? 1 : 0;
  assign indexHandler__currentCmd                     = currentCmd[`MemAndMulCMD_inOp_addCRowFirst] ? `MemAndMulIndexCMD_updateSyncIn : {`MemAndMulIndexCMD_SIZE{1'b0}};
  assign mainMemory__w_bus_cmd[`MainMemCMD_bus_C_row] = currentCmd[`MemAndMulCMD_inOp_addCRowFirst] & indexHandler__w_enable;
  assign mainMemory__r_bus_cmd[`MainMemCMD_bus_C_row] = currentCmd[`MemAndMulCMD_inOp_addCRowFirst];
  assign mainMemory__w_bus__useAdder                  = currentCmd[`MemAndMulCMD_inOp_addCRowFirst];
  assign adder__op1                                   = currentCmd[`MemAndMulCMD_inOp_addCRowFirst] ? bus_in__d2 : 64'b0;
  assign adder__op2                                   = currentCmd[`MemAndMulCMD_inOp_addCRowFirst] ? mainMemory__r_bus__d2 : 64'b0;

  wire [16-1:0] cmpMask = config_lenSec[0] == 1'b1 ? 16'h7FFF : 16'hFFFF;

  assign state__numStates                             = currentCmd[`MemAndMulCMD_inOp_selectKey] ? 3 : 0;
  assign indexHandler__currentCmd          = currentCmd[`MemAndMulCMD_inOp_selectKey] & state[0] ? `MemAndMulIndexCMD_out : {`MemAndMulIndexCMD_SIZE{1'b0}};
  assign indexHandler__bus_out_canReceive  = currentCmd[`MemAndMulCMD_inOp_selectKey] & state[0];
  assign mainMemory__r_dubBus_B_col        = currentCmd[`MemAndMulCMD_inOp_selectKey] & state[0];
  assign isNotZero__isFirst                = currentCmd[`MemAndMulCMD_inOp_selectKey] & state[0] & state__isFirstCycle;
  assign isNotZero__set                    = currentCmd[`MemAndMulCMD_inOp_selectKey] & state[0] & indexHandler__r_enable__d2 & (mainMemory__r_dubBus__d2 & {8{cmpMask}}) != 0;
  assign indexHandler__currentCmd              = currentCmd[`MemAndMulCMD_inOp_selectKey] & state[1] ? `MemAndMulIndexCMD_out : {`MemAndMulIndexCMD_SIZE{1'b0}};
  assign indexHandler__bus_out_canReceive      = currentCmd[`MemAndMulCMD_inOp_selectKey] & state[1];
  assign mainMemory__r_dubBus_C_col            = currentCmd[`MemAndMulCMD_inOp_selectKey] & state[1];
  assign isNotZero__set                        = currentCmd[`MemAndMulCMD_inOp_selectKey] & state[1] & indexHandler__r_enable__d2 & (mainMemory__r_dubBus__d2 & {8{cmpMask}}) != 0;
  assign indexHandler__currentCmd                 = currentCmd[`MemAndMulCMD_inOp_selectKey] & state[2] ? `MemAndMulIndexCMD_updateSyncIn : {`MemAndMulIndexCMD_SIZE{1'b0}};
  assign mainMemory__w_bus_cmd[`MainMemCMD_bus_k] = currentCmd[`MemAndMulCMD_inOp_selectKey] & state[2] & indexHandler__w_enable;
  assign mainMemory__r_bus_cmd[`MainMemCMD_bus_k] = currentCmd[`MemAndMulCMD_inOp_selectKey] & state[2];
  assign mainMemory__w_bus__useIsNotZero          = currentCmd[`MemAndMulCMD_inOp_selectKey] & state[2];
  assign isNotZero__onTrue                        = currentCmd[`MemAndMulCMD_inOp_selectKey] & state[2] ? bus_in__d2 : 64'b0;
  assign isNotZero__onFalse                       = currentCmd[`MemAndMulCMD_inOp_selectKey] & state[2] ? mainMemory__r_bus__d2 : 64'b0;

  assign state__numStates                             = currentCmd[`MemAndMulCMD_op_Erase1] ? 1 : 0;
  assign indexHandler__currentCmd                     = currentCmd[`MemAndMulCMD_op_Erase1] ? `MemAndMulIndexCMD_in : {`MemAndMulIndexCMD_SIZE{1'b0}};
  assign indexHandler__bus_in_isReady                 = currentCmd[`MemAndMulCMD_op_Erase1];
  assign bus_in_canReceive__disable                   = currentCmd[`MemAndMulCMD_op_Erase1];
  assign mainMemory__w_bus_cmd[`MainMemCMD_bus_S_row] = currentCmd[`MemAndMulCMD_op_Erase1] & indexHandler__w_enable;
  assign mainMemory__w_bus__toZero                    = currentCmd[`MemAndMulCMD_op_Erase1];

  assign state__numStates                                 = currentCmd[`MemAndMulCMD_op_Erase2] ? 3 : 0;
  assign mainMemory__w_bus__toZero                        = currentCmd[`MemAndMulCMD_op_Erase2];
  assign indexHandler__currentCmd                         = currentCmd[`MemAndMulCMD_op_Erase2] ? `MemAndMulIndexCMD_in : {`MemAndMulIndexCMD_SIZE{1'b0}};
  assign indexHandler__bus_in_isReady                     = currentCmd[`MemAndMulCMD_op_Erase2];
  assign bus_in_canReceive__disable                       = currentCmd[`MemAndMulCMD_op_Erase2];
  assign mainMemory__w_bus_cmd[`MainMemCMD_bus_u]         = currentCmd[`MemAndMulCMD_op_Erase2] & state[0] & indexHandler__w_enable;
  assign mainMemory__w_bus_cmd[`MainMemCMD_bus_seedSE]    = currentCmd[`MemAndMulCMD_op_Erase2] & state[1] & indexHandler__w_enable;
  assign mainMemory__w_bus_cmd[`MainMemCMD_bus_k]         = currentCmd[`MemAndMulCMD_op_Erase2] & state[2] & indexHandler__w_enable;

  assign state__numStates                             = currentCmd[`MemAndMulCMD_op_Erase3] ? 2 : 0;
  assign mainMemory__w_bus__toZero                    = currentCmd[`MemAndMulCMD_op_Erase3];
  assign indexHandler__currentCmd                     = currentCmd[`MemAndMulCMD_op_Erase3] ? `MemAndMulIndexCMD_in : {`MemAndMulIndexCMD_SIZE{1'b0}};
  assign indexHandler__bus_in_isReady                 = currentCmd[`MemAndMulCMD_op_Erase3];
  assign bus_in_canReceive__disable                   = currentCmd[`MemAndMulCMD_op_Erase3];
  assign mainMemory__w_bus_cmd[`MainMemCMD_bus_B_row] = currentCmd[`MemAndMulCMD_op_Erase3] & state[0] & indexHandler__w_enable;
  assign mainMemory__w_bus_cmd[`MainMemCMD_bus_C_row] = currentCmd[`MemAndMulCMD_op_Erase3] & state[1] & indexHandler__w_enable;
endmodule


module memAndMul__outAdapter(
    input currentCMD__isOut,
    input currentCmd_out_isLastCycle,

    output bus_in_canReceive,
    input [64-1:0] bus_in__d2,

    output bus_out_isReady,
    output bus_out_isLast,
    output [64-1:0] bus_out,
    input bus_out_canReceive,

    input rst,
    input clk
  );

  wire bus_in_isReady = bus_out_canReceive & currentCMD__isOut;
  assign bus_in_canReceive = bus_in_isReady;
  wire bus_in_isReady__d1;
  delay bus_in_isReady__ff1 (bus_in_isReady, bus_in_isReady__d1, rst, clk);
  wire bus_in_isReady__d2;
  delay bus_in_isReady__ff2 (bus_in_isReady__d1, bus_in_isReady__d2, rst, clk);
  wire bus_in_isLast = currentCmd_out_isLastCycle;
  wire bus_in_isLast__d1;
  delay bus_in_isLast__ff1 (bus_in_isLast, bus_in_isLast__d1, rst, clk);
  wire bus_in_isLast__d2;
  delay bus_in_isLast__ff2 (bus_in_isLast__d1, bus_in_isLast__d2, rst, clk);

  wire [64*2-1:0] buffer;
  wire [64*2-1:0] buffer__a1;
  delay #(64*2) buffer__ff (buffer__a1, buffer, rst, clk);
  wire [2-1:0] buffer_isReady;
  wire [2-1:0] buffer_isReady__a1;
  delay #(2) buffer_isReady__ff (buffer_isReady__a1, buffer_isReady, rst, clk);
  wire [2-1:0] buffer_isLast;
  wire [2-1:0] buffer_isLast__a1;
  delay #(2) buffer_isLast__ff (buffer_isLast__a1, buffer_isLast, rst, clk);

  wire [3-1:0] merged_isReady;
  wire [64*3-1:0] merged;
  wire [3-1:0] merged_isLast;
  assign merged_isReady[0] = buffer_isReady[0] | bus_in_isReady__d2;
  assign merged_isReady[1] = buffer_isReady[1] | (buffer_isReady[0] & bus_in_isReady__d2);
  assign merged_isReady[2] = buffer_isReady[0] & buffer_isReady[1] & bus_in_isReady__d2;
  assign merged_isLast[0] = buffer_isReady[0]  ? buffer_isLast[0]
                          : bus_in_isReady__d2 ? bus_in_isLast__d2
                                               : 1'b0;
  assign merged_isLast[1] = buffer_isReady[1]                      ? buffer_isLast[1]
                          : buffer_isReady[0] & bus_in_isReady__d2 ? bus_in_isLast__d2
                                                                   : 1'b0;
  assign merged_isLast[2] = buffer_isReady[0] & buffer_isReady[1] & bus_in_isReady__d2 ? bus_in_isLast__d2
                                                                                       : 1'b0;
  assign merged[0*64+:64] = buffer_isReady[0]   ? buffer[0*64+:64]
                          : bus_in_isReady__d2  ? bus_in__d2
                                                : 64'b0;
  assign merged[1*64+:64] = buffer_isReady[1]                      ? buffer[1*64+:64]
                          : buffer_isReady[0] & bus_in_isReady__d2 ? bus_in__d2
                                                                   : 64'b0;
  assign merged[2*64+:64] = buffer_isReady[0] & buffer_isReady[1] & bus_in_isReady__d2 ? bus_in__d2
                                                                                       : 1'b0;

  assign bus_out_isReady = bus_out_canReceive ? merged_isReady[0] : 1'b0;
  assign bus_out_isLast = bus_out_canReceive ? merged_isLast[0] : 1'b0;
  assign bus_out = bus_out_canReceive ? merged[0+:64] : 64'b0;

  assign buffer_isReady__a1 = bus_out_canReceive ? merged_isReady[1+:2] : merged_isReady[0+:2];
  assign buffer_isLast__a1 = bus_out_canReceive ? merged_isLast[1+:2] : merged_isLast[0+:2];
  assign buffer__a1 = bus_out_canReceive ? merged[1*64+:64*2] : merged[0*64+:64*2];
endmodule


module memAndMul__unpack16 (
    input [64-1:0] in,
    output [64-1:0] out
  );
  assign out[0*16+:8] = in[0*16+8+:8]; assign out[0*16+8+:8] = in[0*16+:8];
  assign out[1*16+:8] = in[1*16+8+:8]; assign out[1*16+8+:8] = in[1*16+:8];
  assign out[2*16+:8] = in[2*16+8+:8]; assign out[2*16+8+:8] = in[2*16+:8];
  assign out[3*16+:8] = in[3*16+8+:8]; assign out[3*16+8+:8] = in[3*16+:8];
endmodule

module memAndMul__pack16 (
    input [64-1:0] in,
    output [64-1:0] out
  );
  assign out[0*16+:8] = in[0*16+8+:8]; assign out[0*16+8+:8] = in[0*16+:8];
  assign out[1*16+:8] = in[1*16+8+:8]; assign out[1*16+8+:8] = in[1*16+:8];
  assign out[2*16+:8] = in[2*16+8+:8]; assign out[2*16+8+:8] = in[2*16+:8];
  assign out[3*16+:8] = in[3*16+8+:8]; assign out[3*16+8+:8] = in[3*16+:8];
endmodule


module realligner_core #(parameter BLOCK_SIZE = 1, NUM_IN_BLOCKS = 1, NUM_OUT_BLOCKS = 1) (
    in,
    in_canReceive,
    in_isReady,
    out,
    out_canReceive,
    out_isReady,
    in_buff,
    out_buff,
    in_buff_size,
    out_buff_size
  );
  
  localparam NUM_MAX_BLOCKS = NUM_IN_BLOCKS > NUM_OUT_BLOCKS ? NUM_IN_BLOCKS : NUM_OUT_BLOCKS;
  localparam NUM_MAX_BLOCKS_SIZE = $clog2(NUM_MAX_BLOCKS+1);
  localparam NUM_SUM_BLOCKS = NUM_IN_BLOCKS + NUM_OUT_BLOCKS;
  localparam NUM_SUM_BLOCKS_SIZE = $clog2(NUM_SUM_BLOCKS+1);

  input [BLOCK_SIZE*NUM_IN_BLOCKS-1:0] in;
  output in_canReceive;
  input in_isReady;
  output [BLOCK_SIZE*NUM_OUT_BLOCKS-1:0] out;
  input out_canReceive;
  output out_isReady;
  input  [BLOCK_SIZE*NUM_MAX_BLOCKS-1:0] in_buff;
  output [BLOCK_SIZE*NUM_MAX_BLOCKS-1:0] out_buff;
  input  [NUM_MAX_BLOCKS_SIZE-1:0] in_buff_size;
  output [NUM_MAX_BLOCKS_SIZE-1:0] out_buff_size;


  assign in_canReceive = out_canReceive & (in_buff_size < NUM_OUT_BLOCKS);

  wire [BLOCK_SIZE*NUM_SUM_BLOCKS-1:0] combined_in = ((in_isReady ? in : {BLOCK_SIZE*NUM_IN_BLOCKS{1'b0}}) << (BLOCK_SIZE * in_buff_size)) |    in_buff;
  wire [NUM_SUM_BLOCKS_SIZE-1:0] combined_in_size  =  (in_isReady ? NUM_IN_BLOCKS : {NUM_SUM_BLOCKS_SIZE{1'b0}})                           + in_buff_size;

  assign out_isReady = out_canReceive & (combined_in_size >= NUM_OUT_BLOCKS);
  assign out = combined_in[0+:BLOCK_SIZE*NUM_OUT_BLOCKS];

  assign out_buff_size = out_isReady ? combined_in_size - NUM_OUT_BLOCKS
                                     : combined_in_size;
  assign out_buff = out_isReady ? { {BLOCK_SIZE*NUM_OUT_BLOCKS{1'b0}} , combined_in[BLOCK_SIZE*NUM_OUT_BLOCKS+:BLOCK_SIZE*NUM_IN_BLOCKS] }
                                : combined_in[0+:BLOCK_SIZE*NUM_MAX_BLOCKS];
endmodule


module memAndMul__unpack15 (
    input [64-1:0] in,
    input in_isReady,
    output in_canReceive,
    output [64-1:0] out,
    output out_isReady,
    input out_canReceive,
    input rst,
    input clk
  );
  wire [64-1:0] in_w;

  swapBits #(8) si0 (in[0*8+:8], in_w[0*8+:8]);
  swapBits #(8) si1 (in[1*8+:8], in_w[1*8+:8]);
  swapBits #(8) si2 (in[2*8+:8], in_w[2*8+:8]);
  swapBits #(8) si3 (in[3*8+:8], in_w[3*8+:8]);

  swapBits #(8) si4 (in[4*8+:8], in_w[4*8+:8]);
  swapBits #(8) si5 (in[5*8+:8], in_w[5*8+:8]);
  swapBits #(8) si6 (in[6*8+:8], in_w[6*8+:8]);
  swapBits #(8) si7 (in[7*8+:8], in_w[7*8+:8]);

  wire [64-1:0] store__a1;
  wire [64-1:0] store;
  delay #(64) store__ff (store__a1, store, rst, clk);
  wire [5-1:0] store_size__a1;
  wire [5-1:0] store_size;
  delay #(5) store_size__ff (store_size__a1, store_size, rst, clk);

  wire [60-1:0] out_w;
  realligner_core #(.BLOCK_SIZE(4), .NUM_IN_BLOCKS(16), .NUM_OUT_BLOCKS(15)) realign (
    .in(in_w),
    .in_isReady(in_isReady),
    .in_canReceive(in_canReceive),
    .out(out_w),
    .out_isReady(out_isReady),
    .out_canReceive(out_canReceive),
    .in_buff(store),
    .out_buff(store__a1),
    .in_buff_size(store_size),
    .out_buff_size(store_size__a1)
  );

  swapBits #(16) so0 ({out_w[0*15+:15], 1'b0}, out[0*16+:16]);
  swapBits #(16) so1 ({out_w[1*15+:15], 1'b0}, out[1*16+:16]);
  swapBits #(16) so2 ({out_w[2*15+:15], 1'b0}, out[2*16+:16]);
  swapBits #(16) so3 ({out_w[3*15+:15], 1'b0}, out[3*16+:16]);
endmodule

module memAndMul__pack15 (
    input [64-1:0] in,
    input in_isReady,
    output in_canReceive,
    output [64-1:0] out,
    output out_isReady,
    input out_canReceive,
    input rst,
    input clk
  );
  wire [60-1:0] in_w;

  swapBits #(15) si0 (in[0*16+:15], in_w[0*15+:15]);
  swapBits #(15) si1 (in[1*16+:15], in_w[1*15+:15]);
  swapBits #(15) si2 (in[2*16+:15], in_w[2*15+:15]);
  swapBits #(15) si3 (in[3*16+:15], in_w[3*15+:15]);

  wire [64-1:0] store__a1;
  wire [64-1:0] store;
  delay #(64) store__ff (store__a1, store, rst, clk);
  wire [5-1:0] store_size__a1;
  wire [5-1:0] store_size;
  delay #(5) store_size__ff (store_size__a1, store_size, rst, clk);

  wire [64-1:0] out_w;
  realligner_core #(.BLOCK_SIZE(4), .NUM_IN_BLOCKS(15), .NUM_OUT_BLOCKS(16)) realign (
    .in(in_w),
    .in_isReady(in_isReady),
    .in_canReceive(in_canReceive),
    .out(out_w),
    .out_isReady(out_isReady),
    .out_canReceive(out_canReceive),
    .in_buff(store),
    .out_buff(store__a1),
    .in_buff_size(store_size),
    .out_buff_size(store_size__a1)
  );

  swapBits #(8) so0 (out_w[0*8+:8], out[0*8+:8]);
  swapBits #(8) so1 (out_w[1*8+:8], out[1*8+:8]);
  swapBits #(8) so2 (out_w[2*8+:8], out[2*8+:8]);
  swapBits #(8) so3 (out_w[3*8+:8], out[3*8+:8]);

  swapBits #(8) so4 (out_w[4*8+:8], out[4*8+:8]);
  swapBits #(8) so5 (out_w[5*8+:8], out[5*8+:8]);
  swapBits #(8) so6 (out_w[6*8+:8], out[6*8+:8]);
  swapBits #(8) so7 (out_w[7*8+:8], out[7*8+:8]);
endmodule



module memAndMul__unpack (
    input isPack,

    input [64-1:0] in,
    input in_isReady,
    output in_canReceive,
    output in_isLast,
    output [64-1:0] out,
    output out_isReady,
    input out_canReceive,
    input out_isLast,

    input [`MemCONF_lenSec_size-1:0] config_lenSec,

    input rst,
    input clk
  );
  wire isP15 = isPack & config_lenSec[0];
  
  wire [64-1:0] p16_out;
  memAndMul__unpack16 p16(in, p16_out);
  wire [64-1:0] p15_out;
  wire p15_in_isReady = in_isReady & isP15;
  wire p15_in_canReceive;
  wire p15_out_isReady;
  wire p15_out_canReceive = out_canReceive & isP15;
  memAndMul__unpack15 p15(
    .in(in),
    .in_isReady(p15_in_isReady),
    .in_canReceive(p15_in_canReceive),
    .out(p15_out),
    .out_isReady(p15_out_isReady),
    .out_canReceive(p15_out_canReceive),
    .rst(rst),
    .clk(clk)
  );

  assign out = ~isPack          ? in
             : config_lenSec[0] ? p15_out
                                : p16_out;
  assign in_canReceive = isP15 ? p15_in_canReceive
                               : out_canReceive;
  assign out_isReady = isP15 ? p15_out_isReady
                             : in_isReady;
  
  wire out_isLast__d1;
  delay out_isLast__ff(out_isLast, out_isLast__d1, rst, clk);
  assign in_isLast = out_isLast;
endmodule

module memAndMul__pack (
    input isPack__a2,
    
    input [64-1:0] in,
    input in_isReady,
    output in_canReceive,
    input in_isLast,
    output [64-1:0] out,
    output out_isReady,
    input out_canReceive,
    output out_isLast,

    input [`MemCONF_lenSec_size-1:0] config_lenSec,

    input rst,
    input clk
  );
  
  wire isPack__a1;
  delay isPack__ff1(isPack__a2, isPack__a1, rst, clk);
  wire isPack;
  delay isPack__ff2(isPack__a1, isPack, rst, clk);
  
  wire isP15 = isPack & config_lenSec[0];
  
  wire [64-1:0] p16_out;
  memAndMul__pack16 p16(in, p16_out);
  wire [64-1:0] p15_out;
  wire p15_in_isReady = in_isReady & isP15;
  wire p15_in_canReceive;
  wire p15_out_isReady;
  wire p15_out_canReceive = out_canReceive & isP15;
  memAndMul__pack15 p15(
    .in(in),
    .in_isReady(p15_in_isReady),
    .in_canReceive(p15_in_canReceive),
    .out(p15_out),
    .out_isReady(p15_out_isReady),
    .out_canReceive(p15_out_canReceive),
    .rst(rst),
    .clk(clk)
  );

  assign out = ~isPack          ? in
             : config_lenSec[0] ? p15_out
                                : p16_out;
  assign in_canReceive = isP15 ? p15_in_canReceive
                               : out_canReceive;
  assign out_isReady = isP15 ? p15_out_isReady
                             : in_isReady;

  assign out_isLast = in_isLast;
endmodule



module memAndMul_ctrl(
    input [`MemAndMulCMD_SIZE-1:0] i, // { isPack: 1bit, main cmd : 6 bit }
    input i_isReady,
    output i_canReceive,

    output [`MemAndMulCMD_FULLSIZE-1:0] o_cmd,
    output o_in_isFirstCycle,
    output o_out_isFirstCycle,
    input o_in_isLastCycle,
    input o_out_isLastCycle, // the bus_out__d2 can output after this is active as this is to start new commands
    output o_in_isPack,
    output o_out_isPack,
    
    input rst,
    input clk
  );

  wire [`MemAndMulCMD_FULLSIZE-1:0] i__full = 1 << i[0+:`MemAndMulCMD_SIZE-1];
  wire i_conflictIn = | (i__full & `MemAndMulCMD_mask_conflictIn);
  wire i_conflictOut = | (i__full & `MemAndMulCMD_mask_conflictOut);


  wire [`MemAndMulCMD_SIZE-1:0] cmdB;
  wire cmdB_hasAny;
  wire cmdB_consume;
  wire cmdB_conflictIn;
  wire cmdB_conflictOut;
  bus_delay_fromstd #(.BusSize(`MemAndMulCMD_SIZE+2), .N(2)) cmdBuf (
    .i({ i, i_conflictIn, i_conflictOut }),
    .i_isReady(i_isReady),
    .i_canReceive(i_canReceive),
    .o({ cmdB, cmdB_conflictIn, cmdB_conflictOut }),
    .o_hasAny(cmdB_hasAny),
    .o_consume(cmdB_consume),
    .rst(rst),
    .clk(clk)
  );
  wire [`MemAndMulCMD_FULLSIZE-1:0] cmdB__full = 1 << cmdB[0+:`MemAndMulCMD_SIZE-1];
  wire cmdB__isPack = cmdB[`MemAndMulCMD_SIZE-1];


  wire [`MemAndMulCMD_FULLSIZE-1:0] prevCmd;
  wire prevCmd_conflictIn;
  wire prevCmd_conflictOut;
  
  assign cmdB_consume = cmdB_hasAny
                      & ~(cmdB_conflictIn & prevCmd_conflictIn) 
                      & ~(cmdB_conflictOut & prevCmd_conflictOut);
  
  wire [`MemAndMulCMD_FULLSIZE-1:0] currentCmd = prevCmd | (cmdB_consume ? cmdB__full : {`MemAndMulCMD_FULLSIZE{1'b0}});
  wire currentCmd_in_isFirstCycle  = cmdB_consume & cmdB_conflictIn;
  wire currentCmd_out_isFirstCycle = cmdB_consume & cmdB_conflictOut;
  wire currentCmd_conflictIn  = prevCmd_conflictIn  | currentCmd_in_isFirstCycle;
  wire currentCmd_conflictOut = prevCmd_conflictOut | currentCmd_out_isFirstCycle;
  
  wire [`MemAndMulCMD_FULLSIZE-1:0] nextCmd = currentCmd
                                            & (o_in_isLastCycle ? ~`MemAndMulCMD_mask_conflictIn : ~`MemAndMulCMD_mask_zero)
                                            & (o_out_isLastCycle ? ~`MemAndMulCMD_mask_conflictOut : ~`MemAndMulCMD_mask_zero);
  wire nextCmd_conflictIn  = currentCmd_conflictIn  & ~o_in_isLastCycle;
  wire nextCmd_conflictOut = currentCmd_conflictOut & ~o_out_isLastCycle;
  delay #(`MemAndMulCMD_FULLSIZE+2) cmd__ff (
    { nextCmd, nextCmd_conflictIn, nextCmd_conflictOut },
    { prevCmd, prevCmd_conflictIn, prevCmd_conflictOut },
    rst,
    clk
  );

  wire currentCmd_in_isFirstCycle__d1;
  delay currentCmd_in_isFirstCycle__ff(currentCmd_in_isFirstCycle, currentCmd_in_isFirstCycle__d1, rst, clk);
  wire currentCmd_out_isFirstCycle__d1;
  delay currentCmd_out_isFirstCycle__ff(currentCmd_out_isFirstCycle, currentCmd_out_isFirstCycle__d1, rst, clk);

 /*  // no delay
  assign o_cmd = currentCmd;
  assign o_in_isFirstCycle  = currentCmd_in_isFirstCycle;
  assign o_out_isFirstCycle = currentCmd_out_isFirstCycle;
*/

  assign o_cmd = prevCmd;
  assign o_in_isFirstCycle  = currentCmd_in_isFirstCycle__d1;
  assign o_out_isFirstCycle = currentCmd_out_isFirstCycle__d1;

  ff_en_imm in_isPack__ff  (o_in_isFirstCycle,  cmdB__isPack, o_in_isPack,  rst, clk);
  ff_en_imm out_isPack__ff (o_out_isFirstCycle, cmdB__isPack, o_out_isPack, rst, clk);
endmodule

module memAndMul(
    input fast_owner,
    input [13:0] fast_r_index, fast_w_index,
    input fast_r_secret, fast_r_secret_col, fast_r_b, fast_w_b,
    output [39:0] fast_s_col_data,
    input [511:0] fast_w_data,
    output [159:0] fast_s_data,
    output [511:0] fast_b_data,

    input [`MemAndMulCMD_SIZE-1:0] cmd, // { isPack: 1bit, main cmd : 6 bit }
    input cmd_isReady,
    output cmd_canReceive,

    input [64-1:0] in,
    input in_isReady,
    output in_canReceive,
    output in_isLast,

    output [64-1:0] out,
    output out_isReady,
    input out_canReceive,
    output out_isLast,

    input [`MemCONF_matrixNumBlocks_size-1:0] config_matrixNumBlocks, // how many 8x8 matrixes are in B and S. The FrodoKEM parameter/8.
    input config_SUseHalfByte,
    input [`MemCONF_lenSec_size-1:0] config_lenSec,
    input [`MemCONF_lenSE_size-1:0] config_lenSE,
    input [`MemCONF_lenSalt_size-1:0] config_lenSalt,

    input rst,
    input clk
  );

  wire [`MemAndMulCMD_FULLSIZE-1:0] currentCmd;
  wire currentCmd_in_isFirstCycle;
  wire currentCmd_out_isFirstCycle;
  wire currentCmd_in_isLastCycle;
  wire currentCmd_out_isLastCycle;
  wire in_isPack;
  wire out_isPack;
  memAndMul_ctrl ctrl(
    .i(cmd),
    .i_isReady(cmd_isReady),
    .i_canReceive(cmd_canReceive),
    .o_cmd(currentCmd),
    .o_in_isFirstCycle(currentCmd_in_isFirstCycle),
    .o_out_isFirstCycle(currentCmd_out_isFirstCycle),
    .o_in_isLastCycle(currentCmd_in_isLastCycle),
    .o_out_isLastCycle(currentCmd_out_isLastCycle),
    .o_in_isPack(in_isPack),
    .o_out_isPack(out_isPack),
    .rst(rst),
    .clk(clk)
  );
 
  wire core__bus_in_isReady;
  wire [64-1:0] core__bus_in;
  wire core__bus_in_canReceive;
  wire core__bus_in_isLast;
  wire core__bus_out_canReceive;
  wire [64-1:0] core__bus_out__d2;
  memAndMul__core core(
    .fast_owner(fast_owner), .fast_r_index(fast_r_index), .fast_w_index(fast_w_index),
    .fast_r_secret(fast_r_secret), .fast_r_secret_col(fast_r_secret_col), .fast_s_col_data(fast_s_col_data), .fast_r_b(fast_r_b), .fast_w_b(fast_w_b),
    .fast_w_data(fast_w_data), .fast_s_data(fast_s_data), .fast_b_data(fast_b_data),

    .currentCmd(currentCmd),
    .currentCmd_in_isFirstCycle(currentCmd_in_isFirstCycle),
    .currentCmd_out_isFirstCycle(currentCmd_out_isFirstCycle),
    .currentCmd_in_isLastCycle(currentCmd_in_isLastCycle),
    .currentCmd_out_isLastCycle(currentCmd_out_isLastCycle),
    .bus_in(core__bus_in),
    .bus_in_isReady(core__bus_in_isReady),
    .bus_in_canReceive(core__bus_in_canReceive),
    .bus_in_isLast(core__bus_in_isLast),
    .bus_out_canReceive(core__bus_out_canReceive),
    .bus_out__d2(core__bus_out__d2),
    .config_matrixNumBlocks(config_matrixNumBlocks),
    .config_SUseHalfByte(config_SUseHalfByte),
    .config_lenSec(config_lenSec),
    .config_lenSE(config_lenSE),
    .config_lenSalt(config_lenSalt),
    .rst(rst),
    .clk(clk)
  );

  //wire currentCMD__isOp = | (currentCmd & `MemAndMulCMD_mask_op);
  //wire currentCMD__isInOp = | (currentCmd & `MemAndMulCMD_mask_inOp);
  //wire currentCMD__isIn = | (currentCmd & `MemAndMulCMD_mask_in);
  wire currentCMD__isOut = | (currentCmd & `MemAndMulCMD_mask_out);
  
  wire [64-1:0] o__out;
  wire o__out_isReady;
  wire o__out_canReceive;
  wire o__out_isLast;
  memAndMul__outAdapter o(
    .currentCMD__isOut(currentCMD__isOut),
    .currentCmd_out_isLastCycle(currentCmd_out_isLastCycle),
    .bus_in_canReceive(core__bus_out_canReceive),
    .bus_in__d2(core__bus_out__d2),

    .bus_out_isReady(o__out_isReady),
    .bus_out_isLast(o__out_isLast),
    .bus_out(o__out),
    .bus_out_canReceive(o__out_canReceive),

    .rst(rst),
    .clk(clk)
  );

  memAndMul__pack pack (
    .isPack__a2(out_isPack),
    .in(o__out),
    .in_isReady(o__out_isReady),
    .in_canReceive(o__out_canReceive),
    .in_isLast(o__out_isLast),
    .out(out),
    .out_isReady(out_isReady),
    .out_canReceive(out_canReceive),
    .out_isLast(out_isLast),
    .config_lenSec(config_lenSec),
    .rst(rst),
    .clk(clk)
  );

  memAndMul__unpack unpack(
    .isPack(in_isPack),
    .in(in),
    .in_isReady(in_isReady),
    .in_canReceive(in_canReceive),
    .in_isLast(in_isLast),
    .out(core__bus_in),
    .out_isReady(core__bus_in_isReady),
    .out_canReceive(core__bus_in_canReceive),
    .out_isLast(core__bus_in_isLast),
    .config_lenSec(config_lenSec),
    .rst(rst),
    .clk(clk)
  );
endmodule



`endif // MEMANDMUL_V

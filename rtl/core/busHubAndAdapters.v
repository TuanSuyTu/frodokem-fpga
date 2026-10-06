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


`ifndef BUS_HUB_AND_ADAPT_V
`define BUS_HUB_AND_ADAPT_V


// This file provides the module: busSwitch, main_adapter_outer_out, main_adapter_outer_in
// It provides the hub to organize the p2p connections, and the adapters from the internal bus to the one used outside the module


`include "lib.v"


module busSwitch #(parameter N = 1) (
    input [N*2-1:0] cmd, // more than one can be selected at the same time, but with only one source. lowest bits are the source, the highest ones are destination.
    input cmd_isReady,
    output cmd_canReceive,

    // the _isLast of connected streams must match if present.

    input [64*N-1:0] in,
    input [N-1:0] in_isReady,
    output [N-1:0] in_canReceive,
    input [N-1:0] in_isLast_in,
    output [N-1:0] in_isLast_out,

    output [64*N-1:0] out,
    output [N-1:0] out_isReady,
    input [N-1:0] out_canReceive,
    input [N-1:0] out_isLast_in,
    output [N-1:0] out_isLast_out,

    input rst,
    input clk
  );
  wire [N*2-1:0] cmdB;
  wire cmdB_hasAny;
  wire cmdB_consume;
  bus_delay_fromstd #(.BusSize(N*2), .N(2)) cmdBuf (
    .i(cmd),
    .i_isReady(cmd_isReady),
    .i_canReceive(cmd_canReceive),
    .o(cmdB),
    .o_hasAny(cmdB_hasAny),
    .o_consume(cmdB_consume),
    .rst(rst),
    .clk(clk)
  );

  wire [N-1:0] cmdB_from = cmdB_hasAny ? cmdB[0+:N] : {N{1'b0}};
  wire [N-1:0] cmdB_to = cmdB_hasAny ? cmdB[N+:N] : {N{1'b0}};

  wor [64-1:0] bus;
  wor bus_isReady;
  wand bus_canReceive;
  wor bus_isLast;

  generate
    for(genvar pos_from = 0; pos_from < N; pos_from=pos_from+1) begin
      assign bus = cmdB_from[pos_from] ? in[pos_from*64+:64] : 64'b0;
      assign bus_isReady = cmdB_from[pos_from] & in_isReady[pos_from];
      assign bus_isLast = cmdB_from[pos_from] & in_isLast_in[pos_from];
    end

    for(genvar pos_to = 0; pos_to < N; pos_to=pos_to+1) begin
      assign bus_canReceive = ~cmdB_to[pos_to] | out_canReceive[pos_to];
      assign bus_isLast = cmdB_to[pos_to] & out_isLast_in[pos_to];
    end

    for(genvar pos_from = 0; pos_from < N; pos_from=pos_from+1) begin
      assign in_canReceive[pos_from] = cmdB_from[pos_from] & bus_canReceive;
      assign in_isLast_out[pos_from] = cmdB_from[pos_from] & bus_isLast;
    end

    for(genvar pos_to = 0; pos_to < N; pos_to=pos_to+1) begin
      assign out[pos_to*64+:64] = cmdB_to[pos_to] ? bus : 64'b0;
      assign out_isReady[pos_to] = cmdB_to[pos_to] & bus_isReady;
      assign out_isLast_out[pos_to] = cmdB_to[pos_to] & bus_isLast;
    end
  endgenerate

  assign cmdB_consume = bus_isLast;
endmodule

`define Outer_MaxWordLen  15

`define OuterInCMD_SIZE  (`Outer_MaxWordLen)




module main_adapter_outer_out(
    input [`OuterInCMD_SIZE-1:0] cmd, //  {size:`Outer_MaxWordLen bits}  // size of 0 for automatic
    input cmd_isReady,
    output cmd_canReceive,

    input [64-1:0] h__out,
    input h__out_isReady,
    output h__out_canReceive,
    output h__out_isLast_in,
    input h__out_isLast_out,

    output [64-1:0] o__out,
    output o__out_isReady,
    input o__out_canReceive,

    input rst,
    input clk
  );
  wor ignore = h__out_isLast_out;
  wire cmd_forward = cmd_isReady; // the only primary command
  wire [`Outer_MaxWordLen-1:0] cmd_size = cmd[0+:`Outer_MaxWordLen]; // number of bus messages

  assign o__out = h__out;

  wire useCounter;
  wire useCounter__d1;
  wire useCounter__val = cmd_size != 0;
  ff_en_imm useCounter__ff1(cmd_forward, useCounter__val, useCounter, rst, clk);
  delay useCounter__ff2(useCounter, useCounter__d1, rst, clk);

  wire counter__canRestart;
  wire counter__canReceive;
  wire counter__isReady = h__out_isReady & counter__canReceive;
  counter_bus #(`Outer_MaxWordLen) counter (
    .restart(cmd_forward),
    .numSteps(cmd_size),
    .canRestart(counter__canRestart),
    .canReceive(counter__canReceive),
    .canReceive_isLast(h__out_isLast_in),
    .isReady(counter__isReady),
    .rst(rst),
    .clk(clk)
  );

  wire noCounterOngoing;
  ff_rs_next noCounterEnded__ff(h__out_isLast_out, cmd_forward, noCounterOngoing, rst, clk);

  assign cmd_canReceive = useCounter__d1 ? counter__canRestart : ~noCounterOngoing;
  assign h__out_canReceive = o__out_canReceive & (useCounter ? counter__canReceive : noCounterOngoing);
  assign o__out_isReady = h__out_isReady;
endmodule

`define OuterOutCMD_SIZE  (`Outer_MaxWordLen)



module main_adapter_outer_in(
    input [`OuterOutCMD_SIZE-1:0] cmd,  //  {size:`Outer_MaxWordLen bits}   // size of 0 means automatic
    input cmd_isReady,
    output cmd_canReceive,

    output [64-1:0] h__in,
    output h__in_isReady,
    input h__in_canReceive,
    output h__in_isLast_in,
    input h__in_isLast_out,

    input [64-1:0] o__in,
    input o__in_isReady,
    output o__in_canReceive,

    input rst,
    input clk
  );
  wor ignore = h__in_isLast_out;

  wire cmd_forward = cmd_isReady; // the only primary command
  wire [`Outer_MaxWordLen-1:0] cmd_size = cmd[0+:`Outer_MaxWordLen]; // number of bus messages

  assign h__in = o__in;


  wire useCounter;
  wire useCounter__d1;
  wire useCounter__val = cmd_size != 0;
  ff_en_imm useCounter__ff1(cmd_forward, useCounter__val, useCounter, rst, clk);
  delay useCounter__ff2(useCounter, useCounter__d1, rst, clk);

  wire counter__canRestart;
  wire counter__canReceive;
  wire counter__isReady = o__in_isReady & counter__canReceive;
  counter_bus #(`Outer_MaxWordLen) counter (
    .restart(cmd_forward),
    .numSteps(cmd_size),
    .canRestart(counter__canRestart),
    .canReceive(counter__canReceive),
    .canReceive_isLast(h__in_isLast_in),
    .isReady(counter__isReady),
    .rst(rst),
    .clk(clk)
  );

  wire noCounterOngoing;
  ff_rs_next noCounterEnded__ff(h__in_isLast_out, cmd_forward, noCounterOngoing, rst, clk);

  assign cmd_canReceive = useCounter__d1 ? counter__canRestart : ~noCounterOngoing;
  assign o__in_canReceive = h__in_canReceive & (useCounter ? counter__canReceive : noCounterOngoing);
  assign h__in_isReady = o__in_isReady;
endmodule


`endif // BUS_HUB_AND_ADAPT_V


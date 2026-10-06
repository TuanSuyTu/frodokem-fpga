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


`ifndef LIB_V
`define LIB_V


// This file is a library of utility modules
// registers, delays, serializations and deserializations, counters, ...


module delay #(parameter N = 1) (
  input [N-1:0] in,
  output [N-1:0] out,
  input rst,
  input clk
);
  reg [N-1:0] r;
  always @ (posedge clk) begin
    r <= rst ? {N{1'b0}} : in;
  end
  assign out = r;  
endmodule


module optionalDelay #(parameter N = 1) (
  input doDelay,
  input [N-1:0] in,
  output [N-1:0] out,
  input rst,
  input clk
);
  wire [N-1:0] in__d1;
  delay #(N) in__ff (in, in__d1, rst, clk);
  assign out = doDelay ? in__d1 : in;
endmodule


module ff_en_next #(parameter N = 1) (
  input enable,
  input [N-1:0] newVal,
  output [N-1:0] val,
  input rst,
  input clk
);
  wire [N-1:0] val__a1 = enable ? newVal : val;
  delay #(N) val__ff (val__a1, val, rst, clk);
endmodule


module ff_en_imm #(parameter N = 1) (
  input enable,
  input [N-1:0] newVal,
  output [N-1:0] val,
  input rst,
  input clk
);
  wire [N-1:0] val__d1;
  assign val = enable ? newVal : val__d1;
  delay #(N) val__ff (val, val__d1, rst, clk);
endmodule


module ff_sr_next (
  input set,
  input reset,
  output val,
  input rst,
  input clk
);
  wire val__a1 = set   ? 1'b1
               : reset ? 1'b0
                       : val;
  delay val__ff (val__a1, val, rst, clk);
endmodule


module ff_sr_imm (
  input set,
  input reset,
  output val,
  input rst,
  input clk
);
  wire val__d1;
  assign val = set   ? 1'b1
             : reset ? 1'b0
                     : val__d1;
  delay val__ff (val, val__d1, rst, clk);
endmodule


module ff_rs_next (
  input reset,
  input set,
  output val,
  input rst,
  input clk
);
  wire val__a1 = reset ? 1'b0
               : set   ? 1'b1
                       : val;
  delay val__ff (val__a1, val, rst, clk);
endmodule


module ff_rs_imm (
  input reset,
  input set,
  output val,
  input rst,
  input clk
);
  wire val__d1;
  assign val = reset ? 1'b0
             : set   ? 1'b1
                     : val__d1;
  delay val__ff (val, val__d1, rst, clk);
endmodule


module ff_s_r ( // set immediate, reset while going into the next cycle
  input set,
  input reset,
  output val,
  output preSet, // the values before the set
  input rst,
  input clk
);
  assign val = preSet | set;
  wire preSet__a1 = val &~ reset;
  delay preSet__ff (preSet__a1, preSet, rst, clk);
endmodule


module counter_bus #(parameter N = 1) ( // N bits must be able to store the highest 'numSteps', and at least 1.
    input restart,  // can't interupt
    input [N-1:0] numSteps,
    output canRestart,

    output canReceive,
    output canReceive_wouldBeLast,
    output canReceive_isLast,
    input isReady, // it requires canReceive, as usual.

    input rst,
    input clk
  );
  wire [N-1:0] nextCounter;
  wire nextCounter_isNotZero;
  
  assign canRestart = ~nextCounter_isNotZero;
  wire doRestart = restart & canRestart;

  wire [N-1:0] counter = doRestart ? numSteps : nextCounter;
  assign canReceive = nextCounter_isNotZero | doRestart & numSteps != 0;
  
  wire [N-1:0] counter__min1 = counter - 1;
  assign canReceive_wouldBeLast = counter__min1 == 0;
  assign canReceive_isLast = canReceive_wouldBeLast & isReady;

  wire [N-1:0] nextCounter__a1 = isReady ? counter__min1 : counter;
  delay #(N) nextCounter__ff (nextCounter__a1, nextCounter, rst, clk);
  wire nextCounter_isNotZero__a1 = nextCounter__a1 != 0;
  delay nextCounter_isNotZero__ff (nextCounter_isNotZero__a1, nextCounter_isNotZero, rst, clk);
endmodule



module counter_bus_fixed #(parameter NUM_STEPS = 1) ( // N bits must be able to store the highest  restart_steps+1
    input restart,  // can't interupt
    output canRestart,

    output canReceive,
    output canReceive_wouldBeLast,
    output canReceive_isLast,
    input isReady, // it requires canReceive, as usual.

    input rst,
    input clk
  );
  counter_bus #($clog2(NUM_STEPS+1)) actualCounter (
    .restart(restart),  // can't interupt
    .numSteps(NUM_STEPS),
    .canRestart(canRestart),
    .canReceive(canReceive),
    .canReceive_wouldBeLast(canReceive_wouldBeLast),
    .canReceive_isLast(canReceive_isLast),
    .isReady(isReady),
    .rst(rst),
    .clk(clk)
  );
endmodule


module counter_bus_diff #(parameter N = 1) ( // N bits must be able to store the highest 'numSteps', and at least 1.
    input restart,
    input [N-1:0] numSteps,
    output restart_consume,
    output canReceive,
    output canReceive_isLast,
    input isReady, // it requires canReceive, as usual.

    input rst,
    input clk
  );
  assign restart_consume = canReceive & canReceive_isLast & isReady;
  counter_bus #(N) actualCounter (
    .restart(restart),  // can't interupt
    .numSteps(numSteps),
    .canReceive(canReceive),
    .canReceive_isLast(canReceive_isLast),
    .isReady(isReady),
    .rst(rst),
    .clk(clk)
  );
endmodule


module counter_bus_state #(parameter MAX_NUM_STEPS = 1) (
    input restart,  // can't interupt
    input [$clog2(MAX_NUM_STEPS+1)-1:0] numStates, // must be active throughtout the whole counter operation.
    output canRestart,
    
    output hasAny,
    output [MAX_NUM_STEPS-1:0] state, // meaningful if hasAny
    input consume, // it requires hasAny, as usual.
    output isLast,

    input rst,
    input clk
  );

  wire [MAX_NUM_STEPS-1:0] one = { {MAX_NUM_STEPS-1{1'b0}} , 1'b1};
  wire [MAX_NUM_STEPS-1:0] maskAllowedStates = (one << numStates) - one;
  
  wire [MAX_NUM_STEPS-1:0] stateNext__d1;
  assign canRestart = ~ ( | stateNext__d1 );

  assign state = stateNext__d1 | { {MAX_NUM_STEPS-1{1'b0}} , restart & canRestart};
  assign hasAny = | state;

  wire [MAX_NUM_STEPS-1:0] stateNext = consume ? (state << 1) & maskAllowedStates : state;
  assign isLast = hasAny & ~ ( | stateNext );
  delay #(MAX_NUM_STEPS) stateNext__ff (stateNext, stateNext__d1, rst, clk);
endmodule


module serdes #(parameter N = 1) ( // the startSer and startDes can be true together
  input cmd_startDes,
  input cmd_startSer,
  output cmd_canReceive,

  output [64*N-1:0] buffer_write,
  input [64*N-1:0] buffer_read,

  input [64-1:0] des,
  input des_isReady,
  output des_canReceive,
  output des_isLast,
  
  output [64-1:0] ser,
  output ser_isReady,
  input ser_canReceive,
  output ser_isLast,

  input rst,
  input clk
);
  wire cmd_startAny = cmd_canReceive & (cmd_startSer | cmd_startDes);

  wire isSer, isDes;
  ff_en_imm isSer__ff (cmd_startAny, cmd_startSer, isSer, rst, clk);
  ff_en_imm isDes_ff (cmd_startAny, cmd_startDes, isDes, rst, clk);

  wire counter__canReceive;
  wire counter__isReady = counter__canReceive & (isDes ? des_isReady : ser_canReceive);
  wire counter__isLast;
  counter_bus_fixed #(N) counter (
    .restart(cmd_startAny),
    .canRestart(cmd_canReceive),
    .canReceive(counter__canReceive),
    .canReceive_isLast(counter__isLast),
    .isReady(counter__isReady),
    .rst(rst),
    .clk(clk)
  );
  assign ser_isLast = counter__isLast & isSer;
  assign des_isLast = counter__isLast & isDes;

  assign des_canReceive = isDes & counter__canReceive & (isSer ? ser_canReceive : 1'b1);
  assign ser_isReady = isSer & counter__canReceive & (isDes ? des_isReady : ser_canReceive);

  assign ser = buffer_read[64-1:0];
  assign buffer_write = ~counter__isReady ? buffer_read
                      : isDes             ? {des,                 buffer_read[64*N-1:64]}
                                          : {buffer_read[64-1:0], buffer_read[64*N-1:64]};
endmodule



module bus_delayFull_std1 #(parameter BusSize = 1) (
  input [BusSize-1:0] i,
  input i_isReady,
  output i_canReceive,
  input i_isLast,

  output [BusSize-1:0] o,
  output o_isReady,
  input o_canReceive,
  output o_isLast,

  input rst,
  input clk
);
  wire buffer1_isUsed;
  wire [BusSize-1:0] buffer1;
  wire buffer2_isUsed;
  wire [BusSize-1:0] buffer2;
  wire in_enabled;
  wire out_sendLast;

  wire buffer1_isUsed__aligned        = buffer1_isUsed & buffer2_isUsed;
  wire [BusSize-1:0] buffer1__aligned = buffer1;
  wire buffer2_isUsed__aligned        = buffer1_isUsed | buffer2_isUsed;
  wire [BusSize-1:0] buffer2__aligned = buffer2_isUsed ? buffer2 : buffer1;

  assign i_canReceive            = ~buffer1_isUsed__aligned & in_enabled;
  assign o_isReady               = buffer2_isUsed__aligned & o_canReceive;  
  assign o                       = buffer2__aligned;
  assign o_isLast                = out_sendLast & (o_isReady & ~buffer1_isUsed__aligned | ~buffer2_isUsed__aligned);
//  assign o_isLast                = out_sendLast & o_canReceive & ~o_isReady;

  wire buffer1_isUsed__a1        = buffer1_isUsed__aligned | i_isReady;
  wire [BusSize-1:0] buffer1__a1 = buffer1_isUsed__aligned ? buffer1__aligned : i;
  wire buffer2_isUsed__a1        = buffer2_isUsed__aligned & ~o_canReceive;
  wire [BusSize-1:0] buffer2__a1 = buffer2__aligned;
  wire in_enabled__a1            = in_enabled & ~i_isLast | o_canReceive & ~o_isReady & ~o_isLast;
  wire out_sendLast__a1          = out_sendLast & ~o_isLast | i_isLast;
  
  delay buffer1_isUsed__ff (buffer1_isUsed__a1, buffer1_isUsed, rst, clk);
  delay #(BusSize) buffer1__ff (buffer1__a1, buffer1, rst, clk);
  delay buffer2_isUsed__ff (buffer2_isUsed__a1, buffer2_isUsed, rst, clk);
  delay #(BusSize) buffer2__ff (buffer2__a1, buffer2, rst, clk);
  delay in_enabled__ff (in_enabled__a1, in_enabled, rst, clk);
  delay out_sendLast__ff (out_sendLast__a1, out_sendLast, rst, clk);
endmodule



module bus_delay_std1 #(parameter BusSize = 1) (
  input [BusSize-1:0] i,
  input i_isReady,
  output i_canReceive,

  output [BusSize-1:0] o,
  output o_isReady,
  input o_canReceive,

  input rst,
  input clk
);
  wire buffer_isUsed;
  wire [BusSize-1:0] buffer;

  assign o_isReady = buffer_isUsed & o_canReceive;
  assign i_canReceive = ~buffer_isUsed;

  assign o = buffer;

  wire buffer_isUsed__a1        = buffer_isUsed ? ~o_canReceive : i_isReady;
  wire [BusSize-1:0] buffer__a1 = buffer_isUsed ? buffer        : i;
  
  delay #(BusSize) buffer__ff (buffer__a1, buffer, rst, clk);
  delay buffer_isUsed__ff (buffer_isUsed__a1, buffer_isUsed, rst, clk);
endmodule

module bus_delay_unstd1 #(parameter BusSize = 1) (
  input [BusSize-1:0] i,
  input i_hasAny,
  output i_consume,

  output [BusSize-1:0] o,
  output o_hasAny,
  input o_consume,

  input rst,
  input clk
);
  wire buffer_isUsed;
  wire [BusSize-1:0] buffer;

  assign i_consume = i_hasAny & ~buffer_isUsed;
  assign o_hasAny = buffer_isUsed;

  assign o = buffer;

  wire buffer_isUsed__a1        = buffer_isUsed ? ~o_consume : i_hasAny;
  wire [BusSize-1:0] buffer__a1 = buffer_isUsed ? buffer     : i;

  delay #(BusSize) buffer__ff (buffer__a1, buffer, rst, clk);
  delay buffer_isUsed__ff (buffer_isUsed__a1, buffer_isUsed, rst, clk);
endmodule

module bus_fromstd1 #(parameter BusSize = 1) (
  input [BusSize-1:0] i,
  input i_isReady,
  output i_canReceive,

  output [BusSize-1:0] o,
  output o_hasAny,
  input o_consume,

  input rst,
  input clk
);
  wire buffer_isUsed;
  wire [BusSize-1:0] buffer;

  assign i_canReceive = ~buffer_isUsed | o_consume;
  assign o_hasAny = buffer_isUsed;

  assign o = buffer;

  wire buffer_isUsed__a1        = buffer_isUsed & ~o_consume | i_isReady;
  wire [BusSize-1:0] buffer__a1 = i_isReady ? i : buffer;

  delay #(BusSize) buffer__ff (buffer__a1, buffer, rst, clk);
  delay buffer_isUsed__ff (buffer_isUsed__a1, buffer_isUsed, rst, clk);
endmodule


module bus_delay_std #(parameter BusSize = 1, N = 0) (
  input [BusSize-1:0] i,
  input i_isReady,
  output i_canReceive,

  output [BusSize-1:0] o,
  output o_isReady,
  input o_canReceive,

  input rst,
  input clk
);

  wire [BusSize*(N+1)-1:0] s;
  wire [N+1-1:0] s_isReady;
  wire [N+1-1:0] s_canReceive;

  assign s[0+:BusSize] = i;
  assign s_isReady[0] = i_isReady;
  assign i_canReceive = s_canReceive[0];
  assign o = s[BusSize*N+:BusSize];
  assign o_isReady = s_isReady[N];
  assign s_canReceive[N] = o_canReceive;

  genvar pos;
  generate
    for (pos = 0; pos < N; pos=pos+1) begin

      bus_delay_std1 #(.BusSize(BusSize)) del (
        .i(s[pos*BusSize+:BusSize]),
        .i_isReady(s_isReady[pos]),
        .i_canReceive(s_canReceive[pos]),

        .o(s[(pos+1)*BusSize+:BusSize]),
        .o_isReady(s_isReady[pos+1]),
        .o_canReceive(s_canReceive[pos+1]),

        .rst(rst),
        .clk(clk)
      );

    end
  endgenerate

endmodule


module bus_delayFull_std #(parameter BusSize = 1, N = 0) (
  input [BusSize-1:0] i,
  input i_isReady,
  output i_canReceive,
  input i_isLast,

  output [BusSize-1:0] o,
  output o_isReady,
  input o_canReceive,
  output o_isLast,

  input rst,
  input clk
);

  wire [BusSize*(N+1)-1:0] s;
  wire [N+1-1:0] s_isReady;
  wire [N+1-1:0] s_canReceive;
  wire [N+1-1:0] s_isLast;

  assign s[0+:BusSize] = i;
  assign s_isReady[0] = i_isReady;
  assign i_canReceive = s_canReceive[0];
  assign s_isLast[0] = i_isLast;

  assign o = s[BusSize*N+:BusSize];
  assign o_isReady = s_isReady[N];
  assign s_canReceive[N] = o_canReceive;
  assign o_isLast = s_isLast[N];

  genvar pos;
  generate
    for (pos = 0; pos < N; pos=pos+1) begin

      bus_delayFull_std1 #(.BusSize(BusSize)) del (
        .i(s[pos*BusSize+:BusSize]),
        .i_isReady(s_isReady[pos]),
        .i_canReceive(s_canReceive[pos]),
        .i_isLast(s_isLast[pos]),

        .o(s[(pos+1)*BusSize+:BusSize]),
        .o_isReady(s_isReady[pos+1]),
        .o_canReceive(s_canReceive[pos+1]),
        .o_isLast(s_isLast[pos+1]),

        .rst(rst),
        .clk(clk)
      );

    end
  endgenerate

endmodule


module bus_delay_unstd #(parameter BusSize = 1, N = 0) (
  input [BusSize-1:0] i,
  input i_hasAny,
  output i_consume,

  output [BusSize-1:0] o,
  output o_hasAny,
  input o_consume,

  input rst,
  input clk
);

  wire [BusSize*(N+1)-1:0] s;
  wire [N+1-1:0] s_hasAny;
  wire [N+1-1:0] s_consume;

  assign s[0+:BusSize] = i;
  assign s_hasAny[0] = i_hasAny;
  assign i_consume = s_consume[0];
  assign o = s[BusSize*N+:BusSize];
  assign o_hasAny = s_hasAny[N];
  assign s_consume[N] = o_consume;

  genvar pos;
  generate
    for (pos = 0; pos < N; pos=pos+1) begin

      bus_delay_unstd1 #(.BusSize(BusSize)) del (
        .i(s[pos*BusSize+:BusSize]),
        .i_hasAny(s_hasAny[pos]),
        .i_consume(s_consume[pos]),

        .o(s[(pos+1)*BusSize+:BusSize]),
        .o_hasAny(s_hasAny[pos+1]),
        .o_consume(s_consume[pos+1]),

        .rst(rst),
        .clk(clk)
      );

    end
  endgenerate

endmodule


module bus_delay_fromstd #(parameter BusSize = 1, N = 1) (
  input [BusSize-1:0] i,
  input i_isReady,
  output i_canReceive,

  output [BusSize-1:0] o,
  output o_hasAny,
  input o_consume,

  input rst,
  input clk
);
  wire [BusSize-1:0] m;
  wire m_isReady;
  wire m_canReceive;

  bus_delay_std #(.BusSize(BusSize), .N(N-1)) mainBuff (
    .i(i),
    .i_isReady(i_isReady),
    .i_canReceive(i_canReceive),
    .o(m),
    .o_isReady(m_isReady),
    .o_canReceive(m_canReceive),
    .rst(rst),
    .clk(clk)
  );

  bus_fromstd1 #(.BusSize(BusSize)) adapter (
    .i(m),
    .i_isReady(m_isReady),
    .i_canReceive(m_canReceive),
    .o(o),
    .o_hasAny(o_hasAny),
    .o_consume(o_consume),
    .rst(rst),
    .clk(clk)
  );
endmodule

module bus_delayFull_fromstd #(parameter BusSize = 1, N = 1) (
  input [BusSize-1:0] i,
  input i_isReady,
  output i_canReceive,

  output [BusSize-1:0] o,
  output o_hasAny,
  input o_consume,

  input rst,
  input clk
);
  wire [BusSize-1:0] m;
  wire m_isReady;
  wire m_canReceive;

  wire ignore;
  bus_delayFull_std #(.BusSize(BusSize), .N(N-1)) mainBuff (
    .i(i),
    .i_isReady(i_isReady),
    .i_canReceive(i_canReceive),
    .i_isLast(1'b0),
    .o(m),
    .o_isReady(m_isReady),
    .o_canReceive(m_canReceive),
    .o_isLast(ignore),
    .rst(rst),
    .clk(clk)
  );

  bus_fromstd1 #(.BusSize(BusSize)) adapter (
    .i(m),
    .i_isReady(m_isReady),
    .i_canReceive(m_canReceive),
    .o(o),
    .o_hasAny(o_hasAny),
    .o_consume(o_consume),
    .rst(rst),
    .clk(clk)
  );
endmodule


module swapBits #(parameter N = 1) (
    input [N-1:0] in,
    output [N-1:0] out
  );
  genvar j;
  generate
    for (j = 0; j < N; j=j+1) begin
      assign out[j] = in[N-1-j];
    end
  endgenerate
endmodule



`endif // LIB_V



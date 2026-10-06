`timescale 1ns/1ps
`ifdef REAL_CORE
`include "main.v"
`endif
module tb_pio;
  logic clk=0; always #8 clk=~clk;
  logic aresetn=0;
  logic [11:0] s_axi_awaddr=0,s_axi_araddr=0;
  logic s_axi_awvalid=0,s_axi_wvalid=0,s_axi_bready=0,s_axi_arvalid=0,s_axi_rready=0;
  wire s_axi_awready,s_axi_wready,s_axi_bvalid,s_axi_arready,s_axi_rvalid;
  logic [31:0] s_axi_wdata=0;
  logic [3:0] s_axi_wstrb=0;
  wire [31:0] s_axi_rdata;
  wire [1:0] s_axi_bresp,s_axi_rresp;
  logic [63:0] s_axis_tdata=0;
  logic [7:0] s_axis_tkeep=8'hff;
  logic s_axis_tvalid=0,s_axis_tlast=0,m_axis_tready=0;
  wire s_axis_tready,m_axis_tvalid,m_axis_tlast,irq;
  wire [63:0] m_axis_tdata;
  wire [7:0] m_axis_tkeep;
  wire [2:0] native_cmd;
  wire native_cmd_valid,native_in_valid,native_out_ready,native_rst;
  logic native_cmd_ready,native_in_ready,native_out_valid;
  wire [63:0] native_in;
  logic [63:0] native_out;
  frodokem_axi_shell #(.PIO(1)) dut(.*);
  integer tick=0, stub_boot=0, stub_input=0,stub_output=0,stub_op=0;
  logic stub_running=0,stub_booting=0;
  integer seed=32'h2468ace1, case_count=0;
  integer expected_in=0,expected_out=0;
  integer selected_op=0;
  logic [31:0] random_state;
  // Explicit PRNG state avoids reseeding $urandom on every draw. In XSim
  // $urandom(seed) left seed unchanged and generated perpetual backpressure.
  function automatic logic [31:0] next_random();
    logic [31:0] x;
    begin
      x=random_state;
      x=x^(x<<13);
      x=x^(x>>17);
      x=x^(x<<5);
      random_state=x;
      next_random=x;
    end
  endfunction
  logic sending_boot=0;
  logic stalled=0;
  logic [72:0] held_output;
`ifdef REAL_CORE
  `include "vectors640.v"
  main crypto_core(.clk(clk),.rst(native_rst),.cmd(native_cmd),.cmd_isReady(native_cmd_valid),
    .cmd_canReceive(native_cmd_ready),.in(native_in),.in_isReady(native_in_valid),.in_canReceive(native_in_ready),
    .out(native_out),.out_isReady(native_out_valid),.out_canReceive(native_out_ready));
  function automatic [63:0] swap64(input [63:0] word);
    integer j;
    for(j=0;j<8;j=j+1) swap64[j*8+:8]=word[(7-j)*8+:8];
  endfunction
`endif
  function automatic [63:0] input_word(input integer index);
`ifdef REAL_CORE
    logic [63:0] value;
    begin
      value=0;
      if(sending_boot) begin
        if(selected_op==0) begin
          if(index<4) value=v640_keygen_rnd_seedSE[0][index*64+:64];
          else if(index<6) value=v640_keygen_rnd_s[0][(index-4)*64+:64];
          else if(index>=10) value=v640_keygen_rnd_z[0][(index-10)*64+:64];
        end else if(selected_op==1) begin
          if(index>=4 && index<6) value=v640_enc_rnd_mu[0][(index-4)*64+:64];
          else if(index>=6 && index<10) value=v640_enc_rnd_salt[0][(index-6)*64+:64];
        end
      end else if(selected_op==1) begin
        if(index<2) value=v640_pk_seedA[0][index*64+:64];
        else value=v640_pk_b[0][(index-2)*64+:64];
      end else if(selected_op==2) begin
        if(index<1280) value=v640_sk_S[0][index*64+:64];
        else if(index<2480) value=v640_ct_c1[0][(index-1280)*64+:64];
        else if(index<2495) value=v640_ct_c2[0][(index-2480)*64+:64];
        else if(index<2499) value=v640_ct_salt[0][(index-2495)*64+:64];
        else if(index<2501) value=v640_sk_pkh[0][(index-2499)*64+:64];
        else if(index<3701) value=v640_pk_b[0][(index-2501)*64+:64];
        else if(index<3703) value=v640_pk_seedA[0][(index-3701)*64+:64];
        else value=v640_sk_s[0][(index-3703)*64+:64];
      end
      input_word=swap64(value);
    end
`else
    input_word=64'h1032547698badcfe ^ index;
`endif
  endfunction
  function automatic [63:0] result_word(input integer op,index);
`ifdef REAL_CORE
    logic [63:0] value;
    begin
      if(op==0) begin
        if(index<2) value=v640_sk_s[0][index*64+:64];
        else if(index<1282) value=v640_sk_S[0][(index-2)*64+:64];
        else if(index<1284) value=v640_pk_seedA[0][(index-1282)*64+:64];
        else if(index<2484) value=v640_pk_b[0][(index-1284)*64+:64];
        else value=v640_sk_pkh[0][(index-2484)*64+:64];
      end else if(op==1) begin
        if(index<1200) value=v640_ct_c1[0][index*64+:64];
        else if(index<1215) value=v640_ct_c2[0][(index-1200)*64+:64];
        else if(index<1219) value=v640_ct_salt[0][(index-1215)*64+:64];
        else value=v640_enc_ss[0][(index-1219)*64+:64];
      end else value=v640_dec_ss[0][index*64+:64];
      result_word=swap64(value);
    end
`else
    result_word=64'habcdef0123456789 ^ (64'(op)<<32) ^ index;
`endif
  endfunction
`ifndef REAL_CORE
  always_comb begin
    native_cmd_ready=!native_rst && tick%7!=0;
    native_in_ready=!native_rst && (stub_booting||stub_running) && tick%5!=0;
    native_out_valid=stub_running && stub_input==expected_in && stub_output<expected_out && native_out_ready;
    native_out=result_word(stub_op,stub_output);
  end
  always @(posedge clk) begin
    tick<=tick+1;
    if(native_rst) begin
      stub_boot<=0; stub_input<=0; stub_output<=0; stub_running<=0; stub_booting<=0;
    end else begin
      if(native_cmd_valid && native_cmd_ready) begin
        if(native_cmd==3) stub_booting<=1;
        if(native_cmd<3) begin
          if(stub_boot!=12) $fatal(1,"COMMAND_BEFORE_BOOTSTRAP");
          stub_op<=native_cmd; stub_running<=1;
        end
      end
      if(native_in_valid && native_in_ready) begin
        if(stub_booting) begin
          if(native_in!==input_word(stub_boot)) $fatal(1,"BOOT_WORD_ORDER");
          stub_boot<=stub_boot+1;
          if(stub_boot==11) stub_booting<=0;
        end else begin
          if(native_in!==input_word(stub_input)) $fatal(1,"PAYLOAD_WORD_ORDER %0d",stub_input);
          stub_input<=stub_input+1;
        end
      end
      if(native_out_valid && native_out_ready) begin
        stub_output<=stub_output+1;
        if(stub_output+1==expected_out) stub_running<=0;
      end
    end
  end
`endif
  task automatic write_reg(input [11:0] addr,input [31:0] data,input [3:0] strb,
                           input integer aw_delay,w_delay,response_delay,input [1:0] expected_resp);
    fork
      begin
        repeat(aw_delay) @(negedge clk);
        @(negedge clk); s_axi_awaddr=addr; s_axi_awvalid=1;
        do @(posedge clk); while(!s_axi_awready);
        @(negedge clk); s_axi_awvalid=0;
      end
      begin
        repeat(w_delay) @(negedge clk);
        @(negedge clk); s_axi_wdata=data; s_axi_wstrb=strb; s_axi_wvalid=1;
        do @(posedge clk); while(!s_axi_wready);
        @(negedge clk); s_axi_wvalid=0;
      end
    join
    repeat(response_delay) @(negedge clk);
    s_axi_bready=1;
    do @(posedge clk); while(!s_axi_bvalid);
    if(s_axi_bresp!==expected_resp) $fatal(1,"BRESP addr=%h got=%h expected=%h",addr,s_axi_bresp,expected_resp);
    @(negedge clk); s_axi_bready=0;
  endtask
  task automatic read_reg(input [11:0] addr,output [31:0] data,input [1:0] expected_resp);
    @(negedge clk); s_axi_araddr=addr; s_axi_arvalid=1;
    do @(posedge clk); while(!s_axi_arready);
    @(negedge clk); s_axi_arvalid=0;
    repeat(3) @(negedge clk);
    s_axi_rready=1;
    do @(posedge clk); while(!s_axi_rvalid);
    data=s_axi_rdata;
    if(s_axi_rresp!==expected_resp) $fatal(1,"RRESP");
    @(negedge clk); s_axi_rready=0;
  endtask

  task automatic wait_bit(input integer bit_index);
    logic [31:0] v;
    for(integer attempt=0;attempt<10000;attempt++) begin
      read_reg(12'h00c,v,0);
      if(v[6]) $fatal(1,"PIO_CORE_ERROR status=%h",v);
      if(v[bit_index]) return;
    end
    $fatal(1,"PIO_STATUS_TIMEOUT bit=%0d",bit_index);
  endtask
  task automatic send_word(input [63:0] word,input bit last_word);
    logic [31:0] v;
    do read_reg(12'h110,v,0); while(!v[0]);
    write_reg(12'h114,last_word,15,0,2,3,0);
    write_reg(12'h100,word[31:0],15,3,0,2,0);
    write_reg(12'h104,word[63:32],15,0,3,4,0);
  endtask
  task automatic run_pio(input integer op);
    logic [31:0] v, lo, hi, ignored;
    integer sent,received;
    expected_in=op==0?0:op==1?1202:3705;
    expected_out=op==0?2486:op==1?1221:2;
    selected_op=op;
    write_reg(8,8,15,0,2,3,0);
    wait_bit(0);
    write_reg(16,op,15,3,0,1,0);
    write_reg(8,1,15,0,3,2,0);
    wait_bit(2);
    sending_boot=1;
    for(integer n=0;n<12;n++) send_word(input_word(n),n==11);
    wait_bit(3);
    sending_boot=0;
    write_reg(8,2,15,2,0,4,0);
    sent=0; received=0;
    // One software-like loop services BOTH directions; never waits for all
    // input to be sent before draining output.
    while(sent<expected_in || received<expected_out) begin
      read_reg(12'h110,v,0);
      if(sent<expected_in && v[0]) begin
        send_word(input_word(sent),sent==expected_in-1);
        sent++;
      end
      if(received<expected_out && v[2]) begin
        if(v[4] !== (received==expected_out-1)) $fatal(1,"PIO_LAST op=%0d n=%0d",op,received);
        // Slow reader deliberately fills output FIFO and stalls the core.
        repeat(next_random()%13) @(negedge clk);
        read_reg(12'h108,lo,0);
        if(received==0) read_reg(12'h108,ignored,2); // LOW cannot duplicate/pop.
        repeat(next_random()%13) @(negedge clk);
        read_reg(12'h10c,hi,0);
        if({hi,lo}!==result_word(op,received))
          $fatal(1,"PIO_KAT_MISMATCH op=%0d n=%0d got=%h expected=%h",op,received,{hi,lo},result_word(op,received));
        received++;
      end
    end
    wait_bit(5);
    read_reg(32,v,0); if(v!=expected_in) $fatal(1,"PIO_INPUT_COUNT");
    read_reg(36,v,0); if(v!=expected_out) $fatal(1,"PIO_OUTPUT_COUNT");
    read_reg(60,v,0); if(v!=12) $fatal(1,"PIO_BOOT_COUNT");
    read_reg(12'h10c,v,2); // HIGH cannot pop twice.
    $display("PIO_KAT_PASS op=%0d words=%0d",op,expected_out);
  endtask
  logic [31:0] check;
  assert property (@(posedge clk) disable iff(!aresetn)
    s_axi_rvalid && !s_axi_rready |=> s_axi_rvalid && $stable({s_axi_rdata,s_axi_rresp}));
  assert property (@(posedge clk) disable iff(!aresetn)
    s_axi_bvalid && !s_axi_bready |=> s_axi_bvalid && $stable(s_axi_bresp));
  assert property (@(posedge clk) disable iff(!aresetn)
    dut.pio_tx_valid && !s_axis_tready |=> dut.pio_tx_valid && $stable({dut.pio_tx_data,dut.pio_tx_last}));
  always @(posedge clk) begin
    if(aresetn && s_axi_rvalid && !s_axi_rready) begin
      assert (!$isunknown({s_axi_rresp,s_axi_rdata})) else $fatal(1,"PIO_R_UNKNOWN");
    end
  end
  initial begin
    random_state=seed;
    repeat(6) @(negedge clk);
    aresetn=1;
    wait_bit(0);
    read_reg(0,check,0); if(check!=32'h46524f32) $fatal(1,"PIO_ID");
    read_reg(4,check,0); if(check!=31) $fatal(1,"PIO_CAP");
    write_reg(12'h104,123,15,0,3,5,2);
    write_reg(12'h100,123,3,4,0,5,2);
    write_reg(12'h114,2,15,0,0,0,2);
    write_reg(12'h101,123,15,0,0,0,2);
    read_reg(12'h108,check,2);
    read_reg(12'h10c,check,2);
    if($value$plusargs("OP=%d",selected_op)) run_pio(selected_op);
    else for(integer op=0;op<3;op++) run_pio(op);
    $display("PIO_ALL_TESTS_PASS");
    $finish;
  end
  initial begin
    #100000000;
    $fatal(1,"PIO_GLOBAL_TIMEOUT");
  end
endmodule

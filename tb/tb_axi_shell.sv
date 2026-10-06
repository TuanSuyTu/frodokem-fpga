`timescale 1ns/1ps
`ifdef REAL_CORE
`include "main.v"
`endif
module tb_axi_shell;
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
  frodokem_axi_shell dut(.*);
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
  always @(posedge clk) begin
    if(!aresetn || native_rst) stalled<=0;
    else begin
      if(stalled && (!m_axis_tvalid || {m_axis_tlast,m_axis_tkeep,m_axis_tdata}!==held_output))
        $fatal(1,"OUTPUT_CHANGED_WHILE_STALLED");
      stalled<=m_axis_tvalid && !m_axis_tready;
      held_output<={m_axis_tlast,m_axis_tkeep,m_axis_tdata};
    end
  end
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
  task automatic wait_status(input integer bit_index);
    logic [31:0] value;
    integer tries;
    begin : status_wait
      for(tries=0;tries<30;tries=tries+1) begin
        read_reg(12'h00c,value,0);
        if(value[bit_index]) disable status_wait;
      end
      $fatal(1,"STATUS_TIMEOUT bit=%0d status=%h",bit_index,value);
    end
  endtask
  task automatic send_packet(input integer words,input logic bad_keep,early_last,is_boot);
    integer n,gap;
    sending_boot=is_boot;
    for(n=0;n<words;n=n+1) begin
      gap=next_random()%3;
      repeat(gap) @(negedge clk);
      @(negedge clk); s_axis_tdata=input_word(n); s_axis_tkeep=bad_keep?8'h0f:8'hff;
      s_axis_tlast=early_last || n==words-1; s_axis_tvalid=1;
      do @(posedge clk); while(!s_axis_tready);
      @(negedge clk); s_axis_tvalid=0;
    end
  endtask
  task automatic receive_packet(input integer op,words);
    integer n,attempts;
    logic [31:0] draw;
    logic [31:0] value;
    begin
      n=0;
      attempts=0;
      // Adversarial sink: never assert READY until it has observed VALID.
      wait(m_axis_tvalid);
      $display("AXI_RX_VALID t=%0t",$time);
      repeat(256) @(negedge clk);
      read_reg(12'h00c,value,0);
      $display("AXI_RX_STATUS t=%0t status=%h",$time,value);
      if(value[5]) $fatal(1,"DONE_BEFORE_LAST_HANDSHAKE");
      while(n<words) begin
        @(negedge clk);
        draw=next_random();
        m_axis_tready=(draw%4)!=0;
        if($test$plusargs("PROBE_NS") && attempts<4)
          $display("AXI_READY_DRAW words=%0d n=%0d draw=%h seed=%h ready=%b",words,n,draw,seed,m_axis_tready);
        attempts=attempts+1;
        @(posedge clk);
        if(m_axis_tvalid && m_axis_tready) begin
          if(m_axis_tdata!==result_word(op,n)) $fatal(1,"OUTPUT_WORD %0d",n);
          if(m_axis_tkeep!==8'hff || m_axis_tlast!==(n==words-1)) $fatal(1,"OUTPUT_METADATA %0d",n);
          n=n+1;
        end
      end
      @(negedge clk); m_axis_tready=0;
    end
  endtask
`ifndef REAL_CORE
  // Subsystem reset cancels outstanding transfers, unlike software DATA_RESET.
  task automatic reset_subsystem;
    @(negedge clk);
    aresetn=0;
    s_axi_awvalid=0; s_axi_wvalid=0; s_axi_bready=0;
    s_axi_arvalid=0; s_axi_rready=0;
    s_axis_tvalid=0; m_axis_tready=0;
    repeat(5) @(negedge clk);
    if(s_axi_bvalid || s_axi_rvalid || m_axis_tvalid || irq)
      $fatal(1,"RESET_STALE_RESPONSE");
    aresetn=1;
    wait_status(0);
  endtask
  task automatic reset_outstanding(input integer kind);
    @(negedge clk);
    if(kind==0 || kind==2) begin
      s_axi_awaddr=16; s_axi_awvalid=1;
      do @(posedge clk); while(!s_axi_awready);
      @(negedge clk); s_axi_awvalid=0;
    end
    if(kind==1 || kind==2) begin
      s_axi_wdata=2; s_axi_wstrb=15; s_axi_wvalid=1;
      do @(posedge clk); while(!s_axi_wready);
      @(negedge clk); s_axi_wvalid=0;
    end
    if(kind==2) wait(s_axi_bvalid);
    if(kind==3) begin
      s_axi_araddr=0; s_axi_arvalid=1;
      do @(posedge clk); while(!s_axi_arready);
      @(negedge clk); s_axi_arvalid=0;
      wait(s_axi_rvalid);
    end
    repeat(8) @(negedge clk);
    reset_subsystem();
    read_reg(16,value,0);
    if(value!=0) $fatal(1,"RESET_CONFIG");
    write_reg(16,1,15,0,0,0,0);
    read_reg(16,value,0);
    if(value!=1) $fatal(1,"RESET_CHANNEL_RECOVERY");
    $display("AXI_RESET_OUTSTANDING_PASS kind=%0d",kind);
  endtask
  task automatic bad_boot_last(input logic missing_last);
    reset_subsystem();
    selected_op=0;
    write_reg(48,3,15,0,0,0,0);
    write_reg(8,1,15,0,0,0,0); wait_status(2);
    sending_boot=1;
    for(integer n=0;n<(missing_last?12:1);n=n+1) begin
      @(negedge clk);
      s_axis_tdata=input_word(n); s_axis_tkeep=8'hff;
      s_axis_tlast=!missing_last; s_axis_tvalid=1;
      do @(posedge clk); while(!s_axis_tready);
      @(negedge clk); s_axis_tvalid=0;
    end
    wait_status(6);
    read_reg(56,value,0);
    if(value!=2 || !irq) $fatal(1,"TLAST_ERROR_CHECK");
    write_reg(8,8,15,0,0,0,0); wait_status(0);
    read_reg(52,value,0);
    if(value[1]!=1 || !irq) $fatal(1,"DATA_RESET_MUST_PRESERVE_IRQ");
    write_reg(52,2,15,0,0,0,0);
    if(irq) $fatal(1,"ERROR_IRQ_CLEAR");
    $display("AXI_BAD_TLAST_PASS missing=%0d",missing_last);
  endtask
`endif
  task automatic run_job(input integer op);
    logic [31:0] value;
    begin
      expected_in=op==0?0:op==1?1202:3705;
      expected_out=op==0?2486:op==1?1221:2;
      selected_op=op;
      write_reg(8,8,15,0,4,5,0); wait_status(0);
      write_reg(52,3,15,0,0,0,0); // Data reset deliberately preserves AXIL IRQ state.
      write_reg(16,op,15,7,0,2,0);
      write_reg(48,3,15,0,0,0,0);
      write_reg(8,1,15,0,8,3,0); wait_status(2);
      send_packet(12,0,0,1); wait_status(3);
      write_reg(8,2,15,6,0,3,0);
      $display("AXI_START_WRITE_DONE t=%0t",$time);
      fork
        if(expected_in!=0) send_packet(expected_in,0,0,0);
        receive_packet(op,expected_out);
      join
      wait_status(5);
      read_reg(32,value,0); if(value!=expected_in) $fatal(1,"INPUT_COUNT");
      read_reg(36,value,0); if(value!=expected_out) $fatal(1,"OUTPUT_COUNT");
      read_reg(60,value,0); if(value!=12) $fatal(1,"BOOT_COUNT");
      read_reg(52,value,0); if(value[0]!=1 || !irq) $fatal(1,"DONE_IRQ");
      write_reg(52,1,15,0,0,9,0);
      if(irq) $fatal(1,"IRQ_CLEAR");
      write_reg(8,2,15,0,0,0,2); // No implicit restart without reset.
      case_count=case_count+1;
      $display("AXI_JOB_PASS op=%0d words=%0d",op,expected_out);
    end
  endtask
`ifdef REAL_CORE
  task automatic export_vectors;
    integer fd,header,n,b,words;
    logic [63:0] word;
    header=$fopen("frodokem_kat_vectors.h","w");
    if(!header) $fatal(1,"VECTOR_HEADER_OPEN");
    $fwrite(header,"/* Deterministic public test vectors; never use as production entropy. */\n");
    for(integer op=0;op<3;op=op+1) begin
      selected_op=op;
      for(integer kind=0;kind<3;kind=kind+1) begin
        sending_boot=kind==0;
        words=kind==0?12:kind==1?(op==0?0:op==1?1202:3705):(op==0?2486:op==1?1221:2);
        fd=$fopen($sformatf("op%0d_%0d.bin",op,kind),"wb");
        if(!fd) $fatal(1,"VECTOR_BIN_OPEN");
        $fwrite(header,"static const unsigned char fk_op%0d_kind%0d[%0d] = {",op,kind,words==0?1:words*8);
        if(words==0) $fwrite(header,"0");
        for(n=0;n<words;n=n+1) begin
          word=kind==2?result_word(op,n):input_word(n);
          for(b=0;b<8;b=b+1) begin
            $fwrite(fd,"%c",word[b*8+:8]);
            $fwrite(header,"%s0x%02h",n==0&&b==0?"":",",word[b*8+:8]);
          end
        end
        $fwrite(header,"};\n");
        $fclose(fd);
      end
    end
    $fclose(header);
    $display("AXI_VECTOR_EXPORT_PASS");
  endtask
`endif
  logic [31:0] value;
  initial begin
`ifdef REAL_CORE
    if($test$plusargs("EXPORT_ONLY")) begin
      #1; export_vectors(); $finish;
    end
`endif
    if($value$plusargs("SEED=%d",seed)) $display("DIRECTED_SEED=%0d",seed);
    random_state=seed==0 ? 32'h2468ace1 : 32'(seed);
    repeat(5) @(negedge clk); aresetn=1;
    wait_status(0);
    read_reg(0,value,0); if(value!=32'h46524f31) $fatal(1,"ID");
`ifdef REAL_CORE
    if(!$value$plusargs("OP=%d",selected_op)) selected_op=0;
    run_job(selected_op);
    $display("AXI_REAL_KAT_PASS op=%0d words=%0d",selected_op,expected_out);
    $finish;
`else
    write_reg(8,2,15,0,4,2,2);
    write_reg(16,3,15,8,0,0,2);
    write_reg(16,2,15,0,7,7,0);
    write_reg(16,0,0,0,0,0,0);
    read_reg(16,value,0); if(value!=2) $fatal(1,"ZERO_STROBE");
    write_reg(16,1,1,0,0,0,0);
    read_reg(16,value,0); if(value!=1) $fatal(1,"BYTE_STROBE");
    write_reg(0,0,15,0,0,0,2);
    read_reg(12'hfff,value,2);
    run_job(0); run_job(1); run_job(2);
    write_reg(8,8,15,0,0,0,0); wait_status(0);
    write_reg(8,1,15,0,0,0,0); wait_status(2);
    send_packet(1,1,1,1); wait_status(6);
    read_reg(56,value,0); if(value!=1) $fatal(1,"KEEP_ERROR");
    run_job(2);
    for(integer kind=0;kind<4;kind=kind+1) reset_outstanding(kind);
    bad_boot_last(0); bad_boot_last(1);
    // Reset an output stalled for an unbounded consumer. DATA_RESET is rejected.
    reset_subsystem(); selected_op=0; expected_in=0; expected_out=2486;
    write_reg(8,1,15,0,0,0,0); wait_status(2);
    send_packet(12,0,0,1); wait_status(3);
    write_reg(8,2,15,0,0,0,0);
    wait(m_axis_tvalid);
    repeat(256) @(negedge clk);
    write_reg(8,8,15,0,0,0,2);
    reset_subsystem();
    run_job(2);
    $display("AXI_NEGATIVE_PASS reset_cases=5 framing_cases=2 recovery=1");
    $display("AXI_SHELL_DIRECTED_PASS jobs=%0d",case_count);
    $finish;
`endif
  end
  // Optional bounded diagnostic: expose the earliest stalled protocol phase
  // without waiting for the full-operation watchdog on every investigation.
  initial begin : diagnostic_watchdog
    integer probe_ns;
    if ($value$plusargs("PROBE_NS=%d", probe_ns)) begin
      #(probe_ns);
      $display("AXI_PROGRESS op=%0d state=%0d status=%h boot=%0d seen=%0d in=%0d in_seen=%0d captured=%0d out=%0d cmd=%0d cmd_vr=%b%b in_vr=%b%b out_vr=%b%b reset=%b",
        selected_op,dut.state,dut.status,dut.boot_count,dut.boot_seen,
        dut.in_count,dut.in_seen,dut.out_captured,dut.out_count,
        native_cmd,native_cmd_valid,native_cmd_ready,native_in_valid,native_in_ready,
        native_out_valid,native_out_ready,native_rst);
      $display("AXI_BUS aw=%b%b w=%b%b b=%b%b ar=%b%b r=%b%b axis=%b%b",
        s_axi_awvalid,s_axi_awready,s_axi_wvalid,s_axi_wready,s_axi_bvalid,s_axi_bready,
        s_axi_arvalid,s_axi_arready,s_axi_rvalid,s_axi_rready,m_axis_tvalid,m_axis_tready);
      $finish;
    end
  end
  initial begin #5000000; $fatal(1,"DIRECTED_TIMEOUT"); end
endmodule

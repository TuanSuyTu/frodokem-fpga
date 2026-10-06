#include "frodokem_driver.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
struct mock { uint32_t regs[17]; uint64_t now; int rx_armed,started,hang,hang_on_start; unsigned tx_calls,rx_calls; };
static uint32_t rd(void *ctx,unsigned offset) { return ((struct mock*)ctx)->regs[offset/4]; }
static void complete(struct mock *m) {
    m->regs[FK_STATUS/4]=FK_DONE;
    m->regs[FK_IN_COUNT/4]=m->regs[FK_IN_BYTES/4]/8;
    m->regs[FK_OUT_COUNT/4]=m->regs[FK_OUT_BYTES/4]/8;
    m->regs[FK_CYCLES_LOW/4]=123;
}
static void wr(void *ctx,unsigned offset,uint32_t value) {
    struct mock *m=ctx;
    m->regs[offset/4]=value;
    if(offset==FK_OPERATION) {
        m->regs[FK_IN_BYTES/4]=(uint32_t)fk_input_size((enum fk_operation)value);
        m->regs[FK_OUT_BYTES/4]=(uint32_t)fk_output_size((enum fk_operation)value);
    }
    if(offset==FK_CONTROL) {
        if(value==8) { m->regs[FK_STATUS/4]=FK_IDLE; m->rx_armed=0; m->started=0; }
        if(value==1) m->regs[FK_STATUS/4]=FK_BOOT_READY;
        if(value==2) {
            if(m->hang_on_start) m->hang=1;
            assert(m->rx_armed); m->started=1; m->regs[FK_STATUS/4]=FK_BUSY;
            if(m->regs[FK_IN_BYTES/4]==0 && !m->hang) complete(m);
        }
    }
}
static int submit(void *ctx,enum fk_dma_direction direction,void *buffer,size_t bytes) {
    struct mock *m=ctx;
    if(direction==FK_RX) { m->rx_armed=1; m->rx_calls++; memset(buffer,0xa5,bytes); }
    else {
        m->tx_calls++;
        if(!m->started) { assert(bytes==96); m->regs[FK_BOOT_COUNT/4]=12; m->regs[FK_STATUS/4]=FK_BOOT_DONE; }
        else if(!m->hang) complete(m);
    }
    return 0;
}
static int busy(void *ctx,enum fk_dma_direction dir) { return ((struct mock*)ctx)->hang && dir==FK_RX; }
static void cache(void *ctx,void *buffer,size_t bytes) { (void)ctx; assert(buffer && bytes); }
static uint64_t timer(void *ctx) { return ((struct mock*)ctx)->now++; }
int main(void) {
    _Alignas(64) unsigned char boot[96],input[29640],output[19888];
    struct fk_stats stats;
    struct mock m={0};
    struct fk_io io={&m,rd,wr,submit,busy,cache,cache,timer};
    m.regs[FK_ID/4]=0x46524f31; m.regs[FK_CAP/4]=15;
    for(int op=0;op<3;op++) {
        assert(fk_run_kat_job(&io,(enum fk_operation)op,boot,sizeof boot,input,
            fk_input_size((enum fk_operation)op),output,fk_output_size((enum fk_operation)op),1000,&stats)==FK_OK);
        assert(stats.job_cycles==123 && output[0]==0xa5);
    }
    assert(m.tx_calls==5 && m.rx_calls==3);
    assert(fk_run_kat_job(&io,FK_KEYGEN,boot,95,NULL,0,output,19888,1000,&stats)==FK_ARGUMENT);
    assert(fk_run_kat_job(&io,FK_KEYGEN,boot,96,NULL,0,output+1,19888,1000,&stats)==FK_ARGUMENT);
    m.hang_on_start=1;
    assert(fk_run_kat_job(&io,FK_KEYGEN,boot,96,NULL,0,output,19888,10,&stats)==FK_TIMEOUT);
    assert(fk_run_kat_job(&io,FK_KEYGEN,boot,96,NULL,0,output,19888,10,&stats)==FK_DMA);
    puts("DRIVER_HOST_PASS: three operation flows, lengths, alignment, RX-before-START, timeout, active-DMA rejection");
    return 0;
}

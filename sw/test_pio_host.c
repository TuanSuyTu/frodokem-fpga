#include "frodokem_pio_driver.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
struct mock {
    unsigned op,status,boot,in,out,writes,low_full,rx_held,last;
    uint32_t low;
    uint64_t ticks;
    int wrong_id,stuck;
};
static const unsigned ins[3]={0,1202,3705},outs[3]={2486,1221,2};
static uint64_t word(unsigned n) { return UINT64_C(0x9876543210abcdef)^n; }
static uint32_t read32(void *ctx,unsigned reg) {
    struct mock *m=ctx;
    m->ticks++;
    switch(reg) {
    case FK_ID: return m->wrong_id?0x46524f31:0x46524f32;
    case FK_CAP: return 31;
    case FK_STATUS: return m->status;
    case FK_PIO_FIFO_STATUS: {
        unsigned needed=m->op==2?ins[2]:(m->out<ins[m->op]?m->out:ins[m->op]);
        unsigned rx=m->status==FK_BUSY && m->in>=needed && m->out<outs[m->op];
        unsigned inactive=m->status==FK_IDLE || m->status==FK_DONE;
        return (!m->low_full && (inactive || (!m->stuck && m->ticks%7!=0))) |
               (m->low_full<<1) | (rx&&!m->rx_held?4:0) | (m->rx_held?8:0) |
               (m->out+1==outs[m->op]?16:0);
    }
    case FK_PIO_RX_LOW: assert(!m->rx_held); m->rx_held=1; return (uint32_t)word(m->out);
    case FK_PIO_RX_HIGH: {
        assert(m->rx_held); m->rx_held=0;
        uint32_t v=(uint32_t)(word(m->out)>>32);
        m->out++;
        if(m->out==outs[m->op]) { assert(m->in==ins[m->op]); m->status=FK_DONE; }
        return v;
    }
    case FK_IN_COUNT: return m->in;
    case FK_OUT_COUNT: return m->out;
    case FK_BOOT_COUNT: return m->boot;
    case FK_CYCLES_LOW: return 12345;
    case FK_CYCLES_HIGH: return 0;
    case FK_ERROR_CODE: return 0;
    default: assert(0); return 0;
    }
}
static void write32(void *ctx,unsigned reg,uint32_t v) {
    struct mock *m=ctx;
    m->writes++;
    switch(reg) {
    case FK_CONTROL:
        if(v==8) { m->boot=m->in=m->out=m->low_full=m->rx_held=0; m->status=FK_IDLE; }
        else if(v==1) m->status=FK_BOOT_READY;
        else if(v==2) { assert(m->boot==12); m->status=FK_BUSY; }
        else assert(0);
        break;
    case FK_OPERATION: m->op=v; break;
    case FK_PARAMETER: assert(v==640); break;
    case FK_IRQ_ENABLE: assert(v==0); break;
    case FK_IRQ_STATUS: break;
    case FK_PIO_TX_LAST: assert(!m->low_full && v<=1); m->last=v; break;
    case FK_PIO_TX_LOW: assert(!m->low_full); m->low=v; m->low_full=1; break;
    case FK_PIO_TX_HIGH:
        assert(m->low_full && m->low==0x03020100 && v==0x07060504);
        m->low_full=0;
        if(m->status==FK_BOOT_READY) {
            assert(m->last==(m->boot==11));
            if(++m->boot==12) m->status=FK_BOOT_DONE;
        } else { assert(m->status==FK_BUSY); assert(m->last==(m->in+1==ins[m->op])); m->in++; }
        break;
    default: assert(0);
    }
}
static uint64_t time_us(void *ctx) { return ++((struct mock *)ctx)->ticks; }
int main(void) {
    unsigned char boot[96],input[29640],output[19888];
    for(unsigned n=0;n<sizeof boot;n++) boot[n]=(unsigned char)(n%8);
    for(unsigned n=0;n<sizeof input;n++) input[n]=(unsigned char)(n%8);
    struct mock m={.status=FK_IDLE};
    struct fk_pio_io io={&m,read32,write32,time_us};
    struct fk_stats stats;
    for(unsigned op=0;op<3;op++) {
        int rc=fk_pio_run(&io,(enum fk_operation)op,boot,input,ins[op]*8,output,outs[op]*8,1000000,&stats);
        assert(rc==FK_OK && stats.in_count==ins[op] && stats.out_count==outs[op]);
        for(unsigned n=0;n<outs[op];n++)
            for(unsigned b=0;b<8;b++) assert(output[n*8+b]==(unsigned char)(word(n)>>(b*8)));
    }
    m.wrong_id=1; unsigned writes=m.writes;
    assert(fk_pio_run(&io,FK_KEYGEN,boot,input,0,output,19888,100,&stats)==FK_HARDWARE);
    assert(m.writes==writes);
    m.wrong_id=0; m.status=FK_BUSY;
    assert(fk_pio_run(&io,FK_KEYGEN,boot,input,0,output,19888,100,&stats)==FK_HARDWARE);
    m.status=FK_IDLE; m.ticks=0;
    assert(fk_pio_run(&io,FK_KEYGEN,boot,input,1,output,19888,100,&stats)==FK_ARGUMENT);
    // Initial ready passes; after PREPARE the FIFO is forced stalled.
    m.stuck=1;
    assert(fk_pio_run(&io,FK_KEYGEN,boot,input,0,output,19888,100,&stats)==FK_TIMEOUT);
    puts("PIO_DRIVER_HOST_PASS three operations, byte order, TLAST, duplex service, old-ID and busy rejection");
    return 0;
}

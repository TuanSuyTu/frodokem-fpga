#include "frodokem_pio_driver.h"
#include <string.h>
static uint32_t load32(const unsigned char *p) {
    return (uint32_t)p[0]|(uint32_t)p[1]<<8|(uint32_t)p[2]<<16|(uint32_t)p[3]<<24;
}
static void store32(unsigned char *p,uint32_t v) {
    for(unsigned n=0;n<4;n++) p[n]=(unsigned char)(v>>(n*8));
}
static int wait_status(const struct fk_pio_io *io,uint32_t mask,uint64_t begin,uint64_t timeout) {
    for(;;) {
        uint32_t s=io->read32(io->ctx,FK_STATUS);
        if(s&FK_ERROR) return FK_HARDWARE;
        if(s&mask) return FK_OK;
        if(io->time_us(io->ctx)-begin>=timeout) return FK_TIMEOUT;
    }
}
static void push(const struct fk_pio_io *io,const unsigned char *p,int last) {
    io->write32(io->ctx,FK_PIO_TX_LAST,(uint32_t)last);
    io->write32(io->ctx,FK_PIO_TX_LOW,load32(p));
    io->write32(io->ctx,FK_PIO_TX_HIGH,load32(p+4));
}
int fk_pio_run(const struct fk_pio_io *io,enum fk_operation op,
               const unsigned char boot[96],const unsigned char *input,size_t input_size,
               unsigned char *output,size_t output_size,uint64_t timeout,
               struct fk_stats *stats) {
    static const size_t ins[3]={0,9616,29640},outs[3]={19888,9768,16};
    if(!io || !io->read32 || !io->write32 || !io->time_us || (unsigned)op>2 ||
       !boot || !output || !stats || !timeout || input_size!=ins[op] ||
       output_size!=outs[op] || (input_size && !input)) return FK_ARGUMENT;
    memset(stats,0,sizeof *stats);
    if(io->read32(io->ctx,FK_ID)!=0x46524f32 || (io->read32(io->ctx,FK_CAP)&31)!=31)
        return FK_HARDWARE; /* Reject the old DMA bitstream before any write. */
    uint32_t s=io->read32(io->ctx,FK_STATUS);
    uint32_t f=io->read32(io->ctx,FK_PIO_FIFO_STATUS);
    if(!(s&(FK_IDLE|FK_DONE)) || !(f&1) || (f&12)) return FK_HARDWARE;
    uint64_t begin=io->time_us(io->ctx);
    io->write32(io->ctx,FK_CONTROL,8);
    int rc=wait_status(io,FK_IDLE,begin,timeout);
    if(rc) return rc;
    io->write32(io->ctx,FK_IRQ_ENABLE,0);
    io->write32(io->ctx,FK_IRQ_STATUS,3);
    io->write32(io->ctx,FK_OPERATION,(uint32_t)op);
    io->write32(io->ctx,FK_PARAMETER,640);
    io->write32(io->ctx,FK_CONTROL,1);
    rc=wait_status(io,FK_BOOT_READY,begin,timeout);
    if(rc) return rc;
    for(size_t n=0;n<12;n++) {
        while(!(io->read32(io->ctx,FK_PIO_FIFO_STATUS)&1)) {
            if(io->read32(io->ctx,FK_STATUS)&FK_ERROR) return FK_HARDWARE;
            if(io->time_us(io->ctx)-begin>=timeout) return FK_TIMEOUT;
        }
        push(io,boot+n*8,n==11);
    }
    rc=wait_status(io,FK_BOOT_DONE,begin,timeout);
    if(rc) return rc;
    io->write32(io->ctx,FK_CONTROL,2);
    size_t sent=0,received=0;
    while(sent<input_size || received<output_size) {
        f=io->read32(io->ctx,FK_PIO_FIFO_STATUS);
        if(sent<input_size && (f&1)) {
            push(io,input+sent,sent+8==input_size);
            sent+=8;
        }
        if(received<output_size && (f&4)) {
            if(!!(f&16)!=(received+8==output_size)) return FK_HARDWARE;
            store32(output+received,io->read32(io->ctx,FK_PIO_RX_LOW));
            store32(output+received+4,io->read32(io->ctx,FK_PIO_RX_HIGH));
            received+=8;
        }
        if(io->read32(io->ctx,FK_STATUS)&FK_ERROR) return FK_HARDWARE;
        if(io->time_us(io->ctx)-begin>=timeout) return FK_TIMEOUT;
    }
    rc=wait_status(io,FK_DONE,begin,timeout);
    if(rc) return rc;
    stats->in_count=io->read32(io->ctx,FK_IN_COUNT);
    stats->out_count=io->read32(io->ctx,FK_OUT_COUNT);
    stats->error_code=io->read32(io->ctx,FK_ERROR_CODE);
    uint32_t high=io->read32(io->ctx,FK_CYCLES_HIGH);
    stats->job_cycles=((uint64_t)high<<32)|io->read32(io->ctx,FK_CYCLES_LOW);
    if(stats->in_count!=input_size/8 || stats->out_count!=output_size/8 ||
       stats->error_code || io->read32(io->ctx,FK_BOOT_COUNT)!=12) return FK_HARDWARE;
    return FK_OK;
}

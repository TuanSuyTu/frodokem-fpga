#include "frodokem_driver.h"
size_t fk_input_size(enum fk_operation op) {
    return op==FK_KEYGEN?0:op==FK_ENCAPS?9616:op==FK_DECAPS?29640:0;
}
size_t fk_output_size(enum fk_operation op) {
    return op==FK_KEYGEN?19888:op==FK_ENCAPS?9768:op==FK_DECAPS?16:0;
}
static int wait_status(const struct fk_io *io, uint32_t mask, uint64_t start,
                       uint64_t timeout, int check_error) {
    for (;;) {
        uint32_t status=io->read32(io->ctx,FK_STATUS);
        if(check_error && (status&FK_ERROR)) return FK_HARDWARE;
        if(status&mask) return FK_OK;
        if(io->time_us(io->ctx)-start>=timeout) return FK_TIMEOUT;
    }
}
static int wait_dma(const struct fk_io *io, enum fk_dma_direction dir,
                    uint64_t start,uint64_t timeout) {
    for (;;) {
        int busy=io->dma_busy(io->ctx,dir);
        if(busy<0) return FK_DMA;
        if(io->read32(io->ctx,FK_STATUS)&FK_ERROR) return FK_HARDWARE;
        if(!busy) return FK_OK;
        if(io->time_us(io->ctx)-start>=timeout) return FK_TIMEOUT;
    }
}
int fk_run_kat_job(const struct fk_io *io, enum fk_operation op,
                  void *bootstrap,size_t bootstrap_bytes,
                  void *input,size_t input_bytes,void *output,size_t output_bytes,
                  uint64_t timeout_us,struct fk_stats *stats) {
    int rc;
    uint64_t start;
    if(!io || !io->read32 || !io->write32 || !io->dma_submit || !io->dma_busy ||
       !io->cache_clean || !io->cache_invalidate || !io->time_us || !stats ||
       op<FK_KEYGEN || op>FK_DECAPS || !bootstrap || bootstrap_bytes!=96 || !output ||
       input_bytes!=fk_input_size(op) || output_bytes!=fk_output_size(op) ||
       (input_bytes && !input) || !timeout_us || ((uintptr_t)bootstrap&7) ||
       ((uintptr_t)output&7) || (input_bytes && ((uintptr_t)input&7))) return FK_ARGUMENT;
    if(io->read32(io->ctx,FK_ID)!=UINT32_C(0x46524f31) ||
       (io->read32(io->ctx,FK_CAP)&15)!=15) return FK_HARDWARE;
    stats->job_cycles=0; stats->in_count=0; stats->out_count=0; stats->error_code=0;
    start=io->time_us(io->ctx);
    if(io->dma_busy(io->ctx,FK_TX)!=0 || io->dma_busy(io->ctx,FK_RX)!=0) return FK_DMA;
    if(io->read32(io->ctx,FK_STATUS)&FK_BUSY) return FK_HARDWARE;
    io->write32(io->ctx,FK_CONTROL,8);
    rc=wait_status(io,FK_IDLE,start,timeout_us,0); if(rc) return rc;
    io->write32(io->ctx,FK_IRQ_STATUS,3);
    io->write32(io->ctx,FK_OPERATION,(uint32_t)op);
    io->write32(io->ctx,FK_PARAMETER,640);
    if(io->read32(io->ctx,FK_OPERATION)!=(uint32_t)op ||
       io->read32(io->ctx,FK_IN_BYTES)!=input_bytes ||
       io->read32(io->ctx,FK_OUT_BYTES)!=output_bytes) return FK_HARDWARE;
    io->write32(io->ctx,FK_CONTROL,1);
    rc=wait_status(io,FK_BOOT_READY,start,timeout_us,1); if(rc) return rc;
    io->cache_clean(io->ctx,bootstrap,bootstrap_bytes);
    if(io->dma_submit(io->ctx,FK_TX,bootstrap,bootstrap_bytes)) return FK_DMA;
    rc=wait_dma(io,FK_TX,start,timeout_us); if(rc) return rc;
    rc=wait_status(io,FK_BOOT_DONE,start,timeout_us,1); if(rc) return rc;
    io->cache_clean(io->ctx,output,output_bytes);
    if(io->dma_submit(io->ctx,FK_RX,output,output_bytes)) return FK_DMA;
    io->write32(io->ctx,FK_CONTROL,2);
    if(input_bytes) {
        io->cache_clean(io->ctx,input,input_bytes);
        if(io->dma_submit(io->ctx,FK_TX,input,input_bytes)) return FK_DMA;
        rc=wait_dma(io,FK_TX,start,timeout_us); if(rc) return rc;
    }
    rc=wait_dma(io,FK_RX,start,timeout_us); if(rc) return rc;
    rc=wait_status(io,FK_DONE,start,timeout_us,1); if(rc) return rc;
    io->cache_invalidate(io->ctx,output,output_bytes);
    stats->in_count=io->read32(io->ctx,FK_IN_COUNT);
    stats->out_count=io->read32(io->ctx,FK_OUT_COUNT);
    stats->error_code=io->read32(io->ctx,FK_ERROR_CODE);
    stats->job_cycles=((uint64_t)io->read32(io->ctx,FK_CYCLES_HIGH)<<32)|
                     io->read32(io->ctx,FK_CYCLES_LOW);
    if(stats->in_count!=input_bytes/8 || stats->out_count!=output_bytes/8 ||
       io->read32(io->ctx,FK_BOOT_COUNT)!=12 || stats->error_code) return FK_HARDWARE;
    return FK_OK;
}

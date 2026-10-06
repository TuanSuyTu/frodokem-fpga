#ifndef FRODOKEM_DRIVER_H
#define FRODOKEM_DRIVER_H
#include <stddef.h>
#include <stdint.h>
enum fk_operation { FK_KEYGEN=0, FK_ENCAPS=1, FK_DECAPS=2 };
enum fk_dma_direction { FK_TX=0, FK_RX=1 };
enum fk_result { FK_OK=0, FK_ARGUMENT=-1, FK_TIMEOUT=-2, FK_HARDWARE=-3, FK_DMA=-4 };
enum { FK_ID=0x00, FK_CAP=0x04, FK_CONTROL=0x08, FK_STATUS=0x0c,
       FK_OPERATION=0x10, FK_PARAMETER=0x14, FK_IN_BYTES=0x18, FK_OUT_BYTES=0x1c,
       FK_IN_COUNT=0x20, FK_OUT_COUNT=0x24, FK_CYCLES_LOW=0x28, FK_CYCLES_HIGH=0x2c,
       FK_IRQ_ENABLE=0x30, FK_IRQ_STATUS=0x34, FK_ERROR_CODE=0x38, FK_BOOT_COUNT=0x3c };
enum { FK_IDLE=1, FK_BOOT_READY=4, FK_BOOT_DONE=8, FK_BUSY=16, FK_DONE=32, FK_ERROR=64 };
struct fk_io {
    void *ctx;
    uint32_t (*read32)(void *ctx, unsigned offset);
    void (*write32)(void *ctx, unsigned offset, uint32_t value);
    int (*dma_submit)(void *ctx, enum fk_dma_direction direction, void *buffer, size_t bytes);
    int (*dma_busy)(void *ctx, enum fk_dma_direction direction); /* 0 done, 1 busy, negative error */
    void (*cache_clean)(void *ctx, void *buffer, size_t bytes);
    void (*cache_invalidate)(void *ctx, void *buffer, size_t bytes);
    uint64_t (*time_us)(void *ctx);
};
struct fk_stats { uint64_t job_cycles; uint32_t in_count,out_count,error_code; };
size_t fk_input_size(enum fk_operation op);
size_t fk_output_size(enum fk_operation op);
int fk_run_kat_job(const struct fk_io *io, enum fk_operation op,
                  void *bootstrap, size_t bootstrap_bytes,
                  void *input, size_t input_bytes, void *output, size_t output_bytes,
                  uint64_t timeout_us, struct fk_stats *stats);
/* On timeout/error, DMA may still be active. Caller MUST quiesce/reset the subsystem
 * before reusing/freeing buffers. This driver never silently replays a job. */
#endif

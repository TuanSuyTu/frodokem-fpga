#ifndef FRODOKEM_PIO_DRIVER_H
#define FRODOKEM_PIO_DRIVER_H
#include <stddef.h>
#include <stdint.h>
enum fk_operation { FK_KEYGEN=0, FK_ENCAPS=1, FK_DECAPS=2 };
enum fk_result { FK_OK=0, FK_ARGUMENT=-1, FK_TIMEOUT=-2, FK_HARDWARE=-3 };
enum { FK_ID=0x00, FK_CAP=0x04, FK_CONTROL=0x08, FK_STATUS=0x0c,
       FK_OPERATION=0x10, FK_PARAMETER=0x14, FK_IN_BYTES=0x18, FK_OUT_BYTES=0x1c,
       FK_IN_COUNT=0x20, FK_OUT_COUNT=0x24, FK_CYCLES_LOW=0x28, FK_CYCLES_HIGH=0x2c,
       FK_IRQ_ENABLE=0x30, FK_IRQ_STATUS=0x34, FK_ERROR_CODE=0x38, FK_BOOT_COUNT=0x3c };
enum { FK_IDLE=1, FK_BOOT_READY=4, FK_BOOT_DONE=8, FK_BUSY=16, FK_DONE=32, FK_ERROR=64 };
struct fk_stats { uint64_t job_cycles; uint32_t in_count,out_count,error_code; };
enum { FK_PIO_TX_LOW=0x100, FK_PIO_TX_HIGH=0x104,
       FK_PIO_RX_LOW=0x108, FK_PIO_RX_HIGH=0x10c,
       FK_PIO_FIFO_STATUS=0x110, FK_PIO_TX_LAST=0x114 };
struct fk_pio_io {
    void *ctx;
    uint32_t (*read32)(void *,unsigned);
    void (*write32)(void *,unsigned,uint32_t);
    uint64_t (*time_us)(void *);
};
int fk_pio_run(const struct fk_pio_io *io,enum fk_operation op,
               const unsigned char boot[96],const unsigned char *input,size_t input_size,
               unsigned char *output,size_t output_size,uint64_t timeout_us,
               struct fk_stats *stats);
#endif

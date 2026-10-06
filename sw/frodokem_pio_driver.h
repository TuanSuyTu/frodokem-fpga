#ifndef FRODOKEM_PIO_DRIVER_H
#define FRODOKEM_PIO_DRIVER_H
#include "frodokem_driver.h"
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

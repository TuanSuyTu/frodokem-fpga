#ifndef FPGA_DRIVER_H
#define FPGA_DRIVER_H
#include "frodokem_driver.h"
struct fk_mapping { void *ptr; size_t size; uint64_t phys; };
struct fk_linux { struct fk_mapping regs, dma, ddr; };
/* Names are sysfs UIO names, NOT hard-coded uio numbers. DDR must be a
 * reserved, DMA-accessible region with an uncached/coherent user mapping.
 * Opening fails unless the caller explicitly acknowledges that contract. */
int fpga_open(struct fk_linux *ctx, const char *regs, const char *dma,
              const char *ddr, int confirmed_dma_safe);
void fpga_close(struct fk_linux *ctx); /* Only after DMA is quiescent. */
void fpga_bind(struct fk_io *io, struct fk_linux *ctx);
#endif

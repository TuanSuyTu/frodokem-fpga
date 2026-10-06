#include "FPGA_Driver.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>
int main(void) {
    uint32_t regs[16]={0},dma[32]={0};
    _Alignas(64) unsigned char ddr[65536];
    struct fk_linux c={.regs={regs,sizeof regs,0xa0000000},
        .dma={dma,sizeof dma,0xa0010000},.ddr={ddr,sizeof ddr,UINT64_C(0x800000000)}};
    struct fk_io io; fpga_bind(&io,&c);
    dma[1]=1; dma[0x34/4]=1;
    assert(io.dma_busy(&c,FK_TX)==0); /* Reset Halted, Idle=0. */
    dma[1]=0;
    assert(io.dma_busy(&c,FK_TX)==1);
    dma[1]=8; assert(io.dma_busy(&c,FK_TX)<0); /* SG excluded. */
    dma[1]=0x10; assert(io.dma_busy(&c,FK_TX)<0);
    dma[1]=2;
    uint32_t saved[32]; memcpy(saved,dma,sizeof dma);
    assert(io.dma_submit(&c,FK_TX,ddr+1,96)<0);
    assert(io.dma_submit(&c,FK_TX,ddr+65528,96)<0);
    assert(io.dma_submit(&c,FK_TX,ddr,65536)<0);
    assert(!memcmp(saved,dma,sizeof dma)); /* Invalid args must not write MMIO. */
    assert(io.dma_submit(&c,FK_TX,ddr+4096,96)==0);
    assert(dma[0x18/4]==4096 && dma[0x1c/4]==8 && dma[0x28/4]==96);
    dma[1]=2; assert(io.dma_busy(&c,FK_TX)==1); /* Idle alone isn't our completion. */
    dma[1]=0x1002; assert(io.dma_busy(&c,FK_TX)==0);
    c.pending[FK_TX]=1; dma[1]=1; assert(io.dma_busy(&c,FK_TX)<0);
    puts("LINUX_BACKEND_HOST_PASS: halted startup, active/SG/error rejection, bounds/alignment, 64-bit addresses, completion tracking");
    return 0;
}

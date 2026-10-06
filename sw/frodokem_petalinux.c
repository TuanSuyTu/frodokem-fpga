#include "FPGA_Driver.h"
#include "frodokem_kat_vectors.h"
#include <stdio.h>
#include <string.h>
int main(int argc,char **argv) {
    if(argc!=5 || strcmp(argv[4],"--confirmed-reserved-uncached-ddr")) {
        fprintf(stderr,"Usage: %s ACCEL_UIO_NAME AXIDMA_UIO_NAME DDR_UIO_NAME --confirmed-reserved-uncached-ddr\n",argv[0]);
        return 2;
    }
    struct fk_linux context;
    if(fpga_open(&context,argv[1],argv[2],argv[3],1)) { perror("fpga_open"); return 1; }
    struct fk_io io; struct fk_stats stats;
    fpga_bind(&io,&context);
    unsigned char *boot=context.ddr.ptr;
    unsigned char *input=boot+4096,*output=boot+36864;
    const unsigned char *boots[]={fk_op0_kind0,fk_op1_kind0,fk_op2_kind0};
    const unsigned char *inputs[]={fk_op0_kind1,fk_op1_kind1,fk_op2_kind1};
    const unsigned char *expected[]={fk_op0_kind2,fk_op1_kind2,fk_op2_kind2};
    for(int op=0;op<3;op++) {
        size_t in=fk_input_size(op),out=fk_output_size(op);
        memcpy(boot,boots[op],96);
        if(in) memcpy(input,inputs[op],in);
        memset(output,0x5a,out);
        int rc=fk_run_kat_job(&io,op,boot,96,input,in,output,out,1000000,&stats);
        if(rc) {
            fprintf(stderr,"JOB_FAIL op=%d rc=%d status=%08x; do not reuse DDR until DMA quiesced\n",op,rc,io.read32(io.ctx,FK_STATUS));
            /* No automatic DMA reset/replay or explicit DDR unmap. Reserved
             * DDR must remain reserved after this process exits. */
            return 1;
        }
        for(size_t i=0;i<out;i++) if(output[i]!=expected[op][i]) {
            fprintf(stderr,"KAT_FAIL op=%d byte=%zu expected=%02x actual=%02x\n",op,i,expected[op][i],output[i]);
            fpga_close(&context); return 1;
        }
        printf("BOARD_KAT_PASS op=%d bytes=%zu cycles=%llu\n",op,out,(unsigned long long)stats.job_cycles);
    }
    fpga_close(&context);
    puts("KV260_ALL_KAT_PASS");
    return 0;
}

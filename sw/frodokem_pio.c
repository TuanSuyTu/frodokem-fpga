#define _POSIX_C_SOURCE 200809L
#include "frodokem_pio_driver.h"
#include "frodokem_kat_vectors.h"
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

static int syshex(const char *dev,const char *field,unsigned long long *v) {
    char path[256];
    snprintf(path,sizeof path,"/sys/class/uio/%s/maps/map0/%s",dev,field);
    FILE *f=fopen(path,"r");
    if(!f) return -1;
    int ok=fscanf(f,"%llx",v)==1;
    fclose(f);
    return ok?0:-1;
}
static int discover(char chosen[64]) {
    DIR *dir=opendir("/sys/class/uio");
    if(!dir) { perror("UIO sysfs"); return -1; }
    struct dirent *e;
    int count=0;
    while((e=readdir(dir))) {
        if(strncmp(e->d_name,"uio",3) || strlen(e->d_name)>=64) continue;
        unsigned long long addr,size,offset;
        if(syshex(e->d_name,"addr",&addr) || syshex(e->d_name,"size",&size) ||
           syshex(e->d_name,"offset",&offset)) continue;
        if(addr==0xa0000000) {
            printf("PIO_UIO_CANDIDATE /dev/%s base=0x%llx size=0x%llx offset=0x%llx\n",e->d_name,addr,size,offset);
            if(size>=0x118 && !offset) { strcpy(chosen,e->d_name); count++; }
        }
    }
    closedir(dir);
    if(count!=1) { fprintf(stderr,"Need exactly one suitable UIO at 0xA0000000, found %d\n",count); return -1; }
    return 0;
}
static uint32_t rd(void *ctx,unsigned off) {
    uint32_t v=((volatile uint32_t *)ctx)[off/4];
    __sync_synchronize();
    return v;
}
static void wr(void *ctx,unsigned off,uint32_t v) {
    __sync_synchronize();
    ((volatile uint32_t *)ctx)[off/4]=v;
    __sync_synchronize();
}
static uint64_t now_us(void *ctx) {
    (void)ctx;
    struct timespec t;
    if(clock_gettime(CLOCK_MONOTONIC,&t)) { perror("clock_gettime"); exit(1); }
    return (uint64_t)t.tv_sec*1000000+(uint64_t)t.tv_nsec/1000;
}
int main(int argc,char **argv) {
    int run=argc==2 && !strcmp(argv[1],"--run");
    if(argc!=1 && !(argc==2 && (!strcmp(argv[1],"--probe") || run))) {
        fprintf(stderr,"Usage: %s [--probe | --run]\n",argv[0]); return 2;
    }
    char device[64]={0};
    if(discover(device)) return 1;
    if(!run) {
        puts("PROBE_ONLY: sysfs only. No MMIO, DMA or reserved DDR. Load the PIO bitstream before --run.");
        return 0;
    }
    char path[80];
    snprintf(path,sizeof path,"/dev/%s",device);
    int fd=open(path,O_RDWR|O_SYNC);
    if(fd<0) { perror(path); return 1; }
    if(flock(fd,LOCK_EX|LOCK_NB)) { perror("exclusive UIO lock"); close(fd); return 1; }
    // Only accelerator registers, never a DMA/physical DDR mapping.
    size_t size=0x118;
    void *map=mmap(NULL,size,PROT_READ|PROT_WRITE,MAP_SHARED,fd,0);
    if(map==MAP_FAILED) { perror("UIO mmap"); close(fd); return 1; }
    struct fk_pio_io io={map,rd,wr,now_us};
    const unsigned char *boot[3]={fk_op0_kind0,fk_op1_kind0,fk_op2_kind0};
    const unsigned char *input[3]={fk_op0_kind1,fk_op1_kind1,fk_op2_kind1};
    const unsigned char *expected[3]={fk_op0_kind2,fk_op1_kind2,fk_op2_kind2};
    const size_t in_size[3]={0,9616,29640},out_size[3]={19888,9768,16};
    unsigned char output[19888];
    int failed=0;
    for(unsigned op=0;op<3;op++) {
        struct fk_stats stats;
        uint64_t start=now_us(NULL);
        int rc=fk_pio_run(&io,(enum fk_operation)op,boot[op],input[op],in_size[op],
                          output,out_size[op],10000000,&stats);
        if(rc) {
            fprintf(stderr,"PIO_FAIL op=%u rc=%d. Stop; inspect/reset FPGA before retry.\n",op,rc);
            failed=1; break;
        }
        size_t n;
        for(n=0;n<out_size[op];n++) if(output[n]!=expected[op][n]) break;
        if(n!=out_size[op]) {
            fprintf(stderr,"PIO_KAT_MISMATCH op=%u byte=%zu got=%02x expected=%02x\n",op,n,output[n],expected[op][n]);
            failed=1; break;
        }
        printf("BOARD_PIO_KAT_PASS op=%u bytes=%zu core_cycles=%llu wall_us=%llu\n",op,out_size[op],
               (unsigned long long)stats.job_cycles,(unsigned long long)(now_us(NULL)-start));
    }
    munmap(map,size); close(fd);
    if(!failed) puts("KV260_PIO_ALL_KAT_PASS");
    return failed;
}

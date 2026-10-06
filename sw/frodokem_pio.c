#define _POSIX_C_SOURCE 200809L
#include "frodokem_pio_driver.h"
#include "frodokem_kat_vectors.h"
#include "frodokem_random.h"
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
#include <math.h>

struct mmio_context {
    void *map;
    int profile;
    uint64_t tx_ns,rx_ns,other_ns;
};
static uint64_t now_ns(void) {
    struct timespec t;
    if(clock_gettime(CLOCK_MONOTONIC,&t)) { perror("clock_gettime"); exit(1); }
    return (uint64_t)t.tv_sec*1000000000+(uint64_t)t.tv_nsec;
}

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
    struct mmio_context *m=ctx;
    uint64_t begin=m->profile?now_ns():0;
    uint32_t v=((volatile uint32_t *)m->map)[off/4];
    __sync_synchronize();
    if(m->profile) {
        uint64_t ns=now_ns()-begin;
        if(off==FK_PIO_RX_LOW || off==FK_PIO_RX_HIGH) m->rx_ns+=ns;
        else m->other_ns+=ns;
    }
    return v;
}
static void wr(void *ctx,unsigned off,uint32_t v) {
    struct mmio_context *m=ctx;
    uint64_t begin=m->profile?now_ns():0;
    __sync_synchronize();
    ((volatile uint32_t *)m->map)[off/4]=v;
    __sync_synchronize();
    if(m->profile) {
        uint64_t ns=now_ns()-begin;
        if(off==FK_PIO_TX_LOW || off==FK_PIO_TX_HIGH || off==FK_PIO_TX_LAST) m->tx_ns+=ns;
        else m->other_ns+=ns;
    }
}
static uint64_t now_us(void *ctx) {
    (void)ctx;
    return now_ns()/1000;
}

struct operation_summary {
    unsigned pass,fail;
    uint64_t wall_ns,min_ns,max_ns,cycles,tx_ns,rx_ns,other_ns;
};
struct case_result { unsigned id; int verdict[3]; uint64_t wall_ns[3]; };
static const char *const op_name[3]={"KeyGen","Encaps","Decaps"};

static int random_run(const struct fk_pio_io *io,struct mmio_context *mmio,
                      const unsigned char *data,uint32_t count,double clock_hz) {
    struct operation_summary summary[3]={{0}};
    struct case_result last[10]={{0}};
    unsigned char kg[19888],enc[9768],ss[16],input[29640],zero_boot[96]={0};
    uint32_t cases_pass=0,attempted=0;
    int failed=0;
    puts("============================================================");
#ifdef FK_HOST_TEST
    puts("HOST MOCK ONLY | runner verification, NOT FPGA results");
#else
    puts("FrodoKEM-640-SHAKE | KV260 AXI-Lite random regression");
#endif
    printf("Independent random cases: %u | Planned operations: %u\n",count,count*3);
    puts("Oracle: official software reference, gated against LightSec KAT");
    printf("PL clock assumed: %.6f MHz (not a runtime measurement)\n",clock_hz/1e6);
    printf("MMIO profiling: %s\n",mmio->profile?"ON: timer instrumentation changes runtime":"OFF: low-overhead wall/cycle measurement");
    puts("Job cycles include PIO stalls; pure compute time is NOT measured.");
    puts("============================================================");
    fflush(stdout);
    uint64_t all_begin=now_ns();
    for(uint32_t c=0;c<count;c++) {
        const unsigned char *r=data+(size_t)c*FK_RANDOM_RECORD;
        struct case_result *row=&last[c%10];
        memset(row,0,sizeof *row); row->id=c+1;
        attempted++;
        for(unsigned op=0;op<3;op++) {
            const unsigned char *boot=op==0?r:op==1?r+96:zero_boot;
            const unsigned char *expected=op==0?r+FK_RANDOM_KG:op==1?r+FK_RANDOM_ENC:r+FK_RANDOM_ENC+9752;
            unsigned char *out=op==0?kg:op==1?enc:ss;
            size_t in_size=op==0?0:op==1?9616:29640;
            size_t out_size=op==0?19888:op==1?9768:16;
            if(op==1) fk_random_enc_input(input,kg);
            if(op==2) fk_random_dec_input(input,kg,enc);
            mmio->tx_ns=mmio->rx_ns=mmio->other_ns=0;
            struct fk_stats stats;
            uint64_t begin=now_ns();
            int rc=fk_pio_run(io,(enum fk_operation)op,boot,input,in_size,out,out_size,10000000,&stats);
            uint64_t duration=now_ns()-begin;
            row->wall_ns[op]=duration;
            size_t mismatch=out_size;
            if(!rc) for(size_t b=0;b<out_size;b++) if(out[b]!=expected[b]) { mismatch=b; break; }
            if(rc || mismatch!=out_size) {
                row->verdict[op]=-1; summary[op].fail++; failed=1;
                fprintf(stderr,"RANDOM_FAIL case=%u op=%s rc=%d",c+1,op_name[op],rc);
                if(!rc) fprintf(stderr," byte=%zu got=%02x expected=%02x",mismatch,out[mismatch],expected[mismatch]);
                fputs("\nStop: no automatic replay.\n",stderr);
                break;
            }
            row->verdict[op]=1;
            struct operation_summary *s=&summary[op];
            s->pass++; s->wall_ns+=duration; s->cycles+=stats.job_cycles;
            s->tx_ns+=mmio->tx_ns; s->rx_ns+=mmio->rx_ns; s->other_ns+=mmio->other_ns;
            if(s->pass==1 || duration<s->min_ns) s->min_ns=duration;
            if(duration>s->max_ns) s->max_ns=duration;
        }
        if(failed) break;
        cases_pass++;
    }
    uint64_t total_ns=now_ns()-all_begin;
    puts("\nLAST 10 ATTEMPTED CASES | time per operation in ms");
    unsigned first=attempted>10?attempted-10:0;
    for(unsigned c=first;c<attempted;c++) {
        const struct case_result *r=&last[c%10];
        printf("%04u",r->id);
        for(unsigned op=0;op<3;op++) printf(" | %-6s %-7s %7.3f",op_name[op],
            r->verdict[op]>0?"PASS":r->verdict[op]<0?"FAIL":"NOT_RUN",r->wall_ns[op]/1e6);
        putchar('\n');
    }
    puts("\nOPERATION SUMMARY | successful operations only | mean/min/max wall ms | mean job cycles | estimated job ms");
    unsigned operations_pass=0,operations_fail=0;
    for(unsigned op=0;op<3;op++) {
        const struct operation_summary *s=&summary[op];
        operations_pass+=s->pass; operations_fail+=s->fail;
        double n=s->pass?s->pass:1;
        printf("%-7s PASS=%u FAIL=%u NOT_RUN=%u wall=%.3f/%.3f/%.3f cycles=%.1f job_ms_est=%.3f\n",
            op_name[op],s->pass,s->fail,count-s->pass-s->fail,
            s->wall_ns/n/1e6,s->min_ns/1e6,s->max_ns/1e6,s->cycles/n,s->cycles/n/clock_hz*1000);
        if(mmio->profile) printf("        CPU MMIO service totals: TX=%.3f ms RX=%.3f ms control/poll=%.3f ms\n",
            s->tx_ns/1e6,s->rx_ns/1e6,s->other_ns/1e6);
    }
    printf("\nCASES: planned=%u attempted=%u PASS=%u FAIL=%u NOT_RUN=%u\n",count,attempted,cases_pass,
           failed?1:0,count-attempted);
    printf("OPERATIONS: PASS=%u FAIL=%u NOT_RUN=%u\n",operations_pass,operations_fail,count*3-operations_pass-operations_fail);
    printf("TOTAL REGRESSION WALL: %.3f s (excludes dataset validation and report printing)\n",total_ns/1e9);
    puts("TX/RX service overlaps job execution: do NOT add TX + RX + job time.");
    puts("No pure-compute, link-only transfer time or board energy claim.");
#ifdef FK_HOST_TEST
    puts(failed?"HOST_MOCK_REGRESSION_FAIL":"HOST_MOCK_REGRESSION_PASS");
#else
    puts(failed?"KV260_RANDOM_REGRESSION_FAIL":"KV260_RANDOM_REGRESSION_PASS");
#endif
    return failed;
}
int main(int argc,char **argv) {
    int mode=0,profile=0,actions=0;
    const char *dataset=NULL;
    double clock_hz=50024473.0;
    for(int i=1;i<argc;i++) {
        if(!strcmp(argv[i],"--run")) { mode=1; actions++; }
        else if(!strcmp(argv[i],"--probe")) { mode=0; actions++; }
        else if((!strcmp(argv[i],"--random")||!strcmp(argv[i],"--check")) && i+1<argc) {
            mode=!strcmp(argv[i],"--random")?2:3; dataset=argv[++i]; actions++;
        } else if(!strcmp(argv[i],"--profile-io")) profile=1;
        else if(!strcmp(argv[i],"--clock-hz") && i+1<argc) {
            char *end; clock_hz=strtod(argv[++i],&end);
            if(*end||!isfinite(clock_hz)||clock_hz<1000000||clock_hz>200000000) goto usage;
        } else goto usage;
    }
    if(actions>1) goto usage;
    unsigned char *data=NULL,header[FK_RANDOM_HEADER]; uint32_t cases=0;
    if(dataset) {
        FILE *f=fopen(dataset,"rb");
        if(!f) { perror(dataset); return 1; }
        int rc=fk_random_load(f,&data,&cases,header); fclose(f);
        if(rc) { fputs("DATASET_INVALID: no hardware access performed\n",stderr); return 1; }
        printf("DATASET_VALID cases=%u bytes=%zu seed=%.*s ref=%.*s\n",cases,
            (size_t)cases*FK_RANDOM_RECORD+FK_RANDOM_HEADER,32,header+20,40,header+52);
        if(mode==3) { free(data); return 0; }
    }
    char device[64]={0};
    if(discover(device)) { free(data); return 1; }
    if(!mode) {
        puts("PROBE_ONLY: sysfs only. No MMIO, DMA or reserved DDR. Load the PIO bitstream before --run.");
        return 0;
    }
    char path[80];
    snprintf(path,sizeof path,"/dev/%s",device);
    int fd=open(path,O_RDWR|O_SYNC);
    if(fd<0) { perror(path); free(data); return 1; }
    if(flock(fd,LOCK_EX|LOCK_NB)) { perror("exclusive UIO lock"); close(fd); free(data); return 1; }
    // Only accelerator registers, never a DMA/physical DDR mapping.
    size_t size=0x118;
    void *map=mmap(NULL,size,PROT_READ|PROT_WRITE,MAP_SHARED,fd,0);
    if(map==MAP_FAILED) { perror("UIO mmap"); close(fd); free(data); return 1; }
    struct mmio_context mmio={.map=map,.profile=profile};
    struct fk_pio_io io={&mmio,rd,wr,now_us};
    if(mode==2) {
        int failed=random_run(&io,&mmio,data,cases,clock_hz);
        munmap(map,size); close(fd); free(data); return failed;
    }
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
        printf("BOARD_PIO_KAT_PASS op=%u bytes=%zu job_cycles_including_stalls=%llu wall_us=%llu\n",op,out_size[op],
               (unsigned long long)stats.job_cycles,(unsigned long long)(now_us(NULL)-start));
    }
    munmap(map,size); close(fd);
    if(!failed) puts("KV260_PIO_ALL_KAT_PASS");
    return failed;
usage:
    fprintf(stderr,"Usage: %s [--probe | --run | --check FILE | --random FILE] [--profile-io] [--clock-hz HZ]\n",argv[0]);
    return 2;
}

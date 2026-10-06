/* Host-only oracle/runner tests. This does NOT simulate FPGA arithmetic. */
#define main pio_application_main
#define FK_HOST_TEST
#include "../../sw/frodokem_pio.c"
#undef main
#include <assert.h>

static const unsigned char *oracle;
static unsigned call_number,fail_call=UINT32_MAX;
int fk_pio_run(const struct fk_pio_io *io,enum fk_operation op,
               const unsigned char boot[96],const unsigned char *input,size_t in_size,
               unsigned char *output,size_t out_size,uint64_t timeout,struct fk_stats *stats) {
    (void)io; (void)timeout;
    unsigned case_id=call_number/3,expected_op=call_number%3;
    const unsigned char *r=oracle+(size_t)case_id*FK_RANDOM_RECORD;
    unsigned char expected_input[29640],zero[96]={0};
    assert((unsigned)op==expected_op);
    assert(!memcmp(boot,op==0?r:op==1?r+96:zero,96));
    assert(in_size==(op==0?0:op==1?9616:29640));
    assert(out_size==(op==0?19888:op==1?9768:16));
    if(op==1) fk_random_enc_input(expected_input,r+FK_RANDOM_KG);
    if(op==2) fk_random_dec_input(expected_input,r+FK_RANDOM_KG,r+FK_RANDOM_ENC);
    if(in_size) assert(!memcmp(input,expected_input,in_size));
    memcpy(output,op==0?r+FK_RANDOM_KG:op==1?r+FK_RANDOM_ENC:r+FK_RANDOM_ENC+9752,out_size);
    memset(stats,0,sizeof *stats); stats->job_cycles=100+op;
    if(call_number++==fail_call) output[0]^=1;
    return 0;
}

static void format_tests(void) {
    assert(fk_crc32((const unsigned char *)"123456789",9)==UINT32_C(0xcbf43926));
    unsigned char input[29640];
    fk_random_enc_input(input,fk_op0_kind2);
    assert(!memcmp(input,fk_op1_kind1,9616));
    fk_random_dec_input(input,fk_op0_kind2,fk_op1_kind2);
    assert(!memcmp(input,fk_op2_kind1,29640));
    unsigned char h[128]={0},record[FK_RANDOM_RECORD]={0},read_h[128];
    memcpy(h,"FRD640R1",8); fk_put32(h+8,1); fk_put32(h+12,1);
    fk_put32(h+16,FK_RANDOM_RECORD); memset(h+52,'a',40);
    fk_put32(h+124,fk_crc32(h,124));
    fk_put32(record+FK_RANDOM_DATA,fk_crc32(record,FK_RANDOM_DATA));
    for(unsigned scenario=0;scenario<9;scenario++) {
        unsigned char hh[128],rr[FK_RANDOM_RECORD];
        memcpy(hh,h,128); memcpy(rr,record,sizeof rr);
        size_t bytes=sizeof rr;
        if(scenario==1) hh[0]^=1;
        if(scenario==2) rr[0]^=1;
        if(scenario==3) bytes--;
        if(scenario==5) { fk_put32(hh+12,1001); fk_put32(hh+124,fk_crc32(hh,124)); }
        if(scenario==6) { hh[92]=1; fk_put32(hh+124,fk_crc32(hh,124)); }
        if(scenario==7) { hh[52]='z'; fk_put32(hh+124,fk_crc32(hh,124)); }
        if(scenario==8) { rr[48]=1; fk_put32(rr+FK_RANDOM_DATA,fk_crc32(rr,FK_RANDOM_DATA)); }
        FILE *f=tmpfile(); assert(f);
        assert(fwrite(hh,1,128,f)==128); assert(fwrite(rr,1,bytes,f)==bytes);
        if(scenario==4) assert(fputc(0,f)!=EOF);
        rewind(f); unsigned char *data=NULL; uint32_t count=0;
        int rc=fk_random_load(f,&data,&count,read_h);
        assert(scenario==0?rc==0:rc!=0);
        if(!rc) assert(count==1);
        free(data); fclose(f);
    }
    puts("RANDOM_FORMAT_AND_KAT_PACKING_PASS");
}
int main(int argc,char **argv) {
    assert(argc==2); format_tests();
    FILE *f=fopen(argv[1],"rb"); assert(f);
    unsigned char *data=NULL,h[128]; uint32_t count=0;
    assert(!fk_random_load(f,&data,&count,h)); fclose(f); assert(count==1000);
    /* Check distinct bootstrap pairs, independently of the generator. */
    for(unsigned i=0;i<count;i++) for(unsigned j=0;j<i;j++)
        assert(memcmp(data+(size_t)i*FK_RANDOM_RECORD,data+(size_t)j*FK_RANDOM_RECORD,192));
    oracle=data; struct fk_pio_io io={0}; struct mmio_context mmio={0};
    assert(!random_run(&io,&mmio,data,count,50024473)); assert(call_number==3000);
    call_number=0; fail_call=2995; /* case 999 Encaps: Decaps and case 1000 must not run. */
    assert(random_run(&io,&mmio,data,count,50024473)==1); assert(call_number==2996);
    free(data); puts("HOST_RANDOM_RUNNER_PASS success=3000 fail_fast=verified (NO BOARD TEST)");
    return 0;
}

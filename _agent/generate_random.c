/* Test-only deterministic entropy. Never use these keys in production. */
#include "api_frodo640.h"
#include "fips202.h"
#include "frodokem_kat_vectors.h"
#include "frodokem_random.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static unsigned char random_tape[112];
static size_t tape_size;
static int tape_error;
int randombytes(unsigned char *out,unsigned long long n) {
    if(n!=tape_size) { tape_error=1; return -1; }
    memcpy(out,random_tape,tape_size); tape_size=0; return 0;
}
static void arm(const unsigned char *p,size_t n) {
    memcpy(random_tape,p,n); tape_size=n;
}
static void boot_to_random(const unsigned char *boot) {
    unsigned char r[64];
    memcpy(r,boot+32,16); memcpy(r+16,boot,32); memcpy(r+48,boot+80,16);
    arm(r,sizeof r);
}
static int reference(const unsigned char *bkg,const unsigned char *benc,
                     unsigned char kg[19888],unsigned char enc[9768]) {
    unsigned char pk[9616],sk[19888],ss[16];
    boot_to_random(bkg);
    if(crypto_kem_keypair_Frodo640(pk,sk)||tape_size||tape_error) return -1;
    /* Standard SK: s|pk|S|pkh. Wire KeyGen: s|S|pk|pkh. */
    memcpy(kg,sk,16); memcpy(kg+16,sk+9632,10240);
    memcpy(kg+10256,pk,9616); memcpy(kg+19872,sk+19872,16);
    arm(benc+32,48);
    if(crypto_kem_enc_Frodo640(enc,enc+9752,pk)||tape_size||tape_error) return -1;
    if(crypto_kem_dec_Frodo640(ss,enc,sk)||memcmp(ss,enc+9752,16)) return -1;
    return 0;
}
static int equal(const char *name,const unsigned char *a,const unsigned char *b,size_t n) {
    for(size_t i=0;i<n;i++) if(a[i]!=b[i]) {
        fprintf(stderr,"REF_MISMATCH %s byte=%zu got=%02x expected=%02x\n",name,i,a[i],b[i]);
        return 0;
    }
    return 1;
}
int main(int argc,char **argv) {
    if(argc!=4) { fprintf(stderr,"Usage: generate_random OUTPUT COUNT REF_SHA\n"); return 2; }
    char *end; unsigned long count=strtoul(argv[2],&end,10);
    if(*end||count<1||count>1000||strlen(argv[3])!=40) return 2;
    unsigned char kg[19888],enc[9768];
    if(reference(fk_op0_kind0,fk_op1_kind0,kg,enc) ||
       !equal("KeyGen",kg,fk_op0_kind2,sizeof kg) ||
       !equal("Encaps",enc,fk_op1_kind2,sizeof enc) ||
       !equal("Decaps",enc+9752,fk_op2_kind2,16)) return 3;
    puts("OFFICIAL_REFERENCE_LIGHTSEC_KAT_PASS all pk/sk/ct/ss wire bytes");
    unsigned char header[FK_RANDOM_HEADER]={0},record[FK_RANDOM_RECORD]={0};
    const unsigned char seed[]="FrodoKEM-test-golden-20261007-v1";
    memcpy(header,"FRD640R1",8); fk_put32(header+8,1); fk_put32(header+12,(uint32_t)count);
    fk_put32(header+16,FK_RANDOM_RECORD); memcpy(header+20,seed,32); memcpy(header+52,argv[3],40);
    fk_put32(header+124,fk_crc32(header,124));
    FILE *f=fopen(argv[1],"wb"); if(!f) { perror(argv[1]); return 4; }
    if(fwrite(header,1,sizeof header,f)!=sizeof header) { fclose(f); return 4; }
    for(unsigned i=0;i<count;i++) {
        unsigned char entropy[112],domain[40]={0};
        memcpy(domain,seed,32); fk_put32(domain+32,i); memcpy(domain+36,"RND1",4);
        shake128(entropy,sizeof entropy,domain,sizeof domain);
        memset(record,0,192);
        memcpy(record,entropy+16,32); memcpy(record+32,entropy,16); memcpy(record+80,entropy+48,16);
        memcpy(record+96+32,entropy+64,48);
        if(reference(record,record+96,record+FK_RANDOM_KG,record+FK_RANDOM_ENC)) {
            fprintf(stderr,"RANDOM_REFERENCE_FAIL case=%u\n",i); fclose(f); return 5;
        }
        fk_put32(record+FK_RANDOM_DATA,fk_crc32(record,FK_RANDOM_DATA));
        if(fwrite(record,1,sizeof record,f)!=sizeof record) { fclose(f); return 4; }
        if((i+1)%100==0) printf("GOLDEN_PROGRESS cases=%u/%lu\n",i+1,count);
    }
    if(fclose(f)) return 4;
    printf("RANDOM_GOLDEN_PASS cases=%lu operations=%lu seed=%.*s ref=%s\n",count,count*3,32,seed,argv[3]);
    return 0;
}

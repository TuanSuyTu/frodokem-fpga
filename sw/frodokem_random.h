#ifndef FRODOKEM_RANDOM_H
#define FRODOKEM_RANDOM_H
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
/* Explicit byte format; never serialize a host C struct. */
enum { FK_RANDOM_HEADER=128, FK_RANDOM_DATA=29848,
       FK_RANDOM_RECORD=29852, FK_RANDOM_KG=192, FK_RANDOM_ENC=20080 };
static inline uint32_t fk_get32(const unsigned char *p) {
    return (uint32_t)p[0] | (uint32_t)p[1]<<8 | (uint32_t)p[2]<<16 | (uint32_t)p[3]<<24;
}
static inline void fk_put32(unsigned char *p,uint32_t v) {
    for(unsigned n=0;n<4;n++) p[n]=(unsigned char)(v>>(8*n));
}
static inline uint32_t fk_crc32(const unsigned char *p,size_t n) {
    uint32_t c=UINT32_MAX;
    while(n--) {
        c^=*p++;
        for(unsigned b=0;b<8;b++) c=(c>>1)^(UINT32_C(0xedb88320)&(0u-(c&1)));
    }
    return ~c;
}
/* Validate the entire file before mapping hardware. CRC detects accidental
 * corruption, not malicious replacement; SOURCE_SHA256 provides provenance. */
static inline int fk_random_load(FILE *f,unsigned char **data,uint32_t *count,
                                 unsigned char header[FK_RANDOM_HEADER]) {
    *data=NULL; *count=0;
    if(fread(header,1,FK_RANDOM_HEADER,f)!=FK_RANDOM_HEADER ||
       memcmp(header,"FRD640R1",8) || fk_get32(header+8)!=1 ||
       fk_get32(header+16)!=FK_RANDOM_RECORD ||
       fk_get32(header+124)!=fk_crc32(header,124)) return -1;
    uint32_t n=fk_get32(header+12);
    if(n<1 || n>1000) return -1;
    for(unsigned i=52;i<92;i++)
        if(!((header[i]>='0'&&header[i]<='9')||(header[i]>='a'&&header[i]<='f'))) return -1;
    for(unsigned i=92;i<124;i++) if(header[i]) return -1;
    size_t bytes=(size_t)n*FK_RANDOM_RECORD;
    unsigned char *p=malloc(bytes);
    if(!p) return -1;
    if(fread(p,1,bytes,f)!=bytes || fgetc(f)!=EOF || ferror(f)) { free(p); return -1; }
    for(uint32_t i=0;i<n;i++) {
        const unsigned char *r=p+(size_t)i*FK_RANDOM_RECORD;
        if(fk_get32(r+FK_RANDOM_DATA)!=fk_crc32(r,FK_RANDOM_DATA)) { free(p); return -1; }
        for(unsigned j=48;j<80;j++) if(r[j]) { free(p); return -1; }
        for(unsigned j=96;j<128;j++) if(r[j]) { free(p); return -1; }
        for(unsigned j=176;j<192;j++) if(r[j]) { free(p); return -1; }
    }
    *data=p; *count=n; return 0;
}
/* Pack subsequent operations from byte-exact, verified FPGA results. */
static inline void fk_random_enc_input(unsigned char *input,const unsigned char *kg) {
    memcpy(input,kg+10256,9616);
}
static inline void fk_random_dec_input(unsigned char *input,const unsigned char *kg,
                                      const unsigned char *enc) {
    memcpy(input,kg+16,10240); memcpy(input+10240,enc,9752);
    memcpy(input+19992,kg+19872,16); memcpy(input+20008,kg+10272,9600);
    memcpy(input+29608,kg+10256,16); memcpy(input+29624,kg,16);
}
#endif

#define _POSIX_C_SOURCE 200809L
#include "FPGA_Driver.h"
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <time.h>
#include <unistd.h>

static int text_file(const char *path, char *buf, size_t size) {
    FILE *f=fopen(path,"r");
    if(!f) return -1;
    int ok=fgets(buf,(int)size,f)!=NULL;
    fclose(f);
    if(!ok) return -1;
    buf[strcspn(buf,"\r\n")]=0;
    return 0;
}
int fpga_probe(void) {
    DIR *dir=opendir("/sys/class/uio");
    struct dirent *ent;
    char path[512],name[256],addr[256],size[256];
    if(!dir) { perror("/sys/class/uio"); return -1; }
    while((ent=readdir(dir))) {
        if(strncmp(ent->d_name,"uio",3)) continue;
        snprintf(path,sizeof path,"/sys/class/uio/%s/name",ent->d_name);
        if(text_file(path,name,sizeof name)) continue;
        snprintf(path,sizeof path,"/sys/class/uio/%s/maps/map0/addr",ent->d_name);
        if(text_file(path,addr,sizeof addr)) continue;
        snprintf(path,sizeof path,"/sys/class/uio/%s/maps/map0/size",ent->d_name);
        if(text_file(path,size,sizeof size)) continue;
        printf("%s name=%s addr=%s size=%s\n",ent->d_name,name,addr,size);
    }
    closedir(dir);
    puts("PROBE_ONLY: no MMIO or DMA performed. DDR reservation/cache policy needs board-owner confirmation.");
    return 0;
}
static int map_uio(struct fk_mapping *m,const char *name,uint64_t base) {
    DIR *dir=opendir("/sys/class/uio");
    struct dirent *ent;
    char path[512],buf[256],device[256]={0};
    if(!dir) return -1;
    while((ent=readdir(dir))) {
        if(strncmp(ent->d_name,"uio",3)) continue;
        snprintf(path,sizeof path,"/sys/class/uio/%s/name",ent->d_name);
        int match=0;
        if(name) match=!text_file(path,buf,sizeof buf) && !strcmp(buf,name);
        else {
            unsigned long long addr;
            snprintf(path,sizeof path,"/sys/class/uio/%s/maps/map0/addr",ent->d_name);
            match=!text_file(path,buf,sizeof buf) && sscanf(buf,"%llx",&addr)==1 && addr==base;
        }
        if(match) {
            if(device[0]) { closedir(dir); errno=EEXIST; return -1; }
            snprintf(device,sizeof device,"%s",ent->d_name);
        }
    }
    closedir(dir);
    if(!device[0]) { errno=ENOENT; return -1; }
    const char *fields[]={"addr","size","offset"};
    unsigned long long values[3];
    for(int i=0;i<3;i++) {
        snprintf(path,sizeof path,"/sys/class/uio/%s/maps/map0/%s",device,fields[i]);
        if(text_file(path,buf,sizeof buf) || sscanf(buf,"%llx",&values[i])!=1) return -1;
    }
    /* Reject offset mappings rather than silently misaligning MMIO/DDR. */
    if(values[2] || !values[1] || values[1]>SIZE_MAX) { errno=EINVAL; return -1; }
    snprintf(path,sizeof path,"/dev/%s",device);
    int fd=open(path,O_RDWR|O_SYNC);
    if(fd<0) return -1;
    m->ptr=mmap(NULL,(size_t)values[1],PROT_READ|PROT_WRITE,MAP_SHARED,fd,0);
    close(fd);
    if(m->ptr==MAP_FAILED) { m->ptr=NULL; return -1; }
    m->phys=values[0]; m->size=(size_t)values[1];
    return 0;
}
void fpga_close(struct fk_linux *c) {
    struct fk_mapping *maps[]={&c->regs,&c->dma,&c->ddr};
    for(int i=0;i<3;i++) {
        if(maps[i]->ptr) munmap(maps[i]->ptr,maps[i]->size);
        memset(maps[i],0,sizeof *maps[i]);
    }
}
int fpga_open(struct fk_linux *c,const char *regs,const char *dma,const char *ddr,int safe) {
    if(!c || !ddr || !safe) { errno=EINVAL; return -1; }
    memset(c,0,sizeof *c);
    if(map_uio(&c->regs,regs,0xa0000000) || map_uio(&c->dma,dma,0xa0010000) || map_uio(&c->ddr,ddr,0)) goto fail;
    if(c->regs.phys!=0xa0000000 || c->dma.phys!=0xa0010000 ||
       c->regs.size<64 || c->dma.size<0x5c || c->ddr.size<65536 || (c->ddr.phys&7) ||
       c->ddr.phys>UINT64_MAX-c->ddr.size) {
        errno=EINVAL; goto fail;
    }
    /* A mistaken DDR UIO name must never turn buffer writes into MMIO writes. */
    if((c->ddr.phys<0xa0010000 && c->ddr.phys+c->ddr.size>0xa0000000) ||
       (c->ddr.phys<0xa0020000 && c->ddr.phys+c->ddr.size>0xa0010000)) {
        errno=EINVAL; goto fail;
    }
    return 0;
fail:
    { int err=errno; fpga_close(c); errno=err; return -1; }
}
static uint32_t rd_map(struct fk_mapping *m,unsigned off) {
    uint32_t v=*(volatile uint32_t*)((unsigned char*)m->ptr+off);
    __sync_synchronize(); return v;
}
static void wr_map(struct fk_mapping *m,unsigned off,uint32_t v) {
    __sync_synchronize(); *(volatile uint32_t*)((unsigned char*)m->ptr+off)=v;
    __sync_synchronize();
}
static uint32_t read32(void *p,unsigned off) { return rd_map(&((struct fk_linux*)p)->regs,off); }
static void write32(void *p,unsigned off,uint32_t v) { wr_map(&((struct fk_linux*)p)->regs,off,v); }
static int dma_busy(void *p,enum fk_dma_direction dir) {
    struct fk_linux *c=p;
    unsigned base=dir==FK_TX?0:0x30;
    uint32_t s=rd_map(&c->dma,base+4);
    if(s&0x778) return -1; /* Reject SG mode and DMA error flags. */
    if(c->pending[dir]) {
        if(s&1) return -1; /* Unexpected halt after submitting a transfer. */
        if((s&0x1002)==0x1002) { c->pending[dir]=0; return 0; }
        return 1;
    }
    return !(s&3); /* Initially Halted or Idle is available, not an active job. */
}
static int dma_submit(void *p,enum fk_dma_direction dir,void *buffer,size_t bytes) {
    struct fk_linux *c=p;
    uintptr_t at=(uintptr_t)buffer,begin=(uintptr_t)c->ddr.ptr;
    if(at<begin || at-begin>c->ddr.size || !bytes || bytes>65535 ||
       bytes>c->ddr.size-(at-begin) || (at&7)) return -1;
    unsigned base=dir==FK_TX?0:0x30;
    uint32_t status=rd_map(&c->dma,base+4);
    if(c->pending[dir] || status&0x778 || (!(status&1) && !(status&2))) return -1;
    uint64_t addr=c->ddr.phys+(at-begin);
    wr_map(&c->dma,base+4,0x7000);
    wr_map(&c->dma,base,1); /* Simple-mode AXI DMA run, polling without IRQ. */
    /* PG021: wait until Halted deasserts before programming a transfer. */
    struct timespec begin_time,now,pause={0,100000};
    clock_gettime(CLOCK_MONOTONIC,&begin_time);
    while(rd_map(&c->dma,base+4)&1) {
        clock_gettime(CLOCK_MONOTONIC,&now);
        int64_t ns=(int64_t)(now.tv_sec-begin_time.tv_sec)*1000000000+now.tv_nsec-begin_time.tv_nsec;
        if(ns>=100000000) return -1;
        nanosleep(&pause,NULL);
    }
    wr_map(&c->dma,base+0x18,(uint32_t)addr);
    wr_map(&c->dma,base+0x1c,(uint32_t)(addr>>32));
    c->pending[dir]=1;
    wr_map(&c->dma,base+0x28,(uint32_t)bytes); /* Length starts transfer. */
    return 0;
}
static void barrier(void *p,void *b,size_t n) {
    (void)p; (void)b; (void)n; __sync_synchronize();
    /* No cache maintenance is needed ONLY under fpga_open's verified contract.
     * A CPU fence does NOT flush a cached DDR buffer. */
}
static uint64_t time_us(void *p) {
    struct timespec t; (void)p;
    clock_gettime(CLOCK_MONOTONIC,&t);
    return (uint64_t)t.tv_sec*1000000+(uint64_t)t.tv_nsec/1000;
}
void fpga_bind(struct fk_io *io,struct fk_linux *c) {
    *io=(struct fk_io){c,read32,write32,dma_submit,dma_busy,barrier,barrier,time_us};
}

/* World.xs - XS module of the IP::World module
   this module maps from IP addresses to country codes, 
   using the free WorldIP database (wipmania.com) */
   
#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
}
#endif

#if U32SIZE != 4
#error IP::World can only be run on a system in which the U32 type is 4 bytes long
#endif

typedef unsigned char uc;

typedef struct {
    char *addr;
    UV   entries;
    PerlIO *IN;
    U32  mode;
} wip_self;

MODULE = IP::World       PACKAGE = IP::World

PROTOTYPES: DISABLE

SV * 
allocNew(filepath, fileLen, mode=0)
    const char *filepath
    STRLEN fileLen
    int mode
    PREINIT:
        wip_self self;
        UV readLen;
        PerlIO *IN;
        U16 *ccs;
    CODE:
        /* XS part of IP::World->new
            allocate a block of memory and fill it from the ipworld.dat file */
        IN = PerlIO_open(filepath, "r");
        if (!IN) croak("Can't open %s: %s", filepath, strerror(errno));
        self.mode = mode;
#ifdef MMAPOK
#include <sys/mman.h>
        if (mode == 1) {
            /* experimental feature: use mmap rather than read */
            int fd = PerlIO_fileno(IN);
            self.addr = (char *)mmap(0, fileLen, PROT_READ, MAP_SHARED, fd, 0);
            if (self.addr == MAP_FAILED) croak ("mmap failed on %s\n", filepath);
        } else 
#endif
        if (!mode) {
            /* malloc a block of size fileLen */
            Newx(self.addr, fileLen, char);
            if (!self.addr) croak ("memory allocation for %s failed", filepath);
            /* read the data from the .dat file into the new block */
            readLen = PerlIO_read(IN, self.addr, fileLen);
            if (readLen < 0) croak("read from %s failed: %s", filepath, strerror(errno));
            if (readLen != fileLen) 
                croak("should have read %d bytes from %s, actually read %d", 
                      fileLen, filepath, readLen);
        }
        /* all is well */
        if (mode < 2) PerlIO_close(IN);
        else self.IN = IN;
        
        /* for each entry there is a 4 byte address plus a 4/3 byte compressed country code */
        self.entries = fileLen*3 >> 4;
        
        /* warn("%s length %d -> %d entries", filepath, fileLen, self.entries); */
        RETVAL = newSVpv((const char *)(&self), sizeof(wip_self));   
    OUTPUT:
        RETVAL

SV*
getcc(self_ref, ip_sv)
    SV* self_ref
    SV* ip_sv
    PREINIT:
        SV* self_deref;		
        char* s;
        STRLEN len;
        wip_self self;
        I32 flgs;
        struct in_addr netip;
        U32 ip;
        register U32 *ips;
        register UV i, bottom = 0, top;
        U32 word;
        char c[] = "**", *ret = c;
    CODE:
        /* $new_obj->getcc is just in XS/C
           check that self_ref is defined ref; dref it; check len; copy to self */
        len = 0;
        if (sv_isobject(self_ref)) {
            self_deref = SvRV(self_ref);
            if (SvPOK(self_deref)) s = SvPV(self_deref, len);
        }
        if (len != sizeof(wip_self))
            croak("automatic 'self' operand to getcc is not of correct type"); 
        memcpy (&self, s, sizeof(wip_self));
        /* the ip_sv argument can be of 3 types (if error return '**') */
        if (!SvOK(ip_sv)) goto set_retval;
        flgs = SvFLAGS(ip_sv);
        if (!(flgs & (SVp_POK|SVf_NOK|SVp_NOK|SVf_IOK|SVp_IOK))) goto set_retval;
        s = SvPV(ip_sv, len);
        /* if the the ip operand is a dotted string, convert it to network-order U32 
           else if the operand does't look like a network-order U32, lose */
        if (inet_pton(AF_INET, s, (void *)&netip) > 0) s = (char *)&netip; 
        else if (len != 4) goto set_retval;
        /* if necessary, convert network order (big-endian) to native endianism */
        ip = ((uc)s[0] << 24) + ((uc)s[1] << 16) + ((uc)s[2] << 8) + (uc)s[3];
        /* binary-search the IP table */
        ips = (U32 *)self.addr;
        top = self.entries;
        while (bottom < top-1) {
            /* compare ip to the table entry halfway between top and bottom */
            i = (bottom + top) >> 1;
            if (self.mode < 2 ? ip < ips[i]
                              : PerlIO_seek(self.IN, i<<2, 0) == 0
                             && PerlIO_read(self.IN, &word, 4) == 4
                             && ip < word) {
                /* warn("ip=%10u <  table[top=%6u]=%10u", ip, i, ips[i]); */
                top = i;
            } else {
                bottom = i;
                /* warn("ip=%10u >= table[bot=%6u]=%10u", ip, i, ips[i]); */
        }   }
        /* warn("final index is %d, top=%d, %d entries", bottom, top, self.entries); */
        /* the table of country codes (3 per word) follows the table of IPs
           move the corresponding entry to ret */
        if (self.mode < 2) word = *(ips + self.entries + bottom/3);
        else {
            PerlIO_seek(self.IN, (self.entries + bottom/3)<<2, 0);
            PerlIO_read(self.IN, &word, 4);
        }
        switch (bottom % 3) {
          case 0:  word >>= 20; break;
          case 1:  word = word>>10 & 0x3FF; break;
          default: word &= 0x3FF;
        }
        if (word == 26*26) strcpy(c, "??");
        else {
          c[0] = (word / 26) + 'A';
          c[1] = (word % 26) + 'A';
        }
        set_retval:
        RETVAL = newSVpv(ret, 2);
    OUTPUT:
        RETVAL

void
DESTROY(self_ref)
    SV* self_ref
    PREINIT:
        SV *self_deref;		
        char *s;
        STRLEN len;
        wip_self self;
    CODE:
        /* DESTROY gives back allocated memory
           check that self_ref is defined ref; dref it; check len; copy to self */
        len = 0;
        if (sv_isobject(self_ref)) {
            self_deref = SvRV(self_ref);
            if (SvPOK(self_deref)) 
                s = SvPV(self_deref, len);
        }
        if (len != sizeof(wip_self))
            croak("automatic 'self' operand to DESTROY is not of correct type"); 
        memcpy (&self, s, sizeof(wip_self));
#ifdef MMAPOK
        if (self.mode == 1) munmap((caddr_t)self.addr, (size_t)(self.entries*6));
        else 
#endif
        if (!self.mode) Safefree(self.addr);
        else PerlIO_close(self.IN);

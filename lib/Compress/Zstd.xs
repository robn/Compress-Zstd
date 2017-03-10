#ifdef __cplusplus
extern "C" {
#endif
#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#ifdef __cplusplus
}
#endif

#define NEED_newCONSTSUB
#include "ppport.h"
#include "zstd.h"

struct Compressor {
    ZSTD_CCtx* cctx;
    ZSTD_CDict* dict;
};

struct Decompressor {
    ZSTD_DCtx* dctx;
    ZSTD_DDict* dict;
};

typedef struct Compressor   *Compress__Zstd__Compressor;
typedef struct Decompressor *Compress__Zstd__Decompressor;

MODULE = Compress::Zstd PACKAGE = Compress::Zstd

BOOT:
{
    HV* stash = gv_stashpv("Compress::Zstd", 1);
    newCONSTSUB(stash, "ZSTD_VERSION_NUMBER", newSViv(ZSTD_VERSION_NUMBER));
    newCONSTSUB(stash, "ZSTD_VERSION_STRING", newSVpvs(ZSTD_VERSION_STRING));
    newCONSTSUB(stash, "ZSTD_MAX_CLEVEL", newSViv(ZSTD_maxCLevel()));
}

PROTOTYPES: DISABLE

void
compress(source, level = 1)
    SV* source;
    int level;
PREINIT:
    const char* src;
    STRLEN src_len;
    SV* dest;
    char* dst;
    size_t bound, ret;
PPCODE:
    if (SvROK(source)) {
        source = SvRV(source);
    }
    if (!SvOK(source)) {
        XSRETURN_UNDEF;
    }
    src = SvPVbyte(source, src_len);
    bound = ZSTD_compressBound(src_len);
    dest = sv_2mortal(newSV(bound + 1));
    dst = SvPVX(dest);
    ret = ZSTD_compress(dst, bound + 1, src, src_len, level);
    if (ZSTD_isError(ret)) {
        XSRETURN_UNDEF;
    }
    dst[ret] = '\0';
    SvCUR_set(dest, ret);
    SvPOK_on(dest);
    EXTEND(SP, 1);
    PUSHs(dest);

void
decompress(source)
    SV* source;
ALIAS:
    uncompress = 1
PREINIT:
    const char* src;
    STRLEN src_len;
    unsigned long long dest_len;
    SV* dest;
    char* dst;
    size_t ret;
PPCODE:
    if (SvROK(source)) {
        source = SvRV(source);
    }
    if (!SvOK(source)) {
        XSRETURN_UNDEF;
    }
    src = SvPVbyte(source, src_len);
    dest_len = ZSTD_getDecompressedSize(src, src_len);
    if (dest_len == ULLONG_MAX) {
        XSRETURN_UNDEF;
    }
    dest = sv_2mortal(newSV(dest_len + 1));
    dst = SvPVX(dest);
    ret = ZSTD_decompress(dst, dest_len + 1, src, src_len);
    if (ZSTD_isError(ret)) {
        XSRETURN_UNDEF;
    }
    dst[ret] = '\0';
    SvCUR_set(dest, ret);
    SvPOK_on(dest);
    EXTEND(SP, 1);
    PUSHs(dest);


MODULE = Compress::Zstd PACKAGE = Compress::Zstd::Compressor

Compress::Zstd::Compressor
new(SV* class)
CODE:
    PERL_UNUSED_VAR(class);
    Newxz(RETVAL, 1, struct Compressor);
    RETVAL->cctx = ZSTD_createCCtx();
OUTPUT:
    RETVAL

void
DESTROY(Compress::Zstd::Compressor self)
CODE:
    if (self->dict)
        ZSTD_freeCDict(self->dict);
    ZSTD_freeCCtx(self->cctx);

void
set_dictionary(Compress::Zstd::Compressor self, SV* dictionary, int level = 1)
PREINIT:
    const char* dict;
    STRLEN dict_len;
CODE:
    if (SvROK(dictionary)) {
        dictionary = SvRV(dictionary);
    }
    if (!SvOK(dictionary)) {
        XSRETURN_UNDEF;
    }
    dict = SvPVbyte(dictionary, dict_len);
    self->dict = ZSTD_createCDict(dict, dict_len, level);

SV*
compress(Compress::Zstd::Compressor self, SV* source, int level = 1)
PREINIT:
    const char* src;
    STRLEN src_len;
    SV* dest;
    char* dst;
    size_t bound, ret;
CODE:
    if (SvROK(source)) {
        source = SvRV(source);
    }
    if (!SvOK(source)) {
        XSRETURN_UNDEF;
    }
    src = SvPVbyte(source, src_len);
    bound = ZSTD_compressBound(src_len);
    dest = newSV(bound + 1);
    dst = SvPVX(dest);
    if (self->dict) {
        ret = ZSTD_compress_usingCDict(self->cctx, dst, bound + 1, src, src_len, self->dict);
    }
    else {
        ret = ZSTD_compressCCtx(self->cctx, dst, bound + 1, src, src_len, level);
    }
    if (ZSTD_isError(ret)) {
        croak("compress: %s", ZSTD_getErrorName(ret));
    }
    dst[ret] = '\0';
    SvCUR_set(dest, ret);
    SvPOK_on(dest);
    RETVAL = dest;
OUTPUT:
    RETVAL


MODULE = Compress::Zstd PACKAGE = Compress::Zstd::Decompressor

Compress::Zstd::Decompressor
new(SV* class)
CODE:
    PERL_UNUSED_VAR(class);
    Newxz(RETVAL, 1, struct Decompressor);
    RETVAL->dctx = ZSTD_createDCtx();
OUTPUT:
    RETVAL

void
DESTROY(Compress::Zstd::Decompressor self)
CODE:
    if (self->dict)
        ZSTD_freeDDict(self->dict);
    ZSTD_freeDCtx(self->dctx);

void
set_dictionary(Compress::Zstd::Decompressor self, SV* dictionary)
PREINIT:
    const char* dict;
    STRLEN dict_len;
CODE:
    if (SvROK(dictionary)) {
        dictionary = SvRV(dictionary);
    }
    if (!SvOK(dictionary)) {
        XSRETURN_UNDEF;
    }
    dict = SvPVbyte(dictionary, dict_len);
    self->dict = ZSTD_createDDict(dict, dict_len);

SV*
decompress(Compress::Zstd::Decompressor self, SV* source)
PREINIT:
    const char* src;
    STRLEN src_len;
    unsigned long long dest_len;
    SV* dest;
    char* dst;
    size_t ret;
CODE:
    if (SvROK(source)) {
        source = SvRV(source);
    }
    if (!SvOK(source)) {
        XSRETURN_UNDEF;
    }
    src = SvPVbyte(source, src_len);
    dest_len = ZSTD_getDecompressedSize(src, src_len);
    if (dest_len == ULLONG_MAX) {
        XSRETURN_UNDEF;
    }
    dest = newSV(dest_len + 1);
    dst = SvPVX(dest);
    if (self->dict) {
        ret = ZSTD_decompress_usingDDict(self->dctx, dst, dest_len + 1, src, src_len, self->dict);
    }
    else {
        ret = ZSTD_decompressDCtx(self->dctx, dst, dest_len + 1, src, src_len);
    }
    if (ZSTD_isError(ret)) {
        croak("decompress: %s", ZSTD_getErrorName(ret));
    }
    dst[ret] = '\0';
    SvCUR_set(dest, ret);
    SvPOK_on(dest);
    RETVAL = dest;
OUTPUT:
    RETVAL

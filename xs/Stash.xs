/*=====================================================================
*
* Template::Stash::XS (Stash.xs)
*
* DESCRIPTION
*   This is a stripped down version of the Template Toolkit XS stash
*   for testing a bug on 64 bit Perl when using TT with DateTime objects.
#   http://rt.cpan.org/Public/Bug/Display.html?id=48020
*
* AUTHORS
*   Andy Wardley   <abw@cpan.org>
*
*=====================================================================*/

#ifdef __cplusplus
extern "C" {
#endif

#define PERL_NO_GET_CONTEXT
#include "EXTERN.h"
#include "perl.h"
#define NEED_sv_2pv_flags
#define NEED_newRV_noinc
#include "ppport.h"
#include "XSUB.h"

#ifdef __cplusplus
}
#endif

#define debug(...) fprintf(stderr, __VA_ARGS__)
#define TT_STASH_PKG    "Template::Stash::XS"
#define TT_LVALUE_FLAG  1
#define TT_DEBUG_FLAG   2
#define TT_DEFAULT_FLAG 4

typedef enum tt_ret { TT_RET_UNDEF, TT_RET_OK, TT_RET_CODEREF } TT_RET;

static TT_RET   tt_fetch_item(pTHX_ SV*, SV*, AV*, SV**);
static SV*      dotop(pTHX_ SV*, SV*, AV*, int);
static SV*      call_coderef(pTHX_ SV*, AV*);


/* The get() method calls dotop().  Usually this does some complicated
 * stuff, but we've stripped it back to a simple call to tt_fetch_item()
 */ 

static SV *dotop(pTHX_ SV *root, SV *key_sv, AV *args, int flags) {
    dSP;
    STRLEN item_len;
    char *item = SvPV(key_sv, item_len);
    SV *result = &PL_sv_undef;
    I32 atroot;

    debug("- dotop(%s)\n", item);

    switch(tt_fetch_item(aTHX_ root, key_sv, args, &result)) {
        case TT_RET_OK:
            /* return immediately */
            debug("- TT_RET_OK\n");
            break;
                
        case TT_RET_CODEREF:
            /* fall through */
            debug("- TT_RET_CODEREF\n");
            break;
                
        default:
            croak("Skipping default case");
    }

    return result;
}



/* tt_fetch_item() would usually fetch items from hash or list references,
 * but we only need to worry about hash refs in order to demonstrate the bug.
 * We get an item from the Stash root and call call_coderef() if it's a code
 * reference.
 */

static TT_RET tt_fetch_item(pTHX_ SV *root, SV *key_sv, AV *args, SV **result) {
    STRLEN key_len;
    char *key = SvPV(key_sv, key_len);
    SV **value = NULL;

    debug("- fetch item: %s\n", key);

    /* negative key_len is used to indicate UTF8 string */
    if (SvUTF8(key_sv))
        key_len = -key_len;
    
    if (! (SvROK(root) && SvTYPE(SvRV(root)) == SVt_PVHV)) {
        croak("not a hash ref");
    }
    
    debug("- fetching hash item\n");
    value = hv_fetch((HV *) SvRV(root), key, key_len, FALSE);

    if (value) {
        debug("- got value, triggering any tied magic\n");

        /* trigger any tied magic to FETCH value */
        SvGETMAGIC(*value);
        
        /* call if a coderef */
        if (SvROK(*value) 
            && (SvTYPE(SvRV(*value)) == SVt_PVCV) 
            && !sv_isobject(*value)) {
            debug("- calling coderef\n");
            *result = call_coderef(aTHX_ *value, args);
            debug("- called coderef, returning result\n");
            return TT_RET_CODEREF;
            
        } 
        else if (SvOK(*value)) {
            *result = *value;
            return TT_RET_OK;
        }

    } 

    *result = &PL_sv_undef;
    return TT_RET_UNDEF;
}


/* call_coderef() handles a callback to a Perl code reference.
 */

static SV *call_coderef(pTHX_ SV *code, AV *args) {
    dSP;
    SV **svp;
    I32 count = (args && args != Nullav) ? av_len(args) : -1;
    I32 i;
    SV *retval = &PL_sv_undef;

    debug("- in call_coderef()\n");

    PUSHMARK(SP);

    debug("- about to push args\n");
    for (i = 0; i <= count; i++)
        if ((svp = av_fetch(args, i, FALSE)))
            XPUSHs(*svp);
    debug("- pushed args\n");

    PUTBACK;

    debug("- calling call_sv()\n");
    count = call_sv(code, G_ARRAY);
    debug("- called call_sv()\n");


    SPAGAIN;

    if (count)
        retval = POPs; 

    PUTBACK;

    return retval;
}


/*====================================================================
 * XS SECTION                                                     
 *====================================================================*/

MODULE = Template::Stash::XS            PACKAGE = Template::Stash::XS

PROTOTYPES: DISABLED


#-----------------------------------------------------------------------
# get(SV *root, SV *ident, SV *args)
#-----------------------------------------------------------------------

SV *
get(root, ident, ...)
    SV *root
    SV *ident
    CODE:
    AV *args = NULL;
    int flags = 0;
    int n;
    STRLEN len;
    char *str;

    /* assume ident is a scalar so we call dotop() just once */
    RETVAL = dotop(aTHX_ root, ident, args, flags);

    if (!SvOK(RETVAL)) {
        croak("get() got no RETVAL");
    }
    else {
        RETVAL = SvREFCNT_inc(RETVAL);
    }

    OUTPUT:
    RETVAL



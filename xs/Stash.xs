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
static SV*      fold_results(pTHX_ I32);
static AV*      mk_mortal_av(pTHX_ SV*, AV*, SV*);

#define THROW_SIZE 64
static char throw_fmt[] = "Can't locate object method \"%s\" via package \"%s\"";


/*------------------------------------------------------------------------
 * tt_fetch_item(pTHX_ SV *root, SV *key_sv, AV *args, SV **result)
 *
 * Retrieves an item from the given hash or array ref.  If item is found
 * and a coderef then the coderef will be called and passed args.  Returns
 * TT_RET_CODEREF or TT_RET_OK and sets result.  If not found, returns 
 * TT_RET_UNDEF and result is undefined.
 *------------------------------------------------------------------------*/

static TT_RET tt_fetch_item(pTHX_ SV *root, SV *key_sv, AV *args, SV **result) {
    STRLEN key_len;
    char *key = SvPV(key_sv, key_len);
    SV **value = NULL;

    debug("fetch item: %s\n", key);

    /* negative key_len is used to indicate UTF8 string */
    if (SvUTF8(key_sv))
        key_len = -key_len;
    
    if (! (SvROK(root) && SvTYPE(SvRV(root)) == SVt_PVHV)) {
        debug("not a hash ref");
        return TT_RET_UNDEF;
    }
    
    debug("fetching hash item\n");
    value = hv_fetch((HV *) SvRV(root), key, key_len, FALSE);

    if (value) {
        debug("got value, triggering any tied magic\n");

        /* trigger any tied magic to FETCH value */
        SvGETMAGIC(*value);
        
        /* call if a coderef */
        if (SvROK(*value) 
            && (SvTYPE(SvRV(*value)) == SVt_PVCV) 
            && !sv_isobject(*value)) {
            debug("calling coderef\n");
            *result = call_coderef(aTHX_ *value, args);
            debug("called coderef, returning result\n");
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



/*------------------------------------------------------------------------
 * dotop(pTHX_ SV *root, SV *key_sv, AV *args, int flags)
 *
 * Resolves dot operations of the form root.key, where 'root' is a
 * reference to the root item, 'key_sv' is an SV containing the
 * operation key (e.g. hash key, list index, first, last, each, etc),
 * 'args' is a list of additional arguments and 'TT_LVALUE_FLAG' is a 
 * flag to indicate if, for certain operations (e.g. hash key), the item
 * should be created if it doesn't exist.  Also, 'TT_DEBUG_FLAG' is the 
 * debug flag.
 *------------------------------------------------------------------------*/

static SV *dotop(pTHX_ SV *root, SV *key_sv, AV *args, int flags) {
    dSP;
    STRLEN item_len;
    char *item = SvPV(key_sv, item_len);
    SV *result = &PL_sv_undef;
    I32 atroot;

    debug("dotop(%s)\n", item);

    switch(tt_fetch_item(aTHX_ root, key_sv, args, &result)) {
        case TT_RET_OK:
            /* return immediately */
            debug("TT_RET_OK\n");
            break;
                
        case TT_RET_CODEREF:
            /* fall through */
            debug("TT_RET_CODEREF\n");
            break;
                
        default:
            croak("Skipping default case");
    }

    return result;
}



/* pushes any arguments in 'args' onto the stack then calls the code ref
 * in 'code'.  Calls fold_results() to return a listref or die.
 */
static SV *call_coderef(pTHX_ SV *code, AV *args) {
    dSP;
    SV **svp;
    I32 count = (args && args != Nullav) ? av_len(args) : -1;
    I32 i;
    SV *retval;

    debug("in call_coderef()\n");

    PUSHMARK(SP);

    debug("about to push args\n");

// HMMM - this code appears to be failing on my Macbook where the 
// original bug *doesn't* manifest itself....  that suggests I've either
// chopped out something I shouldn't have, or we're closer to the bug...

//    for (i = 0; i <= count; i++)
//        if ((svp = av_fetch(args, i, FALSE))) 
//            XPUSHs(*svp);

    debug("pushed args\n");

    PUTBACK;

    debug("calling call_sv()\n");

    count = call_sv(code, G_ARRAY);

    SPAGAIN;

    debug("called call_sv()\n");
    
    return fold_results(aTHX_ count);
}


/* pops 'count' items off the stack, folding them into a list reference
 * if count > 1, or returning the sole item if count == 1.  
 * Returns undef if count == 0. 
 * Dies if first value of list is undef
 */
static SV* fold_results(pTHX_ I32 count) {
    dSP;
    SV *retval = &PL_sv_undef;

    debug("folding results\n");
    
    if (count > 1) {
        /* convert multiple return items into a list reference */
        AV *av = newAV();
        SV *last_sv = &PL_sv_undef;
        SV *sv = &PL_sv_undef;
        I32 i;

        av_extend(av, count - 1);
        for(i = 1; i <= count; i++) {
            last_sv = sv;
            sv = POPs; 
            if (SvOK(sv) && !av_store(av, count - i, SvREFCNT_inc(sv))) 
                SvREFCNT_dec(sv);
        }
        PUTBACK;
        
        retval = sv_2mortal((SV *) newRV_noinc((SV *) av));
    } 
    else { 
        if (count)
            retval = POPs; 
        PUTBACK;
    }

    debug("fold_results() returning\n");

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
    AV *args;
    int flags = 0;
    int n;
    STRLEN len;
    char *str;

    /* otherwise ident is a scalar so we call dotop() just once */
    RETVAL = dotop(aTHX_ root, ident, args, flags);

    if (!SvOK(RETVAL)) {
        croak("get() got no RETVAL");
    }
    else {
        RETVAL = SvREFCNT_inc(RETVAL);
    }

    OUTPUT:
    RETVAL



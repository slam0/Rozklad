#include "rz_import.h"

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ------------------------------------------------------------------ */
/* Mały, ostrożny parser JSON (drzewo zapamiętuje tylko pozycje w tekście) */
/* ------------------------------------------------------------------ */

enum { J_NULL, J_BOOL, J_NUM, J_STR, J_ARR, J_OBJ };

typedef struct {
    unsigned char t;
    unsigned char isint;
    int first, next, count;
    size_t s, e;          /* surowy tekst [s, e) */
    long long iv;
} jn;

typedef struct {
    const char *src;
    size_t len;
    jn *n;
    int cnt, cap;
    const char *msg;
} jdoc;

#define J_MAX_DEPTH 24

static int jnew(jdoc *d, int t, size_t s)
{
    if (d->cnt == d->cap) {
        int ncap = d->cap ? d->cap * 2 : 256;
        jn *nn = (jn *)realloc(d->n, (size_t)ncap * sizeof(jn));
        if (!nn) { d->msg = "brak pamięci"; return -1; }
        d->n = nn;
        d->cap = ncap;
    }
    jn *x = &d->n[d->cnt];
    memset(x, 0, sizeof *x);
    x->t = (unsigned char)t;
    x->first = x->next = -1;
    x->s = s;
    return d->cnt++;
}

static void jskip(const jdoc *d, size_t *p)
{
    while (*p < d->len) {
        char c = d->src[*p];
        if (c == ' ' || c == '\t' || c == '\n' || c == '\r') (*p)++;
        else break;
    }
}

static int jvalue(jdoc *d, size_t *p, int depth);

static int jstring(jdoc *d, size_t *p)
{
    size_t i = *p + 1;
    int id = jnew(d, J_STR, *p);
    if (id < 0) return -1;
    while (i < d->len) {
        unsigned char c = (unsigned char)d->src[i];
        if (c == '"') {
            d->n[id].e = i + 1;
            *p = i + 1;
            return id;
        }
        if (c < 0x20 || c >= 0x80) { d->msg = "niedozwolony znak w tekście"; return -1; }
        if (c == '\\') {
            char q;
            if (i + 1 >= d->len) break;
            q = d->src[i + 1];
            if (q == 'u') {
                int k;
                if (i + 5 >= d->len) break;
                for (k = 2; k < 6; k++) {
                    char h = d->src[i + (size_t)k];
                    if (!((h >= '0' && h <= '9') || (h >= 'a' && h <= 'f') || (h >= 'A' && h <= 'F'))) {
                        d->msg = "zły zapis \\u"; return -1;
                    }
                }
                i += 6;
                continue;
            }
            if (!strchr("\"\\/bfnrt", q) || q == 0) { d->msg = "zły znak po \\"; return -1; }
            i += 2;
            continue;
        }
        i++;
    }
    d->msg = "niedokończony tekst";
    return -1;
}

static int jnumber(jdoc *d, size_t *p)
{
    size_t i = *p;
    int id = jnew(d, J_NUM, i), digits = 0, isint = 1, neg = 0;
    long long v = 0;
    if (id < 0) return -1;
    if (i < d->len && d->src[i] == '-') { neg = 1; i++; }
    while (i < d->len && d->src[i] >= '0' && d->src[i] <= '9') {
        if (digits < 15) v = v * 10 + (d->src[i] - '0'); else isint = 0;
        digits++; i++;
    }
    if (!digits) { d->msg = "zła liczba"; return -1; }
    if (i < d->len && d->src[i] == '.') {
        size_t f = ++i;
        isint = 0;
        while (i < d->len && d->src[i] >= '0' && d->src[i] <= '9') i++;
        if (i == f) { d->msg = "zła liczba"; return -1; }
    }
    if (i < d->len && (d->src[i] == 'e' || d->src[i] == 'E')) {
        size_t f;
        isint = 0;
        i++;
        if (i < d->len && (d->src[i] == '+' || d->src[i] == '-')) i++;
        f = i;
        while (i < d->len && d->src[i] >= '0' && d->src[i] <= '9') i++;
        if (i == f) { d->msg = "zła liczba"; return -1; }
    }
    d->n[id].isint = (unsigned char)isint;
    d->n[id].iv = neg ? -v : v;
    d->n[id].e = i;
    *p = i;
    return id;
}

static int jcontainer(jdoc *d, size_t *p, int depth, int isobj)
{
    char close = isobj ? '}' : ']';
    int id, last = -1;
    if (depth >= J_MAX_DEPTH) { d->msg = "zbyt głęboki JSON"; return -1; }
    id = jnew(d, isobj ? J_OBJ : J_ARR, *p);
    if (id < 0) return -1;
    (*p)++;
    jskip(d, p);
    if (*p < d->len && d->src[*p] == close) {
        (*p)++;
        d->n[id].e = *p;
        return id;
    }
    for (;;) {
        int kids = isobj ? 2 : 1, k;
        for (k = 0; k < kids; k++) {
            int c;
            jskip(d, p);
            if (*p >= d->len) { d->msg = "niedokończony JSON"; return -1; }
            if (isobj && k == 0) {
                if (d->src[*p] != '"') { d->msg = "oczekiwano nazwy pola"; return -1; }
                c = jstring(d, p);
            } else {
                c = jvalue(d, p, depth + 1);
            }
            if (c < 0) return -1;
            if (last < 0) d->n[id].first = c; else d->n[last].next = c;
            last = c;
            d->n[id].count++;
            if (isobj && k == 0) {
                jskip(d, p);
                if (*p >= d->len || d->src[*p] != ':') { d->msg = "oczekiwano :"; return -1; }
                (*p)++;
            }
        }
        jskip(d, p);
        if (*p >= d->len) { d->msg = "niedokończony JSON"; return -1; }
        if (d->src[*p] == ',') { (*p)++; continue; }
        if (d->src[*p] == close) { (*p)++; d->n[id].e = *p; return id; }
        d->msg = "oczekiwano , lub koniec";
        return -1;
    }
}

static int jvalue(jdoc *d, size_t *p, int depth)
{
    char c;
    jskip(d, p);
    if (*p >= d->len) { d->msg = "niedokończony JSON"; return -1; }
    c = d->src[*p];
    if (c == '{') return jcontainer(d, p, depth, 1);
    if (c == '[') return jcontainer(d, p, depth, 0);
    if (c == '"') return jstring(d, p);
    if (c == '-' || (c >= '0' && c <= '9')) return jnumber(d, p);
    if (d->len - *p >= 4 && !strncmp(d->src + *p, "true", 4)) {
        int id = jnew(d, J_BOOL, *p); if (id < 0) return -1; *p += 4; d->n[id].e = *p; return id;
    }
    if (d->len - *p >= 5 && !strncmp(d->src + *p, "false", 5)) {
        int id = jnew(d, J_BOOL, *p); if (id < 0) return -1; *p += 5; d->n[id].e = *p; return id;
    }
    if (d->len - *p >= 4 && !strncmp(d->src + *p, "null", 4)) {
        int id = jnew(d, J_NULL, *p); if (id < 0) return -1; *p += 4; d->n[id].e = *p; return id;
    }
    d->msg = "nieznana wartość";
    return -1;
}

/* Zwraca numer korzenia lub -1. Korzeń ma zawsze numer 0. */
static int jparse(jdoc *d, const char *src, size_t len)
{
    size_t p = 0;
    int root;
    memset(d, 0, sizeof *d);
    d->src = src;
    d->len = len;
    root = jvalue(d, &p, 0);
    if (root < 0) return -1;
    jskip(d, &p);
    if (p != len) { d->msg = "dodatkowe znaki na końcu"; return -1; }
    return root;
}

static void jfree(jdoc *d)
{
    free(d->n);
    d->n = NULL;
}

static int jget(const jdoc *d, int obj, const char *key)
{
    int c;
    size_t klen = strlen(key);
    if (obj < 0 || d->n[obj].t != J_OBJ) return -1;
    c = d->n[obj].first;
    while (c >= 0) {
        const jn *k = &d->n[c];
        int v = k->next;
        if (v < 0) break;
        if (k->e - k->s == klen + 2 && !memcmp(d->src + k->s + 1, key, klen)) return v;
        c = d->n[v].next;
    }
    return -1;
}

static int jis(const jdoc *d, int id, int t)
{
    return id >= 0 && d->n[id].t == t;
}

static int jint(const jdoc *d, int id, long long lo, long long hi)
{
    return jis(d, id, J_NUM) && d->n[id].isint && d->n[id].iv >= lo && d->n[id].iv <= hi;
}

static int kind_bit(char c)
{
    switch (c) {
        case 'b': return 1;
        case 't': return 2;
        case 'p': return 4;
        case 'm': return 8;
    }
    return 0;
}

/* ------------------------------------------------------------------ */
/* Bufor wyjściowy                                                     */
/* ------------------------------------------------------------------ */

typedef struct { char *p; size_t len, cap; int bad; } buf;

static void bput(buf *b, const char *s, size_t n)
{
    if (b->bad) return;
    if (b->len + n + 1 > b->cap) {
        size_t nc = b->cap ? b->cap : 4096;
        char *np;
        while (nc < b->len + n + 1) nc *= 2;
        np = (char *)realloc(b->p, nc);
        if (!np) { b->bad = 1; return; }
        b->p = np;
        b->cap = nc;
    }
    memcpy(b->p + b->len, s, n);
    b->len += n;
    b->p[b->len] = 0;
}

static void bstr(buf *b, const char *s) { bput(b, s, strlen(s)); }

static void bint(buf *b, long long v)
{
    char t[32];
    int n = snprintf(t, sizeof t, "%lld", v);
    bput(b, t, (size_t)n);
}

/* ------------------------------------------------------------------ */
/* Składanie rozklad.json                                              */
/* ------------------------------------------------------------------ */

struct rz_asm {
    char *svctext;           /* kopia svc.json */
    jdoc svc;
    int svcarr;              /* numer węzła tablicy "svc" */
    int *svcnode;            /* numery węzłów kalendarzy */
    int nsvc;
    int *remap;              /* numer w svc.json -> numer w wyniku, albo -1 */
    int *used;               /* kolejność użytych kalendarzy */
    int nused;
    buf stops;
    int nstops;
};

static void seterr(char *err, size_t size, const char *fmt, const char *a)
{
    if (err && size) snprintf(err, size, fmt, a ? a : "");
}

static int check_str_array(const jdoc *d, int id)
{
    int c;
    if (!jis(d, id, J_ARR)) return 0;
    for (c = d->n[id].first; c >= 0; c = d->n[c].next) if (!jis(d, c, J_STR)) return 0;
    return 1;
}

rz_asm *rz_asm_new(const char *svc, size_t len, char *err, size_t errsize)
{
    rz_asm *a;
    int root, arr, c, i, dd;
    if (!svc || len == 0 || len > RZ_IMPORT_MAX_SVC_BYTES) {
        seterr(err, errsize, "Plik z kalendarzami ma złą wielkość.", NULL);
        return NULL;
    }
    a = (rz_asm *)calloc(1, sizeof *a);
    if (!a) { seterr(err, errsize, "Brak pamięci.", NULL); return NULL; }
    a->svctext = (char *)malloc(len + 1);
    if (!a->svctext) { seterr(err, errsize, "Brak pamięci.", NULL); free(a); return NULL; }
    memcpy(a->svctext, svc, len);
    a->svctext[len] = 0;
    root = jparse(&a->svc, a->svctext, len);
    if (root != 0 || !jis(&a->svc, 0, J_OBJ)) {
        seterr(err, errsize, "Plik z kalendarzami jest uszkodzony (%s).", a->svc.msg ? a->svc.msg : "zły format");
        rz_asm_free(a);
        return NULL;
    }
    arr = jget(&a->svc, 0, "svc");
    if (!jis(&a->svc, arr, J_ARR) || !jis(&a->svc, jget(&a->svc, 0, "gen"), J_STR)
        || !jis(&a->svc, jget(&a->svc, 0, "end"), J_STR)) {
        seterr(err, errsize, "Plik z kalendarzami ma zły format.", NULL);
        rz_asm_free(a);
        return NULL;
    }
    a->svcarr = arr;
    a->nsvc = a->svc.n[arr].count;
    if (a->nsvc > 65535) { seterr(err, errsize, "Za dużo kalendarzy.", NULL); rz_asm_free(a); return NULL; }
    a->svcnode = (int *)malloc(sizeof(int) * (size_t)(a->nsvc ? a->nsvc : 1));
    a->remap = (int *)malloc(sizeof(int) * (size_t)(a->nsvc ? a->nsvc : 1));
    a->used = (int *)malloc(sizeof(int) * (size_t)(a->nsvc ? a->nsvc : 1));
    if (!a->svcnode || !a->remap || !a->used) { seterr(err, errsize, "Brak pamięci.", NULL); rz_asm_free(a); return NULL; }
    i = 0;
    for (c = a->svc.n[arr].first; c >= 0; c = a->svc.n[c].next, i++) {
        int dn = jget(&a->svc, c, "d");
        a->svcnode[i] = c;
        a->remap[i] = -1;
        if (!jis(&a->svc, c, J_OBJ) || !jis(&a->svc, dn, J_ARR) || a->svc.n[dn].count != 7
            || !jis(&a->svc, jget(&a->svc, c, "s"), J_STR) || !jis(&a->svc, jget(&a->svc, c, "e"), J_STR)
            || !check_str_array(&a->svc, jget(&a->svc, c, "a")) || !check_str_array(&a->svc, jget(&a->svc, c, "r"))) {
            seterr(err, errsize, "Kalendarz %s ma zły format.", "w pliku");
            rz_asm_free(a);
            return NULL;
        }
        for (dd = a->svc.n[dn].first; dd >= 0; dd = a->svc.n[dd].next)
            if (!jint(&a->svc, dd, 0, 1)) {
                seterr(err, errsize, "Kalendarz ma złe dni tygodnia.", NULL);
                rz_asm_free(a);
                return NULL;
            }
    }
    return a;
}

typedef struct { int minute; int grp; } dep_t;

static int dep_cmp(const void *x, const void *y)
{
    const dep_t *a = (const dep_t *)x, *b = (const dep_t *)y;
    if (a->minute != b->minute) return a->minute < b->minute ? -1 : 1;
    return a->grp < b->grp ? -1 : a->grp > b->grp;
}

int rz_asm_add(rz_asm *a, const char *pole, size_t len, unsigned mask, char *err, size_t errsize)
{
    jdoc d;
    int root, n, c, g, gr, total = 0, ngr = 0, rc = 0;
    int *grline = NULL, *grhead = NULL, *grsv = NULL, *grmins = NULL;
    char *grkind = NULL;
    dep_t *deps = NULL;
    size_t nd = 0, i;
    long long m;

    if (!a || !pole || len == 0 || len > RZ_IMPORT_MAX_POLE_BYTES) {
        seterr(err, errsize, "Plik słupka ma złą wielkość.", NULL);
        return 1;
    }
    root = jparse(&d, pole, len);
    if (root != 0 || !jis(&d, 0, J_OBJ)) {
        seterr(err, errsize, "Plik słupka jest uszkodzony (%s).", d.msg ? d.msg : "zły format");
        jfree(&d);
        return 1;
    }
    n = jget(&d, 0, "n");
    c = jget(&d, 0, "c");
    g = jget(&d, 0, "g");
    if (!jis(&d, n, J_STR) || !jis(&d, c, J_STR) || !jis(&d, g, J_ARR)) {
        seterr(err, errsize, "Plik słupka ma zły format.", NULL);
        jfree(&d);
        return 1;
    }
    ngr = d.n[g].count;
    grline = (int *)malloc(sizeof(int) * (size_t)(ngr ? ngr : 1));
    grhead = (int *)malloc(sizeof(int) * (size_t)(ngr ? ngr : 1));
    grsv = (int *)malloc(sizeof(int) * (size_t)(ngr ? ngr : 1));
    grmins = (int *)malloc(sizeof(int) * (size_t)(ngr ? ngr : 1));
    grkind = (char *)malloc((size_t)(ngr ? ngr : 1));
    if (!grline || !grhead || !grsv || !grmins || !grkind) {
        seterr(err, errsize, "Brak pamięci.", NULL);
        rc = 1;
        goto done;
    }
    ngr = 0;
    for (gr = d.n[g].first; gr >= 0; gr = d.n[gr].next) {
        int e[5], k, x;
        if (!jis(&d, gr, J_ARR) || d.n[gr].count != 5) { rc = 2; goto done; }
        e[0] = d.n[gr].first;
        for (k = 1; k < 5; k++) e[k] = d.n[e[k - 1]].next;
        if (!jis(&d, e[0], J_STR) || !jis(&d, e[1], J_STR) || !jint(&d, e[2], 0, 65534)
            || !jis(&d, e[3], J_STR) || d.n[e[3]].e - d.n[e[3]].s != 3
            || !kind_bit(d.src[d.n[e[3]].s + 1]) || !jis(&d, e[4], J_ARR)) { rc = 2; goto done; }
        for (x = d.n[e[4]].first; x >= 0; x = d.n[x].next)
            if (!jint(&d, x, 0, 20000)) { rc = 2; goto done; }
        if (!(mask & (unsigned)kind_bit(d.src[d.n[e[3]].s + 1]))) continue;
        if (d.n[e[2]].iv >= a->nsvc) { rc = 3; goto done; }
        grline[ngr] = e[0];
        grhead[ngr] = e[1];
        grsv[ngr] = (int)d.n[e[2]].iv;
        grmins[ngr] = e[4];
        grkind[ngr] = d.src[d.n[e[3]].s + 1];
        total += d.n[e[4]].count;
        ngr++;
    }
    if (total == 0) goto done;     /* nic z tych rodzajów - słupek pominięty */

    deps = (dep_t *)malloc(sizeof(dep_t) * (size_t)total);
    if (!deps) { seterr(err, errsize, "Brak pamięci.", NULL); rc = 1; goto done; }
    for (g = 0; g < ngr; g++) {
        int x;
        for (x = d.n[grmins[g]].first; x >= 0; x = d.n[x].next) {
            deps[nd].minute = (int)d.n[x].iv;
            deps[nd].grp = g;
            nd++;
        }
    }
    qsort(deps, nd, sizeof(dep_t), dep_cmp);

    /* kalendarze użyte po raz pierwszy dostają kolejne numery */
    for (g = 0; g < ngr; g++) {
        if (a->remap[grsv[g]] < 0) {
            a->remap[grsv[g]] = a->nused;
            a->used[a->nused++] = grsv[g];
        }
    }

    if (a->nstops) bstr(&a->stops, ",");
    bstr(&a->stops, "{\"n\":");
    bput(&a->stops, d.src + d.n[n].s, d.n[n].e - d.n[n].s);
    bstr(&a->stops, ",\"c\":");
    bput(&a->stops, d.src + d.n[c].s, d.n[c].e - d.n[c].s);
    bstr(&a->stops, ",\"d\":[");
    for (i = 0; i < nd; i++) {
        int gi = deps[i].grp;
        char kk[4];
        if (i) bstr(&a->stops, ",");
        bstr(&a->stops, "[");
        bput(&a->stops, d.src + d.n[grline[gi]].s, d.n[grline[gi]].e - d.n[grline[gi]].s);
        bstr(&a->stops, ",");
        bput(&a->stops, d.src + d.n[grhead[gi]].s, d.n[grhead[gi]].e - d.n[grhead[gi]].s);
        bstr(&a->stops, ",");
        bint(&a->stops, a->remap[grsv[gi]]);
        bstr(&a->stops, ",");
        m = deps[i].minute;
        bint(&a->stops, m);
        kk[0] = ','; kk[1] = '"'; kk[2] = grkind[gi]; kk[3] = '"';
        bput(&a->stops, kk, 4);
        bstr(&a->stops, "]");
    }
    bstr(&a->stops, "]}");
    a->nstops++;
    if (a->stops.bad) { seterr(err, errsize, "Brak pamięci.", NULL); rc = 1; }

done:
    if (rc == 2) seterr(err, errsize, "Plik słupka ma zły format odjazdów.", NULL);
    if (rc == 3) seterr(err, errsize, "Plik słupka odwołuje się do nieistniejącego kalendarza.", NULL);
    free(grline); free(grhead); free(grsv); free(grmins); free(grkind); free(deps);
    jfree(&d);
    return rc ? 1 : 0;
}

int rz_asm_stops(const rz_asm *a)
{
    return a ? a->nstops : 0;
}

char *rz_asm_finish(rz_asm *a, size_t *outlen)
{
    buf o = {0};
    int gen = jget(&a->svc, 0, "gen"), end = jget(&a->svc, 0, "end"), i;
    bstr(&o, "{\"gen\":");
    bput(&o, a->svc.src + a->svc.n[gen].s, a->svc.n[gen].e - a->svc.n[gen].s);
    bstr(&o, ",\"end\":");
    bput(&o, a->svc.src + a->svc.n[end].s, a->svc.n[end].e - a->svc.n[end].s);
    bstr(&o, ",\"stops\":[");
    bput(&o, a->stops.p ? a->stops.p : "", a->stops.len);
    bstr(&o, "],\"svc\":[");
    for (i = 0; i < a->nused; i++) {
        const jn *s = &a->svc.n[a->svcnode[a->used[i]]];
        if (i) bstr(&o, ",");
        bput(&o, a->svc.src + s->s, s->e - s->s);
    }
    bstr(&o, "]}");
    if (o.bad) { free(o.p); return NULL; }
    if (outlen) *outlen = o.len;
    return o.p;
}

void rz_asm_free(rz_asm *a)
{
    if (!a) return;
    jfree(&a->svc);
    free(a->svctext);
    free(a->svcnode);
    free(a->remap);
    free(a->used);
    free(a->stops.p);
    free(a);
}

/* ------------------------------------------------------------------ */
/* Adres rozklad://import?...                                          */
/* ------------------------------------------------------------------ */

static int hexv(char c)
{
    if (c >= '0' && c <= '9') return c - '0';
    if (c >= 'a' && c <= 'f') return c - 'a' + 10;
    if (c >= 'A' && c <= 'F') return c - 'A' + 10;
    return -1;
}

/* odkodowuje %XX z [s, s+n) do out; 0 = ok */
static int pdecode(const char *s, size_t n, char *out, size_t size)
{
    size_t i, o = 0;
    for (i = 0; i < n; i++) {
        unsigned char c = (unsigned char)s[i];
        if (c == '%') {
            int h, l;
            if (i + 2 >= n) return 1;
            h = hexv(s[i + 1]);
            l = hexv(s[i + 2]);
            if (h < 0 || l < 0) return 1;
            c = (unsigned char)(h * 16 + l);
            i += 2;
        }
        if (c < 0x21 || c >= 0x7f) return 1;      /* adres musi być zwykłym ASCII */
        if (o + 1 >= size) return 1;
        out[o++] = (char)c;
    }
    out[o] = 0;
    return 0;
}

int rz_import_parse(const char *url, rz_import_req *r, char *err, size_t errsize)
{
    const char *q, *p;
    char base[512] = "";
    int have_u = 0, have_v = 0, have_p = 0;
    size_t bl;

    memset(r, 0, sizeof *r);
    if (!url || strncmp(url, "rozklad://import", 16) != 0 || (url[16] != '?' && url[16] != 0)) {
        seterr(err, errsize, "To nie jest adres z przycisku „Otwórz w aplikacji Rozkład”.", NULL);
        return 1;
    }
    q = url[16] == '?' ? url + 17 : url + 16;
    while (*q) {
        const char *amp = strchr(q, '&');
        size_t seg = amp ? (size_t)(amp - q) : strlen(q);
        const char *eq = memchr(q, '=', seg);
        if (eq && eq > q) {
            size_t kl = (size_t)(eq - q), vl = seg - kl - 1;
            const char *v = eq + 1;
            if (kl == 1 && q[0] == 'u') {
                if (pdecode(v, vl, base, sizeof base)) { seterr(err, errsize, "Zły adres strony w linku.", NULL); return 1; }
                have_u = 1;
            } else if (kl == 1 && q[0] == 'v') {
                size_t i;
                if (vl == 0 || vl >= sizeof r->version) { seterr(err, errsize, "Zła wersja danych w linku.", NULL); return 1; }
                for (i = 0; i < vl; i++) if (v[i] < '0' || v[i] > '9') { seterr(err, errsize, "Zła wersja danych w linku.", NULL); return 1; }
                memcpy(r->version, v, vl);
                r->version[vl] = 0;
                have_v = 1;
            } else if (kl == 1 && q[0] == 'p') {
                size_t i = 0;
                while (i < vl) {
                    long num = 0, mk = 0;
                    size_t st = i;
                    int dn = 0, dm = 0;
                    while (i < vl && v[i] >= '0' && v[i] <= '9' && dn < 7) { num = num * 10 + (v[i] - '0'); i++; dn++; }
                    if (!dn || i >= vl || v[i] != '.') { seterr(err, errsize, "Zła lista przystanków w linku.", NULL); return 1; }
                    i++;
                    while (i < vl && v[i] >= '0' && v[i] <= '9' && dm < 3) { mk = mk * 10 + (v[i] - '0'); i++; dm++; }
                    (void)st;
                    if (!dm || mk < 1 || mk > 15 || (i < vl && v[i] != ',')) { seterr(err, errsize, "Zła lista przystanków w linku.", NULL); return 1; }
                    if (r->count >= RZ_IMPORT_MAX_POLES) { seterr(err, errsize, "Za dużo przystanków w jednym linku.", NULL); return 1; }
                    r->num[r->count] = (int)num;
                    r->mask[r->count] = (unsigned char)mk;
                    r->count++;
                    if (i < vl) {        /* przecinek, po nim musi być jeszcze jeden element */
                        i++;
                        if (i >= vl) { seterr(err, errsize, "Zła lista przystanków w linku.", NULL); return 1; }
                    }
                }
                have_p = 1;
            }
        }
        q = amp ? amp + 1 : q + seg;
    }
    if (!have_u || !have_v || !have_p || r->count == 0) {
        seterr(err, errsize, "Link nie zawiera wszystkich danych. Wybierz przystanki na stronie jeszcze raz.", NULL);
        return 1;
    }
    if (strncmp(base, "https://", 8) != 0 && strncmp(base, "http://", 7) != 0) {
        seterr(err, errsize, "Adres strony musi zaczynać się od https:// lub http://.", NULL);
        return 1;
    }
    bl = strlen(base);
    if (base[bl - 1] != '/') {
        if (bl + 2 > sizeof base) { seterr(err, errsize, "Zbyt długi adres strony.", NULL); return 1; }
        base[bl++] = '/';
        base[bl] = 0;
    }
    if (strchr(base, '?') || strchr(base, '#') || strchr(base, '"') || strchr(base, '<')) {
        seterr(err, errsize, "Zły adres strony w linku.", NULL);
        return 1;
    }
    memcpy(r->base, base, bl + 1);
    p = base + (base[4] == 's' ? 8 : 7);
    {
        size_t hl = strcspn(p, "/");
        if (hl == 0 || hl >= sizeof r->host) { seterr(err, errsize, "Zły adres strony w linku.", NULL); return 1; }
        memcpy(r->host, p, hl);
        r->host[hl] = 0;
    }
    return 0;
}

int rz_import_file_url(const rz_import_req *r, int which, char *buf, size_t size)
{
    int n;
    if (which < -1 || which >= r->count) return 1;
    if (which < 0) n = snprintf(buf, size, "%sd/%s/svc.json", r->base, r->version);
    else n = snprintf(buf, size, "%sd/%s/s/%d.json", r->base, r->version, r->num[which]);
    return (n < 0 || (size_t)n >= size) ? 1 : 0;
}

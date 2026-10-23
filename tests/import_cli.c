/* Narzędzie testowe: import_cli <katalog_strony> <wersja> <p-lista> [maska_do_nadpisania]
   Składa rozklad.json z plików na dysku dokładnie tak, jak robi to aplikacja. */
#include "../rz_import.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static char *slurp(const char *path, size_t *n)
{
    FILE *f = fopen(path, "rb");
    char *b;
    long l;
    if (!f) return NULL;
    fseek(f, 0, SEEK_END); l = ftell(f); fseek(f, 0, SEEK_SET);
    b = (char *)malloc((size_t)l + 1);
    if (fread(b, 1, (size_t)l, f) != (size_t)l) { fclose(f); free(b); return NULL; }
    b[l] = 0; fclose(f); *n = (size_t)l;
    return b;
}

int main(int argc, char **argv)
{
    char url[4096], err[256] = "", path[1024], fu[1024];
    rz_import_req r;
    rz_asm *a;
    size_t n, i;
    char *svc, *json;
    if (argc < 4) return 2;
    snprintf(url, sizeof url, "rozklad://import?u=http%%3A%%2F%%2Fexample.org%%2Frozklad&v=%s&p=%s", argv[2], argv[3]);
    if (rz_import_parse(url, &r, err, sizeof err)) { fprintf(stderr, "parse: %s\n", err); return 3; }
    snprintf(path, sizeof path, "%s/d/%s/svc.json", argv[1], argv[2]);
    svc = slurp(path, &n);
    if (!svc) { fprintf(stderr, "brak svc\n"); return 4; }
    a = rz_asm_new(svc, n, err, sizeof err);
    free(svc);
    if (!a) { fprintf(stderr, "svc: %s\n", err); return 5; }
    for (i = 0; i < (size_t)r.count; i++) {
        char *p;
        rz_import_file_url(&r, (int)i, fu, sizeof fu);
        snprintf(path, sizeof path, "%s/d/%s/s/%d.json", argv[1], argv[2], r.num[i]);
        p = slurp(path, &n);
        if (!p) { fprintf(stderr, "brak %s\n", path); rz_asm_free(a); return 6; }
        if (rz_asm_add(a, p, n, r.mask[i], err, sizeof err)) { fprintf(stderr, "pole %d: %s\n", r.num[i], err); free(p); rz_asm_free(a); return 7; }
        free(p);
    }
    json = rz_asm_finish(a, &n);
    if (!json) { rz_asm_free(a); return 8; }
    fwrite(json, 1, n, stdout);
    free(json);
    rz_asm_free(a);
    return 0;
}

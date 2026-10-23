#include "../rz_import.h"
#include <assert.h>
#include <stdio.h>
#include <string.h>

static int bad(const char *url)
{
    rz_import_req r;
    char err[200];
    return rz_import_parse(url, &r, err, sizeof err) != 0 && err[0];
}

int main(void)
{
    rz_import_req r;
    char err[200] = "", u[600];

    assert(!rz_import_parse("rozklad://import?u=https%3A%2F%2Fuser.github.io%2Frozklad%2F&v=202610231820&p=12.1,13.3,400.15", &r, err, sizeof err));
    assert(!strcmp(r.base, "https://user.github.io/rozklad/"));
    assert(!strcmp(r.host, "user.github.io"));
    assert(!strcmp(r.version, "202610231820"));
    assert(r.count == 3 && r.num[0] == 12 && r.mask[0] == 1 && r.num[1] == 13 && r.mask[1] == 3 && r.num[2] == 400 && r.mask[2] == 15);
    assert(!rz_import_file_url(&r, -1, u, sizeof u) && !strcmp(u, "https://user.github.io/rozklad/d/202610231820/svc.json"));
    assert(!rz_import_file_url(&r, 2, u, sizeof u) && !strcmp(u, "https://user.github.io/rozklad/d/202610231820/s/400.json"));
    assert(rz_import_file_url(&r, 3, u, sizeof u));
    assert(rz_import_file_url(&r, -1, u, 10));

    /* kolejność parametrów dowolna, brak końcowego "/" dopisany, port w adresie */
    assert(!rz_import_parse("rozklad://import?p=1.8&v=7&u=http%3A%2F%2F192.168.0.5%3A8000%2Fx", &r, err, sizeof err));
    assert(!strcmp(r.base, "http://192.168.0.5:8000/x/") && !strcmp(r.host, "192.168.0.5:8000"));

    assert(bad("rozklad://other?u=a&v=1&p=1.1"));
    assert(bad("http://import?u=a&v=1&p=1.1"));
    assert(bad("rozklad://import"));
    assert(bad("rozklad://import?v=1&p=1.1"));                                                  /* brak u */
    assert(bad("rozklad://import?u=https%3A%2F%2Fa.pl%2F&p=1.1"));                              /* brak v */
    assert(bad("rozklad://import?u=https%3A%2F%2Fa.pl%2F&v=1"));                                /* brak p */
    assert(bad("rozklad://import?u=ftp%3A%2F%2Fa.pl%2F&v=1&p=1.1"));                            /* zły protokół */
    assert(bad("rozklad://import?u=file%3A%2F%2F%2Fetc%2F&v=1&p=1.1"));
    assert(bad("rozklad://import?u=https%3A%2F%2Fa.pl%2F&v=1a&p=1.1"));                         /* wersja nie z cyfr */
    assert(bad("rozklad://import?u=https%3A%2F%2Fa.pl%2F&v=&p=1.1"));
    assert(bad("rozklad://import?u=https%3A%2F%2Fa.pl%2F&v=1&p=1"));                            /* brak maski */
    assert(bad("rozklad://import?u=https%3A%2F%2Fa.pl%2F&v=1&p=1.0"));                          /* maska 0 */
    assert(bad("rozklad://import?u=https%3A%2F%2Fa.pl%2F&v=1&p=1.16"));                         /* maska 16 */
    assert(bad("rozklad://import?u=https%3A%2F%2Fa.pl%2F&v=1&p=1.1,,2.1"));
    assert(bad("rozklad://import?u=https%3A%2F%2Fa.pl%2F&v=1&p=1.1,"));
    assert(bad("rozklad://import?u=https%3A%2F%2Fa.pl%2F&v=1&p=12345678.1"));                   /* za długi numer */
    assert(bad("rozklad://import?u=https%3A%2F%2Fa.pl%2F%zz&v=1&p=1.1"));                       /* zły %XX */
    assert(bad("rozklad://import?u=https%3A%2F%2Fa.pl%2F%2&v=1&p=1.1"));                        /* ucięty %X */
    assert(bad("rozklad://import?u=https%3A%2F%2Fa.pl%2F%3Fx&v=1&p=1.1"));                     /* ? w adresie */
    assert(bad("rozklad://import?u=https%3A%2F%2F%2F&v=1&p=1.1"));                              /* pusty host */
    assert(bad("rozklad://import?u=https%3A%2F%2Fa.pl%2F%20x&v=1&p=1.1"));                      /* spacja */

    {   /* za dużo słupków */
        char big[6000];
        int i, n = 0;
        n += snprintf(big, sizeof big, "rozklad://import?u=https%%3A%%2F%%2Fa.pl%%2F&v=1&p=");
        for (i = 0; i <= RZ_IMPORT_MAX_POLES; i++) n += snprintf(big + n, sizeof big - (size_t)n, "%s%d.1", i ? "," : "", i);
        assert(bad(big));
        big[n - 6] = 0;               /* ucięcie ostatniego elementu (",400.1") -> 400 słupków jest jeszcze ok */
        assert(!rz_import_parse(big, &r, err, sizeof err) && r.count == RZ_IMPORT_MAX_POLES);
    }
    printf("import_test: OK\n");
    return 0;
}

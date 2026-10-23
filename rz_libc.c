/*
 * Zastępcze pliki SDK (.tbd), z których budujemy aplikację na GitHubie, nie wymieniają kilku
 * podstawowych funkcji C. Linker kończył wtedy pracę błędem "Undefined symbols: _memcpy, _memset…".
 * Dlatego te funkcje mamy tutaj własne. Każda ma optnone, żeby kompilator nie zamienił
 * pętli z powrotem na wywołanie memcpy/memset (to byłaby nieskończona rekurencja).
 */
#include <stddef.h>

#define RZ_PLAIN __attribute__((optnone, noinline))

RZ_PLAIN void *memcpy(void *dst, const void *src, size_t n)
{
    unsigned char *d = (unsigned char *)dst;
    const unsigned char *s = (const unsigned char *)src;
    while (n--) *d++ = *s++;
    return dst;
}

RZ_PLAIN void *memset(void *dst, int c, size_t n)
{
    unsigned char *d = (unsigned char *)dst;
    while (n--) *d++ = (unsigned char)c;
    return dst;
}

RZ_PLAIN int memcmp(const void *a, const void *b, size_t n)
{
    const unsigned char *x = (const unsigned char *)a;
    const unsigned char *y = (const unsigned char *)b;
    while (n--) {
        if (*x != *y) return (int)*x - (int)*y;
        x++;
        y++;
    }
    return 0;
}

RZ_PLAIN void *memchr(const void *s, int c, size_t n)
{
    const unsigned char *p = (const unsigned char *)s;
    while (n--) {
        if (*p == (unsigned char)c) return (void *)p;
        p++;
    }
    return NULL;
}

RZ_PLAIN char *strchr(const char *s, int c)
{
    for (;; s++) {
        if (*s == (char)c) return (char *)s;
        if (*s == 0) return NULL;
    }
}

RZ_PLAIN int strncmp(const char *a, const char *b, size_t n)
{
    while (n--) {
        unsigned char x = (unsigned char)*a++, y = (unsigned char)*b++;
        if (x != y) return (int)x - (int)y;
        if (x == 0) return 0;
    }
    return 0;
}

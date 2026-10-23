/*
 * rz_import - składanie rozklad.json z małych plików ze strony (GitHub Pages).
 * Czysty C (bez Foundation), żeby dało się to przetestować na komputerze.
 *
 * Adres z przycisku "Otwórz w aplikacji Rozkład":
 *   rozklad://import?u=<adres strony, zakodowany>&v=<wersja danych>&p=<słupek>.<maska>,<słupek>.<maska>,...
 */
#ifndef RZ_IMPORT_H
#define RZ_IMPORT_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

#define RZ_IMPORT_MAX_POLES 400
#define RZ_IMPORT_MAX_SVC_BYTES  (24u * 1024u * 1024u)
#define RZ_IMPORT_MAX_POLE_BYTES (6u * 1024u * 1024u)

typedef struct {
    char base[512];                 /* adres strony, zawsze z "/" na końcu */
    char host[128];                 /* sama nazwa serwera, do pokazania użytkownikowi */
    char version[24];               /* wersja danych, same cyfry */
    int  count;                     /* liczba słupków */
    int  num[RZ_IMPORT_MAX_POLES];  /* numer pliku słupka */
    unsigned char mask[RZ_IMPORT_MAX_POLES];  /* bity rodzajów: b=1 t=2 p=4 m=8 */
} rz_import_req;

/* Rozbiera cały adres (rozklad://import?...). Zwraca 0, gdy poprawny. */
int rz_import_parse(const char *url, rz_import_req *r, char *err, size_t errsize);

/* Adres pliku do pobrania: which = -1 -> svc.json, 0..count-1 -> plik słupka. */
int rz_import_file_url(const rz_import_req *r, int which, char *buf, size_t size);

typedef struct rz_asm rz_asm;

/* svc.json (kalendarze). NULL + komunikat przy błędzie. */
rz_asm *rz_asm_new(const char *svc, size_t len, char *err, size_t errsize);
/* Dodaje plik słupka z maską rodzajów; 0 = ok (także gdy słupek nie ma odjazdów tych rodzajów). */
int rz_asm_add(rz_asm *a, const char *pole, size_t len, unsigned mask, char *err, size_t errsize);
/* Ile słupków z odjazdami dodano. */
int rz_asm_stops(const rz_asm *a);
/* Gotowy rozklad.json (malloc, zwolnij free); NULL przy braku pamięci. */
char *rz_asm_finish(rz_asm *a, size_t *len);
void rz_asm_free(rz_asm *a);

#ifdef __cplusplus
}
#endif

#endif

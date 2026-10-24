/*
 * rz_core - czysta logika rozkładu (bez Foundation/UIKit), żeby dało się ją
 * przetestować na dowolnym komputerze.
 */
#ifndef RZ_CORE_H
#define RZ_CORE_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Jeden odjazd z przystanku. */
typedef struct {
    int32_t  minute;   /* minuty od północy dnia kursowania (może być > 1440, np. 25:10) */
    uint16_t svc;      /* numer kalendarza (RZService) */
    uint16_t line;     /* indeks w tabeli nazw linii */
    uint16_t head;     /* indeks w tabeli kierunków */
    uint8_t  kind;     /* 'b' autobus, 't' tramwaj, 'p' pociąg, 'm' metro */
} RZDep;

/* Kalendarz kursowania (z calendar.txt i calendar_dates.txt). */
typedef struct {
    int32_t  start, end;      /* yyyymmdd, 0 gdy nieznane */
    uint8_t  days[7];         /* poniedziałek..niedziela */
    int32_t *add;  int nadd;  /* dodatkowe dni kursowania */
    int32_t *rem;  int nrem;  /* dni, w których nie jeździ */
} RZService;

typedef struct {
    int32_t  time;   /* minuty od północy DZISIAJ */
    uint16_t line;
    uint16_t head;
} RZNext;

#define RZ_MAX_NEXT 32

/* weekday: 0 = poniedziałek ... 6 = niedziela */
int rz_service_runs(const RZService *s, int32_t ymd, int weekday);

/*
 * Znajduje najbliższe odjazdy rodzaju `kind`.
 * ymd[0..2] i weekday[0..2] opisują wczoraj, dziś i jutro.
 * now = minuty od północy dzisiaj, horizon = ile minut do przodu szukać.
 * Wynik posortowany rosnąco po czasie; zwraca liczbę wyników (<= limit).
 */
int rz_next(const RZDep *deps, size_t ndeps,
            const RZService *svcs, size_t nsvc,
            const int32_t ymd[3], const int weekday[3],
            int now, int horizon, uint8_t kind,
            RZNext *out, int limit);

/* Teksty po polsku (UTF-8). */
/* Język tekstów: 0 polski (domyślnie), 1 angielski, 2 rosyjski */
extern int rz_lang;
void rz_set_lang(int lang);

void rz_eta(int minutes, char *buf, size_t size);        /* "za 5 minut" */
void rz_clock(int time, char *buf, size_t size);         /* "10:44" */
void rz_duration(long seconds, char *buf, size_t size);  /* "20 dni 13 godz. 24 min" */

/* "20261231" -> 20261231; cokolwiek innego -> 0 */
int32_t rz_parse_date(const char *s);

#ifdef __cplusplus
}
#endif

#endif

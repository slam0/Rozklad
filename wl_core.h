/*
 * Waluty - logika w czystym C (bez libm i bez stdio), osobno, żeby dało się ją przetestować.
 *
 * Kurs w tabeli to zawsze "ile sztuk waluty dostajesz za 1 PLN" (per_pln).
 * Z NBP: per_pln = 1 / mid. Z ER-API: kurs podzielony przez kurs PLN (czyli niezależnie od waluty bazowej).
 * Przeliczanie: kwota * per_pln(do) / per_pln(z).
 */
#ifndef WL_CORE_H
#define WL_CORE_H

#ifdef __cplusplus
extern "C" {
#endif

/* 32-bitowa liczba całkowita jak 'long' na iPhonie (armv7); w testach można ją podmienić: -DWL_LONG=int */
#ifndef WL_LONG
#define WL_LONG long
#endif

#define WL_MAX_RATES 256

enum { WL_SRC_NONE = 0, WL_SRC_ERAPI = 1, WL_SRC_NBP = 2 };

typedef struct {
    char code[4];
    double per_pln;
} wl_rate;

typedef struct {
    int count;
    int source;          /* WL_SRC_* */
    WL_LONG fetched;        /* kiedy pobrano (unix), 0 = nieznane */
    WL_LONG updated;        /* na kiedy są kursy (unix), 0 = nieznane */
    char date[11];       /* "RRRR-MM-DD" albo pusty napis */
    wl_rate rates[WL_MAX_RATES];
} wl_table;

void wl_table_clear(wl_table *t);

/* Czytanie odpowiedzi serwerów. Zwracają liczbę walut albo -1, gdy odpowiedź jest błędna. */
int wl_parse_nbp(const char *json, wl_table *t);      /* api.nbp.pl/api/exchangerates/tables/A/?format=json */
int wl_parse_erapi(const char *json, wl_table *t);    /* open.er-api.com/v6/latest/PLN */

/* Zapis i odczyt z pliku tekstowego (pamięć podręczna). */
int wl_serialize(const wl_table *t, char *buf, int n);   /* długość tekstu albo -1 */
int wl_deserialize(const char *text, wl_table *t);       /* liczba walut albo -1 */

/* Kursy. */
const wl_rate *wl_find(const wl_table *t, const char *code);
int wl_convert(const wl_table *t, double amount, const char *from, const char *to, double *out);
int wl_has(const wl_table *t, const char *code);

/* Kwoty. */
int wl_parse_amount(const char *s, double *out);          /* 1 gdy poprawna; przecinek i kropka, spacje ignorowane */
int wl_format_number(double v, int min_dec, int max_dec, char dec_sep, char group_sep, char *buf, int n);
int wl_money_decimals(double v);                          /* ile miejsc po przecinku pokazać przy wyniku */
int wl_rate_decimals(double v);                           /* ...przy kursie */

/* Daty (UTC). */
WL_LONG wl_date_to_unix(const char *ymd);                    /* "2024-10-21" -> sekundy, -1 przy błędzie */
void wl_unix_to_date(WL_LONG t, char *out11);                /* sekundy -> "RRRR-MM-DD" */
WL_LONG wl_age_days(WL_LONG now, WL_LONG then);                    /* pełne dni; -1 gdy nieznane */

/* Odmiana: lang 0 polski, 1 angielski, 2 rosyjski. 0 = pojedyncza, 1 = "kilka", 2 = reszta. */
int wl_plural(int lang, WL_LONG n);

#ifdef __cplusplus
}
#endif
#endif

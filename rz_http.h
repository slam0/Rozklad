/*
 * rz_http - malutki serwer HTTP do odbierania pliku rozklad.json z komputera przez Wi-Fi.
 * Czysty C (gniazda POSIX), żeby dało się go przetestować na dowolnym komputerze.
 *
 *   GET  /        strona z formularzem do wysłania pliku
 *   POST /upload  treść żądania = plik rozklad.json
 */
#ifndef RZ_HTTP_H
#define RZ_HTTP_H

#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Wołane w wątku serwera, gdy przyjdzie plik. Zwraca 0 gdy wszystko w porządku,
   w przeciwnym razie wpisuje do err krótki komunikat po polsku. */
typedef int (*rz_http_upload_fn)(const char *body, size_t len, void *ctx, char *err, size_t errsize);

/* Uruchamia serwer na pierwszym wolnym porcie z zakresu [port, port+9].
   Zwraca użyty port albo -1. Wywołanie przy działającym serwerze zatrzymuje poprzedni. */
int rz_http_start(int port, rz_http_upload_fn fn, void *ctx);
void rz_http_stop(void);
int rz_http_running(void);

/* Adres IPv4 telefonu w sieci Wi-Fi (np. "192.168.0.12") albo "" gdy brak sieci. */
void rz_http_local_ip(char *buf, size_t size);

#ifdef __cplusplus
}
#endif

#endif

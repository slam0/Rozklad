#include "rz_http.h"
#include "rz_page.h"
#include "rz_core.h"

#include <arpa/inet.h>
#include <errno.h>
#include <ifaddrs.h>
#include <net/if.h>
#include <netinet/in.h>
#include <pthread.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/select.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <unistd.h>

#define RZ_MAX_HEADER 16384
#define RZ_MAX_BODY   (64u * 1024u * 1024u)   /* rozklad.json ma zwykle 0,1-5 MB */

static volatile int g_run = 0;
static int g_fd = -1;
static int g_port = 0;
static pthread_t g_thread;
static int g_thread_ok = 0;
static rz_http_upload_fn g_fn = NULL;
static void *g_ctx = NULL;

/* ---------- pomocnicze ---------- */

static int send_all(int fd, const char *p, size_t n)
{
    while (n) {
        ssize_t k = send(fd, p, n, 0);
        if (k < 0 && errno == EINTR) continue;
        if (k <= 0) return -1;
        p += k;
        n -= (size_t)k;
    }
    return 0;
}

static void respond(int fd, int code, const char *status, const char *ctype, const char *body)
{
    char head[600];
    size_t bl = body ? strlen(body) : 0;
    snprintf(head, sizeof head,
             "HTTP/1.1 %d %s\r\n"
             "Content-Type: %s\r\n"
             "Content-Length: %lu\r\n"
             "Access-Control-Allow-Origin: *\r\n"
             "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n"
             "Access-Control-Allow-Headers: Content-Type\r\n"
             "Cache-Control: no-store\r\n"
             "Connection: close\r\n\r\n",
             code, status, ctype, (unsigned long)bl);
    if (send_all(fd, head, strlen(head)) == 0 && bl) send_all(fd, body, bl);
}

static void text(int fd, int code, const char *status, const char *msg)
{
    respond(fd, code, status, "text/plain; charset=utf-8", msg);
}

/* wyszukiwanie bez rozróżniania wielkości liter (strcasestr nie jest wszędzie) */
static const char *find_ci(const char *h, const char *needle)
{
    size_t n = strlen(needle);
    for (; *h; h++) {
        size_t i = 0;
        while (i < n && h[i]) {
            char a = h[i], b = needle[i];
            if (a >= 'A' && a <= 'Z') a = (char)(a + 32);
            if (b >= 'A' && b <= 'Z') b = (char)(b + 32);
            if (a != b) break;
            i++;
        }
        if (i == n) return h;
    }
    return NULL;
}

/* tekst w języku aplikacji (0 pl, 1 en, 2 ru) */
static const char *L(const char *pl, const char *en, const char *ru)
{
    return rz_lang == 1 ? en : (rz_lang == 2 ? ru : pl);
}

/* ---------- obsługa jednego połączenia ---------- */

static void handle(int fd)
{
    struct timeval tv;
    tv.tv_sec = 10;
    tv.tv_usec = 0;
    setsockopt(fd, SOL_SOCKET, SO_RCVTIMEO, &tv, sizeof tv);
    setsockopt(fd, SOL_SOCKET, SO_SNDTIMEO, &tv, sizeof tv);
#ifdef SO_NOSIGPIPE
    int one = 1;
    setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &one, sizeof one);
#endif

    /* nagłówki */
    char *hdr = (char *)malloc(RZ_MAX_HEADER + 1);
    if (!hdr) return;
    size_t have = 0;
    char *end = NULL;
    while (!end) {
        if (have >= RZ_MAX_HEADER) { text(fd, 431, "Request Header Fields Too Large", L("Za długie nagłówki.", "Headers are too long.", "Слишком длинные заголовки.")); free(hdr); return; }
        ssize_t k = recv(fd, hdr + have, RZ_MAX_HEADER - have, 0);
        if (k < 0 && errno == EINTR) continue;
        if (k <= 0) { free(hdr); return; }
        have += (size_t)k;
        hdr[have] = 0;
        end = strstr(hdr, "\r\n\r\n");
    }
    size_t head_len = (size_t)(end - hdr) + 4;
    size_t extra = have - head_len;          /* początek treści, który już przyszedł */
    *end = 0;                                /* teraz hdr to same nagłówki */

    char method[16] = "", path[256] = "";
    if (sscanf(hdr, "%15s %255s", method, path) != 2) {
        text(fd, 400, "Bad Request", L("Niepoprawne żądanie.", "Invalid request.", "Некорректный запрос."));
        free(hdr);
        return;
    }

    if (strcmp(method, "OPTIONS") == 0) {
        respond(fd, 204, "No Content", "text/plain", "");
    } else if (strcmp(method, "GET") == 0 && (strcmp(path, "/") == 0 || strncmp(path, "/index", 6) == 0)) {
        respond(fd, 200, "OK", "text/html; charset=utf-8",
                rz_lang == 1 ? RZ_PAGE_EN : (rz_lang == 2 ? RZ_PAGE_RU : RZ_PAGE));
    } else if (strcmp(method, "POST") == 0 && strcmp(path, "/upload") == 0) {
        const char *cl = find_ci(hdr, "\ncontent-length:");
        unsigned long len = cl ? strtoul(cl + 16, NULL, 10) : 0;
        if (!cl || len == 0) {
            text(fd, 411, "Length Required", L("Brak pliku w żądaniu.", "No file in the request.", "В запросе нет файла."));
        } else if (len > RZ_MAX_BODY) {
            text(fd, 413, "Payload Too Large", L("Plik jest za duży.", "The file is too large.", "Файл слишком большой."));
        } else {
            char *body = (char *)malloc(len + 1);
            if (!body) {
                text(fd, 500, "Internal Server Error", L("Za mało pamięci w telefonie.", "Not enough memory on the phone.", "Не хватает памяти в телефоне."));
            } else {
                size_t got = extra < len ? extra : len;
                memcpy(body, hdr + head_len, got);
                int ok = 1;
                while (got < len) {
                    ssize_t k = recv(fd, body + got, len - got, 0);
                    if (k < 0 && errno == EINTR) continue;
                    if (k <= 0) { ok = 0; break; }
                    got += (size_t)k;
                }
                if (!ok) {
                    text(fd, 400, "Bad Request", L("Plik doszedł niekompletny. Spróbuj jeszcze raz.", "The file arrived incomplete. Try again.", "Файл пришёл не полностью. Попробуйте ещё раз."));
                } else {
                    body[len] = 0;
                    char err[200] = "";
                    int r = g_fn ? g_fn(body, len, g_ctx, err, sizeof err) : 1;
                    if (r == 0) text(fd, 200, "OK", L("Gotowe: telefon odebrał rozkład.", "Done: the phone received the timetable.", "Готово: телефон получил расписание."));
                    else text(fd, 400, "Bad Request", err[0] ? err : L("Telefon nie przyjął pliku.", "The phone did not accept the file.", "Телефон не принял файл."));
                }
                free(body);
            }
        }
    } else {
        text(fd, 404, "Not Found", "Nie ma takiej strony.");
    }
    free(hdr);
}

static void *server_loop(void *arg)
{
    (void)arg;
    while (g_run) {
        fd_set rs;
        struct timeval tv;
        FD_ZERO(&rs);
        FD_SET(g_fd, &rs);
        tv.tv_sec = 0;
        tv.tv_usec = 300000;
        int r = select(g_fd + 1, &rs, NULL, NULL, &tv);
        if (r <= 0) continue;
        int c = accept(g_fd, NULL, NULL);
        if (c < 0) continue;
        handle(c);
        close(c);
    }
    return NULL;
}

/* ---------- interfejs ---------- */

int rz_http_running(void)
{
    return g_run;
}

void rz_http_stop(void)
{
    if (!g_run && g_fd < 0) return;
    g_run = 0;
    if (g_thread_ok) {
        pthread_join(g_thread, NULL);
        g_thread_ok = 0;
    }
    if (g_fd >= 0) {
        close(g_fd);
        g_fd = -1;
    }
    g_port = 0;
}

int rz_http_start(int port, rz_http_upload_fn fn, void *ctx)
{
    rz_http_stop();
    signal(SIGPIPE, SIG_IGN);

    int fd = -1;
    int used = -1;
    for (int p = port; p < port + 10; p++) {
        fd = socket(AF_INET, SOCK_STREAM, 0);
        if (fd < 0) return -1;
        int yes = 1;
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof yes);
        struct sockaddr_in a;
        memset(&a, 0, sizeof a);
        a.sin_family = AF_INET;
        a.sin_addr.s_addr = htonl(INADDR_ANY);
        a.sin_port = htons((unsigned short)p);
        if (bind(fd, (struct sockaddr *)&a, sizeof a) == 0 && listen(fd, 4) == 0) {
            used = p;
            break;
        }
        close(fd);
        fd = -1;
    }
    if (used < 0) return -1;

    g_fd = fd;
    g_port = used;
    g_fn = fn;
    g_ctx = ctx;
    g_run = 1;
    if (pthread_create(&g_thread, NULL, server_loop, NULL) != 0) {
        g_run = 0;
        close(g_fd);
        g_fd = -1;
        g_port = 0;
        return -1;
    }
    g_thread_ok = 1;
    return used;
}

void rz_http_local_ip(char *buf, size_t size)
{
    struct ifaddrs *list = NULL, *it;
    char best[64] = "";
    if (size) buf[0] = 0;
    if (getifaddrs(&list) != 0) return;
    for (it = list; it; it = it->ifa_next) {
        if (!it->ifa_addr || it->ifa_addr->sa_family != AF_INET) continue;
        if (!(it->ifa_flags & IFF_UP) || (it->ifa_flags & IFF_LOOPBACK)) continue;
        char ip[64];
        inet_ntop(AF_INET, &((struct sockaddr_in *)it->ifa_addr)->sin_addr, ip, sizeof ip);
        if (strncmp(it->ifa_name, "en", 2) == 0 && best[0] == 0) {
            snprintf(best, sizeof best, "%s", ip);       /* Wi-Fi (en0) */
        } else if (best[0] == 0 && strncmp(ip, "169.254.", 8) != 0) {
            snprintf(best, sizeof best, "%s", ip);       /* cokolwiek innego z adresem */
        }
    }
    freeifaddrs(list);
    snprintf(buf, size, "%s", best);
}

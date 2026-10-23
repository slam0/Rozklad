/* Test serwera rz_http: klient na gniazdach wysyła różne żądania. */
#include "../rz_http.h"
#include <arpa/inet.h>
#include <assert.h>
#include <netinet/in.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <unistd.h>
#include <time.h>

static char *g_got = NULL;
static size_t g_got_len = 0;
static int g_mode = 0;   /* 0 = przyjmij, 1 = odrzuć */

static int on_upload(const char *body, size_t len, void *ctx, char *err, size_t es)
{
    (void)ctx;
    free(g_got);
    g_got = (char *)malloc(len + 1);
    memcpy(g_got, body, len);
    g_got[len] = 0;
    g_got_len = len;
    if (g_mode == 1) { snprintf(err, es, "To nie jest plik rozklad.json z generatora."); return 1; }
    return 0;
}

static int connect_to(int port)
{
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in a;
    memset(&a, 0, sizeof a);
    a.sin_family = AF_INET;
    a.sin_port = htons((unsigned short)port);
    inet_pton(AF_INET, "127.0.0.1", &a.sin_addr);
    assert(connect(fd, (struct sockaddr *)&a, sizeof a) == 0);
    return fd;
}

static void sendall(int fd, const char *p, size_t n)
{
    while (n) { ssize_t k = send(fd, p, n, 0); assert(k > 0); p += k; n -= (size_t)k; }
}

static char *readall(int fd)
{
    size_t cap = 1 << 16, n = 0;
    char *b = (char *)malloc(cap);
    for (;;) {
        if (n + 4096 > cap) { cap *= 2; b = (char *)realloc(b, cap); }
        ssize_t k = recv(fd, b + n, 4096, 0);
        if (k <= 0) break;
        n += (size_t)k;
    }
    b[n] = 0;
    return b;
}

/* wysyła całe żądanie jednym ciągiem; chunk>0 = kawałkami z przerwami */
static char *request(int port, const char *head, const char *body, size_t blen, size_t chunk)
{
    int fd = connect_to(port);
    sendall(fd, head, strlen(head));
    if (chunk) {
        struct timespec ts = {0, 20 * 1000 * 1000};
        for (size_t i = 0; i < blen; i += chunk) {
            sendall(fd, body + i, (blen - i < chunk) ? blen - i : chunk);
            nanosleep(&ts, NULL);
        }
    } else if (blen) {
        sendall(fd, body, blen);
    }
    char *r = readall(fd);
    close(fd);
    return r;
}

int main(void)
{
    int port = rz_http_start(18080, on_upload, NULL);
    assert(port >= 18080 && port < 18090);
    assert(rz_http_running());

    /* drugi serwer na zajętym porcie weźmie następny wolny */
    char *r;

    /* 1. strona startowa */
    r = request(port, "GET / HTTP/1.1\r\nHost: x\r\n\r\n", "", 0, 0);
    assert(strstr(r, "200 OK") && strstr(r, "<html") && strstr(r, "Access-Control-Allow-Origin: *"));
    free(r);

    /* 2. preflight CORS */
    r = request(port, "OPTIONS /upload HTTP/1.1\r\nHost: x\r\nOrigin: null\r\n\r\n", "", 0, 0);
    assert(strstr(r, " 204 ") && strstr(r, "Access-Control-Allow-Methods"));
    free(r);

    /* 3. mały plik, nagłówek i treść razem */
    const char *small = "{\"stops\":[],\"svc\":[]}";
    char head[256];
    snprintf(head, sizeof head, "POST /upload HTTP/1.1\r\nHost: x\r\nContent-Type: text/plain\r\ncontent-length: %lu\r\n\r\n", (unsigned long)strlen(small));
    r = request(port, head, small, strlen(small), 0);
    assert(strstr(r, "200 OK") && strstr(r, "telefon odebrał"));
    assert(g_got_len == strlen(small) && strcmp(g_got, small) == 0);
    free(r);

    /* 4. duży plik (3 MB) wysyłany kawałkami z przerwami */
    size_t big = 3u * 1024u * 1024u;
    char *data = (char *)malloc(big);
    for (size_t i = 0; i < big; i++) data[i] = (char)('a' + (i * 7 + i / 1000) % 26);
    snprintf(head, sizeof head, "POST /upload HTTP/1.1\r\nHost: x\r\nContent-Length: %lu\r\n\r\n", (unsigned long)big);
    r = request(port, head, data, big, 512 * 1024);
    assert(strstr(r, "200 OK"));
    assert(g_got_len == big && memcmp(g_got, data, big) == 0);
    free(r);

    /* 5. treść odrzucona przez aplikację -> 400 z komunikatem */
    g_mode = 1;
    snprintf(head, sizeof head, "POST /upload HTTP/1.1\r\nHost: x\r\nContent-Length: 5\r\n\r\n");
    r = request(port, head, "hello", 5, 0);
    assert(strstr(r, " 400 ") && strstr(r, "To nie jest plik rozklad.json"));
    free(r);
    g_mode = 0;

    /* 6. brak Content-Length */
    r = request(port, "POST /upload HTTP/1.1\r\nHost: x\r\n\r\n", "", 0, 0);
    assert(strstr(r, " 411 "));
    free(r);

    /* 7. niekompletna treść (klient zamyka połączenie wcześniej) */
    snprintf(head, sizeof head, "POST /upload HTTP/1.1\r\nHost: x\r\nContent-Length: 1000\r\n\r\n");
    r = request(port, head, "short", 5, 0);
    (void)r; free(r);   /* serwer nie może się zawiesić ani wywołać callbacku */

    /* 8. obcy adres */
    r = request(port, "GET /cokolwiek HTTP/1.1\r\nHost: x\r\n\r\n", "", 0, 0);
    assert(strstr(r, " 404 "));
    free(r);

    /* 9. śmieci zamiast żądania */
    r = request(port, "\x01\x02\x03 nonsens\r\n\r\n", "", 0, 0);
    assert(!strstr(r, " 200 "));   /* śmieci nie mogą dać sukcesu */
    free(r);

    /* 10. po tych wszystkich próbach serwer nadal działa */
    r = request(port, "GET / HTTP/1.1\r\nHost: x\r\n\r\n", "", 0, 0);
    assert(strstr(r, "200 OK"));
    free(r);

    /* 11. zatrzymanie i ponowne uruchomienie; zajęty port -> następny */
    rz_http_stop();
    assert(!rz_http_running());
    int srv = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in a;
    memset(&a, 0, sizeof a);
    a.sin_family = AF_INET; a.sin_addr.s_addr = htonl(INADDR_ANY); a.sin_port = htons(18080);
    int yes = 1; setsockopt(srv, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof yes);
    assert(bind(srv, (struct sockaddr *)&a, sizeof a) == 0 && listen(srv, 1) == 0);
    int p2 = rz_http_start(18080, on_upload, NULL);
    assert(p2 == 18081);
    rz_http_stop();
    close(srv);

    char ip[64];
    rz_http_local_ip(ip, sizeof ip);
    printf("adres lokalny: '%s'\n", ip);
    printf("OK: serwer Wi-Fi przeszedł wszystkie testy\n");
    free(data);
    free(g_got);
    return 0;
}

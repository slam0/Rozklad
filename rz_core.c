#include "rz_core.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static int rz_has(const int32_t *a, int n, int32_t v)
{
    int i;
    for (i = 0; i < n; i++) {
        if (a[i] == v) return 1;
    }
    return 0;
}

int rz_service_runs(const RZService *s, int32_t ymd, int weekday)
{
    if (rz_has(s->rem, s->nrem, ymd)) return 0;
    if (rz_has(s->add, s->nadd, ymd)) return 1;
    if (weekday < 0 || weekday > 6 || !s->days[weekday]) return 0;
    return s->start <= ymd && ymd <= s->end;
}

int rz_next(const RZDep *deps, size_t ndeps,
            const RZService *svcs, size_t nsvc,
            const int32_t ymd[3], const int weekday[3],
            int now, int horizon, uint8_t kind,
            RZNext *out, int limit)
{
    unsigned char *ok;
    int count = 0;
    int di;
    size_t k, i;

    if (limit > RZ_MAX_NEXT) limit = RZ_MAX_NEXT;
    if (limit <= 0 || ndeps == 0 || nsvc == 0) return 0;

    ok = (unsigned char *)calloc(3 * nsvc, 1);
    if (!ok) return 0;
    for (di = 0; di < 3; di++) {
        for (k = 0; k < nsvc; k++) {
            ok[di * nsvc + k] = (unsigned char)rz_service_runs(&svcs[k], ymd[di], weekday[di]);
        }
    }

    for (di = 0; di < 3; di++) {
        int off = (di - 1) * 1440;
        for (i = 0; i < ndeps; i++) {
            const RZDep *d = &deps[i];
            int t, j;
            if (d->kind != kind) continue;
            t = off + d->minute;
            if (t < now || t >= now + horizon) continue;
            if (d->svc >= nsvc || !ok[di * nsvc + d->svc]) continue;
            if (count == limit && t >= out[count - 1].time) continue;

            j = (count < limit) ? count : limit - 1;
            while (j > 0 && out[j - 1].time > t) {
                out[j] = out[j - 1];
                j--;
            }
            out[j].time = t;
            out[j].line = d->line;
            out[j].head = d->head;
            if (count < limit) count++;
        }
    }

    free(ok);
    return count;
}

int rz_lang = 0;

void rz_set_lang(int lang)
{
    rz_lang = (lang == 1 || lang == 2) ? lang : 0;
}

/* Rosyjska liczba mnoga: 0 = "1 минуту", 1 = "2 минуты", 2 = "5 минут" */
static int ru_form(int n)
{
    int a = n % 10, b = n % 100;
    if (a == 1 && b != 11) return 0;
    if (a >= 2 && a <= 4 && (b < 12 || b > 14)) return 1;
    return 2;
}

void rz_eta(int m, char *buf, size_t size)
{
    if (rz_lang == 1) {                      /* angielski */
        if (m <= 0) snprintf(buf, size, "departing now");
        else if (m == 1) snprintf(buf, size, "in 1 minute");
        else if (m < 60) snprintf(buf, size, "in %d minutes", m);
        else if (m % 60) snprintf(buf, size, "in %d h %d min", m / 60, m % 60);
        else snprintf(buf, size, "in %d h", m / 60);
        return;
    }
    if (rz_lang == 2) {                      /* rosyjski */
        static const char *const mins[3] = { "минуту", "минуты", "минут" };
        if (m <= 0) snprintf(buf, size, "отправляется сейчас");
        else if (m < 60) snprintf(buf, size, "через %d %s", m, mins[ru_form(m)]);
        else if (m % 60) snprintf(buf, size, "через %d ч %d мин", m / 60, m % 60);
        else snprintf(buf, size, "через %d ч", m / 60);
        return;
    }
    if (m <= 0) {
        snprintf(buf, size, "odjeżdża teraz");
    } else if (m == 1) {
        snprintf(buf, size, "za 1 minutę");
    } else if (m < 60) {
        int last = m % 10;
        const char *w = (last >= 2 && last <= 4 && (m < 10 || m > 20)) ? "minuty" : "minut";
        snprintf(buf, size, "za %d %s", m, w);
    } else {
        int h = m / 60, r = m % 60;
        if (r) snprintf(buf, size, "za %d godz. %d min", h, r);
        else   snprintf(buf, size, "za %d godz.", h);
    }
}

void rz_clock(int time, char *buf, size_t size)
{
    if (time < 0) time = 0;
    snprintf(buf, size, "%02d:%02d", (time / 60) % 24, time % 60);
}

void rz_duration(long seconds, char *buf, size_t size)
{
    long m, d, h;
    size_t len = 0;
    int first = 1;

    if (seconds < 0) seconds = 0;
    m = seconds / 60;
    d = m / 1440;
    h = (m % 1440) / 60;
    m = m % 60;

    buf[0] = '\0';
#define RZ_APPEND(...) do { \
        int w_ = snprintf(buf + len, size - len, __VA_ARGS__); \
        if (w_ > 0 && (size_t)w_ < size - len) len += (size_t)w_; \
        first = 0; } while (0)

    if (rz_lang == 1) {
        if (d) { RZ_APPEND("%ld %s", d, d == 1 ? "day" : "days"); }
        if (d || h) { RZ_APPEND("%s%ld h", first ? "" : " ", h); }
        RZ_APPEND("%s%ld min", first ? "" : " ", m);
    } else if (rz_lang == 2) {
        static const char *const days[3] = { "день", "дня", "дней" };
        if (d) { RZ_APPEND("%ld %s", d, days[ru_form((int)(d % 100000))]); }
        if (d || h) { RZ_APPEND("%s%ld ч", first ? "" : " ", h); }
        RZ_APPEND("%s%ld мин", first ? "" : " ", m);
    } else {
        if (d) { RZ_APPEND("%ld %s", d, d == 1 ? "dzień" : "dni"); }
        if (d || h) { RZ_APPEND("%s%ld godz.", first ? "" : " ", h); }
        RZ_APPEND("%s%ld min", first ? "" : " ", m);
    }
#undef RZ_APPEND
}

int32_t rz_parse_date(const char *s)
{
    int i;
    int32_t v = 0;
    if (!s || strlen(s) != 8) return 0;
    for (i = 0; i < 8; i++) {
        if (s[i] < '0' || s[i] > '9') return 0;
        v = v * 10 + (s[i] - '0');
    }
    return v;
}

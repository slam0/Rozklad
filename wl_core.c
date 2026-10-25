#include "wl_core.h"

/* ------------------------------------------------------------------ */
/* drobne narzędzia (bez biblioteki C)                                 */
/* ------------------------------------------------------------------ */

static int streq(const char *a, const char *b)
{
    while (*a && *a == *b) { a++; b++; }
    return *a == *b;
}

static int is_ws(char c) { return c == ' ' || c == '\t' || c == '\n' || c == '\r'; }
static int is_digit(char c) { return c >= '0' && c <= '9'; }

static const char *skip_ws(const char *p)
{
    while (*p && is_ws(*p)) p++;
    return p;
}

static double pow10i(int e)
{
    double r = 1.0, b = 10.0;
    while (e > 0) {
        if (e & 1) r *= b;
        b *= b;
        e >>= 1;
    }
    return r;
}

static int valid_code(const char *c)
{
    return c[0] >= 'A' && c[0] <= 'Z' && c[1] >= 'A' && c[1] <= 'Z' && c[2] >= 'A' && c[2] <= 'Z' && c[3] == 0;
}

/* ------------------------------------------------------------------ */
/* mały czytnik JSON                                                   */
/* ------------------------------------------------------------------ */

/* p wskazuje na cudzysłów otwierający. Zwraca wskaźnik za zamykającym albo 0. Do out trafia tekst (bajty
   spoza ASCII zamieniamy na '?', bo interesują nas tylko kody walut i daty). */
static const char *read_string(const char *p, char *out, int n)
{
    int len = 0;
    if (*p != '"') return 0;
    p++;
    while (*p && *p != '"') {
        unsigned char c = (unsigned char)*p;
        if (c == '\\') {
            p++;
            if (!*p) return 0;
            c = (unsigned char)*p;
            if (c == 'u') {
                int i;
                for (i = 0; i < 4; i++) {
                    p++;
                    if (!*p) return 0;
                }
                c = '?';
            } else if (c == 'n' || c == 't' || c == 'r' || c == 'b' || c == 'f') {
                c = ' ';
            }
        } else if (c >= 0x80) {
            c = '?';
        }
        if (out && len < n - 1) out[len++] = (char)c;
        p++;
    }
    if (*p != '"') return 0;
    if (out && n > 0) out[len] = 0;
    return p + 1;
}

/* Liczba: -12.5e-3. Zwraca wskaźnik za liczbą albo 0. */
static const char *read_number(const char *p, double *out)
{
    int neg = 0, digits = 0, exp10 = 0, e = 0, eneg = 0, sig = 0, total;
    double m = 0.0;
    double v;
    if (*p == '-') { neg = 1; p++; }
    else if (*p == '+') p++;
    while (is_digit(*p)) {
        digits++;
        if (sig < 15) {
            m = m * 10.0 + (double)(*p - '0');
            if (m != 0.0) sig++;
        } else {
            exp10++;
        }
        p++;
    }
    if (*p == '.') {
        p++;
        while (is_digit(*p)) {
            digits++;
            if (sig < 15) {
                m = m * 10.0 + (double)(*p - '0');
                if (m != 0.0) sig++;
                exp10--;
            }
            p++;
        }
    }
    if (!digits) return 0;
    if (*p == 'e' || *p == 'E') {
        const char *q = p + 1;
        int ed = 0;
        if (*q == '-') { eneg = 1; q++; }
        else if (*q == '+') q++;
        while (is_digit(*q)) {
            if (e < 10000) e = e * 10 + (*q - '0');
            ed++;
            q++;
        }
        if (ed) p = q;
    }
    total = exp10 + (eneg ? -e : e);
    v = m;
    if (total > 0) {
        if (total > 300) v = 1e300;
        else v *= pow10i(total);
    } else if (total < 0) {
        int k = -total;
        if (k > 330) v = 0.0;
        else if (k <= 22) v /= pow10i(k);
        else { v /= pow10i(22); v /= pow10i(k - 22); }
    }
    *out = neg ? -v : v;
    return p;
}

/* Pomija całą wartość JSON (napis, liczba, true/false/null, obiekt, tablica). */
static const char *skip_value(const char *p)
{
    p = skip_ws(p);
    if (!*p) return 0;
    if (*p == '"') return read_string(p, 0, 0);
    if (*p == '{' || *p == '[') {
        int depth = 0;
        while (*p) {
            if (*p == '"') {
                p = read_string(p, 0, 0);
                if (!p) return 0;
                continue;
            }
            if (*p == '{' || *p == '[') depth++;
            else if (*p == '}' || *p == ']') {
                depth--;
                if (depth == 0) return p + 1;
            }
            p++;
        }
        return 0;
    }
    {
        const char *start = p;
        while (*p && *p != ',' && *p != '}' && *p != ']' && !is_ws(*p)) p++;
        if (p == start) return 0;          /* nic nie przeczytano: błędny JSON, nie kręcimy się w kółko */
    }
    return p;
}

/* *pp stoi tuż za '{' albo za poprzednią wartością. Zwraca 1 i ustawia klucz oraz początek wartości. */
static int obj_next(const char **pp, char *key, int n, const char **val)
{
    const char *p = skip_ws(*pp);
    if (*p == ',') p = skip_ws(p + 1);
    if (*p != '"') return 0;
    p = read_string(p, key, n);
    if (!p) return 0;
    p = skip_ws(p);
    if (*p != ':') return 0;
    *val = skip_ws(p + 1);
    *pp = *val;
    return 1;
}

static int arr_next(const char **pp, const char **val)
{
    const char *p = skip_ws(*pp);
    if (*p == ',') p = skip_ws(p + 1);
    if (*p == ']' || !*p) return 0;
    *val = p;
    *pp = p;
    return 1;
}

/* ------------------------------------------------------------------ */
/* daty                                                                */
/* ------------------------------------------------------------------ */

/* Dni od 1970-01-01 (algorytm Howarda Hinnanta). Tylko 32-bitowe liczby: na iOS 6 (armv7) nie chcemy dzielenia 64-bitowego. */
static WL_LONG days_from_civil(WL_LONG y, int m, int d)
{
    WL_LONG era, yoe, doy, doe;
    if (m <= 2) y -= 1;
    era = (y >= 0 ? y : y - 399) / 400;
    yoe = y - era * 400;
    doy = (153L * (m + (m > 2 ? -3 : 9)) + 2) / 5 + d - 1;
    doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    return era * 146097L + doe - 719468L;
}

static void civil_from_days(WL_LONG z, int *yy, int *mm, int *dd)
{
    WL_LONG era, doe, yoe, y, doy, mp;
    int d, m;
    z += 719468L;
    era = (z >= 0 ? z : z - 146096L) / 146097L;
    doe = z - era * 146097L;
    yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    y = yoe + era * 400;
    doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    mp = (5 * doy + 2) / 153;
    d = (int)(doy - (153 * mp + 2) / 5 + 1);
    m = (int)(mp < 10 ? mp + 3 : mp - 9);
    if (m <= 2) y += 1;
    *yy = (int)y;
    *mm = m;
    *dd = d;
}

WL_LONG wl_date_to_unix(const char *s)
{
    int y, m, d, i;
    if (!s) return -1;
    for (i = 0; i < 10; i++) {
        if (i == 4 || i == 7) { if (s[i] != '-') return -1; }
        else if (!is_digit(s[i])) return -1;
    }
    y = (s[0] - '0') * 1000 + (s[1] - '0') * 100 + (s[2] - '0') * 10 + (s[3] - '0');
    m = (s[5] - '0') * 10 + (s[6] - '0');
    d = (s[8] - '0') * 10 + (s[9] - '0');
    if (y < 1970 || y > 2037 || m < 1 || m > 12 || d < 1 || d > 31) return -1;
    return days_from_civil(y, m, d) * 86400L;
}

void wl_unix_to_date(WL_LONG t, char *out)
{
    int y, m, d;
    if (t < 0) t = 0;
    civil_from_days(t / 86400L, &y, &m, &d);
    out[0] = (char)('0' + (y / 1000) % 10);
    out[1] = (char)('0' + (y / 100) % 10);
    out[2] = (char)('0' + (y / 10) % 10);
    out[3] = (char)('0' + y % 10);
    out[4] = '-';
    out[5] = (char)('0' + m / 10);
    out[6] = (char)('0' + m % 10);
    out[7] = '-';
    out[8] = (char)('0' + d / 10);
    out[9] = (char)('0' + d % 10);
    out[10] = 0;
}

WL_LONG wl_age_days(WL_LONG now, WL_LONG then)
{
    if (then <= 0) return -1;
    if (now <= then) return 0;
    return (now - then) / 86400;
}

/* ------------------------------------------------------------------ */
/* tabela                                                              */
/* ------------------------------------------------------------------ */

void wl_table_clear(wl_table *t)
{
    t->count = 0;
    t->source = WL_SRC_NONE;
    t->fetched = 0;
    t->updated = 0;
    t->date[0] = 0;
}

static void copy_code(char *dst, const char *src)
{
    dst[0] = src[0]; dst[1] = src[1]; dst[2] = src[2]; dst[3] = 0;
}

/* dodaje albo podmienia kurs; zachowuje porządek alfabetyczny */
static int table_add(wl_table *t, const char *code, double per_pln)
{
    int i, pos;
    for (i = 0; i < t->count; i++) {
        if (streq(t->rates[i].code, code)) {
            t->rates[i].per_pln = per_pln;
            return 1;
        }
    }
    if (t->count >= WL_MAX_RATES) return 0;
    pos = t->count;
    while (pos > 0) {
        const char *a = t->rates[pos - 1].code;
        int gt = 0, k;
        for (k = 0; k < 3; k++) {
            if (a[k] != code[k]) { gt = a[k] > code[k]; break; }
        }
        if (!gt) break;
        t->rates[pos] = t->rates[pos - 1];
        pos--;
    }
    copy_code(t->rates[pos].code, code);
    t->rates[pos].per_pln = per_pln;
    t->count++;
    return 1;
}

const wl_rate *wl_find(const wl_table *t, const char *code)
{
    int lo = 0, hi = t->count - 1;
    if (!code) return 0;
    while (lo <= hi) {
        int mid = (lo + hi) / 2, k, cmp = 0;
        const char *a = t->rates[mid].code;
        for (k = 0; k < 3; k++) {
            if (a[k] != code[k]) { cmp = a[k] < code[k] ? -1 : 1; break; }
        }
        if (cmp == 0 && code[3] != 0) cmp = -1;
        if (cmp == 0) return &t->rates[mid];
        if (cmp < 0) lo = mid + 1; else hi = mid - 1;
    }
    return 0;
}

int wl_has(const wl_table *t, const char *code) { return wl_find(t, code) != 0; }

int wl_convert(const wl_table *t, double amount, const char *from, const char *to, double *out)
{
    const wl_rate *a = wl_find(t, from), *b = wl_find(t, to);
    if (!a || !b || a->per_pln <= 0.0 || b->per_pln <= 0.0) return 0;
    *out = amount * b->per_pln / a->per_pln;
    return 1;
}

static int sane(double v) { return v > 0.0 && v < 1e15 && v > 1e-15; }

static void ensure_pln(wl_table *t)
{
    if (!wl_find(t, "PLN")) table_add(t, "PLN", 1.0);
}

/* ------------------------------------------------------------------ */
/* NBP: [{"table":"A","no":"...","effectiveDate":"2024-10-21","rates":[{"currency":"..","code":"EUR","mid":4.3}]}] */
/* ------------------------------------------------------------------ */

int wl_parse_nbp(const char *json, wl_table *t)
{
    const char *p, *val;
    char key[32];
    wl_table_clear(t);
    if (!json) return -1;
    p = skip_ws(json);
    if (*p == '[') p = skip_ws(p + 1);
    if (*p != '{') return -1;
    p++;
    while (obj_next(&p, key, (int)sizeof key, &val)) {
        if (streq(key, "effectiveDate")) {
            char d[16];
            if (read_string(val, d, (int)sizeof d) && wl_date_to_unix(d) >= 0) {
                int i;
                for (i = 0; i < 10; i++) t->date[i] = d[i];
                t->date[10] = 0;
                t->updated = wl_date_to_unix(d);
            }
        } else if (streq(key, "rates") && *val == '[') {
            const char *q = val + 1, *ev;
            while (arr_next(&q, &ev)) {
                if (*ev == '{') {
                    char code[8], k2[16];
                    double mid = 0.0;
                    int hc = 0, hm = 0;
                    const char *r = ev + 1, *v2;
                    code[0] = 0;
                    while (obj_next(&r, k2, (int)sizeof k2, &v2)) {
                        if (streq(k2, "code")) hc = read_string(v2, code, (int)sizeof code) != 0;
                        else if (streq(k2, "mid")) hm = read_number(v2, &mid) != 0;
                        r = skip_value(v2);
                        if (!r) break;
                    }
                    if (hc && hm && valid_code(code) && sane(mid)) table_add(t, code, 1.0 / mid);
                }
                q = skip_value(ev);
                if (!q) break;
            }
        }
        p = skip_value(val);
        if (!p) break;
    }
    if (t->count < 5) { wl_table_clear(t); return -1; }
    ensure_pln(t);
    t->source = WL_SRC_NBP;
    return t->count;
}

/* ------------------------------------------------------------------ */
/* open.er-api.com                                                     */
/* ------------------------------------------------------------------ */

int wl_parse_erapi(const char *json, wl_table *t)
{
    const char *p, *val;
    char key[40];
    double last = 0.0;
    const wl_rate *pln;
    double plnv;
    int i;
    wl_table_clear(t);
    if (!json) return -1;
    p = skip_ws(json);
    if (*p != '{') return -1;
    p++;
    while (obj_next(&p, key, (int)sizeof key, &val)) {
        if (streq(key, "result")) {
            char r[16];
            if (!read_string(val, r, (int)sizeof r) || !streq(r, "success")) { wl_table_clear(t); return -1; }
        } else if (streq(key, "time_last_update_unix")) {
            read_number(val, &last);
        } else if (streq(key, "rates") && *val == '{') {
            const char *q = val + 1, *v2;
            char code[8];
            while (obj_next(&q, code, (int)sizeof code, &v2)) {
                double v;
                if (valid_code(code) && read_number(v2, &v) && sane(v)) table_add(t, code, v);
                q = skip_value(v2);
                if (!q) break;
            }
        }
        p = skip_value(val);
        if (!p) break;
    }
    pln = wl_find(t, "PLN");
    if (!pln || t->count < 5) { wl_table_clear(t); return -1; }
    plnv = pln->per_pln;
    for (i = 0; i < t->count; i++) t->rates[i].per_pln /= plnv;
    t->source = WL_SRC_ERAPI;
    if (last > 1e9 && last < 4e9) {
        t->updated = (WL_LONG)last;
        wl_unix_to_date(t->updated, t->date);
    }
    return t->count;
}

/* ------------------------------------------------------------------ */
/* zapis i odczyt                                                      */
/* ------------------------------------------------------------------ */

static int put_char(char *buf, int n, int *len, char c)
{
    if (*len >= n - 1) return 0;
    buf[(*len)++] = c;
    return 1;
}

static int put_long(char *buf, int n, int *len, WL_LONG v)
{
    char tmp[24];
    int k = 0;
    if (v < 0) { if (!put_char(buf, n, len, '-')) return 0; v = -v; }
    if (v == 0) tmp[k++] = '0';
    while (v > 0) { tmp[k++] = (char)('0' + v % 10); v /= 10; }
    while (k > 0) if (!put_char(buf, n, len, tmp[--k])) return 0;
    return 1;
}

/* 12 cyfr znaczących: d.dddddddddddeNN (cyfry wyciągane z liczby zmiennoprzecinkowej, bez 64-bitowych liczb całkowitych) */
static int put_sci(char *buf, int n, int *len, double v)
{
    int e = 0, i;
    if (!(v > 0.0)) return put_char(buf, n, len, '0');
    while (v >= 10.0) { v /= 10.0; e++; }
    while (v < 1.0) { v *= 10.0; e--; }
    v += 0.000000000005;                       /* zaokrąglenie na 12. cyfrze */
    if (v >= 10.0) { v /= 10.0; e++; }
    for (i = 0; i < 12; i++) {
        int dgt = (int)v;
        if (dgt > 9) dgt = 9;
        if (dgt < 0) dgt = 0;
        if (!put_char(buf, n, len, (char)('0' + dgt))) return 0;
        if (i == 0 && !put_char(buf, n, len, '.')) return 0;
        v = (v - (double)dgt) * 10.0;
    }
    if (!put_char(buf, n, len, 'e')) return 0;
    return put_long(buf, n, len, e);
}

int wl_serialize(const wl_table *t, char *buf, int n)
{
    int len = 0, i;
    const char *h = "WL1\nS ";
    if (n < 16) return -1;
    while (*h) if (!put_char(buf, n, &len, *h++)) return -1;
    if (!put_long(buf, n, &len, t->source)) return -1;
    if (!put_char(buf, n, &len, '\n') || !put_char(buf, n, &len, 'F') || !put_char(buf, n, &len, ' ')) return -1;
    if (!put_long(buf, n, &len, t->fetched)) return -1;
    if (!put_char(buf, n, &len, '\n') || !put_char(buf, n, &len, 'U') || !put_char(buf, n, &len, ' ')) return -1;
    if (!put_long(buf, n, &len, t->updated)) return -1;
    if (!put_char(buf, n, &len, '\n') || !put_char(buf, n, &len, 'D') || !put_char(buf, n, &len, ' ')) return -1;
    for (i = 0; t->date[i] && i < 10; i++) if (!put_char(buf, n, &len, t->date[i])) return -1;
    if (!put_char(buf, n, &len, '\n')) return -1;
    for (i = 0; i < t->count; i++) {
        int k;
        for (k = 0; k < 3; k++) if (!put_char(buf, n, &len, t->rates[i].code[k])) return -1;
        if (!put_char(buf, n, &len, ' ')) return -1;
        if (!put_sci(buf, n, &len, t->rates[i].per_pln)) return -1;
        if (!put_char(buf, n, &len, '\n')) return -1;
    }
    buf[len] = 0;
    return len;
}

int wl_deserialize(const char *s, wl_table *t)
{
    wl_table_clear(t);
    if (!s || s[0] != 'W' || s[1] != 'L' || s[2] != '1') return -1;
    while (*s) {
        const char *line = s, *end = s;
        while (*end && *end != '\n') end++;
        if (line[1] == ' ' && (line[0] == 'S' || line[0] == 'F' || line[0] == 'U')) {
            double v;
            if (read_number(line + 2, &v)) {
                if (line[0] == 'S') t->source = (int)v;
                else if (line[0] == 'F') t->fetched = (WL_LONG)v;
                else t->updated = (WL_LONG)v;
            }
        } else if (line[1] == ' ' && line[0] == 'D') {
            int i;
            if (wl_date_to_unix(line + 2) >= 0) {
                for (i = 0; i < 10; i++) t->date[i] = line[2 + i];
                t->date[10] = 0;
            }
        } else if (line[0] >= 'A' && line[0] <= 'Z' && line[3] == ' ') {
            char code[4];
            double v;
            copy_code(code, line);
            if (valid_code(code) && read_number(line + 4, &v) && sane(v)) table_add(t, code, v);
        }
        s = *end ? end + 1 : end;
    }
    if (t->count < 1) { wl_table_clear(t); return -1; }
    return t->count;
}

/* ------------------------------------------------------------------ */
/* kwoty                                                               */
/* ------------------------------------------------------------------ */

int wl_parse_amount(const char *s, double *out)
{
    char tmp[48];
    int n = 0, i, neg = 0, ndig = 0, dec_at = -1, last_dot = -1, last_com = -1, ndot = 0, ncom = 0;
    char clean[48];
    int cn = 0;
    double v;
    if (!s) return 0;
    while (*s == ' ' || *s == '\t') s++;
    if (*s == '-') { neg = 1; s++; }
    else if (*s == '+') s++;
    for (; *s; s++) {
        unsigned char c = (unsigned char)*s;
        if (c == 0xC2 && (unsigned char)s[1] == 0xA0) { s++; continue; }      /* twarda spacja */
        if (c == ' ' || c == '\t' || c == '\'') continue;
        if (is_digit((char)c)) { ndig++; }
        else if (c == '.') { last_dot = n; ndot++; }
        else if (c == ',') { last_com = n; ncom++; }
        else return 0;
        if (n >= (int)sizeof tmp - 1) return 0;
        tmp[n++] = (char)c;
    }
    if (ndig == 0 || ndig > 17) return 0;
    if (ndot && ncom) dec_at = last_dot > last_com ? last_dot : last_com;
    else if (ndot == 1) dec_at = last_dot;
    else if (ncom == 1) dec_at = last_com;
    for (i = 0; i < n; i++) {
        if (i == dec_at) clean[cn++] = '.';
        else if (tmp[i] != '.' && tmp[i] != ',') clean[cn++] = tmp[i];
    }
    clean[cn] = 0;
    if (cn == 0 || clean[0] == '.') {
        /* ".5" -> "0.5" */
        char z[50];
        int k = 0;
        z[k++] = '0';
        for (i = 0; i < cn; i++) z[k++] = clean[i];
        z[k] = 0;
        for (i = 0; i <= k; i++) clean[i] = z[i];
    }
    if (!read_number(clean, &v)) return 0;
    if (v >= 1e15) return 0;
    *out = neg ? -v : v;
    return 1;
}

int wl_format_number(double v, int min_dec, int max_dec, char dec_sep, char group_sep, char *buf, int n)
{
    int neg = 0, i, len = 0, k, nd = 0;
    unsigned WL_LONG hi, lo, fs, scale = 1;
    double rem, frac;
    char digs[24], fdig[12];
    if (!(v == v) || n < 2) return -1;
    if (v < 0.0) { neg = 1; v = -v; }
    if (v >= 1e15) return -1;
    if (max_dec < 0) max_dec = 0;
    if (max_dec > 9) max_dec = 9;
    if (min_dec < 0) min_dec = 0;
    if (min_dec > max_dec) min_dec = max_dec;
    for (i = 0; i < max_dec; i++) scale *= 10UL;
    /* część całkowita jako hi * 10^9 + lo, żeby użyć tylko 32-bitowych liczb */
    hi = (unsigned WL_LONG)(v / 1e9);
    rem = v - (double)hi * 1e9;
    if (rem < 0.0) { if (hi > 0) hi--; rem = v - (double)hi * 1e9; }
    lo = (unsigned WL_LONG)rem;
    frac = rem - (double)lo;
    fs = (unsigned WL_LONG)(frac * (double)scale + 0.5);
    if (fs >= scale) {
        lo += 1;
        fs -= scale;
        if (lo >= 1000000000UL) { lo -= 1000000000UL; hi += 1; }
    }
    if (hi == 0 && lo == 0 && fs == 0) neg = 0;
    /* część ułamkowa */
    for (i = max_dec - 1; i >= 0; i--) { fdig[i] = (char)('0' + (int)(fs % 10)); fs /= 10; }
    k = max_dec;
    while (k > min_dec && fdig[k - 1] == '0') k--;
    /* część całkowita: od końca */
    if (hi > 0) {
        for (i = 0; i < 9; i++) { digs[nd++] = (char)('0' + (int)(lo % 10)); lo /= 10; }
        while (hi > 0) { digs[nd++] = (char)('0' + (int)(hi % 10)); hi /= 10; }
    } else {
        if (lo == 0) digs[nd++] = '0';
        while (lo > 0) { digs[nd++] = (char)('0' + (int)(lo % 10)); lo /= 10; }
    }
    if (neg) if (!put_char(buf, n, &len, '-')) return -1;
    for (i = nd - 1; i >= 0; i--) {
        if (!put_char(buf, n, &len, digs[i])) return -1;
        if (group_sep && i > 0 && i % 3 == 0) if (!put_char(buf, n, &len, group_sep)) return -1;
    }
    if (k > 0) {
        if (!put_char(buf, n, &len, dec_sep)) return -1;
        for (i = 0; i < k; i++) if (!put_char(buf, n, &len, fdig[i])) return -1;
    }
    buf[len] = 0;
    return len;
}

int wl_money_decimals(double v)
{
    int z = 0;
    if (v < 0.0) v = -v;
    if (v == 0.0 || v >= 1.0) return 2;
    while (v < 0.1 && z < 8) { v *= 10.0; z++; }
    return z + 3 > 8 ? 8 : z + 3;
}

int wl_rate_decimals(double v)
{
    int z = 0;
    if (v < 0.0) v = -v;
    if (v >= 100.0 || v == 0.0) return 2;
    if (v >= 10.0) return 3;
    if (v >= 1.0) return 4;
    while (v < 0.1 && z < 8) { v *= 10.0; z++; }
    return z + 4 > 9 ? 9 : z + 4;
}

int wl_plural(int lang, WL_LONG n)
{
    WL_LONG a, b;
    if (n < 0) n = -n;
    if (lang == 1) return n == 1 ? 0 : 2;
    a = n % 10;
    b = n % 100;
    if (lang == 2) {
        if (a == 1 && b != 11) return 0;
        if (a >= 2 && a <= 4 && !(b >= 12 && b <= 14)) return 1;
        return 2;
    }
    if (n == 1) return 0;
    if (a >= 2 && a <= 4 && !(b >= 12 && b <= 14)) return 1;
    return 2;
}

/* Testy logiki z wl_core.c. Uruchomienie: gcc -Wall wl_core.c tests/core_test.c -o core_test && ./core_test */
#include <stdio.h>
#include <string.h>
#include <math.h>
#include "../wl_core.h"

static int fails = 0, checks = 0;
#define CHECK(c) do { checks++; if (!(c)) { fails++; printf("BŁĄD (linia %d): %s\n", __LINE__, #c); } } while (0)
#define NEAR(a, b, tol) do { checks++; double _a = (a), _b = (b); if (fabs(_a - _b) > (tol) * (fabs(_b) > 1 ? fabs(_b) : 1)) { fails++; printf("BŁĄD (linia %d): %s = %.12g, oczekiwano %.12g\n", __LINE__, #a, _a, _b); } } while (0)

static const char *NBP =
"[{\"table\":\"A\",\"no\":\"205/A/NBP/2024\",\"effectiveDate\":\"2024-10-21\",\"rates\":["
"{\"currency\":\"bat (Tajlandia)\",\"code\":\"THB\",\"mid\":0.1166},"
"{\"currency\":\"dolar amerykański\",\"code\":\"USD\",\"mid\":3.9822},"
"{\"currency\":\"dolar australijski\",\"code\":\"AUD\",\"mid\":2.6531},"
"{\"currency\":\"euro\",\"code\":\"EUR\",\"mid\":4.3000},"
"{\"currency\":\"frank szwajcarski\",\"code\":\"CHF\",\"mid\":4.5913},"
"{\"currency\":\"funt szterling\",\"code\":\"GBP\",\"mid\":5.1650},"
"{\"currency\":\"jen (Japonia)\",\"code\":\"JPY\",\"mid\":0.026230},"
"{\"currency\":\"SDR (MFW)\",\"code\":\"XDR\",\"mid\":5.3901},"
"{\"currency\":\"z \\\"cudzys\\u0142owem\\\"\",\"code\":\"CZK\",\"mid\":1.7e-1}"
"]}]";

static const char *ER =
"{\"result\":\"success\",\"provider\":\"https://www.exchangerate-api.com\","
"\"documentation\":\"https://www.exchangerate-api.com/docs/free\","
"\"terms_of_use\":\"https://www.exchangerate-api.com/terms\","
"\"time_last_update_unix\":1729468951,\"time_last_update_utc\":\"Mon, 21 Oct 2024 00:02:31 +0000\","
"\"time_next_update_unix\":1729556441,\"time_next_update_utc\":\"Tue, 22 Oct 2024 00:20:41 +0000\","
"\"time_eol_unix\":0,\"base_code\":\"PLN\",\"rates\":{\"PLN\":1,\"AED\":0.9222,\"EUR\":0.2326,"
"\"USD\":0.2511,\"GBP\":0.1936,\"JPY\":38.12,\"CHF\":0.2178,\"XOF\":152.5}}";

int main(void)
{
    wl_table t, u;
    double v;
    char buf[64];
    int n;

    /* --- NBP --- */
    n = wl_parse_nbp(NBP, &t);
    CHECK(n == 10);                              /* 9 walut + PLN */
    CHECK(t.source == WL_SRC_NBP);
    CHECK(strcmp(t.date, "2024-10-21") == 0);
    CHECK(t.updated == 1729468800L);
    CHECK(wl_has(&t, "PLN") && wl_has(&t, "THB") && wl_has(&t, "CZK"));
    CHECK(!wl_has(&t, "XYZ") && !wl_has(&t, "EU") && !wl_has(&t, "EURO"));
    NEAR(wl_find(&t, "EUR")->per_pln, 1.0 / 4.3, 1e-12);
    NEAR(wl_find(&t, "CZK")->per_pln, 1.0 / 0.17, 1e-12);
    CHECK(wl_convert(&t, 100.0, "EUR", "PLN", &v)); NEAR(v, 430.0, 1e-9);
    CHECK(wl_convert(&t, 100.0, "PLN", "EUR", &v)); NEAR(v, 100.0 / 4.3, 1e-9);
    CHECK(wl_convert(&t, 10.0, "USD", "EUR", &v)); NEAR(v, 10.0 * 3.9822 / 4.3, 1e-9);
    CHECK(wl_convert(&t, 10.0, "JPY", "JPY", &v)); NEAR(v, 10.0, 1e-12);
    CHECK(!wl_convert(&t, 1.0, "EUR", "XYZ", &v));
    /* posortowane */
    for (int i = 1; i < t.count; i++) CHECK(strcmp(t.rates[i - 1].code, t.rates[i].code) < 0);

    /* złe dane */
    CHECK(wl_parse_nbp("", &t) == -1);
    CHECK(wl_parse_nbp("<html>błąd 404</html>", &t) == -1);
    CHECK(wl_parse_nbp("[]", &t) == -1);
    CHECK(wl_parse_nbp("[{\"table\":\"A\",\"rates\":[{\"code\":\"EUR\",\"mid\":4.3}", &t) == -1);   /* ucięte */
    CHECK(wl_parse_nbp("404 NotFound - Not Found - Brak danych", &t) == -1);
    CHECK(wl_parse_nbp(0, &t) == -1);
    /* uszkodzony element w tablicy nie może zawiesić czytnika (kiedyś pętla bez końca) */
    CHECK(wl_parse_nbp("[{\"effectiveDate\":\"2024-10-21\",\"rates\":[{\"code\":\"EUR\",\"mid\":4.3}\xef{\"code\":\"USD\",\"mid\":4}]}]", &t) == -1);
    CHECK(wl_parse_nbp("[{\"rates\":[}]}]", &t) == -1);
    CHECK(wl_parse_erapi("{\"result\":\"success\",\"rates\":{\"PLN\":1,\"EUR\":}}", &t) == -1);

    /* --- ER-API --- */
    n = wl_parse_erapi(ER, &u);
    CHECK(n == 8);
    CHECK(u.source == WL_SRC_ERAPI);
    CHECK(u.updated == 1729468951L);
    CHECK(strcmp(u.date, "2024-10-21") == 0);
    NEAR(wl_find(&u, "PLN")->per_pln, 1.0, 1e-12);
    NEAR(wl_find(&u, "EUR")->per_pln, 0.2326, 1e-12);
    CHECK(wl_convert(&u, 100.0, "EUR", "USD", &v)); NEAR(v, 100.0 * 0.2511 / 0.2326, 1e-9);
    CHECK(wl_convert(&u, 1000.0, "JPY", "PLN", &v)); NEAR(v, 1000.0 / 38.12, 1e-9);

    /* inna waluta bazowa: wynik taki sam */
    {
        const char *ER_EUR = "{\"result\":\"success\",\"time_last_update_unix\":1729468951,\"base_code\":\"EUR\","
            "\"rates\":{\"EUR\":1,\"PLN\":4.2992,\"USD\":1.0795,\"GBP\":0.8323,\"JPY\":163.9,\"CHF\":0.9364}}";
        wl_table w;
        CHECK(wl_parse_erapi(ER_EUR, &w) == 6);
        CHECK(wl_convert(&w, 1.0, "EUR", "PLN", &v)); NEAR(v, 4.2992, 1e-9);
        CHECK(wl_convert(&w, 100.0, "PLN", "EUR", &v)); NEAR(v, 100.0 / 4.2992, 1e-9);
    }

    CHECK(wl_parse_erapi("{\"result\":\"error\",\"error-type\":\"quota-reached\"}", &u) == -1);
    CHECK(wl_parse_erapi("Error 1015 - rate limited", &u) == -1);
    CHECK(wl_parse_erapi("{\"result\":\"success\",\"rates\":{\"EUR\":0.2}}", &u) == -1);   /* brak PLN */
    CHECK(wl_parse_erapi("", &u) == -1);

    /* --- zapis i odczyt --- */
    {
        char text[8192];
        wl_table r;
        wl_parse_nbp(NBP, &t);
        t.fetched = 1729500000L;
        n = wl_serialize(&t, text, sizeof text);
        CHECK(n > 0 && (int)strlen(text) == n);
        CHECK(strncmp(text, "WL1\n", 4) == 0);
        CHECK(wl_deserialize(text, &r) == t.count);
        CHECK(r.source == WL_SRC_NBP && r.fetched == 1729500000L && r.updated == t.updated);
        CHECK(strcmp(r.date, "2024-10-21") == 0);
        for (int i = 0; i < t.count; i++) {
            CHECK(strcmp(r.rates[i].code, t.rates[i].code) == 0);
            NEAR(r.rates[i].per_pln, t.rates[i].per_pln, 1e-10);
        }
        CHECK(wl_serialize(&t, text, 20) == -1);       /* za mały bufor */
        CHECK(wl_deserialize("śmieci", &r) == -1);
        CHECK(wl_deserialize("WL1\nS 1\n", &r) == -1);
        CHECK(wl_deserialize(0, &r) == -1);
        /* bardzo małe i duże kursy */
        wl_table_clear(&r);
        r.source = 1;
        wl_parse_erapi("{\"result\":\"success\",\"rates\":{\"PLN\":1,\"IDR\":3950.123456,\"XAU\":0.000234567,\"AAA\":2,\"BBB\":3,\"CCC\":4}}", &r);
        n = wl_serialize(&r, text, sizeof text);
        CHECK(n > 0);
        wl_table q;
        CHECK(wl_deserialize(text, &q) == r.count);
        NEAR(wl_find(&q, "IDR")->per_pln, 3950.123456, 1e-10);
        NEAR(wl_find(&q, "XAU")->per_pln, 0.000234567, 1e-9);
    }

    /* --- kwoty --- */
    CHECK(wl_parse_amount("100", &v) && v == 100.0);
    CHECK(wl_parse_amount("100,5", &v)); NEAR(v, 100.5, 1e-12);
    CHECK(wl_parse_amount("100.5", &v)); NEAR(v, 100.5, 1e-12);
    CHECK(wl_parse_amount("1 234,56", &v)); NEAR(v, 1234.56, 1e-12);
    CHECK(wl_parse_amount("1\xC2\xA0" "234,56", &v)); NEAR(v, 1234.56, 1e-12);
    CHECK(wl_parse_amount("1,234.56", &v)); NEAR(v, 1234.56, 1e-12);
    CHECK(wl_parse_amount("1.234,56", &v)); NEAR(v, 1234.56, 1e-12);
    CHECK(wl_parse_amount("1,234,567", &v)); NEAR(v, 1234567.0, 1e-12);
    CHECK(wl_parse_amount(",5", &v)); NEAR(v, 0.5, 1e-12);
    CHECK(wl_parse_amount(".25", &v)); NEAR(v, 0.25, 1e-12);
    CHECK(wl_parse_amount("5.", &v)); NEAR(v, 5.0, 1e-12);
    CHECK(wl_parse_amount("-12,5", &v)); NEAR(v, -12.5, 1e-12);
    CHECK(wl_parse_amount("0,00001", &v)); NEAR(v, 0.00001, 1e-12);
    CHECK(wl_parse_amount("007", &v) && v == 7.0);
    CHECK(!wl_parse_amount("", &v));
    CHECK(!wl_parse_amount("abc", &v));
    CHECK(!wl_parse_amount("12abc", &v));
    CHECK(!wl_parse_amount(",", &v));
    CHECK(!wl_parse_amount("-", &v));
    CHECK(!wl_parse_amount("1e5", &v));
    CHECK(!wl_parse_amount("99999999999999999999", &v));
    CHECK(!wl_parse_amount(0, &v));

    #define FMT(x, mn, mx, ds, gs, expect) do { int _n = wl_format_number((x), (mn), (mx), (ds), (gs), buf, sizeof buf); \
        CHECK(_n >= 0 && strcmp(buf, (expect)) == 0); if (strcmp(buf, (expect))) printf("   dostałem '%s', oczekiwano '%s'\n", buf, (expect)); } while (0)
    FMT(1234.5, 2, 2, ',', ' ', "1 234,50");
    FMT(1234567.891, 2, 2, ',', ' ', "1 234 567,89");
    FMT(1234567.891, 2, 2, '.', ',', "1,234,567.89");
    FMT(0.0, 2, 2, ',', ' ', "0,00");
    FMT(0.0, 0, 2, ',', ' ', "0");
    FMT(999.999, 2, 2, ',', ' ', "1 000,00");               /* przeniesienie przy zaokrągleniu */
    FMT(0.995, 2, 2, ',', 0, "1,00");
    FMT(-5.5, 2, 4, ',', 0, "-5,50");
    FMT(-0.001, 2, 2, ',', 0, "0,00");                       /* bez "-0,00" */
    FMT(12.3456, 0, 4, ',', 0, "12,3456");
    FMT(12.3, 0, 4, ',', 0, "12,3");
    FMT(12.0, 0, 4, ',', 0, "12");
    FMT(100.0, 2, 2, ',', ' ', "100,00");
    FMT(1000.0, 2, 2, ',', ' ', "1 000,00");
    FMT(999999999999999.0, 0, 0, ',', ' ', "999 999 999 999 999");
    FMT(1000000000.0, 2, 2, ',', ' ', "1 000 000 000,00");
    FMT(1999999999.5, 1, 1, ',', ' ', "1 999 999 999,5");
    FMT(123456789012.0, 2, 2, ',', ' ', "123 456 789 012,00");
    FMT(0.00001234, 2, 8, ',', 0, "0,00001234");
    CHECK(wl_format_number(1e15, 2, 2, ',', ' ', buf, sizeof buf) == -1);
    CHECK(wl_format_number(1234.5, 2, 2, ',', ' ', buf, 5) == -1);       /* za mały bufor */

    CHECK(wl_money_decimals(1234.5) == 2 && wl_money_decimals(1.0) == 2 && wl_money_decimals(0.0) == 2);
    CHECK(wl_money_decimals(0.5) == 3 && wl_money_decimals(0.05) == 4 && wl_money_decimals(0.0005) == 6);
    CHECK(wl_rate_decimals(4000.0) == 2 && wl_rate_decimals(38.12) == 3 && wl_rate_decimals(4.3) == 4);
    CHECK(wl_rate_decimals(0.2326) == 4 && wl_rate_decimals(0.0234) == 5 && wl_rate_decimals(0.000234) == 7);
    {
        /* typowy wynik: 100 EUR -> USD */
        wl_parse_erapi(ER, &u);
        wl_convert(&u, 100.0, "EUR", "USD", &v);
        n = wl_format_number(v, 2, wl_money_decimals(v), ',', ' ', buf, sizeof buf);
        CHECK(n > 0 && strcmp(buf, "107,95") == 0);
    }

    /* --- daty --- */
    CHECK(wl_date_to_unix("1970-01-01") == 0);
    CHECK(wl_date_to_unix("2024-10-21") == 1729468800L);
    CHECK(wl_date_to_unix("2024-02-29") == 1709164800L);
    CHECK(wl_date_to_unix("2038-01-01") == -1);   /* poza zakresem 32-bitowego czasu */
    CHECK(wl_date_to_unix("2024-13-01") == -1);
    CHECK(wl_date_to_unix("2024/10/21") == -1);
    CHECK(wl_date_to_unix("abc") == -1);
    CHECK(wl_date_to_unix("2024-1-21") == -1);
    wl_unix_to_date(1729468951L, buf); CHECK(strcmp(buf, "2024-10-21") == 0);
    wl_unix_to_date(1709164800L, buf); CHECK(strcmp(buf, "2024-02-29") == 0);
    wl_unix_to_date(0L, buf); CHECK(strcmp(buf, "1970-01-01") == 0);
    wl_unix_to_date(951782400L, buf); CHECK(strcmp(buf, "2000-02-29") == 0);
    wl_unix_to_date(-5L, buf); CHECK(strcmp(buf, "1970-01-01") == 0);
    for (long d = 0; d < 24000; d += 37) {          /* tam i z powrotem */
        wl_unix_to_date(d * 86400L, buf);
        CHECK(wl_date_to_unix(buf) == d * 86400L);
    }
    CHECK(wl_age_days(1000000L, 0) == -1);
    CHECK(wl_age_days(1729468800L + 3 * 86400L + 5, 1729468800L) == 3);
    CHECK(wl_age_days(100L, 200L) == 0);

    /* --- odmiana --- */
    CHECK(wl_plural(0, 1) == 0 && wl_plural(0, 2) == 1 && wl_plural(0, 5) == 2 && wl_plural(0, 12) == 2 && wl_plural(0, 22) == 1);
    CHECK(wl_plural(1, 1) == 0 && wl_plural(1, 2) == 2 && wl_plural(1, 0) == 2);
    CHECK(wl_plural(2, 1) == 0 && wl_plural(2, 21) == 0 && wl_plural(2, 11) == 2 && wl_plural(2, 3) == 1 && wl_plural(2, 25) == 2);

    printf("%s: %d sprawdzeń, %d błędów\n", fails ? "NIE ZDAŁO" : "OK", checks, fails);
    return fails ? 1 : 0;
}

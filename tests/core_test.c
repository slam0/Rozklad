/* Test logiki rozkładu: clang -I.. ../rz_core.c core_test.c -o core_test && ./core_test */
#include "../rz_core.h"
#include <stdio.h>
#include <string.h>

static int fails = 0;
#define CHECK(cond, msg) do { if (!(cond)) { printf("BŁĄD: %s\n", msg); fails++; } } while (0)

static void expect_eta(int m, const char *want)
{
    char b[64];
    rz_eta(m, b, sizeof b);
    if (strcmp(b, want) != 0) { printf("BŁĄD eta(%d): '%s' zamiast '%s'\n", m, b, want); fails++; }
}

int main(void)
{
    /* --- teksty --- */
    expect_eta(0, "odjeżdża teraz");   expect_eta(-3, "odjeżdża teraz");
    expect_eta(1, "za 1 minutę");      expect_eta(2, "za 2 minuty");
    expect_eta(5, "za 5 minut");       expect_eta(11, "za 11 minut");
    expect_eta(12, "za 12 minut");     expect_eta(14, "za 14 minut");
    expect_eta(22, "za 22 minuty");    expect_eta(45, "za 45 minut");
    expect_eta(59, "za 59 minut");     expect_eta(60, "za 1 godz.");
    expect_eta(65, "za 1 godz. 5 min"); expect_eta(125, "za 2 godz. 5 min");

    char b[64];
    rz_clock(10 * 60 + 44, b, sizeof b);   CHECK(strcmp(b, "10:44") == 0, "clock 10:44");
    rz_clock(25 * 60 + 10, b, sizeof b);   CHECK(strcmp(b, "01:10") == 0, "clock po północy");

    rz_duration((20L * 1440 + 13 * 60 + 24) * 60, b, sizeof b);
    CHECK(strcmp(b, "20 dni 13 godz. 24 min") == 0, "duration 20 dni");
    rz_duration((1L * 1440 + 0 * 60 + 5) * 60, b, sizeof b);
    CHECK(strcmp(b, "1 dzień 0 godz. 5 min") == 0, "duration 1 dzień");
    rz_duration((13L * 60 + 24) * 60, b, sizeof b);
    CHECK(strcmp(b, "13 godz. 24 min") == 0, "duration godziny");
    rz_duration(7 * 60, b, sizeof b);
    CHECK(strcmp(b, "7 min") == 0, "duration minuty");

    /* --- angielski i rosyjski --- */
    rz_set_lang(1);
    expect_eta(0, "departing now");   expect_eta(1, "in 1 minute");
    expect_eta(5, "in 5 minutes");    expect_eta(65, "in 1 h 5 min");
    expect_eta(120, "in 2 h");
    rz_duration((1L * 1440 + 2 * 60 + 5) * 60, b, sizeof b);
    CHECK(strcmp(b, "1 day 2 h 5 min") == 0, "duration en 1 day");
    rz_duration((20L * 1440 + 13 * 60 + 24) * 60, b, sizeof b);
    CHECK(strcmp(b, "20 days 13 h 24 min") == 0, "duration en days");
    rz_set_lang(2);
    expect_eta(0, "отправляется сейчас");
    expect_eta(1, "через 1 минуту");   expect_eta(2, "через 2 минуты");
    expect_eta(5, "через 5 минут");    expect_eta(11, "через 11 минут");
    expect_eta(12, "через 12 минут");  expect_eta(14, "через 14 минут");
    expect_eta(21, "через 21 минуту"); expect_eta(22, "через 22 минуты");
    expect_eta(25, "через 25 минут");  expect_eta(60, "через 1 ч");
    expect_eta(65, "через 1 ч 5 мин");
    rz_duration((21L * 1440 + 13 * 60 + 24) * 60, b, sizeof b);
    CHECK(strcmp(b, "21 день 13 ч 24 мин") == 0, "duration ru 21 день");
    rz_duration((3L * 1440 + 0 * 60 + 5) * 60, b, sizeof b);
    CHECK(strcmp(b, "3 дня 0 ч 5 мин") == 0, "duration ru 3 дня");
    rz_duration((11L * 1440) * 60, b, sizeof b);
    CHECK(strcmp(b, "11 дней 0 ч 0 мин") == 0, "duration ru 11 дней");
    rz_set_lang(0);

    CHECK(rz_parse_date("20261231") == 20261231, "parse date");
    CHECK(rz_parse_date("") == 0 && rz_parse_date("2026-12-31") == 0 && rz_parse_date(NULL) == 0, "parse date zły");

    /* --- kalendarz --- */
    int32_t add[] = { 20261121 }, rem[] = { 20261111 };
    RZService svc[2];
    memset(svc, 0, sizeof svc);
    /* 0: pon-pt od 1.10 do 31.12, święto 11.11 wyłączone, sobota 21.11 dodana */
    svc[0].start = 20261001; svc[0].end = 20261231;
    svc[0].days[0] = svc[0].days[1] = svc[0].days[2] = svc[0].days[3] = svc[0].days[4] = 1;
    svc[0].add = add; svc[0].nadd = 1; svc[0].rem = rem; svc[0].nrem = 1;
    /* 1: bez dat (jak pusty calendar.txt) - nigdy nie jedzie w dni tygodnia */
    svc[1].days[0] = 1;

    CHECK(rz_service_runs(&svc[0], 20261023, 4) == 1, "piątek jedzie");
    CHECK(rz_service_runs(&svc[0], 20261024, 5) == 0, "sobota nie jedzie");
    CHECK(rz_service_runs(&svc[0], 20261111, 2) == 0, "11.11 wyjątek: nie jedzie");
    CHECK(rz_service_runs(&svc[0], 20261121, 5) == 1, "21.11 wyjątek: jedzie");
    CHECK(rz_service_runs(&svc[0], 20260930, 2) == 0, "przed początkiem");
    CHECK(rz_service_runs(&svc[0], 20270105, 1) == 0, "po końcu");
    CHECK(rz_service_runs(&svc[1], 20261026, 0) == 0, "brak dat = nie jedzie");

    /* --- wyszukiwanie odjazdów --- */
    /* "dziś" = piątek 23.10.2026, 10:00 (600 min); wczoraj czwartek, jutro sobota */
    int32_t ymd[3] = { 20261022, 20261023, 20261024 };
    int wd[3] = { 3, 4, 5 };
    RZDep deps[] = {
        { 605,  0, 1, 1, 'b' },   /* 10:05 dziś, linia 1 */
        { 617,  0, 2, 1, 'b' },   /* 10:17 */
        { 640,  0, 1, 1, 'b' },   /* 10:40 */
        { 1510, 0, 3, 2, 'b' },   /* 25:10 wczoraj = dziś 01:10 (przeszłość - pominąć o 10:00) */
        { 605,  0, 9, 1, 't' },   /* inny rodzaj - pominąć */
        { 700,  1, 4, 1, 'b' },   /* kalendarz 1 nigdy nie jedzie */
        { 1330, 0, 5, 1, 'b' },   /* 22:10 dziś - poza horyzontem 12 h? 600+720=1320 -> poza */
        { 1510, 0, 6, 2, 'b' },   /* jutro, ale o 25:10 dnia kursowania = pozniej */
    };
    RZNext out[8];
    int n = rz_next(deps, 8, svc, 2, ymd, wd, 600, 720, 'b', out, 5);
    CHECK(n == 3, "3 odjazdy w 12 h");
    CHECK(n >= 1 && out[0].time == 605 && out[0].line == 1, "pierwszy 10:05");
    CHECK(n >= 2 && out[1].time == 617 && out[1].line == 2, "drugi 10:17");
    CHECK(n >= 3 && out[2].time == 640, "trzeci 10:40");

    /* limit 2 zostawia dwa najbliższe */
    n = rz_next(deps, 8, svc, 2, ymd, wd, 600, 720, 'b', out, 2);
    CHECK(n == 2 && out[0].time == 605 && out[1].time == 617, "limit 2");

    /* nocny kurs z wczoraj: 00:30 dziś (wczoraj 24:30) widoczny o 00:10 */
    RZDep night[] = { { 1470, 0, 7, 3, 'b' } };
    n = rz_next(night, 1, svc, 2, ymd, wd, 10, 720, 'b', out, 5);
    CHECK(n == 1 && out[0].time == 30 && out[0].line == 7, "kurs nocny z wczoraj");

    /* wczoraj = sobota: kalendarz 0 nie jedzie, więc kurs nocny znika */
    int wd2[3] = { 5, 6, 0 };
    n = rz_next(night, 1, svc, 2, ymd, wd2, 10, 720, 'b', out, 5);
    CHECK(n == 0, "kurs nocny, gdy wczoraj nie jeździł");

    /* inny rodzaj */
    n = rz_next(deps, 8, svc, 2, ymd, wd, 600, 720, 't', out, 5);
    CHECK(n == 1 && out[0].line == 9, "tramwaj");
    n = rz_next(deps, 8, svc, 2, ymd, wd, 600, 720, 'm', out, 5);
    CHECK(n == 0, "brak metra");

    /* pociągi: doba do przodu */
    n = rz_next(deps, 8, svc, 2, ymd, wd, 600, 1440, 'b', out, 10);
    CHECK(n == 6, "doba: 3 poranne + 22:10 + dwa kursy 25:10 dnia dzisiejszego");
    CHECK(n == 6 && out[3].time == 1330 && out[4].time == 1510 && out[5].time == 1510, "doba: kolejnosc");


    /* --- cały dzień (rz_list) --- */
    /* ten sam piątek 23.10.2026: okno 0..1440 */
    n = rz_list(deps, 8, svc, 2, ymd, wd, 0, 1440, 'b', NULL, 0);
    CHECK(n == 6, "rz_list zlicza: dwa kursy nocne z wczoraj (01:10) + 4 odjazdy dziś");
    {
        RZNext all[16];
        n = rz_list(deps, 8, svc, 2, ymd, wd, 0, 1440, 'b', all, 16);
        /* oczekiwane: dwa kursy nocne 01:10 (linie 3 i 6, wczoraj 25:10), 10:05, 10:17, 10:40, 22:10;
           kursy 25:10 z dziś wchodzą dopiero do jutrzejszego okna (>= 1440) */
        CHECK(n == 6, "rz_list: 6 odjazdów w dobie 0..1440");
        CHECK(n == 6 && all[0].time == 70 && all[0].line == 3 && all[1].time == 70 && all[1].line == 6, "rz_list: najpierw kursy nocne 01:10, po linii");
        CHECK(n == 6 && all[2].time == 605 && all[3].time == 617 && all[4].time == 640, "rz_list: poranne w kolejności");
        CHECK(n == 6 && all[5].time == 1330, "rz_list: ostatni 22:10");
        /* okno od 10:10 */
        n = rz_list(deps, 8, svc, 2, ymd, wd, 610, 1440, 'b', all, 16);
        CHECK(n == 3 && all[0].time == 617 && all[2].time == 1330, "rz_list: okno od 10:10");
        /* obcięcie do cap */
        n = rz_list(deps, 8, svc, 2, ymd, wd, 0, 1440, 'b', all, 2);
        CHECK(n == 2, "rz_list: cap 2");
        /* inny rodzaj i puste okno */
        n = rz_list(deps, 8, svc, 2, ymd, wd, 0, 1440, 't', all, 16);
        CHECK(n == 1 && all[0].line == 9, "rz_list: tramwaj");
        n = rz_list(deps, 8, svc, 2, ymd, wd, 700, 700, 'b', all, 16);
        CHECK(n == 0, "rz_list: puste okno");
        /* sobota: kalendarz 0 nie jedzie, zostają tylko kursy nocne z piątku (25:10 = sobota 01:10) */
        {
            int32_t ymd3[3] = { 20261023, 20261024, 20261025 };
            int wd3[3] = { 4, 5, 6 };
            n = rz_list(deps, 8, svc, 2, ymd3, wd3, 0, 1440, 'b', all, 16);
            CHECK(n == 2 && all[0].time == 70 && all[1].time == 70, "rz_list: sobota tylko kursy nocne z piątku");
        }
    }

    /* duża doba: 1000 odjazdów w losowej kolejności musi wyjść posortowane */
    {
        static RZDep many[1000];
        static RZNext big[1100];
        unsigned seed = 12345u;
        int i, sorted = 1;
        for (i = 0; i < 1000; i++) {
            seed = seed * 1103515245u + 12345u;
            many[i].minute = (int32_t)((seed >> 8) % 1400);
            many[i].svc = 0;
            many[i].line = (uint16_t)(i % 7);
            many[i].head = 0;
            many[i].kind = 'b';
        }
        n = rz_list(many, 1000, svc, 2, ymd, wd, 0, 1440, 'b', NULL, 0);
        CHECK(n == 1000, "rz_list: zliczono 1000");
        n = rz_list(many, 1000, svc, 2, ymd, wd, 0, 1440, 'b', big, 1100);
        for (i = 1; i < n; i++) if (big[i - 1].time > big[i].time) sorted = 0;
        CHECK(n == 1000 && sorted, "rz_list: 1000 odjazdów posortowane");
    }

    if (fails) { printf("\n%d błędów\n", fails); return 1; }
    printf("OK: wszystkie testy logiki przeszły\n");
    return 0;
}

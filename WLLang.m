#import "WLLang.h"
#import "WLStore.h"

NSString *const WLAppearanceDidChangeNotification = @"WLAppearanceDidChangeNotification";

static NSInteger gLang = -1;

static NSInteger WLAutoLanguage(void)
{
    NSArray *prefs = [NSLocale preferredLanguages];
    NSString *first = [prefs count] ? [prefs objectAtIndex:0] : @"pl";
    if ([first hasPrefix:@"pl"]) return 0;
    if ([first hasPrefix:@"ru"]) return 2;
    return 1;
}

NSInteger WLLanguageSetting(void) { return [WLStore shared].languageSetting; }

NSInteger WLLanguage(void)
{
    if (gLang < 0) {
        NSInteger s = WLLanguageSetting();
        gLang = (s >= 1 && s <= 3) ? s - 1 : WLAutoLanguage();
    }
    return gLang;
}

void WLSetLanguageSetting(NSInteger setting)
{
    if (setting < 0 || setting > 3) setting = 0;
    [WLStore shared].languageSetting = setting;
    gLang = -1;
    [[NSNotificationCenter defaultCenter] postNotificationName:WLAppearanceDidChangeNotification object:nil];
}

NSString *WLLanguageSettingName(NSInteger setting)
{
    switch (setting) {
        case 1: return @"Polski";
        case 2: return @"English";
        case 3: return @"Русский";
        default: return GL(@"Automatycznie");
    }
}

NSLocale *WLLocale(void)
{
    static NSLocale *cache[3];
    NSInteger l = WLLanguage();
    if (!cache[l]) {
        NSString *ids[3] = { @"pl_PL", @"en_GB", @"ru_RU" };
        cache[l] = [[NSLocale alloc] initWithLocaleIdentifier:ids[l]];
    }
    return cache[l];
}

/* polski | angielski | rosyjski */
static const struct { NSString *pl, *en, *ru; } kStrings[] = {
    { @"Przelicznik", @"Converter", @"Конвертер" },
    { @"Kursy", @"Rates", @"Курсы" },
    { @"Ustawienia", @"Settings", @"Настройки" },
    { @"Wygląd", @"Appearance", @"Оформление" },
    { @"Dane", @"Data", @"Данные" },
    { @"O aplikacji", @"About", @"О программе" },
    { @"Język", @"Language", @"Язык" },
    { @"Motyw", @"Theme", @"Тема" },
    { @"Automatycznie", @"Automatic", @"Автоматически" },
    { @"Anuluj", @"Cancel", @"Отмена" },
    { @"Gotowe", @"Done", @"Готово" },
    { @"Odśwież", @"Refresh", @"Обновить" },
    { @"Waluta", @"Currency", @"Валюта" },
    { @"Waluta bazowa", @"Base currency", @"Базовая валюта" },
    { @"Szukaj waluty", @"Search currency", @"Поиск валюты" },
    { @"Ulubione", @"Favorites", @"Избранное" },
    { @"Ulubione waluty", @"Favorite currencies", @"Избранные валюты" },
    { @"Wszystkie waluty", @"All currencies", @"Все валюты" },
    { @"Wyniki", @"Results", @"Результаты" },
    { @"Wynik skopiowany", @"Result copied", @"Результат скопирован" },
    { @"Pobieram kursy…", @"Fetching rates…", @"Загрузка курсов…" },
    { @"Brak kursów. Połącz się z internetem i dotknij Odśwież.", @"No rates yet. Connect to the internet and tap Refresh.", @"Курсов пока нет. Подключитесь к интернету и нажмите «Обновить»." },
    { @"Brak kursów — dotknij, aby pobrać", @"No rates — tap to download", @"Курсов нет — нажмите, чтобы загрузить" },
    { @"Kursy z %@ · %@", @"Rates from %@ · %@", @"Курсы на %@ · %@" },
    { @"Kursy mogą być nieaktualne", @"Rates may be out of date", @"Курсы могут быть устаревшими" },
    { @"Kursy są aktualne (pobrane przed chwilą)", @"Rates are up to date (just downloaded)", @"Курсы актуальны (только что загружены)" },
    { @"Brak połączenia z internetem.", @"No internet connection.", @"Нет подключения к интернету." },
    { @"Nie udało się pobrać kursów.", @"Could not download the rates.", @"Не удалось загрузить курсы." },
    { @"Serwer chwilowo odmawia kolejnych zapytań. Spróbuj za kilka minut.", @"The server is temporarily refusing requests. Try again in a few minutes.", @"Сервер временно отклоняет запросы. Повторите через несколько минут." },
    { @"Nie udało się połączyć bezpiecznie (HTTPS). Na iOS 6 potrzebna jest poprawka SSL/TLS z Cydii.", @"Could not connect securely (HTTPS). iOS 6 needs an SSL/TLS fix from Cydia.", @"Не удалось установить защищённое соединение (HTTPS). Для iOS 6 нужен патч SSL/TLS из Cydia." },
    { @"Źródło kursów", @"Rates source", @"Источник курсов" },
    { @"NBP (Narodowy Bank Polski)", @"NBP (National Bank of Poland)", @"НБП (Национальный банк Польши)" },
    { @"Odśwież kursy teraz", @"Refresh rates now", @"Обновить курсы сейчас" },
    { @"Ostatnio pobrano: %@ · %@ — dotknij, aby odświeżyć", @"Last downloaded: %@ · %@ — tap to refresh", @"Последняя загрузка: %@ · %@ — нажмите, чтобы обновить" },
    { @"Przywróć domyślne ulubione", @"Restore default favorites", @"Вернуть избранное по умолчанию" },
    { @"EUR, USD, GBP, CHF, CZK, UAH, NOK, SEK, JPY", @"EUR, USD, GBP, CHF, CZK, UAH, NOK, SEK, JPY", @"EUR, USD, GBP, CHF, CZK, UAH, NOK, SEK, JPY" },
    { @"Pliki aplikacji", @"App files", @"Файлы программы" },
    { @"waluty.json (ustawienia) i kursy.txt (zapisane kursy) są w iTunes → Aplikacje → Udostępnianie plików", @"waluty.json (settings) and kursy.txt (saved rates) are in iTunes → Apps → File Sharing", @"waluty.json (настройки) и kursy.txt (сохранённые курсы) находятся в iTunes → Программы → Общие файлы" },
    { @"Usuń wszystkie dane", @"Delete all data", @"Удалить все данные" },
    { @"Ustawienia, ulubione i zapisane kursy", @"Settings, favorites and saved rates", @"Настройки, избранное и сохранённые курсы" },
    { @"Usunąć ustawienia, ulubione i zapisane kursy? Tego nie da się cofnąć.", @"Delete settings, favorites and saved rates? This cannot be undone.", @"Удалить настройки, избранное и сохранённые курсы? Это нельзя отменить." },
    { @"Usuń wszystko", @"Delete everything", @"Удалить всё" },
    { @"Wersja", @"Version", @"Версия" },
    { @"Autor", @"Author", @"Автор" },
    { @"Narodowy Bank Polski", @"National Bank of Poland", @"Национальный банк Польши" },
    { @"Główne źródło kursów (open.er-api.com) — dotknij, aby otworzyć stronę", @"Main source of rates (open.er-api.com) — tap to open the website", @"Основной источник курсов (open.er-api.com) — нажмите, чтобы открыть сайт" },
    { @"Zapasowe źródło kursów (tabela A kursów średnich) — dotknij, aby otworzyć stronę", @"Backup source of rates (table A of average rates) — tap to open the website", @"Резервный источник курсов (таблица A средних курсов) — нажмите, чтобы открыть сайт" },
    { @"Uwaga", @"Note", @"Важно" },
    { @"Kursy są orientacyjne i nie służą do rozliczeń. Kantory i banki stosują własne kursy.", @"Rates are indicative only and not for settlements. Exchange offices and banks use their own rates.", @"Курсы ориентировочные и не предназначены для расчётов. Обменные пункты и банки применяют свои курсы." },
    { @"Kursy orientacyjne, nie służą do rozliczeń. Kantory i banki stosują własne kursy.", @"Indicative rates, not for settlements. Exchange offices and banks use their own rates.", @"Курсы ориентировочные, не для расчётов. Обменные пункты и банки применяют свои курсы." },
    { @"Kursy średnie Narodowego Banku Polskiego. Kursy są orientacyjne i nie służą do rozliczeń.", @"Average rates of the National Bank of Poland. Rates are indicative and not for settlements.", @"Средние курсы Национального банка Польши. Курсы ориентировочные и не для расчётов." },
    { @"Grafit", @"Graphite", @"Графит" },
    { @"Błękit", @"Blue", @"Синий" },
    { @"Czerwień", @"Red", @"Красный" },
    { @"Zieleń", @"Green", @"Зелёный" },
    { @"Fiolet", @"Purple", @"Фиолетовый" },
    { @"Srebro", @"Silver", @"Серебро" },
};

NSString *GL(NSString *pl)
{
    NSInteger l = WLLanguage();
    if (l == 0 || !pl) return pl;
    static NSDictionary *tables[2];
    if (!tables[l - 1]) {
        NSMutableDictionary *d = [NSMutableDictionary dictionary];
        for (size_t i = 0; i < sizeof(kStrings) / sizeof(kStrings[0]); i++) {
            [d setObject:(l == 1 ? kStrings[i].en : kStrings[i].ru) forKey:kStrings[i].pl];
        }
        tables[l - 1] = d;
    }
    NSString *t = [tables[l - 1] objectForKey:pl];
    return t ? t : pl;
}

#import <Foundation/Foundation.h>

/* Języki: polski (podstawowy), angielski, rosyjski.
   W kodzie wszystkie napisy są po polsku, a GL() podmienia je na wybrany język. */

extern NSString *const WLAppearanceDidChangeNotification;   /* zmiana języka albo motywu */

/* Język faktycznie używany: 0 polski, 1 angielski, 2 rosyjski. */
NSInteger WLLanguage(void);
/* Ustawienie zapisane w pliku: 0 automatycznie (wg telefonu), 1 polski, 2 English, 3 Русский. */
NSInteger WLLanguageSetting(void);
void WLSetLanguageSetting(NSInteger setting);
NSString *WLLanguageSettingName(NSInteger setting);          /* nazwa w jej własnym języku */
NSLocale *WLLocale(void);

/* Tłumaczy polski napis; gdy brak tłumaczenia, zwraca go bez zmian. */
NSString *GL(NSString *pl);

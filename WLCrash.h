#import <Foundation/Foundation.h>

/* Prosta diagnostyka: aplikacja zapisuje w Documents ostatni "krok" oraz treść nieobsłużonego wyjątku.
   Przy następnym uruchomieniu pokazuje to w okienku, żeby można było zrobić zdjęcie ekranu. */

void WLCrashInstall(void);
void WLCrumb(NSString *step);                 /* zapamiętuje, co aplikacja właśnie robi */
void WLCrumbCleanExit(void);                  /* zwykłe wyjście do tła: zaznacza, że wszystko było w porządku */
NSString *WLTakeLastRunReport(void);          /* tekst o poprzednim, nieudanym uruchomieniu albo nil; czyści pliki */

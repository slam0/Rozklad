#import <Foundation/Foundation.h>

/* Języki aplikacji: wybór zapamiętany w telefonie.
   0 = automatycznie (jak system), 1 = polski, 2 = angielski, 3 = rosyjski. */
extern NSString *const RZLanguageDidChangeNotification;

NSInteger RZLangChoice(void);          /* zapisany wybór 0..3 */
void RZLangSet(NSInteger choice);      /* zapisuje, przełącza język i wysyła powiadomienie */
void RZLangApply(void);                /* ustawia język tekstów w C (wołać przy starcie) */
NSInteger RZLangCurrent(void);         /* 0 polski, 1 angielski, 2 rosyjski (po rozpoznaniu "automatycznie") */
NSString *RZLangCode(void);            /* "pl", "en" lub "ru" */

/* Tłumaczenie tekstu napisanego po polsku. Polski zwraca bez zmian, brakujący wpis też. */
NSString *RZL(NSString *polish);

#import <Foundation/Foundation.h>

/* Kursy walut: pobieranie z internetu (open.er-api.com, a gdy nie działa, NBP), zapis w telefonie
   (Documents/kursy.txt) i przeliczanie. Logika odczytu i liczenia jest w wl_core.c. */

extern NSString *const WLRatesDidChangeNotification;   /* nowe kursy, początek albo koniec pobierania */

enum { WLSourceNone = 0, WLSourceERAPI = 1, WLSourceNBP = 2 };

@interface WLRates : NSObject

+ (WLRates *)shared;

@property (nonatomic, readonly) BOOL loading;
@property (nonatomic, readonly, copy) NSString *errorText;   /* nil, gdy ostatnie pobieranie się udało */

- (BOOL)hasRates;
- (NSArray *)codes;                                        /* kody walut alfabetycznie */
- (BOOL)hasCode:(NSString *)code;
/* ile "to" dostajesz za "amount" waluty "from"; NO, gdy brak kursu */
- (BOOL)convert:(double)amount from:(NSString *)from to:(NSString *)to result:(double *)result;

- (NSInteger)source;                                       /* WLSource... */
- (NSString *)sourceName;                                  /* "open.er-api.com" albo "NBP" */
- (NSDate *)updatedDate;                                   /* na kiedy są kursy; nil, gdy nieznane */
- (NSDate *)fetchedDate;                                   /* kiedy pobrano; nil, gdy nieznane */
- (NSInteger)fetchedAgeDays;                               /* -1, gdy nieznane */

- (void)refreshIfNeeded;                                   /* po starcie i po powrocie do aplikacji: gdy kursy starsze niż godzina */
- (BOOL)refreshNow;                                        /* NO, gdy właśnie trwa pobieranie albo kursy są sprzed minuty */
- (void)clear;                                             /* usuwa zapisane kursy */

@end

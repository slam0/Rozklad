#import <Foundation/Foundation.h>

/* Ustawienia i stan aplikacji w jednym pliku Documents/waluty.json.
   Kursy walut są osobno, w WLRates (plik Documents/kursy.txt). */

@interface WLStore : NSObject

+ (WLStore *)shared;

@property (nonatomic) NSInteger languageSetting;        /* 0 auto, 1 pl, 2 en, 3 ru */
@property (nonatomic) NSInteger themeIndex;
@property (nonatomic) NSInteger sourceSetting;          /* 0 automatycznie, 1 open.er-api.com, 2 NBP */
@property (nonatomic, copy) NSString *fromCode;         /* przelicznik: z waluty */
@property (nonatomic, copy) NSString *toCode;           /* ...na walutę */
@property (nonatomic, copy) NSString *amountText;       /* wpisana kwota (tekst, tak jak w polu) */
@property (nonatomic, copy) NSString *ratesBase;        /* waluta bazowa na liście kursów */
@property (nonatomic, copy) NSArray *favorites;         /* kody walut, w kolejności dodania */

- (BOOL)isFavorite:(NSString *)code;
- (void)toggleFavorite:(NSString *)code;
- (void)resetFavorites;

- (void)save;
- (void)clearAll;                                       /* ustawienia wracają do domyślnych (kursy czyści WLRates) */

@end

#import <UIKit/UIKit.h>

/* Ekran wyboru dnia, na który pokazujemy rozkład przystanku. */
@interface RZDayController : UIViewController

/* Wołane po każdej zmianie dnia: nil oznacza "dzisiaj". */
@property (nonatomic, copy) void (^onChange)(NSDate *day);

/*
 * day - aktualnie wybrany dzień (nil = dzisiaj)
 * lastDay - ostatni dzień, na który telefon ma rozkład (nil = bez ograniczenia)
 */
- (id)initWithDay:(NSDate *)day lastDay:(NSDate *)lastDay;

/* Ten sam dzień, godzina 12:00 (bezpieczne przy zmianie czasu letniego) */
+ (NSDate *)noonOf:(NSDate *)date;
/* Czy to ten sam dzień kalendarzowy */
+ (BOOL)isSameDay:(NSDate *)a as:(NSDate *)b;
/* Napis w języku aplikacji: krótki "sob. 25.10" albo długi "sobota, 25 października 2026" */
+ (NSString *)stringForDay:(NSDate *)day long:(BOOL)isLong;

@end

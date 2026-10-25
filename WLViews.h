#import <UIKit/UIKit.h>

/* Wspólne widoki: komórki z połyskiem, nagłówki sekcji, wykres, pole liczby. */

@interface WLCell : UITableViewCell          /* podtytuł + błyszczące tło */
+ (WLCell *)cellForTable:(UITableView *)table identifier:(NSString *)ident;
@end

@interface WLSectionHeader : UIView
- (id)initWithTitle:(NSString *)title right:(NSString *)right;
@end

UIView *WLHeaderForTitle(NSString *title, NSString *right);

UIToolbar *WLKeyboardToolbar(id target, SEL doneAction);
UIImage *WLCheckImage(BOOL on);
UIImage *WLFieldImage(void);                    /* wpuszczone pole z tłem pod kwotę */
/* Otwiera adres w przeglądarce. Klasa NSURL jest wyszukiwana dopiero w czasie działania (patrz uwaga w WLRates.m). */
void WLOpenURL(NSString *url);
UIImage *WLStarImage(BOOL on);                 /* ulubione */
UIImage *WLTriangleImage(void);                 /* strzałka rozwijania na przycisku */
UIImage *WLSwapImage(void);                     /* zamiana walut */

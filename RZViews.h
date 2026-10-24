#import <UIKit/UIKit.h>

@class RZDeparture;

/* ---- Motywy ---- */
extern NSString *const RZThemeDidChangeNotification;
NSUInteger RZThemeCount(void);
NSInteger RZThemeIndex(void);                   /* aktualny motyw (zapamiętany w telefonie) */
void RZThemeSet(NSInteger index);               /* zapisuje i wysyła RZThemeDidChangeNotification */
NSString *RZThemeName(NSInteger index);
UIImage *RZThemeSwatch(NSInteger index);        /* miniaturka motywu do listy w ustawieniach */

UIColor *RZBrownColor(void);
UIColor *RZLinenColor(void);
UIColor *RZPaperColor(void);        /* tło list w aktualnym motywie */
UIColor *RZInkColor(void);          /* kolor nagłówków sekcji */
UIColor *RZSubtleColor(void);       /* szary tekst pomocniczy */
UIColor *RZCellTextColor(void);     /* tekst w komórkach */
UIColor *RZCellBackgroundColor(void);
UIColor *RZAccentColor(void);       /* czerwony napis "za 4 min" */
UIImage *RZTabIcon(char kind);      /* b t p m oraz s = ustawienia (zębatka) */
UIImage *RZStarIcon(BOOL filled);

/* Tło, linie i kolory tabeli w aktualnym motywie */
void RZStyleTable(UITableView *table);
/* Dopasowuje komórkę (tło) do motywu; wołać w willDisplayCell */
void RZStyleCell(UITableViewCell *cell);

/* Wygląd skórzany jak w Find My Friends */
void RZStyleNavigationBar(UINavigationBar *bar);
void RZStyleTabBar(UITabBar *bar);
void RZStyleTabItem(UITabBarItem *item, char kind);

/* Nagłówek i stopka sekcji tabeli: ciemny napis na jasnym tle */
UIView *RZSectionHeaderView(NSString *text);
UIView *RZSectionFooterView(NSString *text);
/* Nagłówek przystanku z gwiazdką ulubionych po prawej (przycisk dostaje tag i akcję) */
UIView *RZStopHeaderView(NSString *text, BOOL favorite, id target, SEL action, NSInteger tag);

/* Czerwony/niebieski/zielony błyszczący znaczek z numerem linii */
@interface RZBadge : UIView
@property (nonatomic, readonly) UILabel *label;
- (void)setLine:(NSString *)line kind:(char)kind;
@end

/* Zwykły wiersz odjazdu: [linia] kierunek ........ 10:56 / za 17 minut */
@interface RZDepartureCell : UITableViewCell
- (void)setDeparture:(RZDeparture *)dep nowMinutes:(NSInteger)now;
/* showCountdown = NO: bez napisu "za 5 minut" (rozkład na inny dzień niż dzisiaj) */
- (void)setDeparture:(RZDeparture *)dep nowMinutes:(NSInteger)now showCountdown:(BOOL)show;
@end

/* Wiersz listy przystanków: znaczek najbliższego odjazdu, nazwa, "→ kierunek · za 4 min" i gwiazdka */
@interface RZStopCell : UITableViewCell
@property (nonatomic, readonly) UIButton *star;
- (void)setTitle:(NSString *)title departure:(RZDeparture *)dep nowMinutes:(NSInteger)now favorite:(BOOL)favorite;
@end

/* Duży "bilet" z najbliższym odjazdem */
@interface RZTicketCell : UITableViewCell
- (void)setDeparture:(RZDeparture *)dep stopName:(NSString *)stop nowMinutes:(NSInteger)now;
/* Podmienia tylko napis odliczania (co sekundę), bez przeładowania tabeli */
- (void)setCountdownText:(NSString *)text;
@end

/* Ruchomy pasek z napisem */
@interface RZMarquee : UIView
- (void)setText:(NSString *)text warning:(BOOL)warning;
- (void)restart;
@end

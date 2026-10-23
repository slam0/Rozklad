#import <UIKit/UIKit.h>

@class RZDeparture;

UIColor *RZBrownColor(void);
UIColor *RZLinenColor(void);
UIColor *RZPaperColor(void);        /* jasne papierowe tło list */
UIColor *RZInkColor(void);          /* ciemnobrązowy kolor napisów na papierze */
UIImage *RZTabIcon(char kind);

/* Wygląd skórzany jak w Find My Friends */
void RZStyleNavigationBar(UINavigationBar *bar);
void RZStyleTabBar(UITabBar *bar);
void RZStyleTabItem(UITabBarItem *item, char kind);

/* Nagłówek i stopka sekcji tabeli: ciemny napis na jasnym tle */
UIView *RZSectionHeaderView(NSString *text);
UIView *RZSectionFooterView(NSString *text);

/* Czerwony/niebieski/zielony błyszczący znaczek z numerem linii */
@interface RZBadge : UIView
@property (nonatomic, readonly) UILabel *label;
- (void)setLine:(NSString *)line kind:(char)kind;
@end

/* Zwykły wiersz odjazdu: [linia] kierunek ........ 10:56 / za 17 minut */
@interface RZDepartureCell : UITableViewCell
- (void)setDeparture:(RZDeparture *)dep nowMinutes:(NSInteger)now;
@end

/* Duży "bilet" z najbliższym odjazdem */
@interface RZTicketCell : UITableViewCell
- (void)setDeparture:(RZDeparture *)dep stopName:(NSString *)stop nowMinutes:(NSInteger)now;
@end

/* Ruchomy pasek z napisem */
@interface RZMarquee : UIView
- (void)setText:(NSString *)text warning:(BOOL)warning;
- (void)restart;
@end

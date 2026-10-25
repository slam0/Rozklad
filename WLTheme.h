#import <UIKit/UIKit.h>

/* Wygląd w stylu iOS 6 ("grafit z połyskiem") z kilkoma motywami kolorystycznymi
   oraz drobne funkcje pomocnicze do formatowania liczb, dat i jednostek. */

/* ---- paleta bieżącego motywu ---- */
typedef struct {
    int accent[3], accentGelT[3], accentGelB[3], accentGelBorder[3];
    int bg[3], bgHi[3], bgLo[3];
    int barT1[3], barT2[3], barB1[3], barB2[3], barTint[3];
    int cellT1[3], cellT2[3], cellB1[3], cellB2[3];
    int selT1[3], selT2[3], selB1[3], selB2[3];
    int text[3], subtle[3], tabOff[3], tabOn[3];
    int hdrT[3], hdrB[3], hdrTitle[3], hdrRight[3];
    int fieldT[3], fieldB[3], fieldText[3];
    int tileT[3], tileB[3], tileText[3];
    int panelT[3], panelB[3], grid[3];
    int sep[3], neutT[3], neutB[3], neutBorder[3];
    int shadow[3], chrome[3], danger[3];
    float gridAlpha, shadowAlpha, shadowDY, cellHiAlpha, cellLoAlpha;
    int light;
} WLPalette;

const WLPalette *WLP(void);
UIColor *WLRGB(const int *rgb, CGFloat alpha);

/* ---- motywy ---- */
NSInteger WLThemeCount(void);
NSInteger WLCurrentTheme(void);
void WLSetTheme(NSInteger index);               /* zapisuje i ogłasza WLAppearanceDidChangeNotification */
NSString *WLThemeName(NSInteger index);         /* przetłumaczona nazwa */
UIImage *WLThemeSwatch(NSInteger index);        /* mała błyszcząca próbka koloru */

UIColor *WLBackgroundColor(void);       /* teksturowane tło tabel */
UIColor *WLTextColor(void);
UIColor *WLSubtleColor(void);
UIColor *WLAccentColor(void);
UIColor *WLGreenColor(void);
void WLStyleShadow(UILabel *label);     /* cień tekstu pasujący do motywu */

void WLStyleNavigationBar(UINavigationBar *bar);
void WLStyleTabBar(UITabBar *bar);
void WLStyleTabItem(UITabBarItem *item, int kind);   /* 0 przelicznik, 1 kursy, 3 ustawienia */
void WLStyleSearchBar(UISearchBar *bar);
UIImage *WLTabIcon(int kind);
void WLStyleTable(UITableView *table);

/* styl: 0 kolor motywu, 1 neutralny, 2 czerwony, 3 zielony */
UIImage *WLGelImage(int style);
UIButton *WLGelButton(NSString *title, int style, CGRect frame);
UIBarButtonItem *WLBarButton(NSString *title, id target, SEL action);

/* formatowanie liczb (separatory wg języka) */
void WLNumberSeparators(char *dec, char *group);
NSString *WLFormatNumber(double v, int minDec, int maxDec);
NSString *WLMoneyString(double v);                   /* 1 234,56 */
NSString *WLRateString(double v);                    /* 4,3000 */
NSString *WLEditNumber(double v);                    /* do pola edycji, bez grupowania */
double WLParseNumber(NSString *s);                   /* -1 gdy nie da się odczytać */
NSString *WLDateString(double ts);                   /* 21 paź 2024 */
NSString *WLDateTimeString(double ts);

#import "WLSettingsController.h"
#import "WLStore.h"
#import "WLRates.h"
#import "WLTheme.h"
#import "WLLang.h"
#import "WLViews.h"

/* ptaszek w kolorze motywu (systemowy jest ciemnoniebieski i na grafitowym tle słabo widać) */
static UIImage *WLTickImage(void)
{
    CGFloat s = 22.0f;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(s, s), NO, 0.0f);
    UIBezierPath *p = [UIBezierPath bezierPath];
    [p moveToPoint:CGPointMake(3, 11.5f)];
    [p addLineToPoint:CGPointMake(8.5f, 17)];
    [p addLineToPoint:CGPointMake(19, 5)];
    p.lineWidth = 3.6f;
    p.lineCapStyle = kCGLineCapRound;
    p.lineJoinStyle = kCGLineJoinRound;
    [WLAccentColor() setStroke];
    [p stroke];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

@implementation WLChoiceController
{
    UITableView *_table;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = WLBackgroundColor();
    _table = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _table.dataSource = self;
    _table.delegate = self;
    _table.rowHeight = 52;
    WLStyleTable(_table);
    [self.view addSubview:_table];
}

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return (NSInteger)[self.titles count]; }

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip
{
    WLCell *c = [WLCell cellForTable:t identifier:@"choice"];
    c.textLabel.text = [self.titles objectAtIndex:(NSUInteger)ip.row];
    c.detailTextLabel.text = nil;
    c.imageView.image = ip.row < (NSInteger)[self.images count] ? [self.images objectAtIndex:(NSUInteger)ip.row] : nil;
    c.accessoryView = ip.row == self.selected ? [[UIImageView alloc] initWithImage:WLTickImage()] : nil;
    return c;
}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip
{
    [t deselectRowAtIndexPath:ip animated:YES];
    if (ip.row == self.selected) return;
    self.selected = ip.row;
    [t reloadData];
    if (self.onChoose) self.onChoose(ip.row);
}

@end

/* ---------------------------------------------------------------------- */

@interface WLSettingsController ()
{
    UITableView *_table;
}
@end

@implementation WLSettingsController

- (id)init
{
    if ((self = [super init])) self.title = GL(@"Ustawienia");
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = WLBackgroundColor();
    _table = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _table.dataSource = self;
    _table.delegate = self;
    _table.rowHeight = 56;
    WLStyleTable(_table);
    [self.view addSubview:_table];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ratesChanged) name:WLRatesDidChangeNotification object:nil];
}

- (void)ratesChanged { if (self.isViewLoaded) [_table reloadData]; }
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [_table reloadData]; }

static NSString *SourceSettingName(NSInteger s)
{
    if (s == 1) return @"open.er-api.com";
    if (s == 2) return GL(@"NBP (Narodowy Bank Polski)");
    return GL(@"Automatycznie");
}

/* sekcje: 0 Wygląd, 1 Kursy, 2 Dane, 3 O aplikacji */
- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return 4; }

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s
{
    return s == 0 ? 2 : (s == 1 ? 3 : (s == 2 ? 2 : 5));
}

- (CGFloat)tableView:(UITableView *)t heightForHeaderInSection:(NSInteger)s { return 26; }

- (CGFloat)tableView:(UITableView *)t heightForRowAtIndexPath:(NSIndexPath *)ip
{
    BOOL tall = (ip.section == 1 && ip.row >= 1) || (ip.section == 2 && ip.row == 0) || (ip.section == 3 && ip.row >= 2);
    return tall ? 68 : 52;
}

- (UIView *)tableView:(UITableView *)t viewForHeaderInSection:(NSInteger)s
{
    NSArray *n = [NSArray arrayWithObjects:@"Wygląd", @"Kursy", @"Dane", @"O aplikacji", nil];
    return WLHeaderForTitle(GL([n objectAtIndex:(NSUInteger)s]), nil);
}

- (NSString *)refreshDetail
{
    WLRates *r = [WLRates shared];
    if (r.loading) return GL(@"Pobieram kursy…");
    if (![r hasRates]) return r.errorText ? r.errorText : GL(@"Brak kursów — dotknij, aby pobrać");
    NSDate *f = [r fetchedDate];
    NSString *when = f ? WLDateTimeString([f timeIntervalSince1970]) : @"?";
    return [NSString stringWithFormat:GL(@"Ostatnio pobrano: %@ · %@ — dotknij, aby odświeżyć"), when, [r sourceName]];
}

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip
{
    WLCell *c = [WLCell cellForTable:t identifier:@"s"];
    c.accessoryType = UITableViewCellAccessoryNone;
    c.accessoryView = nil;
    c.imageView.image = nil;
    c.selectionStyle = UITableViewCellSelectionStyleBlue;
    c.textLabel.textColor = WLTextColor();
    c.detailTextLabel.numberOfLines = 2;
    WLStore *st = [WLStore shared];
    if (ip.section == 0) {
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        if (ip.row == 0) {
            c.textLabel.text = GL(@"Język");
            c.detailTextLabel.text = WLLanguageSettingName(WLLanguageSetting());
        } else {
            c.textLabel.text = GL(@"Motyw");
            c.detailTextLabel.text = WLThemeName(WLCurrentTheme());
            c.imageView.image = WLThemeSwatch(WLCurrentTheme());
        }
    } else if (ip.section == 1) {
        if (ip.row == 0) {
            c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            c.textLabel.text = GL(@"Źródło kursów");
            c.detailTextLabel.text = SourceSettingName(st.sourceSetting);
        } else if (ip.row == 1) {
            c.textLabel.text = GL(@"Odśwież kursy teraz");
            c.detailTextLabel.text = [self refreshDetail];
        } else {
            c.textLabel.text = GL(@"Przywróć domyślne ulubione");
            c.detailTextLabel.text = GL(@"EUR, USD, GBP, CHF, CZK, UAH, NOK, SEK, JPY");
        }
    } else if (ip.section == 2) {
        if (ip.row == 0) {
            c.textLabel.text = GL(@"Pliki aplikacji");
            c.detailTextLabel.text = GL(@"waluty.json (ustawienia) i kursy.txt (zapisane kursy) są w iTunes → Aplikacje → Udostępnianie plików");
            c.selectionStyle = UITableViewCellSelectionStyleNone;
        } else {
            c.textLabel.text = GL(@"Usuń wszystkie dane");
            c.textLabel.textColor = WLRGB(WLP()->danger, 1);
            c.detailTextLabel.text = GL(@"Ustawienia, ulubione i zapisane kursy");
        }
    } else {
        switch (ip.row) {
            case 0: c.selectionStyle = UITableViewCellSelectionStyleNone; c.textLabel.text = GL(@"Wersja"); c.detailTextLabel.text = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"]; break;
            case 1: c.selectionStyle = UITableViewCellSelectionStyleNone; c.textLabel.text = GL(@"Autor"); c.detailTextLabel.text = @"nazar0vsky-slam0"; break;
            case 2: c.textLabel.text = @"Rates By Exchange Rate API"; c.detailTextLabel.text = GL(@"Główne źródło kursów (open.er-api.com) — dotknij, aby otworzyć stronę"); break;
            case 3: c.textLabel.text = GL(@"Narodowy Bank Polski"); c.detailTextLabel.text = GL(@"Zapasowe źródło kursów (tabela A kursów średnich) — dotknij, aby otworzyć stronę"); break;
            default: c.selectionStyle = UITableViewCellSelectionStyleNone; c.textLabel.text = GL(@"Uwaga"); c.detailTextLabel.text = GL(@"Kursy są orientacyjne i nie służą do rozliczeń. Kantory i banki stosują własne kursy."); break;
        }
    }
    return c;
}

- (void)pushChoice:(NSArray *)titles images:(NSArray *)images selected:(NSInteger)sel title:(NSString *)title handler:(void (^)(NSInteger))handler
{
    WLChoiceController *cc = [[WLChoiceController alloc] init];
    cc.title = title;
    cc.titles = titles;
    cc.images = images;
    cc.selected = sel;
    cc.onChoose = handler;
    [self.navigationController pushViewController:cc animated:YES];
}

- (void)openURLString:(NSString *)u { WLOpenURL(u); }

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip
{
    [t deselectRowAtIndexPath:ip animated:YES];
    WLStore *st = [WLStore shared];
    if (ip.section == 0 && ip.row == 0) {
        NSMutableArray *names = [NSMutableArray array];
        for (NSInteger i = 0; i < 4; i++) [names addObject:WLLanguageSettingName(i)];
        [self pushChoice:names images:nil selected:WLLanguageSetting() title:GL(@"Język") handler:^(NSInteger i) { WLSetLanguageSetting(i); }];
    } else if (ip.section == 0 && ip.row == 1) {
        NSMutableArray *names = [NSMutableArray array], *imgs = [NSMutableArray array];
        for (NSInteger i = 0; i < WLThemeCount(); i++) { [names addObject:WLThemeName(i)]; [imgs addObject:WLThemeSwatch(i)]; }
        [self pushChoice:names images:imgs selected:WLCurrentTheme() title:GL(@"Motyw") handler:^(NSInteger i) { WLSetTheme(i); }];
    } else if (ip.section == 1 && ip.row == 0) {
        NSMutableArray *names = [NSMutableArray array];
        for (NSInteger i = 0; i < 3; i++) [names addObject:SourceSettingName(i)];
        [self pushChoice:names images:nil selected:st.sourceSetting title:GL(@"Źródło kursów") handler:^(NSInteger i) {
            st.sourceSetting = i;
            [[WLRates shared] refreshNow];
        }];
    } else if (ip.section == 1 && ip.row == 1) {
        [[WLRates shared] refreshNow];
        [t reloadData];
    } else if (ip.section == 1 && ip.row == 2) {
        [st resetFavorites];
        [t reloadData];
    } else if (ip.section == 2 && ip.row == 1) {
        UIActionSheet *s = [[UIActionSheet alloc] initWithTitle:GL(@"Usunąć ustawienia, ulubione i zapisane kursy? Tego nie da się cofnąć.")
                                                       delegate:self cancelButtonTitle:GL(@"Anuluj") destructiveButtonTitle:GL(@"Usuń wszystko") otherButtonTitles:nil];
        [s showFromTabBar:self.tabBarController.tabBar];
    } else if (ip.section == 3 && ip.row == 2) {
        [self openURLString:@"https://www.exchangerate-api.com"];
    } else if (ip.section == 3 && ip.row == 3) {
        [self openURLString:@"https://nbp.pl"];
    }
}

- (void)actionSheet:(UIActionSheet *)s clickedButtonAtIndex:(NSInteger)i
{
    if (i == s.destructiveButtonIndex) {
        [[WLStore shared] clearAll];
        [[WLRates shared] clear];
        [_table reloadData];
    }
}

@end

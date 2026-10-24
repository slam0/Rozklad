#import "RZTabController.h"
#import "RZLang.h"
#import "RZSchedule.h"
#import "RZViews.h"
#import "RZPickerController.h"
#import "RZWifiController.h"
#import "RZStopController.h"
#import "rz_config.h"

static NSString *const kStopID = @"stop";
static NSString *const kMsgID = @"msg";

@interface RZTabController () <UIActionSheetDelegate>
@end

/* Lista przystanków jednego rodzaju (autobus, tramwaj, pociąg, metro).
   Dotknięcie przystanku otwiera osobny ekran z jego odjazdami. */
@implementation RZTabController {
    char _kind;
    RZMarquee *_marquee;
    NSTimer *_timer;
    NSArray *_fav;                /* RZStop z gwiazdką */
    NSArray *_rest;               /* pozostałe wybrane RZStop */
    NSMutableDictionary *_next;   /* klucz przystanku -> najbliższy RZDeparture */
    NSInteger _nowMinutes;
    NSUInteger _allCount;         /* ile przystanków tego rodzaju jest w pliku */
    UIBarButtonItem *_pickButton;
}

- (id)initWithKind:(char)kind title:(NSString *)title
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        _kind = kind;
        self.title = title;
        _fav = [NSArray array];
        _rest = [NSArray array];
        _next = [NSMutableDictionary dictionary];
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(scheduleChanged:) name:RZScheduleDidReloadNotification object:nil];
        [nc addObserver:self selector:@selector(appBecameActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
        [nc addObserver:self selector:@selector(themeChanged:) name:RZThemeDidChangeNotification object:nil];
        [nc addObserver:self selector:@selector(languageChanged:) name:RZLanguageDidChangeNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_timer invalidate];
}

#pragma mark - Widok

- (void)viewDidLoad
{
    [super viewDidLoad];
    RZStyleTable(self.tableView);

    _marquee = [[RZMarquee alloc] initWithFrame:CGRectMake(0, 0, 320, 34)];
    self.tableView.tableHeaderView = _marquee;

    _pickButton = [[UIBarButtonItem alloc] initWithTitle:RZL(@"Przystanki")
                                                   style:UIBarButtonItemStyleBordered
                                                  target:self
                                                  action:@selector(pickTapped)];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:RZL(@"Wczytaj")
                                         style:UIBarButtonItemStyleBordered
                                        target:self
                                        action:@selector(loadTapped)];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self rebuild];
    if (!_timer) {
        _timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [_marquee restart];
    [self promptIfNeeded];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [_timer invalidate];
    _timer = nil;
}

#pragma mark - Odświeżanie

/* Przycisk "Wczytaj": wybór, skąd wziąć rozkład */
- (void)loadTapped
{
    if (self.presentedViewController) return;
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:nil
                                                       delegate:self
                                              cancelButtonTitle:RZL(@"Anuluj")
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:RZL(@"Wybierz przystanki na stronie"), RZL(@"Odbierz plik przez Wi-Fi"), RZL(@"Odśwież z plików w telefonie"), nil];
    [sheet showInView:self.tabBarController ? self.tabBarController.view : self.view];
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index
{
    if (index == 0) {
        [self openSite];
    } else if (index == 1) {
        RZWifiController *wc = [[RZWifiController alloc] init];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:wc];
        RZStyleNavigationBar(nav.navigationBar);
        [self presentViewController:nav animated:YES completion:nil];
    } else if (index == 2) {
        [self refreshTapped];
    }
}

/* Otwiera w Safari stronę, na której wybiera się przystanki. */
- (void)openSite
{
    NSString *site = @RZ_SITE_URL;
    if (![site hasPrefix:@"http"]) {
        site = [[NSUserDefaults standardUserDefaults] stringForKey:@"site_base"];   /* adres z ostatniego pobrania */
    }
    if (![site hasPrefix:@"http"]) {
        UIAlertView *a = [[UIAlertView alloc] initWithTitle:RZL(@"Brak adresu strony")
                                                    message:RZL(@"Otwórz w Safari stronę z rozkładem, wybierz przystanki i dotknij „Otwórz w aplikacji Rozkład”. Potem aplikacja zapamięta adres.")
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
        [a show];
        return;
    }
    if ([site hasSuffix:@"/"]) site = [site stringByAppendingString:@"kreator/"];   /* kreator przystanków leży w podfolderze */
    NSString *sep = ([site rangeOfString:@"?"].location == NSNotFound) ? @"?" : @"&";
    site = [NSString stringWithFormat:@"%@%@lang=%@", site, sep, RZLangCode()];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:site]];
}

- (void)refreshTapped
{
    [[RZSchedule shared] reload];   /* wyśle powiadomienie, które odświeży wszystkie zakładki */
    [_marquee restart];
}

- (void)scheduleChanged:(NSNotification *)n
{
    if ([self isViewLoaded]) {
        [self rebuild];
        if (self.view.window) [self promptIfNeeded];
    }
}

#pragma mark - Wybór przystanków

- (void)pickTapped
{
    if (self.presentedViewController) return;
    __weak RZTabController *ws = self;
    RZPickerController *pc = [[RZPickerController alloc] initWithKind:_kind done:^{
        [ws rebuild];
    }];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:pc];
    RZStyleNavigationBar(nav.navigationBar);
    [self presentViewController:nav animated:YES completion:nil];
}

/* Gdy w pliku są przystanki tego rodzaju, a użytkownik jeszcze żadnych nie wybrał,
   okno wyboru wyskakuje samo. */
- (void)promptIfNeeded
{
    if (self.presentedViewController || !self.view.window) return;
    if ([[RZSchedule shared] needsSelectionForKind:_kind]) [self pickTapped];
}

- (void)appBecameActive:(NSNotification *)n
{
    if ([self isViewLoaded] && self.view.window) {
        [self rebuild];
        [_marquee restart];
    }
}

/* Raz na sekundę sprawdzamy zegar. Listę liczymy od nowa dopiero, gdy zmieni się minuta. */
- (void)tick
{
    if ([RZSchedule minutesOfDay:[NSDate date]] != _nowMinutes) [self rebuild];
}

/* Zmiana języka: nowe napisy na przyciskach, w liście i na pasku z ostrzeżeniem. */
- (void)languageChanged:(NSNotification *)n
{
    _pickButton.title = RZL(@"Przystanki");
    self.navigationItem.rightBarButtonItem.title = RZL(@"Wczytaj");
    if ([self isViewLoaded]) [self rebuild];
}

- (void)themeChanged:(NSNotification *)n
{
    if ([self isViewLoaded]) {
        RZStyleTable(self.tableView);
        [self.tableView reloadData];
        [_marquee restart];
    }
}

#pragma mark - Ulubione

- (void)starTapped:(UIButton *)b
{
    CGPoint p = [self.tableView convertPoint:b.center fromView:b.superview];
    NSIndexPath *ip = [self.tableView indexPathForRowAtPoint:p];
    RZStop *s = ip ? [self stopAtIndexPath:ip] : nil;
    if (!s) return;
    RZSchedule *sc = [RZSchedule shared];
    [sc setFavorite:![sc isFavoriteStop:s kind:_kind] forStop:s kind:_kind];
    [self rebuild];
}

/* Liczy odjazdy od nowa (według zegara telefonu) i odświeża tabelę. */
- (void)rebuild
{
    RZSchedule *sc = [RZSchedule shared];
    NSDate *now = [NSDate date];

    _allCount = [[sc stopsOfKind:_kind] count];
    NSMutableArray *favs = [NSMutableArray array];
    NSMutableArray *rest = [NSMutableArray array];
    for (RZStop *st in [sc selectedStopsOfKind:_kind]) {      /* alfabetycznie */
        if ([sc isFavoriteStop:st kind:_kind]) [favs addObject:st]; else [rest addObject:st];
    }
    _fav = favs;
    _rest = rest;
    self.navigationItem.leftBarButtonItem = _allCount ? _pickButton : nil;
    _nowMinutes = [RZSchedule minutesOfDay:now];

    _next = [NSMutableDictionary dictionaryWithCapacity:[favs count] + [rest count]];
    for (NSArray *group in [NSArray arrayWithObjects:favs, rest, nil]) {
        for (RZStop *st in group) {
            NSArray *deps = [sc nextDeparturesForStop:st kind:_kind now:now limit:1];
            if ([deps count]) [_next setObject:[deps objectAtIndex:0] forKey:st.key];
        }
    }

    [self.tableView reloadData];
    [self updateMarquee];
}

- (void)updateMarquee
{
    RZSchedule *sc = [RZSchedule shared];
    NSString *text;
    BOOL warning = NO;

    if ([sc.datasets count] == 0) {
        text = RZL(@"UWAGA! Brak rozkładu. Dotknij „Wczytaj” i wybierz przystanki na stronie z rozkładem.");
        warning = YES;
    } else {
        NSDate *expiry = [sc expiryDate];
        if (!expiry) {
            text = RZL(@"UWAGA! Nie znam daty ważności rozkładu. Jeśli odjazdy wyglądają na nieaktualne, odśwież rozkład.");
        } else {
            NSTimeInterval left = [expiry timeIntervalSinceNow];
            if (left <= 0) {
                text = RZL(@"UWAGA! Rozkład przeterminował się. Prosimy o odświeżenie rozkładu!");
                warning = YES;
            } else {
                text = [NSString stringWithFormat:RZL(@"UWAGA! Rozkład przeterminuje się za: %@. Po tym czasie prosimy o odświeżenie rozkładu!"),
                        [RZSchedule durationString:left]];
                warning = left < 7 * 24 * 3600;
            }
        }
    }
    [_marquee setText:text warning:warning];
}

#pragma mark - Tabela

- (NSString *)kindWord
{
    switch (_kind) {
        case 't': return RZL(@"tramwajowych");
        case 'p': return RZL(@"kolejowych");
        case 'm': return RZL(@"stacji metra");
        default:  return RZL(@"autobusowych");
    }
}

- (NSString *)emptyMessage
{
    RZSchedule *sc = [RZSchedule shared];
    if ([sc.datasets count] == 0) {
        NSString *extra = sc.loadError ? [NSString stringWithFormat:@"\n\n%@", sc.loadError] : @"";
        return [NSString stringWithFormat:RZL(@"Brak rozkładu.\n\nDotknij „Wczytaj” u góry i wybierz „Wybierz przystanki na stronie”. Po wybraniu przystanków dotknij tam „Otwórz w aplikacji Rozkład”.\n\nMożesz też wysłać plik rozklad.json z generatora przez Wi-Fi albo skopiować go do folderu:\n%@\n(albo przeciągnąć go do aplikacji w iTunes) i dotknąć „Wczytaj → Odśwież”.%@"),
                [sc folder], extra];
    }
    if (_allCount > 0) {
        return RZL(@"Nie wybrano żadnych przystanków.\n\nDotknij „Przystanki” w lewym górnym rogu i zaznacz te, które chcesz widzieć.");
    }
    return [NSString stringWithFormat:RZL(@"W wczytanym rozkładzie nie ma przystanków %@.\n\nWygeneruj rozkład z wybranymi przystankami tego rodzaju i skopiuj go na telefon."),
            [self kindWord]];
}

- (BOOL)isEmpty
{
    return [_fav count] + [_rest count] == 0;
}

/* Sekcje: "Ulubione" (jeśli są) i "Przystanki". Gdy nic nie wybrano: jedna sekcja z komunikatem. */
- (NSArray *)stopsInSection:(NSInteger)section
{
    if ([_fav count]) return section == 0 ? _fav : _rest;
    return _rest;
}

- (RZStop *)stopAtIndexPath:(NSIndexPath *)ip
{
    if ([self isEmpty]) return nil;
    NSArray *a = [self stopsInSection:ip.section];
    return ip.row < (NSInteger)[a count] ? [a objectAtIndex:ip.row] : nil;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if ([self isEmpty]) return 1;
    return ([_fav count] && [_rest count]) ? 2 : 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if ([self isEmpty]) return 1;
    return (NSInteger)[[self stopsInSection:section] count];
}

- (NSString *)headerTextForSection:(NSInteger)section
{
    if ([self isEmpty]) return nil;
    if ([_fav count] && section == 0) return RZL(@"Ulubione");
    return [_fav count] ? RZL(@"Pozostałe przystanki") : RZL(@"Przystanki");
}

- (NSString *)footerTextForSection:(NSInteger)section
{
    if (![self isEmpty] && section == [self numberOfSectionsInTableView:self.tableView] - 1) {
        return [NSString stringWithFormat:RZL(@"Dane: %@"), [[RZSchedule shared] summary]];
    }
    return nil;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    NSString *t = [self headerTextForSection:section];
    return t ? RZSectionHeaderView(t) : nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return [self headerTextForSection:section] ? 34.0f : 10.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    NSString *t = [self footerTextForSection:section];
    return t ? RZSectionFooterView(t) : nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return [self footerTextForSection:section] ? 44.0f : 10.0f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self isEmpty]) return ([[RZSchedule shared].datasets count] == 0 || _allCount == 0) ? 220.0f : 120.0f;
    return 58.0f;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    RZStyleCell(cell);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if ([self isEmpty]) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kMsgID];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kMsgID];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.numberOfLines = 0;
            cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
            cell.textLabel.font = [UIFont systemFontOfSize:15.0f];
        }
        cell.textLabel.textColor = RZCellTextColor();
        cell.textLabel.text = [self emptyMessage];
        return cell;
    }

    RZStop *s = [self stopAtIndexPath:indexPath];
    RZStopCell *cell = (RZStopCell *)[tableView dequeueReusableCellWithIdentifier:kStopID];
    if (!cell) {
        cell = [[RZStopCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kStopID];
        [cell.star addTarget:self action:@selector(starTapped:) forControlEvents:UIControlEventTouchUpInside];
    }
    BOOL fav = [[RZSchedule shared] isFavoriteStop:s kind:_kind];
    [cell setTitle:s.title departure:[_next objectForKey:s.key] nowMinutes:_nowMinutes favorite:fav];
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    RZStop *s = [self stopAtIndexPath:indexPath];
    if (!s) return;
    RZStopController *vc = [[RZStopController alloc] initWithStopKey:s.key kind:_kind title:s.title];
    [self.navigationController pushViewController:vc animated:YES];
}

@end

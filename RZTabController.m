#import "RZTabController.h"
#import "RZSchedule.h"
#import "RZViews.h"
#import "RZPickerController.h"
#import "RZWifiController.h"
#import "rz_config.h"

static NSString *const kTicketID = @"ticket";
static NSString *const kDepID = @"dep";
static NSString *const kMsgID = @"msg";

@interface RZTabController () <UIActionSheetDelegate>
@end

@implementation RZTabController {
    char _kind;
    RZMarquee *_marquee;
    NSTimer *_timer;
    NSArray *_stops;              /* RZStop */
    NSMutableArray *_rows;        /* dla każdego przystanku: tablica RZDeparture */
    RZDeparture *_nearest;
    NSString *_nearestStop;
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
        _stops = [NSArray array];
        _rows = [NSMutableArray array];
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(scheduleChanged:) name:RZScheduleDidReloadNotification object:nil];
        [nc addObserver:self selector:@selector(appBecameActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
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
    self.tableView.backgroundView = nil;
    self.tableView.backgroundColor = RZPaperColor();

    _marquee = [[RZMarquee alloc] initWithFrame:CGRectMake(0, 0, 320, 34)];
    self.tableView.tableHeaderView = _marquee;

    _pickButton = [[UIBarButtonItem alloc] initWithTitle:@"Przystanki"
                                                   style:UIBarButtonItemStyleBordered
                                                  target:self
                                                  action:@selector(pickTapped)];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:@"Wczytaj"
                                         style:UIBarButtonItemStyleBordered
                                        target:self
                                        action:@selector(loadTapped)];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self rebuild];
    if (!_timer) {
        _timer = [NSTimer scheduledTimerWithTimeInterval:15.0 target:self selector:@selector(tick) userInfo:nil repeats:YES];
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
                                              cancelButtonTitle:@"Anuluj"
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:@"Wybierz przystanki na stronie", @"Odbierz plik przez Wi-Fi", @"Odśwież z plików w telefonie", nil];
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
        UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Brak adresu strony"
                                                    message:@"Otwórz w Safari stronę z rozkładem, wybierz przystanki i dotknij „Otwórz w aplikacji Rozkład”. Potem aplikacja zapamięta adres."
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
        [a show];
        return;
    }
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

- (void)tick
{
    [self rebuild];
}

/* Liczy odjazdy od nowa (według zegara telefonu) i odświeża tabelę. */
- (void)rebuild
{
    RZSchedule *sc = [RZSchedule shared];
    NSDate *now = [NSDate date];
    NSUInteger limit = (_kind == 'm') ? 4 : 6;

    _allCount = [[sc stopsOfKind:_kind] count];
    _stops = [sc selectedStopsOfKind:_kind];
    self.navigationItem.leftBarButtonItem = _allCount ? _pickButton : nil;
    _rows = [NSMutableArray arrayWithCapacity:[_stops count]];
    _nearest = nil;
    _nearestStop = nil;
    _nowMinutes = [RZSchedule minutesOfDay:now];

    for (RZStop *s in _stops) {
        NSArray *deps = [sc nextDeparturesForStop:s kind:_kind now:now limit:limit];
        [_rows addObject:deps];
        if ([deps count]) {
            RZDeparture *f = [deps objectAtIndex:0];
            if (!_nearest || f.time < _nearest.time) {
                _nearest = f;
                _nearestStop = s.title;
            }
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
        text = @"UWAGA! Brak rozkładu. Dotknij „Wczytaj” i wybierz przystanki na stronie z rozkładem.";
        warning = YES;
    } else {
        NSDate *expiry = [sc expiryDate];
        if (!expiry) {
            text = @"UWAGA! Nie znam daty ważności rozkładu. Jeśli odjazdy wyglądają na nieaktualne, odśwież rozkład.";
        } else {
            NSTimeInterval left = [expiry timeIntervalSinceNow];
            if (left <= 0) {
                text = @"UWAGA! Rozkład przeterminował się. Prosimy o odświeżenie rozkładu!";
                warning = YES;
            } else {
                text = [NSString stringWithFormat:@"UWAGA! Rozkład przeterminuje się za: %@. Po tym czasie prosimy o odświeżenie rozkładu!",
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
        case 't': return @"tramwajowych";
        case 'p': return @"kolejowych";
        case 'm': return @"stacji metra";
        default:  return @"autobusowych";
    }
}

- (NSString *)emptyMessage
{
    RZSchedule *sc = [RZSchedule shared];
    if ([sc.datasets count] == 0) {
        NSString *extra = sc.loadError ? [NSString stringWithFormat:@"\n\n%@", sc.loadError] : @"";
        return [NSString stringWithFormat:@"Brak rozkładu.\n\nDotknij „Wczytaj” u góry i wybierz „Wybierz przystanki na stronie”. Po wybraniu przystanków dotknij tam „Otwórz w aplikacji Rozkład”.\n\nMożesz też wysłać plik rozklad.json z generatora przez Wi-Fi albo skopiować go do folderu:\n%@\n(albo przeciągnąć go do aplikacji w iTunes) i dotknąć „Wczytaj → Odśwież”.%@",
                [sc folder], extra];
    }
    if (_allCount > 0) {
        return @"Nie wybrano żadnych przystanków.\n\nDotknij „Przystanki” w lewym górnym rogu i zaznacz te, które chcesz widzieć.";
    }
    return [NSString stringWithFormat:@"W wczytanym rozkładzie nie ma przystanków %@.\n\nWygeneruj rozkład z wybranymi przystankami tego rodzaju i skopiuj go na telefon.",
            [self kindWord]];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1 + [_stops count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) return 1;
    NSArray *deps = [_rows objectAtIndex:section - 1];
    return [deps count] ? [deps count] : 1;
}

- (NSString *)headerTextForSection:(NSInteger)section
{
    if (section == 0) return [_stops count] ? @"Najbliższy odjazd" : nil;
    return ((RZStop *)[_stops objectAtIndex:section - 1]).title;
}

- (NSString *)footerTextForSection:(NSInteger)section
{
    if ([_stops count] && section == (NSInteger)[_stops count]) {
        return [NSString stringWithFormat:@"Dane: %@", [[RZSchedule shared] summary]];
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
    if (indexPath.section == 0) {
        if (_nearest) return 118.0f;
        if ([_stops count]) return 50.0f;
        return _allCount ? 120.0f : 200.0f;   /* komunikaty o braku danych są długie */
    }
    NSArray *deps = [_rows objectAtIndex:indexPath.section - 1];
    return [deps count] ? 56.0f : 44.0f;
}

- (UITableViewCell *)messageCellWithText:(NSString *)text font:(UIFont *)font color:(UIColor *)color
{
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:kMsgID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kMsgID];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
    }
    cell.textLabel.font = font;
    cell.textLabel.textColor = color;
    cell.textLabel.text = text;
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        if (_nearest) {
            RZTicketCell *cell = (RZTicketCell *)[tableView dequeueReusableCellWithIdentifier:kTicketID];
            if (!cell) cell = [[RZTicketCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kTicketID];
            [cell setDeparture:_nearest stopName:_nearestStop nowMinutes:_nowMinutes];
            return cell;
        }
        NSString *msg = [_stops count] ? @"Brak odjazdów w najbliższym czasie." : [self emptyMessage];
        return [self messageCellWithText:msg font:[UIFont systemFontOfSize:15.0f] color:[UIColor darkGrayColor]];
    }

    NSArray *deps = [_rows objectAtIndex:indexPath.section - 1];
    if (![deps count]) {
        NSString *hours = (_kind == 'p') ? @"24 godzinach" : @"12 godzinach";
        return [self messageCellWithText:[NSString stringWithFormat:@"Brak odjazdów w najbliższych %@.", hours]
                                    font:[UIFont systemFontOfSize:14.0f] color:[UIColor grayColor]];
    }
    RZDepartureCell *cell = (RZDepartureCell *)[tableView dequeueReusableCellWithIdentifier:kDepID];
    if (!cell) cell = [[RZDepartureCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kDepID];
    [cell setDeparture:[deps objectAtIndex:indexPath.row] nowMinutes:_nowMinutes];
    return cell;
}

@end

#import "RZStopController.h"
#import "RZLang.h"
#import "RZSchedule.h"
#import "RZViews.h"

static NSString *const kTicketID = @"ticket";
static NSString *const kDepID = @"dep";
static NSString *const kMsgID = @"msg";

@interface RZStopController () <UIActionSheetDelegate>
@end

@implementation RZStopController {
    RZDeparture *_picked;           /* odjazd, dla którego ustawiamy przypomnienie */
    NSString *_key;
    char _kind;
    NSTimer *_timer;
    NSArray *_deps;                 /* RZDeparture */
    NSString *_stopTitle;
    NSInteger _nowMinutes;
    BOOL _gone;                     /* przystanku nie ma już w wczytanym rozkładzie */
}

- (id)initWithStopKey:(NSString *)key kind:(char)kind title:(NSString *)title
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        _key = [key copy];
        _kind = kind;
        _stopTitle = [title copy];
        self.title = title;
        _deps = [NSArray array];
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(scheduleChanged:) name:RZScheduleDidReloadNotification object:nil];
        [nc addObserver:self selector:@selector(themeChanged:) name:RZThemeDidChangeNotification object:nil];
        [nc addObserver:self selector:@selector(scheduleChanged:) name:RZLanguageDidChangeNotification object:nil];
        [nc addObserver:self selector:@selector(appBecameActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [_timer invalidate];
}

/* Szuka przystanku po kluczu w aktualnie wczytanym rozkładzie (obiekty zmieniają się przy każdym wczytaniu). */
- (RZStop *)currentStop
{
    for (RZStop *s in [[RZSchedule shared] stopsOfKind:_kind]) {
        if ([s.key isEqualToString:_key]) return s;
    }
    return nil;
}

#pragma mark - Widok

- (void)viewDidLoad
{
    [super viewDidLoad];
    RZStyleTable(self.tableView);
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self rebuild];
    if (!_timer) {
        _timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(tick) userInfo:nil repeats:YES];
    }
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [_timer invalidate];
    _timer = nil;
}

- (void)updateStarButton
{
    RZStop *s = [self currentStop];
    BOOL fav = s && [[RZSchedule shared] isFavoriteStop:s kind:_kind];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithImage:RZStarIcon(fav) style:UIBarButtonItemStyleBordered
                                        target:self action:@selector(starTapped)];
}

- (void)starTapped
{
    RZStop *s = [self currentStop];
    if (!s) return;
    RZSchedule *sc = [RZSchedule shared];
    [sc setFavorite:![sc isFavoriteStop:s kind:_kind] forStop:s kind:_kind];
    [self updateStarButton];
}

#pragma mark - Odświeżanie

- (void)scheduleChanged:(NSNotification *)n
{
    if ([self isViewLoaded]) [self rebuild];
}

- (void)themeChanged:(NSNotification *)n
{
    if ([self isViewLoaded]) {
        RZStyleTable(self.tableView);
        [self.tableView reloadData];
    }
}

- (void)appBecameActive:(NSNotification *)n
{
    if ([self isViewLoaded] && self.view.window) [self rebuild];
}

/* Co sekundę odświeżamy odliczanie na bilecie. Listę liczymy od nowa, gdy zmieni się minuta. */
- (void)tick
{
    NSDate *now = [NSDate date];
    if ([RZSchedule minutesOfDay:now] != _nowMinutes) {
        [self rebuild];
        return;
    }
    if ([_deps count]) {
        RZTicketCell *cell = (RZTicketCell *)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
        if ([cell isKindOfClass:[RZTicketCell class]]) {
            RZDeparture *d = [_deps objectAtIndex:0];
            [cell setCountdownText:[RZSchedule countdownString:d.time * 60 - [RZSchedule secondsOfDay:now]]];
        }
    }
}

- (void)rebuild
{
    RZSchedule *sc = [RZSchedule shared];
    RZStop *s = [self currentStop];
    NSDate *now = [NSDate date];
    _nowMinutes = [RZSchedule minutesOfDay:now];
    _gone = (s == nil);
    if (s) {
        _stopTitle = s.title;
        self.title = s.title;
        _deps = [sc nextDeparturesForStop:s kind:_kind now:now limit:(NSUInteger)[RZSchedule departureLimit]];
    } else {
        _deps = [NSArray array];
    }
    [self updateStarButton];
    [self.tableView reloadData];
}

#pragma mark - Tabela

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) return 1;
    return [_deps count] > 1 ? (NSInteger)[_deps count] - 1 : 0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (section == 0) return RZSectionHeaderView(RZL(@"Najbliższy odjazd"));
    return [_deps count] > 1 ? RZSectionHeaderView(RZL(@"Kolejne odjazdy")) : nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section == 0) return 34.0f;
    return [_deps count] > 1 ? 34.0f : 4.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    if (section == 1) {
        return RZSectionFooterView([NSString stringWithFormat:RZL(@"Dotknij odjazdu, aby ustawić przypomnienie.\nDane: %@"), [[RZSchedule shared] summary]]);
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return section == 1 ? 58.0f : 8.0f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) return [_deps count] ? 118.0f : 70.0f;
    return 56.0f;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    RZStyleCell(cell);
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        if ([_deps count]) {
            RZTicketCell *cell = (RZTicketCell *)[tableView dequeueReusableCellWithIdentifier:kTicketID];
            if (!cell) cell = [[RZTicketCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kTicketID];
            [cell setDeparture:[_deps objectAtIndex:0] stopName:_stopTitle nowMinutes:_nowMinutes];
            return cell;
        }
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kMsgID];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kMsgID];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.textLabel.numberOfLines = 0;
            cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
            cell.textLabel.font = [UIFont systemFontOfSize:15.0f];
        }
        cell.textLabel.textColor = RZCellTextColor();
        NSString *hours = (_kind == 'p') ? RZL(@"24 godzinach") : RZL(@"12 godzinach");
        cell.textLabel.text = _gone
            ? RZL(@"Tego przystanku nie ma w wczytanym rozkładzie. Wróć do listy i wybierz inny.")
            : [NSString stringWithFormat:RZL(@"Brak odjazdów w najbliższych %@."), hours];
        return cell;
    }

    RZDepartureCell *cell = (RZDepartureCell *)[tableView dequeueReusableCellWithIdentifier:kDepID];
    if (!cell) cell = [[RZDepartureCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kDepID];
    [cell setDeparture:[_deps objectAtIndex:indexPath.row + 1] nowMinutes:_nowMinutes];
    return cell;
}

#pragma mark - Przypomnienia o odjeździe

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSUInteger i = (indexPath.section == 0) ? 0 : (NSUInteger)indexPath.row + 1;
    if (i >= [_deps count]) return;
    _picked = [_deps objectAtIndex:i];
    NSString *title = [NSString stringWithFormat:RZL(@"Przypomnienie: %@ → %@, %@"),
                       _picked.line, _picked.head, [RZSchedule clockString:_picked.time]];
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:title delegate:self
                                              cancelButtonTitle:RZL(@"Anuluj")
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:RZL(@"5 minut przed odjazdem"), RZL(@"10 minut przed odjazdem"), RZL(@"15 minut przed odjazdem"), nil];
    [sheet showInView:self.tabBarController ? self.tabBarController.view : self.view];
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index
{
    RZDeparture *d = _picked;
    _picked = nil;
    if (!d || index == sheet.cancelButtonIndex) return;
    NSInteger before = (index == 0) ? 5 : (index == 1 ? 10 : 15);

    /* Odjazd to minuty od północy dzisiaj (po północy może być ponad 1440). */
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *day = [cal components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit) fromDate:[NSDate date]];
    NSDate *midnight = [cal dateFromComponents:day];
    NSDateComponents *add = [[NSDateComponents alloc] init];
    [add setMinute:d.time - before];
    NSDate *fire = [cal dateByAddingComponents:add toDate:midnight options:0];

    if (!fire || [fire timeIntervalSinceNow] < 2.0) {
        UIAlertView *a = [[UIAlertView alloc] initWithTitle:RZL(@"Za późno")
                                                    message:RZL(@"Do odjazdu zostało mniej czasu niż wybrane przypomnienie. Wybierz krótszy czas albo późniejszy odjazd.")
                                                   delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [a show];
        return;
    }

    UILocalNotification *n = [[UILocalNotification alloc] init];
    n.fireDate = fire;
    n.timeZone = [NSTimeZone defaultTimeZone];
    n.alertBody = [NSString stringWithFormat:RZL(@"%@ → %@ odjeżdża o %@ z przystanku %@ (za %ld min)"),
                   d.line, d.head, [RZSchedule clockString:d.time], _stopTitle, (long)before];
    n.soundName = UILocalNotificationDefaultSoundName;
    [[UIApplication sharedApplication] scheduleLocalNotification:n];

    UIAlertView *a = [[UIAlertView alloc] initWithTitle:RZL(@"Przypomnienie ustawione")
                                                message:[NSString stringWithFormat:RZL(@"Telefon zadzwoni o %@, %ld min przed odjazdem."),
                                                         [RZSchedule clockString:(NSInteger)d.time - before], (long)before]
                                               delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [a show];
}

@end

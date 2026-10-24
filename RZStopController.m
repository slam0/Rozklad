#import "RZStopController.h"
#import "RZLang.h"
#import "RZSchedule.h"
#import "RZViews.h"
#import "RZDayController.h"

static NSString *const kTicketID = @"ticket";
static NSString *const kCtlID = @"ctl";
static NSString *const kDepID = @"dep";
static NSString *const kMsgID = @"msg";

/* Sekcje tabeli: nazwa i dzień, bilet z najbliższym odjazdem (tylko dziś), lista odjazdów */
enum { kSecControls = 0, kSecTicket = 1, kSecList = 2 };

@interface RZStopController () <UIActionSheetDelegate, UIAlertViewDelegate>
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
    NSDate *_day;                   /* wybrany dzień (godzina 12:00); nil = dziś */
    NSArray *_dayDeps;              /* wszystkie odjazdy wybranego dnia (RZDeparture) */
    BOOL _dayCovered;               /* czy rozkład w telefonie obejmuje wybrany dzień */
    NSString *_lastDayText;         /* ostatni dzień ważności rozkładu, do komunikatu */
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
        _dayDeps = [NSArray array];
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
    if (_day) {
        /* po północy "jutro" staje się "dziś": wtedy wracamy do zwykłego widoku */
        if ([_day compare:[RZDayController noonOf:now]] != NSOrderedDescending) [self rebuild];
        return;
    }
    if ([RZSchedule minutesOfDay:now] != _nowMinutes) {
        [self rebuild];
        return;
    }
    if ([_deps count]) {
        RZTicketCell *cell = (RZTicketCell *)[self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:kSecTicket]];
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
    /* dzień, który już minął albo jest dzisiejszy, oznacza zwykły widok "dziś" */
    if (_day && [_day compare:[RZDayController noonOf:now]] != NSOrderedDescending) _day = nil;
    _deps = [NSArray array];
    _dayDeps = [NSArray array];
    _dayCovered = YES;
    if (s) {
        _stopTitle = s.displayTitle;
        self.title = _stopTitle;
        if (_day) {
            _dayDeps = [sc departuresForStop:s kind:_kind onDate:_day];
            _dayCovered = [sc coversDate:_day forStop:s];
            NSDate *last = [sc lastDayForStop:s];
            _lastDayText = last ? [RZDayController stringForDay:last long:YES] : nil;
        } else {
            _deps = [sc nextDeparturesForStop:s kind:_kind now:now limit:(NSUInteger)[RZSchedule departureLimit]];
        }
    }
    [self updateStarButton];
    [self.tableView reloadData];
}

#pragma mark - Tabela

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == kSecControls) return _gone ? 0 : 2;
    if (section == kSecTicket) return _day ? 0 : 1;
    if (_day) return [_dayDeps count] ? (NSInteger)[_dayDeps count] : 1;
    return [_deps count] > 1 ? (NSInteger)[_deps count] - 1 : 0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    if (section == kSecTicket && !_day) return RZSectionHeaderView(RZL(@"Najbliższy odjazd"));
    if (section == kSecList) {
        if (_day) return RZSectionHeaderView([NSString stringWithFormat:RZL(@"Odjazdy: %@"), [RZDayController stringForDay:_day long:YES]]);
        if ([_deps count] > 1) return RZSectionHeaderView(RZL(@"Kolejne odjazdy"));
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    if (section == kSecControls) return 8.0f;
    if (section == kSecTicket) return _day ? 0.01f : 34.0f;
    if (_day) return 34.0f;
    return [_deps count] > 1 ? 34.0f : 4.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    if (section == kSecControls) {
        NSString *custom = _gone ? nil : [[RZSchedule shared] customNameForStop:[self currentStop]];
        if (custom) {
            return RZSectionFooterView([NSString stringWithFormat:RZL(@"Oryginalna nazwa: %@"), [self currentStop].title]);
        }
        return nil;
    }
    if (section == kSecList) {
        return RZSectionFooterView([NSString stringWithFormat:RZL(@"Dotknij odjazdu, aby ustawić przypomnienie.\nDane: %@"), [[RZSchedule shared] summary]]);
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    if (section == kSecControls) {
        if (_gone) return 4.0f;
        return [[RZSchedule shared] customNameForStop:[self currentStop]] ? 34.0f : 6.0f;
    }
    if (section == kSecTicket) return _day ? 0.01f : 8.0f;
    return 58.0f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kSecControls) return 44.0f;
    if (indexPath.section == kSecTicket) return [_deps count] ? 118.0f : 70.0f;
    if (_day && ![_dayDeps count]) return 70.0f;
    return 56.0f;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    RZStyleCell(cell);
}

- (UITableViewCell *)messageCellInTable:(UITableView *)tableView text:(NSString *)text
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kMsgID];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kMsgID];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.numberOfLines = 0;
        cell.textLabel.lineBreakMode = NSLineBreakByWordWrapping;
        cell.textLabel.font = [UIFont systemFontOfSize:15.0f];
    }
    cell.textLabel.textColor = RZCellTextColor();
    cell.textLabel.text = text;
    return cell;
}

/* Co napisać, gdy nie ma żadnego odjazdu */
- (NSString *)emptyText
{
    if (_gone) return RZL(@"Tego przystanku nie ma w wczytanym rozkładzie. Wróć do listy i wybierz inny.");
    if (_day) {
        if (!_dayCovered) {
            return [NSString stringWithFormat:RZL(@"Rozkład w telefonie jest ważny do %@, więc na ten dzień nie ma danych."),
                    _lastDayText ? _lastDayText : @"?"];
        }
        return RZL(@"Tego dnia nie ma odjazdów z tego przystanku.");
    }
    NSString *hours = (_kind == 'p') ? RZL(@"24 godzinach") : RZL(@"12 godzinach");
    return [NSString stringWithFormat:RZL(@"Brak odjazdów w najbliższych %@."), hours];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kSecControls) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:kCtlID];
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:kCtlID];
            cell.selectionStyle = UITableViewCellSelectionStyleGray;
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.textLabel.font = [UIFont boldSystemFontOfSize:16.0f];
            cell.detailTextLabel.font = [UIFont systemFontOfSize:15.0f];
        }
        cell.textLabel.textColor = RZCellTextColor();
        cell.detailTextLabel.textColor = RZSubtleColor();
        if (indexPath.row == 0) {
            cell.textLabel.text = RZL(@"Nazwa");
            cell.detailTextLabel.text = _stopTitle;
        } else {
            cell.textLabel.text = RZL(@"Dzień");
            cell.detailTextLabel.text = _day ? [RZDayController stringForDay:_day long:NO] : RZL(@"Dzisiaj");
        }
        return cell;
    }

    if (indexPath.section == kSecTicket) {
        if ([_deps count]) {
            RZTicketCell *cell = (RZTicketCell *)[tableView dequeueReusableCellWithIdentifier:kTicketID];
            if (!cell) cell = [[RZTicketCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kTicketID];
            [cell setDeparture:[_deps objectAtIndex:0] stopName:_stopTitle nowMinutes:_nowMinutes];
            return cell;
        }
        return [self messageCellInTable:tableView text:[self emptyText]];
    }

    if (_day) {
        if (![_dayDeps count]) return [self messageCellInTable:tableView text:[self emptyText]];
        RZDepartureCell *cell = (RZDepartureCell *)[tableView dequeueReusableCellWithIdentifier:kDepID];
        if (!cell) cell = [[RZDepartureCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kDepID];
        [cell setDeparture:[_dayDeps objectAtIndex:indexPath.row] nowMinutes:0 showCountdown:NO];
        return cell;
    }

    RZDepartureCell *cell = (RZDepartureCell *)[tableView dequeueReusableCellWithIdentifier:kDepID];
    if (!cell) cell = [[RZDepartureCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kDepID];
    [cell setDeparture:[_deps objectAtIndex:indexPath.row + 1] nowMinutes:_nowMinutes];
    return cell;
}

#pragma mark - Nazwa i dzień

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == kSecControls) {
        if (indexPath.row == 0) [self askForName]; else [self chooseDay];
        return;
    }

    RZDeparture *d = nil;
    if (_day) {
        if (indexPath.section == kSecList && (NSUInteger)indexPath.row < [_dayDeps count]) d = [_dayDeps objectAtIndex:indexPath.row];
    } else if (indexPath.section == kSecTicket) {
        if ([_deps count]) d = [_deps objectAtIndex:0];
    } else if ((NSUInteger)indexPath.row + 1 < [_deps count]) {
        d = [_deps objectAtIndex:indexPath.row + 1];
    }
    if (!d) return;
    [self askForReminder:d];
}

- (void)chooseDay
{
    RZStop *s = [self currentStop];
    if (!s) return;
    RZDayController *vc = [[RZDayController alloc] initWithDay:_day lastDay:[[RZSchedule shared] lastDayForStop:s]];
    __weak RZStopController *me = self;
    vc.onChange = ^(NSDate *day) {
        RZStopController *strong = me;
        if (!strong) return;
        strong->_day = day;
        [strong rebuild];
    };
    [self.navigationController pushViewController:vc animated:YES];
}

- (void)askForName
{
    RZStop *s = [self currentStop];
    if (!s) return;
    BOOL renamed = ([[RZSchedule shared] customNameForStop:s] != nil);
    UIAlertView *a = [[UIAlertView alloc] initWithTitle:RZL(@"Nazwa przystanku")
                                                message:RZL(@"Wpisz własną nazwę, np. Dom albo Praca.")
                                               delegate:self
                                      cancelButtonTitle:RZL(@"Anuluj")
                                      otherButtonTitles:RZL(@"Zapisz"), (renamed ? RZL(@"Przywróć oryginał") : nil), nil];
    a.alertViewStyle = UIAlertViewStylePlainTextInput;
    UITextField *field = [a textFieldAtIndex:0];
    field.text = s.displayTitle;
    field.placeholder = s.title;
    field.autocapitalizationType = UITextAutocapitalizationTypeSentences;
    field.clearButtonMode = UITextFieldViewModeWhileEditing;
    [a show];
}

- (void)alertView:(UIAlertView *)alert clickedButtonAtIndex:(NSInteger)index
{
    if (index == alert.cancelButtonIndex) return;
    RZStop *s = [self currentStop];
    if (!s) return;
    NSString *button = [alert buttonTitleAtIndex:index];
    RZSchedule *sc = [RZSchedule shared];
    if ([button isEqualToString:RZL(@"Przywróć oryginał")]) {
        [sc setCustomName:nil forStop:s];
    } else {
        [sc setCustomName:[[alert textFieldAtIndex:0] text] forStop:s];
    }
    /* listy przystanków w zakładkach odświeżają się po tym powiadomieniu */
    [[NSNotificationCenter defaultCenter] postNotificationName:RZScheduleDidReloadNotification object:sc];
}

#pragma mark - Przypomnienia o odjeździe

- (void)askForReminder:(RZDeparture *)d
{
    _picked = d;
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

    /* Odjazd to minuty od północy dnia kursowania (po północy może być ponad 1440). Dla innego dnia liczymy od jego północy. */
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *day = [cal components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit) fromDate:(_day ? _day : [NSDate date])];
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

    /* przy innym dniu dopisujemy go do nazwy przystanku, żeby było jasne, którego dnia to przypomnienie */
    NSString *where = _day ? [NSString stringWithFormat:@"%@, %@", _stopTitle, [RZDayController stringForDay:_day long:NO]] : _stopTitle;

    UILocalNotification *n = [[UILocalNotification alloc] init];
    n.fireDate = fire;
    n.timeZone = [NSTimeZone defaultTimeZone];
    n.alertBody = [NSString stringWithFormat:RZL(@"%@ → %@ odjeżdża o %@ z przystanku %@ (za %ld min)"),
                   d.line, d.head, [RZSchedule clockString:d.time], where, (long)before];
    n.soundName = UILocalNotificationDefaultSoundName;
    [[UIApplication sharedApplication] scheduleLocalNotification:n];

    UIAlertView *a = [[UIAlertView alloc] initWithTitle:RZL(@"Przypomnienie ustawione")
                                                message:[NSString stringWithFormat:RZL(@"Telefon zadzwoni o %@, %ld min przed odjazdem."),
                                                         [RZSchedule clockString:(NSInteger)d.time - before], (long)before]
                                               delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [a show];
}

@end

#import "RZSettingsController.h"
#import "RZLang.h"
#import "RZSchedule.h"
#import "RZViews.h"
#import "rz_config.h"

enum {
    SecTheme = 0,
    SecLanguage,
    SecDisplay,
    SecData,
    SecAbout,
    SecCount
};

enum {
    DataInfo = 0,
    DataOpenSite,
    DataRemoveExpired,
    DataRemoveAll,
    DataClearFavs,
    DataReminders,
    DataRows
};

@interface RZSettingsController () <UIActionSheetDelegate>
@end

@implementation RZSettingsController {
    int _pending;       /* którą akcję potwierdza arkusz: 1 = przeterminowane, 2 = wszystko, 3 = ulubione */
}

- (id)init
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        self.title = RZL(@"Ustawienia");
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self selector:@selector(refresh:) name:RZThemeDidChangeNotification object:nil];
        [nc addObserver:self selector:@selector(languageChanged:) name:RZLanguageDidChangeNotification object:nil];
        [nc addObserver:self selector:@selector(refresh:) name:RZScheduleDidReloadNotification object:nil];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    RZStyleTable(self.tableView);
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    RZStyleTable(self.tableView);
    [self.tableView reloadData];
}

- (void)languageChanged:(NSNotification *)n
{
    self.title = RZL(@"Ustawienia");
    [self refresh:n];
}

- (void)refresh:(NSNotification *)n
{
    if ([self isViewLoaded]) {
        RZStyleTable(self.tableView);
        [self.tableView reloadData];
    }
}

#pragma mark - Teksty

- (NSString *)versionString
{
    NSString *v = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    return v ? v : @"?";
}

- (NSString *)dataSummary
{
    RZSchedule *sc = [RZSchedule shared];
    if (![sc.datasets count]) return RZL(@"brak wczytanego rozkładu");
    NSString *when = @"";
    NSDate *exp = [sc expiryDate];
    if (exp) {
        NSDateFormatter *f = [[NSDateFormatter alloc] init];
        [f setDateFormat:@"d.MM.yyyy"];
        /* expiryDate to początek następnego dnia, więc pokazujemy dzień wcześniej */
        when = [NSString stringWithFormat:RZL(@", ważny do %@"), [f stringFromDate:[exp dateByAddingTimeInterval:-3600]]];
    }
    return [NSString stringWithFormat:RZL(@"przystanków: %lu%@"), (unsigned long)[sc.stops count], when];
}

#pragma mark - Tabela

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return SecCount;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    switch (section) {
        case SecTheme:   return (NSInteger)RZThemeCount();
        case SecLanguage: return 4;
        case SecDisplay: return 1;
        case SecData:    return DataRows;
        default:         return 4;
    }
}

- (NSString *)headerText:(NSInteger)section
{
    switch (section) {
        case SecTheme:   return RZL(@"Motyw");
        case SecLanguage: return RZL(@"Język");
        case SecDisplay: return RZL(@"Wyświetlanie");
        case SecData:    return RZL(@"Dane");
        default:         return RZL(@"O aplikacji");
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    return RZSectionHeaderView([self headerText:section]);
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 34.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    if (section == SecDisplay) {
        return RZSectionFooterView(RZL(@"Ulubione przystanki oznaczasz gwiazdką na liście lub na ekranie przystanku. Trafiają wtedy na górę."));
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return section == SecDisplay ? 50.0f : 8.0f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return indexPath.section == SecTheme ? 52.0f : 46.0f;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    RZStyleCell(cell);
}

- (UITableViewCell *)cellWithStyle:(UITableViewCellStyle)style
{
    NSString *ident = (style == UITableViewCellStyleValue1) ? @"v1" : (style == UITableViewCellStyleDefault ? @"def" : @"sub");
    UITableViewCell *cell = [self.tableView dequeueReusableCellWithIdentifier:ident];
    if (!cell) cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:ident];
    cell.textLabel.font = [UIFont boldSystemFontOfSize:16.0f];
    cell.textLabel.textColor = RZCellTextColor();
    cell.textLabel.textAlignment = NSTextAlignmentLeft;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0f];
    cell.detailTextLabel.textColor = RZSubtleColor();
    cell.detailTextLabel.numberOfLines = 1;
    cell.accessoryType = UITableViewCellAccessoryNone;
    cell.imageView.image = nil;
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    RZSchedule *sc = [RZSchedule shared];
    UITableViewCell *cell;

    if (indexPath.section == SecTheme) {
        NSInteger i = indexPath.row;
        cell = [self cellWithStyle:UITableViewCellStyleDefault];
        cell.textLabel.text = RZThemeName(i);
        cell.imageView.image = RZThemeSwatch(i);
        cell.accessoryType = (i == RZThemeIndex()) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        return cell;
    }

    if (indexPath.section == SecLanguage) {
        NSInteger i = indexPath.row;        /* 0 automatycznie, 1 polski, 2 angielski, 3 rosyjski */
        cell = [self cellWithStyle:UITableViewCellStyleDefault];
        NSString *names[4] = { RZL(@"Automatycznie"), @"Polski", @"English", @"Русский" };
        cell.textLabel.text = names[i];
        cell.accessoryType = (i == RZLangChoice()) ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        return cell;
    }

    if (indexPath.section == SecDisplay) {
        cell = [self cellWithStyle:UITableViewCellStyleValue1];
        cell.textLabel.text = RZL(@"Odjazdów na ekranie przystanku");
        cell.detailTextLabel.font = [UIFont boldSystemFontOfSize:16.0f];
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%ld", (long)[RZSchedule departureLimit]];
        return cell;
    }

    if (indexPath.section == SecData) {
        cell = [self cellWithStyle:UITableViewCellStyleSubtitle];
        switch (indexPath.row) {
            case DataInfo:
                cell.textLabel.text = RZL(@"Wczytany rozkład");
                cell.detailTextLabel.text = [self dataSummary];
                cell.selectionStyle = UITableViewCellSelectionStyleNone;
                break;
            case DataOpenSite:
                cell.textLabel.text = RZL(@"Pobierz nowy rozkład ze strony");
                cell.detailTextLabel.text = RZL(@"otwiera stronę w Safari");
                cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
                break;
            case DataRemoveExpired: {
                NSUInteger n = [sc expiredFileCount];
                cell.textLabel.text = RZL(@"Usuń przeterminowane rozkłady");
                cell.detailTextLabel.text = n ? [NSString stringWithFormat:RZL(@"do usunięcia: %lu"), (unsigned long)n] : RZL(@"nie ma żadnych przeterminowanych");
                break;
            }
            case DataRemoveAll:
                cell.textLabel.text = RZL(@"Usuń wszystkie rozkłady z telefonu");
                cell.detailTextLabel.text = [NSString stringWithFormat:RZL(@"plików na telefonie: %lu"), (unsigned long)[sc fileCount]];
                cell.textLabel.textColor = RZAccentColor();
                break;
            case DataClearFavs:
                cell.textLabel.text = RZL(@"Wyczyść ulubione");
                cell.detailTextLabel.text = [NSString stringWithFormat:RZL(@"gwiazdek: %lu"), (unsigned long)[sc favoriteCount]];
                break;
            default:
                cell.textLabel.text = RZL(@"Anuluj wszystkie przypomnienia");
                cell.detailTextLabel.text = [NSString stringWithFormat:RZL(@"ustawionych: %lu"),
                    (unsigned long)[[[UIApplication sharedApplication] scheduledLocalNotifications] count]];
                break;
        }
        return cell;
    }

    cell = [self cellWithStyle:UITableViewCellStyleSubtitle];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    switch (indexPath.row) {
        case 0:
            cell.textLabel.text = @"Rozkład";
            cell.detailTextLabel.text = [NSString stringWithFormat:RZL(@"wersja %@"), [self versionString]];
            break;
        case 1:
            cell.textLabel.text = RZL(@"Autor");
            cell.detailTextLabel.text = @"nazar0vsky-slam0";
            break;
        case 2:
            cell.textLabel.text = RZL(@"Strona z rozkładem");
            cell.detailTextLabel.text = [@RZ_SITE_URL hasPrefix:@"http"] ? @RZ_SITE_URL : RZL(@"adres zapisze się po pierwszym pobraniu");
            break;
        default:
            cell.textLabel.text = RZL(@"Źródło danych");
            cell.detailTextLabel.text = RZL(@"ZTM Warszawa (GTFS), udostępnia mkuran.pl");
            break;
    }
    return cell;
}

#pragma mark - Akcje

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    RZSchedule *sc = [RZSchedule shared];

    if (indexPath.section == SecTheme) {
        RZThemeSet(indexPath.row);      /* odświeża paski i listy we wszystkich zakładkach */
        return;
    }

    if (indexPath.section == SecLanguage) {
        RZLangSet(indexPath.row);       /* zmienia język wszystkich ekranów */
        return;
    }

    if (indexPath.section == SecDisplay) {
        NSInteger cur = [RZSchedule departureLimit];
        NSInteger next = (cur == 10) ? 20 : (cur == 20 ? 30 : 10);
        [RZSchedule setDepartureLimit:next];
        [[NSNotificationCenter defaultCenter] postNotificationName:RZScheduleDidReloadNotification object:sc];
        return;
    }

    if (indexPath.section != SecData) return;

    switch (indexPath.row) {
        case DataOpenSite:
            [self openSite];
            break;
        case DataRemoveExpired:
            if ([sc expiredFileCount] == 0) {
                [self say:RZL(@"Brak przeterminowanych rozkładów") text:RZL(@"Wszystkie wczytane rozkłady są jeszcze ważne.")];
            } else {
                [self confirm:1 title:RZL(@"Usunąć przeterminowane rozkłady z telefonu?") button:RZL(@"Usuń przeterminowane")];
            }
            break;
        case DataRemoveAll:
            if ([sc fileCount] == 0) {
                [self say:RZL(@"Brak plików") text:RZL(@"Na telefonie nie ma żadnych plików z rozkładem.")];
            } else {
                [self confirm:2 title:RZL(@"Usunąć wszystkie rozkłady z telefonu? Nowy pobierzesz ze strony.") button:RZL(@"Usuń wszystko")];
            }
            break;
        case DataReminders:
            if ([[[UIApplication sharedApplication] scheduledLocalNotifications] count] == 0) {
                [self say:RZL(@"Brak przypomnień") text:RZL(@"Nie masz ustawionych żadnych przypomnień. Dotknij odjazdu na ekranie przystanku, aby je dodać.")];
            } else {
                [self confirm:4 title:RZL(@"Anulować wszystkie przypomnienia o odjazdach?") button:RZL(@"Anuluj przypomnienia")];
            }
            break;
        case DataClearFavs:
            if ([sc favoriteCount] == 0) {
                [self say:RZL(@"Brak ulubionych") text:RZL(@"Nie masz żadnych przystanków oznaczonych gwiazdką.")];
            } else {
                [self confirm:3 title:RZL(@"Usunąć wszystkie gwiazdki z przystanków?") button:RZL(@"Wyczyść ulubione")];
            }
            break;
        default:
            break;
    }
}

- (void)say:(NSString *)title text:(NSString *)text
{
    UIAlertView *a = [[UIAlertView alloc] initWithTitle:title message:text delegate:nil
                                      cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [a show];
}

- (void)confirm:(int)what title:(NSString *)title button:(NSString *)button
{
    _pending = what;
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:title delegate:self
                                              cancelButtonTitle:RZL(@"Anuluj")
                                         destructiveButtonTitle:button
                                              otherButtonTitles:nil];
    [sheet showInView:self.tabBarController ? self.tabBarController.view : self.view];
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index
{
    if (index != sheet.destructiveButtonIndex) return;
    RZSchedule *sc = [RZSchedule shared];
    if (_pending == 1) {
        [sc removeExpiredFiles];
    } else if (_pending == 2) {
        [sc removeAllFiles];
    } else if (_pending == 4) {
        [[UIApplication sharedApplication] cancelAllLocalNotifications];
    } else if (_pending == 3) {
        [sc clearFavorites];
        [[NSNotificationCenter defaultCenter] postNotificationName:RZScheduleDidReloadNotification object:sc];
    }
    _pending = 0;
    [self.tableView reloadData];
}

- (void)openSite
{
    NSString *site = @RZ_SITE_URL;
    if (![site hasPrefix:@"http"]) {
        site = [[NSUserDefaults standardUserDefaults] stringForKey:@"site_base"];
    }
    if (![site hasPrefix:@"http"]) {
        [self say:RZL(@"Brak adresu strony") text:RZL(@"Otwórz w Safari stronę z rozkładem, wybierz przystanki i dotknij „Otwórz w aplikacji Rozkład”. Potem aplikacja zapamięta adres.")];
        return;
    }
    if ([site hasSuffix:@"/"]) site = [site stringByAppendingString:@"kreator/"];   /* kreator przystanków leży w podfolderze */
    NSString *sep = ([site rangeOfString:@"?"].location == NSNotFound) ? @"?" : @"&";
    site = [NSString stringWithFormat:@"%@%@lang=%@", site, sep, RZLangCode()];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:site]];
}

@end

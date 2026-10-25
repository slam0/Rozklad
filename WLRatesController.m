#import "WLRatesController.h"
#import "WLStore.h"
#import "WLTheme.h"
#import "WLLang.h"
#import "WLViews.h"
#import "WLRates.h"
#import "WLCurrencies.h"
#import "WLPickerController.h"

@interface WLRatesController ()
{
    UITableView *_table;
    UISearchBar *_search;
    UIView *_footer;
    UIButton *_footerButton;
    UILabel *_footerLabel;
    UIActivityIndicatorView *_spinner;
    NSArray *_sections;            /* [{title, items(kody)}] */
    NSString *_query;
}
@end

@implementation WLRatesController

- (id)init
{
    if ((self = [super init])) self.title = GL(@"Kursy");
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

static NSString *Fold(NSString *s)
{
    NSString *f = [s stringByFoldingWithOptions:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch locale:[NSLocale localeWithLocaleIdentifier:@"pl_PL"]];
    f = [f stringByReplacingOccurrencesOfString:@"ł" withString:@"l"];
    return [f stringByReplacingOccurrencesOfString:@"ё" withString:@"е"];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = WLBackgroundColor();
    _search = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    _search.delegate = self;
    _search.placeholder = GL(@"Szukaj waluty");
    WLStyleSearchBar(_search);
    _search.autocorrectionType = UITextAutocorrectionTypeNo;
    _search.autocapitalizationType = UITextAutocapitalizationTypeNone;

    _table = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _table.dataSource = self;
    _table.delegate = self;
    _table.tableHeaderView = _search;
    _table.rowHeight = 58;
    WLStyleTable(_table);
    [self.view addSubview:_table];

    _footer = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 70)];
    _footerLabel = [[UILabel alloc] initWithFrame:CGRectMake(12, 8, 296, 32)];
    _footerLabel.backgroundColor = [UIColor clearColor];
    _footerLabel.font = [UIFont systemFontOfSize:12.0f];
    _footerLabel.textColor = WLSubtleColor();
    _footerLabel.textAlignment = NSTextAlignmentCenter;
    _footerLabel.numberOfLines = 2;
    _footerLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [_footer addSubview:_footerLabel];
    _footerButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _footerButton.frame = CGRectMake(12, 40, 296, 26);
    _footerButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _footerButton.titleLabel.font = [UIFont boldSystemFontOfSize:13.0f];
    [_footerButton setTitleColor:WLAccentColor() forState:UIControlStateNormal];
    [_footerButton addTarget:self action:@selector(openSource) forControlEvents:UIControlEventTouchUpInside];
    [_footer addSubview:_footerButton];
    _table.tableFooterView = _footer;

    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ratesChanged) name:WLRatesDidChangeNotification object:nil];
    [self updateBarButtons];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self updateBarButtons];
    [self reloadList];
}

- (void)updateBarButtons
{
    self.navigationItem.leftBarButtonItem = WLBarButton([WLStore shared].ratesBase, self, @selector(pickBase));
    if ([WLRates shared].loading) {
        [_spinner startAnimating];
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:_spinner];
    } else {
        self.navigationItem.rightBarButtonItem = WLBarButton(GL(@"Odśwież"), self, @selector(refreshTapped));
    }
}

- (void)ratesChanged
{
    [self updateBarButtons];
    if (self.isViewLoaded) [self reloadList];
}

- (void)refreshTapped { [[WLRates shared] refreshNow]; }

- (void)pickBase
{
    WLStore *st = [WLStore shared];
    WLPickerController *p = [[WLPickerController alloc] init];
    p.title = GL(@"Waluta bazowa");
    p.selectedCode = st.ratesBase;
    __weak WLRatesController *me = self;
    p.onPick = ^(NSString *code) {
        st.ratesBase = code;
        [me.navigationController popViewControllerAnimated:YES];
    };
    [self.navigationController pushViewController:p animated:YES];
}

- (void)openSource
{
    NSString *url = [[WLRates shared] source] == WLSourceNBP ? @"https://nbp.pl" : @"https://www.exchangerate-api.com";
    WLOpenURL(url);
}

/* ---------- lista ---------- */

- (void)reloadList
{
    WLRates *r = [WLRates shared];
    WLStore *st = [WLStore shared];
    NSString *q = Fold(_query ? _query : @"");
    NSArray *words = [q componentsSeparatedByString:@" "];
    NSMutableArray *favs = [NSMutableArray array], *rest = [NSMutableArray array];
    for (NSString *code in [r codes]) {
        if ([code isEqualToString:st.ratesBase]) continue;
        if ([q length]) {
            NSString *hay = Fold(WLCurrencySearchText(code));
            BOOL ok = YES;
            for (NSString *w in words) {
                if ([w length] && [hay rangeOfString:w].location == NSNotFound) { ok = NO; break; }
            }
            if (!ok) continue;
        }
        if ([st isFavorite:code] && ![q length]) [favs addObject:code]; else [rest addObject:code];
    }
    NSMutableArray *secs = [NSMutableArray array];
    if ([favs count]) [secs addObject:[NSDictionary dictionaryWithObjectsAndKeys:GL(@"Ulubione"), @"title", favs, @"items", nil]];
    if ([rest count]) [secs addObject:[NSDictionary dictionaryWithObjectsAndKeys:GL([q length] ? @"Wyniki" : @"Wszystkie waluty"), @"title", rest, @"items", nil]];
    _sections = secs;

    if ([r source] == WLSourceNBP) {
        _footerLabel.text = GL(@"Kursy średnie Narodowego Banku Polskiego. Kursy są orientacyjne i nie służą do rozliczeń.");
        [_footerButton setTitle:@"Narodowy Bank Polski (nbp.pl)" forState:UIControlStateNormal];
    } else {
        _footerLabel.text = GL(@"Kursy orientacyjne, nie służą do rozliczeń. Kantory i banki stosują własne kursy.");
        [_footerButton setTitle:@"Rates By Exchange Rate API" forState:UIControlStateNormal];
    }
    [_footerButton setTitleColor:WLAccentColor() forState:UIControlStateNormal];
    [_table reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return (NSInteger)[_sections count]; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return (NSInteger)[[[_sections objectAtIndex:(NSUInteger)s] objectForKey:@"items"] count]; }
- (CGFloat)tableView:(UITableView *)t heightForHeaderInSection:(NSInteger)s { return 26; }

- (UIView *)tableView:(UITableView *)t viewForHeaderInSection:(NSInteger)s
{
    NSDictionary *sec = [_sections objectAtIndex:(NSUInteger)s];
    return WLHeaderForTitle([sec objectForKey:@"title"], [NSString stringWithFormat:@"1 %@ =", [WLStore shared].ratesBase]);
}

- (NSString *)codeAt:(NSIndexPath *)ip
{
    return [[[_sections objectAtIndex:(NSUInteger)ip.section] objectForKey:@"items"] objectAtIndex:(NSUInteger)ip.row];
}

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip
{
    WLCell *c = [WLCell cellForTable:t identifier:@"rate"];
    WLStore *st = [WLStore shared];
    NSString *code = [self codeAt:ip];
    double one = 0.0, back = 0.0;
    BOOL ok = [[WLRates shared] convert:1.0 from:st.ratesBase to:code result:&one];
    [[WLRates shared] convert:1.0 from:code to:st.ratesBase result:&back];
    c.textLabel.text = ok ? [NSString stringWithFormat:@"%@ %@", WLRateString(one), code] : code;
    c.detailTextLabel.text = ok ? [NSString stringWithFormat:@"%@ · 1 %@ = %@ %@", WLCurrencyName(code), code, WLRateString(back), st.ratesBase] : WLCurrencyName(code);
    UIButton *star = [UIButton buttonWithType:UIButtonTypeCustom];
    star.frame = CGRectMake(0, 0, 44, 44);
    [star setImage:WLStarImage([st isFavorite:code]) forState:UIControlStateNormal];
    star.tag = (NSInteger)[[[_sections objectAtIndex:(NSUInteger)ip.section] objectForKey:@"items"] indexOfObject:code] + 1000 * (ip.section + 1);
    [star addTarget:self action:@selector(starTapped:) forControlEvents:UIControlEventTouchUpInside];
    c.accessoryView = star;
    return c;
}

- (void)starTapped:(UIButton *)b
{
    NSInteger sec = b.tag / 1000 - 1, row = b.tag % 1000;
    if (sec < 0 || sec >= (NSInteger)[_sections count]) return;
    NSArray *items = [[_sections objectAtIndex:(NSUInteger)sec] objectForKey:@"items"];
    if (row < 0 || row >= (NSInteger)[items count]) return;
    [[WLStore shared] toggleFavorite:[items objectAtIndex:(NSUInteger)row]];
    [self reloadList];
}

/* dotknięcie waluty: przelicznik "z waluty bazowej na wybraną" i przejście do niego */
- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip
{
    [t deselectRowAtIndexPath:ip animated:YES];
    [_search resignFirstResponder];
    WLStore *st = [WLStore shared];
    st.fromCode = st.ratesBase;
    st.toCode = [self codeAt:ip];
    self.tabBarController.selectedIndex = 0;
}

- (void)searchBar:(UISearchBar *)sb textDidChange:(NSString *)text
{
    _query = [text copy];
    [self reloadList];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)sb { [sb resignFirstResponder]; }

@end

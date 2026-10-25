#import "WLPickerController.h"
#import "WLStore.h"
#import "WLTheme.h"
#import "WLLang.h"
#import "WLViews.h"
#import "WLRates.h"
#import "WLCurrencies.h"

@interface WLPickerController ()
{
    UITableView *_table;
    UISearchBar *_search;
    NSArray *_sections;            /* [{title, items(kody)}] */
    NSString *_query;
}
@end

@implementation WLPickerController

static NSString *Fold(NSString *s)
{
    NSString *f = [s stringByFoldingWithOptions:NSCaseInsensitiveSearch | NSDiacriticInsensitiveSearch locale:[NSLocale localeWithLocaleIdentifier:@"pl_PL"]];
    f = [f stringByReplacingOccurrencesOfString:@"ł" withString:@"l"];
    return [f stringByReplacingOccurrencesOfString:@"ё" withString:@"е"];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = GL(@"Waluta");
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
    _table.rowHeight = 50;
    WLStyleTable(_table);
    [self.view addSubview:_table];
    [self reloadList];
}

- (void)reloadList
{
    NSString *q = Fold(_query ? _query : @"");
    NSArray *words = [q componentsSeparatedByString:@" "];
    NSMutableArray *favs = [NSMutableArray array], *rest = [NSMutableArray array];
    WLStore *st = [WLStore shared];
    for (NSString *code in [[WLRates shared] codes]) {
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
    [_table reloadData];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)t { return (NSInteger)[_sections count]; }
- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return (NSInteger)[[[_sections objectAtIndex:(NSUInteger)s] objectForKey:@"items"] count]; }
- (CGFloat)tableView:(UITableView *)t heightForHeaderInSection:(NSInteger)s { return 26; }

- (UIView *)tableView:(UITableView *)t viewForHeaderInSection:(NSInteger)s
{
    NSDictionary *sec = [_sections objectAtIndex:(NSUInteger)s];
    return WLHeaderForTitle([sec objectForKey:@"title"], [NSString stringWithFormat:@"%lu", (unsigned long)[[sec objectForKey:@"items"] count]]);
}

- (NSString *)codeAt:(NSIndexPath *)ip
{
    return [[[_sections objectAtIndex:(NSUInteger)ip.section] objectForKey:@"items"] objectAtIndex:(NSUInteger)ip.row];
}

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip
{
    WLCell *c = [WLCell cellForTable:t identifier:@"cur"];
    NSString *code = [self codeAt:ip];
    c.textLabel.text = code;
    c.detailTextLabel.text = WLCurrencyName(code);
    c.accessoryType = [code isEqualToString:self.selectedCode] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return c;
}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip
{
    [t deselectRowAtIndexPath:ip animated:YES];
    [_search resignFirstResponder];
    if (self.onPick) self.onPick([self codeAt:ip]);
}

- (void)searchBar:(UISearchBar *)sb textDidChange:(NSString *)text
{
    _query = [text copy];
    [self reloadList];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)sb { [sb resignFirstResponder]; }

@end

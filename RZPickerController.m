#import "RZPickerController.h"
#import "RZLang.h"
#import "RZSchedule.h"
#import "RZViews.h"

@implementation RZPickerController {
    char _kind;
    NSArray *_stops;                 /* RZStop, alfabetycznie */
    NSArray *_details;               /* NSString: opis każdego słupka */
    NSMutableSet *_chosen;           /* klucze zaznaczonych przystanków */
    UIBarButtonItem *_toggle;
    void (^_done)(void);
}

- (id)initWithKind:(char)kind done:(void (^)(void))done
{
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        _kind = kind;
        _done = [done copy];
        RZSchedule *sc = [RZSchedule shared];
        _stops = [sc sortedStopsOfKind:kind];
        NSMutableArray *det = [NSMutableArray arrayWithCapacity:[_stops count]];
        for (RZStop *s in _stops) [det addObject:[sc descriptionForStop:s kind:kind]];
        _details = det;
        _chosen = [NSMutableSet set];
        for (RZStop *s in [sc selectedStopsOfKind:kind]) [_chosen addObject:s.key];
        self.title = RZL(@"Przystanki");
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    RZStyleTable(self.tableView);

    _toggle = [[UIBarButtonItem alloc] initWithTitle:@"" style:UIBarButtonItemStyleBordered
                                              target:self action:@selector(toggleAll)];
    self.navigationItem.leftBarButtonItem = [_stops count] ? _toggle : nil;
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:RZL(@"Gotowe") style:UIBarButtonItemStyleDone
                                        target:self action:@selector(doneTapped)];
    [self updateToggleTitle];
}

- (BOOL)allChosen
{
    return [_stops count] && [_chosen count] >= [_stops count];
}

- (void)updateToggleTitle
{
    _toggle.title = [self allChosen] ? RZL(@"Żadne") : RZL(@"Wszystkie");
}

- (void)toggleAll
{
    BOOL clear = [self allChosen];
    [_chosen removeAllObjects];
    if (!clear) {
        for (RZStop *s in _stops) [_chosen addObject:s.key];
    }
    [self updateToggleTitle];
    [self.tableView reloadData];
}

- (void)doneTapped
{
    NSMutableArray *picked = [NSMutableArray array];
    for (RZStop *s in _stops) {
        if ([_chosen containsObject:s.key]) [picked addObject:s];
    }
    [[RZSchedule shared] setSelectedStops:picked forKind:_kind];
    void (^done)(void) = _done;
    [self dismissViewControllerAnimated:YES completion:^{
        if (done) done();
    }];
}

#pragma mark - Tabela

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_stops count] ? (NSInteger)[_stops count] : 1;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section
{
    return RZSectionHeaderView([_stops count]
        ? RZL(@"Zaznacz przystanki, które chcesz widzieć:")
        : RZL(@"Brak przystanków"));
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section
{
    return 34.0f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return [_stops count] ? 56.0f : 80.0f;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *ident = @"stop";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ident];
    if (!cell) {
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:ident];
        cell.textLabel.font = [UIFont boldSystemFontOfSize:17.0f];
        cell.detailTextLabel.font = [UIFont systemFontOfSize:12.0f];
    }
    cell.textLabel.textColor = RZCellTextColor();
    cell.detailTextLabel.textColor = RZSubtleColor();
    if (![_stops count]) {
        cell.textLabel.text = RZL(@"W wczytanym rozkładzie nie ma tego rodzaju przystanków.");
        cell.textLabel.numberOfLines = 0;
        cell.detailTextLabel.text = nil;
        cell.accessoryType = UITableViewCellAccessoryNone;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        return cell;
    }
    RZStop *s = [_stops objectAtIndex:indexPath.row];
    cell.textLabel.numberOfLines = 1;
    cell.textLabel.text = s.title;
    cell.detailTextLabel.text = [_details objectAtIndex:indexPath.row];
    cell.accessoryType = [_chosen containsObject:s.key] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    cell.selectionStyle = UITableViewCellSelectionStyleBlue;
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    RZStyleCell(cell);
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (![_stops count]) return;
    RZStop *s = [_stops objectAtIndex:indexPath.row];
    if ([_chosen containsObject:s.key]) [_chosen removeObject:s.key]; else [_chosen addObject:s.key];
    [self updateToggleTitle];
    [tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
}

@end

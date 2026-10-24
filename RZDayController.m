#import "RZDayController.h"
#import "RZLang.h"
#import "RZViews.h"

static NSCalendar *RZDayCalendar(void)
{
    NSCalendar *cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    [cal setTimeZone:[NSTimeZone localTimeZone]];
    return cal;
}

@implementation RZDayController {
    NSDate *_selected;          /* wybrany dzień, godzina 12:00 */
    NSDate *_today;             /* dzisiaj, godzina 12:00 */
    NSDate *_last;              /* ostatni dzień ważności lub nil */
    NSArray *_quick;            /* dni pod przyciskami: dziś, jutro, najbliższa sobota, najbliższa niedziela */
    UILabel *_dayLabel;
    UISegmentedControl *_segments;
    UIDatePicker *_picker;
    UILabel *_note;
}

+ (NSDate *)noonOf:(NSDate *)date
{
    NSCalendar *cal = RZDayCalendar();
    NSDateComponents *c = [cal components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit) fromDate:date];
    [c setHour:12];
    return [cal dateFromComponents:c];
}

+ (BOOL)isSameDay:(NSDate *)a as:(NSDate *)b
{
    NSCalendar *cal = RZDayCalendar();
    NSUInteger u = NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit;
    NSDateComponents *x = [cal components:u fromDate:a];
    NSDateComponents *y = [cal components:u fromDate:b];
    return [x year] == [y year] && [x month] == [y month] && [x day] == [y day];
}

static NSLocale *RZAppLocale(void)
{
    NSString *code = RZLangCode();
    NSString *ident = [code isEqualToString:@"ru"] ? @"ru_RU" : ([code isEqualToString:@"en"] ? @"en_GB" : @"pl_PL");
    return [[NSLocale alloc] initWithLocaleIdentifier:ident];
}

+ (NSString *)stringForDay:(NSDate *)day long:(BOOL)isLong
{
    NSDateFormatter *f = [[NSDateFormatter alloc] init];
    [f setLocale:RZAppLocale()];
    [f setTimeZone:[NSTimeZone localTimeZone]];
    [f setDateFormat:isLong ? @"EEEE, d MMMM yyyy" : @"EEE d.MM"];
    return [f stringFromDate:day];
}

- (id)initWithDay:(NSDate *)day lastDay:(NSDate *)lastDay
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        self.title = RZL(@"Wybierz dzień");
        self.hidesBottomBarWhenPushed = YES;
        _today = [RZDayController noonOf:[NSDate date]];
        _selected = day ? [RZDayController noonOf:day] : _today;
        _last = lastDay ? [RZDayController noonOf:lastDay] : nil;
        if ([_selected compare:_today] == NSOrderedAscending) _selected = _today;
        if (_last && [_selected compare:_last] == NSOrderedDescending) _selected = _last;
    }
    return self;
}

/* Najbliższy dzień tygodnia (1 = niedziela ... 7 = sobota) po dzisiejszym */
- (NSDate *)nextWeekday:(NSInteger)weekday
{
    NSCalendar *cal = RZDayCalendar();
    for (int i = 1; i <= 7; i++) {
        NSDateComponents *off = [[NSDateComponents alloc] init];
        [off setDay:i];
        NSDate *d = [cal dateByAddingComponents:off toDate:_today options:0];
        if ([[cal components:NSWeekdayCalendarUnit fromDate:d] weekday] == weekday) return d;
    }
    return _today;
}

- (BOOL)inRange:(NSDate *)d
{
    if ([d compare:_today] == NSOrderedAscending) return NO;
    if (_last && [d compare:_last] == NSOrderedDescending) return NO;
    return YES;
}

#pragma mark - Widok

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = RZPaperColor();
    CGFloat w = self.view.bounds.size.width;

    NSCalendar *cal = RZDayCalendar();
    NSDateComponents *one = [[NSDateComponents alloc] init];
    [one setDay:1];
    _quick = [NSArray arrayWithObjects:_today,
              [cal dateByAddingComponents:one toDate:_today options:0],
              [self nextWeekday:7],
              [self nextWeekday:1], nil];

    _dayLabel = [[UILabel alloc] initWithFrame:CGRectMake(14, 14, w - 28, 28)];
    _dayLabel.backgroundColor = [UIColor clearColor];
    _dayLabel.font = [UIFont boldSystemFontOfSize:19.0f];
    _dayLabel.textColor = RZInkColor();
    _dayLabel.textAlignment = NSTextAlignmentCenter;
    _dayLabel.adjustsFontSizeToFitWidth = YES;
    _dayLabel.minimumScaleFactor = 0.7f;
    _dayLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:_dayLabel];

    NSArray *items = [NSArray arrayWithObjects:
        RZL(@"Dziś"), RZL(@"Jutro"),
        [RZDayController stringForDay:[_quick objectAtIndex:2] long:NO],
        [RZDayController stringForDay:[_quick objectAtIndex:3] long:NO], nil];
    _segments = [[UISegmentedControl alloc] initWithItems:items];
    _segments.segmentedControlStyle = UISegmentedControlStyleBar;
    _segments.tintColor = RZBrownColor();
    _segments.frame = CGRectMake(10, 50, w - 20, 32);
    _segments.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    for (NSInteger i = 0; i < 4; i++) [_segments setEnabled:[self inRange:[_quick objectAtIndex:(NSUInteger)i]] forSegmentAtIndex:i];
    [_segments addTarget:self action:@selector(quickTapped:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_segments];

    _picker = [[UIDatePicker alloc] initWithFrame:CGRectMake(0, 92, w, 216)];
    _picker.datePickerMode = UIDatePickerModeDate;
    _picker.minimumDate = _today;
    if (_last) _picker.maximumDate = _last;
    _picker.date = _selected;
    _picker.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [_picker addTarget:self action:@selector(pickerChanged:) forControlEvents:UIControlEventValueChanged];
    [self.view addSubview:_picker];

    _note = [[UILabel alloc] initWithFrame:CGRectMake(20, 318, w - 40, 60)];
    _note.backgroundColor = [UIColor clearColor];
    _note.font = [UIFont systemFontOfSize:13.0f];
    _note.textColor = RZSubtleColor();
    _note.numberOfLines = 3;
    _note.textAlignment = NSTextAlignmentCenter;
    _note.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    if (_last) {
        _note.text = [NSString stringWithFormat:RZL(@"Rozkład w telefonie jest ważny do %@."), [RZDayController stringForDay:_last long:YES]];
    } else {
        _note.text = RZL(@"Rozkład w telefonie nie podaje daty końca ważności.");
    }
    [self.view addSubview:_note];

    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:RZL(@"Dziś") style:UIBarButtonItemStyleBordered target:self action:@selector(todayTapped)];
    [self refreshLabels];
}

- (void)refreshLabels
{
    _dayLabel.text = [RZDayController stringForDay:_selected long:YES];
    NSInteger match = UISegmentedControlNoSegment;
    for (NSInteger i = 0; i < 4; i++) {
        if ([RZDayController isSameDay:[_quick objectAtIndex:(NSUInteger)i] as:_selected]) { match = i; break; }
    }
    _segments.selectedSegmentIndex = match;
}

/* Zapamiętuje wybór i daje znać ekranowi przystanku (nil = dzisiaj). */
- (void)choose:(NSDate *)day animated:(BOOL)animated
{
    NSDate *d = [RZDayController noonOf:day];
    if (![self inRange:d]) return;
    _selected = d;
    [_picker setDate:d animated:animated];
    [self refreshLabels];
    if (self.onChange) self.onChange([RZDayController isSameDay:d as:_today] ? nil : d);
}

- (void)pickerChanged:(UIDatePicker *)p
{
    [self choose:p.date animated:NO];
}

- (void)quickTapped:(UISegmentedControl *)s
{
    NSInteger i = s.selectedSegmentIndex;
    if (i >= 0 && i < 4) [self choose:[_quick objectAtIndex:(NSUInteger)i] animated:YES];
}

- (void)todayTapped
{
    [self choose:_today animated:YES];
}

@end

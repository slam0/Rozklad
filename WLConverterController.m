#import "WLConverterController.h"
#import "WLStore.h"
#import "WLTheme.h"
#import "WLLang.h"
#import "WLViews.h"
#import "WLRates.h"
#import "WLCurrencies.h"
#import "WLPickerController.h"
#import "wl_core.h"
#import "WLCrash.h"

@interface WLConverterController ()
{
    UITableView *_table;
    UIView *_head;
    UITextField *_field;
    UIImageView *_resultTile;
    UILabel *_resultLabel;
    UIButton *_fromButton, *_toButton;
    UILabel *_fromName, *_toName, *_rateLabel, *_statusLabel;
    UIActivityIndicatorView *_spinner;
    NSString *_toast;
    double _lastResult;
    BOOL _hasResult;
}
@end

@implementation WLConverterController

- (id)init
{
    if ((self = [super init])) self.title = GL(@"Przelicznik");
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

/* ---------- budowa ekranu ---------- */

- (UILabel *)labelAt:(CGRect)f size:(CGFloat)size bold:(BOOL)bold color:(UIColor *)color align:(NSTextAlignment)a
{
    UILabel *l = [[UILabel alloc] initWithFrame:f];
    l.backgroundColor = [UIColor clearColor];
    l.font = bold ? [UIFont boldSystemFontOfSize:size] : [UIFont systemFontOfSize:size];
    l.textColor = color;
    l.textAlignment = a;
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    return l;
}

- (UIButton *)currencyButtonAt:(CGRect)f action:(SEL)action
{
    UIButton *b = WLGelButton(@"", 0, f);
    b.titleLabel.font = [UIFont boldSystemFontOfSize:20.0f];
    b.titleEdgeInsets = UIEdgeInsetsMake(0, 0, 0, 14);
    UIImageView *tri = [[UIImageView alloc] initWithImage:WLTriangleImage()];
    tri.frame = CGRectMake(f.size.width - 22, (f.size.height - 8) / 2, 12, 8);
    tri.alpha = 0.9f;
    [b addSubview:tri];
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    b.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    return b;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    WLCrumb(@"przelicznik: budowa ekranu");
    self.view.backgroundColor = WLBackgroundColor();
    const WLPalette *p = WLP();
    UIColor *fieldText = WLRGB(p->fieldText, 1);

    _head = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 246)];
    _head.autoresizingMask = UIViewAutoresizingFlexibleWidth;

    _field = [[UITextField alloc] initWithFrame:CGRectMake(12, 14, 190, 46)];
    _field.background = WLFieldImage();
    _field.borderStyle = UITextBorderStyleNone;
    _field.font = [UIFont boldSystemFontOfSize:24.0f];
    _field.textColor = fieldText;
    _field.textAlignment = NSTextAlignmentRight;
    _field.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    _field.keyboardType = UIKeyboardTypeDecimalPad;
    _field.keyboardAppearance = UIKeyboardAppearanceAlert;
    _field.adjustsFontSizeToFitWidth = YES;
    _field.minimumFontSize = 14.0f;
    _field.placeholder = @"0";
    _field.delegate = self;
    _field.inputAccessoryView = WLKeyboardToolbar(self, @selector(dismissKeyboard));
    UIView *pad = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
    _field.leftView = pad;
    _field.leftViewMode = UITextFieldViewModeAlways;
    UIView *pad2 = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 10, 10)];
    _field.rightView = pad2;
    _field.rightViewMode = UITextFieldViewModeAlways;
    [_field addTarget:self action:@selector(amountChanged) forControlEvents:UIControlEventEditingChanged];
    [_head addSubview:_field];

    _fromButton = [self currencyButtonAt:CGRectMake(210, 14, 98, 46) action:@selector(pickFrom)];
    [_head addSubview:_fromButton];
    _fromName = [self labelAt:CGRectMake(16, 62, 150, 16) size:12.0f bold:NO color:WLSubtleColor() align:NSTextAlignmentLeft];
    _fromName.autoresizingMask = UIViewAutoresizingFlexibleRightMargin;
    [_head addSubview:_fromName];

    UIButton *swap = WLGelButton(@"", 1, CGRectMake(136, 66, 48, 34));
    [swap setImage:WLSwapImage() forState:UIControlStateNormal];
    [swap addTarget:self action:@selector(swapCurrencies) forControlEvents:UIControlEventTouchUpInside];
    swap.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [_head addSubview:swap];

    _resultTile = [[UIImageView alloc] initWithImage:WLFieldImage()];
    _resultTile.frame = CGRectMake(12, 108, 190, 46);
    _resultTile.userInteractionEnabled = YES;
    [_head addSubview:_resultTile];
    _resultLabel = [self labelAt:CGRectMake(10, 0, 170, 46) size:24.0f bold:YES color:fieldText align:NSTextAlignmentRight];
    _resultLabel.adjustsFontSizeToFitWidth = YES;
    _resultLabel.minimumScaleFactor = 0.55f;
    _resultLabel.autoresizingMask = UIViewAutoresizingNone;
    [_resultTile addSubview:_resultLabel];
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(copyResult)];
    [_resultTile addGestureRecognizer:tap];

    _toButton = [self currencyButtonAt:CGRectMake(210, 108, 98, 46) action:@selector(pickTo)];
    [_head addSubview:_toButton];
    _toName = [self labelAt:CGRectMake(16, 156, 290, 16) size:12.0f bold:NO color:WLSubtleColor() align:NSTextAlignmentLeft];
    [_head addSubview:_toName];

    _rateLabel = [self labelAt:CGRectMake(12, 176, 296, 20) size:15.0f bold:YES color:WLTextColor() align:NSTextAlignmentCenter];
    WLStyleShadow(_rateLabel);
    [_head addSubview:_rateLabel];

    _statusLabel = [self labelAt:CGRectMake(12, 198, 296, 44) size:12.0f bold:NO color:WLSubtleColor() align:NSTextAlignmentCenter];
    _statusLabel.numberOfLines = 3;
    [_head addSubview:_statusLabel];

    _table = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
    _table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _table.dataSource = self;
    _table.delegate = self;
    _table.rowHeight = 56;
    _table.tableHeaderView = _head;
    WLStyleTable(_table);
    [self.view addSubview:_table];

    _spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(ratesChanged) name:WLRatesDidChangeNotification object:nil];
    [self updateBarButton];
    WLCrumb(@"przelicznik: ekran zbudowany");
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    _field.text = [WLStore shared].amountText;
    [self update];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[WLStore shared] save];
}

/* ---------- działania ---------- */

- (void)dismissKeyboard { [_field resignFirstResponder]; }

- (void)amountChanged
{
    [WLStore shared].amountText = _field.text;
    [self update];
}

- (BOOL)textField:(UITextField *)tf shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)s
{
    NSString *t = [tf.text stringByReplacingCharactersInRange:range withString:s];
    return [t length] <= 16;
}

- (void)swapCurrencies
{
    WLStore *st = [WLStore shared];
    NSString *a = st.fromCode;
    st.fromCode = st.toCode;
    st.toCode = a;
    [self update];
}

- (void)pickCurrencyForFrom:(BOOL)isFrom
{
    [_field resignFirstResponder];
    WLStore *st = [WLStore shared];
    WLPickerController *p = [[WLPickerController alloc] init];
    p.selectedCode = isFrom ? st.fromCode : st.toCode;
    __weak WLConverterController *me = self;
    p.onPick = ^(NSString *code) {
        if (isFrom) st.fromCode = code; else st.toCode = code;
        [me.navigationController popViewControllerAnimated:YES];
    };
    [self.navigationController pushViewController:p animated:YES];
}

- (void)pickFrom { [self pickCurrencyForFrom:YES]; }
- (void)pickTo { [self pickCurrencyForFrom:NO]; }

- (void)showToast:(NSString *)text
{
    _toast = [text copy];
    [self updateStatus];
    NSString *mine = _toast;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (_toast == mine) { _toast = nil; [self updateStatus]; }
    });
}

- (void)copyResult
{
    if (!_hasResult) return;
    [UIPasteboard generalPasteboard].string = WLEditNumber(_lastResult);
    [self showToast:GL(@"Wynik skopiowany")];
}

- (void)refreshTapped
{
    if (![[WLRates shared] refreshNow] && !([WLRates shared].loading)) [self showToast:GL(@"Kursy są aktualne (pobrane przed chwilą)")];
}

- (void)updateBarButton
{
    if ([WLRates shared].loading) {
        [_spinner startAnimating];
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:_spinner];
    } else {
        self.navigationItem.rightBarButtonItem = WLBarButton(GL(@"Odśwież"), self, @selector(refreshTapped));
    }
}

- (void)ratesChanged
{
    [self updateBarButton];
    if (self.isViewLoaded) [self update];
}

/* ---------- odświeżanie widoku ---------- */

- (void)updateStatus
{
    WLRates *r = [WLRates shared];
    NSString *text;
    UIColor *color = WLSubtleColor();
    if (_toast) {
        text = _toast;
    } else if (r.loading) {
        text = GL(@"Pobieram kursy…");
    } else if (![r hasRates]) {
        text = r.errorText ? r.errorText : GL(@"Brak kursów. Połącz się z internetem i dotknij Odśwież.");
        color = WLRGB(WLP()->danger, 1);
    } else {
        NSDate *d = [r updatedDate] ? [r updatedDate] : [r fetchedDate];
        text = [NSString stringWithFormat:GL(@"Kursy z %@ · %@"), d ? WLDateString([d timeIntervalSince1970]) : @"?", [r sourceName]];
        if (r.errorText) {
            text = [text stringByAppendingFormat:@"\n%@", r.errorText];
            color = WLRGB(WLP()->danger, 1);
        } else if ([r fetchedAgeDays] >= 3) {
            text = [text stringByAppendingFormat:@"\n%@", GL(@"Kursy mogą być nieaktualne")];
            color = WLRGB(WLP()->danger, 1);
        }
    }
    _statusLabel.text = text;
    _statusLabel.textColor = color;
}

- (void)setButton:(UIButton *)b code:(NSString *)code
{
    [b setTitle:code forState:UIControlStateNormal];
}

- (void)update
{
    WLCrumb(@"przelicznik: odświeżanie");
    WLStore *st = [WLStore shared];
    WLRates *r = [WLRates shared];
    NSString *from = st.fromCode, *to = st.toCode;
    [self setButton:_fromButton code:from];
    [self setButton:_toButton code:to];
    _fromName.text = WLCurrencyName(from);
    _toName.text = WLCurrencyName(to);

    NSString *txt = [_field.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    double amt = [txt length] ? WLParseNumber(txt) : 0.0;
    double out = 0.0;
    _hasResult = amt >= 0.0 && [r convert:amt from:from to:to result:&out];
    _lastResult = out;
    _resultLabel.text = _hasResult ? WLMoneyString(out) : @"—";

    double one;
    if ([r convert:1.0 from:from to:to result:&one]) {
        _rateLabel.text = [NSString stringWithFormat:@"1 %@ = %@ %@", from, WLRateString(one), to];
    } else {
        _rateLabel.text = @"";
    }
    [self updateStatus];
    WLCrumb(@"przelicznik: lista");
    [_table reloadData];
    WLCrumb(@"przelicznik: gotowy");
}

/* ---------- lista ulubionych ---------- */

- (NSArray *)rowCodes
{
    NSMutableArray *a = [NSMutableArray array];
    WLStore *st = [WLStore shared];
    for (NSString *c in st.favorites) {
        if (![c isEqualToString:st.fromCode] && [[WLRates shared] hasCode:c]) [a addObject:c];
    }
    return a;
}

- (NSInteger)tableView:(UITableView *)t numberOfRowsInSection:(NSInteger)s { return (NSInteger)[[self rowCodes] count]; }
- (CGFloat)tableView:(UITableView *)t heightForHeaderInSection:(NSInteger)s { return 26; }

- (UIView *)tableView:(UITableView *)t viewForHeaderInSection:(NSInteger)s
{
    NSString *right = nil;
    if ([[WLRates shared] hasRates]) {
        double amt = WLParseNumber(_field.text);
        right = [NSString stringWithFormat:@"%@ %@", amt >= 0 ? WLMoneyString(amt) : @"0", [WLStore shared].fromCode];
    }
    return WLHeaderForTitle(GL(@"Ulubione waluty"), right);
}

- (UITableViewCell *)tableView:(UITableView *)t cellForRowAtIndexPath:(NSIndexPath *)ip
{
    WLCell *c = [WLCell cellForTable:t identifier:@"fav"];
    WLStore *st = [WLStore shared];
    NSString *code = [[self rowCodes] objectAtIndex:(NSUInteger)ip.row];
    NSString *txt = [_field.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    double amt = [txt length] ? WLParseNumber(txt) : 0.0;
    double out = 0.0, one = 0.0;
    BOOL ok = amt >= 0.0 && [[WLRates shared] convert:amt from:st.fromCode to:code result:&out];
    c.textLabel.text = [NSString stringWithFormat:@"%@ %@", ok ? WLMoneyString(out) : @"—", code];
    if ([[WLRates shared] convert:1.0 from:st.fromCode to:code result:&one]) {
        c.detailTextLabel.text = [NSString stringWithFormat:@"%@ · 1 %@ = %@ %@", WLCurrencyName(code), st.fromCode, WLRateString(one), code];
    } else {
        c.detailTextLabel.text = WLCurrencyName(code);
    }
    c.accessoryType = [code isEqualToString:st.toCode] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
    return c;
}

- (void)tableView:(UITableView *)t didSelectRowAtIndexPath:(NSIndexPath *)ip
{
    [t deselectRowAtIndexPath:ip animated:YES];
    [WLStore shared].toCode = [[self rowCodes] objectAtIndex:(NSUInteger)ip.row];
    [self update];
}

@end

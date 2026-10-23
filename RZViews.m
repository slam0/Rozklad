#import "RZViews.h"
#import "RZSchedule.h"
#import <QuartzCore/QuartzCore.h>

#pragma mark - Kolory

static UIColor *RGB(int r, int g, int b)
{
    return [UIColor colorWithRed:r / 255.0f green:g / 255.0f blue:b / 255.0f alpha:1.0f];
}

UIColor *RZBrownColor(void)
{
    return [UIColor colorWithRed:0.42f green:0.27f blue:0.16f alpha:1.0f];
}

UIColor *RZLinenColor(void)
{
    /* Len z iOS 6 (zniknął w nowszych SDK, więc wołamy go przez nazwę) */
    UIColor *c = nil;
    SEL sel = NSSelectorFromString(@"scrollViewTexturedBackgroundColor");
    if ([UIColor respondsToSelector:sel]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        c = [UIColor performSelector:sel];
#pragma clang diagnostic pop
    }
    return c ? c : RGB(216, 211, 197);
}

static void RZKindColors(char kind, NSString *line, UIColor **top, UIColor **bottom, UIColor **border)
{
    switch (kind) {
        case 't':   /* tramwaj: niebieski */
            *top = RGB(90, 165, 245); *bottom = RGB(27, 98, 200); *border = RGB(15, 60, 130);
            break;
        case 'p':   /* pociąg: zielony */
            *top = RGB(110, 190, 110); *bottom = RGB(36, 120, 48); *border = RGB(20, 75, 28);
            break;
        case 'm':   /* metro: M1 granatowe, M2 czerwone */
            if ([line hasPrefix:@"M2"]) {
                *top = RGB(232, 80, 95); *bottom = RGB(166, 15, 37); *border = RGB(109, 7, 21);
            } else {
                *top = RGB(80, 110, 215); *bottom = RGB(25, 45, 140); *border = RGB(15, 25, 90);
            }
            break;
        default:    /* autobus: czerwony */
            *top = RGB(232, 80, 95); *bottom = RGB(166, 15, 37); *border = RGB(109, 7, 21);
            break;
    }
}

#pragma mark - Ikony zakładek (rysowane kodem, bez plików PNG)

UIImage *RZTabIcon(char kind)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(30, 30), NO, 0.0f);
    CGContextRef c = UIGraphicsGetCurrentContext();
    [[UIColor blackColor] setFill];
    [[UIColor blackColor] setStroke];

    switch (kind) {
        case 't': {   /* tramwaj */
            [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(3, 8, 24, 15) cornerRadius:4] fill];
            [[UIBezierPath bezierPathWithRect:CGRectMake(6, 11, 5, 5)] fillWithBlendMode:kCGBlendModeClear alpha:1.0f];
            [[UIBezierPath bezierPathWithRect:CGRectMake(12.5f, 11, 5, 5)] fillWithBlendMode:kCGBlendModeClear alpha:1.0f];
            [[UIBezierPath bezierPathWithRect:CGRectMake(19, 11, 5, 5)] fillWithBlendMode:kCGBlendModeClear alpha:1.0f];
            CGContextSetLineWidth(c, 2.0f);
            CGContextMoveToPoint(c, 15, 8);  CGContextAddLineToPoint(c, 15, 4);
            CGContextMoveToPoint(c, 9, 3.5f); CGContextAddLineToPoint(c, 21, 3.5f);
            CGContextStrokePath(c);
            [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(7, 21, 5, 5)] fill];
            [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(18, 21, 5, 5)] fill];
            CGContextFillRect(c, CGRectMake(2, 27, 26, 1.5f));
            break;
        }
        case 'p': {   /* pociąg */
            [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(7, 2, 16, 21) cornerRadius:5] fill];
            [[UIBezierPath bezierPathWithRect:CGRectMake(10, 6, 10, 7)] fillWithBlendMode:kCGBlendModeClear alpha:1.0f];
            [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(10, 16.5f, 3, 3)] fillWithBlendMode:kCGBlendModeClear alpha:1.0f];
            [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(17, 16.5f, 3, 3)] fillWithBlendMode:kCGBlendModeClear alpha:1.0f];
            CGContextSetLineWidth(c, 2.0f);
            CGContextMoveToPoint(c, 11, 23);  CGContextAddLineToPoint(c, 8, 28);
            CGContextMoveToPoint(c, 19, 23);  CGContextAddLineToPoint(c, 22, 28);
            CGContextStrokePath(c);
            break;
        }
        case 'm': {   /* metro: koło z literą M */
            [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(2, 2, 26, 26)] fill];
            UIBezierPath *m = [UIBezierPath bezierPath];
            [m moveToPoint:CGPointMake(8, 21)];
            [m addLineToPoint:CGPointMake(8, 9)];
            [m addLineToPoint:CGPointMake(15, 17)];
            [m addLineToPoint:CGPointMake(22, 9)];
            [m addLineToPoint:CGPointMake(22, 21)];
            m.lineWidth = 3.0f;
            [m strokeWithBlendMode:kCGBlendModeClear alpha:1.0f];
            break;
        }
        default: {    /* autobus */
            [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(5, 3, 20, 20) cornerRadius:4] fill];
            [[UIBezierPath bezierPathWithRect:CGRectMake(8, 6, 14, 7)] fillWithBlendMode:kCGBlendModeClear alpha:1.0f];
            [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(8, 16, 3.5f, 3.5f)] fillWithBlendMode:kCGBlendModeClear alpha:1.0f];
            [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(18.5f, 16, 3.5f, 3.5f)] fillWithBlendMode:kCGBlendModeClear alpha:1.0f];
            [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(7, 21, 5, 6)] fill];
            [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(18, 21, 5, 6)] fill];
            break;
        }
    }

    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

#pragma mark - Skóra, papier i napisy

UIColor *RZPaperColor(void)
{
    UIImage *img = [UIImage imageNamed:@"bg_paper.png"];
    return img ? [UIColor colorWithPatternImage:img] : RGB(238, 230, 211);
}

UIColor *RZInkColor(void)
{
    return RGB(74, 46, 24);
}

static UIColor *RZLeatherButtonColor(void)
{
    return RGB(66, 38, 18);
}

void RZStyleNavigationBar(UINavigationBar *bar)
{
    UIImage *bg = [UIImage imageNamed:@"nav_leather.png"];
    if (bg) [bar setBackgroundImage:bg forBarMetrics:UIBarMetricsDefault];
    bar.tintColor = RZLeatherButtonColor();     /* przyciski jak wytłoczone w skórze */
    bar.titleTextAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
        [UIColor whiteColor], UITextAttributeTextColor,
        [UIColor colorWithWhite:0.0f alpha:0.75f], UITextAttributeTextShadowColor,
        [NSValue valueWithUIOffset:UIOffsetMake(0, -1)], UITextAttributeTextShadowOffset,
        [UIFont boldSystemFontOfSize:20.0f], UITextAttributeFont,
        nil];
}

void RZStyleTabBar(UITabBar *bar)
{
    UIImage *bg = [UIImage imageNamed:@"tab_leather.png"];
    if (bg) bar.backgroundImage = bg;
    UIImage *sel = [UIImage imageNamed:@"tab_select.png"];
    if (sel) bar.selectionIndicatorImage = sel;
}

/* Ikona z maski (kształt z RZTabIcon) pomalowana jednym kolorem */
static UIImage *RZTabIconTinted(char kind, UIColor *color)
{
    UIImage *mask = RZTabIcon(kind);
    CGRect r = CGRectMake(0, 0, mask.size.width, mask.size.height);
    UIGraphicsBeginImageContextWithOptions(r.size, NO, 0.0f);
    CGContextRef c = UIGraphicsGetCurrentContext();
    [mask drawInRect:r];
    CGContextSetBlendMode(c, kCGBlendModeSourceIn);
    [color setFill];
    CGContextFillRect(c, r);
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

void RZStyleTabItem(UITabBarItem *item, char kind)
{
    UIColor *off = RGB(214, 196, 164);      /* kremowy: dobrze widoczny na ciemnej skórze */
    UIColor *on = RGB(255, 232, 160);       /* złocisty: zaznaczona zakładka */
    [item setFinishedSelectedImage:RZTabIconTinted(kind, on)
       withFinishedUnselectedImage:RZTabIconTinted(kind, off)];
    NSValue *offset = [NSValue valueWithUIOffset:UIOffsetMake(0, -1)];
    UIColor *shadow = [UIColor colorWithWhite:0.0f alpha:0.8f];
    [item setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
        off, UITextAttributeTextColor, shadow, UITextAttributeTextShadowColor,
        offset, UITextAttributeTextShadowOffset, nil] forState:UIControlStateNormal];
    [item setTitleTextAttributes:[NSDictionary dictionaryWithObjectsAndKeys:
        on, UITextAttributeTextColor, shadow, UITextAttributeTextShadowColor,
        offset, UITextAttributeTextShadowOffset, nil] forState:UIControlStateSelected];
}

UIView *RZSectionHeaderView(NSString *text)
{
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 34)];
    v.backgroundColor = [UIColor clearColor];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(20, 8, 280, 22)];
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    l.backgroundColor = [UIColor clearColor];
    l.font = [UIFont boldSystemFontOfSize:17.0f];
    l.textColor = RZInkColor();
    l.shadowColor = [UIColor colorWithWhite:1.0f alpha:0.85f];
    l.shadowOffset = CGSizeMake(0, 1);
    l.text = text;
    [v addSubview:l];
    return v;
}

UIView *RZSectionFooterView(NSString *text)
{
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 44)];
    v.backgroundColor = [UIColor clearColor];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(20, 8, 280, 30)];
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    l.backgroundColor = [UIColor clearColor];
    l.font = [UIFont systemFontOfSize:12.0f];
    l.textColor = RGB(104, 84, 62);
    l.shadowColor = [UIColor colorWithWhite:1.0f alpha:0.85f];
    l.shadowOffset = CGSizeMake(0, 1);
    l.textAlignment = NSTextAlignmentCenter;
    l.numberOfLines = 2;
    l.text = text;
    [v addSubview:l];
    return v;
}

#pragma mark - Znaczek z numerem linii

@implementation RZBadge {
    CALayer *_gloss;
}

+ (Class)layerClass
{
    return [CAGradientLayer class];
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
        CALayer *l = self.layer;
        l.cornerRadius = 6.0f;
        l.borderWidth = 1.0f;
        l.masksToBounds = YES;     /* przycina gradient i połysk do zaokrąglonych rogów */

        _gloss = [CALayer layer];
        _gloss.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.20f].CGColor;
        [l addSublayer:_gloss];

        _label = [[UILabel alloc] initWithFrame:self.bounds];
        _label.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        _label.backgroundColor = [UIColor clearColor];
        _label.textColor = [UIColor whiteColor];
        _label.textAlignment = NSTextAlignmentCenter;
        _label.font = [UIFont boldSystemFontOfSize:16.0f];
        _label.shadowColor = [UIColor colorWithWhite:0 alpha:0.5f];
        _label.shadowOffset = CGSizeMake(0, -1);
        _label.adjustsFontSizeToFitWidth = YES;
        _label.minimumScaleFactor = 0.5f;
        [self addSubview:_label];
        [self setLine:@"" kind:'b'];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    _gloss.frame = CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height / 2.0f);
}

- (void)setLine:(NSString *)line kind:(char)kind
{
    UIColor *top, *bottom, *border;
    RZKindColors(kind, line, &top, &bottom, &border);
    CAGradientLayer *g = (CAGradientLayer *)self.layer;
    g.colors = [NSArray arrayWithObjects:(__bridge id)top.CGColor, (__bridge id)bottom.CGColor, nil];
    g.borderColor = border.CGColor;
    _label.text = line;
}

@end

#pragma mark - Wiersz odjazdu

@implementation RZDepartureCell {
    RZBadge *_badge;
    UILabel *_head;
    UILabel *_time;
    UILabel *_eta;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;

        _badge = [[RZBadge alloc] initWithFrame:CGRectMake(10, 14, 58, 28)];
        [self.contentView addSubview:_badge];

        _head = [[UILabel alloc] init];
        _head.backgroundColor = [UIColor clearColor];
        _head.font = [UIFont boldSystemFontOfSize:15.0f];
        _head.numberOfLines = 2;
        _head.lineBreakMode = NSLineBreakByTruncatingTail;
        _head.shadowColor = [UIColor whiteColor];
        _head.shadowOffset = CGSizeMake(0, 1);
        [self.contentView addSubview:_head];

        _time = [[UILabel alloc] init];
        _time.backgroundColor = [UIColor clearColor];
        _time.font = [UIFont boldSystemFontOfSize:17.0f];
        _time.textAlignment = NSTextAlignmentRight;
        _time.shadowColor = [UIColor whiteColor];
        _time.shadowOffset = CGSizeMake(0, 1);
        [self.contentView addSubview:_time];

        _eta = [[UILabel alloc] init];
        _eta.backgroundColor = [UIColor clearColor];
        _eta.font = [UIFont systemFontOfSize:12.0f];
        _eta.textColor = [UIColor grayColor];
        _eta.textAlignment = NSTextAlignmentRight;
        _eta.adjustsFontSizeToFitWidth = YES;
        _eta.minimumScaleFactor = 0.7f;
        [self.contentView addSubview:_eta];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect b = self.contentView.bounds;
    CGFloat h = b.size.height;
    _badge.frame = CGRectMake(10, (h - 28) / 2.0f, 58, 28);
    _time.frame = CGRectMake(b.size.width - 108, 7, 98, 22);
    _eta.frame = CGRectMake(b.size.width - 108, 30, 98, 18);
    _head.frame = CGRectMake(78, 0, b.size.width - 78 - 112, h);
}

- (void)setDeparture:(RZDeparture *)dep nowMinutes:(NSInteger)now
{
    [_badge setLine:dep.line kind:dep.kind];
    _head.text = dep.head;
    _time.text = [RZSchedule clockString:dep.time];
    _eta.text = [RZSchedule etaString:dep.time - now];
}

@end

#pragma mark - Bilet z najbliższym odjazdem

@implementation RZTicketCell {
    UILabel *_caption;
    RZBadge *_badge;
    UILabel *_head;
    UILabel *_eta;
    UILabel *_clock;
    CAShapeLayer *_tear;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.contentView.backgroundColor = [UIColor colorWithRed:0.97f green:0.94f blue:0.86f alpha:1.0f];

        _caption = [[UILabel alloc] init];
        _caption.backgroundColor = [UIColor clearColor];
        _caption.font = [UIFont systemFontOfSize:13.0f];
        _caption.textColor = [UIColor colorWithRed:0.54f green:0.51f blue:0.44f alpha:1.0f];
        _caption.shadowColor = [UIColor whiteColor];
        _caption.shadowOffset = CGSizeMake(0, 1);
        [self.contentView addSubview:_caption];

        _badge = [[RZBadge alloc] initWithFrame:CGRectMake(12, 30, 76, 44)];
        _badge.label.font = [UIFont boldSystemFontOfSize:26.0f];
        [self.contentView addSubview:_badge];

        _head = [[UILabel alloc] init];
        _head.backgroundColor = [UIColor clearColor];
        _head.font = [UIFont boldSystemFontOfSize:20.0f];
        _head.numberOfLines = 2;
        _head.shadowColor = [UIColor whiteColor];
        _head.shadowOffset = CGSizeMake(0, 1);
        [self.contentView addSubview:_head];

        _tear = [CAShapeLayer layer];
        _tear.strokeColor = [UIColor colorWithRed:0.78f green:0.75f blue:0.66f alpha:1.0f].CGColor;
        _tear.lineWidth = 2.0f;
        _tear.lineDashPattern = [NSArray arrayWithObjects:[NSNumber numberWithInt:6], [NSNumber numberWithInt:4], nil];
        _tear.fillColor = NULL;
        [self.contentView.layer addSublayer:_tear];

        _eta = [[UILabel alloc] init];
        _eta.backgroundColor = [UIColor clearColor];
        _eta.font = [UIFont boldSystemFontOfSize:24.0f];
        _eta.textColor = [UIColor colorWithRed:0.65f green:0.06f blue:0.145f alpha:1.0f];
        _eta.adjustsFontSizeToFitWidth = YES;
        _eta.minimumScaleFactor = 0.6f;
        _eta.shadowColor = [UIColor whiteColor];
        _eta.shadowOffset = CGSizeMake(0, 1);
        [self.contentView addSubview:_eta];

        _clock = [[UILabel alloc] init];
        _clock.backgroundColor = [UIColor clearColor];
        _clock.font = [UIFont systemFontOfSize:15.0f];
        _clock.textColor = [UIColor colorWithRed:0.54f green:0.51f blue:0.44f alpha:1.0f];
        _clock.textAlignment = NSTextAlignmentRight;
        [self.contentView addSubview:_clock];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGFloat w = self.contentView.bounds.size.width;
    _caption.frame = CGRectMake(12, 8, w - 24, 18);
    _badge.frame = CGRectMake(12, 30, 76, 44);
    _head.frame = CGRectMake(98, 30, w - 110, 44);

    UIBezierPath *p = [UIBezierPath bezierPath];
    [p moveToPoint:CGPointMake(8, 82)];
    [p addLineToPoint:CGPointMake(w - 8, 82)];
    _tear.path = p.CGPath;

    _eta.frame = CGRectMake(12, 86, w - 100, 28);
    _clock.frame = CGRectMake(w - 92, 90, 80, 20);
}

- (void)setDeparture:(RZDeparture *)dep stopName:(NSString *)stop nowMinutes:(NSInteger)now
{
    _caption.text = [NSString stringWithFormat:@"Najbliższy odjazd · %@", stop];
    [_badge setLine:dep.line kind:dep.kind];
    _head.text = dep.head;
    _eta.text = [RZSchedule etaString:dep.time - now];
    _clock.text = [NSString stringWithFormat:@"o %@", [RZSchedule clockString:dep.time]];
}

@end

#pragma mark - Ruchomy pasek

@implementation RZMarquee {
    UILabel *_label;
    CGFloat _textWidth;
}

+ (Class)layerClass
{
    return [CAGradientLayer class];
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.clipsToBounds = YES;
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _label = [[UILabel alloc] init];
        _label.backgroundColor = [UIColor clearColor];
        _label.font = [UIFont boldSystemFontOfSize:15.0f];
        _label.shadowOffset = CGSizeMake(0, 1);
        _label.lineBreakMode = NSLineBreakByClipping;
        [self addSubview:_label];
        [self setText:@"" warning:NO];
    }
    return self;
}

- (void)setText:(NSString *)text warning:(BOOL)warning
{
    CAGradientLayer *g = (CAGradientLayer *)self.layer;
    if (warning) {
        g.colors = [NSArray arrayWithObjects:(__bridge id)RGB(232, 80, 95).CGColor, (__bridge id)RGB(166, 15, 37).CGColor, nil];
        _label.textColor = [UIColor whiteColor];
        _label.shadowColor = [UIColor colorWithWhite:0 alpha:0.55f];
        _label.shadowOffset = CGSizeMake(0, -1);
    } else {
        g.colors = [NSArray arrayWithObjects:(__bridge id)RGB(255, 229, 138).CGColor, (__bridge id)RGB(239, 181, 52).CGColor, nil];
        _label.textColor = RGB(74, 50, 0);
        _label.shadowColor = [UIColor colorWithWhite:1 alpha:0.6f];
        _label.shadowOffset = CGSizeMake(0, 1);
    }

    _label.text = text;
    _textWidth = [text sizeWithFont:_label.font].width + 24.0f;
    /* Odliczanie zwykle się skraca, więc animacji nie ruszamy. Gdy napis jest
       dłuższy niż etykieta (model ma szerokość z ostatniego restartu), zaczynamy od nowa. */
    if (self.window && _label.frame.size.width < _textWidth - 0.5f) {
        [self restart];
    }
}

- (void)restart
{
    UILabel *l = _label;
    CGFloat w = self.bounds.size.width;
    CGFloat h = self.bounds.size.height;
    CGFloat tw = _textWidth > 0 ? _textWidth : 100.0f;

    [l.layer removeAllAnimations];
    l.frame = CGRectMake(w, 0, tw, h);
    NSTimeInterval dur = (w + tw) / 55.0;
    [UIView animateWithDuration:dur
                          delay:0
                        options:(UIViewAnimationOptionRepeat | UIViewAnimationOptionCurveLinear | UIViewAnimationOptionAllowUserInteraction)
                     animations:^{
                         l.frame = CGRectMake(-tw, 0, tw, h);
                     }
                     completion:nil];
}

@end

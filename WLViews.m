#import "WLViews.h"
#import "WLTheme.h"
#import "WLLang.h"

static UIColor *C(int r, int g, int b, CGFloat a)
{
    return [UIColor colorWithRed:r / 255.0f green:g / 255.0f blue:b / 255.0f alpha:a];
}

static void Gradient(CGContextRef c, CGRect r, UIColor *top, UIColor *bottom)
{
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    NSArray *cols = [NSArray arrayWithObjects:(__bridge id)top.CGColor, (__bridge id)bottom.CGColor, nil];
    CGGradientRef g = CGGradientCreateWithColors(cs, (__bridge CFArrayRef)cols, NULL);
    CGContextSaveGState(c);
    CGContextClipToRect(c, r);
    CGContextDrawLinearGradient(c, g, CGPointMake(0, r.origin.y), CGPointMake(0, r.origin.y + r.size.height), 0);
    CGContextRestoreGState(c);
    CGGradientRelease(g);
    CGColorSpaceRelease(cs);
}

/* ---------- tło komórki ---------- */

@interface WLGlossBackground : UIView
@property (nonatomic) BOOL selected;
@end

@implementation WLGlossBackground
- (id)initWithFrame:(CGRect)f
{
    if ((self = [super initWithFrame:f])) {
        self.opaque = YES;
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}
- (void)drawRect:(CGRect)rect
{
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGRect b = self.bounds;
    CGFloat half = (CGFloat)((int)(b.size.height / 2.0f));
    const WLPalette *p = WLP();
    if (_selected) {
        Gradient(c, CGRectMake(0, 0, b.size.width, half), WLRGB(p->selT1, 1), WLRGB(p->selT2, 1));
        Gradient(c, CGRectMake(0, half, b.size.width, b.size.height - half), WLRGB(p->selB1, 1), WLRGB(p->selB2, 1));
    } else {
        Gradient(c, CGRectMake(0, 0, b.size.width, half), WLRGB(p->cellT1, 1), WLRGB(p->cellT2, 1));
        Gradient(c, CGRectMake(0, half, b.size.width, b.size.height - half), WLRGB(p->cellB1, 1), WLRGB(p->cellB2, 1));
    }
    [C(255, 255, 255, p->cellHiAlpha) setFill];
    CGContextFillRect(c, CGRectMake(0, 0, b.size.width, 1));
    [C(0, 0, 0, p->cellLoAlpha) setFill];
    CGContextFillRect(c, CGRectMake(0, b.size.height - 1, b.size.width, 1));
}
@end

@implementation WLCell

+ (WLCell *)cellForTable:(UITableView *)table identifier:(NSString *)ident
{
    WLCell *cell = [table dequeueReusableCellWithIdentifier:ident];
    if (!cell) cell = [[WLCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:ident];
    return cell;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuse
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuse])) {
        self.backgroundView = [[WLGlossBackground alloc] initWithFrame:self.bounds];
        WLGlossBackground *sel = [[WLGlossBackground alloc] initWithFrame:self.bounds];
        sel.selected = YES;
        self.selectedBackgroundView = sel;
        self.textLabel.textColor = WLTextColor();
        WLStyleShadow(self.textLabel);
        self.textLabel.font = [UIFont boldSystemFontOfSize:17.0f];
        self.textLabel.backgroundColor = [UIColor clearColor];
        self.detailTextLabel.textColor = WLSubtleColor();
        self.detailTextLabel.font = [UIFont systemFontOfSize:13.0f];
        self.detailTextLabel.backgroundColor = [UIColor clearColor];
    }
    return self;
}
@end

/* ---------- nagłówek sekcji ---------- */

@interface WLSectionHeader ()
{
    NSString *_title, *_right;
}
@end

@implementation WLSectionHeader
- (id)initWithTitle:(NSString *)title right:(NSString *)right
{
    if ((self = [super initWithFrame:CGRectMake(0, 0, 320, 26)])) {
        _title = [title copy];
        _right = [right copy];
        self.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        self.contentMode = UIViewContentModeRedraw;
    }
    return self;
}
- (void)drawRect:(CGRect)rect
{
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGRect b = self.bounds;
    const WLPalette *p = WLP();
    Gradient(c, b, WLRGB(p->hdrT, 0.97f), WLRGB(p->hdrB, 0.97f));
    [C(255, 255, 255, p->light ? 0.35f : 0.10f) setFill];
    CGContextFillRect(c, CGRectMake(0, 0, b.size.width, 1));
    [C(0, 0, 0, 0.8f) setFill];
    CGContextFillRect(c, CGRectMake(0, b.size.height - 1, b.size.width, 1));
    UIFont *f = [UIFont boldSystemFontOfSize:13.0f];
    CGContextSetShadowWithColor(c, CGSizeMake(0, -1), 0, C(0, 0, 0, p->light ? 0.45f : 0.9f).CGColor);
    [WLRGB(p->hdrTitle, 1) set];
    [_title drawInRect:CGRectMake(12, 5, b.size.width - 100, 18) withFont:f lineBreakMode:NSLineBreakByTruncatingTail];
    if ([_right length]) {
        [WLRGB(p->hdrRight, 1) set];
        [_right drawInRect:CGRectMake(b.size.width - 160, 5, 148, 18) withFont:f lineBreakMode:NSLineBreakByTruncatingTail alignment:NSTextAlignmentRight];
    }
}
@end

UIView *WLHeaderForTitle(NSString *title, NSString *right)
{
    return [[WLSectionHeader alloc] initWithTitle:title right:right];
}

/* ---------- klawiatura ---------- */

UIToolbar *WLKeyboardToolbar(id target, SEL doneAction)
{
    UIToolbar *tb = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, 320, 38)];
    tb.barStyle = UIBarStyleBlack;
    tb.translucent = YES;
    UIBarButtonItem *flex = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
    UIBarButtonItem *done = [[UIBarButtonItem alloc] initWithTitle:GL(@"Gotowe") style:UIBarButtonItemStyleDone target:target action:doneAction];
    tb.items = [NSArray arrayWithObjects:flex, done, nil];
    return tb;
}

UIImage *WLCheckImage(BOOL on)
{
    CGFloat s = 26.0f;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(s, s), NO, 0.0f);
    UIBezierPath *p = [UIBezierPath bezierPath];
    [p moveToPoint:CGPointMake(5, 14)];
    [p addLineToPoint:CGPointMake(10.5f, 19.5f)];
    [p addLineToPoint:CGPointMake(21, 7)];
    p.lineWidth = 4.0f;
    p.lineCapStyle = kCGLineCapRound;
    p.lineJoinStyle = kCGLineJoinRound;
    CGContextRef c = UIGraphicsGetCurrentContext();
    if (on) {
        CGContextSetShadowWithColor(c, CGSizeMake(0, -1), 0, C(0, 0, 0, 0.6f).CGColor);
        [[UIColor whiteColor] setStroke];
    } else {
        [WLSubtleColor() setStroke];
    }
    [p stroke];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

/* ---------- tło pola tekstowego ---------- */

UIImage *WLFieldImage(void)
{
    static UIImage *img;
    static NSInteger forTheme = -1;
    if (img && forTheme == WLCurrentTheme()) return img;
    forTheme = WLCurrentTheme();
    const WLPalette *p = WLP();
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(20, 34), NO, 0.0f);
    CGContextRef c = UIGraphicsGetCurrentContext();
    UIBezierPath *path = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(0.5f, 0.5f, 19, 32) cornerRadius:7];
    CGContextSaveGState(c);
    [path addClip];
    Gradient(c, CGRectMake(0, 0, 20, 34), WLRGB(p->fieldT, 1), WLRGB(p->fieldB, 1));
    CGContextRestoreGState(c);
    [C(0, 0, 0, p->light ? 0.4f : 0.9f) setStroke];
    [path stroke];
    [C(255, 255, 255, p->light ? 0.8f : 0.12f) setFill];
    CGContextFillRect(c, CGRectMake(5, 33, 10, 1));
    UIImage *raw = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    img = [raw resizableImageWithCapInsets:UIEdgeInsetsMake(10, 8, 10, 8)];
    return img;
}


/* ---------- małe ikonki ---------- */

/* gwiazdka ulubionych: pełna w kolorze motywu albo sam obrys */
UIImage *WLStarImage(BOOL on)
{
    CGFloat s = 28.0f;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(s, s), NO, 0.0f);
    UIBezierPath *p = [UIBezierPath bezierPath];
    for (int i = 0; i < 10; i++) {
        /* wierzchołki co 36 stopni; sin i cos z tablicy, bez libm */
        static const CGFloat cs[10] = { 0.0f, 0.5878f, 0.9511f, 0.9511f, 0.5878f, 0.0f, -0.5878f, -0.9511f, -0.9511f, -0.5878f };
        static const CGFloat sn[10] = { 1.0f, 0.8090f, 0.3090f, -0.3090f, -0.8090f, -1.0f, -0.8090f, -0.3090f, 0.3090f, 0.8090f };
        CGFloat r = (i % 2 == 0) ? 12.5f : 5.4f;
        CGPoint pt = CGPointMake(14.0f + cs[i] * r, 14.5f - sn[i] * r);
        if (i == 0) [p moveToPoint:pt]; else [p addLineToPoint:pt];
    }
    [p closePath];
    p.lineJoinStyle = kCGLineJoinRound;
    p.lineWidth = 2.0f;
    if (on) {
        [WLAccentColor() setFill];
        [p fill];
        [[UIColor colorWithWhite:0.0f alpha:0.35f] setStroke];
        p.lineWidth = 1.0f;
        [p stroke];
    } else {
        [WLSubtleColor() setStroke];
        [p stroke];
    }
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

/* mały biały trójkąt "rozwiń" na przyciskach z walutą */
UIImage *WLTriangleImage(void)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(12, 8), NO, 0.0f);
    UIBezierPath *p = [UIBezierPath bezierPath];
    [p moveToPoint:CGPointMake(1, 1)];
    [p addLineToPoint:CGPointMake(11, 1)];
    [p addLineToPoint:CGPointMake(6, 7)];
    [p closePath];
    [[UIColor whiteColor] setFill];
    [p fill];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

/* dwie pionowe strzałki: zamiana walut miejscami */
UIImage *WLSwapImage(void)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(26, 22), NO, 0.0f);
    [[UIColor whiteColor] setFill];
    [[UIColor whiteColor] setStroke];
    UIBezierPath *l = [UIBezierPath bezierPath];
    [l moveToPoint:CGPointMake(8, 19)];
    [l addLineToPoint:CGPointMake(8, 7)];
    l.lineWidth = 3.0f;
    [l stroke];
    UIBezierPath *a = [UIBezierPath bezierPath];
    [a moveToPoint:CGPointMake(8, 1.5f)];
    [a addLineToPoint:CGPointMake(14, 9)];
    [a addLineToPoint:CGPointMake(2, 9)];
    [a closePath];
    [a fill];
    UIBezierPath *r = [UIBezierPath bezierPath];
    [r moveToPoint:CGPointMake(18, 3)];
    [r addLineToPoint:CGPointMake(18, 15)];
    r.lineWidth = 3.0f;
    [r stroke];
    UIBezierPath *b = [UIBezierPath bezierPath];
    [b moveToPoint:CGPointMake(18, 20.5f)];
    [b addLineToPoint:CGPointMake(24, 13)];
    [b addLineToPoint:CGPointMake(12, 13)];
    [b closePath];
    [b fill];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

void WLOpenURL(NSString *url)
{
    Class urlClass = NSClassFromString(@"NSURL");
    id u = [urlClass URLWithString:url];
    if (u) [[UIApplication sharedApplication] openURL:u];
}

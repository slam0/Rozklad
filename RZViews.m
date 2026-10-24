#import "RZViews.h"
#import "RZLang.h"
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
    return c ? c : RGB(112, 116, 128);
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

#pragma mark - Motywy

NSString *const RZThemeDidChangeNotification = @"RZThemeDidChangeNotification";

typedef struct {
    const char *name;
    const char *note;
    int leather;            /* 1: paski ze skóry z plików PNG */
    int navTop[3], navBot[3], tint[3];
    int tabTop[3], tabBot[3], tabOff[3], tabOn[3];
    int bg;                 /* 0 papier, 1 szare prążki iOS, 2 szary len (Centrum powiadomień) */
    int ink[3], footer[3], subtle[3];
    int cellText[3], cellBg[3], sep[3];
    int ticketBg[3], ticketCaption[3], tear[3], accent[3];
    int darkShadow;         /* 1: motyw ciemny: jasne napisy z czarnym cieniem */
    int selLight;           /* 1: zaznaczona zakładka jaśniejsza, 0: ciemniejsza */
} RZThemeDef;

static const RZThemeDef kThemes[] = {
    {   /* 0: Skóra, jak w aplikacji Znajomi */
        "Skóra", "brązowa skóra i papier, jak w aplikacji Znajomi",
        1, {0,0,0}, {0,0,0}, {66,38,18},
        {0,0,0}, {0,0,0}, {214,196,164}, {255,232,160},
        0, {74,46,24}, {104,84,62}, {128,128,128},
        {20,20,20}, {255,255,255}, {205,200,190},
        {247,240,219}, {138,130,112}, {199,191,168}, {166,15,37},
        0, 0
    },
    {   /* 1: Czerwony: szary len z Centrum powiadomień i czerwone paski */
        "Czerwony", "czerwone paski na szarym lnie z Centrum powiadomień",
        0, {238,78,92}, {128,5,20}, {118,8,22},
        {228,66,82}, {112,4,18}, {255,214,218}, {255,255,255},
        2, {246,246,250}, {196,200,210}, {172,178,192},
        {244,244,248}, {54,58,66}, {30,33,39},
        {46,50,58}, {172,178,192}, {92,98,110}, {255,112,112},
        1, 0
    },
    {   /* 2: Klasyczny, jak Cydia: niebieskie paski i szare prążki */
        "Klasyczny", "jak Cydia: niebieskie paski i prążki",
        0, {180,200,228}, {90,122,178}, {76,108,160},
        {72,72,76}, {4,4,6}, {172,172,178}, {96,170,255},
        1, {76,86,108}, {84,94,116}, {120,126,140},
        {20,20,20}, {255,255,255}, {196,200,208},
        {255,255,255}, {120,126,140}, {206,210,218}, {170,20,40},
        0, 1
    },
    {   /* 3: Grafit: szary len i ciemne paski jak w Centrum powiadomień */
        "Grafit", "szary len i ciemne paski jak w Centrum powiadomień",
        0, {100,104,116}, {26,28,34}, {24,26,30},
        {78,82,92}, {12,13,16}, {170,174,186}, {255,196,87},
        2, {246,246,250}, {196,200,210}, {172,178,192},
        {244,244,248}, {54,58,66}, {30,33,39},
        {46,50,58}, {172,178,192}, {92,98,110}, {255,118,118},
        1, 1
    }
};

static NSString *const kThemeKey = @"motyw";

static UIColor *RGBA(const int *c)
{
    return RGB(c[0], c[1], c[2]);
}

NSUInteger RZThemeCount(void)
{
    return sizeof(kThemes) / sizeof(kThemes[0]);
}

NSInteger RZThemeIndex(void)
{
    NSInteger i = [[NSUserDefaults standardUserDefaults] integerForKey:kThemeKey];
    return (i >= 0 && i < (NSInteger)RZThemeCount()) ? i : 0;
}

static const RZThemeDef *RZTheme(void)
{
    return &kThemes[RZThemeIndex()];
}

void RZThemeSet(NSInteger index)
{
    if (index < 0 || index >= (NSInteger)RZThemeCount()) return;
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setInteger:index forKey:kThemeKey];
    [d synchronize];
    [[NSNotificationCenter defaultCenter] postNotificationName:RZThemeDidChangeNotification object:nil];
}

NSString *RZThemeName(NSInteger index)
{
    return RZL([NSString stringWithUTF8String:kThemes[index].name]);
}

static int RZMix(int x, int y, float t)
{
    return (int)(x + (y - x) * t + 0.5f);
}

/* Błyszczący pasek jak w iOS 6: górna połowa jaśniejsza, dolna ciemniejsza,
   do tego jasna linia u góry i ciemna na dole. */
static UIImage *RZBarImage(CGFloat height, const int *top, const int *bottom)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(4.0f, height), NO, 0.0f);
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    int m1[3], m2[3];
    for (int i = 0; i < 3; i++) {
        m1[i] = RZMix(top[i], bottom[i], 0.40f);
        m2[i] = RZMix(top[i], bottom[i], 0.62f);
    }
    CGFloat half = (CGFloat)((int)(height / 2.0f));
    NSArray *up = [NSArray arrayWithObjects:(__bridge id)RGBA(top).CGColor, (__bridge id)RGBA(m1).CGColor, nil];
    CGGradientRef g = CGGradientCreateWithColors(cs, (__bridge CFArrayRef)up, NULL);
    CGContextSaveGState(c);
    CGContextClipToRect(c, CGRectMake(0, 0, 4.0f, half));
    CGContextDrawLinearGradient(c, g, CGPointMake(0, 0), CGPointMake(0, half), 0);
    CGContextRestoreGState(c);
    CGGradientRelease(g);
    NSArray *down = [NSArray arrayWithObjects:(__bridge id)RGBA(m2).CGColor, (__bridge id)RGBA(bottom).CGColor, nil];
    g = CGGradientCreateWithColors(cs, (__bridge CFArrayRef)down, NULL);
    CGContextSaveGState(c);
    CGContextClipToRect(c, CGRectMake(0, half, 4.0f, height - half));
    CGContextDrawLinearGradient(c, g, CGPointMake(0, half), CGPointMake(0, height), 0);
    CGContextRestoreGState(c);
    CGGradientRelease(g);
    CGColorSpaceRelease(cs);
    [[UIColor colorWithWhite:1.0f alpha:0.30f] setFill];
    CGContextFillRect(c, CGRectMake(0, 0, 4.0f, 1.0f));
    [[UIColor colorWithWhite:0.0f alpha:0.50f] setFill];
    CGContextFillRect(c, CGRectMake(0, height - 1.0f, 4.0f, 1.0f));
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [img resizableImageWithCapInsets:UIEdgeInsetsMake(0, 1, 0, 1)];
}

/* Zaokrąglone podświetlenie zaznaczonej zakładki */
static UIImage *RZSelectionImage(BOOL light)
{
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(20.0f, 49.0f), NO, 0.0f);
    UIColor *c = light ? [UIColor colorWithWhite:1.0f alpha:0.24f] : [UIColor colorWithWhite:0.0f alpha:0.30f];
    [c setFill];
    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(2, 3, 16, 43) cornerRadius:6] fill];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [img resizableImageWithCapInsets:UIEdgeInsetsMake(12, 9, 12, 9)];
}

UIImage *RZThemeSwatch(NSInteger index)
{
    const RZThemeDef *t = &kThemes[index];
    CGSize size = CGSizeMake(40.0f, 40.0f);
    UIGraphicsBeginImageContextWithOptions(size, NO, 0.0f);
    CGContextRef c = UIGraphicsGetCurrentContext();
    CGPathRef clip = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(1, 1, 38, 38) cornerRadius:6].CGPath;
    CGContextAddPath(c, clip);
    CGContextClip(c);

    UIColor *bg;
    if (t->bg == 1) bg = RGB(205, 212, 224);
    else if (t->bg == 2) bg = RGB(112, 116, 128);
    else bg = RGB(238, 230, 211);
    [bg setFill];
    CGContextFillRect(c, CGRectMake(0, 0, 40, 40));

    UIColor *nt = t->leather ? RGB(98, 62, 36) : RGBA(t->navTop);
    UIColor *nb = t->leather ? RGB(58, 33, 16) : RGBA(t->navBot);
    UIColor *tt = t->leather ? RGB(98, 62, 36) : RGBA(t->tabTop);
    UIColor *tb = t->leather ? RGB(58, 33, 16) : RGBA(t->tabBot);
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    NSArray *n = [NSArray arrayWithObjects:(__bridge id)nt.CGColor, (__bridge id)nb.CGColor, nil];
    CGGradientRef g = CGGradientCreateWithColors(cs, (__bridge CFArrayRef)n, NULL);
    CGContextDrawLinearGradient(c, g, CGPointMake(0, 0), CGPointMake(0, 11), 0);
    CGGradientRelease(g);
    NSArray *tb2 = [NSArray arrayWithObjects:(__bridge id)tt.CGColor, (__bridge id)tb.CGColor, nil];
    g = CGGradientCreateWithColors(cs, (__bridge CFArrayRef)tb2, NULL);
    CGContextDrawLinearGradient(c, g, CGPointMake(0, 31), CGPointMake(0, 40), 0);
    CGGradientRelease(g);
    CGColorSpaceRelease(cs);

    /* dwa "wiersze" na tle */
    [(t->darkShadow ? RGB(54, 58, 66) : [UIColor whiteColor]) setFill];
    CGContextFillRect(c, CGRectMake(6, 15, 28, 5));
    CGContextFillRect(c, CGRectMake(6, 23, 28, 5));
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
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
        case 's': {   /* ustawienia: zębatka */
            CGFloat cx = 15.0f, cy = 15.0f;
            for (int i = 0; i < 8; i++) {
                CGContextSaveGState(c);
                CGContextTranslateCTM(c, cx, cy);
                CGContextRotateCTM(c, (CGFloat)i * (CGFloat)M_PI / 4.0f);
                CGContextFillRect(c, CGRectMake(-2.6f, -13.0f, 5.2f, 7.0f));
                CGContextRestoreGState(c);
            }
            [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(cx - 10, cy - 10, 20, 20)] fill];
            [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(cx - 4.2f, cy - 4.2f, 8.4f, 8.4f)] fillWithBlendMode:kCGBlendModeClear alpha:1.0f];
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

#pragma mark - Kolory motywu, paski i napisy

/* Niebieskawo-szare pionowe prążki jak tło tabel w iOS 6 (rysowane w kodzie) */
static UIColor *RZStripeColor(void)
{
    static UIImage *tile = nil;
    if (!tile) {
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(7.0f, 8.0f), YES, 0.0f);
        CGContextRef c = UIGraphicsGetCurrentContext();
        [RGB(213, 219, 229) setFill];
        CGContextFillRect(c, CGRectMake(0, 0, 7, 8));
        [RGB(197, 206, 220) setFill];
        CGContextFillRect(c, CGRectMake(0, 0, 3, 8));
        [RGB(222, 227, 236) setFill];
        CGContextFillRect(c, CGRectMake(3, 0, 1, 8));
        tile = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    }
    return [UIColor colorWithPatternImage:tile];
}

UIColor *RZPaperColor(void)
{
    const RZThemeDef *t = RZTheme();
    if (t->bg == 1) return RZStripeColor();                             /* niebieskie prążki jak w iOS */
    if (t->bg == 2) return RZLinenColor();                              /* szary len z Centrum powiadomień */
    UIImage *img = [UIImage imageNamed:@"bg_paper.png"];
    return img ? [UIColor colorWithPatternImage:img] : RGB(238, 230, 211);
}

UIColor *RZInkColor(void)           { return RGBA(RZTheme()->ink); }
UIColor *RZSubtleColor(void)        { return RGBA(RZTheme()->subtle); }
UIColor *RZCellTextColor(void)      { return RGBA(RZTheme()->cellText); }
UIColor *RZCellBackgroundColor(void){ return RGBA(RZTheme()->cellBg); }
UIColor *RZAccentColor(void)        { return RGBA(RZTheme()->accent); }
static UIColor *RZTicketBackgroundColor(void) { return RGBA(RZTheme()->ticketBg); }
static UIColor *RZTicketCaptionColor(void)    { return RGBA(RZTheme()->ticketCaption); }
static UIColor *RZTicketTearColor(void)       { return RGBA(RZTheme()->tear); }

void RZStyleTable(UITableView *table)
{
    const RZThemeDef *t = RZTheme();
    table.backgroundView = nil;
    table.backgroundColor = RZPaperColor();
    table.separatorColor = RGBA(t->sep);
}

void RZStyleCell(UITableViewCell *cell)
{
    cell.backgroundColor = RZCellBackgroundColor();
}

UIImage *RZStarIcon(BOOL filled)
{
    CGFloat size = 24.0f;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(size, size), NO, 0.0f);
    UIBezierPath *p = [UIBezierPath bezierPath];
    CGFloat cx = size / 2.0f, cy = size / 2.0f + 0.5f, ro = 10.5f, ri = 4.4f;
    /* cosinus i sinus kolejnych wierzchołków gwiazdy (stałe, bez libm) */
    static const float dir[10][2] = { {0.0, -1.0}, {0.5878, -0.809}, {0.9511, -0.309}, {0.9511, 0.309}, {0.5878, 0.809}, {0.0, 1.0}, {-0.5878, 0.809}, {-0.9511, 0.309}, {-0.9511, -0.309}, {-0.5878, -0.809} };
    for (int i = 0; i < 10; i++) {
        CGFloat r = (i % 2 == 0) ? ro : ri;
        CGPoint pt = CGPointMake(cx + r * dir[i][0], cy + r * dir[i][1]);
        if (i == 0) [p moveToPoint:pt]; else [p addLineToPoint:pt];
    }
    [p closePath];
    p.lineJoinStyle = kCGLineJoinRound;
    if (filled) {
        [RGB(255, 205, 40) setFill];
        [p fill];
        [RGB(176, 112, 0) setStroke];
        p.lineWidth = 1.2f;
        [p stroke];
    } else {
        [RGB(150, 150, 156) setStroke];
        p.lineWidth = 1.6f;
        [p stroke];
    }
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}

void RZStyleNavigationBar(UINavigationBar *bar)
{
    const RZThemeDef *t = RZTheme();
    UIImage *bg = t->leather ? [UIImage imageNamed:@"nav_leather.png"] : RZBarImage(44.0f, t->navTop, t->navBot);
    if (bg) [bar setBackgroundImage:bg forBarMetrics:UIBarMetricsDefault];
    bar.tintColor = RGBA(t->tint);              /* kolor przycisków na pasku */
    bar.titleTextAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
        [UIColor whiteColor], UITextAttributeTextColor,
        [UIColor colorWithWhite:0.0f alpha:0.75f], UITextAttributeTextShadowColor,
        [NSValue valueWithUIOffset:UIOffsetMake(0, -1)], UITextAttributeTextShadowOffset,
        [UIFont boldSystemFontOfSize:20.0f], UITextAttributeFont,
        nil];
}

void RZStyleTabBar(UITabBar *bar)
{
    const RZThemeDef *t = RZTheme();
    if (t->leather) {
        UIImage *bg = [UIImage imageNamed:@"tab_leather.png"];
        if (bg) bar.backgroundImage = bg;
        UIImage *sel = [UIImage imageNamed:@"tab_select.png"];
        if (sel) bar.selectionIndicatorImage = sel;
    } else {
        bar.backgroundImage = RZBarImage(49.0f, t->tabTop, t->tabBot);
        bar.selectionIndicatorImage = RZSelectionImage(t->selLight != 0);
    }
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
    const RZThemeDef *t = RZTheme();
    UIColor *off = RGBA(t->tabOff);
    UIColor *on = RGBA(t->tabOn);
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

static UIColor *RZHeaderShadow(void)
{
    return RZTheme()->darkShadow ? [UIColor colorWithWhite:0.0f alpha:0.8f] : [UIColor colorWithWhite:1.0f alpha:0.85f];
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
    l.shadowColor = RZHeaderShadow();
    l.shadowOffset = CGSizeMake(0, 1);
    l.text = text;
    [v addSubview:l];
    return v;
}

UIView *RZStopHeaderView(NSString *text, BOOL favorite, id target, SEL action, NSInteger tag)
{
    UIView *v = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 34)];
    v.backgroundColor = [UIColor clearColor];
    UILabel *l = [[UILabel alloc] initWithFrame:CGRectMake(20, 8, 246, 22)];
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    l.backgroundColor = [UIColor clearColor];
    l.font = [UIFont boldSystemFontOfSize:17.0f];
    l.textColor = RZInkColor();
    l.shadowColor = RZHeaderShadow();
    l.shadowOffset = CGSizeMake(0, 1);
    l.text = text;
    [v addSubview:l];

    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.frame = CGRectMake(266, 0, 54, 34);
    b.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [b setImage:RZStarIcon(favorite) forState:UIControlStateNormal];
    b.tag = tag;
    [b addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    [v addSubview:b];
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
    l.textColor = RGBA(RZTheme()->footer);
    l.shadowColor = RZHeaderShadow();
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
        self.selectionStyle = UITableViewCellSelectionStyleGray;

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
    [self setDeparture:dep nowMinutes:now showCountdown:YES];
}

- (void)setDeparture:(RZDeparture *)dep nowMinutes:(NSInteger)now showCountdown:(BOOL)show
{
    BOOL dark = (RZTheme()->darkShadow != 0);
    UIColor *shadow = dark ? [UIColor clearColor] : [UIColor whiteColor];
    [_badge setLine:dep.line kind:dep.kind];
    _head.text = dep.head;
    _head.textColor = RZCellTextColor();
    _head.shadowColor = shadow;
    _time.text = [RZSchedule clockString:dep.time];
    _time.textColor = RZCellTextColor();
    _time.shadowColor = shadow;
    NSInteger left = dep.time - now;
    if (!show) {
        _eta.text = @"";
        return;
    }
    _eta.text = [RZSchedule etaString:left];
    /* odjazd za kilka minut: napis na czerwono i pogrubiony, żeby rzucał się w oczy */
    if (left <= 5) {
        _eta.textColor = RZAccentColor();
        _eta.font = [UIFont boldSystemFontOfSize:12.0f];
    } else {
        _eta.textColor = RZSubtleColor();
        _eta.font = [UIFont systemFontOfSize:12.0f];
    }
}

@end

#pragma mark - Wiersz listy przystanków

@implementation RZStopCell {
    RZBadge *_badge;
    UILabel *_title;
    UILabel *_sub;
    BOOL _hasBadge;
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
    if (self) {
        self.selectionStyle = UITableViewCellSelectionStyleBlue;

        _badge = [[RZBadge alloc] initWithFrame:CGRectMake(10, 15, 54, 28)];
        [self.contentView addSubview:_badge];

        _title = [[UILabel alloc] init];
        _title.backgroundColor = [UIColor clearColor];
        _title.font = [UIFont boldSystemFontOfSize:17.0f];
        _title.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_title];

        _sub = [[UILabel alloc] init];
        _sub.backgroundColor = [UIColor clearColor];
        _sub.font = [UIFont systemFontOfSize:13.0f];
        _sub.lineBreakMode = NSLineBreakByTruncatingTail;
        [self.contentView addSubview:_sub];

        _star = [UIButton buttonWithType:UIButtonTypeCustom];
        _star.frame = CGRectMake(0, 0, 48, 58);
        self.accessoryView = _star;
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    CGRect b = self.contentView.bounds;
    CGFloat h = b.size.height;
    _badge.frame = CGRectMake(10, (h - 28) / 2.0f, 54, 28);
    CGFloat x = _hasBadge ? 74.0f : 14.0f;
    _title.frame = CGRectMake(x, 8, b.size.width - x - 6, 22);
    _sub.frame = CGRectMake(x, 31, b.size.width - x - 6, 18);
}

- (void)setTitle:(NSString *)title departure:(RZDeparture *)dep nowMinutes:(NSInteger)now favorite:(BOOL)favorite
{
    BOOL dark = (RZTheme()->darkShadow != 0);
    _title.text = title;
    _title.textColor = RZCellTextColor();
    _title.shadowColor = dark ? [UIColor clearColor] : [UIColor whiteColor];
    _title.shadowOffset = CGSizeMake(0, 1);
    _hasBadge = (dep != nil);
    _badge.hidden = !_hasBadge;
    if (dep) {
        [_badge setLine:dep.line kind:dep.kind];
        NSInteger left = dep.time - now;
        _sub.text = [NSString stringWithFormat:@"%@ · %@", dep.head, [RZSchedule etaString:left]];
        _sub.textColor = (left <= 5) ? RZAccentColor() : RZSubtleColor();
    } else {
        _sub.text = RZL(@"brak odjazdów w najbliższym czasie");
        _sub.textColor = RZSubtleColor();
    }
    [_star setImage:RZStarIcon(favorite) forState:UIControlStateNormal];
    [self setNeedsLayout];
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
    UIColor *paper = RZTicketBackgroundColor();
    UIColor *shadow = RZTheme()->darkShadow ? [UIColor clearColor] : [UIColor whiteColor];
    self.contentView.backgroundColor = paper;
    self.backgroundColor = paper;
    _caption.textColor = RZTicketCaptionColor();
    _caption.shadowColor = shadow;
    _clock.textColor = RZTicketCaptionColor();
    _head.textColor = RZCellTextColor();
    _head.shadowColor = shadow;
    _eta.textColor = RZAccentColor();
    _eta.shadowColor = shadow;
    _tear.strokeColor = RZTicketTearColor().CGColor;

    _caption.text = [NSString stringWithFormat:RZL(@"Najbliższy odjazd · %@"), stop];
    [_badge setLine:dep.line kind:dep.kind];
    _head.text = dep.head;
    _eta.text = [RZSchedule countdownString:dep.time * 60 - [RZSchedule secondsOfDay:[NSDate date]]];
    _clock.text = [NSString stringWithFormat:@"o %@", [RZSchedule clockString:dep.time]];
}

- (void)setCountdownText:(NSString *)text
{
    _eta.text = text;
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

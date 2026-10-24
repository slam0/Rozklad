#import "RZImportController.h"
#import "RZLang.h"
#import "RZSchedule.h"
#import "RZViews.h"
#import "rz_import.h"

static NSString *const kSiteBaseKey = @"site_base";

/* Komunikat z kodu w C (po polsku) przetłumaczony na język aplikacji.
   Komunikaty typu "Plik słupka jest uszkodzony (zły format)." tłumaczymy w dwóch częściach. */
static NSString *RZCError(const char *e)
{
    NSString *s = [NSString stringWithUTF8String:e];
    NSArray *prefixes = [NSArray arrayWithObjects:@"Plik z kalendarzami jest uszkodzony (", @"Plik słupka jest uszkodzony (", nil];
    for (NSString *p in prefixes) {
        if ([s hasPrefix:p] && [s hasSuffix:@")."]) {
            NSString *reason = [s substringWithRange:NSMakeRange([p length], [s length] - [p length] - 2)];
            NSString *pattern = RZL([p stringByAppendingString:@"%s)."]);
            return [pattern stringByReplacingOccurrencesOfString:@"%s" withString:RZL(reason)];
        }
    }
    return RZL(s);
}

@implementation RZImportController {
    NSString *_urlString;
    NSData *_reqData;               /* rz_import_req (kopia) albo nil, gdy adres jest zły */
    NSString *_parseError;
    UILabel *_head;
    UILabel *_detail;
    UILabel *_status;
    UIProgressView *_bar;
    UIActivityIndicatorView *_spin;
    BOOL _working;
    BOOL _finished;
    volatile BOOL _cancelled;
}

- (id)initWithURLString:(NSString *)url
{
    self = [super initWithNibName:nil bundle:nil];
    if (self) {
        _urlString = [url copy];
        rz_import_req req;
        char err[256] = "";
        if (rz_import_parse([_urlString UTF8String], &req, err, sizeof err) == 0) {
            _reqData = [NSData dataWithBytes:&req length:sizeof req];
        } else {
            _parseError = RZCError(err);
        }
    }
    return self;
}

- (UILabel *)labelWithFrame:(CGRect)f font:(UIFont *)font
{
    UILabel *l = [[UILabel alloc] initWithFrame:f];
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    l.backgroundColor = [UIColor clearColor];
    l.font = font;
    l.textColor = RZInkColor();
    l.numberOfLines = 0;
    l.shadowColor = [UIColor colorWithWhite:1.0f alpha:0.85f];
    l.shadowOffset = CGSizeMake(0, 1);
    return l;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = RZL(@"Pobieranie");
    self.view.backgroundColor = RZPaperColor();
    CGFloat w = self.view.bounds.size.width;

    _head = [self labelWithFrame:CGRectMake(20, 20, w - 40, 26) font:[UIFont boldSystemFontOfSize:19.0f]];
    [self.view addSubview:_head];

    _detail = [self labelWithFrame:CGRectMake(20, 54, w - 40, 110) font:[UIFont systemFontOfSize:16.0f]];
    [self.view addSubview:_detail];

    _bar = [[UIProgressView alloc] initWithProgressViewStyle:UIProgressViewStyleDefault];
    _bar.frame = CGRectMake(20, 178, w - 40, 12);
    _bar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _bar.hidden = YES;
    [self.view addSubview:_bar];

    _spin = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    _spin.center = CGPointMake(w / 2, 224);
    _spin.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
    [self.view addSubview:_spin];

    _status = [self labelWithFrame:CGRectMake(20, 246, w - 40, 120) font:[UIFont boldSystemFontOfSize:16.0f]];
    _status.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:_status];

    if (!_reqData) {
        [self showFailure:_parseError ? _parseError : RZL(@"Nie rozumiem tego linku.")];
        return;
    }
    rz_import_req req;
    [_reqData getBytes:&req length:sizeof req];
    _head.text = RZL(@"Pobrać rozkład?");
    _detail.text = [NSString stringWithFormat:RZL(@"Aplikacja pobierze rozkład wybranych przystanków (słupków: %d) ze strony:\n%s\n\nTo zastąpi rozkład, który masz teraz w telefonie."),
                    req.count, req.host];
    self.navigationItem.leftBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:RZL(@"Anuluj") style:UIBarButtonItemStyleBordered
                                        target:self action:@selector(cancelTapped)];
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:RZL(@"Pobierz") style:UIBarButtonItemStyleDone
                                        target:self action:@selector(startTapped)];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    if (_working) _cancelled = YES;
}

#pragma mark - Przyciski

- (void)cancelTapped
{
    _cancelled = YES;
    [self leave];
}

- (void)doneTapped
{
    [self leave];
}

- (void)leave
{
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)startTapped
{
    if (_working || !_reqData) return;
    _working = YES;
    _cancelled = NO;
    _head.text = RZL(@"Pobieram rozkład…");
    _detail.text = RZL(@"Nie zamykaj aplikacji, dopóki trwa pobieranie. Przy wolnym internecie może to potrwać kilka minut.");
    _status.text = RZL(@"Łączę…");
    _bar.progress = 0;
    _bar.hidden = NO;
    [_spin startAnimating];
    self.navigationItem.rightBarButtonItem = nil;
    [UIApplication sharedApplication].idleTimerDisabled = YES;
    NSData *rd = _reqData;
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self runWithRequestData:rd];
    });
}

#pragma mark - Stan okna (tylko główny wątek)

- (void)setProgress:(float)p text:(NSString *)text
{
    if (_cancelled) return;
    _bar.progress = p;
    _status.text = text;
}

- (void)showFailure:(NSString *)message
{
    _working = NO;
    _finished = YES;
    [_spin stopAnimating];
    _bar.hidden = YES;
    _head.text = RZL(@"Nie udało się");
    _detail.text = message;
    _status.text = @"";
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:RZL(@"Gotowe") style:UIBarButtonItemStyleDone
                                        target:self action:@selector(doneTapped)];
}

- (void)showSuccess:(NSUInteger)stops kilobytes:(NSUInteger)kb base:(NSString *)base
{
    _working = NO;
    _finished = YES;
    [_spin stopAnimating];
    _bar.hidden = YES;
    [UIApplication sharedApplication].idleTimerDisabled = NO;

    RZSchedule *sc = [RZSchedule shared];
    [sc reload];
    [sc selectAllStops];       /* plik zawiera tylko przystanki wybrane na stronie */
    [[NSUserDefaults standardUserDefaults] setObject:base forKey:kSiteBaseKey];
    [[NSUserDefaults standardUserDefaults] synchronize];

    _head.text = RZL(@"Gotowe!");
    _detail.text = [NSString stringWithFormat:RZL(@"Rozkład jest już w telefonie.\nSłupków: %lu, rozmiar pliku: %lu KB."),
                    (unsigned long)stops, (unsigned long)kb];
    _status.text = @"";
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:RZL(@"Gotowe") style:UIBarButtonItemStyleDone
                                        target:self action:@selector(doneTapped)];
}

#pragma mark - Pobieranie (wątek w tle)

- (NSData *)download:(NSString *)urlString limit:(NSUInteger)limit reason:(NSString **)reason
{
    /* Klasy sieciowe bierzemy po nazwie w czasie działania, a nie na stałe przy łączeniu programu:
       SDK 9.3 umieszcza je w CFNetwork, a w iOS 6 są w Foundation, więc stałe odwołanie
       kończyłoby się wyłączeniem aplikacji zaraz po uruchomieniu. */
    Class reqClass = NSClassFromString(@"NSMutableURLRequest");
    Class connClass = NSClassFromString(@"NSURLConnection");
    Class httpClass = NSClassFromString(@"NSHTTPURLResponse");
    if (!reqClass || !connClass || !httpClass) {
        *reason = RZL(@"Ten system nie ma potrzebnych funkcji sieciowych.");
        return nil;
    }
    NSURL *url = [NSURL URLWithString:urlString];
    NSString *last = RZL(@"brak odpowiedzi");
    for (int attempt = 0; attempt < 3; attempt++) {
        if (_cancelled) return nil;
        @autoreleasepool {
            NSMutableURLRequest *rq = [reqClass requestWithURL:url
                                                   cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                               timeoutInterval:45.0];
            NSURLResponse *resp = nil;
            NSError *err = nil;
            NSData *d = [connClass sendSynchronousRequest:rq returningResponse:&resp error:&err];
            NSInteger code = [resp isKindOfClass:httpClass] ? [(NSHTTPURLResponse *)resp statusCode] : 0;
            if (d && code == 200) {
                if ([d length] > limit) {
                    *reason = RZL(@"Plik ze strony jest zbyt duży, więc go odrzuciłem.");
                    return nil;
                }
                return d;
            }
            if (code == 404) {
                *reason = RZL(@"Na stronie nie ma już tych danych (błąd 404). Dane zostały odświeżone – otwórz stronę jeszcze raz, wybierz przystanki i ponownie dotknij „Otwórz w aplikacji Rozkład”.");
                return nil;
            }
            if (err) {
                if ([[err domain] isEqualToString:@"NSURLErrorDomain"] && [err code] <= -1200 && [err code] >= -1206) {
                    *reason = RZL(@"Telefon nie mógł nawiązać bezpiecznego połączenia (HTTPS). Na iOS 6 potrzebna jest poprawka SSL/TLS z Cydii. Sprawdź też, czy data i godzina w telefonie są poprawne.");
                    return nil;
                }
                last = [err localizedDescription];
            } else if (code) {
                last = [NSString stringWithFormat:RZL(@"błąd serwera %ld"), (long)code];
            }
        }
        [NSThread sleepForTimeInterval:1.5];
    }
    *reason = [NSString stringWithFormat:RZL(@"Nie udało się pobrać danych. Sprawdź połączenie z internetem i spróbuj jeszcze raz.\n\n(%@)"), last];
    return nil;
}

- (void)runWithRequestData:(NSData *)rd
{
    rz_import_req req;
    char err[256] = "";
    rz_asm *as = NULL;
    NSString *failure = nil;
    NSString *dest = nil;
    NSUInteger bytes = 0, stops = 0;
    int total = 0, i;

    [rd getBytes:&req length:sizeof req];
    total = req.count + 1;

    for (i = -1; i < req.count && !failure; i++) {
        @autoreleasepool {
            if (_cancelled) { failure = @""; break; }
            char u[1100];
            NSString *why = nil;
            rz_import_file_url(&req, i, u, sizeof u);
            NSData *d = [self download:[NSString stringWithUTF8String:u]
                                 limit:(i < 0 ? RZ_IMPORT_MAX_SVC_BYTES : RZ_IMPORT_MAX_POLE_BYTES)
                                reason:&why];
            if (!d) {
                failure = why ? why : @"";
                break;
            }
            if (i < 0) {
                as = rz_asm_new((const char *)[d bytes], [d length], err, sizeof err);
                if (!as) failure = RZCError(err);
            } else if (rz_asm_add(as, (const char *)[d bytes], [d length], req.mask[i], err, sizeof err)) {
                failure = RZCError(err);
            }
            float p = (float)(i + 2) / (float)total;
            NSString *t = [NSString stringWithFormat:RZL(@"Pobrano %d z %d"), i + 2, total];
            dispatch_async(dispatch_get_main_queue(), ^{ [self setProgress:p text:t]; });
        }
    }

    if (!failure) {
        size_t len = 0;
        stops = (NSUInteger)rz_asm_stops(as);
        if (stops == 0) {
            failure = RZL(@"Wybrane przystanki nie mają żadnych odjazdów. Spróbuj wybrać inne.");
        } else {
            char *json = rz_asm_finish(as, &len);
            if (!json) {
                failure = RZL(@"Brak pamięci w telefonie, żeby złożyć rozkład. Wybierz mniej przystanków.");
            } else {
                NSData *out = [NSData dataWithBytesNoCopy:json length:len freeWhenDone:YES];
                NSString *dir = [[RZSchedule shared] folder];
                [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
                dest = [dir stringByAppendingPathComponent:@"rozklad.json"];
                if (![out writeToFile:dest atomically:YES]) failure = RZL(@"Nie udało się zapisać pliku w telefonie.");
                bytes = len;
            }
        }
    }
    rz_asm_free(as);

    NSString *base = [NSString stringWithUTF8String:req.base];
    dispatch_async(dispatch_get_main_queue(), ^{
        if (_cancelled) return;
        if (failure) [self showFailure:([failure length] ? failure : RZL(@"Pobieranie przerwano."))];
        else [self showSuccess:stops kilobytes:(bytes + 512) / 1024 base:base];
    });
}

@end

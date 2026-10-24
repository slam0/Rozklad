#import "RZWifiController.h"
#import "RZLang.h"
#import "RZSchedule.h"
#import "RZViews.h"
#import "rz_http.h"

static const int kRZPort = 8080;

static __weak RZWifiController *gActive;

@implementation RZWifiController {
    UILabel *_address;
    UILabel *_help;
    UILabel *_status;
    BOOL _running;
}

/* Wołane w wątku serwera: sprawdza plik, zapisuje go i przeładowuje rozkład. */
static int RZReceive(const char *body, size_t len, void *ctx, char *err, size_t errsize)
{
    @autoreleasepool {
        NSData *data = [NSData dataWithBytes:body length:len];
        id root = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
        NSArray *stops = [root isKindOfClass:[NSDictionary class]] ? [root objectForKey:@"stops"] : nil;
        NSArray *svc = [root isKindOfClass:[NSDictionary class]] ? [root objectForKey:@"svc"] : nil;
        if (![stops isKindOfClass:[NSArray class]] || ![svc isKindOfClass:[NSArray class]]) {
            snprintf(err, errsize, "To nie jest plik rozklad.json z generatora.");
            return 1;
        }
        NSString *dir = [[RZSchedule shared] folder];
        [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:NULL];
        NSString *path = [dir stringByAppendingPathComponent:@"rozklad.json"];
        if (![data writeToFile:path atomically:YES]) {
            snprintf(err, errsize, "Nie udało się zapisać pliku w telefonie.");
            return 2;
        }
        NSUInteger n = [stops count];
        NSUInteger kb = (len + 512) / 1024;
        dispatch_async(dispatch_get_main_queue(), ^{
            [[RZSchedule shared] reload];
            RZWifiController *c = gActive;
            if (c) [c showReceivedStops:n kilobytes:kb];
        });
    }
    return 0;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.title = @"Wi-Fi";
    self.view.backgroundColor = RZPaperColor();
    self.navigationItem.rightBarButtonItem =
        [[UIBarButtonItem alloc] initWithTitle:RZL(@"Gotowe") style:UIBarButtonItemStyleDone
                                        target:self action:@selector(doneTapped)];

    CGFloat w = self.view.bounds.size.width;

    UILabel *head = [self labelWithFrame:CGRectMake(20, 18, w - 40, 24) font:[UIFont boldSystemFontOfSize:17.0f] color:RZInkColor()];
    head.text = RZL(@"Adres tego telefonu:");
    [self.view addSubview:head];

    _address = [self labelWithFrame:CGRectMake(14, 46, w - 28, 44) font:[UIFont boldSystemFontOfSize:22.0f] color:[UIColor blackColor]];
    _address.textAlignment = NSTextAlignmentCenter;
    _address.adjustsFontSizeToFitWidth = YES;
    _address.minimumScaleFactor = 0.6f;
    _address.backgroundColor = [UIColor colorWithWhite:1.0f alpha:0.85f];
    _address.layer.cornerRadius = 8.0f;
    _address.layer.borderWidth = 1.0f;
    _address.layer.borderColor = [UIColor colorWithRed:0.64f green:0.62f blue:0.56f alpha:1.0f].CGColor;
    [self.view addSubview:_address];

    _help = [self labelWithFrame:CGRectMake(20, 102, w - 40, 150) font:[UIFont systemFontOfSize:15.0f] color:RZInkColor()];
    _help.numberOfLines = 0;
    _help.text = RZL(@"1. Upewnij się, że telefon i komputer są w tej samej sieci Wi-Fi.\n2. W generatorze wpisz ten adres i kliknij „Wyślij na telefon”.\nMożesz też otworzyć ten adres w przeglądarce na komputerze i wybrać plik rozklad.json.\nNie zamykaj tego okna, dopóki plik nie dojdzie.");
    [self.view addSubview:_help];

    _status = [self labelWithFrame:CGRectMake(20, 262, w - 40, 80) font:[UIFont boldSystemFontOfSize:17.0f] color:RZInkColor()];
    _status.numberOfLines = 0;
    _status.textAlignment = NSTextAlignmentCenter;
    [self.view addSubview:_status];
}

- (UILabel *)labelWithFrame:(CGRect)f font:(UIFont *)font color:(UIColor *)color
{
    UILabel *l = [[UILabel alloc] initWithFrame:f];
    l.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    l.backgroundColor = [UIColor clearColor];
    l.font = font;
    l.textColor = color;
    l.shadowColor = [UIColor colorWithWhite:1.0f alpha:0.85f];
    l.shadowOffset = CGSizeMake(0, 1);
    return l;
}

#pragma mark - Serwer

- (void)startServer
{
    if (_running) return;
    char ip[64];
    rz_http_local_ip(ip, sizeof ip);
    if (!ip[0]) {
        _address.text = RZL(@"brak sieci Wi-Fi");
        _status.text = RZL(@"Telefon nie jest połączony z Wi-Fi. Włącz Wi-Fi w Ustawieniach i wróć tutaj.");
        return;
    }
    gActive = self;
    int port = rz_http_start(kRZPort, RZReceive, NULL);
    if (port < 0) {
        _address.text = [NSString stringWithUTF8String:ip];
        _status.text = RZL(@"Nie udało się uruchomić odbioru. Zamknij to okno i spróbuj jeszcze raz.");
        return;
    }
    _running = YES;
    _address.text = [NSString stringWithFormat:@"%s:%d", ip, port];
    _status.text = RZL(@"Czekam na plik…");
}

- (void)stopServer
{
    if (_running) {
        rz_http_stop();
        _running = NO;
    }
}

- (void)showReceivedStops:(NSUInteger)stops kilobytes:(NSUInteger)kb
{
    _status.text = [NSString stringWithFormat:RZL(@"Odebrano rozkład: %lu pozycji (%lu KB).\nDotknij „Gotowe”."),
                    (unsigned long)stops, (unsigned long)kb];
}

#pragma mark - Widok

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [UIApplication sharedApplication].idleTimerDisabled = YES;   /* telefon nie zasypia, gdy czeka */
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(appResigned:) name:UIApplicationWillResignActiveNotification object:nil];
    [nc addObserver:self selector:@selector(appActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [self startServer];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [UIApplication sharedApplication].idleTimerDisabled = NO;
    [self stopServer];
}

- (void)appResigned:(NSNotification *)n
{
    [self stopServer];
}

- (void)appActive:(NSNotification *)n
{
    [self startServer];
}

- (void)doneTapped
{
    [self stopServer];
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    if (_running) rz_http_stop();
}

@end

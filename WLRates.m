#import "WLRates.h"
#import "WLStore.h"
#import "WLLang.h"
#import "wl_core.h"
#import "WLCrash.h"

NSString *const WLRatesDidChangeNotification = @"WLRatesDidChangeNotification";

#define kERPath   @"://open.er-api.com/v6/latest/PLN"
#define kNBPPath  @"://api.nbp.pl/api/exchangerates/tables/A/?format=json"

@interface WLRates ()
{
    wl_table _table;
    NSArray *_codes;
    BOOL _loading;
    NSString *_errorText;
    NSArray *_plan;              /* kolejne próby: [ @(źródło), @"https" albo @"http" ] */
    NSUInteger _step;
    BOOL _sawSSLError, _sawLimit, _sawOffline;
    NSTimeInterval _lastStart, _lastSuccess;
    NSUInteger _generation;
}
@end

@implementation WLRates

+ (WLRates *)shared
{
    static WLRates *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[WLRates alloc] init]; });
    return s;
}

- (NSString *)cachePath
{
    NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [[dirs objectAtIndex:0] stringByAppendingPathComponent:@"kursy.txt"];
}

- (id)init
{
    if ((self = [super init])) {
        wl_table_clear(&_table);
        NSData *d = [NSData dataWithContentsOfFile:[self cachePath]];
        if (d) {
            NSString *s = [[NSString alloc] initWithData:d encoding:NSUTF8StringEncoding];
            if (s) {
                wl_table *tmp = (wl_table *)malloc(sizeof(wl_table));
                if (tmp) {
                    if (wl_deserialize([s UTF8String], tmp) > 0) _table = *tmp;
                    free(tmp);
                }
            }
        }
    }
    return self;
}

/* ---------- odczyt ---------- */

- (BOOL)loading { return _loading; }
- (NSString *)errorText { return _errorText; }
- (BOOL)hasRates { return _table.count > 1; }
- (BOOL)hasCode:(NSString *)code { return code && wl_has(&_table, [code UTF8String]); }

- (NSArray *)codes
{
    if (!_codes) {
        NSMutableArray *a = [NSMutableArray arrayWithCapacity:(NSUInteger)_table.count];
        for (int i = 0; i < _table.count; i++) [a addObject:[NSString stringWithUTF8String:_table.rates[i].code]];
        _codes = a;
    }
    return _codes;
}

- (BOOL)convert:(double)amount from:(NSString *)from to:(NSString *)to result:(double *)result
{
    if (!from || !to) return NO;
    return wl_convert(&_table, amount, [from UTF8String], [to UTF8String], result) != 0;
}

- (NSInteger)source { return _table.source; }

- (NSString *)sourceName
{
    if (_table.source == WL_SRC_ERAPI) return @"open.er-api.com";
    if (_table.source == WL_SRC_NBP) return @"NBP";
    return @"";
}

- (NSDate *)updatedDate { return _table.updated > 0 ? [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)_table.updated] : nil; }
- (NSDate *)fetchedDate { return _table.fetched > 0 ? [NSDate dateWithTimeIntervalSince1970:(NSTimeInterval)_table.fetched] : nil; }

- (NSInteger)fetchedAgeDays
{
    return (NSInteger)wl_age_days((long)[[NSDate date] timeIntervalSince1970], _table.fetched);
}

/* ---------- pobieranie ---------- */

- (void)postChange
{
    [[NSNotificationCenter defaultCenter] postNotificationName:WLRatesDidChangeNotification object:nil];
}

- (NSArray *)buildPlan
{
    NSInteger setting = [WLStore shared].sourceSetting;
    NSNumber *er = [NSNumber numberWithInt:WL_SRC_ERAPI], *nbp = [NSNumber numberWithInt:WL_SRC_NBP];
    NSMutableArray *p = [NSMutableArray array];
    #define ADD(src, scheme) [p addObject:[NSArray arrayWithObjects:(src), (scheme), nil]]
    if (setting == 1) { ADD(er, @"https"); ADD(er, @"http"); }
    else if (setting == 2) { ADD(nbp, @"https"); ADD(nbp, @"http"); }
    else { ADD(er, @"https"); ADD(nbp, @"https"); ADD(er, @"http"); ADD(nbp, @"http"); }
    #undef ADD
    return p;
}

- (void)refreshIfNeeded
{
    if (_loading) return;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (now - _lastStart < 120.0) return;                         /* nie męczymy serwera */
    if (_table.count > 1 && _table.fetched > 0 && now - (NSTimeInterval)_table.fetched < 3600.0) return;
    [self startFetch];
}

- (BOOL)refreshNow
{
    if (_loading) return NO;
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    if (_lastSuccess > 0 && now - _lastSuccess < 60.0) return NO;
    [self startFetch];
    return YES;
}

- (void)startFetch
{
    WLCrumb(@"pobieranie kursów: start");
    _loading = YES;
    _errorText = nil;
    _sawSSLError = _sawLimit = _sawOffline = NO;
    _plan = [self buildPlan];
    _step = 0;
    _generation++;
    _lastStart = [[NSDate date] timeIntervalSince1970];
    [self postChange];
    [self tryStep];
}

- (void)finishWithError
{
    _loading = NO;
    NSString *t;
    if (_sawLimit) t = GL(@"Serwer chwilowo odmawia kolejnych zapytań. Spróbuj za kilka minut.");
    else if (_sawSSLError) t = GL(@"Nie udało się połączyć bezpiecznie (HTTPS). Na iOS 6 potrzebna jest poprawka SSL/TLS z Cydii.");
    else if (_sawOffline) t = GL(@"Brak połączenia z internetem.");
    else t = GL(@"Nie udało się pobrać kursów.");
    _errorText = t;
    [self postChange];
}

- (void)tryStep
{
    if (_step >= [_plan count]) { [self finishWithError]; return; }
    NSArray *item = [_plan objectAtIndex:_step];
    int src = [[item objectAtIndex:0] intValue];
    NSString *scheme = [item objectAtIndex:1];
    NSString *url = [scheme stringByAppendingString:(src == WL_SRC_ERAPI ? kERPath : kNBPPath)];
    /* Klasy sieciowe wyszukujemy po nazwie w czasie działania. Zastępcze pliki SDK, z których budujemy aplikację,
       przypisują je do CFNetwork, a na iOS 6 ich tam nie ma (dyld: "Symbol not found: _OBJC_CLASS_$_NSHTTPURLResponse"
       i aplikacja zamykała się od razu po starcie). Bez twardego odwołania w pliku problem znika. */
    Class urlClass = NSClassFromString(@"NSURL");
    Class requestClass = NSClassFromString(@"NSMutableURLRequest");
    Class connectionClass = NSClassFromString(@"NSURLConnection");
    if (!urlClass || !requestClass || !connectionClass) { _step++; [self tryStep]; return; }
    id req = [requestClass requestWithURL:[urlClass URLWithString:url]
                              cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                          timeoutInterval:15.0];
    [req setValue:@"application/json" forHTTPHeaderField:@"Accept"];
    NSUInteger gen = _generation;
    [connectionClass sendAsynchronousRequest:req queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *resp, NSData *data, NSError *err) {
        if (gen != self->_generation || !self->_loading) return;
        [self handleResponse:resp data:data error:err source:src];
    }];
}

- (void)handleResponse:(NSURLResponse *)resp data:(NSData *)data error:(NSError *)err source:(int)src
{
    BOOL ok = NO;
    WLCrumb(err ? @"pobieranie kursów: błąd sieci" : @"pobieranie kursów: odpowiedź");
    if (err) {
        NSInteger code = [err code];
        if ([[err domain] isEqualToString:@"NSURLErrorDomain"]) {
            if (code == NSURLErrorNotConnectedToInternet || code == NSURLErrorDataNotAllowed || code == NSURLErrorInternationalRoamingOff) _sawOffline = YES;
            else if (code <= NSURLErrorSecureConnectionFailed && code >= NSURLErrorClientCertificateRequired) _sawSSLError = YES;
        }
    } else {
        NSInteger status = [resp respondsToSelector:@selector(statusCode)] ? [(NSHTTPURLResponse *)resp statusCode] : 200;
        if (status == 429) _sawLimit = YES;
        if (status == 200 && [data length] > 0) {
            NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
            if (text) {
                wl_table *tmp = (wl_table *)malloc(sizeof(wl_table));
                if (tmp) {
                    WLCrumb(@"pobieranie kursów: czytanie");
                    int n = src == WL_SRC_ERAPI ? wl_parse_erapi([text UTF8String], tmp) : wl_parse_nbp([text UTF8String], tmp);
                    if (n > 0) {
                        tmp->fetched = (long)[[NSDate date] timeIntervalSince1970];
                        _table = *tmp;
                        ok = YES;
                    }
                    free(tmp);
                }
            }
        }
    }
    if (!ok) {
        _step++;
        [self tryStep];
        return;
    }
    WLCrumb(@"pobieranie kursów: zapis");
    _codes = nil;
    _loading = NO;
    _errorText = nil;
    _lastSuccess = [[NSDate date] timeIntervalSince1970];
    [self saveCache];
    WLCrumb(@"pobieranie kursów: odświeżanie widoków");
    [self postChange];
    WLCrumb(@"pobieranie kursów: gotowe");
}

- (void)saveCache
{
    char *buf = (char *)malloc(32768);
    if (!buf) return;
    int n = wl_serialize(&_table, buf, 32768);
    if (n > 0) {
        NSData *d = [NSData dataWithBytes:buf length:(NSUInteger)n];
        [d writeToFile:[self cachePath] atomically:YES];
    }
    free(buf);
}

- (void)clear
{
    _generation++;
    _loading = NO;
    _errorText = nil;
    _codes = nil;
    _lastSuccess = 0;
    wl_table_clear(&_table);
    [[NSFileManager defaultManager] removeItemAtPath:[self cachePath] error:NULL];
    [self postChange];
}

@end

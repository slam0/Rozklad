#import "RZSchedule.h"
#include <stdlib.h>
#include <string.h>

NSString *const RZScheduleDidReloadNotification = @"RZScheduleDidReloadNotification";

#pragma mark - Pomocnicze

static NSArray *RZArr(id o)
{
    return [o isKindOfClass:[NSArray class]] ? (NSArray *)o : nil;
}

static int RZInt(id o)
{
    if ([o isKindOfClass:[NSNumber class]] || [o isKindOfClass:[NSString class]]) {
        return [o intValue];
    }
    return 0;
}

static NSString *RZStr(id o)
{
    if ([o isKindOfClass:[NSString class]]) return o;
    if ([o isKindOfClass:[NSNumber class]]) return [o stringValue];
    return @"";
}

static int32_t RZDate(id o)
{
    return rz_parse_date([RZStr(o) UTF8String]);
}

/* Zwraca indeks napisu w tabeli (dodaje, jeśli go nie ma). */
static uint16_t RZIntern(NSMutableDictionary *map, NSMutableArray *table, NSString *s)
{
    NSNumber *n = [map objectForKey:s];
    if (n) return (uint16_t)[n unsignedIntValue];
    if ([table count] >= 65535) return 0;
    [table addObject:s];
    uint16_t idx = (uint16_t)([table count] - 1);
    [map setObject:[NSNumber numberWithUnsignedInt:idx] forKey:s];
    return idx;
}

static NSCalendar *RZCalendar(void)
{
    NSCalendar *cal = [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
    [cal setTimeZone:[NSTimeZone localTimeZone]];
    return cal;
}

#pragma mark - Klasy danych

@implementation RZDataset

- (void)dealloc
{
    if (svcs) {
        for (NSUInteger i = 0; i < svcCount; i++) {
            free(svcs[i].add);
            free(svcs[i].rem);
        }
        free(svcs);
    }
}

@end

@implementation RZStop
@end

@implementation RZDeparture
@end

#pragma mark - RZSchedule

@interface RZSchedule ()
@property (nonatomic, strong, readwrite) NSArray *datasets;
@property (nonatomic, strong, readwrite) NSArray *stops;
@property (nonatomic, copy, readwrite) NSString *loadError;
@property (nonatomic, copy) NSString *signature;
@end

@implementation RZSchedule

+ (RZSchedule *)shared
{
    static RZSchedule *shared = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        shared = [[RZSchedule alloc] init];
    });
    return shared;
}

- (id)init
{
    self = [super init];
    if (self) {
        _datasets = [NSArray array];
        _stops = [NSArray array];
    }
    return self;
}

/* Główny folder dokumentów aplikacji (to on jest widoczny w iTunes w zakładce Pliki) */
- (NSString *)documentsFolder
{
    NSArray *p = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [p count] ? [p objectAtIndex:0] : @"/var/mobile/Documents";
}

- (NSString *)folder
{
    return [[self documentsFolder] stringByAppendingPathComponent:@"Rozklady"];
}

static BOOL RZIsJSON(NSString *name)
{
    return ![name hasPrefix:@"."] && [[[name pathExtension] lowercaseString] isEqualToString:@"json"];
}

/* Pełne ścieżki plików .json: każdy plik .json z folderu Rozklady oraz pliki rozklad*.json
   z głównego folderu dokumentów (tam trafiają pliki przeciągnięte w iTunes). */
- (NSArray *)jsonPaths
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *folder = [self folder];
    NSString *docs = [self documentsFolder];
    [fm createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:NULL];
    NSMutableArray *paths = [NSMutableArray array];
    for (NSString *name in [fm contentsOfDirectoryAtPath:folder error:NULL]) {
        if (RZIsJSON(name)) [paths addObject:[folder stringByAppendingPathComponent:name]];
    }
    for (NSString *name in [fm contentsOfDirectoryAtPath:docs error:NULL]) {
        if (RZIsJSON(name) && [[name lowercaseString] hasPrefix:@"rozklad"]) {
            [paths addObject:[docs stringByAppendingPathComponent:name]];
        }
    }
    /* ta sama nazwa pliku w obu miejscach (np. rozklad.json): zostaje nowszy */
    NSMutableDictionary *byName = [NSMutableDictionary dictionary];
    for (NSString *path in paths) {
        NSString *key = [[path lastPathComponent] lowercaseString];
        NSString *other = [byName objectForKey:key];
        if (!other) { [byName setObject:path forKey:key]; continue; }
        NSDate *d1 = [[fm attributesOfItemAtPath:path error:NULL] objectForKey:NSFileModificationDate];
        NSDate *d2 = [[fm attributesOfItemAtPath:other error:NULL] objectForKey:NSFileModificationDate];
        if (d1 && d2 && [d1 compare:d2] == NSOrderedDescending) [byName setObject:path forKey:key];
    }
    return [[byName allValues] sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        return [[(NSString *)a lastPathComponent] compare:[(NSString *)b lastPathComponent]];
    }];
}

/* Podpis folderu: nazwy + rozmiary + daty zmian */
- (NSString *)currentSignature
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableString *sig = [NSMutableString string];
    for (NSString *path in [self jsonPaths]) {
        NSDictionary *a = [fm attributesOfItemAtPath:path error:NULL];
        [sig appendFormat:@"%@|%@|%.0f;", path, [a objectForKey:NSFileSize],
            [[a objectForKey:NSFileModificationDate] timeIntervalSince1970]];
    }
    return sig;
}

- (BOOL)reloadIfChanged
{
    if ([[self currentSignature] isEqualToString:self.signature]) return NO;
    [self reload];
    return YES;
}

- (void)reload
{
    NSMutableArray *sets = [NSMutableArray array];
    NSMutableArray *allStops = [NSMutableArray array];
    NSString *problem = nil;

    for (NSString *path in [self jsonPaths]) {
        @autoreleasepool {
            NSString *name = [path lastPathComponent];
            NSError *err = nil;
            NSData *data = [NSData dataWithContentsOfFile:path options:NSDataReadingMappedIfSafe error:&err];
            id root = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:&err] : nil;
            if (![root isKindOfClass:[NSDictionary class]]
                || !RZArr([root objectForKey:@"stops"])
                || !RZArr([root objectForKey:@"svc"])) {
                problem = [NSString stringWithFormat:@"Nie mogę odczytać pliku %@ (to nie jest rozklad.json z generatora).", name];
                continue;
            }
            RZDataset *set = [self datasetFromRoot:root fileName:name stops:allStops];
            [sets addObject:set];
        }
    }

    self.datasets = sets;
    self.stops = allStops;
    self.loadError = problem;
    self.signature = [self currentSignature];
    [[NSNotificationCenter defaultCenter] postNotificationName:RZScheduleDidReloadNotification object:self];
}

- (RZDataset *)datasetFromRoot:(NSDictionary *)root fileName:(NSString *)fileName stops:(NSMutableArray *)out
{
    RZDataset *set = [[RZDataset alloc] init];
    set.fileName = fileName;
    set.generated = RZStr([root objectForKey:@"gen"]);
    set.end = RZStr([root objectForKey:@"end"]);

    /* kalendarze */
    NSArray *svcArr = RZArr([root objectForKey:@"svc"]);
    NSUInteger ns = [svcArr count];
    if (ns > 65535) ns = 65535;
    set->svcs = (RZService *)calloc(ns ? ns : 1, sizeof(RZService));
    set->svcCount = ns;
    for (NSUInteger i = 0; i < ns; i++) {
        NSDictionary *d = [svcArr objectAtIndex:i];
        if (![d isKindOfClass:[NSDictionary class]]) continue;
        RZService *s = &set->svcs[i];
        NSArray *days = RZArr([d objectForKey:@"d"]);
        for (int k = 0; k < 7; k++) {
            s->days[k] = (k < (int)[days count] && RZInt([days objectAtIndex:k]) != 0) ? 1 : 0;
        }
        s->start = RZDate([d objectForKey:@"s"]);
        s->end = RZDate([d objectForKey:@"e"]);
        NSArray *a = RZArr([d objectForKey:@"a"]);
        s->nadd = (int)[a count];
        if (s->nadd) {
            s->add = (int32_t *)malloc(sizeof(int32_t) * s->nadd);
            for (int k = 0; k < s->nadd; k++) s->add[k] = RZDate([a objectAtIndex:k]);
        }
        NSArray *r = RZArr([d objectForKey:@"r"]);
        s->nrem = (int)[r count];
        if (s->nrem) {
            s->rem = (int32_t *)malloc(sizeof(int32_t) * s->nrem);
            for (int k = 0; k < s->nrem; k++) s->rem[k] = RZDate([r objectAtIndex:k]);
        }
    }

    /* przystanki i odjazdy */
    NSMutableArray *lines = [NSMutableArray array];
    NSMutableArray *heads = [NSMutableArray array];
    NSMutableDictionary *lineMap = [NSMutableDictionary dictionary];
    NSMutableDictionary *headMap = [NSMutableDictionary dictionary];

    for (NSDictionary *sd in RZArr([root objectForKey:@"stops"])) {
        if (![sd isKindOfClass:[NSDictionary class]]) continue;
        NSArray *raw = RZArr([sd objectForKey:@"d"]);
        NSUInteger n = [raw count];
        RZDep *buf = n ? (RZDep *)malloc(n * sizeof(RZDep)) : NULL;
        NSUInteger used = 0;
        unsigned mask = 0;

        for (NSArray *e in raw) {
            if (!RZArr(e) || [e count] < 5) continue;
            int svc = RZInt([e objectAtIndex:2]);
            if (svc < 0 || (NSUInteger)svc >= set->svcCount) continue;
            NSString *ks = RZStr([e objectAtIndex:4]);
            char kind = [ks length] ? (char)[ks characterAtIndex:0] : 'b';
            if (!RZKindBit(kind)) kind = 'b';
            buf[used].minute = (int32_t)RZInt([e objectAtIndex:3]);
            buf[used].svc = (uint16_t)svc;
            buf[used].line = RZIntern(lineMap, lines, RZStr([e objectAtIndex:0]));
            buf[used].head = RZIntern(headMap, heads, RZStr([e objectAtIndex:1]));
            buf[used].kind = (uint8_t)kind;
            mask |= RZKindBit(kind);
            used++;
        }

        RZStop *stop = [[RZStop alloc] init];
        stop.name = RZStr([sd objectForKey:@"n"]);
        stop.code = RZStr([sd objectForKey:@"c"]);
        stop.key = [NSString stringWithFormat:@"%@|%@", stop.name, stop.code];
        stop.title = [stop.code length] ? [NSString stringWithFormat:@"%@ %@", stop.name, stop.code] : stop.name;
        stop.dataset = set;
        stop.count = used;
        stop.kindMask = mask;
        if (used) {
            stop.deps = [NSData dataWithBytesNoCopy:buf length:used * sizeof(RZDep) freeWhenDone:YES];
        } else {
            free(buf);
        }
        [out addObject:stop];
    }

    set.lines = lines;
    set.heads = heads;
    return set;
}

- (NSArray *)stopsOfKind:(char)kind
{
    NSMutableArray *r = [NSMutableArray array];
    unsigned bit = RZKindBit(kind);
    for (RZStop *s in self.stops) {
        if (s.kindMask & bit) [r addObject:s];
    }
    return r;
}

#pragma mark - Wybór przystanków

static NSString *RZSelectionKey(char kind)
{
    return [NSString stringWithFormat:@"wybrane_%c", kind];
}

- (NSArray *)sortedStopsOfKind:(char)kind
{
    NSLocale *loc = [NSLocale currentLocale];
    return [[self stopsOfKind:kind] sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
        NSString *x = ((RZStop *)a).title;
        NSString *y = ((RZStop *)b).title;
        return [x compare:y options:(NSCaseInsensitiveSearch | NSNumericSearch)
                    range:NSMakeRange(0, [x length]) locale:loc];
    }];
}

- (NSArray *)savedKeysForKind:(char)kind
{
    return [[NSUserDefaults standardUserDefaults] arrayForKey:RZSelectionKey(kind)];
}

- (NSArray *)selectedStopsOfKind:(char)kind
{
    NSArray *keys = [self savedKeysForKind:kind];
    if (![keys count]) return [NSArray array];
    NSSet *set = [NSSet setWithArray:keys];
    NSMutableArray *r = [NSMutableArray array];
    for (RZStop *s in [self sortedStopsOfKind:kind]) {
        if ([set containsObject:s.key]) [r addObject:s];
    }
    return r;
}

- (BOOL)needsSelectionForKind:(char)kind
{
    if (![[self stopsOfKind:kind] count]) return NO;
    NSArray *keys = [self savedKeysForKind:kind];
    if (!keys) return YES;                  /* jeszcze nigdy nie wybierano */
    if (![keys count]) return NO;           /* użytkownik świadomie nie wybrał nic */
    return [[self selectedStopsOfKind:kind] count] == 0;   /* zapisane przystanki zniknęły z nowego pliku */
}

- (void)setSelectedStops:(NSArray *)stops forKind:(char)kind
{
    NSMutableArray *keys = [NSMutableArray arrayWithCapacity:[stops count]];
    for (RZStop *s in stops) [keys addObject:s.key];
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setObject:keys forKey:RZSelectionKey(kind)];
    [d synchronize];
}

- (void)selectAllStops
{
    const char kinds[4] = { 'b', 't', 'p', 'm' };
    for (int i = 0; i < 4; i++) {
        NSArray *all = [self sortedStopsOfKind:kinds[i]];
        if ([all count]) [self setSelectedStops:all forKind:kinds[i]];
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:RZScheduleDidReloadNotification object:self];
}

- (NSString *)descriptionForStop:(RZStop *)stop kind:(char)kind
{
    RZDataset *ds = stop.dataset;
    NSUInteger nl = [ds.lines count], nh = [ds.heads count];
    if (!stop.deps || !nl) return @"";

    int *lc = (int *)calloc(nl, sizeof(int));
    int *hc = (int *)calloc(nh ? nh : 1, sizeof(int));
    const RZDep *d = (const RZDep *)[stop.deps bytes];
    for (NSUInteger i = 0; i < stop.count; i++) {
        if (d[i].kind != (uint8_t)kind) continue;
        if (d[i].line < nl) lc[d[i].line]++;
        if (d[i].head < nh) hc[d[i].head]++;
    }

    NSMutableArray *lines = [NSMutableArray array];
    for (NSUInteger i = 0; i < nl; i++) {
        if (lc[i]) [lines addObject:[ds.lines objectAtIndex:i]];
    }
    [lines sortUsingComparator:^NSComparisonResult(id a, id b) {
        return [(NSString *)a compare:(NSString *)b options:NSNumericSearch];
    }];

    /* najczęstszy kierunek */
    NSInteger best = -1;
    for (NSUInteger i = 0; i < nh; i++) {
        if (hc[i] > 0 && (best < 0 || hc[i] > hc[best])) best = (NSInteger)i;
    }
    NSString *head = (best >= 0) ? [ds.heads objectAtIndex:(NSUInteger)best] : @"";
    free(lc);
    free(hc);

    NSString *list;
    if ([lines count] > 6) {
        list = [[[lines subarrayWithRange:NSMakeRange(0, 6)] componentsJoinedByString:@", "] stringByAppendingString:@"…"];
    } else {
        list = [lines componentsJoinedByString:@", "];
    }
    if (![lines count]) return @"";
    if ([head length]) return [NSString stringWithFormat:@"linie: %@ · do: %@", list, head];
    return [NSString stringWithFormat:@"linie: %@", list];
}

+ (NSInteger)minutesOfDay:(NSDate *)date
{
    NSDateComponents *c = [RZCalendar() components:(NSHourCalendarUnit | NSMinuteCalendarUnit) fromDate:date];
    return [c hour] * 60 + [c minute];
}

- (NSArray *)nextDeparturesForStop:(RZStop *)stop kind:(char)kind now:(NSDate *)now limit:(NSUInteger)limit
{
    if (!stop.deps || !stop.dataset) return [NSArray array];

    NSCalendar *cal = RZCalendar();
    int32_t ymd[3];
    int wd[3];
    for (int i = 0; i < 3; i++) {
        NSDateComponents *off = [[NSDateComponents alloc] init];
        [off setDay:i - 1];
        NSDate *day = [cal dateByAddingComponents:off toDate:now options:0];
        NSDateComponents *c = [cal components:(NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit | NSWeekdayCalendarUnit)
                                     fromDate:day];
        ymd[i] = (int32_t)([c year] * 10000 + [c month] * 100 + [c day]);
        wd[i] = (int)(([c weekday] + 5) % 7);   /* niedziela=1 -> 6, poniedziałek=2 -> 0 */
    }
    int nowMin = (int)[RZSchedule minutesOfDay:now];
    int horizon = (kind == 'p') ? 1440 : 720;

    RZDataset *ds = stop.dataset;
    RZNext found[RZ_MAX_NEXT];
    int n = rz_next((const RZDep *)[stop.deps bytes], stop.count,
                    ds->svcs, ds->svcCount, ymd, wd, nowMin, horizon,
                    (uint8_t)kind, found, (int)limit);

    NSMutableArray *result = [NSMutableArray arrayWithCapacity:n];
    for (int i = 0; i < n; i++) {
        RZDeparture *d = [[RZDeparture alloc] init];
        d.time = found[i].time;
        d.kind = kind;
        d.line = found[i].line < [ds.lines count] ? [ds.lines objectAtIndex:found[i].line] : @"?";
        d.head = found[i].head < [ds.heads count] ? [ds.heads objectAtIndex:found[i].head] : @"";
        [result addObject:d];
    }
    return result;
}

- (NSDate *)expiryDate
{
    NSCalendar *cal = RZCalendar();
    NSDate *best = nil;
    for (RZDataset *ds in self.datasets) {
        int32_t e = rz_parse_date([ds.end UTF8String]);
        if (e <= 0) continue;
        NSDateComponents *c = [[NSDateComponents alloc] init];
        [c setYear:e / 10000];
        [c setMonth:(e / 100) % 100];
        [c setDay:(e % 100) + 1];     /* ważny do końca ostatniego dnia */
        NSDate *d = [cal dateFromComponents:c];
        if (d && (!best || [d compare:best] == NSOrderedAscending)) best = d;
    }
    return best;
}

- (NSString *)summary
{
    NSMutableArray *parts = [NSMutableArray array];
    for (RZDataset *ds in self.datasets) {
        if ([ds.generated length]) {
            [parts addObject:[NSString stringWithFormat:@"%@ (%@)", ds.fileName, ds.generated]];
        } else {
            [parts addObject:ds.fileName];
        }
    }
    return [parts componentsJoinedByString:@", "];
}

#pragma mark - Teksty

+ (NSString *)etaString:(NSInteger)minutes
{
    char buf[64];
    rz_eta((int)minutes, buf, sizeof buf);
    return [NSString stringWithUTF8String:buf];
}

+ (NSString *)clockString:(NSInteger)time
{
    char buf[16];
    rz_clock((int)time, buf, sizeof buf);
    return [NSString stringWithUTF8String:buf];
}

+ (NSString *)durationString:(NSTimeInterval)seconds
{
    char buf[96];
    rz_duration((long)seconds, buf, sizeof buf);
    return [NSString stringWithUTF8String:buf];
}

@end

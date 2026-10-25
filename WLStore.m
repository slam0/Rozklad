#import "WLStore.h"

@interface WLStore ()
{
    NSMutableDictionary *_root;
}
@end

@implementation WLStore

+ (WLStore *)shared
{
    static WLStore *s;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ s = [[WLStore alloc] init]; });
    return s;
}

- (NSString *)dataPath
{
    NSArray *dirs = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    return [[dirs objectAtIndex:0] stringByAppendingPathComponent:@"waluty.json"];
}

+ (NSArray *)defaultFavorites
{
    return [NSArray arrayWithObjects:@"EUR", @"USD", @"GBP", @"CHF", @"CZK", @"UAH", @"NOK", @"SEK", @"JPY", nil];
}

- (id)init
{
    if ((self = [super init])) [self load];
    return self;
}

- (void)load
{
    NSData *d = [NSData dataWithContentsOfFile:[self dataPath]];
    id obj = nil;
    if (d) {
        obj = [NSJSONSerialization JSONObjectWithData:d options:NSJSONReadingMutableContainers error:NULL];
        if (![obj isKindOfClass:[NSMutableDictionary class]]) {
            /* uszkodzony plik: zachowaj kopię i zacznij od zera */
            NSString *bad = [[self dataPath] stringByAppendingString:@".uszkodzony"];
            [[NSFileManager defaultManager] removeItemAtPath:bad error:NULL];
            [[NSFileManager defaultManager] moveItemAtPath:[self dataPath] toPath:bad error:NULL];
            obj = nil;
        }
    }
    _root = obj ? obj : [NSMutableDictionary dictionary];
    [self ensureDefaults];
}

- (void)ensureDefaults
{
    if (![[_root objectForKey:@"from"] isKindOfClass:[NSString class]]) [_root setObject:@"PLN" forKey:@"from"];
    if (![[_root objectForKey:@"to"] isKindOfClass:[NSString class]]) [_root setObject:@"EUR" forKey:@"to"];
    if (![[_root objectForKey:@"base"] isKindOfClass:[NSString class]]) [_root setObject:@"PLN" forKey:@"base"];
    if (![[_root objectForKey:@"amount"] isKindOfClass:[NSString class]]) [_root setObject:@"100" forKey:@"amount"];
    if (![[_root objectForKey:@"favorites"] isKindOfClass:[NSArray class]]) {
        [_root setObject:[NSMutableArray arrayWithArray:[WLStore defaultFavorites]] forKey:@"favorites"];
    }
    for (NSString *k in [NSArray arrayWithObjects:@"lang", @"theme", @"source", nil]) {
        if (![[_root objectForKey:k] isKindOfClass:[NSNumber class]]) [_root setObject:[NSNumber numberWithInteger:([k isEqualToString:@"theme"] ? 3 : 0)] forKey:k];
    }
}

- (void)save
{
    NSData *d = [NSJSONSerialization dataWithJSONObject:_root options:0 error:NULL];
    if (d) [d writeToFile:[self dataPath] atomically:YES];
}

- (NSInteger)languageSetting { return [[_root objectForKey:@"lang"] integerValue]; }
- (void)setLanguageSetting:(NSInteger)v { [_root setObject:[NSNumber numberWithInteger:v] forKey:@"lang"]; [self save]; }
- (NSInteger)themeIndex { return [[_root objectForKey:@"theme"] integerValue]; }
- (void)setThemeIndex:(NSInteger)v { [_root setObject:[NSNumber numberWithInteger:v] forKey:@"theme"]; [self save]; }
- (NSInteger)sourceSetting { return [[_root objectForKey:@"source"] integerValue]; }
- (void)setSourceSetting:(NSInteger)v { [_root setObject:[NSNumber numberWithInteger:v] forKey:@"source"]; [self save]; }

- (NSString *)fromCode { return [_root objectForKey:@"from"]; }
- (void)setFromCode:(NSString *)c { [_root setObject:(c ? [c copy] : @"PLN") forKey:@"from"]; [self save]; }
- (NSString *)toCode { return [_root objectForKey:@"to"]; }
- (void)setToCode:(NSString *)c { [_root setObject:(c ? [c copy] : @"EUR") forKey:@"to"]; [self save]; }
- (NSString *)ratesBase { return [_root objectForKey:@"base"]; }
- (void)setRatesBase:(NSString *)c { [_root setObject:(c ? [c copy] : @"PLN") forKey:@"base"]; [self save]; }
- (NSString *)amountText { return [_root objectForKey:@"amount"]; }
- (void)setAmountText:(NSString *)t { [_root setObject:(t ? [t copy] : @"") forKey:@"amount"]; }   /* zapis przy zmianie ekranu i przy wyjściu */

- (NSArray *)favorites { return [NSArray arrayWithArray:[_root objectForKey:@"favorites"]]; }
- (void)setFavorites:(NSArray *)f { [_root setObject:[NSMutableArray arrayWithArray:f] forKey:@"favorites"]; [self save]; }

- (BOOL)isFavorite:(NSString *)code { return [[_root objectForKey:@"favorites"] containsObject:code]; }

- (void)toggleFavorite:(NSString *)code
{
    NSMutableArray *a = [_root objectForKey:@"favorites"];
    if ([a containsObject:code]) [a removeObject:code]; else [a addObject:code];
    [self save];
}

- (void)resetFavorites
{
    [_root setObject:[NSMutableArray arrayWithArray:[WLStore defaultFavorites]] forKey:@"favorites"];
    [self save];
}

- (void)clearAll
{
    NSInteger lang = self.languageSetting, theme = self.themeIndex;      /* wygląd zostaje */
    _root = [NSMutableDictionary dictionary];
    [self ensureDefaults];
    [_root setObject:[NSNumber numberWithInteger:lang] forKey:@"lang"];
    [_root setObject:[NSNumber numberWithInteger:theme] forKey:@"theme"];
    [self save];
}

@end

#import <Foundation/Foundation.h>
#import "rz_core.h"

extern NSString *const RZScheduleDidReloadNotification;

/* Bity rodzajów transportu: b t p m */
static inline unsigned RZKindBit(char kind)
{
    switch (kind) {
        case 'b': return 1;
        case 't': return 2;
        case 'p': return 4;
        case 'm': return 8;
    }
    return 0;
}

/* Jeden wczytany plik rozklad.json */
@interface RZDataset : NSObject {
@public
    RZService *svcs;
    NSUInteger svcCount;
}
@property (nonatomic, copy) NSString *fileName;
@property (nonatomic, copy) NSString *generated;
@property (nonatomic, copy) NSString *end;
@property (nonatomic, strong) NSArray *lines;
@property (nonatomic, strong) NSArray *heads;
@end

/* Przystanek (wszystkie słupki razem) */
@interface RZStop : NSObject
@property (nonatomic, copy) NSString *name;
@property (nonatomic, copy) NSString *code;      /* numer słupka, np. "01" (może być pusty) */
@property (nonatomic, copy) NSString *key;       /* nazwa|numer: rozpoznaje przystanek między uruchomieniami */
@property (nonatomic, copy) NSString *title;     /* do wyświetlania, np. "Centrum 01" */
@property (nonatomic, strong) RZDataset *dataset;
@property (nonatomic, strong) NSData *deps;      /* tablica RZDep */
@property (nonatomic) NSUInteger count;
@property (nonatomic) unsigned kindMask;
@end

@interface RZDeparture : NSObject
@property (nonatomic) NSInteger time;            /* minuty od północy dzisiaj */
@property (nonatomic, copy) NSString *line;
@property (nonatomic, copy) NSString *head;
@property (nonatomic) char kind;
@end

@interface RZSchedule : NSObject

+ (RZSchedule *)shared;

@property (nonatomic, readonly) NSArray *datasets;
@property (nonatomic, readonly) NSArray *stops;
@property (nonatomic, readonly) NSString *loadError;

/* Folder z plikami .json (na telefonie: /var/mobile/Documents/Rozklady) */
- (NSString *)folder;

/* Wczytuje wszystkie pliki .json z folderu od nowa */
- (void)reload;
/* Wczytuje od nowa tylko, gdy pliki w folderze się zmieniły; zwraca YES jeśli wczytano */
- (BOOL)reloadIfChanged;

- (NSArray *)stopsOfKind:(char)kind;

/* Wybór przystanków (zapamiętywany w telefonie osobno dla każdego rodzaju) */
- (NSArray *)sortedStopsOfKind:(char)kind;       /* wszystkie z pliku, alfabetycznie */
- (NSArray *)selectedStopsOfKind:(char)kind;     /* tylko wybrane przez użytkownika */
- (BOOL)needsSelectionForKind:(char)kind;        /* są przystanki, ale nic jeszcze nie wybrano */
- (void)setSelectedStops:(NSArray *)stops forKind:(char)kind;
/* Zaznacza wszystkie przystanki z wczytanych plików (po pobraniu ze strony) i odświeża zakładki */
- (void)selectAllStops;
/* Krótki opis słupka do listy wyboru, np. "linie: 175, 222 · do: Lotnisko Chopina" */
- (NSString *)descriptionForStop:(RZStop *)stop kind:(char)kind;
- (NSArray *)nextDeparturesForStop:(RZStop *)stop kind:(char)kind now:(NSDate *)now limit:(NSUInteger)limit;

/* Ulubione przystanki (gwiazdka): zapamiętywane w telefonie, wyświetlane na górze listy */
- (BOOL)isFavoriteStop:(RZStop *)stop kind:(char)kind;
- (void)setFavorite:(BOOL)fav forStop:(RZStop *)stop kind:(char)kind;
- (NSUInteger)favoriteCount;
- (void)clearFavorites;

/* Ile odjazdów pokazywać na ekranie przystanku (10, 20 lub 30) */
+ (NSInteger)departureLimit;
+ (void)setDepartureLimit:(NSInteger)n;

/* Sprzątanie plików z rozkładami. Zwracają liczbę usuniętych plików i wczytują dane od nowa. */
- (NSUInteger)removeAllFiles;
- (NSUInteger)removeExpiredFiles;
/* Ile plików .json leży w folderach aplikacji i ile z nich jest przeterminowanych */
- (NSUInteger)fileCount;
- (NSUInteger)expiredFileCount;

/* Koniec ważności najwcześniej kończącego się rozkładu (koniec ostatniego dnia) lub nil */
- (NSDate *)expiryDate;
/* Krótki opis wczytanych danych, np. "rozklad.json (2026-10-22)" */
- (NSString *)summary;

+ (NSInteger)minutesOfDay:(NSDate *)date;
+ (NSInteger)secondsOfDay:(NSDate *)date;
/* Odliczanie do odjazdu w sekundach, np. "za 4 min 20 s" (poniżej 10 minut), inaczej jak etaString */
+ (NSString *)countdownString:(NSInteger)secondsLeft;
+ (NSString *)etaString:(NSInteger)minutes;
+ (NSString *)clockString:(NSInteger)time;
+ (NSString *)durationString:(NSTimeInterval)seconds;

@end

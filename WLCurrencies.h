#import <Foundation/Foundation.h>

/* Nazwy walut po polsku, angielsku i rosyjsku. Kod spoza tabeli dostaje nazwę równą kodowi. */

NSString *WLCurrencyName(NSString *code);                 /* w wybranym języku */
NSString *WLCurrencySearchText(NSString *code);           /* kod + nazwy we wszystkich językach (do wyszukiwania) */

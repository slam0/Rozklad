#import <UIKit/UIKit.h>

/* Okno pobierania rozkładu po dotknięciu "Otwórz w aplikacji Rozkład" na stronie.
   Dostaje cały adres rozklad://import?... */
@interface RZImportController : UIViewController

- (id)initWithURLString:(NSString *)url;

@end

#import <UIKit/UIKit.h>

/* Okno z listą przystanków z rozklad.json: zaznaczasz ptaszkiem te, które chcesz widzieć. */
@interface RZPickerController : UITableViewController
- (id)initWithKind:(char)kind done:(void (^)(void))done;
@end

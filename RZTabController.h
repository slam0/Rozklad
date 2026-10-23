#import <UIKit/UIKit.h>

/* Jedna zakładka: lista przystanków jednego rodzaju (autobus, tramwaj, pociąg, metro). */
@interface RZTabController : UITableViewController

- (id)initWithKind:(char)kind title:(NSString *)title;

@end

#import <UIKit/UIKit.h>

/* Ekran jednego przystanku: bilet z najbliższym odjazdem i lista kolejnych odjazdów. */
@interface RZStopController : UITableViewController

- (id)initWithStopKey:(NSString *)key kind:(char)kind title:(NSString *)title;

@end

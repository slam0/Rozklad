#import <UIKit/UIKit.h>

/* Wybór waluty: lista z wyszukiwarką (po kodzie i nazwie w każdym języku), najpierw ulubione. */
@interface WLPickerController : UIViewController <UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate>
@property (nonatomic, copy) NSString *selectedCode;
@property (nonatomic, copy) void (^onPick)(NSString *code);
@end

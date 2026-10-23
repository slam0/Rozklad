#import "AppDelegate.h"
#import "RZSchedule.h"
#import "RZTabController.h"
#import "RZViews.h"
#import "RZImportController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    RZSchedule *schedule = [RZSchedule shared];
    [schedule reload];

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    const char kinds[4] = { 'b', 't', 'p', 'm' };
    NSArray *names = [NSArray arrayWithObjects:@"Autobus", @"Tramwaj", @"Pociąg", @"Metro", nil];
    NSArray *titles = [NSArray arrayWithObjects:@"Autobusy", @"Tramwaje", @"Pociągi", @"Metro", nil];

    NSMutableArray *controllers = [NSMutableArray array];
    NSUInteger firstWithData = NSNotFound;
    for (NSUInteger i = 0; i < 4; i++) {
        RZTabController *root = [[RZTabController alloc] initWithKind:kinds[i] title:[titles objectAtIndex:i]];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:root];
        RZStyleNavigationBar(nav.navigationBar);
        nav.tabBarItem = [[UITabBarItem alloc] initWithTitle:[names objectAtIndex:i]
                                                       image:RZTabIcon(kinds[i])
                                                         tag:(NSInteger)i];
        RZStyleTabItem(nav.tabBarItem, kinds[i]);
        [controllers addObject:nav];
        if (firstWithData == NSNotFound && [[schedule stopsOfKind:kinds[i]] count]) {
            firstWithData = i;
        }
    }

    UITabBarController *tabs = [[UITabBarController alloc] init];
    tabs.viewControllers = controllers;
    RZStyleTabBar(tabs.tabBar);
    if (firstWithData != NSNotFound) tabs.selectedIndex = firstWithData;

    self.window.rootViewController = tabs;
    [self.window makeKeyAndVisible];
    return YES;
}

/* Przycisk "Otwórz w aplikacji Rozkład" na stronie otwiera adres rozklad://import?... */
- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation
{
    if (![[[url scheme] lowercaseString] isEqualToString:@"rozklad"]) return NO;
    NSString *s = [url absoluteString];
    UIViewController *root = self.window.rootViewController;
    void (^show)(void) = ^{
        RZImportController *c = [[RZImportController alloc] initWithURLString:s];
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:c];
        RZStyleNavigationBar(nav.navigationBar);
        [root presentViewController:nav animated:YES completion:nil];
    };
    if (root.presentedViewController) {
        [root dismissViewControllerAnimated:NO completion:show];
    } else {
        show();
    }
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /* Jeśli w folderze pojawił się nowy plik rozklad.json, wczytaj go */
    [[RZSchedule shared] reloadIfChanged];
}

@end

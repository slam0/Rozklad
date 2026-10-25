#import "AppDelegate.h"
#import "WLStore.h"
#import "WLTheme.h"
#import "WLLang.h"
#import "WLRates.h"
#import "WLCrash.h"
#import "WLConverterController.h"
#import "WLRatesController.h"
#import "WLSettingsController.h"

@implementation AppDelegate

- (UINavigationController *)navWith:(UIViewController *)root title:(NSString *)title kind:(int)kind
{
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:root];
    WLStyleNavigationBar(nav.navigationBar);
    nav.tabBarItem = [[UITabBarItem alloc] initWithTitle:title image:WLTabIcon(kind) tag:kind];
    WLStyleTabItem(nav.tabBarItem, kind);
    return nav;
}

/* cały interfejs od zera: przy starcie oraz po zmianie motywu albo języka */
- (UITabBarController *)buildTabs
{
    NSArray *controllers = [NSArray arrayWithObjects:
        [self navWith:[[WLConverterController alloc] init] title:GL(@"Przelicznik") kind:0],
        [self navWith:[[WLRatesController alloc] init] title:GL(@"Kursy") kind:1],
        [self navWith:[[WLSettingsController alloc] init] title:GL(@"Ustawienia") kind:3], nil];
    UITabBarController *tabs = [[UITabBarController alloc] init];
    tabs.viewControllers = controllers;
    WLStyleTabBar(tabs.tabBar);
    return tabs;
}

- (void)appearanceChanged:(NSNotification *)n
{
    /* po wyjściu z obsługi dotknięcia, żeby nie usuwać kontrolera, który właśnie działa */
    [self performSelector:@selector(rebuildInterface) withObject:nil afterDelay:0.0];
}

- (void)rebuildInterface
{
    UITabBarController *old = (UITabBarController *)self.window.rootViewController;
    NSUInteger selected = [old isKindOfClass:[UITabBarController class]] ? old.selectedIndex : 0;
    [old dismissViewControllerAnimated:NO completion:nil];
    UITabBarController *tabs = [self buildTabs];
    tabs.selectedIndex = selected;
    [UIView transitionWithView:self.window duration:0.3 options:UIViewAnimationOptionTransitionCrossDissolve
                    animations:^{ self.window.rootViewController = tabs; } completion:nil];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    NSString *lastReport = WLTakeLastRunReport();
    WLCrashInstall();
    WLCrumb(@"start aplikacji");
    [WLStore shared];
    WLCrumb(@"ustawienia wczytane");
    [WLRates shared];
    WLCrumb(@"kursy wczytane");
    [application setStatusBarStyle:UIStatusBarStyleBlackOpaque];
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    self.window.backgroundColor = [UIColor blackColor];

    self.window.rootViewController = [self buildTabs];
    WLCrumb(@"interfejs zbudowany");
    [self.window makeKeyAndVisible];
    WLCrumb(@"okno pokazane");
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appearanceChanged:) name:WLAppearanceDidChangeNotification object:nil];

    /* ekran powitalny: ten sam obraz co Default.png, przytrzymany chwilę i płynnie zgaszony */
    CGRect bounds = [[UIScreen mainScreen] bounds];
    UIImage *splash = [UIImage imageNamed:(bounds.size.height > 480.0f ? @"Default-568h" : @"Default")];
    if (splash) {
        UIImageView *cover = [[UIImageView alloc] initWithFrame:bounds];
        cover.image = splash;
        cover.contentMode = UIViewContentModeScaleAspectFill;
        cover.clipsToBounds = YES;
        cover.userInteractionEnabled = YES;
        [self.window addSubview:cover];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.4 animations:^{ cover.alpha = 0.0f; }
                             completion:^(BOOL finished) { [cover removeFromSuperview]; }];
        });
    }
    if (lastReport) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Waluty – diagnostyka" message:lastReport delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
            [a show];
        });
    }
    return YES;
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /* po starcie i po powrocie do aplikacji: jeśli kursy mają ponad godzinę, pobierz nowe */
    WLCrumb(@"aplikacja aktywna");
    [[WLRates shared] refreshIfNeeded];
    WLCrumb(@"po sprawdzeniu kursów");
}

- (void)applicationDidEnterBackground:(UIApplication *)application { [[WLStore shared] save]; WLCrumbCleanExit(); }
- (void)applicationWillTerminate:(UIApplication *)application { [[WLStore shared] save]; WLCrumbCleanExit(); }

@end

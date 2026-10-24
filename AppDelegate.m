#import "AppDelegate.h"
#import "RZLang.h"
#import "RZSchedule.h"
#import "RZTabController.h"
#import "RZViews.h"
#import "RZImportController.h"
#import "RZSettingsController.h"

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    RZLangApply();
    RZSchedule *schedule = [RZSchedule shared];
    [schedule reload];

    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];

    const char kinds[5] = { 'b', 't', 'p', 'm', 's' };
    NSArray *names = [NSArray arrayWithObjects:RZL(@"Autobus"), RZL(@"Tramwaj"), RZL(@"Pociąg"), RZL(@"Metro"), RZL(@"Ustawienia"), nil];
    NSArray *titles = [NSArray arrayWithObjects:RZL(@"Autobusy"), RZL(@"Tramwaje"), RZL(@"Pociągi"), RZL(@"Metro"), nil];

    NSMutableArray *controllers = [NSMutableArray array];
    NSUInteger firstWithData = NSNotFound;
    for (NSUInteger i = 0; i < 5; i++) {
        UIViewController *root;
        if (i < 4) {
            root = [[RZTabController alloc] initWithKind:kinds[i] title:[titles objectAtIndex:i]];
        } else {
            root = [[RZSettingsController alloc] init];
        }
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:root];
        RZStyleNavigationBar(nav.navigationBar);
        nav.tabBarItem = [[UITabBarItem alloc] initWithTitle:[names objectAtIndex:i]
                                                       image:RZTabIcon(kinds[i])
                                                         tag:(NSInteger)i];
        RZStyleTabItem(nav.tabBarItem, kinds[i]);
        [controllers addObject:nav];
        if (i < 4 && firstWithData == NSNotFound && [[schedule stopsOfKind:kinds[i]] count]) {
            firstWithData = i;
        }
    }

    UITabBarController *tabs = [[UITabBarController alloc] init];
    tabs.viewControllers = controllers;
    RZStyleTabBar(tabs.tabBar);
    if (firstWithData != NSNotFound) tabs.selectedIndex = firstWithData;

    self.tabs = tabs;
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(themeChanged:)
                                                 name:RZThemeDidChangeNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(languageChanged:)
                                                 name:RZLanguageDidChangeNotification object:nil];

    self.window.rootViewController = tabs;
    [self.window makeKeyAndVisible];

    /* Ekran powitalny: ten sam obraz co Default.png, przytrzymany chwilę i płynnie zgaszony. */
    CGRect bounds = [[UIScreen mainScreen] bounds];
    UIImage *splash = [UIImage imageNamed:(bounds.size.height > 480.0f ? @"Default-568h" : @"Default")];
    if (splash) {
        UIImageView *cover = [[UIImageView alloc] initWithFrame:bounds];
        cover.image = splash;
        cover.contentMode = UIViewContentModeScaleAspectFill;
        cover.clipsToBounds = YES;
        cover.userInteractionEnabled = YES;
        [self.window addSubview:cover];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [UIView animateWithDuration:0.45 animations:^{ cover.alpha = 0.0f; }
                             completion:^(BOOL finished) { [cover removeFromSuperview]; }];
        });
    }
    return YES;
}

/* Zmiana języka w ustawieniach: nowe nazwy zakładek i tytuły ekranów. */
- (void)languageChanged:(NSNotification *)n
{
    NSArray *names = [NSArray arrayWithObjects:RZL(@"Autobus"), RZL(@"Tramwaj"), RZL(@"Pociąg"), RZL(@"Metro"), RZL(@"Ustawienia"), nil];
    NSArray *titles = [NSArray arrayWithObjects:RZL(@"Autobusy"), RZL(@"Tramwaje"), RZL(@"Pociągi"), RZL(@"Metro"), RZL(@"Ustawienia"), nil];
    NSArray *vcs = self.tabs.viewControllers;
    for (NSUInteger i = 0; i < [vcs count] && i < 5; i++) {
        UINavigationController *nav = [vcs objectAtIndex:i];
        nav.tabBarItem.title = [names objectAtIndex:i];
        UIViewController *root = [nav.viewControllers objectAtIndex:0];
        root.title = [titles objectAtIndex:i];
    }
}

/* Zmiana motywu w ustawieniach: malujemy od nowa paski wszystkich zakładek. */
- (void)themeChanged:(NSNotification *)n
{
    const char kinds[5] = { 'b', 't', 'p', 'm', 's' };
    RZStyleTabBar(self.tabs.tabBar);
    NSArray *vcs = self.tabs.viewControllers;
    for (NSUInteger i = 0; i < [vcs count] && i < 5; i++) {
        UINavigationController *nav = [vcs objectAtIndex:i];
        RZStyleNavigationBar(nav.navigationBar);
        RZStyleTabItem(nav.tabBarItem, kinds[i]);
    }
    /* odświeżenie, żeby pasek natychmiast przyjął nowy wygląd */
    self.tabs.tabBar.hidden = YES;
    self.tabs.tabBar.hidden = NO;
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

/* Gdy przypomnienie przyjdzie przy otwartej aplikacji, iOS nie pokazuje banera, więc pokazujemy okienko. */
- (void)application:(UIApplication *)application didReceiveLocalNotification:(UILocalNotification *)notification
{
    if (application.applicationState == UIApplicationStateActive && [notification.alertBody length]) {
        UIAlertView *a = [[UIAlertView alloc] initWithTitle:RZL(@"Przypomnienie o odjeździe")
                                                    message:notification.alertBody delegate:nil
                                          cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [a show];
    }
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    /* Jeśli w folderze pojawił się nowy plik rozklad.json, wczytaj go */
    [[RZSchedule shared] reloadIfChanged];
}

@end

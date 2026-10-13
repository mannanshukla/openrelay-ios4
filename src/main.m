#import <UIKit/UIKit.h>
#import "ORContactsViewController.h"
#import "ORChatViewController.h"
#import "ORContacts.h"
#import "ORUnprompted.h"

@interface ORAppDelegate : NSObject <UIApplicationDelegate> { UIWindow *window; UINavigationController *nav; ORContactsViewController *contacts; }
@end
@implementation ORAppDelegate
- (void)openThreadFor:(NSString *)cid {
    [[ORUnprompted shared] deliverDue];
    NSDictionary *c = [ORContacts contactWithId:cid] ?: [ORContacts current];
    if (!c) return;
    [nav popToRootViewControllerAnimated:NO];
    [contacts openContact:c animated:NO];
    [UIApplication sharedApplication].applicationIconBadgeNumber = 0;
}
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)opts {
    [ORContacts seedDefaultsIfNeeded];
    [[ORUnprompted shared] deliverDue];   // before any thread is opened
    window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    contacts = [[ORContactsViewController alloc] init];
    nav = [[UINavigationController alloc] initWithRootViewController:contacts];
    nav.navigationBar.tintColor = [UIColor colorWithRed:0x4D/255.0 green:0x7C/255.0 blue:0x0F/255.0 alpha:1]; // OpenRelay olive
    // reopen the last conversation so it feels like Messages
    NSDictionary *cur = [ORContacts current];
    if (cur && ![[NSUserDefaults standardUserDefaults] boolForKey:@"or_start_on_list"]) [contacts openContact:cur animated:NO];
    [window addSubview:nav.view];
    [window makeKeyAndVisible];
    UILocalNotification *n = [opts objectForKey:UIApplicationLaunchOptionsLocalNotificationKey];
    if (n) [self performSelector:@selector(openThreadFor:) withObject:[n.userInfo objectForKey:@"contact"] afterDelay:0.3];
    [[ORUnprompted shared] performSelector:@selector(topUp) withObject:nil afterDelay:4.0];
    app.applicationIconBadgeNumber = 0;
    return YES;
}
- (void)application:(UIApplication *)app didReceiveLocalNotification:(UILocalNotification *)n {
    [[ORUnprompted shared] deliverDue];   // files the text; an open thread picks it up via ORHistoryChanged
    if (app.applicationState != UIApplicationStateActive) [self openThreadFor:[n.userInfo objectForKey:@"contact"]];
    app.applicationIconBadgeNumber = 0;
}
- (void)applicationDidBecomeActive:(UIApplication *)app {
    app.applicationIconBadgeNumber = 0;
    [[ORUnprompted shared] deliverDue];
    [[ORUnprompted shared] performSelector:@selector(topUp) withObject:nil afterDelay:4.0];
}
- (void)dealloc { [contacts release]; [nav release]; [window release]; [super dealloc]; }
@end

int main(int argc, char *argv[]) {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    int r = UIApplicationMain(argc, argv, nil, @"ORAppDelegate");
    [pool release];
    return r;
}

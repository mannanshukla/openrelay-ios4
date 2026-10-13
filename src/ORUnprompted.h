#import <UIKit/UIKit.h>
// "Texts you first": pre-generates short unprompted messages from contacts while the app is open,
// schedules them as local notifications at random daytime hours, and files them into the thread when due.
// This is the closest a jailbreak app without an APNs certificate can get to push.
extern NSString *const ORHistoryChangedNotification;   // object = contact id
@interface ORUnprompted : NSObject
+ (ORUnprompted *)shared;
- (void)deliverDue;      // file any scheduled texts whose time has passed into their threads
- (void)topUp;           // generate + schedule until the next 24h has perDay texts
- (void)cancelAll;
@end

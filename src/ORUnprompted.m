#import "ORUnprompted.h"
#import "ORClient.h"
#import "ORContacts.h"

NSString *const ORHistoryChangedNotification = @"ORHistoryChanged";
static NSString *kSched = @"or_scheduled";
#define DAY_START (9*60)      // minutes after midnight
#define DAY_END   (21*60+30)
#define WINDOW    (24*3600.0)

@interface ORUnprompted () <ORClientDelegate> { ORClient *client; NSMutableString *buf; NSDictionary *generating; NSTimeInterval generatingTs; BOOL busy; }
@end

@implementation ORUnprompted
+ (ORUnprompted *)shared { static ORUnprompted *u = nil; if (!u) u = [[ORUnprompted alloc] init]; return u; }
- (id)init { if ((self = [super init])) { client = [[ORClient alloc] init]; client.delegate = self; } return self; }
- (NSUserDefaults *)d { return [NSUserDefaults standardUserDefaults]; }
- (NSMutableArray *)scheduled { return [NSMutableArray arrayWithArray:([[self d] arrayForKey:kSched] ?: [NSArray array])]; }
- (void)saveScheduled:(NSArray *)a { [[self d] setObject:a forKey:kSched]; [[self d] synchronize]; }

- (void)cancelAll {
    [[UIApplication sharedApplication] cancelAllLocalNotifications];
    [self saveScheduled:[NSArray array]];
}

- (void)deliverDue {
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
    NSMutableArray *sched = [self scheduled]; BOOL changed = NO;
    NSMutableArray *keep = [NSMutableArray array];
    for (NSDictionary *item in sched) {
        NSTimeInterval ts = [[item objectForKey:@"ts"] doubleValue];
        BOOL delivered = [[item objectForKey:@"delivered"] boolValue];
        if (!delivered && ts <= now) {
            NSString *cid = [item objectForKey:@"contact"];
            if ([ORContacts contactWithId:cid]) {
                NSString *key = [ORContacts historyKey:cid];
                NSMutableArray *h = [NSMutableArray arrayWithArray:([[self d] arrayForKey:key] ?: [NSArray array])];
                [h addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"assistant", @"role", [item objectForKey:@"text"], @"content", [NSNumber numberWithDouble:ts], @"ts", [NSNumber numberWithBool:YES], @"unprompted", nil]];
                [[self d] setObject:h forKey:key];
                [[NSNotificationCenter defaultCenter] postNotificationName:ORHistoryChangedNotification object:cid];
            }
            NSMutableDictionary *m = [NSMutableDictionary dictionaryWithDictionary:item]; [m setObject:[NSNumber numberWithBool:YES] forKey:@"delivered"];
            [keep addObject:m]; changed = YES;
        } else if (ts > now - 2*86400) {
            [keep addObject:item];
        } else changed = YES;
    }
    if (changed) [self saveScheduled:keep];
}

- (NSInteger)pendingCount {
    NSTimeInterval now = [[NSDate date] timeIntervalSince1970]; NSInteger n = 0;
    for (NSDictionary *item in [self scheduled]) { NSTimeInterval ts = [[item objectForKey:@"ts"] doubleValue]; if (![[item objectForKey:@"delivered"] boolValue] && ts > now && ts < now + WINDOW) n++; }
    return n;
}
// a random daytime moment in the next 24h, at least 20 minutes out
- (NSTimeInterval)randomSlot {
    NSCalendar *cal = [NSCalendar currentCalendar];
    for (int tries = 0; tries < 40; tries++) {
        NSTimeInterval t = [[NSDate date] timeIntervalSince1970] + 20*60 + (arc4random() % (NSUInteger)(WINDOW - 20*60));
        NSDateComponents *c = [cal components:(NSHourCalendarUnit|NSMinuteCalendarUnit) fromDate:[NSDate dateWithTimeIntervalSince1970:t]];
        NSInteger mins = [c hour]*60 + [c minute];
        if (mins >= DAY_START && mins <= DAY_END) return t;
    }
    return [[NSDate date] timeIntervalSince1970] + 3600;
}
- (void)topUp {
    if (busy) return;
    NSInteger perDay = [ORSettings unpromptedPerDay];
    if (perDay <= 0 || ![[ORSettings apiKey] length]) return;
    if ([self pendingCount] >= perDay) return;
    NSArray *all = [ORContacts all]; if (![all count]) return;
    generating = [[all objectAtIndex:arc4random() % [all count]] retain];
    generatingTs = [self randomSlot];
    NSDateFormatter *f = [[[NSDateFormatter alloc] init] autorelease]; [f setDateFormat:@"EEEE 'around' h a"];
    NSString *when = [f stringFromDate:[NSDate dateWithTimeIntervalSince1970:generatingTs]];
    // give the model the tail of the thread for continuity
    NSArray *h = [[self d] arrayForKey:[ORContacts historyKey:[generating objectForKey:@"id"]]];
    NSMutableArray *turns = [NSMutableArray array];
    NSInteger start = MAX(0, (NSInteger)[h count] - 6);
    for (NSInteger i = start; i < (NSInteger)[h count]; i++) {
        NSDictionary *m = [h objectAtIndex:i]; NSString *role = [m objectForKey:@"role"];
        if (([role isEqualToString:@"user"] || [role isEqualToString:@"assistant"]) && [[m objectForKey:@"content"] length])
            [turns addObject:[NSDictionary dictionaryWithObjectsAndKeys:role, @"role", [m objectForKey:@"content"], @"content", nil]];
    }
    [turns addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"user", @"role",
        [NSString stringWithFormat:@"(Write one unprompted text you would send me on %@, out of the blue, as yourself. One or two short sentences, a single burst, plain text, no greeting needed, nothing about this being scheduled. Reply with only the text.)", when], @"content", nil]];
    client.personaPrompt = [generating objectForKey:@"prompt"];
    client.modelOverride = [generating objectForKey:@"model"];
    [buf release]; buf = [[NSMutableString alloc] init];
    busy = YES;
    [client sendMessages:turns];
}
- (void)clientDidStart:(id)c {}
- (void)client:(id)c didReceiveToken:(NSString *)t { [buf appendString:t]; }
- (void)clientDidFinish:(id)c {
    busy = NO;
    NSString *text = [[buf stringByReplacingOccurrencesOfString:@"\n\n" withString:@" "] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([text hasPrefix:@"\""] && [text hasSuffix:@"\""] && [text length] > 2) text = [text substringWithRange:NSMakeRange(1, [text length]-2)];
    if ([text length] > 240) text = [[text substringToIndex:240] stringByAppendingString:@"..."];
    BOOL filed = [text length] && generating;
    if (filed) {
        NSString *cid = [generating objectForKey:@"id"], *name = [generating objectForKey:@"name"];
        NSMutableArray *sched = [self scheduled];
        [sched addObject:[NSDictionary dictionaryWithObjectsAndKeys:cid, @"contact", [NSNumber numberWithDouble:generatingTs], @"ts", text, @"text", nil]];
        [self saveScheduled:sched];
        UILocalNotification *n = [[UILocalNotification alloc] init];
        n.fireDate = [NSDate dateWithTimeIntervalSince1970:generatingTs]; n.timeZone = [NSTimeZone defaultTimeZone];
        n.alertBody = [NSString stringWithFormat:@"%@: %@", name, text]; n.alertAction = @"Reply";
        n.soundName = UILocalNotificationDefaultSoundName; n.applicationIconBadgeNumber = 1;
        n.userInfo = [NSDictionary dictionaryWithObjectsAndKeys:cid, @"contact", [NSNumber numberWithDouble:generatingTs], @"ts", nil];
        [[UIApplication sharedApplication] scheduleLocalNotification:n]; [n release];
    }
    [generating release]; generating = nil;
    if (filed) [self performSelector:@selector(topUp) withObject:nil afterDelay:2.0];   // keep filling the window; an empty reply waits for the next launch or chat instead of asking again every 2 s
}
- (void)client:(id)c didFailWithMessage:(NSString *)m { busy = NO; [generating release]; generating = nil; }
@end

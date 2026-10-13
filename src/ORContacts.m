#import "ORContacts.h"

static NSString *kContacts = @"or_contacts", *kCurrent = @"or_current_contact";

@implementation ORContacts
+ (NSUserDefaults *)d { return [NSUserDefaults standardUserDefaults]; }
+ (NSArray *)all { return [[self d] arrayForKey:kContacts] ?: [NSArray array]; }
+ (NSDictionary *)contactWithId:(NSString *)cid { for (NSDictionary *c in [self all]) if ([[c objectForKey:@"id"] isEqualToString:cid]) return c; return nil; }
+ (NSString *)currentId { return [[self d] stringForKey:kCurrent]; }
+ (void)setCurrentId:(NSString *)cid { [[self d] setObject:cid forKey:kCurrent]; [[self d] synchronize]; }
+ (NSDictionary *)current { NSDictionary *c = [self contactWithId:[self currentId]]; return c ?: ([[self all] count] ? [[self all] objectAtIndex:0] : nil); }
+ (NSString *)historyKey:(NSString *)cid { return [NSString stringWithFormat:@"or_history_%@", cid]; }
+ (void)save:(NSDictionary *)contact {
    NSMutableArray *a = [NSMutableArray arrayWithArray:[self all]];
    NSString *cid = [contact objectForKey:@"id"]; BOOL replaced = NO;
    for (NSUInteger i = 0; i < [a count]; i++) if ([[[a objectAtIndex:i] objectForKey:@"id"] isEqualToString:cid]) { [a replaceObjectAtIndex:i withObject:contact]; replaced = YES; }
    if (!replaced) [a addObject:contact];
    [[self d] setObject:a forKey:kContacts]; [[self d] synchronize];
}
+ (void)remove:(NSString *)cid {
    NSMutableArray *a = [NSMutableArray array];
    for (NSDictionary *c in [self all]) if (![[c objectForKey:@"id"] isEqualToString:cid]) [a addObject:c];
    [[self d] setObject:a forKey:kContacts];
    [[self d] removeObjectForKey:[self historyKey:cid]];
    [[self d] synchronize];
}
+ (NSDictionary *)newContactWithName:(NSString *)name model:(NSString *)model prompt:(NSString *)prompt {
    CFUUIDRef u = CFUUIDCreate(NULL); NSString *cid = [(NSString *)CFUUIDCreateString(NULL, u) autorelease]; CFRelease(u);
    return [NSDictionary dictionaryWithObjectsAndKeys:cid, @"id", name, @"name", model ?: @"", @"model", prompt ?: @"", @"prompt", nil];
}
+ (NSDictionary *)randomOther:(NSString *)cid {
    NSMutableArray *others = [NSMutableArray array];
    for (NSDictionary *c in [self all]) if (![[c objectForKey:@"id"] isEqualToString:cid]) [others addObject:c];
    if (![others count]) return nil;
    return [others objectAtIndex:arc4random() % [others count]];
}
+ (void)seedDefaultsIfNeeded {
    if ([[self all] count]) return;
    // migrate the old single conversation into the first contact
    NSArray *old = [[self d] arrayForKey:@"or_history"];
    NSString *defaultModel = [[self d] stringForKey:@"or_model"] ?: @"openrelay/gpt-oss-120b";
    NSArray *seed = [NSArray arrayWithObjects:
        [NSArray arrayWithObjects:@"OpenRelay", @"", @"", nil],
        [NSArray arrayWithObjects:@"Barista", @"", @"You are the barista at the user's regular coffee shop. Warm, quick, a little nosy about their day. You remember their usual. Keep it to one or two bursts.", nil],
        [NSArray arrayWithObjects:@"Sarcastic Friend", @"", @"You are the user's oldest friend. Dry, teasing, loyal underneath. You never explain the joke. You text like a real person: lowercase, short, occasionally just one word.", nil],
        [NSArray arrayWithObjects:@"Spanish Tutor", @"", @"You are a patient Spanish tutor texting a beginner. Reply mostly in simple Spanish with a short English gloss in parentheses when a word is new. Gently correct mistakes by restating the sentence correctly. One burst per idea.", nil],
        [NSArray arrayWithObjects:@"Grandpa", @"", @"You are the user's grandpa. It is 2010 as far as you are concerned, and you are thrilled they finally got an iPod touch. You give advice that is 60 percent wise and 40 percent about the weather. You sign off bursts with Love, Grandpa about a third of the time.", nil],
        [NSArray arrayWithObjects:@"Flashback 2010", @"", @"It is October 2010. Your knowledge stops there completely. The newest iPhone is the iPhone 4, the iPad came out this spring, Instagram launched this week, and you are excited about all of it. Anything after 2010 you have never heard of; if asked, you guess like it is a rumor. Never break character.", nil],
        [NSArray arrayWithObjects:@"Zork", @"", @"You run a text adventure in the style of Zork, one room at a time, by text message. Each reply is two or three short bursts: what the user sees, then what is here, then a prompt like What do you do? Track inventory and the map faithfully. Start in a white house west of a field. Never use markdown. Be dry and a little funny.", nil],
        nil];
    NSMutableArray *a = [NSMutableArray array];
    for (NSArray *s in seed) {
        NSDictionary *c = [self newContactWithName:[s objectAtIndex:0] model:defaultModel prompt:[s objectAtIndex:2]];
        [a addObject:c];
    }
    [[self d] setObject:a forKey:kContacts];
    NSString *firstId = [[a objectAtIndex:0] objectForKey:@"id"];
    if ([old count]) { [[self d] setObject:old forKey:[self historyKey:firstId]]; [[self d] removeObjectForKey:@"or_history"]; }
    [[self d] setObject:firstId forKey:kCurrent];
    [[self d] synchronize];
}
@end

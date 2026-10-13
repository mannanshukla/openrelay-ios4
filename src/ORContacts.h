#import <Foundation/Foundation.h>
// A contact is a persona: name, model, system prompt. Each has its own conversation history.
// Stored in NSUserDefaults as an array of dictionaries under or_contacts.
@interface ORContacts : NSObject
+ (NSArray *)all;                                   // array of NSDictionary {id, name, model, prompt, flashback}
+ (NSDictionary *)contactWithId:(NSString *)cid;
+ (NSString *)currentId;   + (void)setCurrentId:(NSString *)cid;
+ (NSDictionary *)current;
+ (void)save:(NSDictionary *)contact;               // insert or replace by id
+ (void)remove:(NSString *)cid;
+ (NSDictionary *)newContactWithName:(NSString *)name model:(NSString *)model prompt:(NSString *)prompt;
+ (NSString *)historyKey:(NSString *)cid;
+ (void)seedDefaultsIfNeeded;
+ (NSDictionary *)randomOther:(NSString *)cid;      // for shake to shuffle
@end

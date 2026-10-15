#import "ORContactsViewController.h"
#import "ORContactEditViewController.h"
#import "ORChatViewController.h"
#import "ORContacts.h"
#import "ORClient.h"

@implementation ORContactsViewController
- (id)init {
    if ((self = [super initWithStyle:UITableViewStylePlain])) {
        self.title = @"Messages";
        self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCompose target:self action:@selector(addContact)] autorelease];
    }
    return self;
}
- (void)viewDidLoad { [super viewDidLoad]; self.tableView.rowHeight = 64; }
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self.tableView reloadData]; }
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (![[ORSettings apiKey] length]) [self performSelector:@selector(needKey) withObject:nil afterDelay:0.6];
}
- (void)needKey { UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Add your OpenRelay key" message:@"Open the Settings app, scroll to OpenRelay, and paste your API key. Model, pacing, sounds and the daily texts live there too." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil]; [a show]; [a release]; }
- (void)addContact {
    ORContactEditViewController *e = [[ORContactEditViewController alloc] initWithContact:nil];
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:e];
    nav.navigationBar.tintColor = self.navigationController.navigationBar.tintColor;
    [self presentModalViewController:nav animated:YES]; [nav release]; [e release];
}
- (void)openContact:(NSDictionary *)contact animated:(BOOL)animated {
    [ORContacts setCurrentId:[contact objectForKey:@"id"]];
    ORChatViewController *chat = [[ORChatViewController alloc] initWithContact:contact];
    [self.navigationController pushViewController:chat animated:animated];
    [chat release];
}
- (NSString *)previewFor:(NSDictionary *)c {
    NSArray *h = [[NSUserDefaults standardUserDefaults] arrayForKey:[ORContacts historyKey:[c objectForKey:@"id"]]];
    for (NSDictionary *m in [h reverseObjectEnumerator]) {
        if ([[m objectForKey:@"hidden"] boolValue]) continue;
        NSString *t = [m objectForKey:@"content"];
        if ([t length]) return [t stringByReplacingOccurrencesOfString:@"\n" withString:@" "];
        if ([[m objectForKey:@"image"] length]) return @"Photo";
    }
    NSString *p = [c objectForKey:@"prompt"];
    return [p length] ? [[p componentsSeparatedByString:@"."] objectAtIndex:0] : @"No messages yet";
}
- (NSString *)timeFor:(NSDictionary *)c {
    NSArray *h = [[NSUserDefaults standardUserDefaults] arrayForKey:[ORContacts historyKey:[c objectForKey:@"id"]]];
    NSNumber *ts = [[h lastObject] objectForKey:@"ts"];
    if (!ts) return @"";
    NSDate *d = [NSDate dateWithTimeIntervalSince1970:[ts doubleValue]];
    NSDateFormatter *f = [[[NSDateFormatter alloc] init] autorelease];
    NSCalendar *cal = [NSCalendar currentCalendar];
    NSDateComponents *a = [cal components:(NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit) fromDate:d];
    NSDateComponents *b = [cal components:(NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit) fromDate:[NSDate date]];
    BOOL today = [a year] == [b year] && [a month] == [b month] && [a day] == [b day];
    [f setDateFormat:today ? @"h:mm a" : @"M/d/yy"];
    return [f stringFromDate:d];
}
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return [[ORContacts all] count]; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *rid = @"contact";
    UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:rid];
    if (!c) {
        c = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:rid] autorelease];
        c.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        c.textLabel.font = [UIFont boldSystemFontOfSize:17];
        c.detailTextLabel.font = [UIFont systemFontOfSize:14]; c.detailTextLabel.textColor = [UIColor colorWithWhite:0.4 alpha:1];
        c.detailTextLabel.numberOfLines = 2;
    }
    NSDictionary *k = [[ORContacts all] objectAtIndex:ip.row];
    c.textLabel.text = [k objectForKey:@"name"];
    c.detailTextLabel.text = [self previewFor:k];
    UILabel *t = (UILabel *)[c.contentView viewWithTag:77];
    if (!t) { t = [[[UILabel alloc] initWithFrame:CGRectMake(c.contentView.bounds.size.width - 80, 8, 70, 16)] autorelease]; t.tag = 77; t.font = [UIFont systemFontOfSize:12]; t.textColor = [UIColor colorWithRed:0.22 green:0.33 blue:0.53 alpha:1]; t.textAlignment = UITextAlignmentRight; t.backgroundColor = [UIColor clearColor]; t.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin; [c.contentView addSubview:t]; }
    t.text = [self timeFor:k];
    return c;
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [self openContact:[[ORContacts all] objectAtIndex:ip.row] animated:YES];
}
- (void)tableView:(UITableView *)tv accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)ip {}
- (BOOL)tableView:(UITableView *)tv canEditRowAtIndexPath:(NSIndexPath *)ip { return YES; }
- (void)tableView:(UITableView *)tv commitEditingStyle:(UITableViewCellEditingStyle)st forRowAtIndexPath:(NSIndexPath *)ip {
    if (st != UITableViewCellEditingStyleDelete) return;
    NSDictionary *k = [[ORContacts all] objectAtIndex:ip.row];
    [ORContacts remove:[k objectForKey:@"id"]];
    [tv deleteRowsAtIndexPaths:[NSArray arrayWithObject:ip] withRowAnimation:UITableViewRowAnimationFade];
}
@end

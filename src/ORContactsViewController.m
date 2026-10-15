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
- (NSString *)flatten:(NSString *)t {   // one line of plain text for the preview: no list dashes, headings or **bold** marks
    for (NSString *m in [NSArray arrayWithObjects:@"**", @"__", @"`", nil]) t = [t stringByReplacingOccurrencesOfString:m withString:@""];
    NSMutableArray *out = [NSMutableArray array];
    for (NSString *line in [t componentsSeparatedByString:@"\n"]) {
        NSString *l = [line stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        while ([l hasPrefix:@"#"]) l = [l substringFromIndex:1];
        for (NSString *b in [NSArray arrayWithObjects:@"- ", @"* ", @"\u2022 ", nil]) if ([l hasPrefix:b]) l = [l substringFromIndex:[b length]];
        NSUInteger d = 0; while (d < [l length] && isdigit([l characterAtIndex:d])) d++;
        if (d > 0 && d + 1 < [l length] && ([l characterAtIndex:d] == '.' || [l characterAtIndex:d] == ')') && [l characterAtIndex:d + 1] == ' ') l = [l substringFromIndex:d + 2];
        l = [l stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        if ([l length]) [out addObject:l];
    }
    return [out componentsJoinedByString:@" "];
}
- (NSString *)previewFor:(NSDictionary *)c {
    NSArray *h = [[NSUserDefaults standardUserDefaults] arrayForKey:[ORContacts historyKey:[c objectForKey:@"id"]]];
    for (NSDictionary *m in [h reverseObjectEnumerator]) {
        if ([[m objectForKey:@"hidden"] boolValue]) continue;
        NSString *t = [m objectForKey:@"content"];
        if ([t length]) return [self flatten:t];
        if ([[m objectForKey:@"image"] length]) return @"Photo";
    }
    return @"No messages yet. Say hi.";
}
- (NSString *)timeFor:(NSDictionary *)c {
    NSArray *h = [[NSUserDefaults standardUserDefaults] arrayForKey:[ORContacts historyKey:[c objectForKey:@"id"]]];
    NSNumber *ts = [[h lastObject] objectForKey:@"ts"];
    if (!ts) return @"";
    NSDate *d = [NSDate dateWithTimeIntervalSince1970:[ts doubleValue]];
    NSDateFormatter *f = [[[NSDateFormatter alloc] init] autorelease];
    NSCalendar *cal = [NSCalendar currentCalendar];
    // like Messages: a time today, "Yesterday", the weekday within the week, then a date
    NSDateComponents *a = [cal components:(NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit) fromDate:d];
    NSDateComponents *b = [cal components:(NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit) fromDate:[NSDate date]];
    NSInteger days = [[cal components:NSDayCalendarUnit fromDate:[cal dateFromComponents:a] toDate:[cal dateFromComponents:b] options:0] day];
    if (days <= 0) [f setDateFormat:@"h:mm a"];
    else if (days == 1) return @"Yesterday";
    else if (days < 7) [f setDateFormat:@"EEEE"];
    else [f setDateFormat:@"M/d/yy"];
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

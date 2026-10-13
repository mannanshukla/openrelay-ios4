#import "ORSettingsViewController.h"
#import "ORClient.h"
#import "ORUnprompted.h"

enum { SEC_KEY = 0, SEC_MODEL, SEC_BEHAVIOR, SEC_DAILY, SEC_SYS, SEC_ADV, SEC_ABOUT, SEC_COUNT };

@implementation ORSettingsViewController

- (id)init {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        self.title = @"Settings";
        self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)] autorelease];
    }
    return self;
}
- (void)dealloc { [keyField release]; [modelField release]; [baseField release]; [sysField release]; [pacingSwitch release]; [soundSwitch release]; [unpromptedSeg release]; [models release]; [modelError release]; [super dealloc]; }

- (UITextField *)field:(NSString *)placeholder value:(NSString *)v secure:(BOOL)secure {
    UITextField *f = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 260, 30)];
    f.placeholder = placeholder; f.text = v; f.secureTextEntry = secure;
    f.font = [UIFont systemFontOfSize:15]; f.delegate = self;
    f.autocorrectionType = UITextAutocorrectionTypeNo; f.autocapitalizationType = UITextAutocapitalizationTypeNone;
    f.returnKeyType = UIReturnKeyDone; f.clearButtonMode = UITextFieldViewModeWhileEditing;
    f.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    return f;
}
- (UISwitch *)sw:(BOOL)on { UISwitch *s = [[UISwitch alloc] initWithFrame:CGRectZero]; s.on = on; [s addTarget:self action:@selector(switched:) forControlEvents:UIControlEventValueChanged]; return s; }
- (void)viewDidLoad {
    [super viewDidLoad];
    keyField   = [self field:@"or_..." value:[ORSettings apiKey] secure:YES];
    modelField = [self field:@"openrelay/gpt-oss-120b" value:[ORSettings model] secure:NO];
    baseField  = [self field:@"https://inference.openrelay.inc" value:[ORSettings baseURL] secure:NO];
    baseField.keyboardType = UIKeyboardTypeURL;
    sysField   = [self field:@"Extra instructions (optional)" value:[ORSettings systemPrompt] secure:NO];
    sysField.autocapitalizationType = UITextAutocapitalizationTypeSentences; sysField.autocorrectionType = UITextAutocorrectionTypeDefault;
    pacingSwitch = [self sw:[ORSettings pacing]];
    soundSwitch  = [self sw:[ORSettings sounds]];
    unpromptedSeg = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"Off", @"1", @"2", @"3", nil]];
    unpromptedSeg.segmentedControlStyle = UISegmentedControlStyleBar;
    unpromptedSeg.selectedSegmentIndex = MIN(3, MAX(0, [ORSettings unpromptedPerDay]));
    [unpromptedSeg addTarget:self action:@selector(unpromptedChanged) forControlEvents:UIControlEventValueChanged];
}
- (void)switched:(UISwitch *)s {
    if (s == pacingSwitch) [ORSettings setPacing:s.on];
    else if (s == soundSwitch) [ORSettings setSounds:s.on];
}
- (void)unpromptedChanged {
    [self save];
    [ORSettings setUnpromptedPerDay:unpromptedSeg.selectedSegmentIndex];
    if (unpromptedSeg.selectedSegmentIndex == 0) [[ORUnprompted shared] cancelAll];
    else [[ORUnprompted shared] topUp];
}
- (void)save {
    [ORSettings setApiKey:[keyField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    [ORSettings setModel:[modelField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]]];
    NSString *b = [baseField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    while ([b hasSuffix:@"/"]) b = [b substringToIndex:[b length]-1];
    [ORSettings setBaseURL:b];
    [ORSettings setSystemPrompt:sysField.text];
}
- (void)done { [self save]; [self dismissModalViewControllerAnimated:YES]; }
- (BOOL)textFieldShouldReturn:(UITextField *)tf { [tf resignFirstResponder]; return YES; }
- (void)textFieldDidEndEditing:(UITextField *)tf { [self save]; }

- (void)loadModels {
    [self save];
    if (![[ORSettings apiKey] length]) { [modelError release]; modelError = [@"Enter your API key first." copy]; [self.tableView reloadData]; return; }
    loadingModels = YES; [modelError release]; modelError = nil; [self.tableView reloadData];
    [self performSelectorInBackground:@selector(fetchModels) withObject:nil];
}
- (void)fetchModels {
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSString *err = nil;
    NSArray *ids = [ORClient fetchModelsWithError:&err];
    [self performSelectorOnMainThread:@selector(modelsLoaded:) withObject:[NSArray arrayWithObjects:(ids ?: [NSArray array]), (err ?: @""), nil] waitUntilDone:NO];
    [pool release];
}
- (void)modelsLoaded:(NSArray *)r {
    loadingModels = NO;
    [models release]; models = [[r objectAtIndex:0] retain];
    [modelError release]; modelError = [[r objectAtIndex:1] length] ? [[r objectAtIndex:1] copy] : nil;
    if (![models count] && !modelError) modelError = [@"No models returned." copy];
    [self.tableView reloadData];
}

#pragma mark table
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return SEC_COUNT; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s {
    switch (s) {
        case SEC_KEY: return 1;
        case SEC_MODEL: return 2 + [models count];
        case SEC_BEHAVIOR: return 2;
        case SEC_DAILY: return 1;
        case SEC_SYS: return 1;
        case SEC_ADV: return 1;
        case SEC_ABOUT: return 1;
    }
    return 0;
}
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s {
    switch (s) {
        case SEC_KEY: return @"API Key";
        case SEC_MODEL: return @"Default Model";
        case SEC_BEHAVIOR: return @"Texting";
        case SEC_DAILY: return @"Texts You First";
        case SEC_SYS: return @"Extra Instructions";
        case SEC_ADV: return @"Server";
        case SEC_ABOUT: return @"About";
    }
    return nil;
}
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    if (s == SEC_KEY) return @"Your key starts with or_ and is stored only on this iPod.";
    if (s == SEC_MODEL) return modelError ?: (loadingModels ? @"Loading..." : @"Contacts without a model of their own use this one.");
    if (s == SEC_BEHAVIOR) return @"Natural pacing holds each message for a beat, like someone typing. Off shows words as they arrive.";
    if (s == SEC_DAILY) return @"How many times a day your contacts text you out of the blue, between 9 AM and 9:30 PM. The messages are written while the app is open and show up on the lock screen when their time comes.";
    if (s == SEC_SYS) return @"Added on top of the built-in rules and the contact's personality.";
    if (s == SEC_ABOUT) return @"Built for iOS 4 with the iPhoneOS 4.3 SDK.";
    return nil;
}
- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip { return 44; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *fid = @"field", *bid = @"button", *mid = @"model", *tid = @"text", *sid = @"switch", *pid = @"picker";
    NSInteger s = ip.section, r = ip.row;
    if (s == SEC_MODEL && r == 1) {
        UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:bid];
        if (!c) { c = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:bid] autorelease]; c.textLabel.textAlignment = UITextAlignmentCenter; c.textLabel.textColor = [UIColor colorWithRed:0.22 green:0.33 blue:0.53 alpha:1]; }
        c.textLabel.text = loadingModels ? @"Loading..." : @"Load Models";
        return c;
    }
    if (s == SEC_MODEL && r >= 2) {
        UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:mid];
        if (!c) { c = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:mid] autorelease]; c.textLabel.font = [UIFont systemFontOfSize:14]; c.detailTextLabel.font = [UIFont systemFontOfSize:12]; }
        NSString *m = [models objectAtIndex:r-2];
        c.textLabel.text = m;
        c.detailTextLabel.text = [[ORSettings visionModels] containsObject:m] ? @"vision" : @"";
        c.accessoryType = [m isEqualToString:[ORSettings model]] ? UITableViewCellAccessoryCheckmark : UITableViewCellAccessoryNone;
        return c;
    }
    if (s == SEC_BEHAVIOR) {
        UITableViewCell *c = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:sid] autorelease];
        c.selectionStyle = UITableViewCellSelectionStyleNone;
        c.textLabel.text = r == 0 ? @"Natural pacing" : @"Sounds";
        c.accessoryView = r == 0 ? pacingSwitch : soundSwitch;
        return c;
    }
    if (s == SEC_DAILY) {
        UITableViewCell *c = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:pid] autorelease];
        c.selectionStyle = UITableViewCellSelectionStyleNone;
        c.textLabel.text = @"Per day";
        unpromptedSeg.frame = CGRectMake(0, 0, 150, 30);
        c.accessoryView = unpromptedSeg;
        return c;
    }
    if (s == SEC_ABOUT) {
        UITableViewCell *c = [tv dequeueReusableCellWithIdentifier:tid];
        if (!c) { c = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:tid] autorelease]; c.selectionStyle = UITableViewCellSelectionStyleNone; }
        c.textLabel.text = @"OpenRelay"; c.detailTextLabel.text = @"1.1";
        return c;
    }
    UITableViewCell *c = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:fid] autorelease];
    c.selectionStyle = UITableViewCellSelectionStyleNone;
    UITextField *f = (s == SEC_KEY) ? keyField : (s == SEC_MODEL) ? modelField : (s == SEC_SYS) ? sysField : baseField;
    f.frame = CGRectMake(10, 7, c.contentView.bounds.size.width - 20, 30);
    f.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [c.contentView addSubview:f];
    return c;
}
- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)ip {
    [tv deselectRowAtIndexPath:ip animated:YES];
    if (ip.section == SEC_MODEL && ip.row == 1 && !loadingModels) [self loadModels];
    else if (ip.section == SEC_MODEL && ip.row >= 2) {
        modelField.text = [models objectAtIndex:ip.row-2]; [self save];
        [tv reloadSections:[NSIndexSet indexSetWithIndex:SEC_MODEL] withRowAnimation:UITableViewRowAnimationNone];
    }
}
@end

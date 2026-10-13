#import "ORContactEditViewController.h"
#import "ORContacts.h"
#import "ORClient.h"

@implementation ORContactEditViewController
- (id)initWithContact:(NSDictionary *)c {
    if ((self = [super initWithStyle:UITableViewStyleGrouped])) {
        isNew = (c == nil);
        contact = [[NSMutableDictionary alloc] initWithDictionary:(c ?: [ORContacts newContactWithName:@"" model:[ORSettings model] prompt:@""])];
        self.title = isNew ? @"New Contact" : @"Edit Contact";
        self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done)] autorelease];
        if (isNew) self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(cancel)] autorelease];
    }
    return self;
}
- (void)dealloc { [contact release]; [nameField release]; [modelField release]; [promptView release]; [super dealloc]; }
- (UITextField *)field:(NSString *)ph value:(NSString *)v {
    UITextField *f = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 260, 30)];
    f.placeholder = ph; f.text = v; f.font = [UIFont systemFontOfSize:15]; f.delegate = self;
    f.autocorrectionType = UITextAutocorrectionTypeNo; f.returnKeyType = UIReturnKeyDone; f.clearButtonMode = UITextFieldViewModeWhileEditing;
    f.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    return f;
}
- (void)viewDidLoad {
    [super viewDidLoad];
    nameField = [self field:@"Name" value:[contact objectForKey:@"name"]];
    nameField.autocapitalizationType = UITextAutocapitalizationTypeWords;
    modelField = [self field:@"Model (blank = default)" value:[contact objectForKey:@"model"]];
    modelField.autocapitalizationType = UITextAutocapitalizationTypeNone;
    promptView = [[UITextView alloc] initWithFrame:CGRectMake(0, 0, 280, 130)];
    promptView.font = [UIFont systemFontOfSize:14]; promptView.text = [contact objectForKey:@"prompt"]; promptView.delegate = self;
    promptView.backgroundColor = [UIColor clearColor];
}
- (void)collect {
    [contact setObject:[nameField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] forKey:@"name"];
    [contact setObject:[modelField.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] forKey:@"model"];
    [contact setObject:promptView.text ?: @"" forKey:@"prompt"];
}
- (void)done {
    [self collect];
    if (![[contact objectForKey:@"name"] length]) [contact setObject:@"Contact" forKey:@"name"];
    [ORContacts save:contact];
    if (isNew) [self dismissModalViewControllerAnimated:YES]; else [self.navigationController popViewControllerAnimated:YES];
}
- (void)cancel { [self dismissModalViewControllerAnimated:YES]; }
- (BOOL)textFieldShouldReturn:(UITextField *)tf { [tf resignFirstResponder]; return YES; }

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tv { return 3; }
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return 1; }
- (NSString *)tableView:(UITableView *)tv titleForHeaderInSection:(NSInteger)s { return s == 0 ? @"Name" : s == 1 ? @"Model" : @"Personality"; }
- (NSString *)tableView:(UITableView *)tv titleForFooterInSection:(NSInteger)s {
    if (s == 1) return @"Leave blank to use the default model from Settings.";
    if (s == 2) return @"Who this contact is and how they text. The app adds its own rules about short plain-text bursts underneath.";
    return nil;
}
- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip { return ip.section == 2 ? 140 : 44; }
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    UITableViewCell *c = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil] autorelease];
    c.selectionStyle = UITableViewCellSelectionStyleNone;
    UIView *v = ip.section == 0 ? (UIView *)nameField : ip.section == 1 ? (UIView *)modelField : (UIView *)promptView;
    v.frame = ip.section == 2 ? CGRectMake(5, 5, c.contentView.bounds.size.width - 10, 130) : CGRectMake(10, 7, c.contentView.bounds.size.width - 20, 30);
    v.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [c.contentView addSubview:v];
    return c;
}
@end

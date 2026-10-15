#import "ORChatViewController.h"
#import "ORBubbleCell.h"
#import "ORContacts.h"
#import "ORImage.h"
#import "ORJSON.h"
#import "ORUnprompted.h"
#import <AudioToolbox/AudioToolbox.h>
#import <AssetsLibrary/AssetsLibrary.h>

#define BAR_H 44.0f
#define CAM_W 36.0f
#define SHEET_CLEAR 1
#define SHEET_PHOTO 2
#define SHEET_SHAKE 3
#define ALERT_MODEL 7

static SystemSoundID sndSent = 0, sndReceived = 0;
static void loadSounds(void) {
    if (sndSent) return;
    NSURL *a = [NSURL fileURLWithPath:@"/System/Library/Audio/UISounds/SentMessage.caf"];
    NSURL *b = [NSURL fileURLWithPath:@"/System/Library/Audio/UISounds/ReceivedMessage.caf"];
    AudioServicesCreateSystemSoundID((CFURLRef)a, &sndSent);
    AudioServicesCreateSystemSoundID((CFURLRef)b, &sndReceived);
}

// iOS 5 Messages input toolbar
@interface ORInputBar : UIView @end
@implementation ORInputBar
- (void)drawRect:(CGRect)r {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGFloat c[12] = {0.90,0.91,0.93,1, 0.79,0.81,0.84,1, 0.69,0.71,0.75,1};
    CGGradientRef g = CGGradientCreateWithColorComponents(cs, c, NULL, 3);
    CGContextDrawLinearGradient(ctx, g, CGPointMake(0, 0), CGPointMake(0, self.bounds.size.height), 0);
    CGGradientRelease(g); CGColorSpaceRelease(cs);
    [[UIColor colorWithWhite:0.52 alpha:1] set]; CGContextFillRect(ctx, CGRectMake(0, 0, self.bounds.size.width, 1));
    [[UIColor colorWithWhite:1 alpha:0.7] set]; CGContextFillRect(ctx, CGRectMake(0, 1, self.bounds.size.width, 1));
}
@end

// table view that lets the controller be first responder for shake + menu
@interface ORChatTable : UITableView @end
@implementation ORChatTable
- (BOOL)canBecomeFirstResponder { return NO; }
@end

@implementation ORChatViewController

- (id)initWithContact:(NSDictionary *)c {
    if ((self = [super initWithNibName:nil bundle:nil])) {
        contact = [c retain];
        historyKey = [[ORContacts historyKey:[c objectForKey:@"id"]] retain];
        self.title = [c objectForKey:@"name"];
        messages = [[NSMutableArray alloc] initWithArray:([[NSUserDefaults standardUserDefaults] arrayForKey:historyKey] ?: [NSArray array])];
        client = [[ORClient alloc] init]; client.delegate = self;
        client.personaPrompt = [c objectForKey:@"prompt"];
        client.modelOverride = [c objectForKey:@"model"];
        imageCache = [[NSMutableDictionary alloc] init];
        burstQueue = [[NSMutableArray alloc] init];
        loadSounds();
    }
    return self;
}
- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [burstTimer invalidate]; [typingTimer invalidate];
    client.delegate = nil; [client release]; [messages release]; [pending release]; [burstQueue release];
    [table release]; [inputBar release]; [input release]; [sendButton release]; [cameraButton release]; [spinner release];
    [attachedImage release]; [attachedBase64 release]; [imageCache release]; [contact release]; [historyKey release]; [menuRow release];
    [super dealloc];
}

#pragma mark view
- (void)loadView {
    UIView *root = [[UIView alloc] initWithFrame:[[UIScreen mainScreen] applicationFrame]];
    root.backgroundColor = [UIColor colorWithRed:0.93 green:0.94 blue:0.92 alpha:1];
    self.view = root; [root release];
    CGRect b = root.bounds;

    table = [[ORChatTable alloc] initWithFrame:CGRectMake(0, 0, b.size.width, b.size.height - BAR_H) style:UITableViewStylePlain];
    table.dataSource = self; table.delegate = self;
    table.separatorStyle = UITableViewCellSeparatorStyleNone;
    table.backgroundColor = [UIColor clearColor];
    table.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [root addSubview:table];
    UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(longPress:)];
    [table addGestureRecognizer:lp]; [lp release];

    inputBar = [[ORInputBar alloc] initWithFrame:CGRectMake(0, b.size.height - BAR_H, b.size.width, BAR_H)];
    inputBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;
    inputBar.backgroundColor = [UIColor clearColor]; inputBar.opaque = NO;
    [root addSubview:inputBar];

    cameraButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
    cameraButton.frame = CGRectMake(2, 7, CAM_W, 30);
    [cameraButton setImage:[ORImage cameraGlyph] forState:UIControlStateNormal];
    [cameraButton addTarget:self action:@selector(pickPhoto) forControlEvents:UIControlEventTouchUpInside];
    [inputBar addSubview:cameraButton];

    CGFloat fx = 2 + CAM_W + 2;
    input = [[UITextField alloc] initWithFrame:CGRectMake(fx, 7, b.size.width - fx - 6 - 64, 30)];
    input.borderStyle = UITextBorderStyleRoundedRect;
    input.font = [ORStyle messageFont];
    input.placeholder = @"Message";
    input.returnKeyType = UIReturnKeySend;
    input.enablesReturnKeyAutomatically = YES;
    input.autocapitalizationType = UITextAutocapitalizationTypeSentences;
    input.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    input.delegate = self;
    input.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    [inputBar addSubview:input];

    sendButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
    sendButton.frame = CGRectMake(b.size.width - 6 - 58, 8, 58, 27);
    sendButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [sendButton setTitle:@"Send" forState:UIControlStateNormal];
    [sendButton setBackgroundImage:[ORStyle sendButtonImage:YES] forState:UIControlStateNormal];
    [sendButton setBackgroundImage:[ORStyle sendButtonImage:NO] forState:UIControlStateDisabled];
    [sendButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [sendButton setTitleColor:[UIColor colorWithWhite:0.95 alpha:1] forState:UIControlStateDisabled];
    [sendButton setTitleShadowColor:[UIColor colorWithWhite:0 alpha:0.4] forState:UIControlStateNormal];
    sendButton.titleLabel.shadowOffset = CGSizeMake(0, -1);
    sendButton.titleLabel.font = [UIFont boldSystemFontOfSize:16];
    [sendButton addTarget:self action:@selector(send) forControlEvents:UIControlEventTouchUpInside];
    [inputBar addSubview:sendButton];

    spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
    self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Clear" style:UIBarButtonItemStyleBordered target:self action:@selector(clearChat)] autorelease];
}
- (void)viewDidLoad {
    [super viewDidLoad];
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [nc addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    [nc addObserver:self selector:@selector(historyChanged:) name:ORHistoryChangedNotification object:nil];
}
- (void)historyChanged:(NSNotification *)n {
    if (![[n object] isEqualToString:[contact objectForKey:@"id"]] || client.running) return;
    NSArray *fresh = [[NSUserDefaults standardUserDefaults] arrayForKey:historyKey];
    if ([fresh count] <= [messages count]) return;
    [messages setArray:fresh];
    [self playSound:sndReceived];
    [self reload]; [self scrollToBottom:YES];
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    // pick up texts that were filed into this thread while it was not on screen
    NSArray *fresh = [[NSUserDefaults standardUserDefaults] arrayForKey:historyKey];
    if (!client.running && [fresh count] > [messages count]) { [messages setArray:fresh]; [self reload]; }
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self scrollToBottom:NO];
    [self becomeFirstResponder];   // for shake
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    if ([d boolForKey:@"or_scroll_top"] && [messages count]) [table scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] atScrollPosition:UITableViewScrollPositionTop animated:NO];
    NSString *autoText = [d stringForKey:@"or_test_send"];   // test hook: send this text on appear, once
    if ([autoText length]) { [d removeObjectForKey:@"or_test_send"]; [d synchronize]; input.text = autoText; [self performSelector:@selector(send) withObject:nil afterDelay:0.5]; }
    if ([d boolForKey:@"or_no_autofocus"]) return;
    if ([[ORSettings apiKey] length]) [input becomeFirstResponder];
}
- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated]; [self resignFirstResponder]; [self persist]; }
- (BOOL)canBecomeFirstResponder { return YES; }

#pragma mark keyboard
- (void)keyboardWillShow:(NSNotification *)n {
    CGRect kb = [[[n userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    kb = [self.view convertRect:kb fromView:nil];
    keyboardHeight = self.view.bounds.size.height - kb.origin.y;
    [self layoutForKeyboard:[[[n userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue]];
}
- (void)keyboardWillHide:(NSNotification *)n { keyboardHeight = 0; [self layoutForKeyboard:[[[n userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue]]; }
- (void)layoutForKeyboard:(NSTimeInterval)dur {
    CGRect b = self.view.bounds;
    [UIView beginAnimations:nil context:NULL]; [UIView setAnimationDuration:dur]; [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
    inputBar.frame = CGRectMake(0, b.size.height - keyboardHeight - BAR_H, b.size.width, BAR_H);
    table.frame = CGRectMake(0, 0, b.size.width, b.size.height - keyboardHeight - BAR_H);
    [UIView commitAnimations];
    [self scrollToBottom:YES];
}

#pragma mark history helpers
- (NSArray *)visible {   // rows shown in the table: non-hidden messages, plus a typing bubble at the end
    NSMutableArray *v = [NSMutableArray arrayWithCapacity:[messages count] + 1];
    for (NSDictionary *m in messages) if (![[m objectForKey:@"hidden"] boolValue]) [v addObject:m];
    if (typing) [v addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"typing", @"role", @"", @"content", nil]];
    return v;
}
- (void)persist {
    [[NSUserDefaults standardUserDefaults] setObject:messages forKey:historyKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
}
- (NSDictionary *)assistantMessage:(NSString *)text ts:(NSNumber *)ts {
    return [NSDictionary dictionaryWithObjectsAndKeys:@"assistant", @"role", text, @"content", ts, @"ts", nil];
}
- (NSNumber *)now { return [NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]]; }
- (void)reload { [table reloadData]; }
- (void)playSound:(SystemSoundID)s { if ([ORSettings sounds] && s) AudioServicesPlaySystemSound(s); }

#pragma mark typing indicator
- (void)setTyping:(BOOL)on {
    if (typing == on) return;
    typing = on;
    if (on) { typingPhase = 0; typingTimer = [[NSTimer scheduledTimerWithTimeInterval:0.35 target:self selector:@selector(tickTyping) userInfo:nil repeats:YES] retain]; }
    else { [typingTimer invalidate]; [typingTimer release]; typingTimer = nil; }
    [self reload]; [self scrollToBottom:YES];
}
- (void)tickTyping {
    typingPhase++;
    NSInteger n = [[self visible] count];
    if (!n) return;
    ORBubbleCell *cell = (ORBubbleCell *)[table cellForRowAtIndexPath:[NSIndexPath indexPathForRow:n-1 inSection:0]];
    if ([cell.bubble.role isEqualToString:@"typing"]) cell.bubble.typingPhase = typingPhase;
}

#pragma mark actions
- (void)clearChat {
    if (![messages count]) return;
    UIActionSheet *as = [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Clear Conversation" otherButtonTitles:nil];
    as.tag = SHEET_CLEAR; [as showInView:self.view]; [as release];
}
- (void)doClear {
    [client cancel]; [pending release]; pending = nil; [burstQueue removeAllObjects]; [burstTimer invalidate]; [burstTimer release]; burstTimer = nil;
    [self setTyping:NO]; [self setBusy:NO];
    [messages removeAllObjects]; [imageCache removeAllObjects]; [self persist]; [self reload];
}
- (void)motionEnded:(UIEventSubtype)motion withEvent:(UIEvent *)event {
    if (motion != UIEventSubtypeMotionShake) return;
    UIActionSheet *as = [[UIActionSheet alloc] initWithTitle:@"Shake" delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:@"Clear Conversation" otherButtonTitles:@"Text Someone Else", nil];
    as.tag = SHEET_SHAKE; [as showInView:self.view]; [as release];
}
- (void)pickPhoto {
    if (attachedImage) {
        [attachedImage release]; attachedImage = nil; [attachedBase64 release]; attachedBase64 = nil;
        [cameraButton setImage:[ORImage cameraGlyph] forState:UIControlStateNormal];
        return;
    }
    BOOL cam = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
    UIActionSheet *as = cam
        ? [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Take Photo", @"Choose Existing", @"Last Photo", nil]
        : [[UIActionSheet alloc] initWithTitle:nil delegate:self cancelButtonTitle:@"Cancel" destructiveButtonTitle:nil otherButtonTitles:@"Choose Existing", @"Last Photo", nil];
    as.tag = SHEET_PHOTO; [as showInView:self.view]; [as release];
}
- (void)actionSheet:(UIActionSheet *)as clickedButtonAtIndex:(NSInteger)i {
    if (as.tag == SHEET_CLEAR) { if (i == as.destructiveButtonIndex) [self doClear]; return; }
    if (as.tag == SHEET_SHAKE) {
        if (i == as.destructiveButtonIndex) [self doClear];
        else if (i != as.cancelButtonIndex) {
            NSDictionary *other = [ORContacts randomOther:[contact objectForKey:@"id"]];
            if (other) {
                [ORContacts setCurrentId:[other objectForKey:@"id"]];
                ORChatViewController *chat = [[ORChatViewController alloc] initWithContact:other];
                NSMutableArray *stack = [NSMutableArray arrayWithArray:self.navigationController.viewControllers];
                [stack removeLastObject]; [stack addObject:chat];
                [self.navigationController setViewControllers:stack animated:YES];
                [chat release];
            }
        }
        return;
    }
    if (as.tag == SHEET_PHOTO) {
        if (i == as.cancelButtonIndex) return;
        NSString *title = [as buttonTitleAtIndex:i];
        if ([title isEqualToString:@"Last Photo"]) { [self attachLastPhoto]; return; }
        UIImagePickerController *picker = [[UIImagePickerController alloc] init];
        picker.delegate = self;
        picker.sourceType = [title isEqualToString:@"Take Photo"] ? UIImagePickerControllerSourceTypeCamera : UIImagePickerControllerSourceTypePhotoLibrary;
        [self presentModalViewController:picker animated:YES];
        [picker release];
    }
}
- (void)attachImage:(UIImage *)img {
    if (!img) return;
    [attachedBase64 release]; attachedBase64 = [[ORImage jpegBase64ForImage:img maxSide:512 quality:0.6] retain];
    [attachedImage release]; attachedImage = [[ORImage imageFromBase64:attachedBase64] retain];
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(30, 30), NO, 0);
    [[UIBezierPath bezierPathWithRoundedRect:CGRectMake(1, 1, 28, 28) cornerRadius:4] addClip];
    CGFloat f = MAX(28 / attachedImage.size.width, 28 / attachedImage.size.height);
    CGSize ds = CGSizeMake(attachedImage.size.width * f, attachedImage.size.height * f);
    [attachedImage drawInRect:CGRectMake(15 - ds.width/2, 15 - ds.height/2, ds.width, ds.height)];
    UIImage *thumb = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    [cameraButton setImage:thumb forState:UIControlStateNormal];
    [input becomeFirstResponder];
}
- (void)attachLastPhoto {
    ALAssetsLibrary *lib = [[ALAssetsLibrary alloc] init];
    [lib enumerateGroupsWithTypes:ALAssetsGroupSavedPhotos usingBlock:^(ALAssetsGroup *group, BOOL *stop) {
        if (!group) return;
        [group setAssetsFilter:[ALAssetsFilter allPhotos]];
        NSInteger n = [group numberOfAssets];
        if (n == 0) return;
        [group enumerateAssetsAtIndexes:[NSIndexSet indexSetWithIndex:n-1] options:0 usingBlock:^(ALAsset *asset, NSUInteger idx, BOOL *stop2) {
            if (!asset) return;
            ALAssetRepresentation *rep = [asset defaultRepresentation];
            UIImage *img = [UIImage imageWithCGImage:[rep fullScreenImage]];
            [self performSelectorOnMainThread:@selector(attachImage:) withObject:img waitUntilDone:NO];
            *stop2 = YES;
        }];
        *stop = YES;
    } failureBlock:^(NSError *err) {
        [self performSelectorOnMainThread:@selector(showError:) withObject:@"Could not read the camera roll." waitUntilDone:NO];
    }];
    [lib autorelease];
}
- (void)showError:(NSString *)msg {
    [messages addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"error", @"role", msg, @"content", [self now], @"ts", nil]];
    [self persist]; [self reload]; [self scrollToBottom:YES];
}
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    UIImage *img = [info objectForKey:UIImagePickerControllerOriginalImage];
    [self dismissModalViewControllerAnimated:YES];
    [self attachImage:img];
}
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker { [self dismissModalViewControllerAnimated:YES]; }

#pragma mark long press menu (Copy / Email)
- (void)longPress:(UILongPressGestureRecognizer *)g {
    if (g.state != UIGestureRecognizerStateBegan) return;
    CGPoint p = [g locationInView:table];
    NSIndexPath *ip = [table indexPathForRowAtPoint:p];
    if (!ip) return;
    NSDictionary *m = [[self visible] objectAtIndex:ip.row];
    if ([[m objectForKey:@"role"] isEqualToString:@"typing"]) return;
    [menuRow release]; menuRow = [ip retain];
    [self becomeFirstResponder];
    UIMenuController *mc = [UIMenuController sharedMenuController];
    UIMenuItem *email = [[[UIMenuItem alloc] initWithTitle:@"Email" action:@selector(emailMessage:)] autorelease];
    mc.menuItems = [NSArray arrayWithObject:email];
    CGRect r = [table rectForRowAtIndexPath:ip];
    [mc setTargetRect:CGRectMake(r.origin.x + r.size.width/2 - 1, r.origin.y + 10, 2, 2) inView:table];
    [mc setMenuVisible:YES animated:YES];
}
- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(copy:) || action == @selector(emailMessage:)) return menuRow != nil;
    return NO;
}
- (NSString *)menuText { NSDictionary *m = [[self visible] objectAtIndex:menuRow.row]; return [m objectForKey:@"content"] ?: @""; }
- (void)copy:(id)sender { [UIPasteboard generalPasteboard].string = [self menuText]; }
- (void)emailMessage:(id)sender {
    if (![MFMailComposeViewController canSendMail]) { [self showError:@"No mail account is set up on this iPod."]; return; }
    MFMailComposeViewController *mc = [[MFMailComposeViewController alloc] init];
    mc.mailComposeDelegate = self;
    [mc setSubject:[NSString stringWithFormat:@"From %@", [contact objectForKey:@"name"]]];
    [mc setMessageBody:[self menuText] isHTML:NO];
    [self presentModalViewController:mc animated:YES]; [mc release];
}
- (void)mailComposeController:(MFMailComposeViewController *)c didFinishWithResult:(MFMailComposeResult)r error:(NSError *)e { [self dismissModalViewControllerAnimated:YES]; }

#pragma mark sending
- (BOOL)textFieldShouldReturn:(UITextField *)tf { [self send]; return NO; }
- (void)send {
    NSString *text = [input.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ((![text length] && !attachedBase64) || client.running) return;
    if (![[ORSettings apiKey] length]) return;
    if (attachedBase64) {
        NSArray *vision = [ORSettings visionModels];
        NSString *model = [[contact objectForKey:@"model"] length] ? [contact objectForKey:@"model"] : [ORSettings model];
        if (vision && ![vision containsObject:model]) {
            NSString *pick = [vision containsObject:@"openrelay/gemma-4-31b"] ? @"openrelay/gemma-4-31b" : ([vision count] ? [vision objectAtIndex:0] : nil);
            if (pick) {
                UIAlertView *a = [[UIAlertView alloc] initWithTitle:@"Model can't see photos" message:[NSString stringWithFormat:@"%@ is text-only. Use %@ for this message?", model, pick] delegate:self cancelButtonTitle:@"Send Anyway" otherButtonTitles:@"Switch", nil];
                a.tag = ALERT_MODEL; [a show]; [a release];
                return;
            }
        }
    }
    [self reallySend:nil];
}
- (void)alertView:(UIAlertView *)a clickedButtonAtIndex:(NSInteger)i {
    if (a.tag != ALERT_MODEL) return;
    NSString *override = nil;
    if (i != a.cancelButtonIndex) { NSArray *vision = [ORSettings visionModels]; override = [vision containsObject:@"openrelay/gemma-4-31b"] ? @"openrelay/gemma-4-31b" : [vision objectAtIndex:0]; }
    [self reallySend:override];
}
- (void)reallySend:(NSString *)modelForThisMessage {
    NSString *text = [input.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    input.text = @"";
    NSMutableDictionary *m = [NSMutableDictionary dictionaryWithObjectsAndKeys:@"user", @"role", text, @"content", [self now], @"ts", nil];
    if (attachedBase64) {
        [m setObject:attachedBase64 forKey:@"image"];
        [imageCache setObject:attachedImage forKey:[m objectForKey:@"ts"]];
        [attachedImage release]; attachedImage = nil; [attachedBase64 release]; attachedBase64 = nil;
        [cameraButton setImage:[ORImage cameraGlyph] forState:UIControlStateNormal];
    }
    [messages addObject:m];
    [self playSound:sndSent];
    [self persist]; [self reload]; [self scrollToBottom:YES];
    client.modelOverride = modelForThisMessage ?: [contact objectForKey:@"model"];
    [self dispatch];
}
- (void)sendHiddenPrompt:(NSString *)prompt {
    if (client.running) return;
    [messages addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"user", @"role", prompt, @"content", [self now], @"ts", [NSNumber numberWithBool:YES], @"hidden", nil]];
    [self persist]; [self dispatch];
}
- (void)dispatch {
    NSMutableArray *turns = [NSMutableArray array];
    for (NSDictionary *m in messages) {
        NSString *role = [m objectForKey:@"role"];
        if ([role isEqualToString:@"error"] || [role isEqualToString:@"typing"]) continue;
        if (![[m objectForKey:@"content"] length] && ![[m objectForKey:@"image"] length]) continue;
        [turns addObject:[NSDictionary dictionaryWithObjectsAndKeys:role, @"role", [m objectForKey:@"content"] ?: @"", @"content", [m objectForKey:@"image"], @"image", nil]];
    }
    [client sendMessages:turns];
}

#pragma mark client callbacks
- (void)setBusy:(BOOL)busy {
    sendButton.enabled = !busy;
    if (busy) { [spinner startAnimating]; self.navigationItem.titleView = spinner; }
    else { [spinner stopAnimating]; self.navigationItem.titleView = nil; }
    [UIApplication sharedApplication].networkActivityIndicatorVisible = busy;
}
- (void)clientDidStart:(id)c {
    replyStartCount = [messages count];
    [pending release]; pending = [[NSMutableString alloc] init];
    [burstQueue removeAllObjects]; streamDone = NO;
    if (![ORSettings pacing]) [messages addObject:[self assistantMessage:@"" ts:[self now]]];
    [self setBusy:YES];
    [self setTyping:YES];
    [self reload]; [self scrollToBottom:YES];
}
- (void)clientDidConnect:(id)c {
    // mark the latest user message Delivered
    for (NSInteger i = [messages count] - 1; i >= 0; i--) {
        NSDictionary *m = [messages objectAtIndex:i];
        if ([[m objectForKey:@"role"] isEqualToString:@"user"]) {
            if (![[m objectForKey:@"hidden"] boolValue]) { NSMutableDictionary *mm = [NSMutableDictionary dictionaryWithDictionary:m]; [mm setObject:[NSNumber numberWithBool:YES] forKey:@"delivered"]; [messages replaceObjectAtIndex:i withObject:mm]; }
            break;
        }
    }
    [self reload];
}
- (void)clientWillRetry:(id)c attempt:(NSInteger)attempt {
    while ([messages count] > replyStartCount) [messages removeLastObject];
    [pending release]; pending = [[NSMutableString alloc] init];
    [burstQueue removeAllObjects];
    if (![ORSettings pacing]) [messages addObject:[self assistantMessage:@"" ts:[self now]]];
    [self reload]; [self scrollToBottom:NO];
}
// paced mode: finished bursts wait in a queue and are released one at a time
- (void)scheduleNextBurst {
    if (burstTimer || ![burstQueue count]) return;
    NSString *next = [burstQueue objectAtIndex:0];
    NSTimeInterval delay = MIN(2.4, 0.5 + 0.028 * [next length]);
    burstTimer = [[NSTimer scheduledTimerWithTimeInterval:delay target:self selector:@selector(releaseBurst) userInfo:nil repeats:NO] retain];
}
- (void)releaseBurst {
    [burstTimer release]; burstTimer = nil;
    if (![burstQueue count]) return;
    NSString *b = [[[burstQueue objectAtIndex:0] retain] autorelease];
    [burstQueue removeObjectAtIndex:0];
    [messages addObject:[self assistantMessage:b ts:[self now]]];
    [self playSound:sndReceived];
    [self persist]; [self reload]; [self scrollToBottom:YES];
    if ([burstQueue count]) { [self scheduleNextBurst]; }
    else if (streamDone) { [self setTyping:NO]; [self setBusy:NO]; }
}
- (void)client:(id)c didReceiveToken:(NSString *)token {
    [pending appendString:token];
    if ([ORSettings pacing]) {
        NSRange br = [pending rangeOfString:@"\n\n"];
        while (br.location != NSNotFound) {
            NSString *done = [[pending substringToIndex:br.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSString *rest = [pending substringFromIndex:br.location + br.length];
            while ([rest hasPrefix:@"\n"]) rest = [rest substringFromIndex:1];
            if ([done length]) [burstQueue addObject:done];
            [pending setString:rest];
            br = [pending rangeOfString:@"\n\n"];
        }
        [self scheduleNextBurst];
        return;
    }
    // live mode: the last bubble grows as tokens arrive; a blank line starts a new bubble
    [self setTyping:NO];
    NSUInteger last = [messages count] - 1;
    NSNumber *ts = [[messages objectAtIndex:last] objectForKey:@"ts"];
    NSRange br = [pending rangeOfString:@"\n\n"];
    while (br.location != NSNotFound) {
        NSString *done = [[pending substringToIndex:br.location] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        NSString *rest = [pending substringFromIndex:br.location + br.length];
        while ([rest hasPrefix:@"\n"]) rest = [rest substringFromIndex:1];
        if ([done length]) {
            [messages replaceObjectAtIndex:last withObject:[self assistantMessage:done ts:ts]];
            [self playSound:sndReceived];
            ts = [self now];
            [messages addObject:[self assistantMessage:@"" ts:ts]];
            last = [messages count] - 1;
        }
        [pending setString:rest];
        br = [pending rangeOfString:@"\n\n"];
    }
    [messages replaceObjectAtIndex:last withObject:[self assistantMessage:[pending stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]] ts:ts]];
    [self reload]; [self scrollToBottom:NO];
}
- (void)clientDidFinish:(id)c {
    [[ORUnprompted shared] performSelector:@selector(topUp) withObject:nil afterDelay:3.0];   // use idle time to stock the day's texts
    NSString *tail = [pending stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([ORSettings pacing]) {
        if ([tail length]) [burstQueue addObject:tail];
        [pending release]; pending = nil;
        streamDone = YES;
        if ([burstQueue count]) [self scheduleNextBurst];
        else { [self setTyping:NO]; [self setBusy:NO]; [self persist]; }
        return;
    }
    if (![tail length]) [messages removeLastObject];
    else { NSUInteger last = [messages count] - 1; [messages replaceObjectAtIndex:last withObject:[self assistantMessage:tail ts:[[messages objectAtIndex:last] objectForKey:@"ts"]]]; [self playSound:sndReceived]; }
    [pending release]; pending = nil;
    [self setTyping:NO]; [self persist]; [self setBusy:NO]; [self reload]; [self scrollToBottom:YES];
}
- (void)client:(id)c didFailWithMessage:(NSString *)msg {
    if (![ORSettings pacing] && pending && ![pending length] && [messages count] && [[[messages lastObject] objectForKey:@"role"] isEqualToString:@"assistant"] && ![[[messages lastObject] objectForKey:@"content"] length]) [messages removeLastObject];
    [pending release]; pending = nil; [burstQueue removeAllObjects]; [burstTimer invalidate]; [burstTimer release]; burstTimer = nil;
    [self setTyping:NO];
    [messages addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"error", @"role", msg, @"content", [self now], @"ts", nil]];
    [self persist]; [self setBusy:NO]; [self reload]; [self scrollToBottom:YES];
}

#pragma mark table
- (void)scrollToBottom:(BOOL)animated {
    NSInteger n = [[self visible] count];
    if (n) [table scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:n-1 inSection:0] atScrollPosition:UITableViewScrollPositionBottom animated:animated];
}
- (NSString *)timestampForRow:(NSInteger)row inVisible:(NSArray *)v {
    NSDictionary *m = [v objectAtIndex:row];
    NSNumber *ts = [m objectForKey:@"ts"];
    if (!ts) return nil;
    if (row > 0) { NSNumber *prev = [[v objectAtIndex:row-1] objectForKey:@"ts"]; if (prev && [ts doubleValue] - [prev doubleValue] < 15*60) return nil; }
    static NSDateFormatter *df = nil;
    if (!df) { df = [[NSDateFormatter alloc] init]; [df setDateFormat:@"MMM d, yyyy h:mm a"]; }
    return [df stringFromDate:[NSDate dateWithTimeIntervalSince1970:[ts doubleValue]]];
}
- (UIImage *)imageFor:(NSDictionary *)m {
    NSString *b64 = [m objectForKey:@"image"];
    if (![b64 length]) return nil;
    id key = [m objectForKey:@"ts"] ?: b64;
    UIImage *img = [imageCache objectForKey:key];
    if (!img) { img = [ORImage imageFromBase64:b64]; if (img) [imageCache setObject:img forKey:key]; }
    return img;
}
- (NSInteger)tableView:(UITableView *)tv numberOfRowsInSection:(NSInteger)s { return [[self visible] count]; }
- (CGFloat)tableView:(UITableView *)tv heightForRowAtIndexPath:(NSIndexPath *)ip {
    NSArray *v = [self visible]; NSDictionary *m = [v objectAtIndex:ip.row];
    if ([[m objectForKey:@"role"] isEqualToString:@"typing"]) return [ORBubbleView typingHeight];
    NSString *t = [m objectForKey:@"content"]; UIImage *img = [self imageFor:m];
    if (![t length] && !img) t = @"...";
    return [ORBubbleView heightForText:t image:img timestamp:([self timestampForRow:ip.row inVisible:v] != nil) delivered:[[m objectForKey:@"delivered"] boolValue]];
}
- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)ip {
    static NSString *rid = @"bubble";
    ORBubbleCell *c = (ORBubbleCell *)[tv dequeueReusableCellWithIdentifier:rid];
    if (!c) c = [[[ORBubbleCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:rid] autorelease];
    NSArray *v = [self visible]; NSDictionary *m = [v objectAtIndex:ip.row];
    NSString *t = [m objectForKey:@"content"];
    c.bubble.role = [m objectForKey:@"role"];
    c.bubble.timestamp = [self timestampForRow:ip.row inVisible:v];
    c.bubble.image = [self imageFor:m];
    c.bubble.delivered = [[m objectForKey:@"delivered"] boolValue];
    c.bubble.typingPhase = typingPhase;
    c.bubble.text = ([t length] || c.bubble.image || [c.bubble.role isEqualToString:@"typing"]) ? t : @"...";
    return c;
}
- (void)scrollViewWillBeginDragging:(UIScrollView *)sv { [input resignFirstResponder]; }
@end

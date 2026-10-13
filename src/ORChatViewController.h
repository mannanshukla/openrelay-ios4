#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>
#import "ORClient.h"
@interface ORChatViewController : UIViewController <UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate, UIActionSheetDelegate, UIAlertViewDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate, MFMailComposeViewControllerDelegate, ORClientDelegate> {
    NSDictionary *contact; NSString *historyKey;
    UITableView *table; UIView *inputBar; UITextField *input; UIButton *sendButton; UIButton *cameraButton;
    UIImage *attachedImage; NSString *attachedBase64;
    NSMutableDictionary *imageCache;   // ts -> UIImage
    UIActivityIndicatorView *spinner;
    NSMutableArray *messages;    // dicts: role, content, ts, image?, hidden?, delivered?
    NSMutableString *pending;    // streaming assistant text not yet committed to a bubble
    NSMutableArray *burstQueue;  // paced mode: finished bursts waiting to be shown
    NSTimer *burstTimer; NSTimer *typingTimer; NSInteger typingPhase; BOOL typing; BOOL streamDone;
    ORClient *client;
    CGFloat keyboardHeight;
    NSUInteger replyStartCount;
    NSIndexPath *menuRow;
}
- (id)initWithContact:(NSDictionary *)contact;
- (void)sendHiddenPrompt:(NSString *)prompt;   // e.g. the daily text trigger
@end

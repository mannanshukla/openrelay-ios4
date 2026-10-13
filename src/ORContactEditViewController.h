#import <UIKit/UIKit.h>
@interface ORContactEditViewController : UITableViewController <UITextFieldDelegate, UITextViewDelegate> {
    NSMutableDictionary *contact; BOOL isNew;
    UITextField *nameField, *modelField; UITextView *promptView;
}
- (id)initWithContact:(NSDictionary *)c;   // nil = new
@end

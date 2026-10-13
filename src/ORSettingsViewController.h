#import <UIKit/UIKit.h>
@interface ORSettingsViewController : UITableViewController <UITextFieldDelegate> {
    UITextField *keyField, *modelField, *baseField, *sysField;
    UISwitch *pacingSwitch, *soundSwitch; UISegmentedControl *unpromptedSeg;
    NSArray *models; BOOL loadingModels; NSString *modelError;
}
@end

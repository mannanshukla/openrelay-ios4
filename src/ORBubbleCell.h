#import <UIKit/UIKit.h>
// iOS 5 Messages.app-style bubble. role: "user" (iMessage blue, right) / "assistant" (grey, left) / "error" (red, left)
@interface ORBubbleView : UIView { NSString *text; NSString *role; NSString *timestamp; UIImage *image; BOOL delivered; NSInteger typingPhase; }
@property (nonatomic, retain) UIImage *image;         // optional attached photo, drawn above the text
@property (nonatomic, assign) BOOL delivered;         // draws a small grey "Delivered" under a sent bubble
@property (nonatomic, assign) NSInteger typingPhase;  // role "typing": which of the three dots is bright
@property (nonatomic, copy) NSString *text;
@property (nonatomic, copy) NSString *role;
@property (nonatomic, copy) NSString *timestamp;   // nil = no timestamp row above the bubble
+ (CGFloat)heightForText:(NSString *)text image:(UIImage *)img timestamp:(BOOL)hasTimestamp delivered:(BOOL)delivered;
+ (CGFloat)typingHeight;
+ (CGSize)imageDrawSize:(UIImage *)img;
@end

@interface ORBubbleCell : UITableViewCell { ORBubbleView *bubble; }
@property (nonatomic, readonly) ORBubbleView *bubble;
@end

// iOS 5 style blue/grey gradient button images
@interface ORStyle : NSObject
+ (UIImage *)sendButtonImage:(BOOL)enabled;
+ (UIFont *)messageFont;
@end

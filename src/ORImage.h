#import <UIKit/UIKit.h>
@interface ORImage : NSObject
+ (NSString *)base64:(NSData *)data;                     // iOS 4 has no built-in encoder
+ (NSString *)jpegBase64ForImage:(UIImage *)img maxSide:(CGFloat)maxSide quality:(CGFloat)q;
+ (UIImage *)imageFromBase64:(NSString *)b64;
+ (UIImage *)cameraGlyph;                               // iOS 5 style grey camera button
@end

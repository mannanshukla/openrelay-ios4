#import "ORImage.h"

static const char b64tab[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

@implementation ORImage
+ (NSString *)base64:(NSData *)data {
    const unsigned char *in = [data bytes]; NSUInteger n = [data length];
    NSMutableData *out = [NSMutableData dataWithLength:((n + 2) / 3) * 4];
    char *o = [out mutableBytes]; NSUInteger i, j = 0;
    for (i = 0; i + 2 < n; i += 3) {
        o[j++] = b64tab[in[i] >> 2];
        o[j++] = b64tab[((in[i] & 3) << 4) | (in[i+1] >> 4)];
        o[j++] = b64tab[((in[i+1] & 15) << 2) | (in[i+2] >> 6)];
        o[j++] = b64tab[in[i+2] & 63];
    }
    if (i < n) {
        o[j++] = b64tab[in[i] >> 2];
        if (i + 1 < n) { o[j++] = b64tab[((in[i] & 3) << 4) | (in[i+1] >> 4)]; o[j++] = b64tab[(in[i+1] & 15) << 2]; }
        else { o[j++] = b64tab[(in[i] & 3) << 4]; o[j++] = '='; }
        o[j++] = '=';
    }
    return [[[NSString alloc] initWithBytes:o length:j encoding:NSASCIIStringEncoding] autorelease];
}
+ (NSData *)dataFromBase64:(NSString *)s {   // works on a plain copy of the characters: a photo is ~40k of them
    NSUInteger n = [s length]; unichar *in = malloc(MAX(n, 1) * sizeof(unichar)); [s getCharacters:in range:NSMakeRange(0, n)];
    NSMutableData *out = [NSMutableData dataWithLength:n * 3 / 4 + 3]; unsigned char *o = [out mutableBytes]; NSUInteger j = 0;
    int val = 0, bits = 0;
    for (NSUInteger i = 0; i < n; i++) {
        unichar c = in[i]; int v;
        if (c >= 'A' && c <= 'Z') v = c - 'A'; else if (c >= 'a' && c <= 'z') v = c - 'a' + 26;
        else if (c >= '0' && c <= '9') v = c - '0' + 52; else if (c == '+') v = 62; else if (c == '/') v = 63; else continue;
        val = ((val << 6) | v) & 0xFFFFFF; bits += 6;
        if (bits >= 8) { bits -= 8; o[j++] = (val >> bits) & 0xFF; }
    }
    free(in); [out setLength:j];
    return out;
}
+ (UIImage *)scale:(UIImage *)img maxSide:(CGFloat)maxSide {
    CGSize s = img.size;
    CGFloat f = MIN(1.0f, maxSide / MAX(s.width, s.height));
    CGSize ns = CGSizeMake(floorf(s.width * f), floorf(s.height * f));
    UIGraphicsBeginImageContextWithOptions(ns, YES, 1.0);
    [img drawInRect:CGRectMake(0, 0, ns.width, ns.height)];   // bakes in EXIF orientation
    UIImage *r = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return r;
}
+ (NSString *)jpegBase64ForImage:(UIImage *)img maxSide:(CGFloat)maxSide quality:(CGFloat)q {
    return [self base64:UIImageJPEGRepresentation([self scale:img maxSide:maxSide], q)];
}
+ (UIImage *)imageFromBase64:(NSString *)b64 {
    if (![b64 length]) return nil;
    return [UIImage imageWithData:[self dataFromBase64:b64]];
}
+ (UIImage *)cameraGlyph {
    CGSize sz = CGSizeMake(30, 30);
    UIGraphicsBeginImageContextWithOptions(sz, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    UIBezierPath *body = [UIBezierPath bezierPathWithRoundedRect:CGRectMake(4, 10, 22, 14) cornerRadius:3];
    [body appendPath:[UIBezierPath bezierPathWithRoundedRect:CGRectMake(11, 6.5, 8, 5) cornerRadius:1.5]];
    CGContextSaveGState(ctx);
    CGContextSetShadowWithColor(ctx, CGSizeMake(0, 1), 0, [UIColor colorWithWhite:1 alpha:0.8].CGColor);
    [[UIColor colorWithWhite:0.36 alpha:1] setFill]; [body fill];
    CGContextRestoreGState(ctx);
    [[UIColor colorWithWhite:0.86 alpha:1] setFill];
    [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(11, 13, 8, 8)] fill];
    [[UIColor colorWithWhite:0.36 alpha:1] setFill];
    [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(13, 15, 4, 4)] fill];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}
@end

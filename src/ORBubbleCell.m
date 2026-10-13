#import "ORBubbleCell.h"

#define PAD_X 11.0f
#define PAD_Y 7.0f
#define MAX_W 228.0f
#define TAIL 8.0f
#define MARGIN_Y 4.0f
#define SIDE 7.0f
#define TS_H 22.0f

static void fillGradient(CGContextRef ctx, CGRect r, const CGFloat *c, size_t n) {
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGGradientRef g = CGGradientCreateWithColorComponents(cs, c, NULL, n);
    CGContextDrawLinearGradient(ctx, g, CGPointMake(0, CGRectGetMinY(r)), CGPointMake(0, CGRectGetMaxY(r)), 0);
    CGGradientRelease(g); CGColorSpaceRelease(cs);
}

@implementation ORStyle
+ (UIFont *)messageFont { return [UIFont fontWithName:@"Helvetica" size:15] ?: [UIFont systemFontOfSize:15]; }
+ (UIImage *)sendButtonImage:(BOOL)enabled {
    CGSize sz = CGSizeMake(64, 27);
    UIGraphicsBeginImageContextWithOptions(sz, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    CGRect r = CGRectMake(0.5, 0.5, sz.width-1, sz.height-1);
    UIBezierPath *p = [UIBezierPath bezierPathWithRoundedRect:r cornerRadius:6];
    CGContextSaveGState(ctx); [p addClip];
    if (enabled) { CGFloat c[8] = {0.62,0.84,0.20,1, 0.36,0.58,0.08,1}; fillGradient(ctx, r, c, 2); }  // OpenRelay green
    else         { CGFloat c[8] = {0.80,0.80,0.80,1, 0.64,0.64,0.64,1}; fillGradient(ctx, r, c, 2); }
    // top gloss
    CGFloat gl[8] = {1,1,1,0.45, 1,1,1,0.08};
    fillGradient(ctx, CGRectMake(0, 0, sz.width, sz.height/2), gl, 2);
    CGContextRestoreGState(ctx);
    [(enabled ? [UIColor colorWithRed:0.24 green:0.40 blue:0.05 alpha:1] : [UIColor colorWithWhite:0.5 alpha:1]) setStroke];
    p.lineWidth = 1; [p stroke];
    UIImage *img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [img stretchableImageWithLeftCapWidth:8 topCapHeight:12];
}
@end

@implementation ORBubbleView
@synthesize text, role, timestamp, image, delivered, typingPhase;
- (void)setDelivered:(BOOL)d { delivered = d; [self setNeedsDisplay]; }
- (void)setTypingPhase:(NSInteger)ph { typingPhase = ph; [self setNeedsDisplay]; }

- (id)initWithFrame:(CGRect)f { if ((self = [super initWithFrame:f])) { self.backgroundColor = [UIColor clearColor]; self.opaque = NO; self.contentMode = UIViewContentModeRedraw; } return self; }
- (void)dealloc { [text release]; [role release]; [timestamp release]; [image release]; [super dealloc]; }
- (void)setImage:(UIImage *)i { [i retain]; [image release]; image = i; [self setNeedsDisplay]; }
- (void)setText:(NSString *)t { [text release]; text = [t copy]; [self setNeedsDisplay]; }
- (void)setRole:(NSString *)r { [role release]; role = [r copy]; [self setNeedsDisplay]; }
- (void)setTimestamp:(NSString *)s { [timestamp release]; timestamp = [s copy]; [self setNeedsDisplay]; }

+ (CGSize)textSize:(NSString *)t {
    NSString *s = [t length] ? t : @" ";
    return [s sizeWithFont:[ORStyle messageFont] constrainedToSize:CGSizeMake(MAX_W - 2*PAD_X, 10000) lineBreakMode:UILineBreakModeWordWrap];
}
+ (CGSize)imageDrawSize:(UIImage *)img {
    if (!img) return CGSizeZero;
    CGFloat maxW = MAX_W - 2*PAD_X, maxH = 180;
    CGFloat f = MIN(maxW / img.size.width, maxH / img.size.height); if (f > 1) f = 1;
    return CGSizeMake(floorf(img.size.width * f), floorf(img.size.height * f));
}
+ (CGFloat)heightForText:(NSString *)t image:(UIImage *)img timestamp:(BOOL)ts delivered:(BOOL)dl {
    CGSize is = [self imageDrawSize:img];
    CGFloat textH = [t length] ? [self textSize:t].height : 0;
    CGFloat inner = is.height + ((is.height > 0 && textH > 0) ? 6 : 0) + textH;
    return inner + 2*PAD_Y + 2*MARGIN_Y + (ts ? TS_H : 0) + (dl ? 16 : 0);
}
+ (CGFloat)typingHeight { return 20 + 2*PAD_Y + 2*MARGIN_Y; }

// iOS 5 balloon: rounded body with a curved tail at the bottom corner
- (UIBezierPath *)balloonPath:(CGRect)b mine:(BOOL)mine {
    CGFloat r = 11.0f;
    CGFloat x0 = b.origin.x, y0 = b.origin.y, x1 = CGRectGetMaxX(b), y1 = CGRectGetMaxY(b);
    UIBezierPath *p = [UIBezierPath bezierPath];
    if (mine) {
        [p moveToPoint:CGPointMake(x0 + r, y0)];
        [p addLineToPoint:CGPointMake(x1 - r, y0)];
        [p addQuadCurveToPoint:CGPointMake(x1, y0 + r) controlPoint:CGPointMake(x1, y0)];
        [p addLineToPoint:CGPointMake(x1, y1 - 12)];
        // tail curling out to the right
        [p addCurveToPoint:CGPointMake(x1 + TAIL, y1) controlPoint1:CGPointMake(x1, y1 - 4) controlPoint2:CGPointMake(x1 + 2, y1 - 1)];
        [p addCurveToPoint:CGPointMake(x1 - r, y1) controlPoint1:CGPointMake(x1 - 1, y1) controlPoint2:CGPointMake(x1 - 4, y1)];
        [p addLineToPoint:CGPointMake(x0 + r, y1)];
        [p addQuadCurveToPoint:CGPointMake(x0, y1 - r) controlPoint:CGPointMake(x0, y1)];
        [p addLineToPoint:CGPointMake(x0, y0 + r)];
        [p addQuadCurveToPoint:CGPointMake(x0 + r, y0) controlPoint:CGPointMake(x0, y0)];
    } else {
        [p moveToPoint:CGPointMake(x0 + r, y0)];
        [p addLineToPoint:CGPointMake(x1 - r, y0)];
        [p addQuadCurveToPoint:CGPointMake(x1, y0 + r) controlPoint:CGPointMake(x1, y0)];
        [p addLineToPoint:CGPointMake(x1, y1 - r)];
        [p addQuadCurveToPoint:CGPointMake(x1 - r, y1) controlPoint:CGPointMake(x1, y1)];
        [p addLineToPoint:CGPointMake(x0 + r, y1)];
        [p addCurveToPoint:CGPointMake(x0 - TAIL, y1) controlPoint1:CGPointMake(x0 + 4, y1) controlPoint2:CGPointMake(x0 + 1, y1)];
        [p addCurveToPoint:CGPointMake(x0, y1 - 12) controlPoint1:CGPointMake(x0 - 2, y1 - 1) controlPoint2:CGPointMake(x0, y1 - 4)];
        [p addLineToPoint:CGPointMake(x0, y0 + r)];
        [p addQuadCurveToPoint:CGPointMake(x0 + r, y0) controlPoint:CGPointMake(x0, y0)];
    }
    [p closePath];
    return p;
}

- (void)drawRect:(CGRect)rect {
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    BOOL mine = [role isEqualToString:@"user"];
    BOOL err  = [role isEqualToString:@"error"];
    CGFloat top = MARGIN_Y;

    if ([timestamp length]) {
        // iOS 5 timestamp: bold grey, white 1px drop shadow, centered
        UIFont *tf = [UIFont fontWithName:@"Helvetica-Bold" size:11.5] ?: [UIFont boldSystemFontOfSize:11.5];
        CGRect tr = CGRectMake(0, 3, self.bounds.size.width, TS_H - 4);
        [[UIColor whiteColor] set];
        [timestamp drawInRect:CGRectOffset(tr, 0, 1) withFont:tf lineBreakMode:UILineBreakModeTailTruncation alignment:UITextAlignmentCenter];
        [[UIColor colorWithWhite:0.44 alpha:1] set];
        [timestamp drawInRect:tr withFont:tf lineBreakMode:UILineBreakModeTailTruncation alignment:UITextAlignmentCenter];
        top += TS_H;
    }

    BOOL typing = [role isEqualToString:@"typing"];
    CGSize ts = typing ? CGSizeMake(34, 20) : ([text length] ? [ORBubbleView textSize:text] : CGSizeZero);
    CGSize is = [ORBubbleView imageDrawSize:image];
    CGFloat gap = (is.height > 0 && ts.height > 0) ? 6 : 0;
    CGFloat bw = MAX(ts.width, is.width) + 2*PAD_X, bh = is.height + gap + ts.height + 2*PAD_Y;
    CGRect b = mine ? CGRectMake(self.bounds.size.width - bw - TAIL - SIDE, top, bw, bh)
                    : CGRectMake(TAIL + SIDE, top, bw, bh);
    b = CGRectIntegral(b); b.origin.x += 0.5; b.origin.y += 0.5;
    UIBezierPath *p = [self balloonPath:b mine:mine];

    // body gradient
    CGContextSaveGState(ctx);
    [p addClip];
    if (err)       { CGFloat c[8] = {0.99,0.86,0.86,1, 0.93,0.62,0.62,1}; fillGradient(ctx, b, c, 2); }
    else if (mine) { CGFloat c[12] = {0.91,0.98,0.62,1, 0.79,0.93,0.25,1, 0.62,0.82,0.02,1}; fillGradient(ctx, b, c, 3); }  // OpenRelay lime, SMS-style
    else           { CGFloat c[12] = {0.99,0.99,0.99,1, 0.93,0.93,0.93,1, 0.84,0.84,0.84,1}; fillGradient(ctx, b, c, 3); }  // received grey
    // glossy top half
    CGFloat gl[8] = {1,1,1,(mine ? 0.50f : 0.60f), 1,1,1,0.05f};
    fillGradient(ctx, CGRectMake(b.origin.x, b.origin.y, b.size.width, b.size.height*0.5f), gl, 2);
    // inner highlight line
    CGContextRestoreGState(ctx);
    CGContextSaveGState(ctx);
    [p addClip];
    [[UIColor colorWithWhite:1 alpha:0.6] setStroke];
    p.lineWidth = 3.0f; [p stroke];
    CGContextRestoreGState(ctx);
    // outer 1px border
    if (err)       [[UIColor colorWithRed:0.65 green:0.25 blue:0.25 alpha:1] setStroke];
    else if (mine) [[UIColor colorWithRed:0.30 green:0.49 blue:0.06 alpha:1] setStroke]; // olive border
    else           [[UIColor colorWithWhite:0.58 alpha:1] setStroke];
    p.lineWidth = 1.0f; [p stroke];

    // attached photo, rounded corners
    if (image) {
        CGRect ir = CGRectMake(b.origin.x + PAD_X, b.origin.y + PAD_Y, is.width, is.height);
        CGContextSaveGState(ctx);
        [[UIBezierPath bezierPathWithRoundedRect:ir cornerRadius:5] addClip];
        [image drawInRect:ir];
        CGContextRestoreGState(ctx);
        [[UIColor colorWithWhite:0 alpha:0.25] setStroke];
        [[UIBezierPath bezierPathWithRoundedRect:CGRectInset(ir, 0.5, 0.5) cornerRadius:5] stroke];
    }
    if (typing) {
        // three dots, the bright one cycles
        for (int i = 0; i < 3; i++) {
            CGFloat a = (i == typingPhase % 3) ? 0.85f : 0.35f;
            [[UIColor colorWithWhite:0.25 alpha:a] setFill];
            [[UIBezierPath bezierPathWithOvalInRect:CGRectMake(b.origin.x + PAD_X + 2 + i*11, b.origin.y + PAD_Y + 6, 8, 8)] fill];
        }
    } else {
        // text: black Helvetica 15, like iOS 5
        [[UIColor blackColor] set];
        [text drawInRect:CGRectMake(b.origin.x + PAD_X, b.origin.y + PAD_Y + is.height + gap, ts.width, ts.height) withFont:[ORStyle messageFont] lineBreakMode:UILineBreakModeWordWrap];
    }
    if (delivered && mine) {
        UIFont *df = [UIFont fontWithName:@"Helvetica-Bold" size:10.5] ?: [UIFont boldSystemFontOfSize:10.5];
        [[UIColor colorWithWhite:0.45 alpha:1] set];
        [@"Delivered" drawInRect:CGRectMake(0, CGRectGetMaxY(b) + 2, self.bounds.size.width - SIDE - TAIL - 2, 14) withFont:df lineBreakMode:UILineBreakModeClip alignment:UITextAlignmentRight];
    }
}
@end

@implementation ORBubbleCell
@synthesize bubble;
- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)rid {
    if ((self = [super initWithStyle:style reuseIdentifier:rid])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.backgroundColor = [UIColor clearColor];
        bubble = [[ORBubbleView alloc] initWithFrame:self.contentView.bounds];
        bubble.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.contentView addSubview:bubble];
    }
    return self;
}
- (void)dealloc { [bubble release]; [super dealloc]; }
@end

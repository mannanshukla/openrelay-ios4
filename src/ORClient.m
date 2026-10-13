#import "ORClient.h"
#import "ORJSON.h"
#import "ORImage.h"
#import <UIKit/UIKit.h>

static NSString *kKey = @"or_api_key", *kModel = @"or_model", *kBase = @"or_base_url", *kSys = @"or_system_prompt";
#define DEFAULT_BASE @"https://inference.openrelay.inc"
#define DEFAULT_MODEL @"openrelay/gpt-oss-120b"

@implementation ORSettings
+ (NSUserDefaults *)d { return [NSUserDefaults standardUserDefaults]; }
+ (NSString *)apiKey { return [[self d] stringForKey:kKey] ?: @""; }
+ (void)setApiKey:(NSString *)k { [[self d] setObject:k forKey:kKey]; [[self d] synchronize]; }
+ (NSString *)model { NSString *m = [[self d] stringForKey:kModel]; return [m length] ? m : DEFAULT_MODEL; }
+ (void)setModel:(NSString *)m { [[self d] setObject:m forKey:kModel]; [[self d] synchronize]; }
+ (NSString *)baseURL { NSString *u = [[self d] stringForKey:kBase]; return [u length] ? u : DEFAULT_BASE; }
+ (void)setBaseURL:(NSString *)u { [[self d] setObject:u forKey:kBase]; [[self d] synchronize]; }
+ (NSString *)systemPrompt { return [[self d] stringForKey:kSys] ?: @""; }
+ (NSArray *)visionModels { return [[self d] arrayForKey:@"or_vision_models"]; }   // nil = unknown yet
+ (BOOL)pacing { id v = [[self d] objectForKey:@"or_pacing"]; return v ? [v boolValue] : YES; }
+ (void)setPacing:(BOOL)v { [[self d] setBool:v forKey:@"or_pacing"]; [[self d] synchronize]; }
+ (BOOL)sounds { id v = [[self d] objectForKey:@"or_sounds"]; return v ? [v boolValue] : YES; }
+ (void)setSounds:(BOOL)v { [[self d] setBool:v forKey:@"or_sounds"]; [[self d] synchronize]; }
+ (NSInteger)unpromptedPerDay { id v = [[self d] objectForKey:@"or_unprompted_per_day"]; return v ? [v integerValue] : 1; }
+ (void)setUnpromptedPerDay:(NSInteger)n { [[self d] setInteger:n forKey:@"or_unprompted_per_day"]; [[self d] synchronize]; }
+ (void)setSystemPrompt:(NSString *)p { [[self d] setObject:p forKey:kSys]; [[self d] synchronize]; }
@end

@implementation ORClient
@synthesize delegate, personaPrompt, modelOverride;

+ (NSString *)builtInSystemPrompt {
    static NSString *prompt = nil;
    if (!prompt) {
        NSString *device = [[UIDevice currentDevice] model] ?: @"iPod touch";
        NSString *ios = [[UIDevice currentDevice] systemVersion] ?: @"4.3";
        prompt = [[NSString stringWithFormat:
            @"You are chatting through OpenRelay, a small native messaging app on a 2010 %@ running iOS %@. "
            @"The user reads your replies as chat bubbles on a 3.5-inch, 320 by 480 point screen, like text messages.\n\n"
            @"Formatting rules, strictly:\n"
            @"- Plain text only. The app renders no markdown: no **bold**, no # headings, no tables, no code fences, no links in [text](url) form.\n"
            @"- For lists, start lines with a dash and keep each item to one line.\n"
            @"- For code, write it inline or on its own lines with no fences, and keep it short; the screen fits about 35 characters per line.\n"
            @"- Write like you are texting: short bursts of one or two sentences, each separated by a blank line. The app shows every burst as its own message bubble.\n"
            @"- Two to five bursts is normal. Expand only when the user clearly wants detail, and even then keep each burst short.\n"
            @"- Keep a dash list inside one burst, one item per line.\n"
            @"- No emoji at all; they render slowly on this device.\n\n"
            @"Context:\n"
            @"- Typing is slow on this keyboard, so expect terse messages and typos, and do not ask for clarification unless truly necessary.\n"
            @"- The user may attach photos taken with the device's low-resolution camera; describe what you can and say when an image is too small to read.\n"
            @"- There is no browser hand-off, no copy-to-clipboard shortcut, and no scrolling inside a bubble, so avoid long URLs and long outputs.\n"
            @"- Earlier photos in the conversation may appear only as \"[photo]\" markers.",
            device, ios] retain];
    }
    return prompt;
}

- (BOOL)running { return conn != nil; }

- (void)dealloc { [conn cancel]; [conn release]; [buffer release]; [errorBody release]; [lastMessages release]; [personaPrompt release]; [modelOverride release]; [super dealloc]; }

- (void)cancel {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(retryAfterDelay) object:nil];
    [conn cancel]; [conn release]; conn = nil;
}

- (void)sendMessages:(NSArray *)messages {
    [lastMessages release]; lastMessages = [messages copy];
    attempt = 0;
    [self sendAttempt];
}
// Shrink any attached photos further for a retry (a dead connection mid-upload is the usual failure on this device).
- (NSArray *)messagesWithSmallerImages:(NSArray *)messages maxSide:(CGFloat)side {
    NSMutableArray *out = [NSMutableArray arrayWithCapacity:[messages count]];
    for (NSDictionary *m in messages) {
        NSString *img = [m objectForKey:@"image"];
        if ([img length]) {
            UIImage *ui = [ORImage imageFromBase64:img];
            if (ui) {
                NSMutableDictionary *mm = [NSMutableDictionary dictionaryWithDictionary:m];
                [mm setObject:[ORImage jpegBase64ForImage:ui maxSide:side quality:0.55] forKey:@"image"];
                [out addObject:mm]; continue;
            }
        }
        [out addObject:m];
    }
    return out;
}
- (void)sendAttempt {
    NSArray *messages = lastMessages;
    if (attempt == 1) messages = [self messagesWithSmallerImages:lastMessages maxSide:384];
    else if (attempt >= 2) messages = [self messagesWithSmallerImages:lastMessages maxSide:256];
    [self cancel];
    finished = NO; status = 0; gotTokens = NO;
    [buffer release]; buffer = [[NSMutableData alloc] init];
    [errorBody release]; errorBody = nil;

    NSMutableArray *msgs = [NSMutableArray array];
    NSString *sys = [ORClient builtInSystemPrompt];
    NSString *persona = [personaPrompt stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([persona length]) sys = [NSString stringWithFormat:@"%@\n\nWho you are in this conversation:\n%@", sys, persona];
    NSString *extra = [[ORSettings systemPrompt] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([extra length]) sys = [NSString stringWithFormat:@"%@\n\nAdditional instructions from the user:\n%@", sys, extra];
    [msgs addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"system", @"role", sys, @"content", nil]];
    // Convert to wire format. Messages may carry "image" (base64 JPEG); only the 2 most recent images are sent in full.
    NSInteger imagesLeft = 2;
    NSMutableArray *wire = [NSMutableArray arrayWithCapacity:[messages count]];
    for (NSDictionary *m in [messages reverseObjectEnumerator]) {
        NSString *role = [m objectForKey:@"role"], *content = [m objectForKey:@"content"] ?: @"", *img = [m objectForKey:@"image"];
        if ([img length] && imagesLeft > 0) {
            imagesLeft--;
            NSMutableArray *parts = [NSMutableArray array];
            if ([content length]) [parts addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"text", @"type", content, @"text", nil]];
            [parts addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"image_url", @"type",
                              [NSDictionary dictionaryWithObject:[@"data:image/jpeg;base64," stringByAppendingString:img] forKey:@"url"], @"image_url", nil]];
            [wire insertObject:[NSDictionary dictionaryWithObjectsAndKeys:role, @"role", parts, @"content", nil] atIndex:0];
        } else {
            NSString *c = [img length] ? [content length] ? [NSString stringWithFormat:@"[photo] %@", content] : @"[photo]" : content;
            [wire insertObject:[NSDictionary dictionaryWithObjectsAndKeys:role, @"role", c, @"content", nil] atIndex:0];
        }
    }
    [msgs addObjectsFromArray:wire];
    NSDictionary *body = [NSDictionary dictionaryWithObjectsAndKeys:
                          ([modelOverride length] ? modelOverride : [ORSettings model]), @"model",
                          msgs, @"messages",
                          [NSNumber numberWithBool:YES], @"stream", nil];
    NSString *json = [ORJSON stringify:body];

    NSString *url = [NSString stringWithFormat:@"%@/v1/chat/completions", [ORSettings baseURL]];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url]
                                                       cachePolicy:NSURLRequestReloadIgnoringLocalCacheData
                                                   timeoutInterval:120];
    [req setHTTPMethod:@"POST"];
    [req setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [req setValue:@"text/event-stream" forHTTPHeaderField:@"Accept"];
    [req setValue:[NSString stringWithFormat:@"Bearer %@", [ORSettings apiKey]] forHTTPHeaderField:@"Authorization"];
    [req setValue:@"OpenRelay-iOS4/1.0" forHTTPHeaderField:@"User-Agent"];
    [req setValue:@"close" forHTTPHeaderField:@"Connection"];   // never reuse a connection that died mid-stream
    [req setHTTPShouldUsePipelining:NO];
    [req setHTTPBody:[json dataUsingEncoding:NSUTF8StringEncoding]];

    conn = [[NSURLConnection alloc] initWithRequest:req delegate:self startImmediately:YES];
    if (!conn) { [delegate client:self didFailWithMessage:@"Could not open connection."]; return; }
    if (attempt == 0) [delegate clientDidStart:self];
}

- (void)connection:(NSURLConnection *)c didReceiveResponse:(NSURLResponse *)response {
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) status = [(NSHTTPURLResponse *)response statusCode];
    if (status == 200 && [delegate respondsToSelector:@selector(clientDidConnect:)]) [delegate clientDidConnect:self];
}

- (void)processLine:(NSString *)line {
    if (![line hasPrefix:@"data:"]) return;
    NSString *payload = [[line substringFromIndex:5] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
    if ([payload isEqualToString:@"[DONE]"]) { finished = YES; return; }
    id obj = [ORJSON parse:payload];
    if (![obj isKindOfClass:[NSDictionary class]]) return;
    NSArray *choices = [obj objectForKey:@"choices"];
    if (![choices isKindOfClass:[NSArray class]] || ![choices count]) return;
    NSDictionary *delta = [[choices objectAtIndex:0] objectForKey:@"delta"];
    id content = [delta objectForKey:@"content"];
    if ([content isKindOfClass:[NSString class]] && [content length]) { gotTokens = YES; [delegate client:self didReceiveToken:content]; }
}

- (void)connection:(NSURLConnection *)c didReceiveData:(NSData *)data {
    if (status != 200) {
        if (!errorBody) errorBody = [[NSMutableData alloc] init];
        [errorBody appendData:data]; return;
    }
    [buffer appendData:data];
    // split on newlines, keep trailing partial line in buffer
    const char *bytes = [buffer bytes]; NSUInteger n = [buffer length], start = 0;
    for (NSUInteger i = 0; i < n; i++) {
        if (bytes[i] == '\n') {
            NSUInteger l = i - start; if (l && bytes[start+l-1] == '\r') l--;
            NSString *line = [[NSString alloc] initWithBytes:bytes+start length:l encoding:NSUTF8StringEncoding];
            if (line) [self processLine:line];
            [line release];
            start = i + 1;
        }
    }
    if (start > 0) [buffer replaceBytesInRange:NSMakeRange(0, start) withBytes:NULL length:0];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)c {
    [conn release]; conn = nil;
    if (status != 200) {
        NSString *msg = [NSString stringWithFormat:@"HTTP %d", (int)status];
        NSString *text = errorBody ? [[[NSString alloc] initWithData:errorBody encoding:NSUTF8StringEncoding] autorelease] : nil;
        id obj = [ORJSON parse:text];
        if ([obj isKindOfClass:[NSDictionary class]]) {
            id err = [obj objectForKey:@"error"];
            if ([err isKindOfClass:[NSDictionary class]] && [err objectForKey:@"message"]) msg = [NSString stringWithFormat:@"%@: %@", msg, [err objectForKey:@"message"]];
            else if ([err isKindOfClass:[NSString class]]) msg = [NSString stringWithFormat:@"%@: %@", msg, err];
        } else if ([text length]) msg = [NSString stringWithFormat:@"%@: %@", msg, [text length] > 200 ? [text substringToIndex:200] : text];
        [delegate client:self didFailWithMessage:msg];
        return;
    }
    [delegate clientDidFinish:self];
}

- (BOOL)isTransient:(NSError *)error {
    if (![[error domain] isEqualToString:NSURLErrorDomain]) return NO;
    NSInteger code = [error code];
    // TLS handshake family, connection lost/reset, timeout, cannot connect
    return (code <= -1200 && code >= -1206) || code == -1005 || code == -1001 || code == -1004;
}
- (void)retryAfterDelay { [self sendAttempt]; }
- (void)connection:(NSURLConnection *)c didFailWithError:(NSError *)error {
    [conn release]; conn = nil;
    if ([self isTransient:error] && attempt < 2 && !(gotTokens && attempt > 0)) {
        attempt++;
        if ([delegate respondsToSelector:@selector(clientWillRetry:attempt:)]) [delegate clientWillRetry:self attempt:attempt];
        [self performSelector:@selector(retryAfterDelay) withObject:nil afterDelay:1.0];
        return;
    }
    [delegate client:self didFailWithMessage:[error localizedDescription]];
}

+ (NSArray *)fetchModelsWithError:(NSString **)err {
    // The model catalogue lives on the control plane (api.openrelay.inc), not the inference host.
    NSString *base = [ORSettings baseURL];
    NSString *host = [base stringByReplacingOccurrencesOfString:@"inference." withString:@"api."];
    NSString *url = [NSString stringWithFormat:@"%@/v1/models", host];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:url] cachePolicy:NSURLRequestReloadIgnoringLocalCacheData timeoutInterval:30];
    [req setValue:[NSString stringWithFormat:@"Bearer %@", [ORSettings apiKey]] forHTTPHeaderField:@"Authorization"];
    NSHTTPURLResponse *resp = nil; NSError *e = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:req returningResponse:&resp error:&e];
    if (!data) { if (err) *err = [e localizedDescription]; return nil; }
    NSString *text = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
    id obj = [ORJSON parse:text];
    if ([resp statusCode] != 200 || ![obj isKindOfClass:[NSDictionary class]]) { if (err) *err = [NSString stringWithFormat:@"HTTP %d from %@", (int)[resp statusCode], host]; return nil; }
    NSMutableArray *ids = [NSMutableArray array]; NSMutableArray *vision = [NSMutableArray array];
    for (id m in [obj objectForKey:@"data"]) {
        if (![m isKindOfClass:[NSDictionary class]] || ![m objectForKey:@"id"]) continue;
        id mod = [m objectForKey:@"modalities"]; BOOL seesImages = NO;
        if ([mod isKindOfClass:[NSDictionary class]]) for (id x in [mod objectForKey:@"input"]) if ([[x description] isEqualToString:@"image"]) seesImages = YES;
        // only chat-capable, currently available models
        id eps = [m objectForKey:@"endpoints"];
        BOOL chat = [eps isKindOfClass:[NSDictionary class]] && ([eps objectForKey:@"chat_completions"] || [eps objectForKey:@"chat"] || [eps objectForKey:@"messages"]);
        if (!chat) { id apis = [m objectForKey:@"supported_apis"]; if ([apis isKindOfClass:[NSArray class]]) for (id a in apis) if ([[a description] rangeOfString:@"chat"].location != NSNotFound) chat = YES; }
        id status = [m objectForKey:@"status"];
        if ([status isKindOfClass:[NSString class]] && ![status isEqualToString:@"available"]) continue;
        if (chat) { [ids addObject:[m objectForKey:@"id"]]; if (seesImages) [vision addObject:[m objectForKey:@"id"]]; }
    }
    [ids sortUsingSelector:@selector(compare:)];
    [[NSUserDefaults standardUserDefaults] setObject:vision forKey:@"or_vision_models"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    return ids;
}
@end

#import <Foundation/Foundation.h>

@protocol ORClientDelegate <NSObject>
- (void)clientDidStart:(id)client;
- (void)client:(id)client didReceiveToken:(NSString *)token;
- (void)clientDidFinish:(id)client;
- (void)client:(id)client didFailWithMessage:(NSString *)message;
@optional
- (void)clientWillRetry:(id)client attempt:(NSInteger)attempt;   // transient network/TLS failure, resending
- (void)clientDidConnect:(id)client;                                // server accepted the request (HTTP 200): "Delivered"
@end

@interface ORSettings : NSObject
+ (NSString *)apiKey;      + (void)setApiKey:(NSString *)k;
+ (NSString *)model;       + (void)setModel:(NSString *)m;
+ (NSString *)baseURL;     + (void)setBaseURL:(NSString *)u;
+ (NSString *)systemPrompt;+ (void)setSystemPrompt:(NSString *)p;
+ (NSArray *)visionModels;
+ (BOOL)pacing;            + (void)setPacing:(BOOL)v;        // release bursts at a human pace
+ (BOOL)sounds;            + (void)setSounds:(BOOL)v;
+ (NSInteger)unpromptedPerDay; + (void)setUnpromptedPerDay:(NSInteger)n;   // texts contacts send you first, per day
@end

// Streaming chat-completions client (OpenAI-compatible SSE) built on NSURLConnection.
@interface ORClient : NSObject {
    NSURLConnection *conn;
    NSMutableData *buffer;     // unparsed SSE bytes
    NSMutableData *errorBody;  // body when HTTP status != 200
    NSInteger status;
    id<ORClientDelegate> delegate;
    BOOL finished;
    NSArray *lastMessages;     // for retries
    NSInteger attempt;
    BOOL gotTokens;
}
@property (nonatomic, assign) id<ORClientDelegate> delegate;
@property (nonatomic, copy) NSString *personaPrompt;   // contact personality, layered under the built-in rules
@property (nonatomic, copy) NSString *modelOverride;   // contact model, or nil for the default
- (void)sendMessages:(NSArray *)messages;   // array of {role, content}
- (void)cancel;
@property (nonatomic, readonly) BOOL running;

+ (NSString *)builtInSystemPrompt;

// one-shot GET /v1/models -> array of model id strings (synchronous helper, call off main thread)
+ (NSArray *)fetchModelsWithError:(NSString **)err;
@end

#import <Cocoa/Cocoa.h>
NS_ASSUME_NONNULL_BEGIN
@interface NexusBridge : NSObject
@property(nonatomic, copy, nullable) void (^featureHandler)(NSString *, NSUInteger);
- (instancetype)initWithDemo:(BOOL)demo;
- (NSView *)surface:(NSString *)feature session:(NSUInteger)session window:(NSWindow *)window;
- (NSString *)status:(NSUInteger)session;
- (void)shutdown;
@end
NS_ASSUME_NONNULL_END

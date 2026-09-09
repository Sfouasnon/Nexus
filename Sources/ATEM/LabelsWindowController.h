#import <Cocoa/Cocoa.h>

@class ATEMController;

NS_ASSUME_NONNULL_BEGIN

@interface LabelsWindowController : NSWindowController

- (instancetype)initWithControllers:(NSArray<ATEMController *> *)controllers
                initialSessionIndex:(NSUInteger)sessionIndex;
- (void)selectSessionIndex:(NSUInteger)sessionIndex;
- (void)scrollOutputsIntoView;
- (instancetype)initWithWindow:(nullable NSWindow *)window NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END

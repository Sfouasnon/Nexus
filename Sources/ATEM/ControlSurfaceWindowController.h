#import <Cocoa/Cocoa.h>

@class ATEMController;

NS_ASSUME_NONNULL_BEGIN

@interface ControlSurfaceWindowController : NSWindowController
@property(nonatomic, copy, nullable) void (^featureActionHandler)(NSString *feature,
                                                                     NSUInteger sessionIndex);
@property(nonatomic, readonly) NSUInteger activeSessionIndex;
- (instancetype)initWithControllers:(NSArray<ATEMController *> *)controllers;
- (instancetype)initWithControllers:(NSArray<ATEMController *> *)controllers
                   defaultsNamespace:(NSString *)defaultsNamespace;
- (void)scrollMultiviewIntoView;
- (void)selectSessionIndex:(NSUInteger)index;
- (instancetype)initWithWindow:(nullable NSWindow *)window NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;
@end

NS_ASSUME_NONNULL_END

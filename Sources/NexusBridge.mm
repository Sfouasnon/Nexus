#import "NexusBridge.h"
#import "ATEM/ATEMController.h"
#import "ATEM/ControlSurfaceWindowController.h"
#import "ATEM/AudioWindowController.h"
#import "ATEM/ColorWindowController.h"
#import "ATEM/LabelsWindowController.h"
#import "ATEM/MediaWindowController.h"
#import "ATEM/HyperDeckWindowController.h"
@interface NexusBridge ()
@property(nonatomic) NSUInteger hyperdeckSession;
@property NSArray<ATEMController *> *controllers;
@property NSMutableDictionary<NSString *, NSWindowController *> *panels;
@property NSMutableDictionary<NSString *, NSView *> *views;
@end
@implementation NexusBridge
- (instancetype)initWithDemo:(BOOL)demo identifier:(NSString *)identifier {
    if ((self = [super init])) {
        _controllers = @[[ATEMController new], [ATEMController new]];
        _panels = [NSMutableDictionary new]; _views = [NSMutableDictionary new];
        ControlSurfaceWindowController *console = [[ControlSurfaceWindowController alloc]
            initWithControllers:_controllers defaultsNamespace:identifier];
        __weak NexusBridge *weakSelf = self;
        console.featureActionHandler = ^(NSString *feature, NSUInteger session) {
            if ([feature isEqualToString:@"hyperdeck"]) {
                weakSelf.hyperdeckSession = session;
                [(HyperDeckWindowController *)weakSelf.panels[@"hyperdeck"] selectSessionIndex:session];
            }
            if (weakSelf.featureHandler) weakSelf.featureHandler(feature, session);
        };
        _panels[@"switcher"] = console;
        _views[@"switcher"] = console.window.contentView;
        if (demo) for (ATEMController *controller in _controllers) [controller enterDemoMode];
    }
    return self;
}
- (NSView *)surface:(NSString *)feature session:(NSUInteger)session window:(NSWindow *)window {
    NSParameterAssert(session < 2);
    NSWindowController *panel = self.panels[feature];
    if (!panel) {
        Class type = @{@"audio": AudioWindowController.class, @"color": ColorWindowController.class,
                       @"labels": LabelsWindowController.class, @"media": MediaWindowController.class,
                       @"hyperdeck": HyperDeckWindowController.class}[feature];
        NSParameterAssert(type != Nil);
        panel = [[type alloc] initWithControllers:self.controllers initialSessionIndex:[feature isEqualToString:@"hyperdeck"] ? self.hyperdeckSession : session];
        self.panels[feature] = panel;
        self.views[feature] = panel.window.contentView;
    }
    if (![feature isEqualToString:@"hyperdeck"]) [(id)panel selectSessionIndex:session];
    // All AppKit field editing and dialogs must address the actual host window.
    panel.window = window;
    NSSegmentedControl *selector = [panel valueForKey:@"sessionSelector"];
    // Each Nexus hardware tab owns one ATEM. Keep the legacy two-session
    // selector visible for layout compatibility, but prevent it from reaching
    // the unused compatibility controller.
    selector.enabled = NO;
    selector.toolTip = @"Choose the hardware tab above to change ATEM";
    return self.views[feature];
}
- (NSString *)status:(NSUInteger)session {
    ATEMState *state = self.controllers[session].latestState;
    return state.isDemo ? @"Demo" : state.isConnected ? @"Connected" : state.isConnecting ? @"Connecting" : @"Offline";
}
- (void)shutdown { [(ColorWindowController *)self.panels[@"color"] shutdown]; for (ATEMController *controller in self.controllers) [controller disconnect]; }
@end

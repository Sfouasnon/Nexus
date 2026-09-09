#import <Cocoa/Cocoa.h>
#import "ATEMController.h"
#import "AudioWindowController.h"
#import "ColorWindowController.h"
#import "ControlSurfaceWindowController.h"
#import "HyperDeckWindowController.h"
#import "LabelsWindowController.h"
#import "MediaWindowController.h"

@interface AppDelegate : NSObject <NSApplicationDelegate>
@property(nonatomic, strong) NSArray<ATEMController *> *controllers;
@property(nonatomic, strong) ControlSurfaceWindowController *windowController;
@property(nonatomic, strong) AudioWindowController *audioWindowController;
@property(nonatomic, strong) ColorWindowController *colorWindowController;
@property(nonatomic, strong) LabelsWindowController *labelsWindowController;
@property(nonatomic, strong) MediaWindowController *mediaWindowController;
@property(nonatomic, strong) HyperDeckWindowController *hyperDeckWindowController;
- (void)showAudioWindowForSession:(NSUInteger)sessionIndex;
- (void)showColorWindowForSession:(NSUInteger)sessionIndex;
- (void)showLabelsWindowForSession:(NSUInteger)sessionIndex;
- (void)showMediaWindowForSession:(NSUInteger)sessionIndex;
- (void)showHyperDeckWindowForSession:(NSUInteger)sessionIndex;
@end


@implementation AppDelegate

- (void)installMainMenu
{
    NSMenu *mainMenu = [[NSMenu alloc] initWithTitle:@"Main Menu"];

    NSMenuItem *applicationItem = [[NSMenuItem alloc] initWithTitle:@"ATEM CNTRL" action:nil keyEquivalent:@""];
    NSMenu *applicationMenu = [[NSMenu alloc] initWithTitle:@"ATEM CNTRL"];
    [applicationMenu addItemWithTitle:@"About ATEM CNTRL" action:@selector(orderFrontStandardAboutPanel:) keyEquivalent:@""];
    [applicationMenu addItem:NSMenuItem.separatorItem];
    NSMenuItem *hide = [applicationMenu addItemWithTitle:@"Hide ATEM CNTRL" action:@selector(hide:) keyEquivalent:@"h"];
    hide.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    [applicationMenu addItemWithTitle:@"Hide Others" action:@selector(hideOtherApplications:) keyEquivalent:@""];
    [applicationMenu addItemWithTitle:@"Show All" action:@selector(unhideAllApplications:) keyEquivalent:@""];
    [applicationMenu addItem:NSMenuItem.separatorItem];
    NSMenuItem *quit = [applicationMenu addItemWithTitle:@"Quit ATEM CNTRL" action:@selector(terminate:) keyEquivalent:@"q"];
    quit.keyEquivalentModifierMask = NSEventModifierFlagCommand;
    applicationItem.submenu = applicationMenu;
    [mainMenu addItem:applicationItem];

    NSMenuItem *editItem = [[NSMenuItem alloc] initWithTitle:@"Edit" action:nil keyEquivalent:@""];
    NSMenu *editMenu = [[NSMenu alloc] initWithTitle:@"Edit"];
    [editMenu addItemWithTitle:@"Undo" action:@selector(undo:) keyEquivalent:@"z"];
    [editMenu addItemWithTitle:@"Redo" action:@selector(redo:) keyEquivalent:@"Z"];
    [editMenu addItem:NSMenuItem.separatorItem];
    [editMenu addItemWithTitle:@"Cut" action:@selector(cut:) keyEquivalent:@"x"];
    [editMenu addItemWithTitle:@"Copy" action:@selector(copy:) keyEquivalent:@"c"];
    [editMenu addItemWithTitle:@"Paste" action:@selector(paste:) keyEquivalent:@"v"];
    [editMenu addItemWithTitle:@"Select All" action:@selector(selectAll:) keyEquivalent:@"a"];
    editItem.submenu = editMenu;
    [mainMenu addItem:editItem];

    NSMenuItem *windowItem = [[NSMenuItem alloc] initWithTitle:@"Window" action:nil keyEquivalent:@""];
    NSMenu *windowMenu = [[NSMenu alloc] initWithTitle:@"Window"];
    [windowMenu addItemWithTitle:@"Minimize" action:@selector(performMiniaturize:) keyEquivalent:@"m"];
    [windowMenu addItemWithTitle:@"Zoom" action:@selector(performZoom:) keyEquivalent:@""];
    [windowMenu addItem:NSMenuItem.separatorItem];
    NSMenuItem *console = [windowMenu addItemWithTitle:@"Switcher Console"
                                                action:@selector(showSwitcherConsole:)
                                         keyEquivalent:@"1"];
    console.target = self;
    NSMenuItem *audio = [windowMenu addItemWithTitle:@"Audio Mixer"
                                              action:@selector(showAudioWindow:)
                                       keyEquivalent:@"2"];
    audio.target = self;
    NSMenuItem *color = [windowMenu addItemWithTitle:@"Camera / Color"
                                              action:@selector(showColorWindow:)
                                       keyEquivalent:@"3"];
    color.target = self;
    NSMenuItem *hyperDeck = [windowMenu addItemWithTitle:@"HyperDeck"
                                                  action:@selector(showHyperDeckWindow:)
                                           keyEquivalent:@"4"];
    hyperDeck.target = self;
    NSMenuItem *labels = [windowMenu addItemWithTitle:@"Input & Output Labels"
                                               action:@selector(showLabelsWindow:)
                                        keyEquivalent:@"5"];
    labels.target = self;
    NSMenuItem *media = [windowMenu addItemWithTitle:@"Media / Color Generators"
                                              action:@selector(showMediaWindow:)
                                       keyEquivalent:@"6"];
    media.target = self;
    [windowMenu addItem:NSMenuItem.separatorItem];
    [windowMenu addItemWithTitle:@"Bring All to Front" action:@selector(arrangeInFront:) keyEquivalent:@""];
    windowItem.submenu = windowMenu;
    [mainMenu addItem:windowItem];
    NSApp.windowsMenu = windowMenu;
    NSApp.mainMenu = mainMenu;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    (void)notification;
    [self installMainMenu];
    self.controllers = @[[[ATEMController alloc] init], [[ATEMController alloc] init]];
    self.windowController = [[ControlSurfaceWindowController alloc] initWithControllers:self.controllers];
    __weak AppDelegate *weakSelf = self;
    self.windowController.featureActionHandler = ^(NSString *feature, NSUInteger sessionIndex) {
        AppDelegate *strongSelf = weakSelf;
        if ([feature isEqualToString:@"audio"])
            [strongSelf showAudioWindowForSession:sessionIndex];
        else if ([feature isEqualToString:@"color"])
            [strongSelf showColorWindowForSession:sessionIndex];
        else if ([feature isEqualToString:@"hyperdeck"])
            [strongSelf showHyperDeckWindowForSession:sessionIndex];
        else if ([feature isEqualToString:@"labels"])
            [strongSelf showLabelsWindowForSession:sessionIndex];
        else if ([feature isEqualToString:@"media"])
            [strongSelf showMediaWindowForSession:sessionIndex];
    };
    [self.windowController showWindow:self];
    [self.windowController.window makeKeyAndOrderFront:self];
    [self.windowController.window orderFrontRegardless];
    [NSApp activateIgnoringOtherApps:YES];

    if ([[NSProcessInfo processInfo].arguments containsObject:@"--demo"])
        for (ATEMController *controller in self.controllers)
            [controller enterDemoMode];

    NSArray<NSString *> *arguments = NSProcessInfo.processInfo.arguments;
    NSUInteger renderIndex = [arguments indexOfObject:@"--render-preview"];
    BOOL renderMultiview = NO;
    NSString *renderFeature = nil;
    if (renderIndex == NSNotFound) {
        renderIndex = [arguments indexOfObject:@"--render-multiview-preview"];
        renderMultiview = renderIndex != NSNotFound;
    }
    if (renderIndex == NSNotFound) {
        NSArray<NSString *> *featureFlags = @[@"--render-audio-preview",
                                               @"--render-color-preview",
                                               @"--render-hyperdeck-preview",
                                               @"--render-labels-preview",
                                               @"--render-media-preview"];
        NSArray<NSString *> *featureNames = @[@"audio", @"color", @"hyperdeck", @"labels", @"media"];
        for (NSUInteger index = 0; index < featureFlags.count; ++index) {
            renderIndex = [arguments indexOfObject:featureFlags[index]];
            if (renderIndex != NSNotFound) {
                renderFeature = featureNames[index];
                break;
            }
        }
    }
    if (renderIndex != NSNotFound && renderIndex + 1 < arguments.count) {
        NSString *outputPath = arguments[renderIndex + 1];
        NSString *feature = [renderFeature copy];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            NSWindowController *renderController = self.windowController;
            if ([feature isEqualToString:@"audio"]) {
                [self showAudioWindowForSession:0];
                renderController = self.audioWindowController;
            } else if ([feature isEqualToString:@"color"]) {
                [self showColorWindowForSession:0];
                renderController = self.colorWindowController;
            } else if ([feature isEqualToString:@"hyperdeck"]) {
                [self showHyperDeckWindowForSession:0];
                renderController = self.hyperDeckWindowController;
            } else if ([feature isEqualToString:@"labels"]) {
                [self showLabelsWindowForSession:0];
                renderController = self.labelsWindowController;
            } else if ([feature isEqualToString:@"media"]) {
                [self showMediaWindowForSession:0];
                renderController = self.mediaWindowController;
            }
            void (^capture)(void) = ^{
                NSView *contentView = renderController.window.contentView;
                [contentView layoutSubtreeIfNeeded];
                if (renderMultiview && renderController == self.windowController)
                    [self.windowController scrollMultiviewIntoView];
                if ([feature isEqualToString:@"labels"])
                    [self.labelsWindowController scrollOutputsIntoView];
                NSBitmapImageRep *bitmap = [contentView bitmapImageRepForCachingDisplayInRect:contentView.bounds];
                [contentView cacheDisplayInRect:contentView.bounds toBitmapImageRep:bitmap];
                NSData *png = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
                BOOL written = [png writeToFile:outputPath atomically:YES];
                fprintf(stderr, "preview render: %s\n", written ? outputPath.UTF8String : "failed");
                [NSApp terminate:self];
            };
            if (feature.length)
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 600 * NSEC_PER_MSEC), dispatch_get_main_queue(), capture);
            else
                capture();
        });
    }
}

- (void)showWindowController:(NSWindowController *)controller
{
    [controller showWindow:self];
    [controller.window makeKeyAndOrderFront:self];
    [NSApp activateIgnoringOtherApps:YES];
}

- (void)showSwitcherConsole:(id)sender
{
    (void)sender;
    [self showWindowController:self.windowController];
}

- (void)showAudioWindowForSession:(NSUInteger)sessionIndex
{
    if (!self.audioWindowController)
        self.audioWindowController = [[AudioWindowController alloc] initWithControllers:self.controllers
                                                                    initialSessionIndex:sessionIndex];
    [self.audioWindowController selectSessionIndex:sessionIndex];
    [self showWindowController:self.audioWindowController];
}

- (void)showAudioWindow:(id)sender
{
    (void)sender;
    [self showAudioWindowForSession:self.windowController.activeSessionIndex];
}

- (void)showColorWindowForSession:(NSUInteger)sessionIndex
{
    if (!self.colorWindowController)
        self.colorWindowController = [[ColorWindowController alloc] initWithControllers:self.controllers
                                                                    initialSessionIndex:sessionIndex];
    [self.colorWindowController selectSessionIndex:sessionIndex];
    [self showWindowController:self.colorWindowController];
}

- (void)showColorWindow:(id)sender
{
    (void)sender;
    [self showColorWindowForSession:self.windowController.activeSessionIndex];
}

- (void)showHyperDeckWindowForSession:(NSUInteger)sessionIndex
{
    if (!self.hyperDeckWindowController)
        self.hyperDeckWindowController = [[HyperDeckWindowController alloc] initWithControllers:self.controllers
                                                                            initialSessionIndex:sessionIndex];
    [self.hyperDeckWindowController selectSessionIndex:sessionIndex];
    [self showWindowController:self.hyperDeckWindowController];
}

- (void)showHyperDeckWindow:(id)sender
{
    (void)sender;
    [self showHyperDeckWindowForSession:self.windowController.activeSessionIndex];
}

- (void)showLabelsWindowForSession:(NSUInteger)sessionIndex
{
    if (!self.labelsWindowController)
        self.labelsWindowController = [[LabelsWindowController alloc] initWithControllers:self.controllers
                                                                       initialSessionIndex:sessionIndex];
    [self.labelsWindowController selectSessionIndex:sessionIndex];
    [self showWindowController:self.labelsWindowController];
}

- (void)showLabelsWindow:(id)sender
{
    (void)sender;
    [self showLabelsWindowForSession:self.windowController.activeSessionIndex];
}

- (void)showMediaWindowForSession:(NSUInteger)sessionIndex
{
    if (!self.mediaWindowController)
        self.mediaWindowController = [[MediaWindowController alloc] initWithControllers:self.controllers
                                                                    initialSessionIndex:sessionIndex];
    [self.mediaWindowController selectSessionIndex:sessionIndex];
    [self showWindowController:self.mediaWindowController];
}

- (void)showMediaWindow:(id)sender
{
    (void)sender;
    [self showMediaWindowForSession:self.windowController.activeSessionIndex];
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender
{
    (void)sender;
    return YES;
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    (void)notification;
    BOOL hasVisibleWindow = NO;
    for (NSWindow *window in NSApp.windows)
        hasVisibleWindow |= window.isVisible;
    if (!hasVisibleWindow)
        [self.windowController.window makeKeyAndOrderFront:self];
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
    (void)notification;
    [self.colorWindowController shutdown];
    for (ATEMController *controller in self.controllers)
        [controller shutdown];
}

@end


int main(int argc, const char *argv[])
{
    (void)argc;
    (void)argv;
    @autoreleasepool {
        NSArray<NSString *> *arguments = NSProcessInfo.processInfo.arguments;
        if ([arguments containsObject:@"--self-test"])
            return ATEMRunSelfTest();
        if ([arguments containsObject:@"--diagnostics"])
            return ATEMPrintDiagnostics();

        NSApplication *application = NSApplication.sharedApplication;
        application.activationPolicy = NSApplicationActivationPolicyRegular;
        AppDelegate *delegate = [[AppDelegate alloc] init];
        application.delegate = delegate;
        [application run];
    }
    return 0;
}

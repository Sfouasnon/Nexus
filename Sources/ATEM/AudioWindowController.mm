#import "AudioWindowController.h"

#import "ATEMController.h"

static NSColor *AudioCanvas(void) { return [NSColor colorWithRed:0.035 green:0.053 blue:0.074 alpha:1]; }
static NSColor *AudioHeader(void) { return [NSColor colorWithRed:0.045 green:0.067 blue:0.091 alpha:1]; }
static NSColor *AudioPanel(void) { return [NSColor colorWithRed:0.065 green:0.090 blue:0.120 alpha:1]; }
static NSColor *AudioPanelRaised(void) { return [NSColor colorWithRed:0.085 green:0.113 blue:0.145 alpha:1]; }
static NSColor *AudioBorder(void) { return [NSColor colorWithRed:0.16 green:0.22 blue:0.28 alpha:1]; }
static NSColor *AudioText(void) { return [NSColor colorWithWhite:0.94 alpha:1]; }
static NSColor *AudioMuted(void) { return [NSColor colorWithWhite:0.60 alpha:1]; }
static NSColor *AudioCyan(void) { return [NSColor colorWithRed:0.13 green:0.82 blue:0.91 alpha:1]; }
static NSColor *AudioViolet(void) { return [NSColor colorWithRed:0.58 green:0.44 blue:0.96 alpha:1]; }
static NSColor *AudioGreen(void) { return [NSColor colorWithRed:0.20 green:0.82 blue:0.48 alpha:1]; }
static NSColor *AudioAmber(void) { return [NSColor colorWithRed:0.95 green:0.66 blue:0.18 alpha:1]; }
static NSColor *AudioRed(void) { return [NSColor colorWithRed:0.96 green:0.25 blue:0.32 alpha:1]; }

static NSTextField *AudioLabel(NSString *text, CGFloat size, NSFontWeight weight, NSColor *color)
{
    NSTextField *label = [NSTextField labelWithString:text];
    label.font = [NSFont systemFontOfSize:size weight:weight];
    label.textColor = color;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.allowsDefaultTighteningForTruncation = YES;
    return label;
}

static NSButton *AudioButton(NSString *title, id target, SEL action)
{
    NSButton *button = [NSButton buttonWithTitle:title target:target action:action];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.bezelStyle = NSBezelStyleTexturedRounded;
    button.font = [NSFont systemFontOfSize:10.5 weight:NSFontWeightSemibold];
    button.contentTintColor = AudioText();
    return button;
}

static double AudioLevelAtIndex(NSArray<NSNumber *> *levels, NSUInteger index)
{
    if (levels.count == 0)
        return -60.0;
    NSUInteger safeIndex = MIN(index, levels.count - 1);
    double value = levels[safeIndex].doubleValue;
    return isfinite(value) ? MAX(-60.0, MIN(0.0, value)) : -60.0;
}

static CGFloat AudioLevelFraction(double decibels)
{
    return (CGFloat)((MAX(-60.0, MIN(0.0, decibels)) + 60.0) / 60.0);
}

static NSString *AudioGainString(double value)
{
    if (value <= -99.5)
        return @"−∞ dB";
    return [NSString stringWithFormat:@"%+.1f dB", value];
}


@interface ATEMAudioHistoryView : NSView
@property(nonatomic, strong) NSMutableArray<NSNumber *> *leftHistory;
@property(nonatomic, strong) NSMutableArray<NSNumber *> *rightHistory;
- (void)appendLevels:(NSArray<NSNumber *> *)levels;
- (void)clearHistory;
@end

@implementation ATEMAudioHistoryView

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        _leftHistory = [NSMutableArray array];
        _rightHistory = [NSMutableArray array];
        self.wantsLayer = YES;
        self.layer.cornerRadius = 5;
        self.accessibilityElement = YES;
        self.accessibilityRole = NSAccessibilityGroupRole;
        self.accessibilityLabel = @"Rolling audio level history";
        self.accessibilityValue = @"No level history";
    }
    return self;
}

- (BOOL)isFlipped
{
    return YES;
}

- (void)appendLevels:(NSArray<NSNumber *> *)levels
{
    double leftLevel = AudioLevelAtIndex(levels, 0);
    double rightLevel = AudioLevelAtIndex(levels, 1);
    [self.leftHistory addObject:@(leftLevel)];
    [self.rightHistory addObject:@(rightLevel)];
    const NSUInteger maximumSamples = 180;
    if (self.leftHistory.count > maximumSamples)
        [self.leftHistory removeObjectsInRange:NSMakeRange(0, self.leftHistory.count - maximumSamples)];
    if (self.rightHistory.count > maximumSamples)
        [self.rightHistory removeObjectsInRange:NSMakeRange(0, self.rightHistory.count - maximumSamples)];
    self.accessibilityValue = [NSString stringWithFormat:@"Latest left %.1f dBFS, right %.1f dBFS",
                               leftLevel, rightLevel];
    self.needsDisplay = YES;
}

- (void)clearHistory
{
    [self.leftHistory removeAllObjects];
    [self.rightHistory removeAllObjects];
    self.accessibilityValue = @"No level history";
    self.needsDisplay = YES;
}

- (void)drawHistory:(NSArray<NSNumber *> *)history color:(NSColor *)color
{
    if (history.count < 2)
        return;

    NSRect graph = NSInsetRect(self.bounds, 5, 5);
    CGFloat step = NSWidth(graph) / MAX((CGFloat)history.count - 1.0, 1.0);
    NSBezierPath *path = [NSBezierPath bezierPath];
    path.lineWidth = 1.45;
    path.lineJoinStyle = NSLineJoinStyleRound;
    for (NSUInteger index = 0; index < history.count; ++index) {
        CGFloat x = NSMinX(graph) + step * index;
        CGFloat y = NSMaxY(graph) - AudioLevelFraction(history[index].doubleValue) * NSHeight(graph);
        NSPoint point = NSMakePoint(x, y);
        if (index == 0)
            [path moveToPoint:point];
        else
            [path lineToPoint:point];
    }
    [color setStroke];
    [path stroke];
}

- (void)drawRect:(NSRect)dirtyRect
{
    (void)dirtyRect;
    [AudioCanvas() setFill];
    [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:5 yRadius:5] fill];

    NSRect graph = NSInsetRect(self.bounds, 5, 5);
    NSColor *gridColor = [AudioBorder() colorWithAlphaComponent:0.46];
    [gridColor setStroke];
    for (NSUInteger line = 1; line < 4; ++line) {
        CGFloat y = NSMinY(graph) + NSHeight(graph) * line / 4.0;
        NSBezierPath *grid = [NSBezierPath bezierPath];
        grid.lineWidth = 0.5;
        [grid moveToPoint:NSMakePoint(NSMinX(graph), y)];
        [grid lineToPoint:NSMakePoint(NSMaxX(graph), y)];
        [grid stroke];
    }

    [self drawHistory:self.rightHistory color:[AudioViolet() colorWithAlphaComponent:0.82]];
    [self drawHistory:self.leftHistory color:AudioCyan()];
}

@end


@interface ATEMAudioMeterView : NSView
@property(nonatomic, copy) NSArray<NSNumber *> *levels;
@property(nonatomic, copy) NSArray<NSNumber *> *peakLevels;
- (void)setLevels:(NSArray<NSNumber *> *)levels peakLevels:(NSArray<NSNumber *> *)peakLevels;
@end

@implementation ATEMAudioMeterView

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        _levels = @[];
        _peakLevels = @[];
        self.accessibilityElement = YES;
        self.accessibilityRole = NSAccessibilityGroupRole;
        self.accessibilityLabel = @"Stereo audio meter";
        self.accessibilityValue = @"Left −60.0 dBFS, right −60.0 dBFS";
    }
    return self;
}

- (BOOL)isFlipped
{
    return YES;
}

- (void)setLevels:(NSArray<NSNumber *> *)levels peakLevels:(NSArray<NSNumber *> *)peakLevels
{
    _levels = [levels copy] ?: @[];
    _peakLevels = [peakLevels copy] ?: @[];
    self.accessibilityValue =
        [NSString stringWithFormat:@"Left %.1f dBFS, right %.1f dBFS; peaks %.1f and %.1f dBFS",
                                   AudioLevelAtIndex(_levels, 0),
                                   AudioLevelAtIndex(_levels, 1),
                                   AudioLevelAtIndex(_peakLevels, 0),
                                   AudioLevelAtIndex(_peakLevels, 1)];
    self.needsDisplay = YES;
}

- (void)fillMeterRect:(NSRect)bar upToFraction:(CGFloat)fraction
{
    fraction = MAX(0.0, MIN(1.0, fraction));
    CGFloat activeHeight = NSHeight(bar) * fraction;
    if (activeHeight <= 0)
        return;

    NSRect active = NSMakeRect(NSMinX(bar), NSMaxY(bar) - activeHeight, NSWidth(bar), activeHeight);
    CGFloat redBoundary = NSMinY(bar) + NSHeight(bar) * 0.10;
    CGFloat amberBoundary = NSMinY(bar) + NSHeight(bar) * 0.30;
    NSRect redZone = NSMakeRect(NSMinX(bar), NSMinY(bar), NSWidth(bar), redBoundary - NSMinY(bar));
    NSRect amberZone = NSMakeRect(NSMinX(bar), redBoundary, NSWidth(bar), amberBoundary - redBoundary);
    NSRect greenZone = NSMakeRect(NSMinX(bar), amberBoundary, NSWidth(bar), NSMaxY(bar) - amberBoundary);

    NSRect redFill = NSIntersectionRect(active, redZone);
    NSRect amberFill = NSIntersectionRect(active, amberZone);
    NSRect greenFill = NSIntersectionRect(active, greenZone);
    if (!NSIsEmptyRect(redFill)) {
        [AudioRed() setFill];
        NSRectFill(redFill);
    }
    if (!NSIsEmptyRect(amberFill)) {
        [AudioAmber() setFill];
        NSRectFill(amberFill);
    }
    if (!NSIsEmptyRect(greenFill)) {
        [AudioGreen() setFill];
        NSRectFill(greenFill);
    }
}

- (void)drawRect:(NSRect)dirtyRect
{
    (void)dirtyRect;
    [AudioCanvas() setFill];
    [[NSBezierPath bezierPathWithRoundedRect:self.bounds xRadius:5 yRadius:5] fill];

    CGFloat inset = 6;
    CGFloat gap = 4;
    CGFloat width = (NSWidth(self.bounds) - inset * 2 - gap) / 2.0;
    for (NSUInteger channel = 0; channel < 2; ++channel) {
        NSRect bar = NSMakeRect(inset + channel * (width + gap),
                                inset,
                                width,
                                NSHeight(self.bounds) - inset * 2);
        [[AudioPanelRaised() colorWithAlphaComponent:0.72] setFill];
        [[NSBezierPath bezierPathWithRoundedRect:bar xRadius:2 yRadius:2] fill];
        [self fillMeterRect:bar upToFraction:AudioLevelFraction(AudioLevelAtIndex(self.levels, channel))];

        CGFloat peakFraction = AudioLevelFraction(AudioLevelAtIndex(self.peakLevels, channel));
        CGFloat peakY = NSMaxY(bar) - peakFraction * NSHeight(bar);
        NSColor *peakColor = peakFraction > 0.90 ? AudioRed() : AudioText();
        [peakColor setFill];
        NSRectFill(NSMakeRect(NSMinX(bar), peakY - 1, NSWidth(bar), 2));
    }
}

@end


@interface ATEMAudioSourceSlider : NSSlider
@property(nonatomic) int64_t inputID;
@property(nonatomic) int64_t sourceID;
@end

@implementation ATEMAudioSourceSlider
@end


@interface ATEMAudioMixControl : NSSegmentedControl
@property(nonatomic) int64_t inputID;
@property(nonatomic) int64_t sourceID;
@end

@implementation ATEMAudioMixControl
@end


@interface ATEMAudioChannelControls : NSObject
@property(nonatomic) int64_t inputID;
@property(nonatomic) int64_t sourceID;
@property(nonatomic, strong) NSView *container;
@property(nonatomic, strong) NSView *activeDot;
@property(nonatomic, strong) NSTextField *sourceLabel;
@property(nonatomic, strong) ATEMAudioHistoryView *history;
@property(nonatomic, strong) ATEMAudioMeterView *meter;
@property(nonatomic, strong) ATEMAudioSourceSlider *fader;
@property(nonatomic, strong) NSTextField *faderValue;
@property(nonatomic, strong) ATEMAudioSourceSlider *pan;
@property(nonatomic, strong) NSTextField *panValue;
@property(nonatomic, strong) ATEMAudioMixControl *mix;
@end

@implementation ATEMAudioChannelControls
@end


@interface AudioWindowController () <NSWindowDelegate>
@property(nonatomic, copy) NSArray<ATEMController *> *controllers;
@property(nonatomic) NSUInteger activeSessionIndex;
@property(nonatomic, strong) NSSegmentedControl *sessionSelector;
@property(nonatomic, strong) NSView *statusDot;
@property(nonatomic, strong) NSTextField *targetLabel;
@property(nonatomic, strong) NSTextField *statusLabel;
@property(nonatomic, strong) NSButton *resetPeaksButton;
@property(nonatomic, strong) NSStackView *mixerRow;
@property(nonatomic, copy) NSString *channelSignature;
@property(nonatomic, strong) NSMutableDictionary<NSString *, ATEMAudioChannelControls *> *channelControls;
@property(nonatomic, strong) ATEMAudioHistoryView *masterHistory;
@property(nonatomic, strong) ATEMAudioMeterView *masterMeter;
@property(nonatomic, strong) NSSlider *masterFader;
@property(nonatomic, strong) NSTextField *masterFaderValue;
@end

@implementation AudioWindowController

- (instancetype)initWithControllers:(NSArray<ATEMController *> *)controllers
                 initialSessionIndex:(NSUInteger)sessionIndex
{
    NSParameterAssert(controllers.count == 2);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1280, 720)
                                                  styleMask:(NSWindowStyleMaskTitled |
                                                             NSWindowStyleMaskClosable |
                                                             NSWindowStyleMaskMiniaturizable |
                                                             NSWindowStyleMaskResizable)
                                                    backing:NSBackingStoreBuffered
                                                      defer:NO];
    window.title = @"Fairlight Audio — ATEM CNTRL";
    window.minSize = NSMakeSize(900, 620);
    window.backgroundColor = AudioCanvas();
    window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    window.tabbingMode = NSWindowTabbingModeDisallowed;
    [window center];
    [window setFrameAutosaveName:@"ATEMCNTRLAudioWindow"];

    self = [super initWithWindow:window];
    if (self) {
        _controllers = [controllers copy];
        _activeSessionIndex = MIN(sessionIndex, controllers.count - 1);
        _channelControls = [NSMutableDictionary dictionary];
        window.delegate = self;
        [self buildInterface];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(audioStateDidChange:)
                                                     name:ATEMAudioStateDidChangeNotification
                                                   object:nil];
        [self refreshSessionState];
    }
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:ATEMAudioStateDidChangeNotification
                                                  object:nil];
}

- (ATEMController *)activeController
{
    return self.controllers[self.activeSessionIndex];
}

- (void)buildInterface
{
    NSView *root = [[NSView alloc] initWithFrame:self.window.contentView.bounds];
    root.translatesAutoresizingMaskIntoConstraints = NO;
    root.wantsLayer = YES;
    root.layer.backgroundColor = AudioCanvas().CGColor;
    self.window.contentView = root;

    NSView *header = [[NSView alloc] initWithFrame:NSZeroRect];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.wantsLayer = YES;
    header.layer.backgroundColor = AudioHeader().CGColor;
    header.layer.borderColor = AudioBorder().CGColor;
    header.layer.borderWidth = 1;
    [root addSubview:header];

    NSTextField *title = AudioLabel(@"FAIRLIGHT AUDIO", 20, NSFontWeightSemibold, AudioText());
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:title];
    NSTextField *subtitle = AudioLabel(@"Live stereo levels · rolling history · scroll horizontally for more channels", 10,
                                       NSFontWeightMedium, AudioMuted());
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:subtitle];

    self.sessionSelector = [NSSegmentedControl segmentedControlWithLabels:@[@"ATEM A", @"ATEM B"]
                                                               trackingMode:NSSegmentSwitchTrackingSelectOne
                                                                     target:self
                                                                     action:@selector(sessionChanged:)];
    self.sessionSelector.translatesAutoresizingMaskIntoConstraints = NO;
    self.sessionSelector.segmentStyle = NSSegmentStyleCapsule;
    self.sessionSelector.selectedSegment = self.activeSessionIndex;
    self.sessionSelector.selectedSegmentBezelColor = AudioCyan();
    self.sessionSelector.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
    self.sessionSelector.toolTip = @"Choose which connected ATEM this audio window controls.";
    self.sessionSelector.accessibilityLabel = @"Active ATEM audio session";
    [header addSubview:self.sessionSelector];

    self.statusDot = [[NSView alloc] initWithFrame:NSZeroRect];
    self.statusDot.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusDot.wantsLayer = YES;
    self.statusDot.layer.cornerRadius = 4;
    self.statusDot.layer.backgroundColor = AudioMuted().CGColor;
    [header addSubview:self.statusDot];

    self.targetLabel = AudioLabel(@"ATEM A · No switcher connected · NO IP TARGET", 11,
                                  NSFontWeightSemibold, AudioText());
    self.targetLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.targetLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    self.targetLabel.accessibilityLabel = @"Active audio target";
    [header addSubview:self.targetLabel];

    self.statusLabel = AudioLabel(@"Connect an ATEM to use its Fairlight mixer.", 9.5,
                                  NSFontWeightRegular, AudioMuted());
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    self.statusLabel.accessibilityLabel = @"Fairlight audio status";
    [header addSubview:self.statusLabel];

    self.resetPeaksButton = AudioButton(@"RESET PEAKS", self, @selector(resetPeaksPressed:));
    self.resetPeaksButton.contentTintColor = AudioCyan();
    self.resetPeaksButton.toolTip = @"Clear held peaks on the active ATEM's master and input meters.";
    self.resetPeaksButton.accessibilityLabel = @"Reset audio peak levels";
    [header addSubview:self.resetPeaksButton];

    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.drawsBackground = NO;
    scroll.hasHorizontalScroller = YES;
    scroll.hasVerticalScroller = NO;
    scroll.autohidesScrollers = NO;
    scroll.borderType = NSNoBorder;
    scroll.toolTip = @"Scroll horizontally to reach additional input channels and the master output.";
    scroll.accessibilityLabel = @"Horizontally scrolling Fairlight mixer";
    scroll.accessibilityHelp = @"Scroll left or right to reach every audio channel and the master output.";
    [root addSubview:scroll];

    NSView *document = [[NSView alloc] initWithFrame:NSZeroRect];
    document.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.documentView = document;

    self.mixerRow = [[NSStackView alloc] initWithFrame:NSZeroRect];
    self.mixerRow.translatesAutoresizingMaskIntoConstraints = NO;
    self.mixerRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    self.mixerRow.alignment = NSLayoutAttributeCenterY;
    self.mixerRow.distribution = NSStackViewDistributionFill;
    self.mixerRow.spacing = 10;
    [document addSubview:self.mixerRow];

    [NSLayoutConstraint activateConstraints:@[
        [header.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [header.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [header.topAnchor constraintEqualToAnchor:root.topAnchor],
        [header.heightAnchor constraintEqualToConstant:86],

        [title.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:22],
        [title.topAnchor constraintEqualToAnchor:header.topAnchor constant:16],
        [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:4],

        [self.sessionSelector.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [self.sessionSelector.leadingAnchor constraintEqualToAnchor:title.trailingAnchor constant:42],
        [self.sessionSelector.widthAnchor constraintEqualToConstant:184],

        [self.resetPeaksButton.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-20],
        [self.resetPeaksButton.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [self.resetPeaksButton.widthAnchor constraintEqualToConstant:116],
        [self.resetPeaksButton.heightAnchor constraintEqualToConstant:32],

        [self.statusDot.trailingAnchor constraintEqualToAnchor:self.targetLabel.leadingAnchor constant:-9],
        [self.statusDot.leadingAnchor constraintEqualToAnchor:self.sessionSelector.trailingAnchor constant:28],
        [self.statusDot.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [self.statusDot.widthAnchor constraintEqualToConstant:8],
        [self.statusDot.heightAnchor constraintEqualToConstant:8],
        [self.targetLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.resetPeaksButton.leadingAnchor constant:-18],
        [self.targetLabel.topAnchor constraintEqualToAnchor:header.topAnchor constant:24],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.targetLabel.leadingAnchor],
        [self.statusLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.resetPeaksButton.leadingAnchor constant:-18],
        [self.statusLabel.topAnchor constraintEqualToAnchor:self.targetLabel.bottomAnchor constant:3],

        [scroll.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:header.bottomAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:root.bottomAnchor],

        [document.leadingAnchor constraintEqualToAnchor:scroll.contentView.leadingAnchor],
        [document.topAnchor constraintEqualToAnchor:scroll.contentView.topAnchor],
        [document.heightAnchor constraintEqualToAnchor:scroll.contentView.heightAnchor],
        [document.widthAnchor constraintGreaterThanOrEqualToAnchor:scroll.contentView.widthAnchor],

        [self.mixerRow.leadingAnchor constraintEqualToAnchor:document.leadingAnchor constant:16],
        [self.mixerRow.trailingAnchor constraintEqualToAnchor:document.trailingAnchor constant:-16],
        [self.mixerRow.centerYAnchor constraintEqualToAnchor:document.centerYAnchor],
        [self.mixerRow.heightAnchor constraintEqualToConstant:570],
    ]];
}

- (NSString *)signatureForAudioState:(ATEMAudioState *)state
{
    NSMutableArray<NSString *> *parts = [NSMutableArray arrayWithObject:state.isAvailable ? @"available" : @"unavailable"];
    for (ATEMAudioChannelState *channel in state.channels) {
        [parts addObject:[NSString stringWithFormat:@"%lld:%lld:%@",
                          channel.inputID, channel.sourceID, channel.name ?: @""]];
    }
    return [parts componentsJoinedByString:@"|"];
}

- (NSString *)channelKeyForInput:(int64_t)inputID source:(int64_t)sourceID
{
    return [NSString stringWithFormat:@"%lld:%lld", inputID, sourceID];
}

- (void)removeAllMixerSubviews
{
    for (NSView *view in self.mixerRow.arrangedSubviews.copy) {
        [self.mixerRow removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    [self.channelControls removeAllObjects];
    self.masterHistory = nil;
    self.masterMeter = nil;
    self.masterFader = nil;
    self.masterFaderValue = nil;
}

- (NSView *)newStripContainerWithWidth:(CGFloat)width accent:(NSColor *)accent
{
    NSView *container = [[NSView alloc] initWithFrame:NSZeroRect];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.wantsLayer = YES;
    container.layer.backgroundColor = AudioPanel().CGColor;
    container.layer.borderColor = AudioBorder().CGColor;
    container.layer.borderWidth = 1;
    container.layer.cornerRadius = 10;

    NSView *accentLine = [[NSView alloc] initWithFrame:NSZeroRect];
    accentLine.translatesAutoresizingMaskIntoConstraints = NO;
    accentLine.wantsLayer = YES;
    accentLine.layer.backgroundColor = accent.CGColor;
    accentLine.layer.cornerRadius = 1.5;
    [container addSubview:accentLine];

    [NSLayoutConstraint activateConstraints:@[
        [container.widthAnchor constraintEqualToConstant:width],
        [container.heightAnchor constraintEqualToConstant:570],
        [accentLine.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:12],
        [accentLine.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-12],
        [accentLine.topAnchor constraintEqualToAnchor:container.topAnchor],
        [accentLine.heightAnchor constraintEqualToConstant:3],
    ]];
    return container;
}

- (ATEMAudioChannelControls *)buildChannelStrip:(ATEMAudioChannelState *)channel
{
    ATEMAudioChannelControls *controls = [[ATEMAudioChannelControls alloc] init];
    controls.inputID = channel.inputID;
    controls.sourceID = channel.sourceID;
    controls.container = [self newStripContainerWithWidth:178 accent:AudioCyan()];
    NSString *channelName = channel.name.length ? channel.name : @"Audio Source";

    NSTextField *title = AudioLabel(channelName, 12, NSFontWeightSemibold, AudioText());
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.toolTip = channelName;
    [controls.container addSubview:title];

    controls.activeDot = [[NSView alloc] initWithFrame:NSZeroRect];
    controls.activeDot.translatesAutoresizingMaskIntoConstraints = NO;
    controls.activeDot.wantsLayer = YES;
    controls.activeDot.layer.cornerRadius = 3.5;
    [controls.container addSubview:controls.activeDot];

    controls.sourceLabel = AudioLabel([NSString stringWithFormat:@"INPUT %lld · SOURCE %lld",
                                       channel.inputID, channel.sourceID],
                                      8.5, NSFontWeightMedium, AudioMuted());
    controls.sourceLabel.translatesAutoresizingMaskIntoConstraints = NO;
    controls.sourceLabel.font = [NSFont monospacedSystemFontOfSize:8.5 weight:NSFontWeightMedium];
    [controls.container addSubview:controls.sourceLabel];

    NSTextField *historyTitle = AudioLabel(@"LEVEL HISTORY", 8, NSFontWeightSemibold, AudioMuted());
    historyTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [controls.container addSubview:historyTitle];
    controls.history = [[ATEMAudioHistoryView alloc] initWithFrame:NSZeroRect];
    controls.history.translatesAutoresizingMaskIntoConstraints = NO;
    controls.history.accessibilityLabel =
        [NSString stringWithFormat:@"%@ rolling stereo level history", channelName];
    controls.history.toolTip =
        [NSString stringWithFormat:@"%@ rolling left/right dBFS level history.", channelName];
    [controls.container addSubview:controls.history];

    controls.meter = [[ATEMAudioMeterView alloc] initWithFrame:NSZeroRect];
    controls.meter.translatesAutoresizingMaskIntoConstraints = NO;
    controls.meter.accessibilityLabel =
        [NSString stringWithFormat:@"%@ live stereo audio meter", channelName];
    controls.meter.toolTip =
        [NSString stringWithFormat:@"%@ live left/right dBFS levels with peak hold.", channelName];
    [controls.container addSubview:controls.meter];

    controls.fader = [[ATEMAudioSourceSlider alloc] initWithFrame:NSZeroRect];
    controls.fader.translatesAutoresizingMaskIntoConstraints = NO;
    controls.fader.vertical = YES;
    controls.fader.minValue = -100;
    controls.fader.maxValue = 10;
    controls.fader.continuous = YES;
    controls.fader.trackFillColor = AudioCyan();
    controls.fader.inputID = channel.inputID;
    controls.fader.sourceID = channel.sourceID;
    controls.fader.target = self;
    controls.fader.action = @selector(channelFaderChanged:);
    controls.fader.accessibilityLabel = [NSString stringWithFormat:@"%@ fader", channelName];
    controls.fader.accessibilityHelp =
        [NSString stringWithFormat:@"Adjust %@ audio gain from minus infinity to plus 10 dB.", channelName];
    controls.fader.toolTip =
        [NSString stringWithFormat:@"Adjust %@ gain (−∞ to +10 dB).", channelName];
    [controls.container addSubview:controls.fader];

    controls.faderValue = AudioLabel(@"0.0 dB", 9.5, NSFontWeightSemibold, AudioText());
    controls.faderValue.translatesAutoresizingMaskIntoConstraints = NO;
    controls.faderValue.font = [NSFont monospacedDigitSystemFontOfSize:9.5 weight:NSFontWeightSemibold];
    controls.faderValue.alignment = NSTextAlignmentCenter;
    [controls.container addSubview:controls.faderValue];

    NSTextField *panTitle = AudioLabel(@"L        PAN        R", 8, NSFontWeightSemibold, AudioMuted());
    panTitle.translatesAutoresizingMaskIntoConstraints = NO;
    panTitle.alignment = NSTextAlignmentCenter;
    [controls.container addSubview:panTitle];

    controls.pan = [[ATEMAudioSourceSlider alloc] initWithFrame:NSZeroRect];
    controls.pan.translatesAutoresizingMaskIntoConstraints = NO;
    controls.pan.minValue = -1;
    controls.pan.maxValue = 1;
    controls.pan.continuous = YES;
    controls.pan.trackFillColor = AudioViolet();
    controls.pan.inputID = channel.inputID;
    controls.pan.sourceID = channel.sourceID;
    controls.pan.target = self;
    controls.pan.action = @selector(channelPanChanged:);
    controls.pan.accessibilityLabel = [NSString stringWithFormat:@"%@ pan", channelName];
    controls.pan.accessibilityHelp =
        [NSString stringWithFormat:@"Pan %@ between the left and right output channels.", channelName];
    controls.pan.toolTip =
        [NSString stringWithFormat:@"Pan %@ left or right.", channelName];
    [controls.container addSubview:controls.pan];

    controls.panValue = AudioLabel(@"CENTER", 8.5, NSFontWeightMedium, AudioText());
    controls.panValue.translatesAutoresizingMaskIntoConstraints = NO;
    controls.panValue.font = [NSFont monospacedDigitSystemFontOfSize:8.5 weight:NSFontWeightMedium];
    controls.panValue.alignment = NSTextAlignmentCenter;
    [controls.container addSubview:controls.panValue];

    NSTextField *mixTitle = AudioLabel(@"MIX MODE", 8, NSFontWeightSemibold, AudioMuted());
    mixTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [controls.container addSubview:mixTitle];
    controls.mix = [[ATEMAudioMixControl alloc] initWithFrame:NSZeroRect];
    controls.mix.translatesAutoresizingMaskIntoConstraints = NO;
    controls.mix.segmentCount = 3;
    [controls.mix setLabel:@"OFF" forSegment:0];
    [controls.mix setLabel:@"ON" forSegment:1];
    [controls.mix setLabel:@"AFV" forSegment:2];
    controls.mix.segmentStyle = NSSegmentStyleTexturedRounded;
    controls.mix.trackingMode = NSSegmentSwitchTrackingSelectOne;
    controls.mix.font = [NSFont systemFontOfSize:9 weight:NSFontWeightSemibold];
    controls.mix.inputID = channel.inputID;
    controls.mix.sourceID = channel.sourceID;
    controls.mix.target = self;
    controls.mix.action = @selector(channelMixChanged:);
    controls.mix.accessibilityLabel = [NSString stringWithFormat:@"%@ mix mode", channelName];
    controls.mix.accessibilityHelp =
        @"Choose Off, always On, or audio-follow-video for this source.";
    controls.mix.toolTip =
        [NSString stringWithFormat:@"Set %@ to Off, On, or audio-follow-video (AFV).", channelName];
    [controls.container addSubview:controls.mix];

    [NSLayoutConstraint activateConstraints:@[
        [controls.activeDot.leadingAnchor constraintEqualToAnchor:controls.container.leadingAnchor constant:13],
        [controls.activeDot.topAnchor constraintEqualToAnchor:controls.container.topAnchor constant:18],
        [controls.activeDot.widthAnchor constraintEqualToConstant:7],
        [controls.activeDot.heightAnchor constraintEqualToConstant:7],
        [title.leadingAnchor constraintEqualToAnchor:controls.activeDot.trailingAnchor constant:7],
        [title.trailingAnchor constraintEqualToAnchor:controls.container.trailingAnchor constant:-12],
        [title.centerYAnchor constraintEqualToAnchor:controls.activeDot.centerYAnchor],
        [controls.sourceLabel.leadingAnchor constraintEqualToAnchor:controls.container.leadingAnchor constant:13],
        [controls.sourceLabel.trailingAnchor constraintEqualToAnchor:controls.container.trailingAnchor constant:-10],
        [controls.sourceLabel.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:5],

        [historyTitle.leadingAnchor constraintEqualToAnchor:controls.container.leadingAnchor constant:13],
        [historyTitle.topAnchor constraintEqualToAnchor:controls.sourceLabel.bottomAnchor constant:11],
        [controls.history.leadingAnchor constraintEqualToAnchor:controls.container.leadingAnchor constant:12],
        [controls.history.trailingAnchor constraintEqualToAnchor:controls.container.trailingAnchor constant:-12],
        [controls.history.topAnchor constraintEqualToAnchor:historyTitle.bottomAnchor constant:4],
        [controls.history.heightAnchor constraintEqualToConstant:76],

        [controls.meter.leadingAnchor constraintEqualToAnchor:controls.container.leadingAnchor constant:13],
        [controls.meter.topAnchor constraintEqualToAnchor:controls.history.bottomAnchor constant:12],
        [controls.meter.widthAnchor constraintEqualToConstant:39],
        [controls.meter.heightAnchor constraintEqualToConstant:248],

        [controls.fader.leadingAnchor constraintEqualToAnchor:controls.meter.trailingAnchor constant:34],
        [controls.fader.topAnchor constraintEqualToAnchor:controls.meter.topAnchor],
        [controls.fader.widthAnchor constraintEqualToConstant:28],
        [controls.fader.heightAnchor constraintEqualToConstant:225],
        [controls.faderValue.centerXAnchor constraintEqualToAnchor:controls.fader.centerXAnchor],
        [controls.faderValue.topAnchor constraintEqualToAnchor:controls.fader.bottomAnchor constant:5],
        [controls.faderValue.widthAnchor constraintEqualToConstant:74],

        [panTitle.leadingAnchor constraintEqualToAnchor:controls.container.leadingAnchor constant:13],
        [panTitle.trailingAnchor constraintEqualToAnchor:controls.container.trailingAnchor constant:-13],
        [panTitle.topAnchor constraintEqualToAnchor:controls.meter.bottomAnchor constant:12],
        [controls.pan.leadingAnchor constraintEqualToAnchor:controls.container.leadingAnchor constant:13],
        [controls.pan.trailingAnchor constraintEqualToAnchor:controls.container.trailingAnchor constant:-13],
        [controls.pan.topAnchor constraintEqualToAnchor:panTitle.bottomAnchor constant:2],
        [controls.panValue.leadingAnchor constraintEqualToAnchor:controls.pan.leadingAnchor],
        [controls.panValue.trailingAnchor constraintEqualToAnchor:controls.pan.trailingAnchor],
        [controls.panValue.topAnchor constraintEqualToAnchor:controls.pan.bottomAnchor constant:2],

        [mixTitle.leadingAnchor constraintEqualToAnchor:controls.container.leadingAnchor constant:13],
        [mixTitle.topAnchor constraintEqualToAnchor:controls.panValue.bottomAnchor constant:10],
        [controls.mix.leadingAnchor constraintEqualToAnchor:controls.container.leadingAnchor constant:12],
        [controls.mix.trailingAnchor constraintEqualToAnchor:controls.container.trailingAnchor constant:-12],
        [controls.mix.topAnchor constraintEqualToAnchor:mixTitle.bottomAnchor constant:4],
        [controls.mix.heightAnchor constraintEqualToConstant:27],
    ]];
    return controls;
}

- (NSView *)buildMasterStrip
{
    NSView *container = [self newStripContainerWithWidth:190 accent:AudioViolet()];
    NSTextField *title = AudioLabel(@"MASTER", 13, NSFontWeightBold, AudioText());
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:title];
    NSTextField *source = AudioLabel(@"PROGRAM OUTPUT", 8.5, NSFontWeightMedium, AudioViolet());
    source.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:source];

    NSTextField *historyTitle = AudioLabel(@"MASTER HISTORY", 8, NSFontWeightSemibold, AudioMuted());
    historyTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:historyTitle];
    self.masterHistory = [[ATEMAudioHistoryView alloc] initWithFrame:NSZeroRect];
    self.masterHistory.translatesAutoresizingMaskIntoConstraints = NO;
    self.masterHistory.accessibilityLabel = @"Master rolling audio level history";
    self.masterHistory.toolTip = @"Rolling left/right dBFS history for the master program output.";
    [container addSubview:self.masterHistory];

    self.masterMeter = [[ATEMAudioMeterView alloc] initWithFrame:NSZeroRect];
    self.masterMeter.translatesAutoresizingMaskIntoConstraints = NO;
    self.masterMeter.accessibilityLabel = @"Master stereo audio meter";
    self.masterMeter.toolTip = @"Live master left/right dBFS levels with peak hold.";
    [container addSubview:self.masterMeter];

    self.masterFader = [[NSSlider alloc] initWithFrame:NSZeroRect];
    self.masterFader.translatesAutoresizingMaskIntoConstraints = NO;
    self.masterFader.vertical = YES;
    self.masterFader.minValue = -100;
    self.masterFader.maxValue = 10;
    self.masterFader.continuous = YES;
    self.masterFader.trackFillColor = AudioViolet();
    self.masterFader.target = self;
    self.masterFader.action = @selector(masterFaderChanged:);
    self.masterFader.accessibilityLabel = @"Master output fader";
    self.masterFader.accessibilityHelp =
        @"Adjust the active ATEM's master program output from minus infinity to plus 10 dB.";
    self.masterFader.toolTip = @"Adjust master program output gain (−∞ to +10 dB).";
    [container addSubview:self.masterFader];

    self.masterFaderValue = AudioLabel(@"0.0 dB", 10, NSFontWeightSemibold, AudioText());
    self.masterFaderValue.translatesAutoresizingMaskIntoConstraints = NO;
    self.masterFaderValue.font = [NSFont monospacedDigitSystemFontOfSize:10 weight:NSFontWeightSemibold];
    self.masterFaderValue.alignment = NSTextAlignmentCenter;
    [container addSubview:self.masterFaderValue];

    NSTextField *legend = AudioLabel(@"L     LIVE LEVEL     R", 8, NSFontWeightSemibold, AudioMuted());
    legend.translatesAutoresizingMaskIntoConstraints = NO;
    legend.alignment = NSTextAlignmentCenter;
    [container addSubview:legend];
    NSTextField *note = AudioLabel(@"Peak hold is cleared with RESET PEAKS in the header.", 9,
                                   NSFontWeightRegular, AudioMuted());
    note.translatesAutoresizingMaskIntoConstraints = NO;
    note.maximumNumberOfLines = 3;
    note.lineBreakMode = NSLineBreakByWordWrapping;
    note.alignment = NSTextAlignmentCenter;
    [container addSubview:note];

    [NSLayoutConstraint activateConstraints:@[
        [title.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:14],
        [title.topAnchor constraintEqualToAnchor:container.topAnchor constant:15],
        [source.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [source.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:5],

        [historyTitle.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:14],
        [historyTitle.topAnchor constraintEqualToAnchor:source.bottomAnchor constant:12],
        [self.masterHistory.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:13],
        [self.masterHistory.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-13],
        [self.masterHistory.topAnchor constraintEqualToAnchor:historyTitle.bottomAnchor constant:4],
        [self.masterHistory.heightAnchor constraintEqualToConstant:76],

        [self.masterMeter.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:18],
        [self.masterMeter.topAnchor constraintEqualToAnchor:self.masterHistory.bottomAnchor constant:12],
        [self.masterMeter.widthAnchor constraintEqualToConstant:44],
        [self.masterMeter.heightAnchor constraintEqualToConstant:280],

        [self.masterFader.leadingAnchor constraintEqualToAnchor:self.masterMeter.trailingAnchor constant:38],
        [self.masterFader.topAnchor constraintEqualToAnchor:self.masterMeter.topAnchor],
        [self.masterFader.widthAnchor constraintEqualToConstant:30],
        [self.masterFader.heightAnchor constraintEqualToConstant:250],
        [self.masterFaderValue.centerXAnchor constraintEqualToAnchor:self.masterFader.centerXAnchor],
        [self.masterFaderValue.topAnchor constraintEqualToAnchor:self.masterFader.bottomAnchor constant:6],
        [self.masterFaderValue.widthAnchor constraintEqualToConstant:78],

        [legend.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:13],
        [legend.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-13],
        [legend.topAnchor constraintEqualToAnchor:self.masterMeter.bottomAnchor constant:12],
        [note.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:17],
        [note.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-17],
        [note.topAnchor constraintEqualToAnchor:legend.bottomAnchor constant:10],
    ]];
    return container;
}

- (NSView *)buildUnavailableStrip:(NSString *)message
{
    NSView *container = [self newStripContainerWithWidth:410 accent:AudioMuted()];
    NSTextField *title = AudioLabel(@"AUDIO MIXER UNAVAILABLE", 14, NSFontWeightSemibold, AudioText());
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [container addSubview:title];
    NSTextField *body = AudioLabel(message.length ? message : @"Connect an ATEM with Fairlight audio support.",
                                   12, NSFontWeightRegular, AudioMuted());
    body.translatesAutoresizingMaskIntoConstraints = NO;
    body.maximumNumberOfLines = 0;
    body.lineBreakMode = NSLineBreakByWordWrapping;
    body.alignment = NSTextAlignmentCenter;
    [container addSubview:body];
    [NSLayoutConstraint activateConstraints:@[
        [title.centerXAnchor constraintEqualToAnchor:container.centerXAnchor],
        [title.centerYAnchor constraintEqualToAnchor:container.centerYAnchor constant:-24],
        [body.leadingAnchor constraintEqualToAnchor:container.leadingAnchor constant:38],
        [body.trailingAnchor constraintEqualToAnchor:container.trailingAnchor constant:-38],
        [body.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:14],
    ]];
    return container;
}

- (void)rebuildMixerForState:(ATEMAudioState *)state
{
    [self removeAllMixerSubviews];
    if (!state.isAvailable) {
        [self.mixerRow addArrangedSubview:[self buildUnavailableStrip:state.statusMessage]];
        return;
    }

    for (ATEMAudioChannelState *channel in state.channels) {
        ATEMAudioChannelControls *controls = [self buildChannelStrip:channel];
        self.channelControls[[self channelKeyForInput:channel.inputID source:channel.sourceID]] = controls;
        [self.mixerRow addArrangedSubview:controls.container];
    }
    [self.mixerRow addArrangedSubview:[self buildMasterStrip]];
}

- (NSInteger)segmentForMixOption:(ATEMAudioMixOption)mixOption
{
    switch (mixOption) {
        case ATEMAudioMixOptionOn:
            return 1;
        case ATEMAudioMixOptionAudioFollowVideo:
            return 2;
        case ATEMAudioMixOptionOff:
        default:
            return 0;
    }
}

- (NSString *)panString:(double)pan
{
    if (fabs(pan) < 0.005)
        return @"CENTER";
    return [NSString stringWithFormat:@"%@ %d",
            pan < 0 ? @"L" : @"R", (int)lround(fabs(pan) * 100.0)];
}

- (NSString *)activeSessionName
{
    return self.activeSessionIndex == 0 ? @"ATEM A" : @"ATEM B";
}

- (NSString *)activeTargetEndpoint
{
    ATEMState *switcherState = self.activeController.latestState;
    if (switcherState.isDemo)
        return @"DEMO TARGET";
    NSString *address = self.activeController.currentAddress;
    return address.length ? [NSString stringWithFormat:@"IP %@", address] : @"NO IP TARGET";
}

- (NSString *)activeTargetIdentity
{
    ATEMState *switcherState = self.activeController.latestState;
    NSString *productName = switcherState.productName;
    if (!productName.length)
        productName = switcherState.isConnecting ? @"Connecting…" : @"No switcher connected";
    return [NSString stringWithFormat:@"%@ · %@ · %@",
            [self activeSessionName], productName, [self activeTargetEndpoint]];
}

- (void)applyAudioState:(ATEMAudioState *)state
{
    NSAssert(NSThread.isMainThread, @"Audio UI updates must run on the main thread");
    if (!state)
        return;

    NSString *signature = [self signatureForAudioState:state];
    if (![signature isEqualToString:self.channelSignature]) {
        self.channelSignature = signature;
        [self rebuildMixerForState:state];
    }

    NSString *targetIdentity = [self activeTargetIdentity];
    self.targetLabel.stringValue = targetIdentity;
    self.targetLabel.toolTip = targetIdentity;
    self.targetLabel.accessibilityValue = targetIdentity;
    self.statusLabel.stringValue = state.statusMessage ?: @"";
    self.statusLabel.toolTip = state.statusMessage ?: @"";
    self.statusLabel.textColor = state.isAvailable ? AudioText() : AudioMuted();
    self.statusDot.layer.backgroundColor = (state.isDemo ? AudioViolet() :
                                            (state.isAvailable ? AudioGreen() : AudioMuted())).CGColor;
    self.resetPeaksButton.enabled = state.isAvailable;
    self.resetPeaksButton.toolTip =
        [NSString stringWithFormat:@"Clear held audio peaks on %@.", targetIdentity];
    self.resetPeaksButton.accessibilityHelp = self.resetPeaksButton.toolTip;
    self.sessionSelector.accessibilityValue = targetIdentity;


    for (ATEMAudioChannelState *channel in state.channels) {
        ATEMAudioChannelControls *controls =
            self.channelControls[[self channelKeyForInput:channel.inputID source:channel.sourceID]];
        if (!controls)
            continue;
        controls.activeDot.layer.backgroundColor = (channel.isActive ? AudioGreen() : AudioMuted()).CGColor;
        controls.fader.doubleValue = MAX(controls.fader.minValue,
                                         MIN(controls.fader.maxValue, channel.faderGain));
        controls.faderValue.stringValue = AudioGainString(channel.faderGain);
        controls.fader.accessibilityValueDescription = AudioGainString(channel.faderGain);
        controls.pan.doubleValue = MAX(-1.0, MIN(1.0, channel.pan));
        controls.panValue.stringValue = [self panString:channel.pan];
        controls.pan.accessibilityValueDescription = [self panString:channel.pan];
        controls.mix.selectedSegment = [self segmentForMixOption:channel.mixOption];
        [controls.mix setEnabled:(channel.supportedMixOptions & ATEMAudioMixOptionOff) != 0 forSegment:0];
        [controls.mix setEnabled:(channel.supportedMixOptions & ATEMAudioMixOptionOn) != 0 forSegment:1];
        [controls.mix setEnabled:(channel.supportedMixOptions & ATEMAudioMixOptionAudioFollowVideo) != 0 forSegment:2];
        controls.fader.enabled = state.isAvailable;
        controls.pan.enabled = state.isAvailable;
        controls.mix.enabled = state.isAvailable;
        [controls.meter setLevels:channel.levels peakLevels:channel.peakLevels];
        [controls.history appendLevels:channel.levels];
    }

    if (self.masterFader) {
        self.masterFader.enabled = state.isAvailable;
        self.masterFader.doubleValue = MAX(self.masterFader.minValue,
                                           MIN(self.masterFader.maxValue, state.masterFaderGain));
        self.masterFaderValue.stringValue = AudioGainString(state.masterFaderGain);
        self.masterFader.accessibilityValueDescription = AudioGainString(state.masterFaderGain);
        [self.masterMeter setLevels:state.masterLevels peakLevels:state.masterPeakLevels];
        [self.masterHistory appendLevels:state.masterLevels];
    }
}

- (void)updateSessionSelector
{
    [self.controllers enumerateObjectsUsingBlock:^(ATEMController *controller, NSUInteger index, BOOL *stop) {
        (void)stop;
        ATEMState *state = controller.latestState;
        NSString *indicator = state.isDemo ? @"◆" : (state.isConnected ? @"●" : (state.isConnecting ? @"…" : @"○"));
        NSString *letter = index == 0 ? @"A" : @"B";
        [self.sessionSelector setLabel:[NSString stringWithFormat:@"ATEM %@  %@", letter, indicator]
                           forSegment:index];
    }];
    self.sessionSelector.selectedSegment = self.activeSessionIndex;
}

- (void)refreshSessionState
{
    [self updateSessionSelector];
    [self applyAudioState:self.activeController.latestAudioState];
}

- (void)audioStateDidChange:(NSNotification *)notification
{
    ATEMController *controller = (ATEMController *)notification.object;
    NSUInteger index = [self.controllers indexOfObjectIdenticalTo:controller];
    if (index == NSNotFound)
        return;
    if (!NSThread.isMainThread) {
        __weak AudioWindowController *weakSelf = self;
        dispatch_async(dispatch_get_main_queue(), ^{
            [weakSelf audioStateDidChange:notification];
        });
        return;
    }
    [self updateSessionSelector];
    if (index == self.activeSessionIndex)
        [self applyAudioState:controller.latestAudioState];
}

- (void)sessionChanged:(NSSegmentedControl *)sender
{
    NSInteger selected = sender.selectedSegment;
    if (selected < 0 || (NSUInteger)selected >= self.controllers.count)
        return;
    if ((NSUInteger)selected == self.activeSessionIndex)
        return;
    self.activeSessionIndex = (NSUInteger)selected;
    self.channelSignature = nil;
    [self refreshSessionState];
}

- (void)selectSessionIndex:(NSUInteger)sessionIndex
{
    if (sessionIndex >= self.controllers.count || sessionIndex == self.activeSessionIndex)
        return;
    self.sessionSelector.selectedSegment = (NSInteger)sessionIndex;
    [self sessionChanged:self.sessionSelector];
}

- (void)channelFaderChanged:(ATEMAudioSourceSlider *)sender
{
    ATEMAudioChannelControls *controls =
        self.channelControls[[self channelKeyForInput:sender.inputID source:sender.sourceID]];
    controls.faderValue.stringValue = AudioGainString(sender.doubleValue);
    sender.accessibilityValueDescription = AudioGainString(sender.doubleValue);
    [self.activeController setAudioInput:sender.inputID
                                  source:sender.sourceID
                               faderGain:sender.doubleValue];
}

- (void)channelPanChanged:(ATEMAudioSourceSlider *)sender
{
    ATEMAudioChannelControls *controls =
        self.channelControls[[self channelKeyForInput:sender.inputID source:sender.sourceID]];
    controls.panValue.stringValue = [self panString:sender.doubleValue];
    sender.accessibilityValueDescription = [self panString:sender.doubleValue];
    [self.activeController setAudioInput:sender.inputID
                                  source:sender.sourceID
                                     pan:sender.doubleValue];
}

- (void)channelMixChanged:(ATEMAudioMixControl *)sender
{
    ATEMAudioMixOption option = ATEMAudioMixOptionOff;
    if (sender.selectedSegment == 1)
        option = ATEMAudioMixOptionOn;
    else if (sender.selectedSegment == 2)
        option = ATEMAudioMixOptionAudioFollowVideo;
    [self.activeController setAudioInput:sender.inputID
                                  source:sender.sourceID
                               mixOption:option];
}

- (void)masterFaderChanged:(NSSlider *)sender
{
    self.masterFaderValue.stringValue = AudioGainString(sender.doubleValue);
    sender.accessibilityValueDescription = AudioGainString(sender.doubleValue);
    [self.activeController setAudioMasterFaderGain:sender.doubleValue];
}

- (void)resetPeaksPressed:(id)sender
{
    (void)sender;
    [self.activeController resetAudioPeakLevels];
}

@end

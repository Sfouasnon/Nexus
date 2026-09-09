#import "ColorWindowController.h"

#import "ATEMController.h"

#include <signal.h>
#include <unistd.h>

static NSColor *ColorCanvas(void) { return [NSColor colorWithRed:0.035 green:0.053 blue:0.074 alpha:1]; }
static NSColor *ColorPanel(void) { return [NSColor colorWithRed:0.065 green:0.090 blue:0.120 alpha:1]; }
static NSColor *ColorBorder(void) { return [NSColor colorWithRed:0.16 green:0.22 blue:0.28 alpha:1]; }
static NSColor *ColorText(void) { return [NSColor colorWithWhite:0.94 alpha:1]; }
static NSColor *ColorMuted(void) { return [NSColor colorWithWhite:0.60 alpha:1]; }
static NSColor *ColorCyan(void) { return [NSColor colorWithRed:0.13 green:0.82 blue:0.91 alpha:1]; }
static NSColor *ColorViolet(void) { return [NSColor colorWithRed:0.58 green:0.44 blue:0.96 alpha:1]; }

static NSTextField *ColorLabel(NSString *text, CGFloat size, NSFontWeight weight, NSColor *color)
{
    NSTextField *label = [NSTextField labelWithString:text];
    label.font = [NSFont systemFontOfSize:size weight:weight];
    label.textColor = color;
    return label;
}

static NSButton *ColorButton(NSString *title, id target, SEL action)
{
    NSButton *button = [NSButton buttonWithTitle:title target:target action:action];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.bezelStyle = NSBezelStyleTexturedRounded;
    button.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
    button.contentTintColor = ColorText();
    return button;
}

@interface ColorWindowController () <NSWindowDelegate>
@property(nonatomic, copy) NSArray<ATEMController *> *controllers;
@property(nonatomic) NSUInteger activeSessionIndex;
@property(nonatomic, strong) NSSegmentedControl *sessionSelector;
@property(nonatomic, strong) NSPopUpButton *cameraPopup;
@property(nonatomic, strong) NSTextField *statusLabel;
@property(nonatomic, strong) NSView *statusDot;
@property(nonatomic, strong) NSButton *engineButton;
@property(nonatomic, strong) NSArray<NSArray<NSSlider *> *> *stageSliders;
@property(nonatomic, strong) NSArray<NSArray<NSTextField *> *> *valueLabels;
@property(nonatomic, strong) NSDictionary<NSNumber *, NSArray<NSSlider *> *> *secondarySliders;
@property(nonatomic, strong) NSDictionary<NSNumber *, NSArray<NSTextField *> *> *secondaryValueLabels;
@property(nonatomic, strong) NSArray<NSButton *> *resetButtons;
@property(nonatomic, strong, nullable) NSTask *helperTask;
@property(nonatomic, strong, nullable) NSFileHandle *helperInput;
@property(nonatomic, strong, nullable) NSFileHandle *helperOutput;
@property(nonatomic, strong) NSMutableData *helperBuffer;
@property(nonatomic) BOOL helperReady;
@property(nonatomic) NSUInteger helperGeneration;
@property(nonatomic, copy) NSString *helperAddress;
@property(nonatomic, strong) dispatch_queue_t helperWriteQueue;
@property(nonatomic, strong) NSMutableDictionary<NSString *, NSDictionary *> *pendingHelperCommands;
@property(nonatomic, strong) NSMutableArray<NSString *> *pendingHelperCommandKeys;
@property(nonatomic, strong, nullable) NSDictionary *activeHelperCommand;
@property(nonatomic) BOOL helperWriteInFlight;
@property(nonatomic) NSUInteger helperCommandGeneration;
@property(nonatomic, strong) NSMutableIndexSet *pendingColorParameters;
@property(nonatomic) NSUInteger colorLoadGeneration;
@property(nonatomic) NSUInteger loadingCameraID;
@property(nonatomic) BOOL colorReadbackInProgress;
@end

@implementation ColorWindowController

- (instancetype)initWithControllers:(NSArray<ATEMController *> *)controllers
                 initialSessionIndex:(NSUInteger)sessionIndex
{
    NSParameterAssert(controllers.count == 2);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1080, 720)
                                                  styleMask:(NSWindowStyleMaskTitled |
                                                             NSWindowStyleMaskClosable |
                                                             NSWindowStyleMaskMiniaturizable |
                                                             NSWindowStyleMaskResizable)
                                                    backing:NSBackingStoreBuffered
                                                      defer:NO];
    window.title = @"Camera Color — ATEM CNTRL";
    window.minSize = NSMakeSize(900, 620);
    window.backgroundColor = ColorCanvas();
    window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    window.tabbingMode = NSWindowTabbingModeDisallowed;
    [window center];
    [window setFrameAutosaveName:@"ATEMCNTRLColorWindow"];

    self = [super initWithWindow:window];
    if (self) {
        _controllers = [controllers copy];
        _activeSessionIndex = MIN(sessionIndex, controllers.count - 1);
        _helperBuffer = [NSMutableData data];
        _helperAddress = @"";
        _helperWriteQueue = dispatch_queue_create("com.local.atem-cntrl.camera-ipc", DISPATCH_QUEUE_SERIAL);
        _pendingHelperCommands = [NSMutableDictionary dictionary];
        _pendingHelperCommandKeys = [NSMutableArray array];
        _pendingColorParameters = [NSMutableIndexSet indexSet];
        window.delegate = self;
        [self buildInterface];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(controllerStateChanged:)
                                                     name:ATEMStateDidChangeNotification
                                                   object:nil];
        [self setControlsEnabled:NO];
        [self refreshSessionState];
    }
    return self;
}

- (ATEMController *)activeController
{
    return self.controllers[self.activeSessionIndex];
}

- (NSString *)targetIdentity
{
    ATEMController *controller = self.activeController;
    ATEMState *state = controller.latestState;
    NSString *session = self.activeSessionIndex == 0 ? @"ATEM A" : @"ATEM B";
    NSString *product = state.productName.length ? state.productName : @"ATEM";
    if (state.isDemo)
        return [NSString stringWithFormat:@"%@ · %@ · DEMO TARGET", session, product];
    NSString *address = self.helperAddress.length ? self.helperAddress : controller.currentAddress;
    if (address.length == 0)
        address = @"NO IP TARGET";
    else
        address = [NSString stringWithFormat:@"IP %@", address];
    return [NSString stringWithFormat:@"%@ · %@ · %@", session, product, address];
}

- (void)setStatusDetail:(NSString *)detail color:(NSColor *)color
{
    self.statusDot.layer.backgroundColor = color.CGColor;
    self.statusLabel.stringValue = [NSString stringWithFormat:@"%@  •  %@",
                                    [self targetIdentity],
                                    detail ?: @""];
}

- (void)buildInterface
{
    NSView *root = [[NSView alloc] initWithFrame:self.window.contentView.bounds];
    root.translatesAutoresizingMaskIntoConstraints = NO;
    root.wantsLayer = YES;
    root.layer.backgroundColor = ColorCanvas().CGColor;
    self.window.contentView = root;

    NSView *header = [[NSView alloc] initWithFrame:NSZeroRect];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.wantsLayer = YES;
    header.layer.backgroundColor = [NSColor colorWithRed:0.045 green:0.067 blue:0.091 alpha:1].CGColor;
    header.layer.borderColor = ColorBorder().CGColor;
    header.layer.borderWidth = 1;
    [root addSubview:header];

    NSTextField *title = ColorLabel(@"CAMERA / COLOR", 20, NSFontWeightSemibold, ColorText());
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:title];
    NSTextField *subtitle = ColorLabel(@"Isolated, restartable camera-control engine", 10, NSFontWeightMedium, ColorMuted());
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:subtitle];

    self.sessionSelector = [NSSegmentedControl segmentedControlWithLabels:@[@"ATEM A", @"ATEM B"]
                                                               trackingMode:NSSegmentSwitchTrackingSelectOne
                                                                     target:self
                                                                     action:@selector(sessionChanged:)];
    self.sessionSelector.translatesAutoresizingMaskIntoConstraints = NO;
    self.sessionSelector.segmentStyle = NSSegmentStyleCapsule;
    self.sessionSelector.selectedSegment = self.activeSessionIndex;
    self.sessionSelector.toolTip = @"Select which ATEM this color window controls.";
    self.sessionSelector.accessibilityLabel = @"Color control target ATEM";
    [header addSubview:self.sessionSelector];

    self.cameraPopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    self.cameraPopup.translatesAutoresizingMaskIntoConstraints = NO;
    self.cameraPopup.target = self;
    self.cameraPopup.action = @selector(cameraChanged:);
    self.cameraPopup.toolTip = @"Select the camera number to color-correct.";
    self.cameraPopup.accessibilityLabel = @"Camera to color-correct";
    [header addSubview:self.cameraPopup];

    self.engineButton = ColorButton(@"START ISOLATED ENGINE", self, @selector(enginePressed:));
    self.engineButton.contentTintColor = ColorCyan();
    self.engineButton.toolTip = @"Start or stop the isolated Blackmagic camera-control process.";
    self.engineButton.accessibilityLabel = @"Isolated camera-control engine";
    [header addSubview:self.engineButton];

    self.statusDot = [[NSView alloc] initWithFrame:NSZeroRect];
    self.statusDot.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusDot.wantsLayer = YES;
    self.statusDot.layer.cornerRadius = 4;
    self.statusDot.layer.backgroundColor = ColorMuted().CGColor;
    [header addSubview:self.statusDot];
    self.statusLabel = ColorLabel(@"Camera control is stopped.", 10.5, NSFontWeightRegular, ColorMuted());
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    self.statusLabel.accessibilityLabel = @"Color control status";
    [header addSubview:self.statusLabel];

    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.drawsBackground = NO;
    scroll.hasVerticalScroller = YES;
    scroll.autohidesScrollers = YES;
    [root addSubview:scroll];
    NSView *document = [[NSView alloc] initWithFrame:NSZeroRect];
    document.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.documentView = document;
    NSStackView *stages = [[NSStackView alloc] initWithFrame:NSZeroRect];
    stages.translatesAutoresizingMaskIntoConstraints = NO;
    stages.orientation = NSUserInterfaceLayoutOrientationVertical;
    stages.alignment = NSLayoutAttributeLeading;
    stages.spacing = 12;
    stages.edgeInsets = NSEdgeInsetsMake(16, 16, 18, 16);
    [document addSubview:stages];

    NSArray<NSString *> *stageNames = @[@"LIFT", @"GAMMA", @"GAIN", @"OFFSET"];
    NSArray<NSNumber *> *minimums = @[@(-2.0), @(-4.0), @(0.0), @(-8.0)];
    NSArray<NSNumber *> *maximums = @[@(2.0), @(4.0), @(15.9995), @(8.0)];
    NSArray<NSString *> *rangeStrings = @[@"-2 … 2", @"-4 … 4", @"0 … 16", @"-8 … 8"];
    NSArray<NSString *> *componentNames = @[@"RED", @"GREEN", @"BLUE", @"LUMA"];
    NSArray<NSColor *> *componentColors = @[
        [NSColor colorWithRed:1 green:0.33 blue:0.29 alpha:1],
        [NSColor colorWithRed:0.31 green:0.88 blue:0.52 alpha:1],
        [NSColor colorWithRed:0.31 green:0.61 blue:1 alpha:1],
        ColorCyan(),
    ];
    NSMutableArray *sliderStages = [NSMutableArray array];
    NSMutableArray *labelStages = [NSMutableArray array];
    NSMutableArray<NSButton *> *resetButtons = [NSMutableArray array];
    for (NSUInteger stageIndex = 0; stageIndex < stageNames.count; ++stageIndex) {
        NSView *card = [[NSView alloc] initWithFrame:NSZeroRect];
        card.translatesAutoresizingMaskIntoConstraints = NO;
        card.wantsLayer = YES;
        card.layer.backgroundColor = ColorPanel().CGColor;
        card.layer.borderColor = ColorBorder().CGColor;
        card.layer.borderWidth = 1;
        card.layer.cornerRadius = 10;
        [stages addArrangedSubview:card];
        [card.widthAnchor constraintEqualToAnchor:stages.widthAnchor constant:-32].active = YES;
        [card.heightAnchor constraintEqualToConstant:126].active = YES;

        NSTextField *stageTitle = ColorLabel(stageNames[stageIndex], 12, NSFontWeightBold,
                                            stageIndex == 2 ? ColorCyan() : ColorViolet());
        stageTitle.translatesAutoresizingMaskIntoConstraints = NO;
        [card addSubview:stageTitle];
        NSTextField *range = ColorLabel(rangeStrings[stageIndex],
                                       9, NSFontWeightRegular, ColorMuted());
        range.translatesAutoresizingMaskIntoConstraints = NO;
        [card addSubview:range];

        NSStackView *componentRow = [[NSStackView alloc] initWithFrame:NSZeroRect];
        componentRow.translatesAutoresizingMaskIntoConstraints = NO;
        componentRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        componentRow.distribution = NSStackViewDistributionFillEqually;
        componentRow.alignment = NSLayoutAttributeCenterY;
        componentRow.spacing = 14;
        [card addSubview:componentRow];

        NSMutableArray *stageSliderArray = [NSMutableArray array];
        NSMutableArray *stageLabelArray = [NSMutableArray array];
        for (NSUInteger component = 0; component < componentNames.count; ++component) {
            NSStackView *column = [[NSStackView alloc] initWithFrame:NSZeroRect];
            column.orientation = NSUserInterfaceLayoutOrientationVertical;
            column.alignment = NSLayoutAttributeLeading;
            column.spacing = 5;
            NSTextField *name = ColorLabel(componentNames[component], 9, NSFontWeightSemibold,
                                           componentColors[component]);
            [column addArrangedSubview:name];
            NSSlider *slider = [NSSlider sliderWithValue:(stageIndex == 2 ? 1.0 : 0.0)
                                                minValue:minimums[stageIndex].doubleValue
                                                maxValue:maximums[stageIndex].doubleValue
                                                  target:self
                                                  action:@selector(colorSliderChanged:)];
            slider.continuous = YES;
            slider.tag = (NSInteger)(stageIndex * 10 + component);
            slider.trackFillColor = componentColors[component];
            slider.accessibilityLabel = [NSString stringWithFormat:@"%@ %@ color control",
                                         stageNames[stageIndex],
                                         componentNames[component]];
            slider.toolTip = [NSString stringWithFormat:@"%@ %@ (%@)",
                              stageNames[stageIndex],
                              componentNames[component],
                              rangeStrings[stageIndex]];
            [column addArrangedSubview:slider];
            [slider.widthAnchor constraintGreaterThanOrEqualToConstant:120].active = YES;
            NSTextField *value = ColorLabel([NSString stringWithFormat:@"%.3f", slider.doubleValue],
                                            10, NSFontWeightMedium, ColorText());
            value.font = [NSFont monospacedDigitSystemFontOfSize:10 weight:NSFontWeightMedium];
            [column addArrangedSubview:value];
            [componentRow addArrangedSubview:column];
            [stageSliderArray addObject:slider];
            [stageLabelArray addObject:value];
        }
        [sliderStages addObject:stageSliderArray];
        [labelStages addObject:stageLabelArray];

        NSButton *reset = ColorButton(@"RESET", self, @selector(resetStage:));
        reset.tag = stageIndex;
        reset.accessibilityLabel = [NSString stringWithFormat:@"Reset %@ color controls",
                                    stageNames[stageIndex]];
        reset.toolTip = [NSString stringWithFormat:@"Reset all %@ components to their defaults.",
                         stageNames[stageIndex].lowercaseString];
        [card addSubview:reset];
        [resetButtons addObject:reset];
        [NSLayoutConstraint activateConstraints:@[
            [stageTitle.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:17],
            [stageTitle.topAnchor constraintEqualToAnchor:card.topAnchor constant:17],
            [range.leadingAnchor constraintEqualToAnchor:stageTitle.leadingAnchor],
            [range.topAnchor constraintEqualToAnchor:stageTitle.bottomAnchor constant:5],
            [reset.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:15],
            [reset.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-15],
            [reset.widthAnchor constraintEqualToConstant:72],
            [componentRow.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:112],
            [componentRow.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],
            [componentRow.topAnchor constraintEqualToAnchor:card.topAnchor constant:14],
            [componentRow.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-12],
        ]];
    }
    self.stageSliders = sliderStages;
    self.valueLabels = labelStages;
    self.resetButtons = resetButtons;

    NSView *finishingCard = [[NSView alloc] initWithFrame:NSZeroRect];
    finishingCard.translatesAutoresizingMaskIntoConstraints = NO;
    finishingCard.wantsLayer = YES;
    finishingCard.layer.backgroundColor = ColorPanel().CGColor;
    finishingCard.layer.borderColor = ColorBorder().CGColor;
    finishingCard.layer.borderWidth = 1;
    finishingCard.layer.cornerRadius = 10;
    [stages addArrangedSubview:finishingCard];
    [finishingCard.widthAnchor constraintEqualToAnchor:stages.widthAnchor constant:-32].active = YES;
    [finishingCard.heightAnchor constraintEqualToConstant:142].active = YES;
    NSTextField *finishingTitle = ColorLabel(@"FINISHING", 12, NSFontWeightBold, ColorCyan());
    finishingTitle.translatesAutoresizingMaskIntoConstraints = NO;
    [finishingCard addSubview:finishingTitle];
    NSTextField *finishingSubtitle = ColorLabel(@"CONTRAST · LUMA MIX · COLOR", 8.5, NSFontWeightSemibold, ColorMuted());
    finishingSubtitle.translatesAutoresizingMaskIntoConstraints = NO;
    [finishingCard addSubview:finishingSubtitle];
    NSButton *resetAll = ColorButton(@"RESET ALL", self, @selector(resetAllColor:));
    resetAll.accessibilityLabel = @"Reset all camera color controls";
    resetAll.toolTip = @"Reset lift, gamma, gain, offset, contrast, luma mix, hue, and saturation.";
    [finishingCard addSubview:resetAll];
    [resetButtons addObject:resetAll];
    self.resetButtons = resetButtons;

    NSStackView *finishingRow = [[NSStackView alloc] initWithFrame:NSZeroRect];
    finishingRow.translatesAutoresizingMaskIntoConstraints = NO;
    finishingRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    finishingRow.distribution = NSStackViewDistributionFillEqually;
    finishingRow.alignment = NSLayoutAttributeCenterY;
    finishingRow.spacing = 12;
    [finishingCard addSubview:finishingRow];
    NSArray<NSDictionary *> *finishingControls = @[
        @{@"name": @"PIVOT", @"parameter": @4, @"component": @0, @"min": @0.0, @"max": @1.0, @"default": @0.5},
        @{@"name": @"CONTRAST", @"parameter": @4, @"component": @1, @"min": @0.0, @"max": @2.0, @"default": @1.0},
        @{@"name": @"LUMA MIX", @"parameter": @5, @"component": @0, @"min": @0.0, @"max": @1.0, @"default": @1.0},
        @{@"name": @"HUE", @"parameter": @6, @"component": @0, @"min": @(-1.0), @"max": @1.0, @"default": @0.0},
        @{@"name": @"SATURATION", @"parameter": @6, @"component": @1, @"min": @0.0, @"max": @2.0, @"default": @1.0},
    ];
    NSMutableDictionary<NSNumber *, NSMutableArray<NSSlider *> *> *secondarySliders = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSNumber *, NSMutableArray<NSTextField *> *> *secondaryLabels = [NSMutableDictionary dictionary];
    for (NSDictionary *definition in finishingControls) {
        NSNumber *parameter = definition[@"parameter"];
        if (!secondarySliders[parameter])
            secondarySliders[parameter] = [NSMutableArray array];
        if (!secondaryLabels[parameter])
            secondaryLabels[parameter] = [NSMutableArray array];
        NSStackView *column = [[NSStackView alloc] initWithFrame:NSZeroRect];
        column.orientation = NSUserInterfaceLayoutOrientationVertical;
        column.alignment = NSLayoutAttributeLeading;
        column.spacing = 5;
        NSTextField *name = ColorLabel(definition[@"name"], 9, NSFontWeightSemibold, ColorCyan());
        [column addArrangedSubview:name];
        NSSlider *slider = [NSSlider sliderWithValue:[definition[@"default"] doubleValue]
                                            minValue:[definition[@"min"] doubleValue]
                                            maxValue:[definition[@"max"] doubleValue]
                                              target:self
                                              action:@selector(secondarySliderChanged:)];
        slider.continuous = YES;
        slider.tag = parameter.integerValue * 10 + [definition[@"component"] integerValue];
        slider.trackFillColor = ColorCyan();
        slider.accessibilityLabel = [NSString stringWithFormat:@"%@ color control", definition[@"name"]];
        slider.toolTip = [NSString stringWithFormat:@"Adjust %@ for the selected camera.",
                          [definition[@"name"] lowercaseString]];
        [column addArrangedSubview:slider];
        [slider.widthAnchor constraintGreaterThanOrEqualToConstant:100].active = YES;
        NSTextField *value = ColorLabel([NSString stringWithFormat:@"%.3f", slider.doubleValue],
                                        10, NSFontWeightMedium, ColorText());
        value.font = [NSFont monospacedDigitSystemFontOfSize:10 weight:NSFontWeightMedium];
        [column addArrangedSubview:value];
        [finishingRow addArrangedSubview:column];
        [secondarySliders[parameter] addObject:slider];
        [secondaryLabels[parameter] addObject:value];
    }
    self.secondarySliders = secondarySliders;
    self.secondaryValueLabels = secondaryLabels;
    [NSLayoutConstraint activateConstraints:@[
        [finishingTitle.leadingAnchor constraintEqualToAnchor:finishingCard.leadingAnchor constant:17],
        [finishingTitle.topAnchor constraintEqualToAnchor:finishingCard.topAnchor constant:17],
        [finishingSubtitle.leadingAnchor constraintEqualToAnchor:finishingTitle.leadingAnchor],
        [finishingSubtitle.topAnchor constraintEqualToAnchor:finishingTitle.bottomAnchor constant:4],
        [resetAll.leadingAnchor constraintEqualToAnchor:finishingCard.leadingAnchor constant:15],
        [resetAll.bottomAnchor constraintEqualToAnchor:finishingCard.bottomAnchor constant:-15],
        [resetAll.widthAnchor constraintEqualToConstant:82],
        [finishingRow.leadingAnchor constraintEqualToAnchor:finishingCard.leadingAnchor constant:112],
        [finishingRow.trailingAnchor constraintEqualToAnchor:finishingCard.trailingAnchor constant:-18],
        [finishingRow.topAnchor constraintEqualToAnchor:finishingCard.topAnchor constant:14],
        [finishingRow.bottomAnchor constraintEqualToAnchor:finishingCard.bottomAnchor constant:-12],
    ]];

    NSView *safety = [[NSView alloc] initWithFrame:NSZeroRect];
    safety.translatesAutoresizingMaskIntoConstraints = NO;
    safety.wantsLayer = YES;
    safety.layer.backgroundColor = [ColorViolet() colorWithAlphaComponent:0.08].CGColor;
    safety.layer.borderColor = [ColorViolet() colorWithAlphaComponent:0.35].CGColor;
    safety.layer.borderWidth = 1;
    safety.layer.cornerRadius = 9;
    NSTextField *safetyText = ColorLabel(@"COLOR SAFETY  •  This engine runs in a separate helper process. If Tahoe stalls the Blackmagic camera-control call, the switcher console and audio/HyperDeck windows remain responsive; stop or restart this engine at any time.",
                                         10.5, NSFontWeightRegular, ColorMuted());
    safetyText.translatesAutoresizingMaskIntoConstraints = NO;
    safetyText.maximumNumberOfLines = 2;
    safetyText.lineBreakMode = NSLineBreakByWordWrapping;
    [safety addSubview:safetyText];
    [stages addArrangedSubview:safety];
    [safety.widthAnchor constraintEqualToAnchor:stages.widthAnchor constant:-32].active = YES;
    [safety.heightAnchor constraintGreaterThanOrEqualToConstant:58].active = YES;
    [NSLayoutConstraint activateConstraints:@[
        [safetyText.leadingAnchor constraintEqualToAnchor:safety.leadingAnchor constant:14],
        [safetyText.trailingAnchor constraintEqualToAnchor:safety.trailingAnchor constant:-14],
        [safetyText.centerYAnchor constraintEqualToAnchor:safety.centerYAnchor],
    ]];

    [NSLayoutConstraint activateConstraints:@[
        [header.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [header.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [header.topAnchor constraintEqualToAnchor:root.topAnchor],
        [header.heightAnchor constraintEqualToConstant:92],
        [title.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:20],
        [title.topAnchor constraintEqualToAnchor:header.topAnchor constant:14],
        [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:2],
        [self.sessionSelector.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:270],
        [self.sessionSelector.topAnchor constraintEqualToAnchor:header.topAnchor constant:18],
        [self.sessionSelector.widthAnchor constraintEqualToConstant:180],
        [self.cameraPopup.leadingAnchor constraintEqualToAnchor:self.sessionSelector.trailingAnchor constant:12],
        [self.cameraPopup.centerYAnchor constraintEqualToAnchor:self.sessionSelector.centerYAnchor],
        [self.cameraPopup.widthAnchor constraintEqualToConstant:128],
        [self.engineButton.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-20],
        [self.engineButton.centerYAnchor constraintEqualToAnchor:self.sessionSelector.centerYAnchor],
        [self.engineButton.widthAnchor constraintEqualToConstant:190],
        [self.statusDot.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:22],
        [self.statusDot.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-13],
        [self.statusDot.widthAnchor constraintEqualToConstant:8],
        [self.statusDot.heightAnchor constraintEqualToConstant:8],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.statusDot.trailingAnchor constant:9],
        [self.statusLabel.centerYAnchor constraintEqualToAnchor:self.statusDot.centerYAnchor],
        [self.statusLabel.trailingAnchor constraintLessThanOrEqualToAnchor:header.trailingAnchor constant:-20],
        [scroll.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:header.bottomAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:root.bottomAnchor],
        [document.leadingAnchor constraintEqualToAnchor:scroll.contentView.leadingAnchor],
        [document.trailingAnchor constraintEqualToAnchor:scroll.contentView.trailingAnchor],
        [document.topAnchor constraintEqualToAnchor:scroll.contentView.topAnchor],
        [document.widthAnchor constraintEqualToAnchor:scroll.contentView.widthAnchor],
        [stages.leadingAnchor constraintEqualToAnchor:document.leadingAnchor],
        [stages.trailingAnchor constraintEqualToAnchor:document.trailingAnchor],
        [stages.topAnchor constraintEqualToAnchor:document.topAnchor],
        [stages.bottomAnchor constraintEqualToAnchor:document.bottomAnchor],
    ]];
}

- (void)refreshSessionState
{
    ATEMState *state = self.activeController.latestState;
    [self rebuildCameraMenuForState:state];
    [self.controllers enumerateObjectsUsingBlock:^(ATEMController *controller, NSUInteger index, BOOL *stop) {
        (void)stop;
        ATEMState *candidate = controller.latestState;
        NSString *letter = index == 0 ? @"ATEM A" : @"ATEM B";
        NSString *indicator = candidate.isConnected ? @" ●" : (candidate.isConnecting ? @" …" : @" ○");
        [self.sessionSelector setLabel:[letter stringByAppendingString:indicator] forSegment:index];
    }];
    self.sessionSelector.selectedSegment = self.activeSessionIndex;
    BOOL connected = state.isConnected;
    self.engineButton.enabled = connected || self.helperReady;
    if (!self.helperReady && !self.helperTask) {
        [self setStatusDetail:(connected
            ? (state.isDemo ? @"Demo switcher ready; start the simulated color engine."
                            : @"Ready to launch isolated camera control for this ATEM.")
            : @"Connect this ATEM before starting camera color control.")
                         color:(connected ? ColorViolet() : ColorMuted())];
    }
}

- (void)rebuildCameraMenuForState:(ATEMState *)state
{
    NSMutableArray<ATEMInputState *> *cameraInputs = [NSMutableArray array];
    for (ATEMInputState *input in state.inputs) {
        if (input.inputID <= 0 || input.inputID > 255)
            continue;
        if (state.isDemo && cameraInputs.count >= 8)
            break;
        [cameraInputs addObject:input];
    }
    NSMutableArray<NSNumber *> *desiredIDs = [NSMutableArray array];
    NSMutableArray<NSString *> *desiredNames = [NSMutableArray array];
    for (ATEMInputState *input in cameraInputs) {
        [desiredIDs addObject:@(input.inputID)];
        [desiredNames addObject:input.longName.length ? input.longName
                                                   : [NSString stringWithFormat:@"Camera %lld", input.inputID]];
    }
    if (desiredIDs.count == 0) {
        for (NSUInteger camera = 1; camera <= 8; ++camera) {
            [desiredIDs addObject:@(camera)];
            [desiredNames addObject:[NSString stringWithFormat:@"Camera %lu", (unsigned long)camera]];
        }
    }
    NSMutableArray<NSNumber *> *currentIDs = [NSMutableArray array];
    for (NSMenuItem *item in self.cameraPopup.itemArray)
        if (item.representedObject)
            [currentIDs addObject:item.representedObject];
    if ([currentIDs isEqualToArray:desiredIDs])
        return;
    NSNumber *selectedID = self.cameraPopup.selectedItem.representedObject;
    [self.cameraPopup removeAllItems];
    for (NSUInteger index = 0; index < desiredIDs.count; ++index) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:desiredNames[index] action:nil keyEquivalent:@""];
        item.representedObject = desiredIDs[index];
        [self.cameraPopup.menu addItem:item];
        if ([desiredIDs[index] isEqual:selectedID])
            [self.cameraPopup selectItem:item];
    }
    if (self.cameraPopup.indexOfSelectedItem < 0)
        [self.cameraPopup selectItemAtIndex:0];
}

- (void)controllerStateChanged:(NSNotification *)notification
{
    if ([self.controllers containsObject:notification.object]) {
        if (notification.object == self.activeController &&
            (self.helperTask || self.helperReady)) {
            BOOL disconnected = !self.activeController.latestState.isConnected;
            BOOL targetChanged = self.helperAddress.length &&
                                 ![self.helperAddress isEqualToString:self.activeController.currentAddress];
            if (disconnected || targetChanged)
                [self stopHelperWithStatus:disconnected
                    ? @"The ATEM disconnected; isolated color control stopped."
                    : @"The ATEM address changed; restart color control for the new target."];
        }
        [self refreshSessionState];
    }
}

- (void)sessionChanged:(NSSegmentedControl *)sender
{
    NSUInteger selected = (NSUInteger)MAX(sender.selectedSegment, 0);
    if (selected == self.activeSessionIndex || selected >= self.controllers.count)
        return;
    [self stopHelperWithStatus:@"Session changed; start color control for the selected ATEM."];
    self.activeSessionIndex = selected;
    [self refreshSessionState];
}

- (void)selectSessionIndex:(NSUInteger)sessionIndex
{
    if (sessionIndex >= self.controllers.count || sessionIndex == self.activeSessionIndex)
        return;
    self.sessionSelector.selectedSegment = (NSInteger)sessionIndex;
    [self sessionChanged:self.sessionSelector];
}

- (void)cameraChanged:(id)sender
{
    (void)sender;
    if (!self.helperReady)
        return;
    if (self.activeController.latestState.isDemo) {
        [self setAdjustmentControlsEnabled:YES];
        [self setStatusDetail:@"Demo color engine is active; controls are simulated."
                         color:ColorCyan()];
        return;
    }
    [self beginSelectedCameraReadback];
}

- (void)enginePressed:(id)sender
{
    (void)sender;
    if (self.helperTask || self.helperReady) {
        [self stopHelperWithStatus:@"Isolated camera control stopped."];
        return;
    }
    [self startHelper];
}

- (void)startHelper
{
    ATEMController *controller = self.activeController;
    if (!controller.latestState.isConnected) {
        [self setStatusDetail:@"Connect the selected ATEM first." color:NSColor.systemOrangeColor];
        return;
    }
    if (controller.latestState.isDemo) {
        self.helperReady = YES;
        self.helperAddress = controller.currentAddress.length ? controller.currentAddress : @"demo";
        self.engineButton.title = @"STOP DEMO ENGINE";
        [self setStatusDetail:@"Demo color engine is active; controls are simulated."
                         color:ColorCyan()];
        [self setControlsEnabled:YES];
        return;
    }
    if (controller.currentAddress.length == 0) {
        [self setStatusDetail:@"The selected ATEM address is unavailable; reconnect it from the console."
                         color:NSColor.systemOrangeColor];
        return;
    }

    NSString *helperPath = [NSBundle.mainBundle.bundlePath stringByAppendingPathComponent:@"Contents/Helpers/ATEMCameraHelper"];
    if (![[NSFileManager defaultManager] isExecutableFileAtPath:helperPath]) {
        [self setStatusDetail:@"The isolated camera helper is missing from this build."
                         color:NSColor.systemOrangeColor];
        return;
    }

    NSPipe *inputPipe = [NSPipe pipe];
    NSPipe *outputPipe = [NSPipe pipe];
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:helperPath];
    task.arguments = @[@"--address", controller.currentAddress];
    task.standardInput = inputPipe;
    task.standardOutput = outputPipe;
    task.standardError = [NSFileHandle fileHandleWithNullDevice];
    self.helperInput = inputPipe.fileHandleForWriting;
    self.helperOutput = outputPipe.fileHandleForReading;
    self.helperBuffer.length = 0;
    self.helperTask = task;
    self.helperAddress = [controller.currentAddress copy];
    self.helperReady = NO;
    self.helperGeneration += 1;
    NSUInteger generation = self.helperGeneration;
    self.engineButton.title = @"STOP / KILL ENGINE";
    [self setStatusDetail:@"Starting isolated camera control…" color:ColorViolet()];
    [self setControlsEnabled:NO];

    __weak ColorWindowController *weakSelf = self;
    self.helperOutput.readabilityHandler = ^(NSFileHandle *handle) {
        NSData *data = handle.availableData;
        if (data.length == 0)
            return;
        dispatch_async(dispatch_get_main_queue(), ^{
            ColorWindowController *strongSelf = weakSelf;
            if (!strongSelf || generation != strongSelf.helperGeneration)
                return;
            [strongSelf consumeHelperData:data];
        });
    };
    task.terminationHandler = ^(NSTask *finishedTask) {
        int status = finishedTask.terminationStatus;
        dispatch_async(dispatch_get_main_queue(), ^{
            ColorWindowController *strongSelf = weakSelf;
            if (!strongSelf || generation != strongSelf.helperGeneration)
                return;
            if (strongSelf.helperTask == finishedTask)
                [strongSelf stopHelperWithStatus:[NSString stringWithFormat:@"Color engine exited (status %d). Restart it when ready.", status]];
        });
    };

    NSError *launchError = nil;
    if (![task launchAndReturnError:&launchError]) {
        [self stopHelperWithStatus:launchError.localizedDescription ?: @"The color engine could not launch."];
        return;
    }

    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 8 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        ColorWindowController *strongSelf = weakSelf;
        if (strongSelf && generation == strongSelf.helperGeneration && strongSelf.helperTask && !strongSelf.helperReady)
            [strongSelf stopHelperWithStatus:@"Camera control did not become ready within 8 seconds. The helper was stopped safely."];
    });
}

- (void)consumeHelperData:(NSData *)data
{
    static const NSUInteger kMaximumHelperBuffer = 1024 * 1024;
    if (self.helperBuffer.length + data.length > kMaximumHelperBuffer) {
        [self stopHelperWithStatus:@"The camera helper produced an invalid oversized response and was stopped."];
        return;
    }
    [self.helperBuffer appendData:data];
    while (YES) {
        const uint8_t *bytes = (const uint8_t *)self.helperBuffer.bytes;
        NSUInteger length = self.helperBuffer.length;
        NSUInteger newline = NSNotFound;
        for (NSUInteger index = 0; index < length; ++index) {
            if (bytes[index] == '\n') {
                newline = index;
                break;
            }
        }
        if (newline == NSNotFound)
            break;
        NSData *line = [self.helperBuffer subdataWithRange:NSMakeRange(0, newline)];
        [self.helperBuffer replaceBytesInRange:NSMakeRange(0, newline + 1) withBytes:NULL length:0];
        if (line.length == 0)
            continue;
        NSDictionary *message = [NSJSONSerialization JSONObjectWithData:line options:0 error:nil];
        if ([message isKindOfClass:NSDictionary.class])
            [self handleHelperMessage:message];
    }
}

- (void)handleHelperMessage:(NSDictionary *)message
{
    NSString *type = message[@"type"];
    if ([type isEqualToString:@"ready"]) {
        self.helperReady = YES;
        self.cameraPopup.enabled = YES;
        [self setAdjustmentControlsEnabled:NO];
        [self beginSelectedCameraReadback];
    } else if ([type isEqualToString:@"values"]) {
        NSDictionary *command = self.activeHelperCommand;
        NSUInteger camera = [message[@"camera"] unsignedIntegerValue];
        NSUInteger parameter = [message[@"parameter"] unsignedIntegerValue];
        NSArray<NSNumber *> *values = message[@"values"];
        BOOL matchesCommand = [command[@"op"] isEqualToString:@"get"] &&
                              [command[@"camera"] unsignedIntegerValue] == camera &&
                              [command[@"parameter"] unsignedIntegerValue] == parameter;
        if (!matchesCommand) {
            [self.pendingHelperCommands removeAllObjects];
            [self.pendingHelperCommandKeys removeAllObjects];
            [self completeHelperCommand];
            [self stopHelperWithStatus:@"The camera helper returned a mismatched response and was stopped."];
            return;
        }
        NSArray<NSSlider *> *sliders = parameter < self.stageSliders.count
            ? self.stageSliders[parameter] : self.secondarySliders[@(parameter)];
        NSArray<NSTextField *> *labels = parameter < self.valueLabels.count
            ? self.valueLabels[parameter] : self.secondaryValueLabels[@(parameter)];
        if (sliders.count == 0 || ![values isKindOfClass:NSArray.class] || values.count != sliders.count) {
            [self.pendingHelperCommands removeAllObjects];
            [self.pendingHelperCommandKeys removeAllObjects];
            [self completeHelperCommand];
            [self stopHelperWithStatus:@"The camera helper returned invalid color data and was stopped."];
            return;
        }

        NSUInteger selectedCamera = [self.cameraPopup.selectedItem.representedObject unsignedIntegerValue];
        NSUInteger loadGeneration = [command[@"loadGeneration"] unsignedIntegerValue];
        BOOL belongsToCurrentLoad = self.colorReadbackInProgress &&
                                    camera == selectedCamera &&
                                    camera == self.loadingCameraID &&
                                    loadGeneration == self.colorLoadGeneration &&
                                    [self.pendingColorParameters containsIndex:parameter];
        if (belongsToCurrentLoad) {
            for (NSUInteger component = 0; component < sliders.count; ++component) {
                sliders[component].doubleValue = values[component].doubleValue;
                labels[component].stringValue =
                    [NSString stringWithFormat:@"%.3f", values[component].doubleValue];
            }
            [self.pendingColorParameters removeIndex:parameter];
            if (self.pendingColorParameters.count == 0) {
                self.colorReadbackInProgress = NO;
                [self setAdjustmentControlsEnabled:YES];
                NSString *cameraName = self.cameraPopup.selectedItem.title ?: @"selected camera";
                [self setStatusDetail:[NSString stringWithFormat:@"%@ color values are live.", cameraName]
                                 color:ColorCyan()];
            }
        }
        [self completeHelperCommand];
    } else if ([type isEqualToString:@"ack"]) {
        NSDictionary *command = self.activeHelperCommand;
        NSUInteger camera = [message[@"camera"] unsignedIntegerValue];
        NSUInteger parameter = [message[@"parameter"] unsignedIntegerValue];
        BOOL matchesCommand = [command[@"op"] isEqualToString:@"set"] &&
                              [command[@"camera"] unsignedIntegerValue] == camera &&
                              [command[@"parameter"] unsignedIntegerValue] == parameter;
        if (!matchesCommand) {
            [self.pendingHelperCommands removeAllObjects];
            [self.pendingHelperCommandKeys removeAllObjects];
        }
        [self completeHelperCommand];
        if (!matchesCommand)
            [self stopHelperWithStatus:@"The camera helper returned a mismatched acknowledgement and was stopped."];
    } else if ([type isEqualToString:@"reset"]) {
        NSDictionary *command = self.activeHelperCommand;
        NSUInteger camera = [message[@"camera"] unsignedIntegerValue];
        NSUInteger selectedCamera = [self.cameraPopup.selectedItem.representedObject unsignedIntegerValue];
        BOOL matchesCommand = [command[@"op"] isEqualToString:@"reset"] &&
                              [command[@"camera"] unsignedIntegerValue] == camera;
        if (matchesCommand && camera == selectedCamera) {
            [self applyDefaultColorValues];
            [self setStatusDetail:@"Camera color correction reset to defaults."
                             color:ColorCyan()];
        }
        if (!matchesCommand) {
            [self.pendingHelperCommands removeAllObjects];
            [self.pendingHelperCommandKeys removeAllObjects];
        }
        [self completeHelperCommand];
        if (!matchesCommand)
            [self stopHelperWithStatus:@"The camera helper returned a mismatched reset response and was stopped."];
    } else if ([type isEqualToString:@"error"]) {
        NSString *errorMessage = message[@"message"] ?: @"Camera-control error.";
        [self.pendingHelperCommands removeAllObjects];
        [self.pendingHelperCommandKeys removeAllObjects];
        [self completeHelperCommand];
        [self stopHelperWithStatus:[NSString stringWithFormat:@"%@ Restart the isolated engine to retry.",
                                    errorMessage]];
    }
}

- (void)beginSelectedCameraReadback
{
    if (!self.helperReady || self.activeController.latestState.isDemo)
        return;
    NSUInteger camera = [self.cameraPopup.selectedItem.representedObject unsignedIntegerValue];
    if (camera == 0) {
        [self stopHelperWithStatus:@"No valid camera is available for color control."];
        return;
    }

    self.colorLoadGeneration += 1;
    self.loadingCameraID = camera;
    self.colorReadbackInProgress = YES;
    [self.pendingColorParameters removeAllIndexes];
    [self.pendingColorParameters addIndexesInRange:NSMakeRange(0, 7)];

    // Drop coalesced work for the previous camera. A command already awaiting its
    // response remains in flight and is safely ignored by the load-generation check.
    [self.pendingHelperCommands removeAllObjects];
    [self.pendingHelperCommandKeys removeAllObjects];
    self.cameraPopup.enabled = YES;
    [self setAdjustmentControlsEnabled:NO];
    NSString *cameraName = self.cameraPopup.selectedItem.title ?: @"selected camera";
    [self setStatusDetail:[NSString stringWithFormat:@"Loading all color values for %@…", cameraName]
                     color:ColorViolet()];
    [self requestCurrentValues];
}

- (void)requestCurrentValues
{
    NSUInteger camera = [self.cameraPopup.selectedItem.representedObject unsignedIntegerValue];
    NSUInteger loadGeneration = self.colorLoadGeneration;
    for (NSUInteger parameter = 0; parameter <= 6; ++parameter) {
        [self sendHelperCommand:@{
            @"op": @"get",
            @"camera": @(camera),
            @"parameter": @(parameter),
            @"loadGeneration": @(loadGeneration),
        }];
    }
}

- (void)sendHelperCommand:(NSDictionary *)command
{
    if (!self.helperReady || !self.helperInput)
        return;
    NSString *key = [NSString stringWithFormat:@"%@:%@:%@",
                     command[@"op"] ?: @"",
                     command[@"camera"] ?: @0,
                     command[@"parameter"] ?: @0];
    if (!self.pendingHelperCommands[key])
        [self.pendingHelperCommandKeys addObject:key];
    self.pendingHelperCommands[key] = command;
    while (self.pendingHelperCommandKeys.count > 24) {
        NSString *oldestKey = self.pendingHelperCommandKeys.firstObject;
        [self.pendingHelperCommandKeys removeObjectAtIndex:0];
        [self.pendingHelperCommands removeObjectForKey:oldestKey];
    }
    [self pumpHelperWriter];
}

- (void)pumpHelperWriter
{
    NSAssert(NSThread.isMainThread, @"Camera IPC scheduling belongs on the main thread.");
    if (!self.helperReady || !self.helperInput || self.helperWriteInFlight ||
        self.pendingHelperCommandKeys.count == 0)
        return;
    NSString *key = self.pendingHelperCommandKeys.firstObject;
    [self.pendingHelperCommandKeys removeObjectAtIndex:0];
    NSDictionary *command = self.pendingHelperCommands[key];
    [self.pendingHelperCommands removeObjectForKey:key];
    NSData *json = [NSJSONSerialization dataWithJSONObject:command options:0 error:nil];
    if (!json) {
        [self pumpHelperWriter];
        return;
    }
    NSMutableData *line = [json mutableCopy];
    [line appendBytes:"\n" length:1];
    NSFileHandle *input = self.helperInput;
    NSUInteger generation = self.helperGeneration;
    self.helperWriteInFlight = YES;
    self.activeHelperCommand = command;
    self.helperCommandGeneration += 1;
    NSUInteger commandGeneration = self.helperCommandGeneration;
    __weak ColorWindowController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        ColorWindowController *strongSelf = weakSelf;
        if (!strongSelf ||
            generation != strongSelf.helperGeneration ||
            commandGeneration != strongSelf.helperCommandGeneration ||
            !strongSelf.helperWriteInFlight)
            return;
        [strongSelf stopHelperWithStatus:
            @"The camera-control command timed out after 3 seconds. The isolated engine was stopped safely."];
    });
    dispatch_async(self.helperWriteQueue, ^{
        NSError *writeError = nil;
        BOOL wrote = [input writeData:line error:&writeError];
        (void)writeError;
        dispatch_async(dispatch_get_main_queue(), ^{
            ColorWindowController *strongSelf = weakSelf;
            if (!strongSelf || generation != strongSelf.helperGeneration)
                return;
            if (!wrote) {
                [strongSelf stopHelperWithStatus:@"The isolated color engine stopped responding."];
                return;
            }
        });
    });
}

- (void)completeHelperCommand
{
    NSAssert(NSThread.isMainThread, @"Camera IPC responses belong on the main thread.");
    if (!self.helperWriteInFlight)
        return;
    self.helperWriteInFlight = NO;
    self.activeHelperCommand = nil;
    self.helperCommandGeneration += 1;
    [self pumpHelperWriter];
}

- (void)colorSliderChanged:(NSSlider *)sender
{
    NSUInteger parameter = (NSUInteger)sender.tag / 10;
    if (parameter >= self.stageSliders.count)
        return;
    NSMutableArray<NSNumber *> *values = [NSMutableArray arrayWithCapacity:4];
    for (NSUInteger component = 0; component < 4; ++component) {
        NSSlider *slider = self.stageSliders[parameter][component];
        [values addObject:@(slider.doubleValue)];
        self.valueLabels[parameter][component].stringValue = [NSString stringWithFormat:@"%.3f", slider.doubleValue];
    }
    if (self.activeController.latestState.isDemo)
        return;
    NSUInteger camera = [self.cameraPopup.selectedItem.representedObject unsignedIntegerValue];
    [self sendHelperCommand:@{
        @"op": @"set",
        @"camera": @(camera),
        @"parameter": @(parameter),
        @"values": values,
    }];
}

- (void)secondarySliderChanged:(NSSlider *)sender
{
    NSUInteger parameter = (NSUInteger)sender.tag / 10;
    NSArray<NSSlider *> *sliders = self.secondarySliders[@(parameter)];
    NSArray<NSTextField *> *labels = self.secondaryValueLabels[@(parameter)];
    if (sliders.count == 0)
        return;
    NSMutableArray<NSNumber *> *values = [NSMutableArray arrayWithCapacity:sliders.count];
    for (NSUInteger component = 0; component < sliders.count; ++component) {
        [values addObject:@(sliders[component].doubleValue)];
        labels[component].stringValue = [NSString stringWithFormat:@"%.3f", sliders[component].doubleValue];
    }
    if (self.activeController.latestState.isDemo)
        return;
    NSUInteger camera = [self.cameraPopup.selectedItem.representedObject unsignedIntegerValue];
    [self sendHelperCommand:@{
        @"op": @"set",
        @"camera": @(camera),
        @"parameter": @(parameter),
        @"values": values,
    }];
}

- (void)resetStage:(NSButton *)sender
{
    NSUInteger parameter = (NSUInteger)sender.tag;
    if (parameter >= self.stageSliders.count)
        return;
    double defaultValue = parameter == 2 ? 1.0 : 0.0;
    for (NSSlider *slider in self.stageSliders[parameter])
        slider.doubleValue = defaultValue;
    [self colorSliderChanged:self.stageSliders[parameter].firstObject];
}

- (void)resetAllColor:(id)sender
{
    (void)sender;
    [self applyDefaultColorValues];
    if (self.activeController.latestState.isDemo)
        return;
    NSUInteger camera = [self.cameraPopup.selectedItem.representedObject unsignedIntegerValue];
    [self sendHelperCommand:@{@"op": @"reset", @"camera": @(camera), @"parameter": @7}];
}

- (void)applyDefaultColorValues
{
    for (NSUInteger parameter = 0; parameter < self.stageSliders.count; ++parameter) {
        double defaultValue = parameter == 2 ? 1.0 : 0.0;
        for (NSUInteger component = 0; component < self.stageSliders[parameter].count; ++component) {
            self.stageSliders[parameter][component].doubleValue = defaultValue;
            self.valueLabels[parameter][component].stringValue =
                [NSString stringWithFormat:@"%.3f", defaultValue];
        }
    }
    NSArray<NSArray<NSNumber *> *> *secondaryDefaults = @[
        @[@0.5, @1.0],
        @[@1.0],
        @[@0.0, @1.0],
    ];
    for (NSUInteger offset = 0; offset < secondaryDefaults.count; ++offset) {
        NSNumber *parameter = @(offset + 4);
        NSArray<NSSlider *> *sliders = self.secondarySliders[parameter];
        NSArray<NSTextField *> *labels = self.secondaryValueLabels[parameter];
        for (NSUInteger component = 0; component < sliders.count; ++component) {
            double value = secondaryDefaults[offset][component].doubleValue;
            sliders[component].doubleValue = value;
            labels[component].stringValue = [NSString stringWithFormat:@"%.3f", value];
        }
    }
}

- (void)setControlsEnabled:(BOOL)enabled
{
    self.cameraPopup.enabled = enabled;
    [self setAdjustmentControlsEnabled:enabled];
}

- (void)setAdjustmentControlsEnabled:(BOOL)enabled
{
    for (NSArray<NSSlider *> *sliders in self.stageSliders)
        for (NSSlider *slider in sliders)
            slider.enabled = enabled;
    for (NSArray<NSSlider *> *sliders in self.secondarySliders.allValues)
        for (NSSlider *slider in sliders)
            slider.enabled = enabled;
    for (NSButton *button in self.resetButtons)
        button.enabled = enabled;
}

- (void)stopHelperWithStatus:(NSString *)status
{
    self.helperGeneration += 1;
    self.helperCommandGeneration += 1;
    self.colorLoadGeneration += 1;
    NSTask *task = self.helperTask;
    self.helperOutput.readabilityHandler = nil;
    NSFileHandle *input = self.helperInput;
    self.helperInput = nil;
    self.helperOutput = nil;
    self.helperTask = nil;
    self.helperReady = NO;
    self.helperAddress = @"";
    [self.pendingHelperCommands removeAllObjects];
    [self.pendingHelperCommandKeys removeAllObjects];
    self.activeHelperCommand = nil;
    self.helperWriteInFlight = NO;
    self.colorReadbackInProgress = NO;
    self.loadingCameraID = 0;
    [self.pendingColorParameters removeAllIndexes];
    if (task.isRunning) {
        [task terminate];
        pid_t processIdentifier = task.processIdentifier;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            if (task.isRunning && processIdentifier > 1)
                kill(processIdentifier, SIGKILL);
        });
    }
    if (input) {
        dispatch_async(self.helperWriteQueue, ^{
            [input closeFile];
        });
    }
    self.engineButton.title = @"START ISOLATED ENGINE";
    [self setControlsEnabled:NO];
    [self refreshSessionState];
    if (status.length)
        [self setStatusDetail:status color:ColorMuted()];
}

- (void)windowWillClose:(NSNotification *)notification
{
    (void)notification;
    [self stopHelperWithStatus:@"Camera control is stopped."];
}

- (void)shutdown
{
    NSTask *task = self.helperTask;
    pid_t processIdentifier = task.processIdentifier;
    [self stopHelperWithStatus:@"Camera control is stopped."];
    if (task.isRunning && processIdentifier > 1) {
        if (kill(processIdentifier, SIGKILL) == 0)
            [task waitUntilExit];
    }
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [self stopHelperWithStatus:@""];
}

@end

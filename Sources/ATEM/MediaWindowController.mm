#import "MediaWindowController.h"
#import "ATEMController.h"
#import "ATEMColorMath.h"

#import <cmath>

#pragma mark - Theme

static NSColor *MDColor(NSUInteger rgb)
{
    return [NSColor colorWithSRGBRed:((rgb >> 16) & 0xFF) / 255.0
                               green:((rgb >> 8) & 0xFF) / 255.0
                                blue:(rgb & 0xFF) / 255.0
                               alpha:1.0];
}

static NSColor *MDCanvas(void)    { return MDColor(0x090D12); }
static NSColor *MDHeader(void)    { return MDColor(0x0E141B); }
static NSColor *MDPanel(void)     { return MDColor(0x151C24); }
static NSColor *MDPanelRaised(void) { return MDColor(0x1A232D); }
static NSColor *MDDivider(void)   { return MDColor(0x2C3A48); }
static NSColor *MDText(void)      { return MDColor(0xF2F5F8); }
static NSColor *MDSecondary(void) { return MDColor(0xA5B0BC); }
static NSColor *MDMuted(void)     { return MDColor(0x6E7B88); }
static NSColor *MDCyan(void)      { return MDColor(0x32C7F3); }
static NSColor *MDGreen(void)     { return MDColor(0x31CE7A); }
static NSColor *MDRed(void)       { return MDColor(0xF3485D); }
static NSColor *MDAmber(void)     { return MDColor(0xF2AE32); }
static NSColor *MDViolet(void)    { return MDColor(0xB27AF5); }

static NSTextField *MDLabel(NSString *text, CGFloat size, NSFontWeight weight, NSColor *color)
{
    NSTextField *label = [NSTextField labelWithString:text ?: @""];
    label.font = [NSFont systemFontOfSize:size weight:weight];
    label.textColor = color ?: MDText();
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    return label;
}

static NSTextField *MDEyebrow(NSString *text)
{
    return MDLabel(text.uppercaseString, 9, NSFontWeightSemibold, MDMuted());
}

static NSTextField *MDValueField(void)
{
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSZeroRect];
    field.translatesAutoresizingMaskIntoConstraints = NO;
    field.font = [NSFont monospacedSystemFontOfSize:11 weight:NSFontWeightMedium];
    field.textColor = MDText();
    field.backgroundColor = MDHeader();
    field.drawsBackground = YES;
    field.bezeled = NO;
    field.alignment = NSTextAlignmentRight;
    field.focusRingType = NSFocusRingTypeExterior;
    field.wantsLayer = YES;
    field.layer.cornerRadius = 6;
    field.layer.borderWidth = 1;
    field.layer.borderColor = MDDivider().CGColor;
    return field;
}

static NSButton *MDButton(NSString *title, NSColor *tint, id target, SEL action)
{
    NSButton *button = [NSButton buttonWithTitle:title target:target action:action];
    button.translatesAutoresizingMaskIntoConstraints = NO;
    button.font = [NSFont systemFontOfSize:10 weight:NSFontWeightSemibold];
    button.bezelStyle = NSBezelStyleTexturedRounded;
    button.contentTintColor = tint ?: MDCyan();
    return button;
}

static NSSlider *MDSlider(double minimum, double maximum, id target, SEL action)
{
    NSSlider *slider = [NSSlider sliderWithValue:minimum
                                        minValue:minimum
                                        maxValue:maximum
                                          target:target
                                          action:action];
    slider.translatesAutoresizingMaskIntoConstraints = NO;
    slider.continuous = YES;
    slider.controlSize = NSControlSizeRegular;
    return slider;
}

/// A flat colour rectangle with a rounded border, used for the live swatch.
@interface MDSwatchView : NSView
@property(nonatomic, strong) NSColor *swatchColor;
@end

@implementation MDSwatchView

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (!self)
        return nil;
    _swatchColor = NSColor.blackColor;
    self.wantsLayer = YES;
    self.layer.cornerRadius = 8;
    self.layer.borderWidth = 1;
    self.layer.borderColor = MDDivider().CGColor;
    self.layer.backgroundColor = _swatchColor.CGColor;
    return self;
}

- (void)setSwatchColor:(NSColor *)swatchColor
{
    _swatchColor = swatchColor ?: NSColor.blackColor;
    self.layer.backgroundColor = _swatchColor.CGColor;
}

@end

#pragma mark - Presets

/// Neutral references, described by the signal level the ATEM is actually set to.
static NSArray<NSDictionary *> *MDGrayscalePresets(void)
{
    static NSArray<NSDictionary *> *presets = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        double gray18 = ATEMRec709SignalForSceneLinear(0.18);
        double white90 = ATEMRec709SignalForSceneLinear(0.90);
        presets = @[
            @{@"title": @"BLACK", @"luma": @0.0,
              @"tip": @"Luma 0% — full black."},
            @{@"title": @"18% GRAY", @"luma": @(gray18),
              @"tip": [NSString stringWithFormat:@"Luma %.1f%% — an 18%% reflectance gray card through the Rec.709 curve.", gray18 * 100.0]},
            @{@"title": @"50%", @"luma": @0.5,
              @"tip": @"Luma 50% — half signal, the usual LED-wall alignment gray."},
            @{@"title": @"90% WHITE", @"luma": @(white90),
              @"tip": [NSString stringWithFormat:@"Luma %.1f%% — a 90%% reflectance white card through the Rec.709 curve.", white90 * 100.0]},
            @{@"title": @"100%", @"luma": @1.0,
              @"tip": @"Luma 100% — peak white."},
        ];
    });
    return presets;
}

/// SMPTE 75% colour bars: each bar is a pair of 0.00/0.75 primaries, which is
/// saturation 100% at luma 37.5%, with only the hue changing.
static NSArray<NSDictionary *> *MDBarPresets(void)
{
    static NSArray<NSDictionary *> *presets = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        NSArray<NSString *> *titles = @[@"YEL", @"CYN", @"GRN", @"MAG", @"RED", @"BLU"];
        const double components[6][3] = {
            {0.75, 0.75, 0.00},
            {0.00, 0.75, 0.75},
            {0.00, 0.75, 0.00},
            {0.75, 0.00, 0.75},
            {0.75, 0.00, 0.00},
            {0.00, 0.00, 0.75},
        };
        NSMutableArray<NSDictionary *> *built = [NSMutableArray array];
        for (NSUInteger index = 0; index < titles.count; ++index) {
            ATEMHSL hsl = ATEMHSLFromRGB(components[index][0], components[index][1], components[index][2]);
            [built addObject:@{@"title": titles[index],
                               @"hue": @(hsl.hue),
                               @"saturation": @(hsl.saturation),
                               @"luma": @(hsl.luma),
                               @"tip": [NSString stringWithFormat:@"75%% bar: hue %.0f°, saturation 100%%, luma 37.5%%.", hsl.hue]}];
        }
        presets = [built copy];
    });
    return presets;
}

#pragma mark - Panel

@interface MDColorPanel : NSView
@property(nonatomic) NSUInteger generatorIndex;
@property(nonatomic) int64_t inputID;

@property(nonatomic, strong) NSTextField *titleLabel;
@property(nonatomic, strong) NSTextField *inputLabel;
@property(nonatomic, strong) MDSwatchView *swatch;
@property(nonatomic, strong) NSTextField *readoutLabel;
@property(nonatomic, strong) NSColorWell *colorWell;
@property(nonatomic, strong) NSTextField *hexField;

@property(nonatomic, strong) NSSlider *hueSlider;
@property(nonatomic, strong) NSTextField *hueField;
@property(nonatomic, strong) NSSlider *saturationSlider;
@property(nonatomic, strong) NSTextField *saturationField;
@property(nonatomic, strong) NSSlider *lumaSlider;
@property(nonatomic, strong) NSTextField *lumaField;
@property(nonatomic, strong) NSTextField *exposureLabel;
@property(nonatomic, copy) NSArray<NSButton *> *stopButtons;
@property(nonatomic, copy) NSArray<NSButton *> *presetButtons;
@property(nonatomic, strong) NSButton *previewButton;
@property(nonatomic, strong) NSButton *programButton;

/// Values the UI is currently showing. Authoritative while a write is in flight.
@property(nonatomic) double hue;
@property(nonatomic) double saturation;
@property(nonatomic) double luma;
/// Luma at the moment the colour itself was last chosen, so the exposure
/// readout can say how far the operator has ridden it since.
@property(nonatomic) double referenceLuma;
@property(nonatomic) BOOL hasReference;

/// Poll echo suppression, as used by the rate field and multiview writes.
@property(nonatomic) CFAbsoluteTime echoSuppressUntil;
@property(nonatomic) BOOL sendScheduled;
@property(nonatomic) BOOL needsSend;
@end

@implementation MDColorPanel

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (!self)
        return nil;
    self.wantsLayer = YES;
    self.layer.backgroundColor = MDPanel().CGColor;
    self.layer.cornerRadius = 12;
    self.layer.borderWidth = 1;
    self.layer.borderColor = MDDivider().CGColor;
    return self;
}

@end

#pragma mark - Window controller

@interface MediaWindowController () <NSTextFieldDelegate>
@property(nonatomic, copy) NSArray<ATEMController *> *controllers;
@property(nonatomic) NSUInteger activeSessionIndex;
@property(nonatomic, strong) NSSegmentedControl *sessionSelector;
@property(nonatomic, strong) NSTextField *switcherLabel;
@property(nonatomic, strong) NSTextField *statusLabel;
@property(nonatomic, strong) NSView *statusDot;
@property(nonatomic, strong) NSStackView *panelStack;
@property(nonatomic, strong) NSTextField *emptyLabel;
@property(nonatomic, copy) NSArray<MDColorPanel *> *panels;
@property(nonatomic) NSUInteger builtPanelCount;
@end

@implementation MediaWindowController

- (instancetype)initWithControllers:(NSArray<ATEMController *> *)controllers
                initialSessionIndex:(NSUInteger)sessionIndex
{
    NSParameterAssert(controllers.count == 2);
    NSRect frame = NSMakeRect(0, 0, 1060, 720);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                  styleMask:(NSWindowStyleMaskTitled |
                                                             NSWindowStyleMaskClosable |
                                                             NSWindowStyleMaskMiniaturizable |
                                                             NSWindowStyleMaskResizable)
                                                    backing:NSBackingStoreBuffered
                                                      defer:NO];
    window.title = @"ATEM CNTRL — Media";
    window.minSize = NSMakeSize(920, 640);
    window.backgroundColor = MDCanvas();
    window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    window.titlebarAppearsTransparent = YES;
    window.titleVisibility = NSWindowTitleHidden;
    window.tabbingMode = NSWindowTabbingModeDisallowed;
    window.sharingType = NSWindowSharingReadOnly;
    [window setFrameAutosaveName:@"ATEMCNTRLMediaWindow"];
    [window center];

    self = [super initWithWindow:window];
    if (!self)
        return nil;
    _controllers = [controllers copy];
    _activeSessionIndex = MIN(sessionIndex, controllers.count - 1);
    _panels = @[];
    [self buildInterface];
    for (ATEMController *controller in controllers) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(stateDidChange:)
                                                     name:ATEMStateDidChangeNotification
                                                   object:controller];
    }
    [self refreshActiveSession];
    return self;
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (ATEMController *)activeController
{
    return self.controllers[self.activeSessionIndex];
}

#pragma mark - Interface

- (void)buildInterface
{
    NSView *root = [[NSView alloc] initWithFrame:NSZeroRect];
    root.wantsLayer = YES;
    root.layer.backgroundColor = MDCanvas().CGColor;
    self.window.contentView = root;

    NSView *header = [[NSView alloc] initWithFrame:NSZeroRect];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.wantsLayer = YES;
    header.layer.backgroundColor = MDHeader().CGColor;
    header.layer.borderColor = MDDivider().CGColor;
    header.layer.borderWidth = 1;
    [root addSubview:header];

    NSTextField *title = MDLabel(@"MEDIA — COLOR GENERATORS", 20, NSFontWeightSemibold, MDText());
    [header addSubview:title];
    NSTextField *subtitle = MDLabel(@"Pick a colour, then ride its exposure in stops of emitted light",
                                    10, NSFontWeightMedium, MDSecondary());
    [header addSubview:subtitle];

    NSTextField *targetLabel = MDEyebrow(@"Control target");
    [header addSubview:targetLabel];
    self.sessionSelector = [NSSegmentedControl segmentedControlWithLabels:@[@"A  ○", @"B  ○"]
                                                            trackingMode:NSSegmentSwitchTrackingSelectOne
                                                                  target:self
                                                                  action:@selector(sessionChanged:)];
    self.sessionSelector.translatesAutoresizingMaskIntoConstraints = NO;
    self.sessionSelector.segmentStyle = NSSegmentStyleCapsule;
    self.sessionSelector.selectedSegmentBezelColor = MDCyan();
    self.sessionSelector.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
    self.sessionSelector.selectedSegment = self.activeSessionIndex;
    [header addSubview:self.sessionSelector];

    self.statusDot = [[NSView alloc] initWithFrame:NSZeroRect];
    self.statusDot.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusDot.wantsLayer = YES;
    self.statusDot.layer.cornerRadius = 4;
    [header addSubview:self.statusDot];
    self.switcherLabel = MDLabel(@"Not connected", 12, NSFontWeightSemibold, MDText());
    [header addSubview:self.switcherLabel];
    self.statusLabel = MDLabel(@"Connect an ATEM or use Demo to set the colour generators.",
                               10, NSFontWeightRegular, MDSecondary());
    [header addSubview:self.statusLabel];

    self.panelStack = [NSStackView stackViewWithViews:@[]];
    self.panelStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.panelStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    self.panelStack.alignment = NSLayoutAttributeTop;
    self.panelStack.distribution = NSStackViewDistributionFillEqually;
    self.panelStack.spacing = 16;
    [root addSubview:self.panelStack];

    self.emptyLabel = MDLabel(@"This switcher reports no colour generators. Connect an ATEM or use Demo mode.",
                              12, NSFontWeightRegular, MDSecondary());
    self.emptyLabel.hidden = YES;
    [root addSubview:self.emptyLabel];

    [NSLayoutConstraint activateConstraints:@[
        [header.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [header.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [header.topAnchor constraintEqualToAnchor:root.topAnchor],
        [header.heightAnchor constraintEqualToConstant:104],
        [title.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:22],
        [title.topAnchor constraintEqualToAnchor:header.topAnchor constant:17],
        [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:3],
        [targetLabel.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-22],
        [targetLabel.topAnchor constraintEqualToAnchor:header.topAnchor constant:13],
        [self.sessionSelector.trailingAnchor constraintEqualToAnchor:targetLabel.trailingAnchor],
        [self.sessionSelector.topAnchor constraintEqualToAnchor:header.topAnchor constant:29],
        [self.sessionSelector.widthAnchor constraintEqualToConstant:150],
        [self.sessionSelector.heightAnchor constraintEqualToConstant:32],
        [self.statusDot.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [self.statusDot.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-14],
        [self.statusDot.widthAnchor constraintEqualToConstant:8],
        [self.statusDot.heightAnchor constraintEqualToConstant:8],
        [self.switcherLabel.leadingAnchor constraintEqualToAnchor:self.statusDot.trailingAnchor constant:8],
        [self.switcherLabel.centerYAnchor constraintEqualToAnchor:self.statusDot.centerYAnchor],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:self.switcherLabel.trailingAnchor constant:12],
        [self.statusLabel.trailingAnchor constraintLessThanOrEqualToAnchor:self.sessionSelector.leadingAnchor constant:-16],
        [self.statusLabel.centerYAnchor constraintEqualToAnchor:self.statusDot.centerYAnchor],

        [self.panelStack.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:18],
        [self.panelStack.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-18],
        [self.panelStack.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:18],
        [self.panelStack.bottomAnchor constraintLessThanOrEqualToAnchor:root.bottomAnchor constant:-18],

        [self.emptyLabel.centerXAnchor constraintEqualToAnchor:root.centerXAnchor],
        [self.emptyLabel.centerYAnchor constraintEqualToAnchor:root.centerYAnchor],
    ]];
}

- (NSView *)presetRowWithTitle:(NSString *)title
                       presets:(NSArray<NSDictionary *> *)presets
                        action:(SEL)action
                         panel:(MDColorPanel *)panel
                       buttons:(NSMutableArray<NSButton *> *)collected
{
    NSView *row = [[NSView alloc] initWithFrame:NSZeroRect];
    row.translatesAutoresizingMaskIntoConstraints = NO;

    NSTextField *eyebrow = MDEyebrow(title);
    [row addSubview:eyebrow];

    NSStackView *buttonStack = [NSStackView stackViewWithViews:@[]];
    buttonStack.translatesAutoresizingMaskIntoConstraints = NO;
    buttonStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    buttonStack.distribution = NSStackViewDistributionFillEqually;
    buttonStack.spacing = 5;
    [row addSubview:buttonStack];

    [presets enumerateObjectsUsingBlock:^(NSDictionary *preset, NSUInteger index, BOOL *stop) {
        (void)stop;
        NSButton *button = MDButton(preset[@"title"], MDSecondary(), self, action);
        button.tag = (NSInteger)(panel.generatorIndex * 100 + index);
        button.toolTip = preset[@"tip"];
        [buttonStack addArrangedSubview:button];
        [collected addObject:button];
    }];

    [NSLayoutConstraint activateConstraints:@[
        [eyebrow.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [eyebrow.topAnchor constraintEqualToAnchor:row.topAnchor],
        [buttonStack.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [buttonStack.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [buttonStack.topAnchor constraintEqualToAnchor:eyebrow.bottomAnchor constant:5],
        [buttonStack.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
        [buttonStack.heightAnchor constraintEqualToConstant:26],
    ]];
    return row;
}

- (NSView *)sliderRowWithTitle:(NSString *)title
                        slider:(NSSlider *)slider
                         field:(NSTextField *)field
                         extra:(nullable NSView *)extra
{
    NSView *row = [[NSView alloc] initWithFrame:NSZeroRect];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    NSTextField *eyebrow = MDEyebrow(title);
    [row addSubview:eyebrow];
    [row addSubview:slider];
    [row addSubview:field];
    if (extra)
        [row addSubview:extra];

    NSMutableArray<NSLayoutConstraint *> *constraints = [NSMutableArray arrayWithArray:@[
        [eyebrow.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [eyebrow.topAnchor constraintEqualToAnchor:row.topAnchor],
        [field.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [field.centerYAnchor constraintEqualToAnchor:slider.centerYAnchor],
        [field.widthAnchor constraintEqualToConstant:74],
        [field.heightAnchor constraintEqualToConstant:24],
        [slider.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [slider.trailingAnchor constraintEqualToAnchor:field.leadingAnchor constant:-10],
        [slider.topAnchor constraintEqualToAnchor:eyebrow.bottomAnchor constant:4],
        [slider.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
    ]];
    if (extra) {
        [constraints addObjectsFromArray:@[
            [extra.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
            [extra.centerYAnchor constraintEqualToAnchor:eyebrow.centerYAnchor],
        ]];
    }
    [NSLayoutConstraint activateConstraints:constraints];
    return row;
}

- (MDColorPanel *)panelForIndex:(NSUInteger)index
{
    MDColorPanel *panel = [[MDColorPanel alloc] initWithFrame:NSZeroRect];
    panel.translatesAutoresizingMaskIntoConstraints = NO;
    panel.generatorIndex = index;
    panel.inputID = -1;

    panel.titleLabel = MDLabel([NSString stringWithFormat:@"COLOR %lu", (unsigned long)index + 1],
                               14, NSFontWeightSemibold, MDText());
    [panel addSubview:panel.titleLabel];
    panel.inputLabel = MDLabel(@"", 9.5, NSFontWeightMedium, MDMuted());
    [panel addSubview:panel.inputLabel];

    panel.swatch = [[MDSwatchView alloc] initWithFrame:NSZeroRect];
    panel.swatch.translatesAutoresizingMaskIntoConstraints = NO;
    panel.swatch.toolTip = @"Approximate on-screen preview of what this generator is outputting.";
    [panel addSubview:panel.swatch];

    panel.readoutLabel = MDLabel(@"—", 10.5, NSFontWeightMedium, MDSecondary());
    [panel addSubview:panel.readoutLabel];

    NSTextField *pickerEyebrow = MDEyebrow(@"Colour");
    [panel addSubview:pickerEyebrow];
    panel.colorWell = [[NSColorWell alloc] initWithFrame:NSZeroRect];
    panel.colorWell.translatesAutoresizingMaskIntoConstraints = NO;
    panel.colorWell.target = self;
    panel.colorWell.action = @selector(colorWellChanged:);
    panel.colorWell.tag = (NSInteger)index;
    panel.colorWell.toolTip = @"Open the macOS colour picker. Hue and saturation come from the picked colour; "
                               @"luma follows it too, and becomes the reference the stop buttons work from.";
    [panel addSubview:panel.colorWell];

    panel.hexField = MDValueField();
    panel.hexField.alignment = NSTextAlignmentLeft;
    panel.hexField.placeholderString = @"#RRGGBB";
    panel.hexField.delegate = self;
    panel.hexField.tag = (NSInteger)index;
    panel.hexField.target = self;
    panel.hexField.action = @selector(hexCommitted:);
    panel.hexField.toolTip = @"Type a hex colour and press Return.";
    [panel addSubview:panel.hexField];

    panel.hueSlider = MDSlider(0.0, 360.0, self, @selector(hueSliderMoved:));
    panel.hueSlider.tag = (NSInteger)index;
    panel.hueField = MDValueField();
    panel.hueField.delegate = self;
    panel.hueField.tag = (NSInteger)index;
    panel.hueField.target = self;
    panel.hueField.action = @selector(hueFieldCommitted:);
    NSView *hueRow = [self sliderRowWithTitle:@"Hue (degrees)"
                                       slider:panel.hueSlider
                                        field:panel.hueField
                                        extra:nil];
    [panel addSubview:hueRow];

    panel.saturationSlider = MDSlider(0.0, 100.0, self, @selector(saturationSliderMoved:));
    panel.saturationSlider.tag = (NSInteger)index;
    panel.saturationField = MDValueField();
    panel.saturationField.delegate = self;
    panel.saturationField.tag = (NSInteger)index;
    panel.saturationField.target = self;
    panel.saturationField.action = @selector(saturationFieldCommitted:);
    NSView *saturationRow = [self sliderRowWithTitle:@"Saturation"
                                              slider:panel.saturationSlider
                                               field:panel.saturationField
                                               extra:nil];
    [panel addSubview:saturationRow];

    NSView *exposureBlock = [[NSView alloc] initWithFrame:NSZeroRect];
    exposureBlock.translatesAutoresizingMaskIntoConstraints = NO;
    exposureBlock.wantsLayer = YES;
    exposureBlock.layer.backgroundColor = MDPanelRaised().CGColor;
    exposureBlock.layer.cornerRadius = 9;
    exposureBlock.layer.borderWidth = 1;
    exposureBlock.layer.borderColor = MDDivider().CGColor;
    [panel addSubview:exposureBlock];

    panel.lumaSlider = MDSlider(0.0, 100.0, self, @selector(lumaSliderMoved:));
    panel.lumaSlider.tag = (NSInteger)index;
    panel.lumaSlider.toolTip = @"Luma is the signal level the ATEM sends, 0–100%.";
    panel.lumaField = MDValueField();
    panel.lumaField.delegate = self;
    panel.lumaField.tag = (NSInteger)index;
    panel.lumaField.target = self;
    panel.lumaField.action = @selector(lumaFieldCommitted:);
    panel.exposureLabel = MDLabel(@"at reference", 9.5, NSFontWeightSemibold, MDAmber());
    NSView *lumaRow = [self sliderRowWithTitle:@"Exposure — luma"
                                        slider:panel.lumaSlider
                                         field:panel.lumaField
                                         extra:panel.exposureLabel];
    [exposureBlock addSubview:lumaRow];

    NSStackView *stopStack = [NSStackView stackViewWithViews:@[]];
    stopStack.translatesAutoresizingMaskIntoConstraints = NO;
    stopStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    stopStack.distribution = NSStackViewDistributionFillEqually;
    stopStack.spacing = 5;
    [exposureBlock addSubview:stopStack];

    NSArray<NSString *> *stopTitles = @[@"−1", @"−⅔", @"−⅓", @"+⅓", @"+⅔", @"+1"];
    NSArray<NSNumber *> *stopValues = @[@(-1.0), @(-2.0 / 3.0), @(-1.0 / 3.0), @(1.0 / 3.0), @(2.0 / 3.0), @1.0];
    NSMutableArray<NSButton *> *stopButtons = [NSMutableArray array];
    for (NSUInteger stopIndex = 0; stopIndex < stopTitles.count; ++stopIndex) {
        double stops = stopValues[stopIndex].doubleValue;
        NSButton *button = MDButton([NSString stringWithFormat:@"%@ STOP", stopTitles[stopIndex]],
                                    stops < 0 ? MDCyan() : MDAmber(),
                                    self,
                                    @selector(stopPressed:));
        button.tag = (NSInteger)(index * 100 + stopIndex);
        button.toolTip = [NSString stringWithFormat:
            @"Change emitted light by %.2f stop. Luma is scaled by 2^(stops/%.1f) because the display "
            @"applies a gamma of %.1f — halving the light is not halving the number.",
            stops, kATEMDisplayGamma, kATEMDisplayGamma];
        [stopStack addArrangedSubview:button];
        [stopButtons addObject:button];
    }
    panel.stopButtons = stopButtons;

    NSMutableArray<NSButton *> *presetButtons = [NSMutableArray array];
    NSView *grayscaleRow = [self presetRowWithTitle:@"Grayscale references"
                                            presets:MDGrayscalePresets()
                                             action:@selector(grayscalePresetPressed:)
                                              panel:panel
                                            buttons:presetButtons];
    [panel addSubview:grayscaleRow];
    NSView *barsRow = [self presetRowWithTitle:@"75% colour bars"
                                       presets:MDBarPresets()
                                        action:@selector(barPresetPressed:)
                                         panel:panel
                                       buttons:presetButtons];
    [panel addSubview:barsRow];
    panel.presetButtons = presetButtons;

    NSTextField *routeEyebrow = MDEyebrow(@"Route this generator");
    [panel addSubview:routeEyebrow];
    panel.previewButton = MDButton(@"→ PREVIEW", MDGreen(), self, @selector(routeToPreviewPressed:));
    panel.previewButton.tag = (NSInteger)index;
    panel.previewButton.toolTip = @"Put this colour generator on the Preview bus.";
    [panel addSubview:panel.previewButton];
    panel.programButton = MDButton(@"→ PROGRAM", MDRed(), self, @selector(routeToProgramPressed:));
    panel.programButton.tag = (NSInteger)index;
    panel.programButton.toolTip = @"Cut this colour generator to Program — it goes to air immediately.";
    [panel addSubview:panel.programButton];

    [NSLayoutConstraint activateConstraints:@[
        [panel.widthAnchor constraintGreaterThanOrEqualToConstant:420],

        [panel.titleLabel.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:16],
        [panel.titleLabel.topAnchor constraintEqualToAnchor:panel.topAnchor constant:14],
        [panel.inputLabel.leadingAnchor constraintEqualToAnchor:panel.titleLabel.trailingAnchor constant:10],
        [panel.inputLabel.lastBaselineAnchor constraintEqualToAnchor:panel.titleLabel.lastBaselineAnchor],
        [panel.inputLabel.trailingAnchor constraintLessThanOrEqualToAnchor:panel.trailingAnchor constant:-16],

        [panel.swatch.leadingAnchor constraintEqualToAnchor:panel.leadingAnchor constant:16],
        [panel.swatch.trailingAnchor constraintEqualToAnchor:panel.trailingAnchor constant:-16],
        [panel.swatch.topAnchor constraintEqualToAnchor:panel.titleLabel.bottomAnchor constant:12],
        [panel.swatch.heightAnchor constraintEqualToConstant:92],

        [panel.readoutLabel.leadingAnchor constraintEqualToAnchor:panel.swatch.leadingAnchor],
        [panel.readoutLabel.topAnchor constraintEqualToAnchor:panel.swatch.bottomAnchor constant:8],

        [pickerEyebrow.leadingAnchor constraintEqualToAnchor:panel.swatch.leadingAnchor],
        [pickerEyebrow.topAnchor constraintEqualToAnchor:panel.readoutLabel.bottomAnchor constant:10],
        [panel.colorWell.leadingAnchor constraintEqualToAnchor:panel.swatch.leadingAnchor],
        [panel.colorWell.topAnchor constraintEqualToAnchor:pickerEyebrow.bottomAnchor constant:5],
        [panel.colorWell.widthAnchor constraintEqualToConstant:70],
        [panel.colorWell.heightAnchor constraintEqualToConstant:26],
        [panel.hexField.leadingAnchor constraintEqualToAnchor:panel.colorWell.trailingAnchor constant:8],
        [panel.hexField.centerYAnchor constraintEqualToAnchor:panel.colorWell.centerYAnchor],
        [panel.hexField.widthAnchor constraintEqualToConstant:96],
        [panel.hexField.heightAnchor constraintEqualToConstant:24],

        [hueRow.leadingAnchor constraintEqualToAnchor:panel.swatch.leadingAnchor],
        [hueRow.trailingAnchor constraintEqualToAnchor:panel.swatch.trailingAnchor],
        [hueRow.topAnchor constraintEqualToAnchor:panel.colorWell.bottomAnchor constant:12],
        [saturationRow.leadingAnchor constraintEqualToAnchor:hueRow.leadingAnchor],
        [saturationRow.trailingAnchor constraintEqualToAnchor:hueRow.trailingAnchor],
        [saturationRow.topAnchor constraintEqualToAnchor:hueRow.bottomAnchor constant:10],

        [exposureBlock.leadingAnchor constraintEqualToAnchor:hueRow.leadingAnchor],
        [exposureBlock.trailingAnchor constraintEqualToAnchor:hueRow.trailingAnchor],
        [exposureBlock.topAnchor constraintEqualToAnchor:saturationRow.bottomAnchor constant:14],
        [lumaRow.leadingAnchor constraintEqualToAnchor:exposureBlock.leadingAnchor constant:12],
        [lumaRow.trailingAnchor constraintEqualToAnchor:exposureBlock.trailingAnchor constant:-12],
        [lumaRow.topAnchor constraintEqualToAnchor:exposureBlock.topAnchor constant:10],
        [stopStack.leadingAnchor constraintEqualToAnchor:lumaRow.leadingAnchor],
        [stopStack.trailingAnchor constraintEqualToAnchor:lumaRow.trailingAnchor],
        [stopStack.topAnchor constraintEqualToAnchor:lumaRow.bottomAnchor constant:10],
        [stopStack.heightAnchor constraintEqualToConstant:26],
        [stopStack.bottomAnchor constraintEqualToAnchor:exposureBlock.bottomAnchor constant:-12],

        [grayscaleRow.leadingAnchor constraintEqualToAnchor:hueRow.leadingAnchor],
        [grayscaleRow.trailingAnchor constraintEqualToAnchor:hueRow.trailingAnchor],
        [grayscaleRow.topAnchor constraintEqualToAnchor:exposureBlock.bottomAnchor constant:14],
        [barsRow.leadingAnchor constraintEqualToAnchor:hueRow.leadingAnchor],
        [barsRow.trailingAnchor constraintEqualToAnchor:hueRow.trailingAnchor],
        [barsRow.topAnchor constraintEqualToAnchor:grayscaleRow.bottomAnchor constant:10],

        [routeEyebrow.leadingAnchor constraintEqualToAnchor:hueRow.leadingAnchor],
        [routeEyebrow.topAnchor constraintEqualToAnchor:barsRow.bottomAnchor constant:14],
        [panel.previewButton.leadingAnchor constraintEqualToAnchor:hueRow.leadingAnchor],
        [panel.previewButton.topAnchor constraintEqualToAnchor:routeEyebrow.bottomAnchor constant:5],
        [panel.previewButton.heightAnchor constraintEqualToConstant:28],
        [panel.programButton.leadingAnchor constraintEqualToAnchor:panel.previewButton.trailingAnchor constant:8],
        [panel.programButton.widthAnchor constraintEqualToAnchor:panel.previewButton.widthAnchor],
        [panel.programButton.trailingAnchor constraintEqualToAnchor:hueRow.trailingAnchor],
        [panel.programButton.centerYAnchor constraintEqualToAnchor:panel.previewButton.centerYAnchor],
        [panel.programButton.heightAnchor constraintEqualToAnchor:panel.previewButton.heightAnchor],
        [panel.bottomAnchor constraintEqualToAnchor:panel.previewButton.bottomAnchor constant:16],
    ]];
    return panel;
}

- (void)rebuildPanels:(NSUInteger)count
{
    for (NSView *view in [self.panelStack.arrangedSubviews copy]) {
        [self.panelStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    NSMutableArray<MDColorPanel *> *panels = [NSMutableArray array];
    for (NSUInteger index = 0; index < count; ++index) {
        MDColorPanel *panel = [self panelForIndex:index];
        [panels addObject:panel];
        [self.panelStack addArrangedSubview:panel];
    }
    self.panels = panels;
    self.builtPanelCount = count;
    self.panelStack.hidden = count == 0;
    self.emptyLabel.hidden = count != 0;
}

#pragma mark - Display helpers

- (BOOL)isEditingField:(NSTextField *)field
{
    // AppKit edits through a shared field editor, so the text field itself is
    // never the first responder — the field editor's delegate identifies it.
    NSResponder *responder = field.window.firstResponder;
    return [responder isKindOfClass:[NSTextView class]] &&
           (id)((NSTextView *)responder).delegate == (id)field;
}

- (NSColor *)colorForPanel:(MDColorPanel *)panel
{
    ATEMRGB rgb = ATEMRGBFromHSL(panel.hue, panel.saturation, panel.luma);
    return [NSColor colorWithSRGBRed:rgb.red green:rgb.green blue:rgb.blue alpha:1.0];
}

- (NSString *)hexForPanel:(MDColorPanel *)panel
{
    ATEMRGB rgb = ATEMRGBFromHSL(panel.hue, panel.saturation, panel.luma);
    return [NSString stringWithFormat:@"#%02lX%02lX%02lX",
            (unsigned long)lround(rgb.red * 255.0),
            (unsigned long)lround(rgb.green * 255.0),
            (unsigned long)lround(rgb.blue * 255.0)];
}

- (void)refreshPanelDisplay:(MDColorPanel *)panel
{
    panel.swatch.swatchColor = [self colorForPanel:panel];

    // 10-bit legal-range code value is what an LED-wall processor is metering.
    long codeValue = lround(64.0 + panel.luma * 876.0);
    panel.readoutLabel.stringValue =
        [NSString stringWithFormat:@"H %.1f°   S %.1f%%   LUMA %.1f%%   ·   %@   ·   10-bit %ld",
         panel.hue, panel.saturation * 100.0, panel.luma * 100.0, [self hexForPanel:panel], codeValue];

    if (!panel.hasReference || panel.referenceLuma <= 0.0 || panel.luma <= 0.0) {
        panel.exposureLabel.stringValue = @"no reference";
        panel.exposureLabel.textColor = MDMuted();
    } else {
        double stops = ATEMStopsBetweenLuma(panel.referenceLuma, panel.luma);
        if (std::fabs(stops) < 0.005) {
            panel.exposureLabel.stringValue = @"at reference";
            panel.exposureLabel.textColor = MDMuted();
        } else {
            panel.exposureLabel.stringValue = [NSString stringWithFormat:@"%+.2f stop", stops];
            panel.exposureLabel.textColor = stops < 0 ? MDCyan() : MDAmber();
        }
        panel.exposureLabel.toolTip =
            [NSString stringWithFormat:@"Reference luma %.1f%%. Stops are of emitted light, using a display gamma of %.1f.",
             panel.referenceLuma * 100.0, kATEMDisplayGamma];
    }

    if (![self isEditingField:panel.hueField])
        panel.hueField.stringValue = [NSString stringWithFormat:@"%.1f", panel.hue];
    if (![self isEditingField:panel.saturationField])
        panel.saturationField.stringValue = [NSString stringWithFormat:@"%.1f", panel.saturation * 100.0];
    if (![self isEditingField:panel.lumaField])
        panel.lumaField.stringValue = [NSString stringWithFormat:@"%.1f", panel.luma * 100.0];
    if (![self isEditingField:panel.hexField])
        panel.hexField.stringValue = [self hexForPanel:panel];

    panel.hueSlider.doubleValue = panel.hue;
    panel.saturationSlider.doubleValue = panel.saturation * 100.0;
    panel.lumaSlider.doubleValue = panel.luma * 100.0;
    // Never write into the well while its picker is open — that would fight the
    // operator's own drag inside the macOS colour panel.
    if (!panel.colorWell.isActive)
        panel.colorWell.color = [self colorForPanel:panel];
}

- (void)setPanelEnabled:(MDColorPanel *)panel enabled:(BOOL)enabled
{
    panel.hueSlider.enabled = enabled;
    panel.saturationSlider.enabled = enabled;
    panel.lumaSlider.enabled = enabled;
    panel.hueField.enabled = enabled;
    panel.saturationField.enabled = enabled;
    panel.lumaField.enabled = enabled;
    panel.hexField.enabled = enabled;
    panel.colorWell.enabled = enabled;
    panel.previewButton.enabled = enabled;
    panel.programButton.enabled = enabled;
    for (NSButton *button in panel.stopButtons)
        button.enabled = enabled;
    for (NSButton *button in panel.presetButtons)
        button.enabled = enabled;
}

#pragma mark - State

- (void)applyState:(ATEMState *)state
{
    NSString *sessionName = self.activeSessionIndex == 0 ? @"A" : @"B";
    NSString *product = state.productName.length
        ? state.productName
        : (state.isConnecting ? @"Connecting…" : @"Not connected");
    self.switcherLabel.stringValue = [NSString stringWithFormat:@"ATEM %@ — %@", sessionName, product];
    self.statusLabel.stringValue = state.statusMessage.length
        ? state.statusMessage
        : @"Colour generators are stored on the switcher and stay set after the app quits.";
    self.statusDot.layer.backgroundColor =
        (state.isDemo ? MDViolet() : (state.isConnected ? MDGreen() : MDMuted())).CGColor;


    NSArray<ATEMColorGeneratorState *> *generators = state.colorGenerators;
    if (generators.count != self.builtPanelCount)
        [self rebuildPanels:generators.count];

    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    for (NSUInteger index = 0; index < self.panels.count && index < generators.count; ++index) {
        MDColorPanel *panel = self.panels[index];
        ATEMColorGeneratorState *generator = generators[index];
        panel.inputID = generator.inputID;
        panel.titleLabel.stringValue = generator.name.uppercaseString;
        panel.inputLabel.stringValue = [NSString stringWithFormat:@"input %lld", generator.inputID];
        [self setPanelEnabled:panel enabled:state.isConnected];

        // The switcher acknowledges a Set… call after it returns, so a poll that
        // lands inside the suppression window would drag a slider back under the
        // operator's hand. Keep showing what they asked for until it clears.
        if (now < panel.echoSuppressUntil)
            continue;

        panel.hue = generator.hue;
        panel.saturation = generator.saturation;
        panel.luma = generator.luma;
        if (!panel.hasReference) {
            panel.referenceLuma = generator.luma;
            panel.hasReference = YES;
        }
        [self refreshPanelDisplay:panel];
    }
    [self refreshSessionSelector];
}

- (void)refreshActiveSession
{
    self.builtPanelCount = NSUIntegerMax;  // force a rebuild for the new session
    for (MDColorPanel *panel in self.panels) {
        panel.hasReference = NO;
        panel.echoSuppressUntil = 0;
    }
    [self applyState:self.activeController.latestState];
}

- (void)refreshSessionSelector
{
    for (NSUInteger index = 0; index < MIN(self.controllers.count, 2UL); ++index) {
        ATEMState *state = self.controllers[index].latestState;
        NSString *dot = state.isConnected ? @"●" : (state.isConnecting ? @"◐" : @"○");
        [self.sessionSelector setLabel:[NSString stringWithFormat:@"%@  %@", index == 0 ? @"A" : @"B", dot]
                            forSegment:index];
    }
    self.sessionSelector.selectedSegment = self.activeSessionIndex;
}

- (void)selectSessionIndex:(NSUInteger)sessionIndex
{
    if (sessionIndex >= self.controllers.count)
        return;
    self.activeSessionIndex = sessionIndex;
    self.sessionSelector.selectedSegment = sessionIndex;
    [self refreshActiveSession];
}

- (void)sessionChanged:(NSSegmentedControl *)sender
{
    [self selectSessionIndex:(NSUInteger)sender.selectedSegment];
}

- (void)stateDidChange:(NSNotification *)notification
{
    if (notification.object != self.activeController)
        return;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self applyState:self.activeController.latestState];
    });
}

#pragma mark - Writes

- (MDColorPanel *)panelAtIndex:(NSUInteger)index
{
    return index < self.panels.count ? self.panels[index] : nil;
}

/// Coalesce slider traffic: a continuous drag can fire far faster than the
/// switcher round trip, and every send costs a full state publish.
- (void)schedulePanelSend:(MDColorPanel *)panel
{
    panel.echoSuppressUntil = CFAbsoluteTimeGetCurrent() + 1.0;
    [self refreshPanelDisplay:panel];
    panel.needsSend = YES;
    if (panel.sendScheduled)
        return;
    panel.sendScheduled = YES;
    __weak MediaWindowController *weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 40 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
        MediaWindowController *strongSelf = weakSelf;
        if (!strongSelf)
            return;
        panel.sendScheduled = NO;
        if (!panel.needsSend)
            return;
        panel.needsSend = NO;
        panel.echoSuppressUntil = CFAbsoluteTimeGetCurrent() + 1.0;
        [strongSelf.activeController setColorGenerator:panel.generatorIndex
                                                   hue:panel.hue
                                            saturation:panel.saturation
                                                  luma:panel.luma];
    });
}

/// Choosing the colour itself re-arms the exposure reference, so "+1/3 stop"
/// always reads relative to the colour the operator picked.
- (void)setPanel:(MDColorPanel *)panel
             hue:(double)hue
      saturation:(double)saturation
            luma:(double)luma
     asReference:(BOOL)asReference
{
    panel.hue = ATEMWrapDegrees(hue);
    panel.saturation = ATEMClamp01(saturation);
    panel.luma = ATEMClamp01(luma);
    if (asReference) {
        panel.referenceLuma = panel.luma;
        panel.hasReference = YES;
    }
    [self schedulePanelSend:panel];
}

- (void)hueSliderMoved:(NSSlider *)sender
{
    MDColorPanel *panel = [self panelAtIndex:(NSUInteger)sender.tag];
    if (panel)
        [self setPanel:panel hue:sender.doubleValue saturation:panel.saturation luma:panel.luma asReference:NO];
}

- (void)saturationSliderMoved:(NSSlider *)sender
{
    MDColorPanel *panel = [self panelAtIndex:(NSUInteger)sender.tag];
    if (panel)
        [self setPanel:panel hue:panel.hue saturation:sender.doubleValue / 100.0 luma:panel.luma asReference:NO];
}

- (void)lumaSliderMoved:(NSSlider *)sender
{
    MDColorPanel *panel = [self panelAtIndex:(NSUInteger)sender.tag];
    if (panel)
        [self setPanel:panel hue:panel.hue saturation:panel.saturation luma:sender.doubleValue / 100.0 asReference:NO];
}

- (void)hueFieldCommitted:(NSTextField *)sender
{
    MDColorPanel *panel = [self panelAtIndex:(NSUInteger)sender.tag];
    if (panel)
        [self setPanel:panel hue:sender.doubleValue saturation:panel.saturation luma:panel.luma asReference:NO];
}

- (void)saturationFieldCommitted:(NSTextField *)sender
{
    MDColorPanel *panel = [self panelAtIndex:(NSUInteger)sender.tag];
    if (panel)
        [self setPanel:panel hue:panel.hue saturation:sender.doubleValue / 100.0 luma:panel.luma asReference:NO];
}

- (void)lumaFieldCommitted:(NSTextField *)sender
{
    MDColorPanel *panel = [self panelAtIndex:(NSUInteger)sender.tag];
    if (panel)
        [self setPanel:panel hue:panel.hue saturation:panel.saturation luma:sender.doubleValue / 100.0 asReference:NO];
}

- (void)colorWellChanged:(NSColorWell *)sender
{
    MDColorPanel *panel = [self panelAtIndex:(NSUInteger)sender.tag];
    if (!panel)
        return;
    NSColor *color = [sender.color colorUsingColorSpace:NSColorSpace.sRGBColorSpace];
    if (!color)
        return;
    ATEMHSL hsl = ATEMHSLFromRGB(color.redComponent, color.greenComponent, color.blueComponent);
    [self setPanel:panel hue:hsl.hue saturation:hsl.saturation luma:hsl.luma asReference:YES];
}

- (void)hexCommitted:(NSTextField *)sender
{
    MDColorPanel *panel = [self panelAtIndex:(NSUInteger)sender.tag];
    if (!panel)
        return;
    NSString *text = [sender.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    text = [text stringByReplacingOccurrencesOfString:@"#" withString:@""];
    if (text.length == 3) {
        NSMutableString *expanded = [NSMutableString string];
        for (NSUInteger index = 0; index < 3; ++index) {
            unichar character = [text characterAtIndex:index];
            [expanded appendFormat:@"%C%C", character, character];
        }
        text = expanded;
    }
    unsigned int value = 0;
    if (text.length != 6 || ![[NSScanner scannerWithString:text] scanHexInt:&value]) {
        NSBeep();
        self.statusLabel.stringValue = @"Enter a hex colour such as #808080.";
        [self refreshPanelDisplay:panel];
        return;
    }
    ATEMHSL hsl = ATEMHSLFromRGB(((value >> 16) & 0xFF) / 255.0,
                                 ((value >> 8) & 0xFF) / 255.0,
                                 (value & 0xFF) / 255.0);
    [self setPanel:panel hue:hsl.hue saturation:hsl.saturation luma:hsl.luma asReference:YES];
}

- (void)stopPressed:(NSButton *)sender
{
    NSUInteger panelIndex = (NSUInteger)(sender.tag / 100);
    NSUInteger stopIndex = (NSUInteger)(sender.tag % 100);
    MDColorPanel *panel = [self panelAtIndex:panelIndex];
    if (!panel)
        return;
    static const double stopValues[6] = {-1.0, -2.0 / 3.0, -1.0 / 3.0, 1.0 / 3.0, 2.0 / 3.0, 1.0};
    if (stopIndex >= 6)
        return;
    double stops = stopValues[stopIndex];
    if (panel.luma <= 0.0) {
        NSBeep();
        self.statusLabel.stringValue = @"Black has no light to scale — set a luma above 0% first.";
        return;
    }
    if (panel.luma >= 1.0 && stops > 0.0) {
        NSBeep();
        self.statusLabel.stringValue = @"Already at peak white — there is no headroom left to expose up.";
        return;
    }
    [self setPanel:panel
               hue:panel.hue
        saturation:panel.saturation
              luma:ATEMLumaAfterStops(panel.luma, stops)
       asReference:NO];
}

- (void)grayscalePresetPressed:(NSButton *)sender
{
    NSUInteger panelIndex = (NSUInteger)(sender.tag / 100);
    NSUInteger presetIndex = (NSUInteger)(sender.tag % 100);
    MDColorPanel *panel = [self panelAtIndex:panelIndex];
    NSArray<NSDictionary *> *presets = MDGrayscalePresets();
    if (!panel || presetIndex >= presets.count)
        return;
    // A neutral keeps whatever hue is dialled in; saturation is what makes it gray.
    [self setPanel:panel
               hue:panel.hue
        saturation:0.0
              luma:[presets[presetIndex][@"luma"] doubleValue]
       asReference:YES];
}

- (void)barPresetPressed:(NSButton *)sender
{
    NSUInteger panelIndex = (NSUInteger)(sender.tag / 100);
    NSUInteger presetIndex = (NSUInteger)(sender.tag % 100);
    MDColorPanel *panel = [self panelAtIndex:panelIndex];
    NSArray<NSDictionary *> *presets = MDBarPresets();
    if (!panel || presetIndex >= presets.count)
        return;
    NSDictionary *preset = presets[presetIndex];
    [self setPanel:panel
               hue:[preset[@"hue"] doubleValue]
        saturation:[preset[@"saturation"] doubleValue]
              luma:[preset[@"luma"] doubleValue]
       asReference:YES];
}

- (void)routeToPreviewPressed:(NSButton *)sender
{
    MDColorPanel *panel = [self panelAtIndex:(NSUInteger)sender.tag];
    if (panel && panel.inputID >= 0)
        [self.activeController setPreviewInput:panel.inputID];
}

- (void)routeToProgramPressed:(NSButton *)sender
{
    MDColorPanel *panel = [self panelAtIndex:(NSUInteger)sender.tag];
    if (!panel || panel.inputID < 0)
        return;
    [self.activeController setProgramInput:panel.inputID];
}

@end

#import "ControlSurfaceWindowController.h"

#import "ATEMController.h"


static NSColor *ColorRGB(NSUInteger rgb)
{
    return [NSColor colorWithSRGBRed:((rgb >> 16) & 0xFF) / 255.0
                               green:((rgb >> 8) & 0xFF) / 255.0
                                blue:(rgb & 0xFF) / 255.0
                               alpha:1.0];
}

static NSColor *ThemeCanvas(void)       { return ColorRGB(0x090D12); }
static NSColor *ThemeCanvasRaised(void) { return ColorRGB(0x0E141B); }
static NSColor *ThemePanel(void)        { return ColorRGB(0x151C24); }
static NSColor *ThemePanelRaised(void)  { return ColorRGB(0x1A232D); }
static NSColor *ThemeControl(void)      { return ColorRGB(0x222C37); }
static NSColor *ThemeControlTop(void)   { return ColorRGB(0x2B3744); }
static NSColor *ThemeDivider(void)      { return ColorRGB(0x2C3947); }
static NSColor *ThemeText(void)         { return ColorRGB(0xF2F5F8); }
static NSColor *ThemeSecondary(void)    { return ColorRGB(0xA2ADBA); }
static NSColor *ThemeMuted(void)        { return ColorRGB(0x6F7B88); }
static NSColor *ThemeCyan(void)         { return ColorRGB(0x32C7F3); }
static NSColor *ThemeProgram(void)      { return ColorRGB(0xF3485D); }
static NSColor *ThemePreview(void)      { return ColorRGB(0x31CE7A); }
static NSColor *ThemeAmber(void)        { return ColorRGB(0xF2AE32); }
static NSColor *ThemeViolet(void)       { return ColorRGB(0xB27AF5); }
static NSColor *ThemeLime(void)         { return ColorRGB(0x9BE564); }

static NSColor *Blend(NSColor *color, CGFloat fraction, NSColor *other)
{
    return [color blendedColorWithFraction:fraction ofColor:other] ?: color;
}

static NSTextField *Label(NSString *text, CGFloat size, NSFontWeight weight, NSColor *color)
{
    NSTextField *label = [NSTextField labelWithString:text];
    label.font = [NSFont systemFontOfSize:size weight:weight];
    label.textColor = color;
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    label.allowsDefaultTighteningForTruncation = YES;
    return label;
}

static NSTextField *Eyebrow(NSString *text)
{
    return Label(text.uppercaseString, 9, NSFontWeightSemibold, ThemeMuted());
}

static void StylePopup(NSPopUpButton *popup)
{
    popup.font = [NSFont systemFontOfSize:10.5 weight:NSFontWeightMedium];
    popup.bordered = NO;
    popup.contentTintColor = ThemeText();
    popup.controlSize = NSControlSizeSmall;
    popup.focusRingType = NSFocusRingTypeExterior;
    popup.wantsLayer = YES;
    popup.layer.backgroundColor = ThemeControl().CGColor;
    popup.layer.borderColor = ThemeDivider().CGColor;
    popup.layer.borderWidth = 1;
    popup.layer.cornerRadius = 5;
}

static void StyleCompactField(NSTextField *field)
{
    field.textColor = ThemeText();
    field.backgroundColor = ColorRGB(0x101720);
    field.drawsBackground = YES;
    field.bezeled = NO;
    field.focusRingType = NSFocusRingTypeExterior;
    field.wantsLayer = YES;
    field.layer.cornerRadius = 6;
    field.layer.borderColor = ThemeDivider().CGColor;
    field.layer.borderWidth = 1;
}

static void RemoveAllArrangedSubviews(NSStackView *stack)
{
    for (NSView *view in stack.arrangedSubviews.copy) {
        [stack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
}

static NSInteger MultiviewControlTag(NSUInteger multiview, NSUInteger window)
{
    return (NSInteger)(((multiview & 0x7FFFU) << 16) | (window & 0xFFFFU));
}

static NSUInteger MultiviewIndexFromTag(NSInteger tag)
{
    return ((NSUInteger)tag >> 16) & 0x7FFFU;
}

static NSUInteger MultiviewWindowFromTag(NSInteger tag)
{
    return (NSUInteger)tag & 0xFFFFU;
}


@interface ATEMCanvasView : NSView
@end

@implementation ATEMCanvasView
- (void)drawRect:(NSRect)dirtyRect
{
    (void)dirtyRect;
    NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:ThemeCanvasRaised()
                                                         endingColor:ThemeCanvas()];
    [gradient drawInRect:self.bounds angle:-90];
}
@end


@interface ATEMHeaderView : NSView
@end

@implementation ATEMHeaderView
- (void)drawRect:(NSRect)dirtyRect
{
    (void)dirtyRect;
    NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:ColorRGB(0x17202A)
                                                         endingColor:ColorRGB(0x0D1218)];
    [gradient drawInRect:self.bounds angle:-90];

    [ThemeCanvas() setFill];
    NSRectFill(NSMakeRect(0, 0, NSWidth(self.bounds), 30));
    [ThemeDivider() setFill];
    NSRectFill(NSMakeRect(0, 29, NSWidth(self.bounds), 1));
    [ThemeCyan() setFill];
    NSRectFill(NSMakeRect(0, 0, 3, NSHeight(self.bounds)));
}
@end


@interface ATEMControlButton : NSButton
@property(nonatomic, getter=isActive) BOOL active;
@property(nonatomic, strong) NSColor *activeColor;
@property(nonatomic, strong) NSColor *idleColor;
@property(nonatomic) CGFloat cornerRadius;
@property(nonatomic) BOOL fillsWhenActive;
@property(nonatomic) BOOL hovered;
@property(nonatomic, strong) NSTrackingArea *hoverTrackingArea;
@end

@implementation ATEMControlButton

- (instancetype)initWithTitle:(NSString *)title target:(id)target action:(SEL)action
{
    self = [super initWithFrame:NSZeroRect];
    if (self) {
        self.title = title;
        self.target = target;
        self.action = action;
        self.bordered = NO;
        self.buttonType = NSButtonTypeMomentaryChange;
        self.font = [NSFont systemFontOfSize:10.5 weight:NSFontWeightSemibold];
        self.idleColor = ThemeControl();
        self.activeColor = ThemeCyan();
        self.cornerRadius = 7;
        self.fillsWhenActive = YES;
        self.translatesAutoresizingMaskIntoConstraints = NO;
        [self.heightAnchor constraintGreaterThanOrEqualToConstant:36].active = YES;
        self.accessibilityLabel = title;
    }
    return self;
}

- (void)updateTrackingAreas
{
    [super updateTrackingAreas];
    if (self.hoverTrackingArea)
        [self removeTrackingArea:self.hoverTrackingArea];
    self.hoverTrackingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect
                                                          options:(NSTrackingMouseEnteredAndExited |
                                                                   NSTrackingActiveInActiveApp |
                                                                   NSTrackingInVisibleRect)
                                                            owner:self
                                                         userInfo:nil];
    [self addTrackingArea:self.hoverTrackingArea];
}

- (void)mouseEntered:(NSEvent *)event
{
    (void)event;
    self.hovered = YES;
    [self setNeedsDisplay:YES];
}

- (void)mouseExited:(NSEvent *)event
{
    (void)event;
    self.hovered = NO;
    [self setNeedsDisplay:YES];
}

- (void)setActive:(BOOL)active
{
    if (_active == active)
        return;
    _active = active;
    self.accessibilityValue = @(active);
    NSAccessibilityPostNotification(self, NSAccessibilityValueChangedNotification);
    [self setNeedsDisplay:YES];
}

- (void)setEnabled:(BOOL)enabled
{
    [super setEnabled:enabled];
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect
{
    (void)dirtyRect;
    NSRect bounds = NSInsetRect(self.bounds, 0.75, 0.75);
    BOOL activeFill = self.isActive && self.fillsWhenActive;
    NSColor *top = activeFill ? Blend(self.activeColor, 0.12, NSColor.whiteColor) : ThemeControlTop();
    NSColor *bottom = activeFill ? Blend(self.activeColor, 0.22, NSColor.blackColor) : self.idleColor;
    if (self.hovered && self.isEnabled && !activeFill) {
        top = Blend(top, 0.10, NSColor.whiteColor);
        bottom = Blend(bottom, 0.07, NSColor.whiteColor);
    }
    if (self.isHighlighted) {
        top = Blend(top, 0.16, NSColor.blackColor);
        bottom = Blend(bottom, 0.22, NSColor.blackColor);
    }
    if (!self.isEnabled) {
        top = [top colorWithAlphaComponent:0.38];
        bottom = [bottom colorWithAlphaComponent:0.38];
    }

    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:bounds
                                                        xRadius:self.cornerRadius
                                                        yRadius:self.cornerRadius];
    NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:top endingColor:bottom];
    [gradient drawInBezierPath:path angle:-90];

    NSColor *border = self.isActive
        ? [self.activeColor colorWithAlphaComponent:self.isEnabled ? 0.88 : 0.30]
        : [NSColor colorWithWhite:1 alpha:self.hovered ? 0.18 : 0.10];
    [border setStroke];
    path.lineWidth = 1;
    [path stroke];

    if (self.window.firstResponder == self) {
        [[ThemeCyan() colorWithAlphaComponent:0.82] setStroke];
        NSBezierPath *focus = [NSBezierPath bezierPathWithRoundedRect:NSInsetRect(bounds, 2, 2)
                                                              xRadius:MAX(2, self.cornerRadius - 2)
                                                              yRadius:MAX(2, self.cornerRadius - 2)];
        focus.lineWidth = 1.5;
        [focus stroke];
    }

    if (self.isActive) {
        NSColor *signalColor = activeFill ? [NSColor colorWithWhite:1 alpha:0.52] : self.activeColor;
        [signalColor setFill];
        NSRect railRect = NSMakeRect(NSMinX(bounds) + 7,
                                     NSMinY(bounds) + 1.5,
                                     MAX(0, NSWidth(bounds) - 14),
                                     2);
        [[NSBezierPath bezierPathWithRoundedRect:railRect xRadius:1 yRadius:1] fill];
    }

    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.alignment = NSTextAlignmentCenter;
    NSColor *textColor = ThemeText();
    if (self.isActive && !activeFill)
        textColor = self.activeColor;
    if (!self.isEnabled)
        textColor = [ThemeSecondary() colorWithAlphaComponent:0.40];
    NSDictionary *attributes = @{
        NSFontAttributeName: self.font ?: [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: textColor,
        NSParagraphStyleAttributeName: paragraph,
    };
    NSSize textSize = [self.title sizeWithAttributes:attributes];
    NSRect textRect = NSMakeRect(5,
                                 floor((NSHeight(self.bounds) - textSize.height) / 2.0),
                                 MAX(0, NSWidth(self.bounds) - 10),
                                 textSize.height + 2);
    [self.title drawInRect:textRect withAttributes:attributes];
}

@end


@interface ATEMInputButton : ATEMControlButton
@property(nonatomic) int64_t inputID;
@end
@implementation ATEMInputButton
@end


@interface ATEMIndexedButton : ATEMControlButton
@property(nonatomic) NSUInteger itemIndex;
@end
@implementation ATEMIndexedButton
@end


@interface ATEMCardView : NSView
@property(nonatomic, strong) NSColor *accentColor;
@end

@implementation ATEMCardView
- (instancetype)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        self.wantsLayer = YES;
        self.layer.backgroundColor = NSColor.clearColor.CGColor;
        self.accentColor = ThemeCyan();
    }
    return self;
}

- (void)setAccentColor:(NSColor *)accentColor
{
    _accentColor = accentColor;
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect
{
    (void)dirtyRect;
    NSRect bounds = NSInsetRect(self.bounds, 0.5, 0.5);
    NSBezierPath *panel = [NSBezierPath bezierPathWithRoundedRect:bounds xRadius:9 yRadius:9];
    NSGradient *gradient = [[NSGradient alloc] initWithStartingColor:ThemePanelRaised()
                                                         endingColor:ThemePanel()];
    [gradient drawInBezierPath:panel angle:-90];
    [ThemeDivider() setStroke];
    panel.lineWidth = 1;
    [panel stroke];

    [[self.accentColor colorWithAlphaComponent:0.95] setFill];
    NSRect accent = NSMakeRect(NSMinX(bounds) + 15, NSMaxY(bounds) - 2.5, 42, 2);
    [[NSBezierPath bezierPathWithRoundedRect:accent xRadius:1 yRadius:1] fill];
}
@end


@interface ControlSurfaceWindowController () <NSTextFieldDelegate>
@property(nonatomic, copy) NSArray<ATEMController *> *controllers;
@property(nonatomic, strong) NSMutableArray<ATEMState *> *sessionStates;
@property(nonatomic) NSUInteger activeSessionIndex;
@property(nonatomic, strong) ATEMState *state;

@property(nonatomic, strong) NSSegmentedControl *sessionSelector;
@property(nonatomic, strong) NSTextField *productLabel;
@property(nonatomic, strong) NSTextField *statusLabel;
@property(nonatomic, strong) NSView *statusDot;
@property(nonatomic, strong) NSTextField *addressField;
@property(nonatomic, strong) ATEMControlButton *connectButton;
@property(nonatomic, strong) ATEMControlButton *demoButton;

@property(nonatomic, strong) NSScrollView *programScroll;
@property(nonatomic, strong) NSScrollView *previewScroll;
@property(nonatomic, strong) NSStackView *programStack;
@property(nonatomic, strong) NSStackView *previewStack;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, ATEMInputButton *> *programButtons;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, ATEMInputButton *> *previewButtons;
@property(nonatomic, copy) NSString *inputSignature;
@property(nonatomic, strong) NSScrollView *contentScroll;

@property(nonatomic, strong) NSArray<ATEMControlButton *> *styleButtons;
@property(nonatomic, strong) NSArray<ATEMControlButton *> *selectionButtons;
@property(nonatomic, strong) NSTextField *rateField;
@property(nonatomic, strong) NSStepper *rateStepper;
/// Wall-clock deadline before which polled state must not overwrite the RATE
/// controls. Without it the 250 ms poll snaps the field back to the pre-write
/// value while the switcher round-trip is still in flight.
@property(nonatomic) NSTimeInterval rateEchoSuppressUntil;
@property(nonatomic, strong) NSStackView *upstreamKeyStack;
@property(nonatomic, strong) NSMutableArray<ATEMIndexedButton *> *upstreamKeyButtons;

@property(nonatomic, strong) ATEMControlButton *cutButton;
@property(nonatomic, strong) ATEMControlButton *autoButton;
@property(nonatomic, strong) ATEMControlButton *ftbButton;
@property(nonatomic, strong) NSSlider *tBar;
@property(nonatomic, strong) NSTextField *framesLabel;

@property(nonatomic, strong) NSStackView *dskStack;
@property(nonatomic, strong) NSMutableArray<ATEMIndexedButton *> *dskTieButtons;
@property(nonatomic, strong) NSMutableArray<ATEMIndexedButton *> *dskOnAirButtons;
@property(nonatomic, strong) NSMutableArray<ATEMIndexedButton *> *dskAutoButtons;

@property(nonatomic, strong) ATEMCardView *auxCard;
@property(nonatomic, strong) NSStackView *auxStack;
@property(nonatomic, strong) NSMutableArray<NSPopUpButton *> *auxPopups;

@property(nonatomic, strong) NSPopUpButton *videoFormatPopup;
@property(nonatomic, strong) NSPopUpButton *videoRatePopup;
@property(nonatomic, strong) ATEMControlButton *videoApplyButton;
@property(nonatomic, strong) NSTextField *videoModeLabel;
@property(nonatomic, copy) NSArray<ATEMVideoModeOption *> *videoModeOptions;
@property(nonatomic, copy) NSString *videoModeSignature;
/// Last switcher video mode pushed into the popups. Sentinel forces a resync.
@property(nonatomic) uint32_t syncedVideoMode;

@property(nonatomic, strong) ATEMCardView *multiviewCard;
@property(nonatomic, strong) NSStackView *multiviewStack;
@property(nonatomic, strong) NSLayoutConstraint *multiviewHeightConstraint;
@property(nonatomic, copy) NSString *multiviewSignature;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, NSPopUpButton *> *multiviewLayoutPopups;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, NSArray<ATEMControlButton *> *> *multiviewQuadrantButtons;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, ATEMControlButton *> *multiviewSwapButtons;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, NSSlider *> *multiviewOpacitySliders;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, ATEMControlButton *> *multiviewAllLabelButtons;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, ATEMControlButton *> *multiviewAllBorderButtons;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, NSPopUpButton *> *multiviewSourcePopups;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, NSButton *> *multiviewVUButtons;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, NSButton *> *multiviewSafeButtons;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, NSButton *> *multiviewLabelButtons;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, NSButton *> *multiviewBorderButtons;

@property(nonatomic, strong) NSMutableArray<NSControl *> *requiresConnection;
@end


@implementation ControlSurfaceWindowController

- (instancetype)initWithControllers:(NSArray<ATEMController *> *)controllers
{
    NSParameterAssert(controllers.count == 2);
    NSRect frame = NSMakeRect(0, 0, 1320, 860);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                  styleMask:(NSWindowStyleMaskTitled |
                                                             NSWindowStyleMaskClosable |
                                                             NSWindowStyleMaskMiniaturizable |
                                                             NSWindowStyleMaskResizable)
                                                    backing:NSBackingStoreBuffered
                                                      defer:NO];
    window.title = @"ATEM CNTRL";
    window.minSize = NSMakeSize(1080, 700);
    window.backgroundColor = ThemeCanvas();
    window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    window.titlebarAppearsTransparent = YES;
    window.titleVisibility = NSWindowTitleHidden;
    window.tabbingMode = NSWindowTabbingModeDisallowed;
    window.sharingType = NSWindowSharingReadOnly;
    [window center];
    [window setFrameAutosaveName:@"ATEMEditMainWindow"];

    self = [super initWithWindow:window];
    if (self) {
        _controllers = [controllers copy];
        _sessionStates = [NSMutableArray arrayWithCapacity:controllers.count];
        for (ATEMController *controller in controllers)
            [_sessionStates addObject:controller.latestState];
        _activeSessionIndex = 0;
        _programButtons = [NSMutableDictionary dictionary];
        _previewButtons = [NSMutableDictionary dictionary];
        _upstreamKeyButtons = [NSMutableArray array];
        _dskTieButtons = [NSMutableArray array];
        _dskOnAirButtons = [NSMutableArray array];
        _dskAutoButtons = [NSMutableArray array];
        _auxPopups = [NSMutableArray array];
        _multiviewLayoutPopups = [NSMutableDictionary dictionary];
        _multiviewQuadrantButtons = [NSMutableDictionary dictionary];
        _multiviewSwapButtons = [NSMutableDictionary dictionary];
        _multiviewOpacitySliders = [NSMutableDictionary dictionary];
        _multiviewAllLabelButtons = [NSMutableDictionary dictionary];
        _multiviewAllBorderButtons = [NSMutableDictionary dictionary];
        _multiviewSourcePopups = [NSMutableDictionary dictionary];
        _multiviewVUButtons = [NSMutableDictionary dictionary];
        _multiviewSafeButtons = [NSMutableDictionary dictionary];
        _multiviewLabelButtons = [NSMutableDictionary dictionary];
        _multiviewBorderButtons = [NSMutableDictionary dictionary];
        _requiresConnection = [NSMutableArray array];
        [self buildInterface];

        __weak ControlSurfaceWindowController *weakSelf = self;
        [controllers enumerateObjectsUsingBlock:^(ATEMController *controller, NSUInteger index, BOOL *stop) {
            (void)stop;
            controller.stateHandler = ^(ATEMState *state) {
                [weakSelf receivedState:state forSession:index];
            };
        }];
        [self updateSessionSelector];
        [self applyState:self.sessionStates.firstObject];
    }
    return self;
}

- (ATEMController *)activeController
{
    return self.controllers[self.activeSessionIndex];
}

- (NSString *)addressDefaultsKeyForSession:(NSUInteger)index
{
    return [NSString stringWithFormat:@"lastSwitcherAddress.%lu", (unsigned long)index];
}

- (NSString *)savedAddressForSession:(NSUInteger)index
{
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    NSString *address = [defaults stringForKey:[self addressDefaultsKeyForSession:index]];
    if (address.length == 0 && index == 0)
        address = [defaults stringForKey:@"lastSwitcherAddress"];
    return address ?: @"";
}

- (void)saveAddressForActiveSession
{
    NSString *address = [self.addressField.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    [NSUserDefaults.standardUserDefaults setObject:address forKey:[self addressDefaultsKeyForSession:self.activeSessionIndex]];
}

- (void)receivedState:(ATEMState *)state forSession:(NSUInteger)index
{
    NSAssert(NSThread.isMainThread, @"Session state must arrive on the main thread");
    if (!state || index >= self.sessionStates.count)
        return;
    self.sessionStates[index] = state;
    [self updateSessionSelector];
    if (index == self.activeSessionIndex)
        [self applyState:state];
}

- (void)updateSessionSelector
{
    if (!self.sessionSelector)
        return;
    [self.sessionStates enumerateObjectsUsingBlock:^(ATEMState *state, NSUInteger index, BOOL *stop) {
        (void)stop;
        NSString *letter = index == 0 ? @"A" : @"B";
        NSString *indicator = state.isConnected ? @"●" : (state.isConnecting ? @"…" : @"○");
        [self.sessionSelector setLabel:[NSString stringWithFormat:@"%@  %@", letter, indicator] forSegment:index];
    }];
    self.sessionSelector.selectedSegment = self.activeSessionIndex;
}

- (void)selectSessionIndex:(NSUInteger)index
{
    self.sessionSelector.selectedSegment = index;
    [self sessionChanged:self.sessionSelector];
}

- (void)sessionChanged:(NSSegmentedControl *)sender
{
    NSInteger selected = sender.selectedSegment;
    if (selected < 0 || (NSUInteger)selected >= self.controllers.count || (NSUInteger)selected == self.activeSessionIndex)
        return;
    [self saveAddressForActiveSession];
    self.activeSessionIndex = (NSUInteger)selected;
    self.addressField.stringValue = [self savedAddressForSession:self.activeSessionIndex];
    self.state = nil;
    self.inputSignature = nil;
    self.multiviewSignature = nil;
    // The other switcher may run a different standard and support a different set.
    self.videoModeSignature = nil;
    self.syncedVideoMode = UINT32_MAX;
    self.rateEchoSuppressUntil = 0;
    [self updateSessionSelector];
    [self applyState:self.sessionStates[self.activeSessionIndex]];
}

- (ATEMCardView *)cardWithTitle:(NSString *)title
                    accentColor:(NSColor *)accentColor
                        content:(NSStackView * __strong *)content
{
    ATEMCardView *card = [[ATEMCardView alloc] initWithFrame:NSZeroRect];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    card.accentColor = accentColor ?: ThemeCyan();

    NSTextField *heading = Label(title.uppercaseString, 10.5, NSFontWeightSemibold, ThemeSecondary());
    heading.translatesAutoresizingMaskIntoConstraints = NO;
    [card addSubview:heading];

    NSStackView *stack = [[NSStackView alloc] initWithFrame:NSZeroRect];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.orientation = NSUserInterfaceLayoutOrientationVertical;
    stack.alignment = NSLayoutAttributeLeading;
    stack.spacing = 8;
    [card addSubview:stack];

    [NSLayoutConstraint activateConstraints:@[
        [heading.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [heading.trailingAnchor constraintLessThanOrEqualToAnchor:card.trailingAnchor constant:-16],
        [heading.topAnchor constraintEqualToAnchor:card.topAnchor constant:13],
        [stack.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:16],
        [stack.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-16],
        [stack.topAnchor constraintEqualToAnchor:heading.bottomAnchor constant:9],
        [stack.bottomAnchor constraintLessThanOrEqualToAnchor:card.bottomAnchor constant:-14],
    ]];
    if (content)
        *content = stack;
    return card;
}

- (void)buildInterface
{
    NSView *root = [[ATEMCanvasView alloc] initWithFrame:self.window.contentView.bounds];
    root.translatesAutoresizingMaskIntoConstraints = NO;
    root.wantsLayer = YES;
    self.window.contentView = root;

    NSView *header = [self buildHeader];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:header];

    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.drawsBackground = NO;
    scroll.hasVerticalScroller = YES;
    scroll.autohidesScrollers = YES;
    scroll.borderType = NSNoBorder;
    self.contentScroll = scroll;
    [root addSubview:scroll];

    NSView *document = [[NSView alloc] initWithFrame:NSZeroRect];
    document.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.documentView = document;

    NSStackView *body = [[NSStackView alloc] initWithFrame:NSZeroRect];
    body.translatesAutoresizingMaskIntoConstraints = NO;
    body.orientation = NSUserInterfaceLayoutOrientationVertical;
    body.alignment = NSLayoutAttributeLeading;
    body.spacing = 12;
    body.edgeInsets = NSEdgeInsetsMake(14, 16, 20, 16);
    [document addSubview:body];

    NSView *buses = [self buildBusesCard];
    [body addArrangedSubview:buses];
    [buses.widthAnchor constraintEqualToAnchor:body.widthAnchor constant:-32].active = YES;
    [buses.heightAnchor constraintEqualToConstant:180].active = YES;

    NSStackView *controlRow = [[NSStackView alloc] initWithFrame:NSZeroRect];
    controlRow.translatesAutoresizingMaskIntoConstraints = NO;
    controlRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    controlRow.alignment = NSLayoutAttributeTop;
    controlRow.distribution = NSStackViewDistributionFill;
    controlRow.spacing = 12;
    [body addArrangedSubview:controlRow];
    [controlRow.widthAnchor constraintEqualToAnchor:body.widthAnchor constant:-32].active = YES;
    [controlRow.heightAnchor constraintEqualToConstant:292].active = YES;

    NSView *nextTransition = [self buildNextTransitionCard];
    NSView *transition = [self buildTransitionCard];
    NSView *tbar = [self buildTBarCard];
    NSView *dsk = [self buildDownstreamKeyCard];
    [controlRow addArrangedSubview:nextTransition];
    [controlRow addArrangedSubview:transition];
    [controlRow addArrangedSubview:tbar];
    [controlRow addArrangedSubview:dsk];
    [nextTransition.widthAnchor constraintEqualToConstant:270].active = YES;
    [transition.widthAnchor constraintEqualToConstant:250].active = YES;
    [tbar.widthAnchor constraintEqualToConstant:112].active = YES;
    [dsk.widthAnchor constraintGreaterThanOrEqualToConstant:360].active = YES;

    NSView *videoStandard = [self buildVideoStandardCard];
    [body addArrangedSubview:videoStandard];
    [videoStandard.widthAnchor constraintEqualToAnchor:body.widthAnchor constant:-32].active = YES;
    [videoStandard.heightAnchor constraintEqualToConstant:104].active = YES;

    self.auxCard = (ATEMCardView *)[self buildAuxCard];
    [body addArrangedSubview:self.auxCard];
    [self.auxCard.widthAnchor constraintEqualToAnchor:body.widthAnchor constant:-32].active = YES;
    [self.auxCard.heightAnchor constraintEqualToConstant:128].active = YES;

    self.multiviewCard = (ATEMCardView *)[self buildMultiviewCard];
    [body addArrangedSubview:self.multiviewCard];
    [self.multiviewCard.widthAnchor constraintEqualToAnchor:body.widthAnchor constant:-32].active = YES;
    self.multiviewHeightConstraint = [self.multiviewCard.heightAnchor constraintEqualToConstant:138];
    self.multiviewHeightConstraint.active = YES;

    NSView *notice = [self buildSafetyNotice];
    [body addArrangedSubview:notice];
    [notice.widthAnchor constraintEqualToAnchor:body.widthAnchor constant:-32].active = YES;
    [notice.heightAnchor constraintGreaterThanOrEqualToConstant:62].active = YES;

    [NSLayoutConstraint activateConstraints:@[
        [header.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [header.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [header.topAnchor constraintEqualToAnchor:root.topAnchor],
        [header.heightAnchor constraintEqualToConstant:98],

        [scroll.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:header.bottomAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:root.bottomAnchor],

        [document.leadingAnchor constraintEqualToAnchor:scroll.contentView.leadingAnchor],
        [document.trailingAnchor constraintEqualToAnchor:scroll.contentView.trailingAnchor],
        [document.topAnchor constraintEqualToAnchor:scroll.contentView.topAnchor],
        [document.widthAnchor constraintEqualToAnchor:scroll.contentView.widthAnchor],

        [body.leadingAnchor constraintEqualToAnchor:document.leadingAnchor],
        [body.trailingAnchor constraintEqualToAnchor:document.trailingAnchor],
        [body.topAnchor constraintEqualToAnchor:document.topAnchor],
        [body.bottomAnchor constraintEqualToAnchor:document.bottomAnchor],
    ]];
}

- (void)scrollMultiviewIntoView
{
    [self.window.contentView layoutSubtreeIfNeeded];
    [self.multiviewCard scrollRectToVisible:self.multiviewCard.bounds];
    [self.contentScroll reflectScrolledClipView:self.contentScroll.contentView];
    [self.window.contentView layoutSubtreeIfNeeded];
}

- (NSView *)buildHeader
{
    NSView *header = [[ATEMHeaderView alloc] initWithFrame:NSZeroRect];
    header.wantsLayer = YES;

    NSString *logoPath = [NSBundle.mainBundle pathForResource:@"Nexus-SignalN" ofType:@"png"];
    NSImageView *brandLogo = [[NSImageView alloc] initWithFrame:NSZeroRect];
    brandLogo.translatesAutoresizingMaskIntoConstraints = NO;
    brandLogo.image = [[NSImage alloc] initWithContentsOfFile:logoPath];
    brandLogo.imageScaling = NSImageScaleProportionallyUpOrDown;
    brandLogo.imageFrameStyle = NSImageFrameNone;
    brandLogo.accessibilityLabel = @"Nexus Signal N logo";
    [header addSubview:brandLogo];

    NSTextField *appTitle = Label(@"SWITCHER", 20, NSFontWeightSemibold, ThemeText());
    appTitle.translatesAutoresizingMaskIntoConstraints = NO;
    NSMutableAttributedString *wordmark = [[NSMutableAttributedString alloc] initWithString:@"SWITCHER"];
    [wordmark addAttributes:@{
        NSFontAttributeName: [NSFont systemFontOfSize:20 weight:NSFontWeightSemibold],
        NSKernAttributeName: @0.7,
        NSForegroundColorAttributeName: ThemeText(),
    } range:NSMakeRange(0, wordmark.length)];
    appTitle.attributedStringValue = wordmark;
    [header addSubview:appTitle];
    NSTextField *subtitle = Label(@"LIVE SWITCHER CONSOLE", 9, NSFontWeightMedium, ThemeMuted());
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:subtitle];

    NSTextField *targetLabel = Eyebrow(@"Control target");
    targetLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:targetLabel];

    self.sessionSelector = [NSSegmentedControl segmentedControlWithLabels:@[@"A  ○", @"B  ○"]
                                                              trackingMode:NSSegmentSwitchTrackingSelectOne
                                                                    target:self
                                                                    action:@selector(sessionChanged:)];
    self.sessionSelector.translatesAutoresizingMaskIntoConstraints = NO;
    self.sessionSelector.selectedSegment = 0;
    self.sessionSelector.segmentStyle = NSSegmentStyleCapsule;
    self.sessionSelector.selectedSegmentBezelColor = ThemeCyan();
    self.sessionSelector.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
    self.sessionSelector.toolTip = @"Control target. Both ATEM sessions remain connected when you switch views.";
    self.sessionSelector.accessibilityLabel = @"Active ATEM session";
    [header addSubview:self.sessionSelector];

    NSTextField *identityLabel = Eyebrow(@"Active switcher");
    identityLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:identityLabel];

    self.statusDot = [[NSView alloc] initWithFrame:NSZeroRect];
    self.statusDot.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusDot.wantsLayer = YES;
    self.statusDot.layer.cornerRadius = 4;
    self.statusDot.layer.backgroundColor = ThemeMuted().CGColor;
    [header addSubview:self.statusDot];

    self.productLabel = Label(@"Not connected", 12.5, NSFontWeightSemibold, ThemeText());
    self.productLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:self.productLabel];

    NSTextField *addressLabel = Eyebrow(@"Switcher address");
    addressLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:addressLabel];

    self.addressField = [[NSTextField alloc] initWithFrame:NSZeroRect];
    self.addressField.translatesAutoresizingMaskIntoConstraints = NO;
    self.addressField.placeholderString = @"Switcher IP or hostname";
    self.addressField.stringValue = [self savedAddressForSession:self.activeSessionIndex];
    self.addressField.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
    self.addressField.textColor = ThemeText();
    self.addressField.backgroundColor = ColorRGB(0x101720);
    self.addressField.drawsBackground = YES;
    self.addressField.bezeled = NO;
    self.addressField.focusRingType = NSFocusRingTypeExterior;
    self.addressField.wantsLayer = YES;
    self.addressField.layer.cornerRadius = 7;
    self.addressField.layer.borderColor = ThemeDivider().CGColor;
    self.addressField.layer.borderWidth = 1;
    self.addressField.delegate = self;
    [header addSubview:self.addressField];

    self.connectButton = [[ATEMControlButton alloc] initWithTitle:@"CONNECT" target:self action:@selector(connectPressed:)];
    self.connectButton.activeColor = ThemeCyan();
    self.connectButton.fillsWhenActive = NO;
    [header addSubview:self.connectButton];
    self.demoButton = [[ATEMControlButton alloc] initWithTitle:@"DEMO" target:self action:@selector(demoPressed:)];
    self.demoButton.activeColor = ThemeViolet();
    self.demoButton.fillsWhenActive = NO;
    [header addSubview:self.demoButton];

    NSTextField *statusPrefix = Eyebrow(@"Status");
    statusPrefix.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:statusPrefix];
    self.statusLabel = Label(@"", 10.5, NSFontWeightRegular, ThemeSecondary());
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusLabel.lineBreakMode = NSLineBreakByTruncatingMiddle;
    [header addSubview:self.statusLabel];

    ATEMControlButton *audioButton = [[ATEMControlButton alloc] initWithTitle:@"AUDIO"
                                                                      target:self
                                                                      action:@selector(featurePressed:)];
    audioButton.tag = 0;
    audioButton.activeColor = ThemeCyan();
    audioButton.fillsWhenActive = NO;
    audioButton.toolTip = @"Open the dedicated Fairlight audio mixer window.";
    [header addSubview:audioButton];
    ATEMControlButton *colorButton = [[ATEMControlButton alloc] initWithTitle:@"COLOR"
                                                                      target:self
                                                                      action:@selector(featurePressed:)];
    colorButton.tag = 1;
    colorButton.activeColor = ThemeViolet();
    colorButton.fillsWhenActive = NO;
    colorButton.toolTip = @"Open isolated camera color control.";
    [header addSubview:colorButton];
    ATEMControlButton *hyperDeckButton = [[ATEMControlButton alloc] initWithTitle:@"HYPERDECK"
                                                                          target:self
                                                                          action:@selector(featurePressed:)];
    hyperDeckButton.tag = 2;
    hyperDeckButton.activeColor = ThemeAmber();
    hyperDeckButton.fillsWhenActive = NO;
    hyperDeckButton.toolTip = @"Configure and control HyperDecks through the active ATEM.";
    [header addSubview:hyperDeckButton];
    ATEMControlButton *labelsButton = [[ATEMControlButton alloc] initWithTitle:@"LABELS"
                                                                       target:self
                                                                       action:@selector(featurePressed:)];
    labelsButton.tag = 3;
    labelsButton.activeColor = ThemePreview();
    labelsButton.fillsWhenActive = NO;
    labelsButton.toolTip = @"Edit switcher-stored input and output labels.";
    [header addSubview:labelsButton];
    ATEMControlButton *mediaButton = [[ATEMControlButton alloc] initWithTitle:@"MEDIA"
                                                                      target:self
                                                                      action:@selector(featurePressed:)];
    mediaButton.tag = 4;
    mediaButton.activeColor = ThemeLime();
    mediaButton.fillsWhenActive = NO;
    mediaButton.toolTip = @"Set the colour generators and ride their exposure.";
    [header addSubview:mediaButton];

    [NSLayoutConstraint activateConstraints:@[
        [brandLogo.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:18],
        [brandLogo.topAnchor constraintEqualToAnchor:header.topAnchor constant:10],
        [brandLogo.widthAnchor constraintEqualToConstant:46],
        [brandLogo.heightAnchor constraintEqualToConstant:46],
        [appTitle.leadingAnchor constraintEqualToAnchor:brandLogo.trailingAnchor constant:8],
        [appTitle.topAnchor constraintEqualToAnchor:header.topAnchor constant:11],
        [subtitle.leadingAnchor constraintEqualToAnchor:appTitle.leadingAnchor],
        [subtitle.topAnchor constraintEqualToAnchor:appTitle.bottomAnchor constant:0],

        [targetLabel.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:220],
        [targetLabel.topAnchor constraintEqualToAnchor:header.topAnchor constant:11],
        [self.sessionSelector.leadingAnchor constraintEqualToAnchor:targetLabel.leadingAnchor],
        [self.sessionSelector.topAnchor constraintEqualToAnchor:header.topAnchor constant:27],
        [self.sessionSelector.widthAnchor constraintEqualToConstant:138],
        [self.sessionSelector.heightAnchor constraintEqualToConstant:32],

        [identityLabel.leadingAnchor constraintEqualToAnchor:self.sessionSelector.trailingAnchor constant:22],
        [identityLabel.topAnchor constraintEqualToAnchor:targetLabel.topAnchor],
        [self.statusDot.leadingAnchor constraintEqualToAnchor:identityLabel.leadingAnchor],
        [self.statusDot.centerYAnchor constraintEqualToAnchor:self.productLabel.centerYAnchor],
        [self.statusDot.widthAnchor constraintEqualToConstant:8],
        [self.statusDot.heightAnchor constraintEqualToConstant:8],
        [self.productLabel.leadingAnchor constraintEqualToAnchor:self.statusDot.trailingAnchor constant:8],
        [self.productLabel.topAnchor constraintEqualToAnchor:header.topAnchor constant:31],
        [self.productLabel.trailingAnchor constraintLessThanOrEqualToAnchor:addressLabel.leadingAnchor constant:-20],

        [self.demoButton.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-20],
        [self.demoButton.topAnchor constraintEqualToAnchor:header.topAnchor constant:27],
        [self.demoButton.widthAnchor constraintEqualToConstant:74],
        [self.demoButton.heightAnchor constraintEqualToConstant:36],
        [self.connectButton.trailingAnchor constraintEqualToAnchor:self.demoButton.leadingAnchor constant:-8],
        [self.connectButton.topAnchor constraintEqualToAnchor:self.demoButton.topAnchor],
        [self.connectButton.widthAnchor constraintEqualToConstant:106],
        [self.connectButton.heightAnchor constraintEqualToAnchor:self.demoButton.heightAnchor],
        [addressLabel.leadingAnchor constraintEqualToAnchor:self.addressField.leadingAnchor],
        [addressLabel.topAnchor constraintEqualToAnchor:targetLabel.topAnchor],
        [self.addressField.trailingAnchor constraintEqualToAnchor:self.connectButton.leadingAnchor constant:-10],
        [self.addressField.topAnchor constraintEqualToAnchor:self.demoButton.topAnchor],
        [self.addressField.widthAnchor constraintEqualToConstant:200],
        [self.addressField.heightAnchor constraintEqualToAnchor:self.demoButton.heightAnchor],

        [statusPrefix.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:22],
        [statusPrefix.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-9],
        [self.statusLabel.leadingAnchor constraintEqualToAnchor:statusPrefix.trailingAnchor constant:10],
        [self.statusLabel.trailingAnchor constraintLessThanOrEqualToAnchor:mediaButton.leadingAnchor constant:-14],
        [self.statusLabel.centerYAnchor constraintEqualToAnchor:statusPrefix.centerYAnchor],

        [hyperDeckButton.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-20],
        [hyperDeckButton.bottomAnchor constraintEqualToAnchor:header.bottomAnchor constant:-5],
        [hyperDeckButton.widthAnchor constraintEqualToConstant:104],
        [hyperDeckButton.heightAnchor constraintEqualToConstant:25],
        [colorButton.trailingAnchor constraintEqualToAnchor:hyperDeckButton.leadingAnchor constant:-7],
        [colorButton.bottomAnchor constraintEqualToAnchor:hyperDeckButton.bottomAnchor],
        [colorButton.widthAnchor constraintEqualToConstant:76],
        [colorButton.heightAnchor constraintEqualToAnchor:hyperDeckButton.heightAnchor],
        [audioButton.trailingAnchor constraintEqualToAnchor:colorButton.leadingAnchor constant:-7],
        [audioButton.bottomAnchor constraintEqualToAnchor:hyperDeckButton.bottomAnchor],
        [audioButton.widthAnchor constraintEqualToConstant:76],
        [audioButton.heightAnchor constraintEqualToAnchor:hyperDeckButton.heightAnchor],
        [labelsButton.trailingAnchor constraintEqualToAnchor:audioButton.leadingAnchor constant:-7],
        [labelsButton.bottomAnchor constraintEqualToAnchor:hyperDeckButton.bottomAnchor],
        [labelsButton.widthAnchor constraintEqualToConstant:76],
        [labelsButton.heightAnchor constraintEqualToAnchor:hyperDeckButton.heightAnchor],
        [mediaButton.trailingAnchor constraintEqualToAnchor:labelsButton.leadingAnchor constant:-7],
        [mediaButton.bottomAnchor constraintEqualToAnchor:hyperDeckButton.bottomAnchor],
        [mediaButton.widthAnchor constraintEqualToConstant:76],
        [mediaButton.heightAnchor constraintEqualToAnchor:hyperDeckButton.heightAnchor],
    ]];
    return header;
}

- (NSScrollView *)busScrollWithStack:(NSStackView * __strong *)stackOut
{
    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.drawsBackground = NO;
    scroll.hasHorizontalScroller = YES;
    scroll.hasVerticalScroller = NO;
    scroll.autohidesScrollers = YES;
    scroll.borderType = NSNoBorder;

    NSStackView *stack = [[NSStackView alloc] initWithFrame:NSMakeRect(0, 0, 100, 42)];
    stack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    stack.alignment = NSLayoutAttributeCenterY;
    stack.spacing = 6;
    stack.edgeInsets = NSEdgeInsetsMake(0, 0, 0, 6);
    scroll.documentView = stack;
    if (stackOut)
        *stackOut = stack;
    return scroll;
}

- (NSView *)busRowWithName:(NSString *)name scroll:(NSScrollView *)scroll color:(NSColor *)color
{
    NSView *row = [[NSView alloc] initWithFrame:NSZeroRect];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    NSView *labelShell = [[NSView alloc] initWithFrame:NSZeroRect];
    labelShell.translatesAutoresizingMaskIntoConstraints = NO;
    labelShell.wantsLayer = YES;
    labelShell.layer.backgroundColor = [color colorWithAlphaComponent:0.08].CGColor;
    labelShell.layer.borderColor = [color colorWithAlphaComponent:0.30].CGColor;
    labelShell.layer.borderWidth = 1;
    labelShell.layer.cornerRadius = 6;
    NSView *rail = [[NSView alloc] initWithFrame:NSZeroRect];
    rail.translatesAutoresizingMaskIntoConstraints = NO;
    rail.wantsLayer = YES;
    rail.layer.backgroundColor = color.CGColor;
    rail.layer.cornerRadius = 1.5;
    [labelShell addSubview:rail];
    NSTextField *label = Label(name, 10, NSFontWeightSemibold, color);
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [labelShell addSubview:label];
    [row addSubview:labelShell];
    [row addSubview:scroll];
    [NSLayoutConstraint activateConstraints:@[
        [labelShell.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [labelShell.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [labelShell.widthAnchor constraintEqualToConstant:78],
        [labelShell.heightAnchor constraintEqualToConstant:36],
        [rail.leadingAnchor constraintEqualToAnchor:labelShell.leadingAnchor constant:6],
        [rail.centerYAnchor constraintEqualToAnchor:labelShell.centerYAnchor],
        [rail.widthAnchor constraintEqualToConstant:3],
        [rail.heightAnchor constraintEqualToConstant:18],
        [label.leadingAnchor constraintEqualToAnchor:rail.trailingAnchor constant:7],
        [label.centerYAnchor constraintEqualToAnchor:labelShell.centerYAnchor],
        [scroll.leadingAnchor constraintEqualToAnchor:labelShell.trailingAnchor constant:10],
        [scroll.trailingAnchor constraintEqualToAnchor:row.trailingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:row.topAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
        [row.heightAnchor constraintEqualToConstant:52],
    ]];
    return row;
}

- (NSView *)buildBusesCard
{
    NSStackView *content = nil;
    ATEMCardView *card = [self cardWithTitle:@"M/E 1 — Program / Preview" accentColor:ThemeCyan() content:&content];
    self.programScroll = [self busScrollWithStack:&_programStack];
    self.previewScroll = [self busScrollWithStack:&_previewStack];
    NSView *program = [self busRowWithName:@"PROGRAM" scroll:self.programScroll color:ThemeProgram()];
    NSView *preview = [self busRowWithName:@"PREVIEW" scroll:self.previewScroll color:ThemePreview()];
    [content addArrangedSubview:program];
    [content addArrangedSubview:preview];
    [program.widthAnchor constraintEqualToAnchor:content.widthAnchor].active = YES;
    [preview.widthAnchor constraintEqualToAnchor:content.widthAnchor].active = YES;
    return card;
}

- (NSView *)buildNextTransitionCard
{
    NSStackView *content = nil;
    ATEMCardView *card = [self cardWithTitle:@"Next Transition" accentColor:ThemeAmber() content:&content];

    NSStackView *styleRowOne = [NSStackView stackViewWithViews:@[]];
    styleRowOne.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    styleRowOne.distribution = NSStackViewDistributionFillEqually;
    styleRowOne.spacing = 6;
    NSStackView *styleRowTwo = [NSStackView stackViewWithViews:@[]];
    styleRowTwo.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    styleRowTwo.distribution = NSStackViewDistributionFillEqually;
    styleRowTwo.spacing = 6;
    NSArray<NSString *> *styleNames = @[@"MIX", @"DIP", @"WIPE", @"DVE", @"STING"];
    NSMutableArray *styles = [NSMutableArray array];
    [styleNames enumerateObjectsUsingBlock:^(NSString *name, NSUInteger index, BOOL *stop) {
        (void)stop;
        ATEMControlButton *button = [[ATEMControlButton alloc] initWithTitle:name target:self action:@selector(stylePressed:)];
        button.tag = index;
        button.activeColor = ThemeAmber();
        button.fillsWhenActive = NO;
        [(index < 3 ? styleRowOne : styleRowTwo) addArrangedSubview:button];
        [styles addObject:button];
        [self.requiresConnection addObject:button];
    }];
    self.styleButtons = styles;
    [content addArrangedSubview:styleRowOne];
    [content addArrangedSubview:styleRowTwo];
    [styleRowOne.widthAnchor constraintEqualToAnchor:content.widthAnchor].active = YES;
    [styleRowTwo.widthAnchor constraintEqualToAnchor:content.widthAnchor].active = YES;

    NSStackView *rateRow = [[NSStackView alloc] initWithFrame:NSZeroRect];
    rateRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    rateRow.alignment = NSLayoutAttributeCenterY;
    rateRow.spacing = 8;
    [rateRow addArrangedSubview:Label(@"RATE", 9, NSFontWeightSemibold, ThemeMuted())];
    self.rateField = [[NSTextField alloc] initWithFrame:NSZeroRect];
    self.rateField.alignment = NSTextAlignmentRight;
    self.rateField.font = [NSFont monospacedDigitSystemFontOfSize:12 weight:NSFontWeightSemibold];
    self.rateField.stringValue = @"25";
    self.rateField.delegate = self;
    StyleCompactField(self.rateField);
    [rateRow addArrangedSubview:self.rateField];
    [self.rateField.widthAnchor constraintEqualToConstant:54].active = YES;
    [self.rateField.heightAnchor constraintEqualToConstant:27].active = YES;
    [rateRow addArrangedSubview:Label(@"frames", 10, NSFontWeightRegular, ThemeMuted())];
    self.rateStepper = [[NSStepper alloc] initWithFrame:NSZeroRect];
    self.rateStepper.minValue = 1;
    self.rateStepper.maxValue = 250;
    self.rateStepper.increment = 1;
    self.rateStepper.integerValue = 25;
    self.rateStepper.valueWraps = NO;
    self.rateStepper.autorepeat = YES;
    self.rateStepper.target = self;
    self.rateStepper.action = @selector(rateChanged:);
    [rateRow addArrangedSubview:self.rateStepper];
    [content addArrangedSubview:rateRow];
    [self.requiresConnection addObject:self.rateField];
    [self.requiresConnection addObject:self.rateStepper];

    NSStackView *selection = [[NSStackView alloc] initWithFrame:NSZeroRect];
    selection.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    selection.distribution = NSStackViewDistributionFillEqually;
    selection.spacing = 5;
    NSArray<NSString *> *selectionNames = @[@"BKGD", @"KEY 1", @"KEY 2", @"KEY 3", @"KEY 4"];
    NSMutableArray *selectionButtons = [NSMutableArray array];
    [selectionNames enumerateObjectsUsingBlock:^(NSString *name, NSUInteger index, BOOL *stop) {
        (void)stop;
        ATEMControlButton *button = [[ATEMControlButton alloc] initWithTitle:name target:self action:@selector(selectionPressed:)];
        button.tag = index;
        button.activeColor = ThemeAmber();
        button.fillsWhenActive = NO;
        [selection addArrangedSubview:button];
        [selectionButtons addObject:button];
        [self.requiresConnection addObject:button];
    }];
    self.selectionButtons = selectionButtons;
    [content addArrangedSubview:selection];
    [selection.widthAnchor constraintEqualToAnchor:content.widthAnchor].active = YES;
    return card;
}

- (NSView *)buildVideoStandardCard
{
    NSStackView *content = nil;
    ATEMCardView *card = [self cardWithTitle:@"Video Standard" accentColor:ThemeViolet() content:&content];

    NSStackView *row = [[NSStackView alloc] initWithFrame:NSZeroRect];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeCenterY;
    row.spacing = 8;

    [row addArrangedSubview:Label(@"FORMAT", 9, NSFontWeightSemibold, ThemeMuted())];
    self.videoFormatPopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    StylePopup(self.videoFormatPopup);
    self.videoFormatPopup.target = self;
    self.videoFormatPopup.action = @selector(videoFormatChanged:);
    [row addArrangedSubview:self.videoFormatPopup];
    [self.videoFormatPopup.widthAnchor constraintEqualToConstant:130].active = YES;

    [row addArrangedSubview:Label(@"FRAME RATE", 9, NSFontWeightSemibold, ThemeMuted())];
    self.videoRatePopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    StylePopup(self.videoRatePopup);
    self.videoRatePopup.target = self;
    self.videoRatePopup.action = @selector(videoRateChanged:);
    [row addArrangedSubview:self.videoRatePopup];
    [self.videoRatePopup.widthAnchor constraintEqualToConstant:100].active = YES;

    self.videoApplyButton = [[ATEMControlButton alloc] initWithTitle:@"SET STANDARD"
                                                              target:self
                                                              action:@selector(videoStandardApplyPressed:)];
    self.videoApplyButton.activeColor = ThemeViolet();
    self.videoApplyButton.fillsWhenActive = NO;
    [row addArrangedSubview:self.videoApplyButton];
    [self.videoApplyButton.widthAnchor constraintEqualToConstant:130].active = YES;

    NSView *spacer = [[NSView alloc] initWithFrame:NSZeroRect];
    [spacer setContentHuggingPriority:NSLayoutPriorityDefaultLow - 1
                       forOrientation:NSLayoutConstraintOrientationHorizontal];
    [row addArrangedSubview:spacer];
    [content addArrangedSubview:row];
    [row.widthAnchor constraintEqualToAnchor:content.widthAnchor].active = YES;

    self.videoModeLabel = Label(@"Connect to read the switcher video standard.", 10, NSFontWeightRegular, ThemeSecondary());
    [content addArrangedSubview:self.videoModeLabel];

    self.videoModeOptions = @[];
    self.syncedVideoMode = UINT32_MAX;
    return card;
}

- (NSView *)buildTransitionCard
{
    NSStackView *content = nil;
    ATEMCardView *card = [self cardWithTitle:@"Transition" accentColor:ThemeCyan() content:&content];

    NSTextField *keyLabel = Label(@"UPSTREAM KEY ON AIR", 9, NSFontWeightSemibold, ThemeMuted());
    [content addArrangedSubview:keyLabel];
    self.upstreamKeyStack = [[NSStackView alloc] initWithFrame:NSZeroRect];
    self.upstreamKeyStack.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    self.upstreamKeyStack.distribution = NSStackViewDistributionFillEqually;
    self.upstreamKeyStack.spacing = 6;
    [content addArrangedSubview:self.upstreamKeyStack];
    [self.upstreamKeyStack.widthAnchor constraintEqualToAnchor:content.widthAnchor].active = YES;

    NSView *spacer = [[NSView alloc] initWithFrame:NSZeroRect];
    [spacer.heightAnchor constraintEqualToConstant:7].active = YES;
    [content addArrangedSubview:spacer];

    self.cutButton = [[ATEMControlButton alloc] initWithTitle:@"CUT" target:self action:@selector(cutPressed:)];
    self.cutButton.activeColor = ThemeCyan();
    self.cutButton.cornerRadius = 7;
    [self.cutButton.heightAnchor constraintEqualToConstant:44].active = YES;
    [content addArrangedSubview:self.cutButton];
    [self.cutButton.widthAnchor constraintEqualToAnchor:content.widthAnchor].active = YES;

    self.autoButton = [[ATEMControlButton alloc] initWithTitle:@"AUTO" target:self action:@selector(autoPressed:)];
    self.autoButton.activeColor = ThemeProgram();
    self.autoButton.cornerRadius = 7;
    [self.autoButton.heightAnchor constraintEqualToConstant:44].active = YES;
    [content addArrangedSubview:self.autoButton];
    [self.autoButton.widthAnchor constraintEqualToAnchor:content.widthAnchor].active = YES;

    self.ftbButton = [[ATEMControlButton alloc] initWithTitle:@"FADE TO BLACK" target:self action:@selector(ftbPressed:)];
    self.ftbButton.activeColor = ThemeProgram();
    [content addArrangedSubview:self.ftbButton];
    [self.ftbButton.widthAnchor constraintEqualToAnchor:content.widthAnchor].active = YES;
    [self.requiresConnection addObjectsFromArray:@[self.cutButton, self.autoButton, self.ftbButton]];
    return card;
}

- (NSView *)buildTBarCard
{
    NSStackView *content = nil;
    ATEMCardView *card = [self cardWithTitle:@"T-Bar" accentColor:ThemeCyan() content:&content];
    content.alignment = NSLayoutAttributeCenterX;
    self.tBar = [NSSlider sliderWithValue:0 minValue:0 maxValue:1 target:self action:@selector(tBarMoved:)];
    self.tBar.translatesAutoresizingMaskIntoConstraints = NO;
    self.tBar.vertical = YES;
    self.tBar.continuous = YES;
    self.tBar.numberOfTickMarks = 11;
    self.tBar.allowsTickMarkValuesOnly = NO;
    [content addArrangedSubview:self.tBar];
    [self.tBar.heightAnchor constraintEqualToConstant:188].active = YES;
    [self.tBar.widthAnchor constraintEqualToConstant:40].active = YES;
    self.framesLabel = Label(@"—", 11, NSFontWeightSemibold, ThemeText());
    self.framesLabel.alignment = NSTextAlignmentCenter;
    [content addArrangedSubview:self.framesLabel];
    [self.requiresConnection addObject:self.tBar];
    return card;
}

- (NSView *)buildDownstreamKeyCard
{
    NSStackView *content = nil;
    ATEMCardView *card = [self cardWithTitle:@"Downstream Key" accentColor:ThemeProgram() content:&content];
    self.dskStack = content;
    return card;
}

- (NSView *)buildAuxCard
{
    NSStackView *content = nil;
    ATEMCardView *card = [self cardWithTitle:@"Auxiliary Outputs" accentColor:ThemeCyan() content:&content];
    self.auxStack = content;
    return card;
}

- (NSView *)buildMultiviewCard
{
    NSStackView *content = nil;
    ATEMCardView *card = [self cardWithTitle:@"Multiview Configuration — Active Session" accentColor:ThemeViolet() content:&content];
    self.multiviewStack = content;
    return card;
}

- (NSView *)smallCheckboxGroupWithTitle:(NSString *)title
                                 action:(SEL)action
                                    tag:(NSInteger)tag
                    displayWindowNumber:(NSUInteger)displayWindowNumber
                                 button:(NSButton * __strong *)buttonOut
{
    NSStackView *group = [[NSStackView alloc] initWithFrame:NSZeroRect];
    group.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    group.alignment = NSLayoutAttributeCenterY;
    group.spacing = 1;
    NSButton *button = [NSButton checkboxWithTitle:title target:self action:action];
    button.tag = tag;
    button.controlSize = NSControlSizeSmall;
    button.font = [NSFont systemFontOfSize:9 weight:NSFontWeightMedium];
    button.attributedTitle = [[NSAttributedString alloc] initWithString:title
                                                              attributes:@{
        NSFontAttributeName: button.font,
        NSForegroundColorAttributeName: ThemeSecondary(),
    }];
    button.contentTintColor = ThemeCyan();
    button.accessibilityLabel = [NSString stringWithFormat:@"Multiview %lu Window %lu %@",
                                 (unsigned long)MultiviewIndexFromTag(tag) + 1,
                                 (unsigned long)displayWindowNumber,
                                 title.capitalizedString];
    [group addArrangedSubview:button];
    if (buttonOut)
        *buttonOut = button;
    return group;
}

- (NSView *)buildSafetyNotice
{
    NSView *notice = [[NSView alloc] initWithFrame:NSZeroRect];
    notice.translatesAutoresizingMaskIntoConstraints = NO;
    notice.wantsLayer = YES;
    notice.layer.backgroundColor = [ThemeAmber() colorWithAlphaComponent:0.07].CGColor;
    notice.layer.cornerRadius = 7;
    notice.layer.borderColor = [ThemeAmber() colorWithAlphaComponent:0.28].CGColor;
    notice.layer.borderWidth = 1;
    NSTextField *text = [NSTextField wrappingLabelWithString:@"Tahoe safety mode: this build deliberately does not initialize IBMDSwitcherCameraControl. The supplied hang report blocks in camera-default transmission on the UI thread; core switching remains fully asynchronous here."];
    text.translatesAutoresizingMaskIntoConstraints = NO;
    text.font = [NSFont systemFontOfSize:11 weight:NSFontWeightRegular];
    text.textColor = Blend(ThemeAmber(), 0.28, ThemeText());
    [notice addSubview:text];
    [NSLayoutConstraint activateConstraints:@[
        [text.leadingAnchor constraintEqualToAnchor:notice.leadingAnchor constant:14],
        [text.trailingAnchor constraintEqualToAnchor:notice.trailingAnchor constant:-14],
        [text.topAnchor constraintEqualToAnchor:notice.topAnchor constant:12],
        [text.bottomAnchor constraintEqualToAnchor:notice.bottomAnchor constant:-12],
    ]];
    return notice;
}

- (NSString *)signatureForInputs:(NSArray<ATEMInputState *> *)inputs
{
    NSMutableArray<NSString *> *parts = [NSMutableArray arrayWithCapacity:inputs.count];
    for (ATEMInputState *input in inputs)
        [parts addObject:[NSString stringWithFormat:@"%lld:%@:%u", input.inputID, input.longName, input.availabilityMask]];
    return [parts componentsJoinedByString:@"|"];
}

- (NSArray<ATEMInputState *> *)inputs:(NSArray<ATEMInputState *> *)inputs matchingAvailability:(uint32_t)availabilityMask
{
    if (availabilityMask == 0)
        return @[];
    NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(ATEMInputState *input, NSDictionary *bindings) {
        (void)bindings;
        return (input.availabilityMask & availabilityMask) == availabilityMask;
    }];
    return [inputs filteredArrayUsingPredicate:predicate];
}

- (NSString *)signatureForMultiviews:(NSArray<ATEMMultiviewState *> *)multiviews
                              inputs:(NSArray<ATEMInputState *> *)inputs
{
    NSMutableArray<NSString *> *parts = [NSMutableArray arrayWithObject:[self signatureForInputs:inputs]];
    for (ATEMMultiviewState *multiview in multiviews) {
        [parts addObject:[NSString stringWithFormat:@"m%lu:%lu:%u:%d:%d:%d:%d:%d:%d",
                          (unsigned long)multiview.index,
                          (unsigned long)multiview.windows.count,
                          multiview.inputAvailabilityMask,
                          multiview.canChangeLayout,
                          multiview.supportsQuadrantLayout,
                          multiview.canRouteInputs,
                          multiview.supportsVUMeters,
                          multiview.canToggleSafeArea,
                          multiview.canChangeOverlayProperties]];
        for (ATEMMultiviewWindowState *window in multiview.windows) {
            [parts addObject:[NSString stringWithFormat:@"w%lu:%d:%d:%d",
                              (unsigned long)window.index,
                              window.supportsVUMeter,
                              window.supportsSafeArea,
                              window.supportsLabelOverlay]];
        }
    }
    return [parts componentsJoinedByString:@"|"];
}

- (void)addLayoutItem:(NSString *)title value:(ATEMMultiviewLayout)value toPopup:(NSPopUpButton *)popup
{
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
    item.tag = value;
    [popup.menu addItem:item];
}

- (void)rebuildMultiviews:(NSArray<ATEMMultiviewState *> *)multiviews
                    inputs:(NSArray<ATEMInputState *> *)inputs
{
    RemoveAllArrangedSubviews(self.multiviewStack);
    [self.multiviewLayoutPopups removeAllObjects];
    [self.multiviewQuadrantButtons removeAllObjects];
    [self.multiviewSwapButtons removeAllObjects];
    [self.multiviewOpacitySliders removeAllObjects];
    [self.multiviewAllLabelButtons removeAllObjects];
    [self.multiviewAllBorderButtons removeAllObjects];
    [self.multiviewSourcePopups removeAllObjects];
    [self.multiviewVUButtons removeAllObjects];
    [self.multiviewSafeButtons removeAllObjects];
    [self.multiviewLabelButtons removeAllObjects];
    [self.multiviewBorderButtons removeAllObjects];

    if (multiviews.count == 0) {
        NSTextField *empty = [NSTextField wrappingLabelWithString:@"No configurable multiview outputs are available for this session. Connect an ATEM or use Demo to preview the workflow."];
        empty.font = [NSFont systemFontOfSize:11 weight:NSFontWeightRegular];
        empty.textColor = ThemeMuted();
        [self.multiviewStack addArrangedSubview:empty];
        [empty.widthAnchor constraintEqualToAnchor:self.multiviewStack.widthAnchor].active = YES;
        self.multiviewHeightConstraint.constant = 138;
        return;
    }

    CGFloat totalHeight = 62;
    for (ATEMMultiviewState *multiview in multiviews) {
        NSView *section = [[NSView alloc] initWithFrame:NSZeroRect];
        section.translatesAutoresizingMaskIntoConstraints = NO;
        section.wantsLayer = YES;
        section.layer.backgroundColor = ThemeCanvasRaised().CGColor;
        section.layer.cornerRadius = 7;
        section.layer.borderColor = ThemeDivider().CGColor;
        section.layer.borderWidth = 1;

        NSStackView *sectionStack = [[NSStackView alloc] initWithFrame:NSZeroRect];
        sectionStack.translatesAutoresizingMaskIntoConstraints = NO;
        sectionStack.orientation = NSUserInterfaceLayoutOrientationVertical;
        sectionStack.alignment = NSLayoutAttributeLeading;
        sectionStack.spacing = 8;
        [section addSubview:sectionStack];
        [NSLayoutConstraint activateConstraints:@[
            [sectionStack.leadingAnchor constraintEqualToAnchor:section.leadingAnchor constant:12],
            [sectionStack.trailingAnchor constraintEqualToAnchor:section.trailingAnchor constant:-12],
            [sectionStack.topAnchor constraintEqualToAnchor:section.topAnchor constant:12],
            [sectionStack.bottomAnchor constraintEqualToAnchor:section.bottomAnchor constant:-12],
        ]];

        NSStackView *header = [[NSStackView alloc] initWithFrame:NSZeroRect];
        header.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        header.alignment = NSLayoutAttributeCenterY;
        header.spacing = 10;
        NSTextField *title = Label([NSString stringWithFormat:@"MULTIVIEW %lu", (unsigned long)multiview.index + 1], 10.5, NSFontWeightSemibold, ThemeText());
        [header addArrangedSubview:title];
        [title.widthAnchor constraintEqualToConstant:92].active = YES;

        if (multiview.supportsQuadrantLayout) {
            NSStackView *quadrants = [[NSStackView alloc] initWithFrame:NSZeroRect];
            quadrants.orientation = NSUserInterfaceLayoutOrientationHorizontal;
            quadrants.distribution = NSStackViewDistributionFillEqually;
            quadrants.spacing = 5;
            NSArray<NSString *> *titles = @[@"TL  1", @"TR  1", @"BL  1", @"BR  1"];
            const ATEMMultiviewLayout bits[] = {
                ATEMMultiviewLayoutTopLeftSmall,
                ATEMMultiviewLayoutTopRightSmall,
                ATEMMultiviewLayoutBottomLeftSmall,
                ATEMMultiviewLayoutBottomRightSmall,
            };
            NSMutableArray<ATEMControlButton *> *buttons = [NSMutableArray arrayWithCapacity:4];
            for (NSUInteger quadrant = 0; quadrant < 4; ++quadrant) {
                ATEMControlButton *button = [[ATEMControlButton alloc] initWithTitle:titles[quadrant]
                                                                             target:self
                                                                             action:@selector(multiviewQuadrantPressed:)];
                button.tag = MultiviewControlTag(multiview.index, bits[quadrant]);
                button.activeColor = ThemeViolet();
                button.fillsWhenActive = NO;
                button.accessibilityLabel = [NSString stringWithFormat:@"Multiview %lu %@ quadrant layout",
                                              (unsigned long)multiview.index + 1,
                                              @[@"top-left", @"top-right", @"bottom-left", @"bottom-right"][quadrant]];
                button.toolTip = [NSString stringWithFormat:@"Click to change the %@ quadrant between one large window and four small windows.",
                                  @[@"top-left", @"top-right", @"bottom-left", @"bottom-right"][quadrant]];
                [quadrants addArrangedSubview:button];
                [buttons addObject:button];
            }
            [header addArrangedSubview:quadrants];
            [quadrants.widthAnchor constraintEqualToConstant:310].active = YES;
            self.multiviewQuadrantButtons[@(multiview.index)] = buttons;
        } else {
            NSPopUpButton *layoutPopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
            layoutPopup.tag = multiview.index;
            layoutPopup.target = self;
            layoutPopup.action = @selector(multiviewLayoutChanged:);
            StylePopup(layoutPopup);
            [self addLayoutItem:@"Program Top" value:ATEMMultiviewLayoutProgramTop toPopup:layoutPopup];
            [self addLayoutItem:@"Program Bottom" value:ATEMMultiviewLayoutProgramBottom toPopup:layoutPopup];
            [self addLayoutItem:@"Program Left" value:ATEMMultiviewLayoutProgramLeft toPopup:layoutPopup];
            [self addLayoutItem:@"Program Right" value:ATEMMultiviewLayoutProgramRight toPopup:layoutPopup];
            [header addArrangedSubview:layoutPopup];
            [layoutPopup.widthAnchor constraintEqualToConstant:180].active = YES;
            self.multiviewLayoutPopups[@(multiview.index)] = layoutPopup;
        }

        ATEMControlButton *swap = [[ATEMControlButton alloc] initWithTitle:@"SWAP PGM / PVW" target:self action:@selector(multiviewSwapPressed:)];
        swap.tag = multiview.index;
        swap.activeColor = ThemeViolet();
        swap.fillsWhenActive = NO;
        swap.accessibilityLabel = [NSString stringWithFormat:@"Multiview %lu swap Program and Preview",
                                   (unsigned long)multiview.index + 1];
        [header addArrangedSubview:swap];
        [swap.widthAnchor constraintEqualToConstant:132].active = YES;
        self.multiviewSwapButtons[@(multiview.index)] = swap;

        ATEMControlButton *allLabels = [[ATEMControlButton alloc] initWithTitle:@"LABELS ON"
                                                                        target:self
                                                                        action:@selector(multiviewAllLabelsPressed:)];
        allLabels.tag = multiview.index;
        allLabels.activeColor = ThemeViolet();
        allLabels.fillsWhenActive = NO;
        allLabels.accessibilityLabel = [NSString stringWithFormat:@"Multiview %lu all labels",
                                       (unsigned long)multiview.index + 1];
        allLabels.toolTip = @"Turn labels on for every supported window, or turn them all off.";
        [header addArrangedSubview:allLabels];
        [allLabels.widthAnchor constraintEqualToConstant:102].active = YES;
        self.multiviewAllLabelButtons[@(multiview.index)] = allLabels;

        ATEMControlButton *allBorders = [[ATEMControlButton alloc] initWithTitle:@"BORDERS ON"
                                                                         target:self
                                                                         action:@selector(multiviewAllBordersPressed:)];
        allBorders.tag = multiview.index;
        allBorders.activeColor = ThemeViolet();
        allBorders.fillsWhenActive = NO;
        allBorders.accessibilityLabel = [NSString stringWithFormat:@"Multiview %lu all borders",
                                        (unsigned long)multiview.index + 1];
        allBorders.toolTip = @"Turn borders on for every window, or turn them all off.";
        [header addArrangedSubview:allBorders];
        [allBorders.widthAnchor constraintEqualToConstant:108].active = YES;
        self.multiviewAllBorderButtons[@(multiview.index)] = allBorders;

        NSView *spacer = [[NSView alloc] initWithFrame:NSZeroRect];
        [spacer setContentHuggingPriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];
        [header addArrangedSubview:spacer];
        NSTextField *opacityLabel = Label(@"VU OPACITY", 9, NSFontWeightSemibold, ThemeMuted());
        [header addArrangedSubview:opacityLabel];
        NSSlider *opacity = [NSSlider sliderWithValue:multiview.vuMeterOpacity
                                             minValue:0
                                             maxValue:1
                                               target:self
                                               action:@selector(multiviewOpacityChanged:)];
        opacity.tag = multiview.index;
        opacity.continuous = NO;
        opacity.toolTip = @"Multiview audio-meter opacity";
        [header addArrangedSubview:opacity];
        [opacity.widthAnchor constraintEqualToConstant:125].active = YES;
        self.multiviewOpacitySliders[@(multiview.index)] = opacity;
        [sectionStack addArrangedSubview:header];
        [header.widthAnchor constraintEqualToAnchor:sectionStack.widthAnchor].active = YES;
        [header.heightAnchor constraintEqualToConstant:34].active = YES;

        const NSUInteger columns = 4;
        NSUInteger rowCount = (multiview.windows.count + columns - 1) / columns;
        for (NSUInteger rowIndex = 0; rowIndex < rowCount; ++rowIndex) {
            NSStackView *row = [[NSStackView alloc] initWithFrame:NSZeroRect];
            row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
            row.alignment = NSLayoutAttributeTop;
            row.distribution = NSStackViewDistributionFillEqually;
            row.spacing = 8;
            for (NSUInteger column = 0; column < columns; ++column) {
                NSUInteger windowIndex = rowIndex * columns + column;
                if (windowIndex >= multiview.windows.count) {
                    [row addArrangedSubview:[[NSView alloc] initWithFrame:NSZeroRect]];
                    continue;
                }
                ATEMMultiviewWindowState *window = multiview.windows[windowIndex];
                NSInteger controlTag = MultiviewControlTag(multiview.index, window.index);
                NSNumber *controlKey = @(controlTag);
                NSStackView *tile = [[NSStackView alloc] initWithFrame:NSZeroRect];
                tile.orientation = NSUserInterfaceLayoutOrientationVertical;
                tile.alignment = NSLayoutAttributeLeading;
                tile.spacing = 5;
                tile.edgeInsets = NSEdgeInsetsMake(7, 8, 7, 8);
                tile.wantsLayer = YES;
                tile.layer.backgroundColor = ThemePanelRaised().CGColor;
                tile.layer.cornerRadius = 7;
                tile.layer.borderColor = ThemeDivider().CGColor;
                tile.layer.borderWidth = 1;

                NSUInteger displayWindowNumber = windowIndex + 1;
                NSTextField *windowLabel =
                    Label([NSString stringWithFormat:@"WINDOW %lu",
                           (unsigned long)displayWindowNumber],
                          9, NSFontWeightSemibold, ThemeSecondary());
                [tile addArrangedSubview:windowLabel];
                NSPopUpButton *sourcePopup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
                sourcePopup.tag = controlTag;
                sourcePopup.target = self;
                sourcePopup.action = @selector(multiviewSourceChanged:);
                StylePopup(sourcePopup);
                sourcePopup.accessibilityLabel = [NSString stringWithFormat:@"Multiview %lu Window %lu source",
                                                  (unsigned long)multiview.index + 1,
                                                  (unsigned long)displayWindowNumber];
                for (ATEMInputState *input in inputs) {
                    BOOL available = multiview.inputAvailabilityMask != 0 &&
                        (input.availabilityMask & multiview.inputAvailabilityMask) == multiview.inputAvailabilityMask;
                    if (!available && input.inputID != window.sourceID)
                        continue;
                    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:input.longName action:nil keyEquivalent:@""];
                    item.representedObject = @(input.inputID);
                    [sourcePopup.menu addItem:item];
                }
                [tile addArrangedSubview:sourcePopup];
                [sourcePopup.widthAnchor constraintEqualToAnchor:tile.widthAnchor constant:-16].active = YES;
                self.multiviewSourcePopups[controlKey] = sourcePopup;

                NSStackView *options = [[NSStackView alloc] initWithFrame:NSZeroRect];
                options.orientation = NSUserInterfaceLayoutOrientationHorizontal;
                options.alignment = NSLayoutAttributeCenterY;
                options.distribution = NSStackViewDistributionFillProportionally;
                options.spacing = 3;
                NSButton *vu = nil;
                NSButton *safe = nil;
                NSButton *label = nil;
                NSButton *border = nil;
                [options addArrangedSubview:[self smallCheckboxGroupWithTitle:@"VU"
                                                                       action:@selector(multiviewVUToggled:)
                                                                          tag:controlTag
                                                          displayWindowNumber:displayWindowNumber
                                                                       button:&vu]];
                [options addArrangedSubview:[self smallCheckboxGroupWithTitle:@"SAFE"
                                                                       action:@selector(multiviewSafeToggled:)
                                                                          tag:controlTag
                                                          displayWindowNumber:displayWindowNumber
                                                                       button:&safe]];
                [options addArrangedSubview:[self smallCheckboxGroupWithTitle:@"LABEL"
                                                                       action:@selector(multiviewLabelToggled:)
                                                                          tag:controlTag
                                                          displayWindowNumber:displayWindowNumber
                                                                       button:&label]];
                [options addArrangedSubview:[self smallCheckboxGroupWithTitle:@"BORDER"
                                                                       action:@selector(multiviewBorderToggled:)
                                                                          tag:controlTag
                                                          displayWindowNumber:displayWindowNumber
                                                                       button:&border]];
                [tile addArrangedSubview:options];
                [options.widthAnchor constraintEqualToAnchor:tile.widthAnchor constant:-16].active = YES;
                self.multiviewVUButtons[controlKey] = vu;
                self.multiviewSafeButtons[controlKey] = safe;
                self.multiviewLabelButtons[controlKey] = label;
                self.multiviewBorderButtons[controlKey] = border;
                [row addArrangedSubview:tile];
            }
            [sectionStack addArrangedSubview:row];
            [row.widthAnchor constraintEqualToAnchor:sectionStack.widthAnchor].active = YES;
            [row.heightAnchor constraintEqualToConstant:64].active = YES;
        }

        CGFloat sectionHeight = 82 + rowCount * 72;
        [self.multiviewStack addArrangedSubview:section];
        [section.widthAnchor constraintEqualToAnchor:self.multiviewStack.widthAnchor].active = YES;
        [section.heightAnchor constraintEqualToConstant:sectionHeight].active = YES;
        totalHeight += sectionHeight;
    }
    totalHeight += MAX(0, (NSInteger)multiviews.count - 1) * self.multiviewStack.spacing;
    self.multiviewHeightConstraint.constant = totalHeight;
}

- (void)rebuildBusButtons:(NSArray<ATEMInputState *> *)inputs
{
    RemoveAllArrangedSubviews(self.programStack);
    RemoveAllArrangedSubviews(self.previewStack);
    [self.programButtons removeAllObjects];
    [self.previewButtons removeAllObjects];

    if (inputs.count == 0) {
        [self.programStack addArrangedSubview:Label(@"Connect to a switcher to populate inputs", 11, NSFontWeightRegular, ThemeMuted())];
        [self.previewStack addArrangedSubview:Label(@"Inputs adapt to the connected ATEM model", 11, NSFontWeightRegular, ThemeMuted())];
    } else {
        for (ATEMInputState *input in inputs) {
            NSString *title = input.shortName.length ? input.shortName : input.longName;
            ATEMInputButton *program = [[ATEMInputButton alloc] initWithTitle:title target:self action:@selector(programPressed:)];
            program.inputID = input.inputID;
            program.toolTip = input.longName;
            program.accessibilityLabel = [NSString stringWithFormat:@"Set Program to %@", input.longName];
            program.activeColor = ThemeProgram();
            [program.widthAnchor constraintEqualToConstant:90].active = YES;
            [self.programStack addArrangedSubview:program];
            self.programButtons[@(input.inputID)] = program;

            ATEMInputButton *preview = [[ATEMInputButton alloc] initWithTitle:title target:self action:@selector(previewPressed:)];
            preview.inputID = input.inputID;
            preview.toolTip = input.longName;
            preview.accessibilityLabel = [NSString stringWithFormat:@"Set Preview to %@", input.longName];
            preview.activeColor = ThemePreview();
            [preview.widthAnchor constraintEqualToConstant:90].active = YES;
            [self.previewStack addArrangedSubview:preview];
            self.previewButtons[@(input.inputID)] = preview;
        }
    }
    [self.programStack layoutSubtreeIfNeeded];
    [self.previewStack layoutSubtreeIfNeeded];
    NSSize programSize = self.programStack.fittingSize;
    NSSize previewSize = self.previewStack.fittingSize;
    self.programStack.frame = NSMakeRect(0, 0, MAX(programSize.width, self.programScroll.contentSize.width), 42);
    self.previewStack.frame = NSMakeRect(0, 0, MAX(previewSize.width, self.previewScroll.contentSize.width), 42);
}

- (void)rebuildUpstreamKeys:(NSArray<ATEMKeyState *> *)keys
{
    RemoveAllArrangedSubviews(self.upstreamKeyStack);
    [self.upstreamKeyButtons removeAllObjects];
    if (keys.count == 0) {
        NSTextField *empty = Label(@"No upstream keys", 10, NSFontWeightRegular, ThemeMuted());
        [self.upstreamKeyStack addArrangedSubview:empty];
        return;
    }
    for (ATEMKeyState *key in keys) {
        ATEMIndexedButton *button = [[ATEMIndexedButton alloc] initWithTitle:[NSString stringWithFormat:@"KEY %lu", (unsigned long)key.index + 1]
                                                                      target:self
                                                                      action:@selector(upstreamKeyPressed:)];
        button.itemIndex = key.index;
        button.activeColor = ThemeProgram();
        button.accessibilityLabel = [NSString stringWithFormat:@"Upstream Key %lu On Air", (unsigned long)key.index + 1];
        [self.upstreamKeyStack addArrangedSubview:button];
        [self.upstreamKeyButtons addObject:button];
    }
}

- (void)rebuildDownstreamKeys:(NSArray<ATEMDownstreamKeyState *> *)keys
{
    RemoveAllArrangedSubviews(self.dskStack);
    [self.dskTieButtons removeAllObjects];
    [self.dskOnAirButtons removeAllObjects];
    [self.dskAutoButtons removeAllObjects];
    if (keys.count == 0) {
        self.dskStack.orientation = NSUserInterfaceLayoutOrientationVertical;
        self.dskStack.distribution = NSStackViewDistributionFill;
        [self.dskStack addArrangedSubview:Label(@"No downstream keyers reported by this switcher.", 10, NSFontWeightRegular, ThemeMuted())];
        return;
    }
    self.dskStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.dskStack.alignment = NSLayoutAttributeLeading;
    self.dskStack.distribution = NSStackViewDistributionFill;
    self.dskStack.spacing = 8;
    __block NSStackView *keyerRow = nil;
    [keys enumerateObjectsUsingBlock:^(ATEMDownstreamKeyState *key, NSUInteger keyIndex, BOOL *stop) {
        (void)stop;
        if (keyIndex % 2 == 0) {
            keyerRow = [[NSStackView alloc] initWithFrame:NSZeroRect];
            keyerRow.orientation = NSUserInterfaceLayoutOrientationHorizontal;
            keyerRow.alignment = NSLayoutAttributeTop;
            keyerRow.distribution = NSStackViewDistributionFillEqually;
            keyerRow.spacing = 8;
            [self.dskStack addArrangedSubview:keyerRow];
            [keyerRow.widthAnchor constraintEqualToAnchor:self.dskStack.widthAnchor].active = YES;
        }
        NSStackView *keyer = [[NSStackView alloc] initWithFrame:NSZeroRect];
        keyer.orientation = NSUserInterfaceLayoutOrientationVertical;
        keyer.alignment = NSLayoutAttributeLeading;
        keyer.spacing = 7;
        keyer.edgeInsets = NSEdgeInsetsMake(9, 9, 9, 9);
        keyer.wantsLayer = YES;
        keyer.layer.backgroundColor = ThemeCanvasRaised().CGColor;
        keyer.layer.borderColor = ThemeDivider().CGColor;
        keyer.layer.borderWidth = 1;
        keyer.layer.cornerRadius = 7;
        NSTextField *title = Label([NSString stringWithFormat:@"DSK %lu", (unsigned long)key.index + 1], 9.5, NSFontWeightSemibold, ThemeSecondary());
        [keyer addArrangedSubview:title];
        NSStackView *row = [[NSStackView alloc] initWithFrame:NSZeroRect];
        row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
        row.distribution = NSStackViewDistributionFillEqually;
        row.spacing = 6;
        ATEMIndexedButton *tie = [[ATEMIndexedButton alloc] initWithTitle:@"TIE" target:self action:@selector(dskTiePressed:)];
        ATEMIndexedButton *onAir = [[ATEMIndexedButton alloc] initWithTitle:@"ON AIR" target:self action:@selector(dskOnAirPressed:)];
        ATEMIndexedButton *autoButton = [[ATEMIndexedButton alloc] initWithTitle:@"AUTO" target:self action:@selector(dskAutoPressed:)];
        tie.itemIndex = onAir.itemIndex = autoButton.itemIndex = key.index;
        tie.accessibilityLabel = [NSString stringWithFormat:@"DSK %lu Tie", (unsigned long)key.index + 1];
        onAir.accessibilityLabel = [NSString stringWithFormat:@"DSK %lu On Air", (unsigned long)key.index + 1];
        autoButton.accessibilityLabel = [NSString stringWithFormat:@"DSK %lu Auto", (unsigned long)key.index + 1];
        tie.activeColor = ThemeAmber();
        tie.fillsWhenActive = NO;
        onAir.activeColor = ThemeProgram();
        autoButton.activeColor = ThemeProgram();
        [row addArrangedSubview:tie];
        [row addArrangedSubview:onAir];
        [row addArrangedSubview:autoButton];
        [keyer addArrangedSubview:row];
        [row.widthAnchor constraintEqualToAnchor:keyer.widthAnchor constant:-18].active = YES;
        [keyerRow addArrangedSubview:keyer];
        [keyer.heightAnchor constraintEqualToConstant:94].active = YES;
        [self.dskTieButtons addObject:tie];
        [self.dskOnAirButtons addObject:onAir];
        [self.dskAutoButtons addObject:autoButton];
        if (keyIndex + 1 == keys.count && keys.count % 2 == 1)
            [keyerRow addArrangedSubview:[[NSView alloc] initWithFrame:NSZeroRect]];
    }];
}

- (void)rebuildAuxes:(NSArray<ATEMAuxState *> *)auxes inputs:(NSArray<ATEMInputState *> *)inputs
{
    RemoveAllArrangedSubviews(self.auxStack);
    [self.auxPopups removeAllObjects];
    if (auxes.count == 0) {
        [self.auxStack addArrangedSubview:Label(@"No auxiliary outputs reported by this switcher.", 10, NSFontWeightRegular, ThemeMuted())];
        return;
    }
    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.drawsBackground = NO;
    scroll.hasHorizontalScroller = YES;
    scroll.hasVerticalScroller = NO;
    scroll.autohidesScrollers = YES;
    scroll.borderType = NSNoBorder;
    NSStackView *row = [[NSStackView alloc] initWithFrame:NSMakeRect(0, 0, 100, 58)];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeCenterY;
    row.spacing = 12;
    for (ATEMAuxState *aux in auxes) {
        NSStackView *group = [[NSStackView alloc] initWithFrame:NSZeroRect];
        group.orientation = NSUserInterfaceLayoutOrientationVertical;
        group.spacing = 5;
        [group addArrangedSubview:Label(aux.name, 9.5, NSFontWeightSemibold, ThemeSecondary())];
        NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
        popup.tag = aux.index;
        popup.target = self;
        popup.action = @selector(auxChanged:);
        StylePopup(popup);
        popup.accessibilityLabel = [NSString stringWithFormat:@"Route %@", aux.name];
        for (ATEMInputState *input in inputs) {
            BOOL available = aux.inputAvailabilityMask != 0 &&
                (input.availabilityMask & aux.inputAvailabilityMask) == aux.inputAvailabilityMask;
            if (!available && input.inputID != aux.sourceID)
                continue;
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:input.longName action:nil keyEquivalent:@""];
            item.representedObject = @(input.inputID);
            [popup.menu addItem:item];
        }
        [group addArrangedSubview:popup];
        [popup.widthAnchor constraintGreaterThanOrEqualToConstant:180].active = YES;
        [row addArrangedSubview:group];
        [self.auxPopups addObject:popup];
    }
    scroll.documentView = row;
    [self.auxStack addArrangedSubview:scroll];
    [scroll.widthAnchor constraintEqualToAnchor:self.auxStack.widthAnchor].active = YES;
    [scroll.heightAnchor constraintEqualToConstant:62].active = YES;
    [row layoutSubtreeIfNeeded];
    NSSize rowSize = row.fittingSize;
    row.frame = NSMakeRect(0, 0, MAX(rowSize.width, scroll.contentSize.width), 58);
}

- (void)applyState:(ATEMState *)state
{
    if (!state)
        return;
    NSAssert(NSThread.isMainThread, @"UI state must be applied on the main thread");
    ATEMState *previous = self.state;
    self.state = state;

    NSString *sessionName = self.activeSessionIndex == 0 ? @"A" : @"B";
    NSString *product = state.productName.length ? state.productName : (state.isConnecting ? @"Connecting…" : @"Not connected");
    self.productLabel.stringValue = [NSString stringWithFormat:@"ATEM %@ — %@", sessionName, product];
    self.statusLabel.stringValue = [NSString stringWithFormat:@"SESSION %@  •  %@", sessionName, state.statusMessage];

    self.statusDot.layer.backgroundColor = (state.isDemo ? ThemeViolet() :
                                            (state.isConnected ? ThemePreview() :
                                             (state.isConnecting ? ThemeAmber() : ThemeMuted()))).CGColor;
    self.connectButton.title = state.isConnected ? @"DISCONNECT" : (state.isConnecting ? @"CONNECTING" : @"CONNECT");
    self.connectButton.accessibilityLabel = self.connectButton.title;
    self.connectButton.enabled = !state.isConnecting;
    self.connectButton.active = state.isConnected;
    self.demoButton.active = state.isDemo;
    self.addressField.enabled = !state.isConnected && !state.isConnecting;

    NSArray<ATEMInputState *> *busInputs = [self inputs:state.inputs matchingAvailability:state.mixEffectInputAvailabilityMask];
    NSString *signature = [self signatureForInputs:busInputs];
    if (![signature isEqualToString:self.inputSignature]) {
        self.inputSignature = signature;
        [self rebuildBusButtons:busInputs];
    }
    if (!previous || previous.upstreamKeys.count != state.upstreamKeys.count)
        [self rebuildUpstreamKeys:state.upstreamKeys];
    if (!previous || previous.downstreamKeys.count != state.downstreamKeys.count)
        [self rebuildDownstreamKeys:state.downstreamKeys];
    if (!previous || previous.auxOutputs.count != state.auxOutputs.count || ![previous.inputs isEqualToArray:state.inputs])
        [self rebuildAuxes:state.auxOutputs inputs:state.inputs];
    NSString *multiviewSignature = [self signatureForMultiviews:state.multiviews inputs:state.inputs];
    if (![multiviewSignature isEqualToString:self.multiviewSignature]) {
        self.multiviewSignature = multiviewSignature;
        [self rebuildMultiviews:state.multiviews inputs:state.inputs];
    }

    for (ATEMInputButton *button in self.programButtons.allValues)
        button.active = button.inputID == state.programInputID;
    for (ATEMInputButton *button in self.previewButtons.allValues)
        button.active = button.inputID == state.previewInputID;

    for (NSControl *control in self.requiresConnection)
        control.enabled = state.isConnected;

    [self.styleButtons enumerateObjectsUsingBlock:^(ATEMControlButton *button, NSUInteger index, BOOL *stop) {
        (void)stop;
        button.active = index == (NSUInteger)state.nextTransitionStyle;
    }];
    [self.selectionButtons enumerateObjectsUsingBlock:^(ATEMControlButton *button, NSUInteger index, BOOL *stop) {
        (void)stop;
        NSUInteger flag = 1UL << index;
        button.active = (state.nextTransitionSelection & flag) != 0;
        if (index > 0)
            button.enabled = state.isConnected && state.upstreamKeys.count >= index;
    }];
    [self applyTransitionRate:state.transitionRate];
    [self applyVideoModeState:state];

    for (ATEMKeyState *key in state.upstreamKeys) {
        if (key.index < self.upstreamKeyButtons.count)
            self.upstreamKeyButtons[key.index].active = key.isOnAir;
    }
    self.cutButton.active = NO;
    self.autoButton.active = state.isInTransition;
    self.ftbButton.active = state.isFadeToBlack || state.isFadeToBlackTransitioning;
    self.tBar.doubleValue = state.transitionPosition;
    self.framesLabel.stringValue = state.isInTransition
        ? [NSString stringWithFormat:@"%u fr", state.transitionFramesRemaining]
        : @"READY";

    for (ATEMDownstreamKeyState *key in state.downstreamKeys) {
        if (key.index < self.dskTieButtons.count) self.dskTieButtons[key.index].active = key.isTied;
        if (key.index < self.dskOnAirButtons.count) self.dskOnAirButtons[key.index].active = key.isOnAir;
        if (key.index < self.dskAutoButtons.count) self.dskAutoButtons[key.index].active = key.isTransitioning;
    }
    for (ATEMAuxState *aux in state.auxOutputs) {
        if (aux.index >= self.auxPopups.count)
            continue;
        NSPopUpButton *popup = self.auxPopups[aux.index];
        for (NSMenuItem *item in popup.itemArray) {
            if ([item.representedObject longLongValue] == aux.sourceID) {
                [popup selectItem:item];
                break;
            }
        }
    }
    for (ATEMMultiviewState *multiview in state.multiviews) {
        NSPopUpButton *popup = self.multiviewLayoutPopups[@(multiview.index)];
        if (popup) {
            [popup selectItemWithTag:multiview.layout];
            popup.enabled = state.isConnected && multiview.canChangeLayout;
        }
        NSArray<ATEMControlButton *> *quadrantButtons = self.multiviewQuadrantButtons[@(multiview.index)];
        const ATEMMultiviewLayout quadrantBits[] = {
            ATEMMultiviewLayoutTopLeftSmall,
            ATEMMultiviewLayoutTopRightSmall,
            ATEMMultiviewLayoutBottomLeftSmall,
            ATEMMultiviewLayoutBottomRightSmall,
        };
        for (NSUInteger index = 0; index < MIN(quadrantButtons.count, 4UL); ++index) {
            ATEMControlButton *button = quadrantButtons[index];
            BOOL split = ((uint32_t)multiview.layout & (uint32_t)quadrantBits[index]) != 0;
            button.active = split;
            button.title = [NSString stringWithFormat:@"%@  %@", @[@"TL", @"TR", @"BL", @"BR"][index], split ? @"4" : @"1"];
            button.enabled = state.isConnected && multiview.canChangeLayout;
            button.accessibilityValue = split ? @"Four small windows" : @"One large window";
        }
        ATEMControlButton *swap = self.multiviewSwapButtons[@(multiview.index)];
        if (swap) {
            swap.active = multiview.isProgramPreviewSwapped;
            swap.enabled = state.isConnected && multiview.supportsProgramPreviewSwap;
        }
        NSSlider *opacity = self.multiviewOpacitySliders[@(multiview.index)];
        if (opacity) {
            opacity.doubleValue = multiview.vuMeterOpacity;
            opacity.enabled = state.isConnected && multiview.supportsVUMeters && multiview.canAdjustVUMeterOpacity;
        }

        NSUInteger labelCount = 0;
        NSUInteger visibleLabelCount = 0;
        NSUInteger borderCount = multiview.windows.count;
        NSUInteger visibleBorderCount = 0;
        for (ATEMMultiviewWindowState *window in multiview.windows) {
            if (window.supportsLabelOverlay) {
                ++labelCount;
                if (window.isLabelVisible)
                    ++visibleLabelCount;
            }
            if (window.isBorderVisible)
                ++visibleBorderCount;
        }
        ATEMControlButton *allLabels = self.multiviewAllLabelButtons[@(multiview.index)];
        BOOL allLabelsVisible = labelCount > 0 && visibleLabelCount == labelCount;
        allLabels.title = allLabelsVisible ? @"LABELS ON" : (visibleLabelCount > 0 ? @"LABELS MIXED" : @"LABELS OFF");
        allLabels.active = allLabelsVisible;
        allLabels.enabled = state.isConnected && multiview.canChangeOverlayProperties && labelCount > 0;
        allLabels.accessibilityValue = allLabelsVisible ? @"All on" : (visibleLabelCount > 0 ? @"Mixed" : @"All off");

        ATEMControlButton *allBorders = self.multiviewAllBorderButtons[@(multiview.index)];
        BOOL allBordersVisible = borderCount > 0 && visibleBorderCount == borderCount;
        allBorders.title = allBordersVisible ? @"BORDERS ON" : (visibleBorderCount > 0 ? @"BORDERS MIXED" : @"BORDERS OFF");
        allBorders.active = allBordersVisible;
        allBorders.enabled = state.isConnected && multiview.canChangeOverlayProperties && borderCount > 0;
        allBorders.accessibilityValue = allBordersVisible ? @"All on" : (visibleBorderCount > 0 ? @"Mixed" : @"All off");

        for (ATEMMultiviewWindowState *window in multiview.windows) {
            NSNumber *key = @(MultiviewControlTag(multiview.index, window.index));
            NSPopUpButton *sourcePopup = self.multiviewSourcePopups[key];
            for (NSMenuItem *item in sourcePopup.itemArray) {
                if ([item.representedObject longLongValue] == window.sourceID) {
                    [sourcePopup selectItem:item];
                    break;
                }
            }
            sourcePopup.enabled = state.isConnected && window.canRouteInput;
            sourcePopup.toolTip = window.canRouteInput
                ? @"Select the source shown in this multiview window."
                : @"Program/Preview windows are fixed on classic multiview layouts.";
            NSButton *vu = self.multiviewVUButtons[key];
            vu.state = window.isVUMeterEnabled ? NSControlStateValueOn : NSControlStateValueOff;
            vu.enabled = state.isConnected && multiview.supportsVUMeters && window.supportsVUMeter;
            NSButton *safe = self.multiviewSafeButtons[key];
            safe.state = window.isSafeAreaEnabled ? NSControlStateValueOn : NSControlStateValueOff;
            safe.enabled = state.isConnected && multiview.canToggleSafeArea && window.supportsSafeArea;
            NSButton *label = self.multiviewLabelButtons[key];
            label.state = window.isLabelVisible ? NSControlStateValueOn : NSControlStateValueOff;
            label.enabled = state.isConnected && multiview.canChangeOverlayProperties && window.supportsLabelOverlay;
            NSButton *border = self.multiviewBorderButtons[key];
            border.state = window.isBorderVisible ? NSControlStateValueOn : NSControlStateValueOff;
            border.enabled = state.isConnected && multiview.canChangeOverlayProperties;
        }
    }

    for (ATEMInputButton *button in self.programButtons.allValues) button.enabled = state.isConnected;
    for (ATEMInputButton *button in self.previewButtons.allValues) button.enabled = state.isConnected;
    for (ATEMIndexedButton *button in self.upstreamKeyButtons) button.enabled = state.isConnected;
    for (ATEMIndexedButton *button in self.dskTieButtons) button.enabled = state.isConnected;
    for (ATEMIndexedButton *button in self.dskOnAirButtons) button.enabled = state.isConnected;
    for (ATEMIndexedButton *button in self.dskAutoButtons) button.enabled = state.isConnected;
    for (NSPopUpButton *popup in self.auxPopups) popup.enabled = state.isConnected;
    self.connectButton.enabled = !state.isConnecting;
    self.demoButton.enabled = !state.isConnecting;
    [self updateSessionSelector];
}

- (void)connectPressed:(id)sender
{
    (void)sender;
    [self saveAddressForActiveSession];
    if (self.state.isConnected)
        [self.activeController disconnect];
    else
        [self.activeController connectToAddress:self.addressField.stringValue];
}

- (void)demoPressed:(id)sender
{
    (void)sender;
    [self.activeController enterDemoMode];
}

- (void)featurePressed:(NSButton *)sender
{
    NSArray<NSString *> *features = @[@"audio", @"color", @"hyperdeck", @"labels", @"media"];
    if (sender.tag < 0 || (NSUInteger)sender.tag >= features.count)
        return;
    void (^handler)(NSString *, NSUInteger) = self.featureActionHandler;
    if (handler)
        handler(features[(NSUInteger)sender.tag], self.activeSessionIndex);
}

- (void)programPressed:(ATEMInputButton *)sender { [self.activeController setProgramInput:sender.inputID]; }
- (void)previewPressed:(ATEMInputButton *)sender { [self.activeController setPreviewInput:sender.inputID]; }
- (void)cutPressed:(id)sender { (void)sender; [self.activeController performCut]; }
- (void)autoPressed:(id)sender { (void)sender; [self.activeController performAutoTransition]; }
- (void)ftbPressed:(id)sender { (void)sender; [self.activeController performFadeToBlack]; }
- (void)tBarMoved:(NSSlider *)sender { [self.activeController setTransitionPosition:sender.doubleValue]; }

- (void)stylePressed:(ATEMControlButton *)sender
{
    [self.activeController setNextTransitionStyle:(ATEMTransitionStyle)sender.tag];
}

- (void)selectionPressed:(ATEMControlButton *)sender
{
    ATEMTransitionSelection selection = self.state.nextTransitionSelection;
    ATEMTransitionSelection flag = (ATEMTransitionSelection)(1UL << sender.tag);
    selection ^= flag;
    if (selection == 0)
        selection = ATEMTransitionSelectionBackground;
    [self.activeController setNextTransitionSelection:selection];
}

/// YES while the user is typing into the RATE field. AppKit hands editing to a
/// shared field editor, so the text field itself is never the first responder.
- (BOOL)isEditingRateField
{
    NSResponder *responder = self.rateField.window.firstResponder;
    if (![responder isKindOfClass:[NSTextView class]])
        return NO;
    return (id)((NSTextView *)responder).delegate == (id)self.rateField;
}

/// Pushes the switcher's rate into the RATE controls, but never on top of an
/// edit in progress and never inside the echo window after a local change.
- (void)applyTransitionRate:(uint32_t)rate
{
    if ([self isEditingRateField])
        return;
    if ([NSDate timeIntervalSinceReferenceDate] < self.rateEchoSuppressUntil)
        return;
    if (self.rateField.integerValue != (NSInteger)rate)
        self.rateField.integerValue = (NSInteger)rate;
    if (self.rateStepper.integerValue != (NSInteger)rate)
        self.rateStepper.integerValue = (NSInteger)rate;
}

#pragma mark - Video standard

- (ATEMVideoModeOption *)videoModeOptionForRawMode:(uint32_t)rawMode
{
    for (ATEMVideoModeOption *option in self.videoModeOptions) {
        if (option.rawMode == rawMode)
            return option;
    }
    return nil;
}

/// Distinct format names, in the order the controller supplied them.
- (NSArray<NSString *> *)videoFormatNames
{
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (ATEMVideoModeOption *option in self.videoModeOptions) {
        if (![names containsObject:option.formatName])
            [names addObject:option.formatName];
    }
    return names;
}

- (void)rebuildVideoFormatPopup
{
    [self.videoFormatPopup removeAllItems];
    for (NSString *name in [self videoFormatNames])
        [self.videoFormatPopup addItemWithTitle:name];
    [self rebuildVideoRatePopupForFormat:self.videoFormatPopup.titleOfSelectedItem selecting:nil];
}

- (void)rebuildVideoRatePopupForFormat:(NSString *)format selecting:(NSString *)frameRate
{
    [self.videoRatePopup removeAllItems];
    for (ATEMVideoModeOption *option in self.videoModeOptions) {
        if (![option.formatName isEqualToString:format])
            continue;
        NSString *title = option.frameRateName.length ? option.frameRateName : @"—";
        if (![self.videoRatePopup itemWithTitle:title])
            [self.videoRatePopup addItemWithTitle:title];
    }
    if (frameRate.length && [self.videoRatePopup itemWithTitle:frameRate])
        [self.videoRatePopup selectItemWithTitle:frameRate];
}

- (ATEMVideoModeOption *)selectedVideoModeOption
{
    NSString *format = self.videoFormatPopup.titleOfSelectedItem;
    NSString *rate = self.videoRatePopup.titleOfSelectedItem;
    if (!format)
        return nil;
    for (ATEMVideoModeOption *option in self.videoModeOptions) {
        if (![option.formatName isEqualToString:format])
            continue;
        NSString *title = option.frameRateName.length ? option.frameRateName : @"—";
        if (!rate || [title isEqualToString:rate])
            return option;
    }
    return nil;
}

- (void)applyVideoModeState:(ATEMState *)state
{
    NSMutableString *signature = [NSMutableString string];
    for (ATEMVideoModeOption *option in state.supportedVideoModes)
        [signature appendFormat:@"%u|", option.rawMode];
    if (![signature isEqualToString:self.videoModeSignature]) {
        self.videoModeSignature = [signature copy];
        self.videoModeOptions = state.supportedVideoModes;
        [self rebuildVideoFormatPopup];
        self.syncedVideoMode = UINT32_MAX;
    }

    BOOL usable = state.isConnected && state.canChangeVideoMode;
    self.videoFormatPopup.enabled = usable;
    self.videoRatePopup.enabled = usable;
    self.videoApplyButton.enabled = usable;

    ATEMVideoModeOption *current = [self videoModeOptionForRawMode:state.videoMode];
    if (!state.isConnected)
        self.videoModeLabel.stringValue = @"Connect to read the switcher video standard.";
    else if (current)
        self.videoModeLabel.stringValue = [NSString stringWithFormat:@"Switcher is running %@.", current.displayName];
    else
        self.videoModeLabel.stringValue = [NSString stringWithFormat:@"Switcher is running an unlabelled mode (%u).", state.videoMode];

    // Only follow the switcher when it actually changed, so a pending selection
    // the user has not applied yet is not yanked out from under them.
    if (state.videoMode != self.syncedVideoMode) {
        self.syncedVideoMode = state.videoMode;
        if (current) {
            [self.videoFormatPopup selectItemWithTitle:current.formatName];
            [self rebuildVideoRatePopupForFormat:current.formatName
                                       selecting:current.frameRateName.length ? current.frameRateName : @"—"];
        }
    }
}

- (void)videoFormatChanged:(NSPopUpButton *)sender
{
    [self rebuildVideoRatePopupForFormat:sender.titleOfSelectedItem selecting:nil];
}

- (void)videoRateChanged:(NSPopUpButton *)sender
{
    (void)sender;
}

- (void)videoStandardApplyPressed:(id)sender
{
    (void)sender;
    ATEMVideoModeOption *option = [self selectedVideoModeOption];
    if (!option)
        return;
    if (option.rawMode == self.state.videoMode)
        return;

    NSAlert *alert = [[NSAlert alloc] init];
    alert.alertStyle = NSAlertStyleCritical;
    alert.messageText = [NSString stringWithFormat:@"Change the video standard to %@?", option.displayName];
    alert.informativeText = @"Every switcher output re-syncs. Program, preview, multiview and any downstream "
                             "recorder or streaming encoder will drop for several seconds, and inputs running a "
                             "different standard will go to black until they are re-locked. Do not do this on air.";
    [alert addButtonWithTitle:@"Change Standard"];
    [alert addButtonWithTitle:@"Cancel"];
    if ([alert runModal] != NSAlertFirstButtonReturn)
        return;

    [self.activeController setVideoMode:option.rawMode];
    self.syncedVideoMode = UINT32_MAX;
}

- (void)rateChanged:(id)sender
{
    NSInteger value = [sender integerValue];
    value = MAX(1, MIN(250, value));
    // Hold off the poll long enough for the switcher to acknowledge the write.
    self.rateEchoSuppressUntil = [NSDate timeIntervalSinceReferenceDate] + 1.0;
    if (self.rateField.integerValue != value)
        self.rateField.integerValue = value;
    if (self.rateStepper.integerValue != value)
        self.rateStepper.integerValue = value;
    [self.activeController setTransitionRate:(uint32_t)value];
}

- (void)upstreamKeyPressed:(ATEMIndexedButton *)sender
{
    BOOL current = sender.itemIndex < self.state.upstreamKeys.count ? self.state.upstreamKeys[sender.itemIndex].isOnAir : NO;
    [self.activeController setUpstreamKey:sender.itemIndex onAir:!current];
}

- (void)dskTiePressed:(ATEMIndexedButton *)sender
{
    BOOL current = sender.itemIndex < self.state.downstreamKeys.count ? self.state.downstreamKeys[sender.itemIndex].isTied : NO;
    [self.activeController setDownstreamKey:sender.itemIndex tied:!current];
}

- (void)dskOnAirPressed:(ATEMIndexedButton *)sender
{
    BOOL current = sender.itemIndex < self.state.downstreamKeys.count ? self.state.downstreamKeys[sender.itemIndex].isOnAir : NO;
    [self.activeController setDownstreamKey:sender.itemIndex onAir:!current];
}

- (void)dskAutoPressed:(ATEMIndexedButton *)sender
{
    [self.activeController performDownstreamKeyAuto:sender.itemIndex];
}

- (void)auxChanged:(NSPopUpButton *)sender
{
    NSNumber *source = sender.selectedItem.representedObject;
    if (source)
        [self.activeController setAuxOutput:sender.tag source:source.longLongValue];
}

- (ATEMMultiviewState *)multiviewStateForIndex:(NSUInteger)index
{
    for (ATEMMultiviewState *multiview in self.state.multiviews) {
        if (multiview.index == index)
            return multiview;
    }
    return nil;
}

- (void)multiviewLayoutChanged:(NSPopUpButton *)sender
{
    [self.activeController setMultiview:(NSUInteger)sender.tag layout:(ATEMMultiviewLayout)sender.selectedItem.tag];
}

- (void)multiviewQuadrantPressed:(ATEMControlButton *)sender
{
    NSUInteger multiviewIndex = MultiviewIndexFromTag(sender.tag);
    sender.active = !sender.isActive;
    NSArray<ATEMControlButton *> *buttons = self.multiviewQuadrantButtons[@(multiviewIndex)];
    const ATEMMultiviewLayout bits[] = {
        ATEMMultiviewLayoutTopLeftSmall,
        ATEMMultiviewLayoutTopRightSmall,
        ATEMMultiviewLayoutBottomLeftSmall,
        ATEMMultiviewLayoutBottomRightSmall,
    };
    uint32_t layoutMask = 0;
    for (NSUInteger index = 0; index < MIN(buttons.count, 4UL); ++index) {
        ATEMControlButton *button = buttons[index];
        button.title = [NSString stringWithFormat:@"%@  %@", @[@"TL", @"TR", @"BL", @"BR"][index], button.isActive ? @"4" : @"1"];
        if (button.isActive)
            layoutMask |= (uint32_t)bits[index];
    }
    [self.activeController setMultiview:multiviewIndex layout:(ATEMMultiviewLayout)layoutMask];
}

- (void)multiviewSwapPressed:(ATEMControlButton *)sender
{
    ATEMMultiviewState *multiview = [self multiviewStateForIndex:(NSUInteger)sender.tag];
    if (multiview)
        [self.activeController setMultiview:multiview.index programPreviewSwapped:!multiview.isProgramPreviewSwapped];
}

- (void)multiviewOpacityChanged:(NSSlider *)sender
{
    [self.activeController setMultiview:(NSUInteger)sender.tag vuMeterOpacity:sender.doubleValue];
}

- (void)multiviewAllLabelsPressed:(ATEMControlButton *)sender
{
    ATEMMultiviewState *multiview = [self multiviewStateForIndex:(NSUInteger)sender.tag];
    if (!multiview)
        return;
    NSUInteger eligibleCount = 0;
    NSUInteger visibleCount = 0;
    for (ATEMMultiviewWindowState *window in multiview.windows) {
        if (!window.supportsLabelOverlay)
            continue;
        ++eligibleCount;
        if (window.isLabelVisible)
            ++visibleCount;
    }
    if (eligibleCount > 0)
        [self.activeController setMultiview:multiview.index allLabelsVisible:visibleCount != eligibleCount];
}

- (void)multiviewAllBordersPressed:(ATEMControlButton *)sender
{
    ATEMMultiviewState *multiview = [self multiviewStateForIndex:(NSUInteger)sender.tag];
    if (!multiview || multiview.windows.count == 0)
        return;
    NSUInteger visibleCount = 0;
    for (ATEMMultiviewWindowState *window in multiview.windows) {
        if (window.isBorderVisible)
            ++visibleCount;
    }
    [self.activeController setMultiview:multiview.index allBordersVisible:visibleCount != multiview.windows.count];
}

- (void)multiviewSourceChanged:(NSPopUpButton *)sender
{
    NSNumber *source = sender.selectedItem.representedObject;
    if (source) {
        [self.activeController setMultiview:MultiviewIndexFromTag(sender.tag)
                                     window:MultiviewWindowFromTag(sender.tag)
                                     source:source.longLongValue];
    }
}

- (void)multiviewVUToggled:(NSButton *)sender
{
    [self.activeController setMultiview:MultiviewIndexFromTag(sender.tag)
                                 window:MultiviewWindowFromTag(sender.tag)
                         vuMeterEnabled:sender.state == NSControlStateValueOn];
}

- (void)multiviewSafeToggled:(NSButton *)sender
{
    [self.activeController setMultiview:MultiviewIndexFromTag(sender.tag)
                                 window:MultiviewWindowFromTag(sender.tag)
                         safeAreaEnabled:sender.state == NSControlStateValueOn];
}

- (void)multiviewLabelToggled:(NSButton *)sender
{
    [self.activeController setMultiview:MultiviewIndexFromTag(sender.tag)
                                 window:MultiviewWindowFromTag(sender.tag)
                            labelVisible:sender.state == NSControlStateValueOn];
}

- (void)multiviewBorderToggled:(NSButton *)sender
{
    [self.activeController setMultiview:MultiviewIndexFromTag(sender.tag)
                                 window:MultiviewWindowFromTag(sender.tag)
                           borderVisible:sender.state == NSControlStateValueOn];
}

- (void)controlTextDidEndEditing:(NSNotification *)notification
{
    if (notification.object == self.rateField)
        [self rateChanged:self.rateField];
    else if (notification.object == self.addressField)
        [self saveAddressForActiveSession];
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    (void)notification;
}

@end

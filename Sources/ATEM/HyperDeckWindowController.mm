#import "HyperDeckWindowController.h"
#import "ATEMController.h"

static NSColor *HDColor(NSUInteger rgb)
{
    return [NSColor colorWithSRGBRed:((rgb >> 16) & 0xFF) / 255.0
                               green:((rgb >> 8) & 0xFF) / 255.0
                                blue:(rgb & 0xFF) / 255.0
                               alpha:1.0];
}

static NSColor *HDCanvas(void)    { return HDColor(0x090D12); }
static NSColor *HDHeader(void)    { return HDColor(0x0E141B); }
static NSColor *HDPanel(void)     { return HDColor(0x151C24); }
static NSColor *HDDivider(void)   { return HDColor(0x2C3A48); }
static NSColor *HDText(void)      { return HDColor(0xF2F5F8); }
static NSColor *HDSecondary(void) { return HDColor(0xA5B0BC); }
static NSColor *HDMuted(void)     { return HDColor(0x6E7B88); }
static NSColor *HDCyan(void)      { return HDColor(0x32C7F3); }
static NSColor *HDGreen(void)     { return HDColor(0x31CE7A); }
static NSColor *HDAmber(void)     { return HDColor(0xF2AE32); }
static NSColor *HDRed(void)       { return HDColor(0xF3485D); }
static NSColor *HDViolet(void)    { return HDColor(0xB27AF5); }

static NSTextField *HDLabel(NSString *text, CGFloat size, NSFontWeight weight, NSColor *color)
{
    NSTextField *label = [NSTextField labelWithString:text ?: @""];
    label.font = [NSFont systemFontOfSize:size weight:weight];
    label.textColor = color ?: HDText();
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    return label;
}

static NSTextField *HDEyebrow(NSString *text)
{
    NSTextField *label = HDLabel(text.uppercaseString, 9.0, NSFontWeightSemibold, HDMuted());
    label.font = [NSFont systemFontOfSize:9.0 weight:NSFontWeightSemibold];
    return label;
}

static NSStackView *HDRow(void)
{
    NSStackView *row = [NSStackView stackViewWithViews:@[]];
    row.orientation = NSUserInterfaceLayoutOrientationHorizontal;
    row.alignment = NSLayoutAttributeCenterY;
    row.distribution = NSStackViewDistributionFill;
    row.spacing = 10;
    return row;
}

static NSStackView *HDColumn(void)
{
    NSStackView *column = [NSStackView stackViewWithViews:@[]];
    column.orientation = NSUserInterfaceLayoutOrientationVertical;
    column.alignment = NSLayoutAttributeLeading;
    column.distribution = NSStackViewDistributionFill;
    column.spacing = 5;
    return column;
}

static NSView *HDFlexibleSpacer(void)
{
    NSView *spacer = [[NSView alloc] initWithFrame:NSZeroRect];
    [spacer setContentHuggingPriority:NSLayoutPriorityDefaultLow
                      forOrientation:NSLayoutConstraintOrientationHorizontal];
    [spacer setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow
                                    forOrientation:NSLayoutConstraintOrientationHorizontal];
    return spacer;
}

static NSTextField *HDEditField(NSString *placeholder)
{
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSZeroRect];
    field.placeholderString = placeholder;
    field.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightMedium];
    field.textColor = HDText();
    field.backgroundColor = HDHeader();
    field.drawsBackground = YES;
    field.bezeled = NO;
    field.focusRingType = NSFocusRingTypeExterior;
    field.wantsLayer = YES;
    field.layer.cornerRadius = 7;
    field.layer.borderWidth = 1;
    field.layer.borderColor = HDDivider().CGColor;
    return field;
}

static NSPopUpButton *HDPopup(void)
{
    NSPopUpButton *popup = [[NSPopUpButton alloc] initWithFrame:NSZeroRect pullsDown:NO];
    popup.font = [NSFont systemFontOfSize:11.5 weight:NSFontWeightMedium];
    popup.contentTintColor = HDText();
    popup.bezelStyle = NSBezelStyleTexturedRounded;
    return popup;
}

static void HDSetButtonTitle(NSButton *button, NSString *title, NSColor *color)
{
    button.attributedTitle = [[NSAttributedString alloc] initWithString:title
                                                             attributes:@{
        NSFontAttributeName: [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: color ?: HDText(),
    }];
}

static NSButton *HDButton(NSString *title, id target, SEL action, NSColor *tint)
{
    NSButton *button = [NSButton buttonWithTitle:title target:target action:action];
    button.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
    button.bezelStyle = NSBezelStyleTexturedRounded;
    button.contentTintColor = tint ?: HDText();
    button.focusRingType = NSFocusRingTypeExterior;
    HDSetButtonTitle(button, title, tint ?: HDText());
    return button;
}

static NSButton *HDToggle(NSString *title, id target, SEL action)
{
    NSButton *button = [NSButton checkboxWithTitle:title target:target action:action];
    button.font = [NSFont systemFontOfSize:11.5 weight:NSFontWeightMedium];
    button.contentTintColor = HDCyan();
    NSAttributedString *styledTitle = [[NSAttributedString alloc] initWithString:title
                                                                      attributes:@{
        NSFontAttributeName: [NSFont systemFontOfSize:11.5 weight:NSFontWeightMedium],
        NSForegroundColorAttributeName: HDText(),
    }];
    button.attributedTitle = styledTitle;
    button.attributedAlternateTitle = styledTitle;
    return button;
}

static BOOL HDValidIPv4Address(NSString *address)
{
    NSString *trimmed = [address stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSArray<NSString *> *parts = [trimmed componentsSeparatedByString:@"."];
    if (parts.count != 4)
        return NO;

    NSCharacterSet *nonDigits = [NSCharacterSet characterSetWithCharactersInString:@"0123456789"].invertedSet;
    BOOL anyNonZero = NO;
    for (NSString *part in parts) {
        if (part.length == 0 || part.length > 3 || [part rangeOfCharacterFromSet:nonDigits].location != NSNotFound)
            return NO;
        NSInteger value = part.integerValue;
        if (value < 0 || value > 255)
            return NO;
        anyNonZero |= value != 0;
    }
    return anyNonZero;
}

static NSString *HDConnectionText(ATEMHyperDeckState *deck)
{
    switch (deck.connectionStatus) {
        case ATEMHyperDeckConnectionStatusConnecting:
            return @"CONNECTING";
        case ATEMHyperDeckConnectionStatusConnected:
            return @"CONNECTED";
        case ATEMHyperDeckConnectionStatusIncompatible:
            return @"INCOMPATIBLE";
        case ATEMHyperDeckConnectionStatusNotConnected:
        default:
            return deck.networkAddress.length ? @"OFFLINE" : @"NOT CONFIGURED";
    }
}

static NSColor *HDConnectionColor(ATEMHyperDeckState *deck)
{
    switch (deck.connectionStatus) {
        case ATEMHyperDeckConnectionStatusConnecting:
            return HDAmber();
        case ATEMHyperDeckConnectionStatusConnected:
            return HDGreen();
        case ATEMHyperDeckConnectionStatusIncompatible:
            return HDRed();
        case ATEMHyperDeckConnectionStatusNotConnected:
        default:
            return deck.networkAddress.length ? HDRed() : HDMuted();
    }
}

static NSString *HDPlayerText(ATEMHyperDeckPlayerState state)
{
    switch (state) {
        case ATEMHyperDeckPlayerStateIdle: return @"IDLE";
        case ATEMHyperDeckPlayerStatePlay: return @"PLAY";
        case ATEMHyperDeckPlayerStateRecord: return @"RECORD";
        case ATEMHyperDeckPlayerStateShuttle: return @"SHUTTLE";
        case ATEMHyperDeckPlayerStateUnknown:
        default: return @"UNKNOWN";
    }
}

@interface HDDeckCardView : NSView
@property(nonatomic) int64_t deckID;
@property(nonatomic, strong) NSTextField *titleLabel;
@property(nonatomic, strong) NSTextField *modelLabel;
@property(nonatomic, strong) NSView *statusDot;
@property(nonatomic, strong) NSTextField *statusLabel;
@property(nonatomic, strong) NSTextField *remoteLabel;
@property(nonatomic, strong) NSTextField *addressField;
@property(nonatomic, strong) NSTextField *addressMessage;
@property(nonatomic, strong) NSButton *applyButton;
@property(nonatomic, strong) NSButton *disableButton;
@property(nonatomic, strong) NSPopUpButton *inputPopup;
@property(nonatomic, strong) NSPopUpButton *clipPopup;
@property(nonatomic, strong) NSTextField *timecodeLabel;
@property(nonatomic, strong) NSTextField *clipLabel;
@property(nonatomic, strong) NSTextField *remainingLabel;
@property(nonatomic, strong) NSTextField *playerLabel;
@property(nonatomic, strong) NSButton *playButton;
@property(nonatomic, strong) NSButton *stopButton;
@property(nonatomic, strong) NSButton *recordButton;
@property(nonatomic, strong) NSButton *jogBackButton;
@property(nonatomic, strong) NSButton *jogForwardButton;
@property(nonatomic, strong) NSSlider *shuttleSlider;
@property(nonatomic, strong) NSTextField *shuttleLabel;
@property(nonatomic, strong) NSButton *loopButton;
@property(nonatomic, strong) NSButton *singleButton;
@property(nonatomic, strong) NSButton *autoRollButton;
@property(nonatomic, strong) NSTextField *frameDelayField;
@property(nonatomic, strong) NSStepper *frameDelayStepper;
@property(nonatomic) BOOL addressDirty;
@property(nonatomic, copy, nullable) NSString *pendingAddress;
@property(nonatomic) CFAbsoluteTime pendingAddressDeadline;
@property(nonatomic) BOOL hasPendingInput;
@property(nonatomic) int64_t pendingInputID;
@property(nonatomic) CFAbsoluteTime pendingInputDeadline;
@property(nonatomic, copy) NSString *clipMenuSignature;
@end

@implementation HDDeckCardView

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (!self)
        return nil;
    self.wantsLayer = YES;
    self.layer.backgroundColor = HDPanel().CGColor;
    self.layer.cornerRadius = 12;
    self.layer.borderWidth = 1;
    self.layer.borderColor = HDDivider().CGColor;
    return self;
}

@end

@interface HyperDeckWindowController () <NSTextFieldDelegate>
@property(nonatomic, copy) NSArray<ATEMController *> *controllers;
@property(nonatomic) NSUInteger activeSessionIndex;
@property(nonatomic, strong) NSSegmentedControl *sessionSelector;
@property(nonatomic, strong) NSTextField *switcherLabel;
@property(nonatomic, strong) NSTextField *switcherStatusLabel;
@property(nonatomic, strong) NSView *switcherStatusDot;
@property(nonatomic, strong) NSScrollView *scrollView;
@property(nonatomic, strong) NSStackView *deckStack;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, HDDeckCardView *> *cardsByID;
@property(nonatomic, copy) NSString *structureSignature;
@end

@implementation HyperDeckWindowController

- (instancetype)initWithControllers:(NSArray<ATEMController *> *)controllers
                initialSessionIndex:(NSUInteger)sessionIndex
{
    NSParameterAssert(controllers.count == 2);
    NSRect frame = NSMakeRect(0, 0, 1160, 760);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                  styleMask:(NSWindowStyleMaskTitled |
                                                             NSWindowStyleMaskClosable |
                                                             NSWindowStyleMaskMiniaturizable |
                                                             NSWindowStyleMaskResizable)
                                                    backing:NSBackingStoreBuffered
                                                      defer:NO];
    window.title = @"ATEM CNTRL — HyperDeck";
    window.minSize = NSMakeSize(900, 620);
    window.backgroundColor = HDCanvas();
    window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    window.titlebarAppearsTransparent = YES;
    window.titleVisibility = NSWindowTitleHidden;
    window.tabbingMode = NSWindowTabbingModeDisallowed;
    window.sharingType = NSWindowSharingReadOnly;
    [window setFrameAutosaveName:@"ATEMCNTRLHyperDeckWindow"];
    [window center];

    self = [super initWithWindow:window];
    if (!self)
        return nil;

    _controllers = [controllers copy];
    _activeSessionIndex = MIN(sessionIndex, controllers.count - 1);
    _cardsByID = [NSMutableDictionary dictionary];
    [self buildInterface];

    for (ATEMController *controller in controllers) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(hyperDeckStateDidChange:)
                                                     name:ATEMHyperDeckStateDidChangeNotification
                                                   object:controller];
    }
    [self refreshSessionSelector];
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

- (void)buildInterface
{
    NSView *root = [[NSView alloc] initWithFrame:NSZeroRect];
    root.wantsLayer = YES;
    root.layer.backgroundColor = HDCanvas().CGColor;
    self.window.contentView = root;

    NSView *header = [[NSView alloc] initWithFrame:NSZeroRect];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.wantsLayer = YES;
    header.layer.backgroundColor = HDHeader().CGColor;
    header.layer.borderColor = HDDivider().CGColor;
    header.layer.borderWidth = 1;
    [root addSubview:header];

    NSTextField *title = HDLabel(@"HYPERDECK CONTROL", 20, NSFontWeightSemibold, HDText());
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:title];
    NSTextField *subtitle = HDLabel(@"ATEM-managed playback and recording  •  TCP 9993", 10, NSFontWeightMedium, HDSecondary());
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:subtitle];

    NSTextField *targetLabel = HDEyebrow(@"Control target");
    targetLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:targetLabel];
    self.sessionSelector = [NSSegmentedControl segmentedControlWithLabels:@[@"A  ○", @"B  ○"]
                                                              trackingMode:NSSegmentSwitchTrackingSelectOne
                                                                    target:self
                                                                    action:@selector(sessionChanged:)];
    self.sessionSelector.translatesAutoresizingMaskIntoConstraints = NO;
    self.sessionSelector.segmentStyle = NSSegmentStyleCapsule;
    self.sessionSelector.selectedSegmentBezelColor = HDCyan();
    self.sessionSelector.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
    self.sessionSelector.selectedSegment = self.activeSessionIndex;
    self.sessionSelector.toolTip = @"Select the ATEM whose HyperDeck interfaces receive commands.";
    self.sessionSelector.accessibilityLabel = @"Active ATEM session";
    [header addSubview:self.sessionSelector];

    NSTextField *switcherEyebrow = HDEyebrow(@"Active switcher");
    switcherEyebrow.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:switcherEyebrow];
    self.switcherStatusDot = [[NSView alloc] initWithFrame:NSZeroRect];
    self.switcherStatusDot.translatesAutoresizingMaskIntoConstraints = NO;
    self.switcherStatusDot.wantsLayer = YES;
    self.switcherStatusDot.layer.cornerRadius = 4;
    self.switcherStatusDot.layer.backgroundColor = HDMuted().CGColor;
    [header addSubview:self.switcherStatusDot];
    self.switcherLabel = HDLabel(@"Not connected", 12.5, NSFontWeightSemibold, HDText());
    self.switcherLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:self.switcherLabel];
    self.switcherStatusLabel = HDLabel(@"Connect an ATEM in the main console.", 10, NSFontWeightRegular, HDSecondary());
    self.switcherStatusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:self.switcherStatusLabel];

    self.scrollView = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.drawsBackground = NO;
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.autohidesScrollers = YES;
    [root addSubview:self.scrollView];

    NSView *document = [[NSView alloc] initWithFrame:NSZeroRect];
    document.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.documentView = document;
    self.deckStack = [NSStackView stackViewWithViews:@[]];
    self.deckStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.deckStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.deckStack.alignment = NSLayoutAttributeLeading;
    self.deckStack.distribution = NSStackViewDistributionFill;
    self.deckStack.spacing = 16;
    [document addSubview:self.deckStack];

    [NSLayoutConstraint activateConstraints:@[
        [header.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [header.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [header.topAnchor constraintEqualToAnchor:root.topAnchor],
        [header.heightAnchor constraintEqualToConstant:94],

        [title.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:22],
        [title.topAnchor constraintEqualToAnchor:header.topAnchor constant:19],
        [subtitle.leadingAnchor constraintEqualToAnchor:title.leadingAnchor],
        [subtitle.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:3],

        [targetLabel.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:310],
        [targetLabel.topAnchor constraintEqualToAnchor:header.topAnchor constant:15],
        [self.sessionSelector.leadingAnchor constraintEqualToAnchor:targetLabel.leadingAnchor],
        [self.sessionSelector.topAnchor constraintEqualToAnchor:header.topAnchor constant:33],
        [self.sessionSelector.widthAnchor constraintEqualToConstant:144],
        [self.sessionSelector.heightAnchor constraintEqualToConstant:32],

        [switcherEyebrow.leadingAnchor constraintEqualToAnchor:self.sessionSelector.trailingAnchor constant:30],
        [switcherEyebrow.topAnchor constraintEqualToAnchor:targetLabel.topAnchor],
        [self.switcherStatusDot.leadingAnchor constraintEqualToAnchor:switcherEyebrow.leadingAnchor],
        [self.switcherStatusDot.centerYAnchor constraintEqualToAnchor:self.switcherLabel.centerYAnchor],
        [self.switcherStatusDot.widthAnchor constraintEqualToConstant:8],
        [self.switcherStatusDot.heightAnchor constraintEqualToConstant:8],
        [self.switcherLabel.leadingAnchor constraintEqualToAnchor:self.switcherStatusDot.trailingAnchor constant:8],
        [self.switcherLabel.topAnchor constraintEqualToAnchor:header.topAnchor constant:34],
        [self.switcherLabel.trailingAnchor constraintLessThanOrEqualToAnchor:header.trailingAnchor constant:-22],
        [self.switcherStatusLabel.leadingAnchor constraintEqualToAnchor:switcherEyebrow.leadingAnchor],
        [self.switcherStatusLabel.topAnchor constraintEqualToAnchor:self.switcherLabel.bottomAnchor constant:3],
        [self.switcherStatusLabel.trailingAnchor constraintLessThanOrEqualToAnchor:header.trailingAnchor constant:-22],

        [self.scrollView.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [self.scrollView.topAnchor constraintEqualToAnchor:header.bottomAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:root.bottomAnchor],

        [document.leadingAnchor constraintEqualToAnchor:self.scrollView.contentView.leadingAnchor],
        [document.trailingAnchor constraintEqualToAnchor:self.scrollView.contentView.trailingAnchor],
        [document.topAnchor constraintEqualToAnchor:self.scrollView.contentView.topAnchor],
        [document.widthAnchor constraintEqualToAnchor:self.scrollView.contentView.widthAnchor],
        [self.deckStack.leadingAnchor constraintEqualToAnchor:document.leadingAnchor constant:20],
        [self.deckStack.trailingAnchor constraintEqualToAnchor:document.trailingAnchor constant:-20],
        [self.deckStack.topAnchor constraintEqualToAnchor:document.topAnchor constant:20],
        [self.deckStack.bottomAnchor constraintEqualToAnchor:document.bottomAnchor constant:-20],
    ]];
}

- (void)sessionChanged:(NSSegmentedControl *)sender
{
    NSInteger selected = sender.selectedSegment;
    if (selected < 0 || (NSUInteger)selected >= self.controllers.count)
        return;
    self.activeSessionIndex = (NSUInteger)selected;
    self.structureSignature = nil;
    [self refreshSessionSelector];
    [self refreshActiveSession];
}

- (void)selectSessionIndex:(NSUInteger)sessionIndex
{
    if (sessionIndex >= self.controllers.count || sessionIndex == self.activeSessionIndex)
        return;
    self.sessionSelector.selectedSegment = (NSInteger)sessionIndex;
    [self sessionChanged:self.sessionSelector];
}

- (void)hyperDeckStateDidChange:(NSNotification *)notification
{
    NSAssert(NSThread.isMainThread, @"HyperDeck notifications must be delivered on the main thread");
    [self refreshSessionSelector];
    if (notification.object == self.activeController)
        [self refreshActiveSession];
}

- (void)refreshSessionSelector
{
    [self.controllers enumerateObjectsUsingBlock:^(ATEMController *controller, NSUInteger index, BOOL *stop) {
        (void)stop;
        NSString *letter = index == 0 ? @"A" : @"B";
        ATEMState *state = controller.latestState;
        NSString *indicator = state.isConnected ? @"●" : (state.isConnecting ? @"…" : @"○");
        [self.sessionSelector setLabel:[NSString stringWithFormat:@"%@  %@", letter, indicator] forSegment:index];
    }];
    self.sessionSelector.selectedSegment = self.activeSessionIndex;
}

- (NSString *)structureSignatureForDecks:(NSArray<ATEMHyperDeckState *> *)decks
                                  inputs:(NSArray<ATEMInputState *> *)inputs
{
    NSMutableString *signature = [NSMutableString string];
    for (ATEMHyperDeckState *deck in decks)
        [signature appendFormat:@"d:%lld;", deck.deckID];
    [signature appendString:@"|"];
    for (ATEMInputState *input in inputs)
        [signature appendFormat:@"i:%lld:%@;", input.inputID, input.longName];
    return signature;
}

- (void)refreshActiveSession
{
    ATEMController *controller = self.activeController;
    ATEMState *switcherState = controller.latestState;
    NSArray<ATEMHyperDeckState *> *decks = controller.latestHyperDeckStates ?: @[];
    NSArray<ATEMInputState *> *inputs = switcherState.inputs ?: @[];
    NSString *session = self.activeSessionIndex == 0 ? @"A" : @"B";
    NSString *product = switcherState.productName.length ? switcherState.productName : @"Not connected";
    NSString *endpoint = switcherState.isDemo
        ? @"DEMO TARGET"
        : (controller.currentAddress.length
            ? [NSString stringWithFormat:@"IP %@", controller.currentAddress]
            : @"NO IP TARGET");
    self.switcherLabel.stringValue =
        [NSString stringWithFormat:@"ATEM %@ — %@ — %@", session, product, endpoint];
    self.switcherLabel.toolTip = self.switcherLabel.stringValue;
    self.switcherLabel.accessibilityValue = self.switcherLabel.stringValue;
    self.switcherStatusLabel.stringValue = switcherState.isDemo
        ? @"Demo mode — no HyperDeck hardware commands are sent."
        : (switcherState.statusMessage.length ? switcherState.statusMessage : @"Connect an ATEM in the main console.");
    self.switcherStatusDot.layer.backgroundColor = (switcherState.isDemo ? HDViolet() :
                                                    (switcherState.isConnected ? HDGreen() :
                                                     (switcherState.isConnecting ? HDAmber() : HDMuted()))).CGColor;


    NSString *signature = [self structureSignatureForDecks:decks inputs:inputs];
    if (![signature isEqualToString:self.structureSignature]) {
        self.structureSignature = signature;
        [self rebuildCardsForDecks:decks inputs:inputs];
    }

    for (ATEMHyperDeckState *deck in decks) {
        HDDeckCardView *card = self.cardsByID[@(deck.deckID)];
        if (card)
            [self applyDeck:deck toCard:card switcherConnected:switcherState.isConnected];
    }
}

- (void)removeAllDeckViews
{
    for (NSView *view in self.deckStack.arrangedSubviews.copy) {
        [self.deckStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    [self.cardsByID removeAllObjects];
}

- (void)rebuildCardsForDecks:(NSArray<ATEMHyperDeckState *> *)decks
                      inputs:(NSArray<ATEMInputState *> *)inputs
{
    [self removeAllDeckViews];
    if (decks.count == 0) {
        NSView *empty = [[NSView alloc] initWithFrame:NSZeroRect];
        empty.wantsLayer = YES;
        empty.layer.backgroundColor = HDPanel().CGColor;
        empty.layer.cornerRadius = 12;
        empty.layer.borderWidth = 1;
        empty.layer.borderColor = HDDivider().CGColor;
        NSTextField *title = HDLabel(@"No HyperDeck interfaces available", 16, NSFontWeightSemibold, HDText());
        title.translatesAutoresizingMaskIntoConstraints = NO;
        NSTextField *detail = [NSTextField wrappingLabelWithString:@"Connect an ATEM that supports HyperDeck control. The ATEM—not this Mac—will connect to each configured HyperDeck on TCP port 9993."];
        detail.translatesAutoresizingMaskIntoConstraints = NO;
        detail.font = [NSFont systemFontOfSize:12 weight:NSFontWeightRegular];
        detail.textColor = HDSecondary();
        detail.alignment = NSTextAlignmentCenter;
        [empty addSubview:title];
        [empty addSubview:detail];
        [self.deckStack addArrangedSubview:empty];
        [empty.widthAnchor constraintEqualToAnchor:self.deckStack.widthAnchor].active = YES;
        [empty.heightAnchor constraintEqualToConstant:190].active = YES;
        [NSLayoutConstraint activateConstraints:@[
            [title.centerXAnchor constraintEqualToAnchor:empty.centerXAnchor],
            [title.topAnchor constraintEqualToAnchor:empty.topAnchor constant:55],
            [detail.centerXAnchor constraintEqualToAnchor:empty.centerXAnchor],
            [detail.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:12],
            [detail.widthAnchor constraintLessThanOrEqualToConstant:590],
        ]];
        return;
    }

    for (ATEMHyperDeckState *deck in decks) {
        HDDeckCardView *card = [self buildCardForDeck:deck inputs:inputs];
        self.cardsByID[@(deck.deckID)] = card;
        [self.deckStack addArrangedSubview:card];
        [card.widthAnchor constraintEqualToAnchor:self.deckStack.widthAnchor].active = YES;
        [card.heightAnchor constraintEqualToConstant:334].active = YES;
    }
}

- (HDDeckCardView *)buildCardForDeck:(ATEMHyperDeckState *)deck
                              inputs:(NSArray<ATEMInputState *> *)inputs
{
    HDDeckCardView *card = [[HDDeckCardView alloc] initWithFrame:NSZeroRect];
    card.deckID = deck.deckID;
    NSStackView *content = [NSStackView stackViewWithViews:@[]];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    content.orientation = NSUserInterfaceLayoutOrientationVertical;
    content.alignment = NSLayoutAttributeLeading;
    content.distribution = NSStackViewDistributionFill;
    content.spacing = 13;
    [card addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [content.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],
        [content.trailingAnchor constraintEqualToAnchor:card.trailingAnchor constant:-18],
        [content.topAnchor constraintEqualToAnchor:card.topAnchor constant:16],
        [content.bottomAnchor constraintEqualToAnchor:card.bottomAnchor constant:-16],
    ]];

    NSStackView *titleRow = HDRow();
    card.statusDot = [[NSView alloc] initWithFrame:NSZeroRect];
    card.statusDot.wantsLayer = YES;
    card.statusDot.layer.cornerRadius = 5;
    card.statusDot.layer.backgroundColor = HDMuted().CGColor;
    [card.statusDot.widthAnchor constraintEqualToConstant:10].active = YES;
    [card.statusDot.heightAnchor constraintEqualToConstant:10].active = YES;
    [titleRow addArrangedSubview:card.statusDot];
    NSStackView *identity = HDColumn();
    card.titleLabel = HDLabel(deck.name, 15, NSFontWeightSemibold, HDText());
    card.modelLabel = HDLabel(deck.modelName, 10.5, NSFontWeightRegular, HDSecondary());
    [identity addArrangedSubview:card.titleLabel];
    [identity addArrangedSubview:card.modelLabel];
    [titleRow addArrangedSubview:identity];
    [titleRow addArrangedSubview:HDFlexibleSpacer()];
    card.remoteLabel = HDLabel(@"AWAITING CONNECTION", 10, NSFontWeightSemibold, HDMuted());
    [titleRow addArrangedSubview:card.remoteLabel];
    card.statusLabel = HDLabel(@"NOT CONFIGURED", 10.5, NSFontWeightSemibold, HDMuted());
    [titleRow addArrangedSubview:card.statusLabel];
    [card.statusLabel.widthAnchor constraintGreaterThanOrEqualToConstant:104].active = YES;
    [content addArrangedSubview:titleRow];
    [titleRow.widthAnchor constraintEqualToAnchor:content.widthAnchor].active = YES;

    NSStackView *configuration = HDRow();
    NSStackView *addressGroup = HDColumn();
    [addressGroup addArrangedSubview:HDEyebrow(@"HyperDeck IPv4 address")];
    card.addressField = HDEditField(@"192.168.1.50");
    card.addressField.delegate = self;
    card.addressField.tag = (NSInteger)deck.deckID;
    card.addressField.target = self;
    card.addressField.action = @selector(applyAddress:);
    card.addressField.stringValue = deck.networkAddress ?: @"";
    card.addressField.toolTip = @"The ATEM will connect to this HyperDeck on TCP port 9993.";
    card.addressField.accessibilityLabel = [NSString stringWithFormat:@"%@ IP address", deck.name];
    [addressGroup addArrangedSubview:card.addressField];
    [card.addressField.widthAnchor constraintEqualToConstant:164].active = YES;
    card.addressMessage = HDLabel(@"ATEM initiates the connection", 9, NSFontWeightRegular, HDMuted());
    [addressGroup addArrangedSubview:card.addressMessage];
    [configuration addArrangedSubview:addressGroup];

    card.applyButton = HDButton(@"APPLY", self, @selector(applyAddress:), HDCyan());
    card.applyButton.tag = (NSInteger)deck.deckID;
    card.applyButton.toolTip = @"Save this address in the selected ATEM and begin connecting.";
    card.applyButton.accessibilityLabel = [NSString stringWithFormat:@"Apply %@ address", deck.name];
    [configuration addArrangedSubview:card.applyButton];
    [card.applyButton.widthAnchor constraintEqualToConstant:72].active = YES;
    card.disableButton = HDButton(@"CLEAR ADDRESS", self, @selector(disableDeck:), HDSecondary());
    card.disableButton.tag = (NSInteger)deck.deckID;
    card.disableButton.toolTip = @"Clear this address in the ATEM and stop its HyperDeck connection attempts.";
    card.disableButton.accessibilityLabel = [NSString stringWithFormat:@"Clear %@ address", deck.name];
    [configuration addArrangedSubview:card.disableButton];
    [card.disableButton.widthAnchor constraintEqualToConstant:112].active = YES;

    NSStackView *inputGroup = HDColumn();
    [inputGroup addArrangedSubview:HDEyebrow(@"Associated ATEM input")];
    card.inputPopup = HDPopup();
    card.inputPopup.tag = (NSInteger)deck.deckID;
    card.inputPopup.target = self;
    card.inputPopup.action = @selector(inputChanged:);
    [card.inputPopup removeAllItems];
    NSMenuItem *none = [[NSMenuItem alloc] initWithTitle:@"None — no tally association" action:nil keyEquivalent:@""];
    none.representedObject = @0;
    [card.inputPopup.menu addItem:none];
    for (ATEMInputState *input in inputs) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:input.longName action:nil keyEquivalent:@""];
        item.representedObject = @(input.inputID);
        [card.inputPopup.menu addItem:item];
    }
    card.inputPopup.toolTip = @"Associates tally for automatic roll-on-take. Only external ATEM inputs are accepted by the SDK.";
    card.inputPopup.accessibilityLabel = [NSString stringWithFormat:@"%@ associated ATEM input", deck.name];
    [inputGroup addArrangedSubview:card.inputPopup];
    [card.inputPopup.widthAnchor constraintEqualToConstant:230].active = YES;
    [configuration addArrangedSubview:inputGroup];
    [configuration addArrangedSubview:HDFlexibleSpacer()];

    NSStackView *clipGroup = HDColumn();
    [clipGroup addArrangedSubview:HDEyebrow(@"Current clip")];
    card.clipPopup = HDPopup();
    card.clipPopup.tag = (NSInteger)deck.deckID;
    card.clipPopup.target = self;
    card.clipPopup.action = @selector(clipChanged:);
    card.clipPopup.toolTip = @"Select a clip from the active HyperDeck storage media.";
    card.clipPopup.accessibilityLabel = [NSString stringWithFormat:@"%@ current clip", deck.name];
    [clipGroup addArrangedSubview:card.clipPopup];
    [card.clipPopup.widthAnchor constraintEqualToConstant:190].active = YES;
    [configuration addArrangedSubview:clipGroup];
    [content addArrangedSubview:configuration];
    [configuration.widthAnchor constraintEqualToAnchor:content.widthAnchor].active = YES;

    NSView *divider = [[NSView alloc] initWithFrame:NSZeroRect];
    divider.wantsLayer = YES;
    divider.layer.backgroundColor = HDDivider().CGColor;
    [content addArrangedSubview:divider];
    [divider.widthAnchor constraintEqualToAnchor:content.widthAnchor].active = YES;
    [divider.heightAnchor constraintEqualToConstant:1].active = YES;

    NSStackView *transport = HDRow();
    NSStackView *timeGroup = HDColumn();
    [timeGroup addArrangedSubview:HDEyebrow(@"Timeline")];
    card.timecodeLabel = HDLabel(@"--:--:--:--", 25, NSFontWeightSemibold, HDText());
    card.timecodeLabel.font = [NSFont monospacedDigitSystemFontOfSize:25 weight:NSFontWeightSemibold];
    [timeGroup addArrangedSubview:card.timecodeLabel];
    card.clipLabel = HDLabel(@"No clip selected", 9.5, NSFontWeightMedium, HDSecondary());
    [timeGroup addArrangedSubview:card.clipLabel];
    [transport addArrangedSubview:timeGroup];
    [timeGroup.widthAnchor constraintEqualToConstant:184].active = YES;

    card.jogBackButton = HDButton(@"−1", self, @selector(jogBack:), HDSecondary());
    card.jogBackButton.tag = (NSInteger)deck.deckID;
    card.jogBackButton.toolTip = @"Jog backward one frame.";
    [transport addArrangedSubview:card.jogBackButton];
    [card.jogBackButton.widthAnchor constraintEqualToConstant:50].active = YES;
    card.stopButton = HDButton(@"■  STOP", self, @selector(stop:), HDText());
    card.stopButton.tag = (NSInteger)deck.deckID;
    [transport addArrangedSubview:card.stopButton];
    [card.stopButton.widthAnchor constraintEqualToConstant:82].active = YES;
    card.playButton = HDButton(@"▶  PLAY", self, @selector(play:), HDGreen());
    card.playButton.tag = (NSInteger)deck.deckID;
    [transport addArrangedSubview:card.playButton];
    [card.playButton.widthAnchor constraintEqualToConstant:82].active = YES;
    card.recordButton = HDButton(@"●  RECORD", self, @selector(record:), HDRed());
    card.recordButton.tag = (NSInteger)deck.deckID;
    card.recordButton.toolTip = @"Begin recording on this HyperDeck.";
    [transport addArrangedSubview:card.recordButton];
    [card.recordButton.widthAnchor constraintEqualToConstant:96].active = YES;
    card.jogForwardButton = HDButton(@"+1", self, @selector(jogForward:), HDSecondary());
    card.jogForwardButton.tag = (NSInteger)deck.deckID;
    card.jogForwardButton.toolTip = @"Jog forward one frame.";
    [transport addArrangedSubview:card.jogForwardButton];
    [card.jogForwardButton.widthAnchor constraintEqualToConstant:50].active = YES;

    [transport addArrangedSubview:HDFlexibleSpacer()];
    NSStackView *remainingGroup = HDColumn();
    [remainingGroup addArrangedSubview:HDEyebrow(@"Record time remaining")];
    card.remainingLabel = HDLabel(@"--:--:--:--", 14, NSFontWeightMedium, HDText());
    card.remainingLabel.font = [NSFont monospacedDigitSystemFontOfSize:14 weight:NSFontWeightMedium];
    [remainingGroup addArrangedSubview:card.remainingLabel];
    [transport addArrangedSubview:remainingGroup];
    card.playerLabel = HDLabel(@"UNKNOWN", 10, NSFontWeightSemibold, HDMuted());
    [transport addArrangedSubview:card.playerLabel];
    [card.playerLabel.widthAnchor constraintGreaterThanOrEqualToConstant:64].active = YES;
    [content addArrangedSubview:transport];
    [transport.widthAnchor constraintEqualToAnchor:content.widthAnchor].active = YES;

    NSStackView *options = HDRow();
    NSStackView *shuttleGroup = HDColumn();
    NSStackView *shuttleHeader = HDRow();
    [shuttleHeader addArrangedSubview:HDEyebrow(@"Shuttle speed")];
    [shuttleHeader addArrangedSubview:HDFlexibleSpacer()];
    card.shuttleLabel = HDLabel(@"0%", 10, NSFontWeightSemibold, HDCyan());
    [shuttleHeader addArrangedSubview:card.shuttleLabel];
    [shuttleGroup addArrangedSubview:shuttleHeader];
    card.shuttleSlider = [NSSlider sliderWithValue:0
                                        minValue:-400
                                        maxValue:400
                                           target:self
                                           action:@selector(shuttleChanged:)];
    card.shuttleSlider.tag = (NSInteger)deck.deckID;
    card.shuttleSlider.continuous = NO;
    card.shuttleSlider.numberOfTickMarks = 9;
    card.shuttleSlider.allowsTickMarkValuesOnly = NO;
    card.shuttleSlider.controlSize = NSControlSizeSmall;
    card.shuttleSlider.toolTip = @"Shuttle from −400% reverse to +400% forward.";
    [shuttleGroup addArrangedSubview:card.shuttleSlider];
    [card.shuttleSlider.widthAnchor constraintEqualToConstant:240].active = YES;
    [shuttleHeader.widthAnchor constraintEqualToAnchor:card.shuttleSlider.widthAnchor].active = YES;
    [options addArrangedSubview:shuttleGroup];

    [options addArrangedSubview:HDFlexibleSpacer()];
    card.loopButton = HDToggle(@"Loop", self, @selector(loopChanged:));
    card.loopButton.tag = (NSInteger)deck.deckID;
    [options addArrangedSubview:card.loopButton];
    card.singleButton = HDToggle(@"Single clip", self, @selector(singleChanged:));
    card.singleButton.tag = (NSInteger)deck.deckID;
    [options addArrangedSubview:card.singleButton];
    card.autoRollButton = HDToggle(@"Auto-roll on take", self, @selector(autoRollChanged:));
    card.autoRollButton.tag = (NSInteger)deck.deckID;
    card.autoRollButton.toolTip = @"Start playback when the associated ATEM input is tallied to Program.";
    [options addArrangedSubview:card.autoRollButton];

    NSStackView *delayGroup = HDColumn();
    [delayGroup addArrangedSubview:HDEyebrow(@"Frame delay")];
    NSStackView *delayControls = HDRow();
    card.frameDelayField = HDEditField(@"0");
    card.frameDelayField.tag = (NSInteger)deck.deckID;
    card.frameDelayField.alignment = NSTextAlignmentRight;
    card.frameDelayField.target = self;
    card.frameDelayField.action = @selector(frameDelayChanged:);
    NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
    formatter.numberStyle = NSNumberFormatterDecimalStyle;
    formatter.allowsFloats = NO;
    formatter.minimum = @0;
    formatter.maximum = @65535;
    card.frameDelayField.formatter = formatter;
    [delayControls addArrangedSubview:card.frameDelayField];
    [card.frameDelayField.widthAnchor constraintEqualToConstant:62].active = YES;
    card.frameDelayStepper = [[NSStepper alloc] initWithFrame:NSZeroRect];
    card.frameDelayStepper.tag = (NSInteger)deck.deckID;
    card.frameDelayStepper.minValue = 0;
    card.frameDelayStepper.maxValue = 65535;
    card.frameDelayStepper.increment = 1;
    card.frameDelayStepper.target = self;
    card.frameDelayStepper.action = @selector(frameDelayChanged:);
    [delayControls addArrangedSubview:card.frameDelayStepper];
    [delayGroup addArrangedSubview:delayControls];
    [options addArrangedSubview:delayGroup];
    [content addArrangedSubview:options];
    [options.widthAnchor constraintEqualToAnchor:content.widthAnchor].active = YES;

    return card;
}

- (HDDeckCardView *)cardForSender:(NSControl *)sender
{
    return self.cardsByID[@((int64_t)sender.tag)];
}

- (void)setAddressMessageForCard:(HDDeckCardView *)card text:(NSString *)text color:(NSColor *)color
{
    card.addressMessage.stringValue = text ?: @"";
    card.addressMessage.textColor = color ?: HDMuted();
    card.addressField.layer.borderColor = ([color isEqual:HDRed()] ? HDRed() : HDDivider()).CGColor;
}

- (void)applyDeck:(ATEMHyperDeckState *)deck
           toCard:(HDDeckCardView *)card
switcherConnected:(BOOL)switcherConnected
{
    card.titleLabel.stringValue = deck.name ?: @"HyperDeck";
    card.modelLabel.stringValue = deck.modelName.length ? deck.modelName : @"HyperDeck Slot";
    card.statusLabel.stringValue = HDConnectionText(deck);
    card.statusLabel.textColor = HDConnectionColor(deck);
    card.statusDot.layer.backgroundColor = HDConnectionColor(deck).CGColor;

    BOOL deckConnected = deck.connectionStatus == ATEMHyperDeckConnectionStatusConnected;
    BOOL remoteReady = deckConnected && deck.isRemoteAccessEnabled;
    if (remoteReady) {
        card.remoteLabel.stringValue = @"REMOTE READY";
        card.remoteLabel.textColor = HDGreen();
    } else if (deckConnected) {
        card.remoteLabel.stringValue = @"REMOTE DISABLED • READ ONLY";
        card.remoteLabel.textColor = HDAmber();
    } else {
        card.remoteLabel.stringValue = @"AWAITING CONNECTION";
        card.remoteLabel.textColor = HDMuted();
    }

    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    if (card.pendingAddress) {
        if ([deck.networkAddress isEqualToString:card.pendingAddress] || now > card.pendingAddressDeadline)
            card.pendingAddress = nil;
    }
    if (!card.addressDirty && !card.pendingAddress &&
        self.window.firstResponder != card.addressField.currentEditor)
        card.addressField.stringValue = deck.networkAddress ?: @"";

    BOOL validAddress = HDValidIPv4Address(card.addressField.stringValue);
    card.applyButton.enabled = switcherConnected && validAddress;
    card.disableButton.enabled = switcherConnected && (deck.networkAddress.length || card.pendingAddress.length);
    card.addressField.enabled = switcherConnected;
    if (!card.addressDirty && !card.pendingAddress) {
        NSString *message = deck.networkAddress.length
            ? (deck.connectionStatus == ATEMHyperDeckConnectionStatusConnecting ? @"ATEM is connecting on TCP 9993" :
               (deckConnected ? @"ATEM owns the TCP 9993 connection" : @"Configured in ATEM • currently offline"))
            : @"ATEM initiates the connection";
        [self setAddressMessageForCard:card text:message color:HDMuted()];
    }

    int64_t displayedInput = deck.switcherInputID;
    if (card.hasPendingInput) {
        if (deck.switcherInputID == card.pendingInputID || now > card.pendingInputDeadline)
            card.hasPendingInput = NO;
        else
            displayedInput = card.pendingInputID;
    }
    for (NSMenuItem *item in card.inputPopup.itemArray) {
        if ([item.representedObject longLongValue] == displayedInput) {
            [card.inputPopup selectItem:item];
            break;
        }
    }
    card.inputPopup.enabled = switcherConnected;

    [self updateClipPopupForDeck:deck card:card];
    card.clipPopup.enabled = remoteReady && deck.clips.count > 0;
    card.timecodeLabel.stringValue = deck.timecode.length ? deck.timecode : @"--:--:--:--";
    card.remainingLabel.stringValue = deck.recordTimeRemaining.length ? deck.recordTimeRemaining : @"--:--:--:--";
    ATEMHyperDeckClipState *currentClip = nil;
    for (ATEMHyperDeckClipState *clip in deck.clips) {
        if (clip.clipID == deck.currentClip) {
            currentClip = clip;
            break;
        }
    }
    if (currentClip) {
        card.clipLabel.stringValue = [NSString stringWithFormat:@"%@  •  %lu indexed",
                                      currentClip.name,
                                      (unsigned long)deck.clips.count];
    } else if (deck.currentClip >= 0) {
        card.clipLabel.stringValue = [NSString stringWithFormat:@"Current ID %lld unavailable  •  %lu reported",
                                      deck.currentClip,
                                      (unsigned long)deck.clipCount];
    } else {
        card.clipLabel.stringValue = [NSString stringWithFormat:@"No clip selected  •  %lu reported",
                                      (unsigned long)deck.clipCount];
    }
    card.playerLabel.stringValue = HDPlayerText(deck.playerState);
    card.playerLabel.textColor = deck.playerState == ATEMHyperDeckPlayerStateRecord
        ? HDRed() : (deck.playerState == ATEMHyperDeckPlayerStatePlay ? HDGreen() : HDSecondary());

    card.playButton.enabled = remoteReady;
    card.stopButton.enabled = remoteReady;
    card.recordButton.enabled = remoteReady;
    card.jogBackButton.enabled = remoteReady;
    card.jogForwardButton.enabled = remoteReady;
    card.shuttleSlider.enabled = remoteReady;
    card.loopButton.enabled = remoteReady;
    card.singleButton.enabled = remoteReady;
    card.autoRollButton.enabled = switcherConnected;
    card.frameDelayField.enabled = switcherConnected;
    card.frameDelayStepper.enabled = switcherConnected;

    HDSetButtonTitle(card.playButton, @"▶  PLAY", HDGreen());
    HDSetButtonTitle(card.recordButton, @"●  RECORD", HDRed());
    card.loopButton.state = deck.isLoopedPlayback ? NSControlStateValueOn : NSControlStateValueOff;
    card.singleButton.state = deck.isSingleClipPlayback ? NSControlStateValueOn : NSControlStateValueOff;
    card.autoRollButton.state = deck.isAutoRollOnTake ? NSControlStateValueOn : NSControlStateValueOff;
    if (self.window.firstResponder != card.frameDelayField.currentEditor)
        card.frameDelayField.integerValue = (NSInteger)deck.autoRollFrameDelay;
    card.frameDelayStepper.integerValue = (NSInteger)deck.autoRollFrameDelay;
    if (!card.shuttleSlider.isHighlighted)
        card.shuttleSlider.integerValue = deck.shuttleSpeed;
    card.shuttleLabel.stringValue = [NSString stringWithFormat:@"%+ld%%", (long)deck.shuttleSpeed];
}

- (void)updateClipPopupForDeck:(ATEMHyperDeckState *)deck card:(HDDeckCardView *)card
{
    NSMutableArray<NSString *> *clipSignatures =
        [NSMutableArray arrayWithCapacity:deck.clips.count];
    for (ATEMHyperDeckClipState *clip in deck.clips) {
        [clipSignatures addObject:[NSString stringWithFormat:@"%lld:%@:%@",
                                  clip.clipID,
                                  clip.name ?: @"",
                                  clip.duration ?: @""]];
    }
    NSString *signature = [NSString stringWithFormat:@"%lu:%lld:%@",
                           (unsigned long)deck.clipCount,
                           deck.currentClip,
                           [clipSignatures componentsJoinedByString:@"|"]];
    if ([signature isEqualToString:card.clipMenuSignature])
        return;
    card.clipMenuSignature = signature;
    [card.clipPopup removeAllItems];
    if (deck.clipCount == 0) {
        [card.clipPopup addItemWithTitle:@"No clips"];
        return;
    }
    if (deck.clips.count == 0) {
        NSMenuItem *unavailable = [[NSMenuItem alloc] initWithTitle:@"Clip list unavailable"
                                                            action:nil
                                                     keyEquivalent:@""];
        unavailable.enabled = NO;
        [card.clipPopup.menu addItem:unavailable];
        return;
    }

    BOOL includedCurrent = NO;
    for (ATEMHyperDeckClipState *clip in deck.clips) {
        NSString *title = clip.duration.length
            ? [NSString stringWithFormat:@"%@  ·  %@", clip.name, clip.duration]
            : clip.name;
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title
                                                     action:nil
                                              keyEquivalent:@""];
        item.representedObject = @(clip.clipID);
        [card.clipPopup.menu addItem:item];
        if (clip.clipID == deck.currentClip) {
            [card.clipPopup selectItem:item];
            includedCurrent = YES;
        }
    }
    if (deck.clipCount > deck.clips.count) {
        NSMenuItem *more = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"… %lu not indexed",
                                                                                       (unsigned long)(deck.clipCount - deck.clips.count)]
                                                     action:nil
                                              keyEquivalent:@""];
        more.enabled = NO;
        [card.clipPopup.menu addItem:more];
    }
    if (!includedCurrent && deck.currentClip >= 0) {
        NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:[NSString stringWithFormat:@"Current ID %lld (not indexed)",
                                                                                       deck.currentClip]
                                                     action:nil
                                              keyEquivalent:@""];
        item.enabled = NO;
        [card.clipPopup.menu insertItem:item atIndex:0];
        [card.clipPopup selectItem:item];
    }
}

- (void)controlTextDidChange:(NSNotification *)notification
{
    NSTextField *field = notification.object;
    HDDeckCardView *card = [self cardForSender:field];
    if (!card || field != card.addressField)
        return;
    card.addressDirty = YES;
    NSString *trimmed = [field.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    BOOL valid = HDValidIPv4Address(trimmed);
    card.applyButton.enabled = self.activeController.latestState.isConnected && valid;
    [self setAddressMessageForCard:card
                              text:(trimmed.length == 0 ? @"Enter an IPv4 address or use Clear Address" :
                                    (valid ? @"Valid IPv4 address" : @"Use four numbers from 0–255"))
                             color:(valid ? HDGreen() : HDRed())];
}

- (void)applyAddress:(NSControl *)sender
{
    HDDeckCardView *card = [self cardForSender:sender];
    if (!card)
        return;
    NSString *address = [card.addressField.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (!HDValidIPv4Address(address)) {
        [self setAddressMessageForCard:card text:@"Enter a valid IPv4 address before applying" color:HDRed()];
        NSBeep();
        return;
    }
    card.addressField.stringValue = address;
    card.addressDirty = NO;
    card.pendingAddress = address;
    card.pendingAddressDeadline = CFAbsoluteTimeGetCurrent() + 4.0;
    [self setAddressMessageForCard:card text:@"Applying to ATEM…" color:HDAmber()];
    [self.activeController setHyperDeck:card.deckID networkAddress:address];
}

- (void)disableDeck:(NSButton *)sender
{
    HDDeckCardView *card = [self cardForSender:sender];
    if (!card)
        return;
    card.addressDirty = NO;
    card.addressField.stringValue = @"";
    card.pendingAddress = @"";
    card.pendingAddressDeadline = CFAbsoluteTimeGetCurrent() + 4.0;
    [self setAddressMessageForCard:card text:@"Clearing address in ATEM…" color:HDAmber()];
    [self.activeController setHyperDeck:card.deckID networkAddress:@""];
}

- (void)inputChanged:(NSPopUpButton *)sender
{
    HDDeckCardView *card = [self cardForSender:sender];
    NSNumber *input = sender.selectedItem.representedObject;
    if (!card || !input)
        return;
    card.hasPendingInput = YES;
    card.pendingInputID = input.longLongValue;
    card.pendingInputDeadline = CFAbsoluteTimeGetCurrent() + 3.0;
    [self.activeController setHyperDeck:card.deckID switcherInput:input.longLongValue];
}

- (void)clipChanged:(NSPopUpButton *)sender
{
    HDDeckCardView *card = [self cardForSender:sender];
    NSNumber *clip = sender.selectedItem.representedObject;
    if (card && clip)
        [self.activeController setHyperDeck:card.deckID currentClip:clip.longLongValue];
}

- (void)play:(NSButton *)sender
{
    HDDeckCardView *card = [self cardForSender:sender];
    if (card) [self.activeController playHyperDeck:card.deckID];
}

- (void)stop:(NSButton *)sender
{
    HDDeckCardView *card = [self cardForSender:sender];
    if (card) [self.activeController stopHyperDeck:card.deckID];
}

- (void)record:(NSButton *)sender
{
    HDDeckCardView *card = [self cardForSender:sender];
    if (card) [self.activeController recordHyperDeck:card.deckID];
}

- (void)jogBack:(NSButton *)sender
{
    HDDeckCardView *card = [self cardForSender:sender];
    if (card) [self.activeController jogHyperDeck:card.deckID frames:-1];
}

- (void)jogForward:(NSButton *)sender
{
    HDDeckCardView *card = [self cardForSender:sender];
    if (card) [self.activeController jogHyperDeck:card.deckID frames:1];
}

- (void)shuttleChanged:(NSSlider *)sender
{
    HDDeckCardView *card = [self cardForSender:sender];
    if (!card)
        return;
    NSInteger speed = MAX(-400, MIN(400, sender.integerValue));
    card.shuttleLabel.stringValue = [NSString stringWithFormat:@"%+ld%%", (long)speed];
    [self.activeController shuttleHyperDeck:card.deckID speed:speed];
}

- (void)loopChanged:(NSButton *)sender
{
    HDDeckCardView *card = [self cardForSender:sender];
    if (card) [self.activeController setHyperDeck:card.deckID loopedPlayback:sender.state == NSControlStateValueOn];
}

- (void)singleChanged:(NSButton *)sender
{
    HDDeckCardView *card = [self cardForSender:sender];
    if (card) [self.activeController setHyperDeck:card.deckID singleClipPlayback:sender.state == NSControlStateValueOn];
}

- (void)autoRollChanged:(NSButton *)sender
{
    HDDeckCardView *card = [self cardForSender:sender];
    if (card) [self.activeController setHyperDeck:card.deckID autoRollOnTake:sender.state == NSControlStateValueOn];
}

- (void)frameDelayChanged:(NSControl *)sender
{
    HDDeckCardView *card = [self cardForSender:sender];
    if (!card)
        return;
    NSInteger value = MAX(0, MIN(65535, sender.integerValue));
    card.frameDelayField.integerValue = value;
    card.frameDelayStepper.integerValue = value;
    [self.activeController setHyperDeck:card.deckID autoRollFrameDelay:(NSUInteger)value];
}

@end

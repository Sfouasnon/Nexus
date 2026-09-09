#import "LabelsWindowController.h"
#import "ATEMController.h"

static NSColor *LBColor(NSUInteger rgb)
{
    return [NSColor colorWithSRGBRed:((rgb >> 16) & 0xFF) / 255.0
                               green:((rgb >> 8) & 0xFF) / 255.0
                                blue:(rgb & 0xFF) / 255.0
                               alpha:1.0];
}

static NSColor *LBCanvas(void)    { return LBColor(0x090D12); }
static NSColor *LBHeader(void)    { return LBColor(0x0E141B); }
static NSColor *LBPanel(void)     { return LBColor(0x151C24); }
static NSColor *LBDivider(void)   { return LBColor(0x2C3A48); }
static NSColor *LBText(void)      { return LBColor(0xF2F5F8); }
static NSColor *LBSecondary(void) { return LBColor(0xA5B0BC); }
static NSColor *LBMuted(void)     { return LBColor(0x6E7B88); }
static NSColor *LBCyan(void)      { return LBColor(0x32C7F3); }
static NSColor *LBGreen(void)     { return LBColor(0x31CE7A); }
static NSColor *LBViolet(void)    { return LBColor(0xB27AF5); }

static NSTextField *LBLabel(NSString *text, CGFloat size, NSFontWeight weight, NSColor *color)
{
    NSTextField *label = [NSTextField labelWithString:text ?: @""];
    label.font = [NSFont systemFontOfSize:size weight:weight];
    label.textColor = color ?: LBText();
    label.lineBreakMode = NSLineBreakByTruncatingTail;
    return label;
}

static NSTextField *LBEyebrow(NSString *text)
{
    return LBLabel(text.uppercaseString, 9, NSFontWeightSemibold, LBMuted());
}

static NSTextField *LBEditField(NSString *placeholder)
{
    NSTextField *field = [[NSTextField alloc] initWithFrame:NSZeroRect];
    field.placeholderString = placeholder;
    field.font = [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightMedium];
    field.textColor = LBText();
    field.backgroundColor = LBHeader();
    field.drawsBackground = YES;
    field.bezeled = NO;
    field.focusRingType = NSFocusRingTypeExterior;
    field.wantsLayer = YES;
    field.layer.cornerRadius = 7;
    field.layer.borderWidth = 1;
    field.layer.borderColor = LBDivider().CGColor;
    return field;
}

static NSButton *LBButton(NSString *title, id target, SEL action)
{
    NSButton *button = [NSButton buttonWithTitle:title target:target action:action];
    button.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
    button.bezelStyle = NSBezelStyleTexturedRounded;
    button.contentTintColor = LBCyan();
    return button;
}

@interface LBLabelRow : NSView
@property(nonatomic) int64_t inputID;
@property(nonatomic, strong) NSTextField *nameLabel;
@property(nonatomic, strong) NSTextField *typeLabel;
@property(nonatomic, strong) NSTextField *longField;
@property(nonatomic, strong) NSTextField *shortField;
@property(nonatomic, strong) NSButton *applyButton;
@property(nonatomic) BOOL dirty;
@property(nonatomic) BOOL pending;
@property(nonatomic, copy) NSString *pendingLongName;
@property(nonatomic, copy) NSString *pendingShortName;
@property(nonatomic) CFAbsoluteTime pendingDeadline;
@end

@implementation LBLabelRow

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (!self)
        return nil;
    self.wantsLayer = YES;
    self.layer.backgroundColor = LBPanel().CGColor;
    self.layer.cornerRadius = 10;
    self.layer.borderWidth = 1;
    self.layer.borderColor = LBDivider().CGColor;
    return self;
}

@end

@interface LabelsWindowController () <NSTextFieldDelegate>
@property(nonatomic, copy) NSArray<ATEMController *> *controllers;
@property(nonatomic) NSUInteger activeSessionIndex;
@property(nonatomic, strong) NSSegmentedControl *sessionSelector;
@property(nonatomic, strong) NSTextField *switcherLabel;
@property(nonatomic, strong) NSTextField *statusLabel;
@property(nonatomic, strong) NSView *statusDot;
@property(nonatomic, strong) NSStackView *labelStack;
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, LBLabelRow *> *rowsByID;
@property(nonatomic, copy) NSString *structureSignature;
@end

@implementation LabelsWindowController

- (instancetype)initWithControllers:(NSArray<ATEMController *> *)controllers
                initialSessionIndex:(NSUInteger)sessionIndex
{
    NSParameterAssert(controllers.count == 2);
    NSRect frame = NSMakeRect(0, 0, 960, 720);
    NSWindow *window = [[NSWindow alloc] initWithContentRect:frame
                                                  styleMask:(NSWindowStyleMaskTitled |
                                                             NSWindowStyleMaskClosable |
                                                             NSWindowStyleMaskMiniaturizable |
                                                             NSWindowStyleMaskResizable)
                                                    backing:NSBackingStoreBuffered
                                                      defer:NO];
    window.title = @"ATEM CNTRL — Labels";
    window.minSize = NSMakeSize(760, 520);
    window.backgroundColor = LBCanvas();
    window.appearance = [NSAppearance appearanceNamed:NSAppearanceNameDarkAqua];
    window.titlebarAppearsTransparent = YES;
    window.titleVisibility = NSWindowTitleHidden;
    window.tabbingMode = NSWindowTabbingModeDisallowed;
    window.sharingType = NSWindowSharingReadOnly;
    [window setFrameAutosaveName:@"ATEMCNTRLLabelsWindow"];
    [window center];

    self = [super initWithWindow:window];
    if (!self)
        return nil;
    _controllers = [controllers copy];
    _activeSessionIndex = MIN(sessionIndex, controllers.count - 1);
    _rowsByID = [NSMutableDictionary dictionary];
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

- (void)buildInterface
{
    NSView *root = [[NSView alloc] initWithFrame:NSZeroRect];
    root.wantsLayer = YES;
    root.layer.backgroundColor = LBCanvas().CGColor;
    self.window.contentView = root;

    NSView *header = [[NSView alloc] initWithFrame:NSZeroRect];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    header.wantsLayer = YES;
    header.layer.backgroundColor = LBHeader().CGColor;
    header.layer.borderColor = LBDivider().CGColor;
    header.layer.borderWidth = 1;
    [root addSubview:header];

    NSTextField *title = LBLabel(@"INPUT & OUTPUT LABELS", 20, NSFontWeightSemibold, LBText());
    title.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:title];
    NSTextField *subtitle = LBLabel(@"Edit the long and short names stored on the active ATEM", 10, NSFontWeightMedium, LBSecondary());
    subtitle.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:subtitle];

    NSTextField *targetLabel = LBEyebrow(@"Control target");
    targetLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:targetLabel];
    self.sessionSelector = [NSSegmentedControl segmentedControlWithLabels:@[@"A  ○", @"B  ○"]
                                                              trackingMode:NSSegmentSwitchTrackingSelectOne
                                                                    target:self
                                                                    action:@selector(sessionChanged:)];
    self.sessionSelector.translatesAutoresizingMaskIntoConstraints = NO;
    self.sessionSelector.segmentStyle = NSSegmentStyleCapsule;
    self.sessionSelector.selectedSegmentBezelColor = LBCyan();
    self.sessionSelector.font = [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold];
    self.sessionSelector.selectedSegment = self.activeSessionIndex;
    [header addSubview:self.sessionSelector];

    self.statusDot = [[NSView alloc] initWithFrame:NSZeroRect];
    self.statusDot.translatesAutoresizingMaskIntoConstraints = NO;
    self.statusDot.wantsLayer = YES;
    self.statusDot.layer.cornerRadius = 4;
    [header addSubview:self.statusDot];
    self.switcherLabel = LBLabel(@"Not connected", 12, NSFontWeightSemibold, LBText());
    self.switcherLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:self.switcherLabel];
    self.statusLabel = LBLabel(@"Connect an ATEM or use Demo to edit labels.", 10, NSFontWeightRegular, LBSecondary());
    self.statusLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:self.statusLabel];

    NSScrollView *scroll = [[NSScrollView alloc] initWithFrame:NSZeroRect];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.drawsBackground = NO;
    scroll.hasVerticalScroller = YES;
    scroll.autohidesScrollers = YES;
    scroll.borderType = NSNoBorder;
    [root addSubview:scroll];

    NSView *document = [[NSView alloc] initWithFrame:NSZeroRect];
    document.translatesAutoresizingMaskIntoConstraints = NO;
    scroll.documentView = document;
    self.labelStack = [NSStackView stackViewWithViews:@[]];
    self.labelStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.labelStack.orientation = NSUserInterfaceLayoutOrientationVertical;
    self.labelStack.alignment = NSLayoutAttributeLeading;
    self.labelStack.distribution = NSStackViewDistributionFill;
    self.labelStack.spacing = 8;
    [document addSubview:self.labelStack];

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
        [scroll.leadingAnchor constraintEqualToAnchor:root.leadingAnchor],
        [scroll.trailingAnchor constraintEqualToAnchor:root.trailingAnchor],
        [scroll.topAnchor constraintEqualToAnchor:header.bottomAnchor],
        [scroll.bottomAnchor constraintEqualToAnchor:root.bottomAnchor],
        [document.leadingAnchor constraintEqualToAnchor:scroll.contentView.leadingAnchor],
        [document.trailingAnchor constraintEqualToAnchor:scroll.contentView.trailingAnchor],
        [document.topAnchor constraintEqualToAnchor:scroll.contentView.topAnchor],
        [document.widthAnchor constraintEqualToAnchor:scroll.contentView.widthAnchor],
        [self.labelStack.leadingAnchor constraintEqualToAnchor:document.leadingAnchor constant:18],
        [self.labelStack.trailingAnchor constraintEqualToAnchor:document.trailingAnchor constant:-18],
        [self.labelStack.topAnchor constraintEqualToAnchor:document.topAnchor constant:18],
        [self.labelStack.bottomAnchor constraintEqualToAnchor:document.bottomAnchor constant:-18],
    ]];
}

- (void)removeAllRows
{
    for (NSView *view in self.labelStack.arrangedSubviews) {
        [self.labelStack removeArrangedSubview:view];
        [view removeFromSuperview];
    }
    [self.rowsByID removeAllObjects];
}

- (LBLabelRow *)rowForTarget:(ATEMLabelTargetState *)target
{
    LBLabelRow *row = [[LBLabelRow alloc] initWithFrame:NSZeroRect];
    row.translatesAutoresizingMaskIntoConstraints = NO;
    row.inputID = target.inputID;

    row.nameLabel = LBLabel(target.longName, 12, NSFontWeightSemibold, LBText());
    row.nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    row.typeLabel = LBLabel([NSString stringWithFormat:@"%@  •  ID %lld", target.typeName, target.inputID],
                            9.5, NSFontWeightMedium, LBMuted());
    row.typeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:row.nameLabel];
    [row addSubview:row.typeLabel];

    row.longField = LBEditField(@"Long label");
    row.longField.translatesAutoresizingMaskIntoConstraints = NO;
    row.longField.stringValue = target.longName;
    row.longField.delegate = self;
    row.longField.tag = (NSInteger)target.inputID;
    row.longField.target = self;
    row.longField.action = @selector(applyFromField:);
    row.longField.accessibilityLabel = [NSString stringWithFormat:@"Long label for %@", target.longName];
    [row addSubview:row.longField];

    row.shortField = LBEditField(@"Short label");
    row.shortField.translatesAutoresizingMaskIntoConstraints = NO;
    row.shortField.stringValue = target.shortName;
    row.shortField.delegate = self;
    row.shortField.tag = (NSInteger)target.inputID;
    row.shortField.target = self;
    row.shortField.action = @selector(applyFromField:);
    row.shortField.accessibilityLabel = [NSString stringWithFormat:@"Short label for %@", target.longName];
    [row addSubview:row.shortField];

    row.applyButton = LBButton(@"APPLY", self, @selector(applyPressed:));
    row.applyButton.translatesAutoresizingMaskIntoConstraints = NO;
    row.applyButton.tag = (NSInteger)target.inputID;
    row.applyButton.enabled = NO;
    row.applyButton.toolTip = @"Write both labels to the active ATEM.";
    [row addSubview:row.applyButton];

    [NSLayoutConstraint activateConstraints:@[
        [row.heightAnchor constraintEqualToConstant:70],
        [row.nameLabel.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:14],
        [row.nameLabel.topAnchor constraintEqualToAnchor:row.topAnchor constant:13],
        [row.nameLabel.widthAnchor constraintEqualToConstant:190],
        [row.typeLabel.leadingAnchor constraintEqualToAnchor:row.nameLabel.leadingAnchor],
        [row.typeLabel.topAnchor constraintEqualToAnchor:row.nameLabel.bottomAnchor constant:3],
        [row.typeLabel.widthAnchor constraintEqualToAnchor:row.nameLabel.widthAnchor],
        [row.longField.leadingAnchor constraintEqualToAnchor:row.nameLabel.trailingAnchor constant:12],
        [row.longField.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [row.longField.heightAnchor constraintEqualToConstant:34],
        [row.shortField.leadingAnchor constraintEqualToAnchor:row.longField.trailingAnchor constant:10],
        [row.shortField.centerYAnchor constraintEqualToAnchor:row.longField.centerYAnchor],
        [row.shortField.widthAnchor constraintEqualToConstant:132],
        [row.shortField.heightAnchor constraintEqualToAnchor:row.longField.heightAnchor],
        [row.applyButton.leadingAnchor constraintEqualToAnchor:row.shortField.trailingAnchor constant:10],
        [row.applyButton.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-14],
        [row.applyButton.centerYAnchor constraintEqualToAnchor:row.longField.centerYAnchor],
        [row.applyButton.widthAnchor constraintEqualToConstant:82],
        [row.applyButton.heightAnchor constraintEqualToConstant:32],
        [row.longField.widthAnchor constraintGreaterThanOrEqualToConstant:190],
    ]];
    return row;
}

- (NSView *)sectionHeaderWithTitle:(NSString *)title count:(NSUInteger)count
{
    NSView *header = [[NSView alloc] initWithFrame:NSZeroRect];
    header.translatesAutoresizingMaskIntoConstraints = NO;
    NSTextField *section = LBEyebrow([NSString stringWithFormat:@"%@  •  %lu", title, (unsigned long)count]);
    section.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:section];
    NSTextField *longLabel = LBEyebrow(@"Long label");
    longLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:longLabel];
    NSTextField *shortLabel = LBEyebrow(@"Short label");
    shortLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:shortLabel];
    [NSLayoutConstraint activateConstraints:@[
        [header.heightAnchor constraintEqualToConstant:20],
        [section.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:14],
        [section.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [longLabel.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:216],
        [longLabel.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
        [shortLabel.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-126],
        [shortLabel.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],
    ]];
    return header;
}

- (void)rebuildRows:(NSArray<ATEMLabelTargetState *> *)targets
{
    [self removeAllRows];
    NSArray<NSNumber *> *categories = @[@NO, @YES];
    NSArray<NSString *> *titles = @[@"INPUTS", @"OUTPUTS"];
    for (NSUInteger category = 0; category < categories.count; ++category) {
        BOOL output = categories[category].boolValue;
        NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(ATEMLabelTargetState *target, NSDictionary *bindings) {
            (void)bindings;
            return target.isOutput == output;
        }];
        NSArray<ATEMLabelTargetState *> *sectionTargets = [targets filteredArrayUsingPredicate:predicate];
        if (sectionTargets.count == 0)
            continue;
        NSView *section = [self sectionHeaderWithTitle:titles[category] count:sectionTargets.count];
        [self.labelStack addArrangedSubview:section];
        [section.widthAnchor constraintEqualToAnchor:self.labelStack.widthAnchor].active = YES;
        for (ATEMLabelTargetState *target in sectionTargets) {
            LBLabelRow *row = [self rowForTarget:target];
            self.rowsByID[@(target.inputID)] = row;
            [self.labelStack addArrangedSubview:row];
            [row.widthAnchor constraintEqualToAnchor:self.labelStack.widthAnchor].active = YES;
        }
    }
    if (targets.count == 0) {
        NSTextField *empty = LBLabel(@"No label endpoints are available. Connect an ATEM or use Demo mode.",
                                           12, NSFontWeightRegular, LBSecondary());
        [self.labelStack addArrangedSubview:empty];
        [empty.widthAnchor constraintEqualToAnchor:self.labelStack.widthAnchor].active = YES;
    }
}

- (NSString *)structureSignatureForTargets:(NSArray<ATEMLabelTargetState *> *)targets
{
    NSMutableString *signature = [NSMutableString string];
    for (ATEMLabelTargetState *target in targets)
        [signature appendFormat:@"%lld:%d:%@|", target.inputID, target.isOutput, target.typeName];
    return signature;
}

- (BOOL)isEditingField:(NSTextField *)field
{
    NSResponder *responder = field.window.firstResponder;
    return [responder isKindOfClass:[NSTextView class]] &&
           (id)((NSTextView *)responder).delegate == (id)field;
}

- (void)applyState:(ATEMState *)state
{
    NSString *sessionName = self.activeSessionIndex == 0 ? @"A" : @"B";
    NSString *product = state.productName.length ? state.productName : (state.isConnecting ? @"Connecting…" : @"Not connected");
    self.switcherLabel.stringValue = [NSString stringWithFormat:@"ATEM %@ — %@", sessionName, product];
    self.statusLabel.stringValue = state.statusMessage.length ? state.statusMessage : @"Long and short labels are stored on the switcher.";
    self.statusDot.layer.backgroundColor = (state.isDemo ? LBViolet() : (state.isConnected ? LBGreen() : LBMuted())).CGColor;


    NSString *signature = [self structureSignatureForTargets:state.labelTargets];
    if (![signature isEqualToString:self.structureSignature]) {
        self.structureSignature = signature;
        [self rebuildRows:state.labelTargets];
    }

    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    for (ATEMLabelTargetState *target in state.labelTargets) {
        LBLabelRow *row = self.rowsByID[@(target.inputID)];
        if (!row)
            continue;
        row.longField.enabled = state.isConnected;
        row.shortField.enabled = state.isConnected;
        row.applyButton.enabled = state.isConnected && row.dirty;
        if (row.dirty || [self isEditingField:row.longField] || [self isEditingField:row.shortField])
            continue;
        if (row.pending) {
            BOOL acknowledged = [target.longName isEqualToString:row.pendingLongName] &&
                                [target.shortName isEqualToString:row.pendingShortName];
            if (!acknowledged && now <= row.pendingDeadline)
                continue;
            row.pending = NO;
        }
        row.nameLabel.stringValue = target.longName;
        row.longField.stringValue = target.longName;
        row.shortField.stringValue = target.shortName;
    }
    [self refreshSessionSelector];
}

- (void)refreshActiveSession
{
    self.structureSignature = nil;
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

- (void)scrollOutputsIntoView
{
    for (ATEMLabelTargetState *target in self.activeController.latestState.labelTargets) {
        if (!target.isOutput)
            continue;
        LBLabelRow *row = self.rowsByID[@(target.inputID)];
        [row scrollRectToVisible:row.bounds];
        break;
    }
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

- (void)controlTextDidChange:(NSNotification *)notification
{
    NSTextField *field = notification.object;
    LBLabelRow *row = self.rowsByID[@(field.tag)];
    if (!row)
        return;
    row.dirty = YES;
    row.pending = NO;
    row.applyButton.enabled = self.activeController.latestState.isConnected;
}

- (void)applyRow:(LBLabelRow *)row
{
    [self.window makeFirstResponder:nil];
    NSString *longName = [row.longField.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *shortName = [row.shortField.stringValue stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (longName.length == 0 || shortName.length == 0) {
        NSBeep();
        self.statusLabel.stringValue = @"Long and short labels cannot be empty.";
        return;
    }
    row.longField.stringValue = longName;
    row.shortField.stringValue = shortName;
    row.dirty = NO;
    row.pending = YES;
    row.pendingLongName = longName;
    row.pendingShortName = shortName;
    row.pendingDeadline = CFAbsoluteTimeGetCurrent() + 2.0;
    row.applyButton.enabled = NO;
    [self.activeController setLabelForInput:row.inputID longName:longName shortName:shortName];
}

- (void)applyPressed:(NSButton *)sender
{
    LBLabelRow *row = self.rowsByID[@(sender.tag)];
    if (row)
        [self applyRow:row];
}

- (void)applyFromField:(NSTextField *)sender
{
    LBLabelRow *row = self.rowsByID[@(sender.tag)];
    if (row)
        [self applyRow:row];
}

@end

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ATEMTransitionStyle) {
    ATEMTransitionStyleMix = 0,
    ATEMTransitionStyleDip = 1,
    ATEMTransitionStyleWipe = 2,
    ATEMTransitionStyleDVE = 3,
    ATEMTransitionStyleStinger = 4,
};

typedef NS_OPTIONS(NSUInteger, ATEMTransitionSelection) {
    ATEMTransitionSelectionBackground = 1 << 0,
    ATEMTransitionSelectionKey1 = 1 << 1,
    ATEMTransitionSelectionKey2 = 1 << 2,
    ATEMTransitionSelectionKey3 = 1 << 3,
    ATEMTransitionSelectionKey4 = 1 << 4,
};

typedef NS_OPTIONS(uint32_t, ATEMMultiviewLayout) {
    ATEMMultiviewLayoutProgramTop = 0x0C,
    ATEMMultiviewLayoutProgramBottom = 0x03,
    ATEMMultiviewLayoutProgramLeft = 0x0A,
    ATEMMultiviewLayoutProgramRight = 0x05,
    ATEMMultiviewLayoutTopLeftSmall = 0x01,
    ATEMMultiviewLayoutTopRightSmall = 0x02,
    ATEMMultiviewLayoutBottomLeftSmall = 0x04,
    ATEMMultiviewLayoutBottomRightSmall = 0x08,
};

FOUNDATION_EXPORT NSNotificationName const ATEMAudioStateDidChangeNotification;
FOUNDATION_EXPORT NSNotificationName const ATEMHyperDeckStateDidChangeNotification;
FOUNDATION_EXPORT NSNotificationName const ATEMStateDidChangeNotification;

typedef NS_ENUM(NSUInteger, ATEMAudioMixOption) {
    ATEMAudioMixOptionOff = 0x00000001,
    ATEMAudioMixOptionOn = 0x00000002,
    ATEMAudioMixOptionAudioFollowVideo = 0x00000004,
};

typedef NS_ENUM(NSUInteger, ATEMHyperDeckConnectionStatus) {
    ATEMHyperDeckConnectionStatusNotConnected = 0,
    ATEMHyperDeckConnectionStatusConnecting,
    ATEMHyperDeckConnectionStatusConnected,
    ATEMHyperDeckConnectionStatusIncompatible,
};

typedef NS_ENUM(NSUInteger, ATEMHyperDeckPlayerState) {
    ATEMHyperDeckPlayerStateUnknown = 0,
    ATEMHyperDeckPlayerStateIdle,
    ATEMHyperDeckPlayerStatePlay,
    ATEMHyperDeckPlayerStateRecord,
    ATEMHyperDeckPlayerStateShuttle,
};

@interface ATEMInputState : NSObject
@property(nonatomic, readonly) int64_t inputID;
@property(nonatomic, copy, readonly) NSString *longName;
@property(nonatomic, copy, readonly) NSString *shortName;
@property(nonatomic, readonly) uint32_t availabilityMask;
- (instancetype)initWithID:(int64_t)inputID
                  longName:(NSString *)longName
                 shortName:(NSString *)shortName
          availabilityMask:(uint32_t)availabilityMask NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface ATEMLabelTargetState : NSObject
/// SDK input identifier. Output endpoints are also represented by IBMDSwitcherInput.
@property(nonatomic, readonly) int64_t inputID;
@property(nonatomic, copy, readonly) NSString *longName;
@property(nonatomic, copy, readonly) NSString *shortName;
/// Human-readable SDK port type, e.g. @"Camera/Input", @"Aux Output", or @"Multiview Output".
@property(nonatomic, copy, readonly) NSString *typeName;
@property(nonatomic, readonly, getter=isOutput) BOOL output;
@end

/// One switcher colour generator (Color 1, Color 2, …) in the SDK's HSL model.
@interface ATEMColorGeneratorState : NSObject
/// Zero-based position: Color 1 is index 0.
@property(nonatomic, readonly) NSUInteger index;
/// SDK input identifier, so the generator can be routed to Program, Preview, or an AUX.
@property(nonatomic, readonly) int64_t inputID;
/// Switcher-stored label, e.g. @"Color 1".
@property(nonatomic, copy, readonly) NSString *name;
/// Hue in degrees, 0...360.
@property(nonatomic, readonly) double hue;
/// Saturation, 0...1.
@property(nonatomic, readonly) double saturation;
/// Luma (HSL lightness) as a signal level, 0...1.
@property(nonatomic, readonly) double luma;
@end

@interface ATEMKeyState : NSObject
@property(nonatomic, readonly) NSUInteger index;
@property(nonatomic, readonly, getter=isOnAir) BOOL onAir;
- (instancetype)initWithIndex:(NSUInteger)index onAir:(BOOL)onAir NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface ATEMDownstreamKeyState : NSObject
@property(nonatomic, readonly) NSUInteger index;
@property(nonatomic, readonly, getter=isOnAir) BOOL onAir;
@property(nonatomic, readonly, getter=isTied) BOOL tied;
@property(nonatomic, readonly, getter=isTransitioning) BOOL transitioning;
@property(nonatomic, readonly) uint32_t framesRemaining;
- (instancetype)initWithIndex:(NSUInteger)index
                        onAir:(BOOL)onAir
                         tied:(BOOL)tied
                transitioning:(BOOL)transitioning
              framesRemaining:(uint32_t)framesRemaining NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface ATEMAuxState : NSObject
@property(nonatomic, readonly) NSUInteger index;
@property(nonatomic, copy, readonly) NSString *name;
@property(nonatomic, readonly) int64_t sourceID;
@property(nonatomic, readonly) uint32_t inputAvailabilityMask;
- (instancetype)initWithIndex:(NSUInteger)index
                         name:(NSString *)name
                     sourceID:(int64_t)sourceID
        inputAvailabilityMask:(uint32_t)inputAvailabilityMask NS_DESIGNATED_INITIALIZER;
- (instancetype)init NS_UNAVAILABLE;
@end

@interface ATEMMultiviewWindowState : NSObject
@property(nonatomic, readonly) NSUInteger index;
@property(nonatomic, readonly) int64_t sourceID;
@property(nonatomic, readonly) BOOL canRouteInput;
@property(nonatomic, readonly) BOOL supportsVUMeter;
@property(nonatomic, readonly, getter=isVUMeterEnabled) BOOL vuMeterEnabled;
@property(nonatomic, readonly) BOOL supportsSafeArea;
@property(nonatomic, readonly, getter=isSafeAreaEnabled) BOOL safeAreaEnabled;
@property(nonatomic, readonly) uint32_t safeAreaType;
@property(nonatomic, readonly) BOOL supportsLabelOverlay;
@property(nonatomic, readonly, getter=isLabelVisible) BOOL labelVisible;
@property(nonatomic, readonly, getter=isBorderVisible) BOOL borderVisible;
@end

@interface ATEMMultiviewState : NSObject
@property(nonatomic, readonly) NSUInteger index;
@property(nonatomic, readonly) ATEMMultiviewLayout layout;
@property(nonatomic, readonly) BOOL canChangeLayout;
@property(nonatomic, readonly) BOOL supportsQuadrantLayout;
@property(nonatomic, readonly) BOOL canRouteInputs;
@property(nonatomic, readonly) uint32_t inputAvailabilityMask;
@property(nonatomic, readonly) BOOL supportsVUMeters;
@property(nonatomic, readonly) BOOL canAdjustVUMeterOpacity;
@property(nonatomic, readonly) double vuMeterOpacity;
@property(nonatomic, readonly) BOOL canToggleSafeArea;
@property(nonatomic, readonly) uint32_t supportedSafeAreaTypes;
@property(nonatomic, readonly) BOOL supportsProgramPreviewSwap;
@property(nonatomic, readonly, getter=isProgramPreviewSwapped) BOOL programPreviewSwapped;
@property(nonatomic, readonly) BOOL canChangeOverlayProperties;
@property(nonatomic, readonly) NSUInteger totalWindowCount;
@property(nonatomic, copy, readonly) NSArray<ATEMMultiviewWindowState *> *windows;
@end

@interface ATEMAudioChannelState : NSObject
@property(nonatomic, readonly) int64_t inputID;
@property(nonatomic, readonly) int64_t sourceID;
@property(nonatomic, copy, readonly) NSString *name;
@property(nonatomic, readonly, getter=isActive) BOOL active;
@property(nonatomic, readonly) double faderGain;
@property(nonatomic, readonly) double pan;
@property(nonatomic, readonly) ATEMAudioMixOption mixOption;
@property(nonatomic, readonly) NSUInteger supportedMixOptions;
@property(nonatomic, copy, readonly) NSArray<NSNumber *> *levels;
@property(nonatomic, copy, readonly) NSArray<NSNumber *> *peakLevels;
@end

@interface ATEMAudioState : NSObject
@property(nonatomic, readonly, getter=isAvailable) BOOL available;
@property(nonatomic, readonly, getter=isDemo) BOOL demo;
@property(nonatomic, copy, readonly) NSString *statusMessage;
@property(nonatomic, readonly) double masterFaderGain;
@property(nonatomic, copy, readonly) NSArray<NSNumber *> *masterLevels;
@property(nonatomic, copy, readonly) NSArray<NSNumber *> *masterPeakLevels;
@property(nonatomic, copy, readonly) NSArray<ATEMAudioChannelState *> *channels;
@end

@interface ATEMHyperDeckClipState : NSObject
@property(nonatomic, readonly) int64_t clipID;
@property(nonatomic, copy, readonly) NSString *name;
@property(nonatomic, copy, readonly) NSString *duration;
@end

@interface ATEMHyperDeckState : NSObject
@property(nonatomic, readonly) int64_t deckID;
@property(nonatomic, copy, readonly) NSString *name;
@property(nonatomic, copy, readonly) NSString *modelName;
@property(nonatomic, copy, readonly) NSString *networkAddress;
@property(nonatomic, readonly) int64_t switcherInputID;
@property(nonatomic, readonly) ATEMHyperDeckConnectionStatus connectionStatus;
@property(nonatomic, readonly, getter=isRemoteAccessEnabled) BOOL remoteAccessEnabled;
@property(nonatomic, readonly) ATEMHyperDeckPlayerState playerState;
@property(nonatomic, readonly) int64_t currentClip;
@property(nonatomic, readonly) NSUInteger clipCount;
@property(nonatomic, copy, readonly) NSArray<ATEMHyperDeckClipState *> *clips;
@property(nonatomic, copy, readonly) NSString *timecode;
@property(nonatomic, copy, readonly) NSString *recordTimeRemaining;
@property(nonatomic, readonly, getter=isLoopedPlayback) BOOL loopedPlayback;
@property(nonatomic, readonly, getter=isSingleClipPlayback) BOOL singleClipPlayback;
@property(nonatomic, readonly, getter=isAutoRollOnTake) BOOL autoRollOnTake;
@property(nonatomic, readonly) NSUInteger autoRollFrameDelay;
@property(nonatomic, readonly) NSInteger shuttleSpeed;
@end

@interface ATEMVideoModeOption : NSObject
/// Raw BMDSwitcherVideoMode value. Held as uint32_t so this header stays free of SDK types.
@property(nonatomic, readonly) uint32_t rawMode;
/// Resolution portion, e.g. @"1080p", @"2160p", @"NTSC 16:9".
@property(nonatomic, copy, readonly) NSString *formatName;
/// Frame rate portion, e.g. @"59.94". Empty when the mode has no separable rate.
@property(nonatomic, copy, readonly) NSString *frameRateName;
/// Combined label, e.g. @"1080p59.94".
@property(nonatomic, copy, readonly) NSString *displayName;
@end

@interface ATEMState : NSObject
@property(nonatomic, readonly, getter=isConnected) BOOL connected;
@property(nonatomic, readonly, getter=isConnecting) BOOL connecting;
@property(nonatomic, readonly, getter=isDemo) BOOL demo;
@property(nonatomic, copy, readonly) NSString *productName;
@property(nonatomic, copy, readonly) NSString *statusMessage;
@property(nonatomic, copy, readonly) NSArray<ATEMInputState *> *inputs;
@property(nonatomic, readonly) uint32_t mixEffectInputAvailabilityMask;
@property(nonatomic, readonly) int64_t programInputID;
@property(nonatomic, readonly) int64_t previewInputID;
@property(nonatomic, readonly) double transitionPosition;
@property(nonatomic, readonly) uint32_t transitionFramesRemaining;
@property(nonatomic, readonly, getter=isInTransition) BOOL inTransition;
@property(nonatomic, readonly) ATEMTransitionStyle nextTransitionStyle;
@property(nonatomic, readonly) ATEMTransitionSelection nextTransitionSelection;
@property(nonatomic, readonly) uint32_t transitionRate;
@property(nonatomic, readonly, getter=isFadeToBlack) BOOL fadeToBlack;
@property(nonatomic, readonly, getter=isFadeToBlackTransitioning) BOOL fadeToBlackTransitioning;
@property(nonatomic, readonly) uint32_t fadeToBlackFramesRemaining;
@property(nonatomic, copy, readonly) NSArray<ATEMKeyState *> *upstreamKeys;
@property(nonatomic, copy, readonly) NSArray<ATEMDownstreamKeyState *> *downstreamKeys;
@property(nonatomic, copy, readonly) NSArray<ATEMAuxState *> *auxOutputs;
@property(nonatomic, copy, readonly) NSArray<ATEMMultiviewState *> *multiviews;
/// Every SDK endpoint whose long and short labels can be edited.
@property(nonatomic, copy, readonly) NSArray<ATEMLabelTargetState *> *labelTargets;
/// Colour generators reported by the switcher, in SDK input order.
@property(nonatomic, copy, readonly) NSArray<ATEMColorGeneratorState *> *colorGenerators;
/// Raw BMDSwitcherVideoMode currently running on the switcher.
@property(nonatomic, readonly) uint32_t videoMode;
/// YES when the switcher reports more than one supported video mode.
@property(nonatomic, readonly) BOOL canChangeVideoMode;
/// Every mode the connected switcher accepts, in resolution then frame-rate order.
@property(nonatomic, copy, readonly) NSArray<ATEMVideoModeOption *> *supportedVideoModes;
@end

@interface ATEMController : NSObject

@property(nonatomic, copy, nullable) void (^stateHandler)(ATEMState *state);
@property(nonatomic, readonly) ATEMState *latestState;
@property(nonatomic, readonly) ATEMAudioState *latestAudioState;
@property(nonatomic, copy, readonly) NSArray<ATEMHyperDeckState *> *latestHyperDeckStates;
@property(nonatomic, copy, readonly) NSString *currentAddress;

- (void)connectToAddress:(NSString *)address;
- (void)disconnect;
- (void)enterDemoMode;

- (void)setProgramInput:(int64_t)inputID;
- (void)setPreviewInput:(int64_t)inputID;
- (void)performCut;
- (void)performAutoTransition;
- (void)performFadeToBlack;
- (void)setTransitionPosition:(double)position;
- (void)setNextTransitionStyle:(ATEMTransitionStyle)style;
- (void)setNextTransitionSelection:(ATEMTransitionSelection)selection;
- (void)setTransitionRate:(uint32_t)frames;
- (void)setUpstreamKey:(NSUInteger)index onAir:(BOOL)onAir;
- (void)setDownstreamKey:(NSUInteger)index onAir:(BOOL)onAir;
- (void)setDownstreamKey:(NSUInteger)index tied:(BOOL)tied;
- (void)performDownstreamKeyAuto:(NSUInteger)index;
- (void)setAuxOutput:(NSUInteger)index source:(int64_t)sourceID;
/// Sets the switcher-stored long and short labels for an input or output endpoint.
- (void)setLabelForInput:(int64_t)inputID longName:(NSString *)longName shortName:(NSString *)shortName;
/// Sets one colour generator. Hue is in degrees and wraps; saturation and luma clamp to 0...1.
- (void)setColorGenerator:(NSUInteger)index
                      hue:(double)hue
               saturation:(double)saturation
                     luma:(double)luma;
/// Changes the switcher-wide video standard. Disruptive: every output re-syncs.
- (void)setVideoMode:(uint32_t)videoMode;
- (void)setMultiview:(NSUInteger)index layout:(ATEMMultiviewLayout)layout;
- (void)setMultiview:(NSUInteger)index programPreviewSwapped:(BOOL)swapped;
- (void)setMultiview:(NSUInteger)index vuMeterOpacity:(double)opacity;
- (void)setMultiview:(NSUInteger)index window:(NSUInteger)window source:(int64_t)sourceID;
- (void)setMultiview:(NSUInteger)index window:(NSUInteger)window vuMeterEnabled:(BOOL)enabled;
- (void)setMultiview:(NSUInteger)index window:(NSUInteger)window safeAreaEnabled:(BOOL)enabled;
- (void)setMultiview:(NSUInteger)index window:(NSUInteger)window labelVisible:(BOOL)visible;
- (void)setMultiview:(NSUInteger)index window:(NSUInteger)window borderVisible:(BOOL)visible;
- (void)setMultiview:(NSUInteger)index allLabelsVisible:(BOOL)visible;
- (void)setMultiview:(NSUInteger)index allBordersVisible:(BOOL)visible;

- (void)setAudioInput:(int64_t)inputID source:(int64_t)sourceID faderGain:(double)gain;
- (void)setAudioInput:(int64_t)inputID source:(int64_t)sourceID pan:(double)pan;
- (void)setAudioInput:(int64_t)inputID source:(int64_t)sourceID mixOption:(ATEMAudioMixOption)mixOption;
- (void)setAudioMasterFaderGain:(double)gain;
- (void)resetAudioPeakLevels;

- (void)setHyperDeck:(int64_t)deckID networkAddress:(NSString *)address;
- (void)setHyperDeck:(int64_t)deckID switcherInput:(int64_t)inputID;
- (void)playHyperDeck:(int64_t)deckID;
- (void)recordHyperDeck:(int64_t)deckID;
- (void)stopHyperDeck:(int64_t)deckID;
- (void)jogHyperDeck:(int64_t)deckID frames:(NSInteger)frames;
- (void)shuttleHyperDeck:(int64_t)deckID speed:(NSInteger)speedPercent;
- (void)setHyperDeck:(int64_t)deckID currentClip:(int64_t)clipID;
- (void)setHyperDeck:(int64_t)deckID loopedPlayback:(BOOL)enabled;
- (void)setHyperDeck:(int64_t)deckID singleClipPlayback:(BOOL)enabled;
- (void)setHyperDeck:(int64_t)deckID autoRollOnTake:(BOOL)enabled;
- (void)setHyperDeck:(int64_t)deckID autoRollFrameDelay:(NSUInteger)frames;

- (void)shutdown;

+ (BOOL)isRuntimeInstalled;
+ (NSString *)runtimePath;

@end

FOUNDATION_EXPORT int ATEMRunSelfTest(void);
FOUNDATION_EXPORT int ATEMPrintDiagnostics(void);

NS_ASSUME_NONNULL_END

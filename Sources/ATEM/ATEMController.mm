#import "ATEMController.h"

#import <Cocoa/Cocoa.h>
#import <atomic>
#import <cstring>
#import <netinet/in.h>
#import <arpa/inet.h>
#import <vector>

#include <cmath>

#include "BMDSwitcherAPI.h"
#include "ATEMColorMath.h"

static NSString *const kATEMRuntimePath = @"/Library/Application Support/Blackmagic Design/Switchers/BMDSwitcherAPI.bundle";

NSNotificationName const ATEMAudioStateDidChangeNotification = @"ATEMAudioStateDidChangeNotification";
NSNotificationName const ATEMHyperDeckStateDidChangeNotification = @"ATEMHyperDeckStateDidChangeNotification";
NSNotificationName const ATEMStateDidChangeNotification = @"ATEMStateDidChangeNotification";


@interface ATEMInputState ()
@property(nonatomic, readwrite) int64_t inputID;
@property(nonatomic, copy, readwrite) NSString *longName;
@property(nonatomic, copy, readwrite) NSString *shortName;
@property(nonatomic, readwrite) uint32_t availabilityMask;
@end

@implementation ATEMInputState
- (instancetype)initWithID:(int64_t)inputID
                  longName:(NSString *)longName
                 shortName:(NSString *)shortName
          availabilityMask:(uint32_t)availabilityMask
{
    self = [super init];
    if (self) {
        _inputID = inputID;
        _longName = [longName copy];
        _shortName = [shortName copy];
        _availabilityMask = availabilityMask;
    }
    return self;
}
@end


@interface ATEMLabelTargetState ()
@property(nonatomic, readwrite) int64_t inputID;
@property(nonatomic, copy, readwrite) NSString *longName;
@property(nonatomic, copy, readwrite) NSString *shortName;
@property(nonatomic, copy, readwrite) NSString *typeName;
@property(nonatomic, readwrite, getter=isOutput) BOOL output;
+ (instancetype)targetWithInputID:(int64_t)inputID
                         longName:(NSString *)longName
                        shortName:(NSString *)shortName
                         typeName:(NSString *)typeName
                           output:(BOOL)output;
@end

@implementation ATEMLabelTargetState

+ (instancetype)targetWithInputID:(int64_t)inputID
                         longName:(NSString *)longName
                        shortName:(NSString *)shortName
                         typeName:(NSString *)typeName
                           output:(BOOL)output
{
    ATEMLabelTargetState *target = [[ATEMLabelTargetState alloc] init];
    target.inputID = inputID;
    target.longName = longName ?: @"";
    target.shortName = shortName ?: @"";
    target.typeName = typeName ?: @"Input";
    target.output = output;
    return target;
}

@end


@interface ATEMColorGeneratorState ()
@property(nonatomic, readwrite) NSUInteger index;
@property(nonatomic, readwrite) int64_t inputID;
@property(nonatomic, copy, readwrite) NSString *name;
@property(nonatomic, readwrite) double hue;
@property(nonatomic, readwrite) double saturation;
@property(nonatomic, readwrite) double luma;
@end

@implementation ATEMColorGeneratorState
@end


@interface ATEMKeyState ()
@property(nonatomic, readwrite) NSUInteger index;
@property(nonatomic, readwrite, getter=isOnAir) BOOL onAir;
@end

@implementation ATEMKeyState
- (instancetype)initWithIndex:(NSUInteger)index onAir:(BOOL)onAir
{
    self = [super init];
    if (self) {
        _index = index;
        _onAir = onAir;
    }
    return self;
}
@end


@interface ATEMDownstreamKeyState ()
@property(nonatomic, readwrite) NSUInteger index;
@property(nonatomic, readwrite, getter=isOnAir) BOOL onAir;
@property(nonatomic, readwrite, getter=isTied) BOOL tied;
@property(nonatomic, readwrite, getter=isTransitioning) BOOL transitioning;
@property(nonatomic, readwrite) uint32_t framesRemaining;
@end

@implementation ATEMDownstreamKeyState
- (instancetype)initWithIndex:(NSUInteger)index
                        onAir:(BOOL)onAir
                         tied:(BOOL)tied
                transitioning:(BOOL)transitioning
              framesRemaining:(uint32_t)framesRemaining
{
    self = [super init];
    if (self) {
        _index = index;
        _onAir = onAir;
        _tied = tied;
        _transitioning = transitioning;
        _framesRemaining = framesRemaining;
    }
    return self;
}
@end


@interface ATEMAuxState ()
@property(nonatomic, readwrite) NSUInteger index;
@property(nonatomic, copy, readwrite) NSString *name;
@property(nonatomic, readwrite) int64_t sourceID;
@property(nonatomic, readwrite) uint32_t inputAvailabilityMask;
@end

@implementation ATEMAuxState
- (instancetype)initWithIndex:(NSUInteger)index
                         name:(NSString *)name
                     sourceID:(int64_t)sourceID
        inputAvailabilityMask:(uint32_t)inputAvailabilityMask
{
    self = [super init];
    if (self) {
        _index = index;
        _name = [name copy];
        _sourceID = sourceID;
        _inputAvailabilityMask = inputAvailabilityMask;
    }
    return self;
}
@end


@interface ATEMMultiviewWindowState ()
@property(nonatomic, readwrite) NSUInteger index;
@property(nonatomic, readwrite) int64_t sourceID;
@property(nonatomic, readwrite) BOOL canRouteInput;
@property(nonatomic, readwrite) BOOL supportsVUMeter;
@property(nonatomic, readwrite, getter=isVUMeterEnabled) BOOL vuMeterEnabled;
@property(nonatomic, readwrite) BOOL supportsSafeArea;
@property(nonatomic, readwrite, getter=isSafeAreaEnabled) BOOL safeAreaEnabled;
@property(nonatomic, readwrite) uint32_t safeAreaType;
@property(nonatomic, readwrite) BOOL supportsLabelOverlay;
@property(nonatomic, readwrite, getter=isLabelVisible) BOOL labelVisible;
@property(nonatomic, readwrite, getter=isBorderVisible) BOOL borderVisible;
@end

@implementation ATEMMultiviewWindowState
@end


@interface ATEMMultiviewState ()
@property(nonatomic, readwrite) NSUInteger index;
@property(nonatomic, readwrite) ATEMMultiviewLayout layout;
@property(nonatomic, readwrite) BOOL canChangeLayout;
@property(nonatomic, readwrite) BOOL supportsQuadrantLayout;
@property(nonatomic, readwrite) BOOL canRouteInputs;
@property(nonatomic, readwrite) uint32_t inputAvailabilityMask;
@property(nonatomic, readwrite) BOOL supportsVUMeters;
@property(nonatomic, readwrite) BOOL canAdjustVUMeterOpacity;
@property(nonatomic, readwrite) double vuMeterOpacity;
@property(nonatomic, readwrite) BOOL canToggleSafeArea;
@property(nonatomic, readwrite) uint32_t supportedSafeAreaTypes;
@property(nonatomic, readwrite) BOOL supportsProgramPreviewSwap;
@property(nonatomic, readwrite, getter=isProgramPreviewSwapped) BOOL programPreviewSwapped;
@property(nonatomic, readwrite) BOOL canChangeOverlayProperties;
@property(nonatomic, readwrite) NSUInteger totalWindowCount;
@property(nonatomic, copy, readwrite) NSArray<ATEMMultiviewWindowState *> *windows;
@end

@implementation ATEMMultiviewState
@end


@interface ATEMAudioChannelState ()
@property(nonatomic, readwrite) int64_t inputID;
@property(nonatomic, readwrite) int64_t sourceID;
@property(nonatomic, copy, readwrite) NSString *name;
@property(nonatomic, readwrite, getter=isActive) BOOL active;
@property(nonatomic, readwrite) double faderGain;
@property(nonatomic, readwrite) double pan;
@property(nonatomic, readwrite) ATEMAudioMixOption mixOption;
@property(nonatomic, readwrite) NSUInteger supportedMixOptions;
@property(nonatomic, copy, readwrite) NSArray<NSNumber *> *levels;
@property(nonatomic, copy, readwrite) NSArray<NSNumber *> *peakLevels;
@end

@implementation ATEMAudioChannelState
@end


@interface ATEMAudioState ()
@property(nonatomic, readwrite, getter=isAvailable) BOOL available;
@property(nonatomic, readwrite, getter=isDemo) BOOL demo;
@property(nonatomic, copy, readwrite) NSString *statusMessage;
@property(nonatomic, readwrite) double masterFaderGain;
@property(nonatomic, copy, readwrite) NSArray<NSNumber *> *masterLevels;
@property(nonatomic, copy, readwrite) NSArray<NSNumber *> *masterPeakLevels;
@property(nonatomic, copy, readwrite) NSArray<ATEMAudioChannelState *> *channels;
@end

@implementation ATEMAudioState
@end


@interface ATEMHyperDeckClipState ()
@property(nonatomic, readwrite) int64_t clipID;
@property(nonatomic, copy, readwrite) NSString *name;
@property(nonatomic, copy, readwrite) NSString *duration;
@end

@implementation ATEMHyperDeckClipState
@end


@interface ATEMHyperDeckState ()
@property(nonatomic, readwrite) int64_t deckID;
@property(nonatomic, copy, readwrite) NSString *name;
@property(nonatomic, copy, readwrite) NSString *modelName;
@property(nonatomic, copy, readwrite) NSString *networkAddress;
@property(nonatomic, readwrite) int64_t switcherInputID;
@property(nonatomic, readwrite) ATEMHyperDeckConnectionStatus connectionStatus;
@property(nonatomic, readwrite, getter=isRemoteAccessEnabled) BOOL remoteAccessEnabled;
@property(nonatomic, readwrite) ATEMHyperDeckPlayerState playerState;
@property(nonatomic, readwrite) int64_t currentClip;
@property(nonatomic, readwrite) NSUInteger clipCount;
@property(nonatomic, copy, readwrite) NSArray<ATEMHyperDeckClipState *> *clips;
@property(nonatomic, copy, readwrite) NSString *timecode;
@property(nonatomic, copy, readwrite) NSString *recordTimeRemaining;
@property(nonatomic, readwrite, getter=isLoopedPlayback) BOOL loopedPlayback;
@property(nonatomic, readwrite, getter=isSingleClipPlayback) BOOL singleClipPlayback;
@property(nonatomic, readwrite, getter=isAutoRollOnTake) BOOL autoRollOnTake;
@property(nonatomic, readwrite) NSUInteger autoRollFrameDelay;
@property(nonatomic, readwrite) NSInteger shuttleSpeed;
@end

@implementation ATEMHyperDeckState
@end


@interface ATEMState ()
@property(nonatomic, readwrite, getter=isConnected) BOOL connected;
@property(nonatomic, readwrite, getter=isConnecting) BOOL connecting;
@property(nonatomic, readwrite, getter=isDemo) BOOL demo;
@property(nonatomic, copy, readwrite) NSString *productName;
@property(nonatomic, copy, readwrite) NSString *statusMessage;
@property(nonatomic, copy, readwrite) NSArray<ATEMInputState *> *inputs;
@property(nonatomic, readwrite) uint32_t mixEffectInputAvailabilityMask;
@property(nonatomic, readwrite) int64_t programInputID;
@property(nonatomic, readwrite) int64_t previewInputID;
@property(nonatomic, readwrite) double transitionPosition;
@property(nonatomic, readwrite) uint32_t transitionFramesRemaining;
@property(nonatomic, readwrite, getter=isInTransition) BOOL inTransition;
@property(nonatomic, readwrite) ATEMTransitionStyle nextTransitionStyle;
@property(nonatomic, readwrite) ATEMTransitionSelection nextTransitionSelection;
@property(nonatomic, readwrite) uint32_t transitionRate;
@property(nonatomic, readwrite, getter=isFadeToBlack) BOOL fadeToBlack;
@property(nonatomic, readwrite, getter=isFadeToBlackTransitioning) BOOL fadeToBlackTransitioning;
@property(nonatomic, readwrite) uint32_t fadeToBlackFramesRemaining;
@property(nonatomic, copy, readwrite) NSArray<ATEMKeyState *> *upstreamKeys;
@property(nonatomic, copy, readwrite) NSArray<ATEMDownstreamKeyState *> *downstreamKeys;
@property(nonatomic, copy, readwrite) NSArray<ATEMAuxState *> *auxOutputs;
@property(nonatomic, copy, readwrite) NSArray<ATEMMultiviewState *> *multiviews;
@property(nonatomic, copy, readwrite) NSArray<ATEMLabelTargetState *> *labelTargets;
@property(nonatomic, copy, readwrite) NSArray<ATEMColorGeneratorState *> *colorGenerators;
@property(nonatomic, readwrite) uint32_t videoMode;
@property(nonatomic, readwrite) BOOL canChangeVideoMode;
@property(nonatomic, copy, readwrite) NSArray<ATEMVideoModeOption *> *supportedVideoModes;
@end

@implementation ATEMState
@end


@class ATEMController;

static bool InterfaceIDsEqual(const REFIID &left, const REFIID &right)
{
    return std::memcmp(&left, &right, sizeof(REFIID)) == 0;
}

static bool InterfaceIDEqualsUUID(const REFIID &left, CFUUIDRef right)
{
    CFUUIDBytes bytes = CFUUIDGetUUIDBytes(right);
    return InterfaceIDsEqual(left, bytes);
}


class SwitcherMonitor final : public IBMDSwitcherCallback
{
public:
    explicit SwitcherMonitor(ATEMController *owner) : owner_(owner), refCount_(1) {}

    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, LPVOID *value) override;
    ULONG STDMETHODCALLTYPE AddRef(void) override { return ++refCount_; }
    ULONG STDMETHODCALLTYPE Release(void) override
    {
        ULONG count = --refCount_;
        if (count == 0)
            delete this;
        return count;
    }
    HRESULT STDMETHODCALLTYPE Notify(BMDSwitcherEventType eventType, BMDSwitcherVideoMode coreVideoMode) override;

private:
    __unsafe_unretained ATEMController *owner_;
    std::atomic<ULONG> refCount_;
};


class MixEffectBlockMonitor final : public IBMDSwitcherMixEffectBlockCallback
{
public:
    explicit MixEffectBlockMonitor(ATEMController *owner) : owner_(owner), refCount_(1) {}

    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, LPVOID *value) override;
    ULONG STDMETHODCALLTYPE AddRef(void) override { return ++refCount_; }
    ULONG STDMETHODCALLTYPE Release(void) override
    {
        ULONG count = --refCount_;
        if (count == 0)
            delete this;
        return count;
    }
    HRESULT STDMETHODCALLTYPE Notify(BMDSwitcherMixEffectBlockEventType eventType) override;

private:
    __unsafe_unretained ATEMController *owner_;
    std::atomic<ULONG> refCount_;
};

class FairlightMixerMonitor final : public IBMDSwitcherFairlightAudioMixerCallback
{
public:
    explicit FairlightMixerMonitor(ATEMController *owner) : owner_(owner), refCount_(1) {}

    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, LPVOID *value) override;
    ULONG STDMETHODCALLTYPE AddRef(void) override { return ++refCount_; }
    ULONG STDMETHODCALLTYPE Release(void) override
    {
        ULONG count = --refCount_;
        if (count == 0)
            delete this;
        return count;
    }
    HRESULT STDMETHODCALLTYPE Notify(BMDSwitcherFairlightAudioMixerEventType eventType) override;
    HRESULT STDMETHODCALLTYPE MasterOutLevelNotification(uint32_t numLevels,
                                                         const double *levels,
                                                         uint32_t numPeakLevels,
                                                         const double *peakLevels) override;

private:
    __unsafe_unretained ATEMController *owner_;
    std::atomic<ULONG> refCount_;
};

class FairlightSourceMonitor final : public IBMDSwitcherFairlightAudioSourceCallback
{
public:
    FairlightSourceMonitor(ATEMController *owner, int64_t inputID, int64_t sourceID)
        : owner_(owner), inputID_(inputID), sourceID_(sourceID), refCount_(1) {}

    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID iid, LPVOID *value) override;
    ULONG STDMETHODCALLTYPE AddRef(void) override { return ++refCount_; }
    ULONG STDMETHODCALLTYPE Release(void) override
    {
        ULONG count = --refCount_;
        if (count == 0)
            delete this;
        return count;
    }
    HRESULT STDMETHODCALLTYPE Notify(BMDSwitcherFairlightAudioSourceEventType eventType) override;
    HRESULT STDMETHODCALLTYPE OutputLevelNotification(uint32_t numLevels,
                                                      const double *levels,
                                                      uint32_t numPeakLevels,
                                                      const double *peakLevels) override;

private:
    __unsafe_unretained ATEMController *owner_;
    int64_t inputID_;
    int64_t sourceID_;
    std::atomic<ULONG> refCount_;
};


struct AuxAPIRecord
{
    int64_t inputID = 0;
    IBMDSwitcherInputAux *api = nullptr;
    __strong NSString *name = nil;
    uint32_t inputAvailabilityMask = 0;
};

struct InputAPIRecord
{
    int64_t inputID = 0;
    BMDSwitcherPortType portType = bmdSwitcherPortTypeExternal;
    IBMDSwitcherInput *api = nullptr;
};

struct ColorGeneratorAPIRecord
{
    int64_t inputID = 0;
    IBMDSwitcherInputColor *api = nullptr;
    __strong NSString *name = nil;
};

struct FairlightSourceAPIRecord
{
    int64_t inputID = 0;
    int64_t sourceID = 0;
    IBMDSwitcherFairlightAudioSource *api = nullptr;
    FairlightSourceMonitor *monitor = nullptr;
    __strong NSString *name = nil;
    std::vector<double> levels;
    std::vector<double> peaks;
};

struct DemoAudioChannel
{
    int64_t inputID = 0;
    int64_t sourceID = 0;
    double faderGain = 0;
    double pan = 0;
    ATEMAudioMixOption mixOption = ATEMAudioMixOptionAudioFollowVideo;
};

struct DemoHyperDeck
{
    int64_t deckID = 0;
    __strong NSString *address = nil;
    int64_t switcherInputID = 1;
    ATEMHyperDeckConnectionStatus connectionStatus = ATEMHyperDeckConnectionStatusNotConnected;
    ATEMHyperDeckPlayerState playerState = ATEMHyperDeckPlayerStateIdle;
    int64_t currentClip = -1;
    bool loopedPlayback = false;
    bool singleClipPlayback = false;
    bool autoRollOnTake = false;
    NSUInteger autoRollFrameDelay = 0;
    NSInteger shuttleSpeed = 0;
};

struct DemoColorGenerator
{
    int64_t inputID = 0;
    __strong NSString *name = nil;
    double hue = 0;        // degrees
    double saturation = 0; // 0...1
    double luma = 0;       // 0...1
};

struct DemoMultiview
{
    ATEMMultiviewLayout layout = ATEMMultiviewLayoutProgramTop;
    bool programPreviewSwapped = false;
    double vuMeterOpacity = 0.75;
    std::vector<int64_t> sources;
    std::vector<bool> vuMeters;
    std::vector<bool> safeAreas;
    std::vector<bool> labels;
    std::vector<bool> borders;
};

template <typename T>
struct PendingValue
{
    bool active = false;
    T value {};
    CFAbsoluteTime expiresAt = 0;
};

struct PendingMultiview
{
    PendingValue<ATEMMultiviewLayout> layout;
    PendingValue<bool> programPreviewSwapped;
    PendingValue<double> vuMeterOpacity;
    std::vector<PendingValue<int64_t>> sources;
    std::vector<PendingValue<bool>> vuMeters;
    std::vector<PendingValue<bool>> safeAreas;
    std::vector<PendingValue<bool>> labels;
    std::vector<PendingValue<bool>> borders;
};

static constexpr CFTimeInterval kReadbackGracePeriod = 2.0;

template <typename T>
static void MarkPendingValue(PendingValue<T> &pending, T value)
{
    pending.active = true;
    pending.value = value;
    pending.expiresAt = CFAbsoluteTimeGetCurrent() + kReadbackGracePeriod;
}

template <typename T>
static void ReconcilePendingValue(PendingValue<T> &pending,
                                           HRESULT readResult,
                                           T *value)
{
    if (!pending.active)
        return;
    if (SUCCEEDED(readResult) && *value == pending.value) {
        pending.active = false;
        return;
    }
    if (CFAbsoluteTimeGetCurrent() <= pending.expiresAt)
        *value = pending.value;
    else
        pending.active = false;
}

static void ReconcilePendingDouble(PendingValue<double> &pending,
                                   HRESULT readResult,
                                   double *value,
                                   double tolerance = 0.001)
{
    if (!pending.active)
        return;
    if (SUCCEEDED(readResult) && std::fabs(*value - pending.value) < tolerance) {
        pending.active = false;
        return;
    }
    if (CFAbsoluteTimeGetCurrent() <= pending.expiresAt)
        *value = pending.value;
    else
        pending.active = false;
}

// Colour-generator writes need the same echo suppression as multiview writes:
// SetHue/SetSaturation/SetLuma return before the switcher acknowledges, so the
// next 250 ms poll would otherwise snap a slider the user is still dragging
// back to the pre-write value.
struct PendingColorGenerator
{
    PendingValue<double> hue;
    PendingValue<double> saturation;
    PendingValue<double> luma;
};

static void EnsurePendingMultiviewWindowCount(PendingMultiview &pending, NSUInteger count)
{
    if (pending.sources.size() >= count)
        return;
    pending.sources.resize(count);
    pending.vuMeters.resize(count);
    pending.safeAreas.resize(count);
    pending.labels.resize(count);
    pending.borders.resize(count);
}


@interface ATEMController ()
{
    dispatch_queue_t _controlQueue;
    dispatch_source_t _pollTimer;
    dispatch_source_t _featureTimer;
    BOOL _shutdown;

    IBMDSwitcherDiscovery *_discovery;
    IBMDSwitcher *_switcher;
    IBMDSwitcherMixEffectBlock *_mixEffectBlock;
    IBMDSwitcherTransitionParameters *_transitionParameters;
    IBMDSwitcherTransitionMixParameters *_mixParameters;
    IBMDSwitcherTransitionDipParameters *_dipParameters;
    IBMDSwitcherTransitionWipeParameters *_wipeParameters;
    IBMDSwitcherTransitionDVEParameters *_dveParameters;
    IBMDSwitcherTransitionStingerParameters *_stingerParameters;
    SwitcherMonitor *_switcherMonitor;
    MixEffectBlockMonitor *_mixEffectBlockMonitor;
    std::vector<IBMDSwitcherKey *> _upstreamKeyAPIs;
    std::vector<IBMDSwitcherDownstreamKey *> _downstreamKeyAPIs;
    std::vector<InputAPIRecord> _inputAPIs;
    std::vector<AuxAPIRecord> _auxAPIs;
    std::vector<ColorGeneratorAPIRecord> _colorGeneratorAPIs;
    std::vector<PendingColorGenerator> _pendingColorGenerators;
    std::vector<IBMDSwitcherMultiView *> _multiviewAPIs;
    std::vector<PendingMultiview> _pendingMultiviews;
    NSArray<ATEMMultiviewState *> *_lastKnownMultiviews;
    IBMDSwitcherFairlightAudioMixer *_fairlightMixer;
    FairlightMixerMonitor *_fairlightMixerMonitor;
    std::vector<FairlightSourceAPIRecord> _fairlightSources;
    std::vector<double> _masterAudioLevels;
    std::vector<double> _masterAudioPeaks;
    std::vector<IBMDSwitcherHyperDeck *> _hyperDeckAPIs;
    NSMutableDictionary<NSNumber *, NSArray<ATEMHyperDeckClipState *> *> *_hyperDeckClipCache;
    NSMutableDictionary<NSNumber *, NSNumber *> *_hyperDeckClipCacheTimes;
    NSMutableDictionary<NSNumber *, NSNumber *> *_hyperDeckClipCacheCounts;

    BOOL _connecting;
    BOOL _demo;
    NSString *_targetAddressLocked;
    NSString *_productName;
    NSString *_statusMessage;
    NSArray<ATEMInputState *> *_inputStates;
    NSArray<ATEMLabelTargetState *> *_labelStates;
    NSDictionary<NSNumber *, NSString *> *_inputNamesByID;
    uint32_t _mixEffectInputAvailabilityMask;
    NSArray<ATEMVideoModeOption *> *_supportedVideoModes;

    int64_t _demoProgram;
    uint32_t _demoVideoMode;
    int64_t _demoPreview;
    double _demoTransitionPosition;
    BOOL _demoInTransition;
    ATEMTransitionStyle _demoStyle;
    ATEMTransitionSelection _demoSelection;
    uint32_t _demoRate;
    BOOL _demoFTB;
    std::vector<bool> _demoKeys;
    std::vector<bool> _demoDSKOnAir;
    std::vector<bool> _demoDSKTied;
    std::vector<int64_t> _demoAuxSources;
    std::vector<DemoColorGenerator> _demoColorGenerators;
    std::vector<DemoMultiview> _demoMultiviews;
    std::vector<DemoAudioChannel> _demoAudioChannels;
    double _demoMasterAudioFader;
    std::vector<DemoHyperDeck> _demoHyperDecks;
}

@property(nonatomic, strong, readwrite) ATEMState *latestState;
@property(nonatomic, strong, readwrite) ATEMAudioState *latestAudioState;
@property(nonatomic, copy, readwrite) NSArray<ATEMHyperDeckState *> *latestHyperDeckStates;
@property(nonatomic, copy, readwrite) NSString *currentAddress;

- (void)sdkStateChanged;
- (void)sdkAudioStateChanged;
- (void)audioMasterLevelsChanged:(const double *)levels
                           count:(uint32_t)count
                      peakLevels:(const double *)peakLevels
                       peakCount:(uint32_t)peakCount;
- (void)audioInput:(int64_t)inputID
             source:(int64_t)sourceID
      levelsChanged:(const double *)levels
              count:(uint32_t)count
         peakLevels:(const double *)peakLevels
          peakCount:(uint32_t)peakCount;
- (void)switcherDisconnectedByDevice;
- (void)publishStateLocked;
- (void)publishFeatureStatesLocked;
- (NSArray<ATEMHyperDeckClipState *> *)clipsForHyperDeckLocked:(IBMDSwitcherHyperDeck *)api
                                                        deckID:(int64_t)deckID
                                                     clipCount:(NSUInteger)clipCount;
- (void)disconnectLockedWithMessage:(NSString *)message;
@end


HRESULT SwitcherMonitor::QueryInterface(REFIID iid, LPVOID *value)
{
    if (!value)
        return E_POINTER;
    if (InterfaceIDsEqual(iid, IID_IBMDSwitcherCallback)) {
        *value = static_cast<IBMDSwitcherCallback *>(this);
        AddRef();
        return S_OK;
    }
    if (InterfaceIDEqualsUUID(iid, IUnknownUUID)) {
        *value = static_cast<IUnknown *>(this);
        AddRef();
        return S_OK;
    }
    *value = nullptr;
    return E_NOINTERFACE;
}

HRESULT SwitcherMonitor::Notify(BMDSwitcherEventType eventType, BMDSwitcherVideoMode coreVideoMode)
{
    (void)coreVideoMode;
    if (eventType == bmdSwitcherEventTypeDisconnected)
        [owner_ switcherDisconnectedByDevice];
    else
        [owner_ sdkStateChanged];
    return S_OK;
}

HRESULT MixEffectBlockMonitor::QueryInterface(REFIID iid, LPVOID *value)
{
    if (!value)
        return E_POINTER;
    if (InterfaceIDsEqual(iid, IID_IBMDSwitcherMixEffectBlockCallback)) {
        *value = static_cast<IBMDSwitcherMixEffectBlockCallback *>(this);
        AddRef();
        return S_OK;
    }
    if (InterfaceIDEqualsUUID(iid, IUnknownUUID)) {
        *value = static_cast<IUnknown *>(this);
        AddRef();
        return S_OK;
    }
    *value = nullptr;
    return E_NOINTERFACE;
}

HRESULT MixEffectBlockMonitor::Notify(BMDSwitcherMixEffectBlockEventType eventType)
{
    (void)eventType;
    [owner_ sdkStateChanged];
    return S_OK;
}

HRESULT FairlightMixerMonitor::QueryInterface(REFIID iid, LPVOID *value)
{
    if (!value)
        return E_POINTER;
    if (InterfaceIDsEqual(iid, IID_IBMDSwitcherFairlightAudioMixerCallback)) {
        *value = static_cast<IBMDSwitcherFairlightAudioMixerCallback *>(this);
        AddRef();
        return S_OK;
    }
    if (InterfaceIDEqualsUUID(iid, IUnknownUUID)) {
        *value = static_cast<IUnknown *>(this);
        AddRef();
        return S_OK;
    }
    *value = nullptr;
    return E_NOINTERFACE;
}

HRESULT FairlightMixerMonitor::Notify(BMDSwitcherFairlightAudioMixerEventType eventType)
{
    (void)eventType;
    [owner_ sdkAudioStateChanged];
    return S_OK;
}

HRESULT FairlightMixerMonitor::MasterOutLevelNotification(uint32_t numLevels,
                                                          const double *levels,
                                                          uint32_t numPeakLevels,
                                                          const double *peakLevels)
{
    [owner_ audioMasterLevelsChanged:levels
                               count:numLevels
                          peakLevels:peakLevels
                           peakCount:numPeakLevels];
    return S_OK;
}

HRESULT FairlightSourceMonitor::QueryInterface(REFIID iid, LPVOID *value)
{
    if (!value)
        return E_POINTER;
    if (InterfaceIDsEqual(iid, IID_IBMDSwitcherFairlightAudioSourceCallback)) {
        *value = static_cast<IBMDSwitcherFairlightAudioSourceCallback *>(this);
        AddRef();
        return S_OK;
    }
    if (InterfaceIDEqualsUUID(iid, IUnknownUUID)) {
        *value = static_cast<IUnknown *>(this);
        AddRef();
        return S_OK;
    }
    *value = nullptr;
    return E_NOINTERFACE;
}

HRESULT FairlightSourceMonitor::Notify(BMDSwitcherFairlightAudioSourceEventType eventType)
{
    (void)eventType;
    [owner_ sdkAudioStateChanged];
    return S_OK;
}

HRESULT FairlightSourceMonitor::OutputLevelNotification(uint32_t numLevels,
                                                        const double *levels,
                                                        uint32_t numPeakLevels,
                                                        const double *peakLevels)
{
    [owner_ audioInput:inputID_
                 source:sourceID_
          levelsChanged:levels
                  count:numLevels
             peakLevels:peakLevels
              peakCount:numPeakLevels];
    return S_OK;
}


static NSString *StringFromOwnedCFString(CFStringRef value)
{
    if (!value)
        return @"";
    NSString *result = [(__bridge NSString *)value copy];
    CFRelease(value);
    return result;
}

static NSArray<NSNumber *> *NumbersFromValues(const std::vector<double> &values)
{
    NSMutableArray<NSNumber *> *numbers = [NSMutableArray arrayWithCapacity:values.size()];
    for (double value : values)
        [numbers addObject:@(value)];
    return numbers;
}

static NSString *InputNameForID(NSArray<ATEMInputState *> *inputs, int64_t inputID)
{
    for (ATEMInputState *input in inputs)
        if (input.inputID == inputID)
            return input.longName;
    return [NSString stringWithFormat:@"Input %lld", inputID];
}

static BOOL IsOutputPortType(BMDSwitcherPortType portType)
{
    return portType == bmdSwitcherPortTypeMixEffectBlockOutput ||
           portType == bmdSwitcherPortTypeAuxOutput ||
           portType == bmdSwitcherPortTypeKeyCutOutput ||
           portType == bmdSwitcherPortTypeMultiview ||
           portType == bmdSwitcherPortTypeAudioMonitor;
}

static NSString *PortTypeName(BMDSwitcherPortType portType)
{
    switch (portType) {
        case bmdSwitcherPortTypeExternal: return @"Camera / Input";
        case bmdSwitcherPortTypeExternalDirect: return @"Direct Input";
        case bmdSwitcherPortTypeBlack: return @"Black Generator";
        case bmdSwitcherPortTypeColorBars: return @"Color Bars";
        case bmdSwitcherPortTypeColorGenerator: return @"Color Generator";
        case bmdSwitcherPortTypeMediaPlayerFill: return @"Media Player Fill";
        case bmdSwitcherPortTypeMediaPlayerCut: return @"Media Player Key";
        case bmdSwitcherPortTypeSuperSource: return @"SuperSource";
        case bmdSwitcherPortTypeMixEffectBlockOutput: return @"M/E Output";
        case bmdSwitcherPortTypeAuxOutput: return @"Aux Output";
        case bmdSwitcherPortTypeKeyCutOutput: return @"Key Output";
        case bmdSwitcherPortTypeMultiview: return @"Multiview Output";
        case bmdSwitcherPortTypeAudioMonitor: return @"Audio Monitor Output";
        default: return @"Input";
    }
}

static NSString *LabelLongNameForID(NSArray<ATEMLabelTargetState *> *targets,
                                    int64_t inputID,
                                    NSString *fallback)
{
    for (ATEMLabelTargetState *target in targets)
        if (target.inputID == inputID)
            return target.longName.length ? target.longName : fallback;
    return fallback;
}

static ATEMLabelTargetState *LabelTargetForID(NSArray<ATEMLabelTargetState *> *targets, int64_t inputID)
{
    for (ATEMLabelTargetState *target in targets)
        if (target.inputID == inputID)
            return target;
    return nil;
}

static const int64_t kDemoAuxLabelBase = 10000;
static const int64_t kDemoMultiviewLabelBase = 11000;

static ATEMHyperDeckConnectionStatus AppHyperDeckConnectionStatus(BMDSwitcherHyperDeckConnectionStatus status)
{
    switch (status) {
        case bmdSwitcherHyperDeckConnectionStatusConnecting:
            return ATEMHyperDeckConnectionStatusConnecting;
        case bmdSwitcherHyperDeckConnectionStatusConnected:
            return ATEMHyperDeckConnectionStatusConnected;
        case bmdSwitcherHyperDeckConnectionStatusIncompatible:
            return ATEMHyperDeckConnectionStatusIncompatible;
        case bmdSwitcherHyperDeckConnectionStatusNotConnected:
        default:
            return ATEMHyperDeckConnectionStatusNotConnected;
    }
}

static ATEMHyperDeckPlayerState AppHyperDeckPlayerState(BMDSwitcherHyperDeckPlayerState state)
{
    switch (state) {
        case bmdSwitcherHyperDeckStateIdle: return ATEMHyperDeckPlayerStateIdle;
        case bmdSwitcherHyperDeckStatePlay: return ATEMHyperDeckPlayerStatePlay;
        case bmdSwitcherHyperDeckStateRecord: return ATEMHyperDeckPlayerStateRecord;
        case bmdSwitcherHyperDeckStateShuttle: return ATEMHyperDeckPlayerStateShuttle;
        case bmdSwitcherHyperDeckStateUnknown:
        default: return ATEMHyperDeckPlayerStateUnknown;
    }
}

static NSString *TimecodeString(uint16_t hours, uint8_t minutes, uint8_t seconds, uint8_t frames)
{
    return [NSString stringWithFormat:@"%02u:%02u:%02u:%02u", hours, minutes, seconds, frames];
}

// The ATEM SDK specifies a packed IPv4 value with the least-significant byte first.
static BOOL PackHyperDeckAddress(NSString *address, uint32_t *packedAddress)
{
    if (!packedAddress)
        return NO;
    NSArray<NSString *> *parts = [address componentsSeparatedByString:@"."];
    if (parts.count != 4)
        return NO;
    uint32_t packed = 0;
    for (NSUInteger index = 0; index < 4; ++index) {
        NSString *part = parts[index];
        NSScanner *scanner = [NSScanner scannerWithString:part];
        NSInteger value = -1;
        if (![scanner scanInteger:&value] || !scanner.isAtEnd || value < 0 || value > 255)
            return NO;
        packed |= ((uint32_t)value) << (index * 8);
    }
    *packedAddress = packed;
    return YES;
}

static NSString *UnpackHyperDeckAddress(uint32_t packedAddress)
{
    if (packedAddress == 0)
        return @"";
    return [NSString stringWithFormat:@"%u.%u.%u.%u",
            packedAddress & 0xFFU,
            (packedAddress >> 8U) & 0xFFU,
            (packedAddress >> 16U) & 0xFFU,
            (packedAddress >> 24U) & 0xFFU];
}

#pragma mark - Video standard table

typedef struct {
    BMDSwitcherVideoMode mode;
    const char *format;
    const char *frameRate;
} ATEMVideoModeEntry;

// Every BMDSwitcherVideoMode the *installed* SDK header defines, with UI labels,
// ordered by resolution and then by frame rate.
//
// The contents are GENERATED at build time by Tools/generate_video_modes.py, which
// reads the enum straight out of BMDSwitcherAPI.h. That is deliberate. The enum gains
// members with every SDK release — the 30 and 60 fps variants, higher resolutions —
// and a hand-written list is wrong in two directions at once: it omits standards the
// switcher can actually run, and it fails to compile the moment it names a symbol the
// installed header does not define. Generating it means this app offers exactly the
// set of standards the installed SDK knows about, no more and no less.
//
// Regenerate with `make video-modes`. Never hand-edit ATEMVideoModeTable.inc.
static const ATEMVideoModeEntry kATEMVideoModeTable[] = {
#include "ATEMVideoModeTable.inc"
};

static const size_t kATEMVideoModeTableCount = sizeof(kATEMVideoModeTable) / sizeof(kATEMVideoModeTable[0]);

// How far past the highest known enum value the fallback probe reaches, and the
// value above which it gives up entirely. See refreshSupportedVideoModesLocked.
static const uint32_t kATEMVideoModeProbeHeadroom = 32;
static const uint32_t kATEMVideoModeProbeCeiling = 512;

@interface ATEMVideoModeOption ()
@property(nonatomic, readwrite) uint32_t rawMode;
@property(nonatomic, copy, readwrite) NSString *formatName;
@property(nonatomic, copy, readwrite) NSString *frameRateName;
+ (instancetype)optionWithRawMode:(uint32_t)rawMode
                           format:(NSString *)format
                        frameRate:(NSString *)frameRate;
@end

@implementation ATEMVideoModeOption

+ (instancetype)optionWithRawMode:(uint32_t)rawMode
                           format:(NSString *)format
                        frameRate:(NSString *)frameRate
{
    ATEMVideoModeOption *option = [[ATEMVideoModeOption alloc] init];
    option.rawMode = rawMode;
    option.formatName = format ?: @"";
    option.frameRateName = frameRate ?: @"";
    return option;
}

- (NSString *)displayName
{
    if (self.frameRateName.length == 0)
        return self.formatName;
    return [NSString stringWithFormat:@"%@%@", self.formatName, self.frameRateName];
}

@end

/// Every mode in the label table, used for demo mode where no switcher can be asked.
static NSArray<ATEMVideoModeOption *> *ATEMAllKnownVideoModes(void)
{
    NSMutableArray<ATEMVideoModeOption *> *options = [NSMutableArray array];
    for (size_t index = 0; index < kATEMVideoModeTableCount; ++index) {
        const ATEMVideoModeEntry &entry = kATEMVideoModeTable[index];
        [options addObject:[ATEMVideoModeOption optionWithRawMode:(uint32_t)entry.mode
                                                           format:@(entry.format)
                                                        frameRate:@(entry.frameRate)]];
    }
    return [options copy];
}

/// Demo mode's starting standard, resolved from the generated table rather than by
/// naming an SDK symbol here, so no BMDSwitcherVideoMode constant is referenced
/// outside ATEMVideoModeTable.inc. Falls back to the first known mode.
static uint32_t ATEMDefaultDemoVideoMode(void)
{
    for (size_t index = 0; index < kATEMVideoModeTableCount; ++index) {
        const ATEMVideoModeEntry &entry = kATEMVideoModeTable[index];
        if (std::strcmp(entry.format, "1080p") == 0 && std::strcmp(entry.frameRate, "59.94") == 0)
            return (uint32_t)entry.mode;
    }
    return kATEMVideoModeTableCount > 0 ? (uint32_t)kATEMVideoModeTable[0].mode : 0;
}

static ATEMTransitionStyle AppTransitionStyle(BMDSwitcherTransitionStyle style)
{
    switch (style) {
        case bmdSwitcherTransitionStyleDip: return ATEMTransitionStyleDip;
        case bmdSwitcherTransitionStyleWipe: return ATEMTransitionStyleWipe;
        case bmdSwitcherTransitionStyleDVE: return ATEMTransitionStyleDVE;
        case bmdSwitcherTransitionStyleStinger: return ATEMTransitionStyleStinger;
        case bmdSwitcherTransitionStyleMix:
        default: return ATEMTransitionStyleMix;
    }
}

static BMDSwitcherTransitionStyle SDKTransitionStyle(ATEMTransitionStyle style)
{
    switch (style) {
        case ATEMTransitionStyleDip: return bmdSwitcherTransitionStyleDip;
        case ATEMTransitionStyleWipe: return bmdSwitcherTransitionStyleWipe;
        case ATEMTransitionStyleDVE: return bmdSwitcherTransitionStyleDVE;
        case ATEMTransitionStyleStinger: return bmdSwitcherTransitionStyleStinger;
        case ATEMTransitionStyleMix:
        default: return bmdSwitcherTransitionStyleMix;
    }
}

static ATEMTransitionSelection AppTransitionSelection(BMDSwitcherTransitionSelection selection)
{
    return (ATEMTransitionSelection)(NSUInteger)selection;
}

static BMDSwitcherTransitionSelection SDKTransitionSelection(ATEMTransitionSelection selection)
{
    return (BMDSwitcherTransitionSelection)(NSUInteger)selection;
}

static NSUInteger ActiveQuadrantWindowCount(ATEMMultiviewLayout layout)
{
    uint32_t mask = (uint32_t)layout & 0x0FU;
    NSUInteger splitQuadrants = 0;
    while (mask != 0) {
        splitQuadrants += mask & 1U;
        mask >>= 1U;
    }
    return 4 + splitQuadrants * 3;
}

static constexpr uint32_t kQuadrantPhysicalWindowCount = 16;

static uint32_t NormalizedMultiviewWindowCount(BOOL supportsQuadrantLayout,
                                                uint32_t reportedWindowCount)
{
    reportedWindowCount = MIN(reportedWindowCount, 64U);
    return supportsQuadrantLayout
        ? MAX(reportedWindowCount, kQuadrantPhysicalWindowCount)
        : reportedWindowCount;
}

static BOOL CanRouteMultiviewWindow(BOOL supportsQuadrantLayout, NSUInteger window)
{
    // On classic multiviews the SDK reserves windows 0 and 1 for
    // Program/Preview. Quadrant-capable models may route every grid cell.
    return supportsQuadrantLayout || window >= 2;
}

// Quadrant-capable ATEMs expose a fixed 4x4 grid of 16 SDK window IDs.
// A large quadrant uses the top-left ID of its 2x2 block; splitting that
// quadrant reveals all four IDs. The IDs therefore stay sparse whenever one
// or more quadrants are large:
//   TL {0,1,4,5}, TR {2,3,6,7}, BL {8,9,12,13}, BR {10,11,14,15}.
static std::vector<uint32_t> VisibleQuadrantWindowIndices(ATEMMultiviewLayout layout)
{
    std::vector<uint32_t> indices;
    uint32_t layoutMask = (uint32_t)layout & 0x0FU;
    for (uint32_t index = 0; index < kQuadrantPhysicalWindowCount; ++index) {
        uint32_t row = index / 4;
        uint32_t column = index % 4;
        ATEMMultiviewLayout quadrantBit;
        if (row < 2)
            quadrantBit = column < 2 ? ATEMMultiviewLayoutTopLeftSmall
                                     : ATEMMultiviewLayoutTopRightSmall;
        else
            quadrantBit = column < 2 ? ATEMMultiviewLayoutBottomLeftSmall
                                     : ATEMMultiviewLayoutBottomRightSmall;
        BOOL quadrantIsSplit =
            (layoutMask & (uint32_t)quadrantBit) != 0;
        BOOL isLargeWindowPrimary = (row % 2 == 0) && (column % 2 == 0);
        if (quadrantIsSplit || isLargeWindowPrimary)
            indices.push_back(index);
    }
    return indices;
}

static ATEMMultiviewWindowState *MultiviewWindowStateForIndex(ATEMMultiviewState *state,
                                                              NSUInteger physicalIndex)
{
    for (ATEMMultiviewWindowState *window in state.windows)
        if (window.index == physicalIndex)
            return window;
    return nil;
}

static NSString *ConnectionFailureMessage(BMDSwitcherConnectToFailure failure)
{
    switch (failure) {
        case bmdSwitcherConnectToFailureNoResponse:
            return @"No response from the switcher. Check its address and network connection.";
        case bmdSwitcherConnectToFailureIncompatibleFirmware:
            return @"The switcher firmware is incompatible with the installed ATEM runtime.";
        case bmdSwitcherConnectToFailureCorruptData:
            return @"The switcher returned corrupt connection data.";
        case bmdSwitcherConnectToFailureStateSync:
            return @"The switcher could not synchronize its state.";
        case bmdSwitcherConnectToFailureStateSyncTimedOut:
            return @"The switcher state synchronization timed out.";
        default:
            return @"The connection failed for an unknown reason.";
    }
}


@implementation ATEMController

- (instancetype)init
{
    self = [super init];
    if (!self)
        return nil;

    _controlQueue = dispatch_queue_create("com.local.atem-cntrl.control", DISPATCH_QUEUE_SERIAL);
    _switcherMonitor = new SwitcherMonitor(self);
    _mixEffectBlockMonitor = new MixEffectBlockMonitor(self);
    _fairlightMixerMonitor = new FairlightMixerMonitor(self);
    _targetAddressLocked = @"";
    _productName = @"";
    _statusMessage = [ATEMController isRuntimeInstalled]
        ? @"Enter the switcher IP address to connect."
        : @"Blackmagic Switchers runtime not found. Install ATEM Software Control first.";
    _inputStates = @[];
    _labelStates = @[];
    _inputNamesByID = @{};
    _supportedVideoModes = @[];
    _demoVideoMode = ATEMDefaultDemoVideoMode();
    _hyperDeckClipCache = [NSMutableDictionary dictionary];
    _hyperDeckClipCacheTimes = [NSMutableDictionary dictionary];
    _hyperDeckClipCacheCounts = [NSMutableDictionary dictionary];
    _lastKnownMultiviews = @[];
    _demoRate = 25;
    _demoSelection = ATEMTransitionSelectionBackground;
    self.latestState = [self emptyStateWithMessage:_statusMessage];
    ATEMAudioState *audioState = [[ATEMAudioState alloc] init];
    audioState.statusMessage = @"Connect an ATEM with Fairlight audio support.";
    audioState.masterLevels = @[];
    audioState.masterPeakLevels = @[];
    audioState.channels = @[];
    self.latestAudioState = audioState;
    self.latestHyperDeckStates = @[];
    self.currentAddress = @"";

    __weak ATEMController *weakSelf = self;
    dispatch_async(_controlQueue, ^{
        ATEMController *strongSelf = weakSelf;
        if (!strongSelf)
            return;
        strongSelf->_discovery = CreateBMDSwitcherDiscoveryInstance();
        if (!strongSelf->_discovery)
            strongSelf->_statusMessage = @"Could not load BMDSwitcherAPI. Reinstall ATEM Software Control.";
        [strongSelf publishStateLocked];
    });

    _pollTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _controlQueue);
    dispatch_source_set_timer(_pollTimer,
                              dispatch_time(DISPATCH_TIME_NOW, 250 * NSEC_PER_MSEC),
                              250 * NSEC_PER_MSEC,
                              75 * NSEC_PER_MSEC);
    dispatch_source_set_event_handler(_pollTimer, ^{
        ATEMController *strongSelf = weakSelf;
        if (strongSelf && (strongSelf->_switcher || strongSelf->_demo))
            [strongSelf publishStateLocked];
    });
    dispatch_resume(_pollTimer);

    _featureTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _controlQueue);
    dispatch_source_set_timer(_featureTimer,
                              dispatch_time(DISPATCH_TIME_NOW, 100 * NSEC_PER_MSEC),
                              100 * NSEC_PER_MSEC,
                              25 * NSEC_PER_MSEC);
    dispatch_source_set_event_handler(_featureTimer, ^{
        ATEMController *strongSelf = weakSelf;
        if (strongSelf && (strongSelf->_switcher || strongSelf->_demo))
            [strongSelf publishFeatureStatesLocked];
    });
    dispatch_resume(_featureTimer);

    return self;
}

- (ATEMState *)emptyStateWithMessage:(NSString *)message
{
    ATEMState *state = [[ATEMState alloc] init];
    state.productName = @"";
    state.statusMessage = message ?: @"";
    state.inputs = @[];
    state.mixEffectInputAvailabilityMask = 0;
    state.programInputID = -1;
    state.previewInputID = -1;
    state.nextTransitionStyle = ATEMTransitionStyleMix;
    state.nextTransitionSelection = ATEMTransitionSelectionBackground;
    state.transitionRate = 25;
    state.upstreamKeys = @[];
    state.downstreamKeys = @[];
    state.auxOutputs = @[];
    state.multiviews = @[];
    state.labelTargets = @[];
    state.videoMode = 0;
    state.canChangeVideoMode = NO;
    state.supportedVideoModes = @[];
    return state;
}

+ (NSString *)runtimePath
{
    return kATEMRuntimePath;
}

+ (BOOL)isRuntimeInstalled
{
    return [[NSFileManager defaultManager] fileExistsAtPath:kATEMRuntimePath];
}

- (void)connectToAddress:(NSString *)address
{
    NSString *trimmed = [address stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (trimmed.length == 0) {
        dispatch_async(_controlQueue, ^{
            self->_statusMessage = @"Enter a switcher IP address or host name.";
            [self publishStateLocked];
        });
        return;
    }

    dispatch_async(_controlQueue, ^{
        if (self->_shutdown)
            return;

        [self disconnectLockedWithMessage:@""];
        self->_connecting = YES;
        self->_demo = NO;
        self->_targetAddressLocked = [trimmed copy];
        self->_statusMessage = [NSString stringWithFormat:@"Connecting to %@…", trimmed];
        [self publishStateLocked];

        if (!self->_discovery)
            self->_discovery = CreateBMDSwitcherDiscoveryInstance();
        if (!self->_discovery) {
            self->_connecting = NO;
            self->_statusMessage = @"BMDSwitcherAPI could not be loaded. Reinstall ATEM Software Control.";
            [self publishStateLocked];
            return;
        }

        IBMDSwitcher *newSwitcher = nullptr;
        BMDSwitcherConnectToFailure failure = bmdSwitcherConnectToFailureNoResponse;
        HRESULT result = self->_discovery->ConnectTo((__bridge CFStringRef)trimmed, &newSwitcher, &failure);
        self->_connecting = NO;
        if (FAILED(result) || !newSwitcher) {
            self->_statusMessage = ConnectionFailureMessage(failure);
            [self publishStateLocked];
            return;
        }

        self->_switcher = newSwitcher;
        self->_switcher->AddCallback(self->_switcherMonitor);
        if (![self configureConnectedSwitcherLocked]) {
            [self disconnectLockedWithMessage:@"Connected, but no mix/effects block was available."];
            [self publishStateLocked];
            return;
        }
        self->_statusMessage = @"Connected. Camera-control initialization is intentionally isolated from this core surface.";
        [self publishStateLocked];
    });
}

/// Asks the connected switcher which video standards it accepts. Runs once per
/// connection: the answer is a hardware capability and does not change at runtime.
- (void)refreshSupportedVideoModesLocked
{
    if (!_switcher) {
        _supportedVideoModes = @[];
        return;
    }

    NSMutableArray<ATEMVideoModeOption *> *options = [NSMutableArray array];
    NSMutableSet<NSNumber *> *listed = [NSMutableSet set];

    for (size_t index = 0; index < kATEMVideoModeTableCount; ++index) {
        const ATEMVideoModeEntry &entry = kATEMVideoModeTable[index];
        bool supported = false;
        if (FAILED(_switcher->DoesSupportVideoMode(entry.mode, &supported)) || !supported)
            continue;
        [options addObject:[ATEMVideoModeOption optionWithRawMode:(uint32_t)entry.mode
                                                           format:@(entry.format)
                                                        frameRate:@(entry.frameRate)]];
        [listed addObject:@((uint32_t)entry.mode)];
    }

    // Safety net for a runtime newer than the SDK this app was compiled against.
    // That is the normal case here, not a hypothetical: the Tahoe machines run the
    // 10.3 runtime while the build links 10.0 headers, so a switcher can legitimately
    // report a standard the generated table has no name for. Probe just past the
    // highest known value and offer anything found as an unlabelled mode.
    uint32_t highestKnown = 0;
    for (size_t index = 0; index < kATEMVideoModeTableCount; ++index)
        highestKnown = MAX(highestKnown, (uint32_t)kATEMVideoModeTable[index].mode);

    // Only meaningful while BMDSwitcherVideoMode stays a small sequential enum. If a
    // future SDK moves to FourCC-style values the range cannot contain anything, so
    // skip it rather than burning several hundred pointless capability queries.
    if (highestKnown < kATEMVideoModeProbeCeiling) {
        uint32_t limit = MIN(highestKnown + kATEMVideoModeProbeHeadroom, kATEMVideoModeProbeCeiling);
        for (uint32_t raw = 0; raw <= limit; ++raw) {
            if ([listed containsObject:@(raw)])
                continue;
            bool supported = false;
            if (FAILED(_switcher->DoesSupportVideoMode((BMDSwitcherVideoMode)raw, &supported)) || !supported)
                continue;
            [options addObject:[ATEMVideoModeOption optionWithRawMode:raw
                                                               format:[NSString stringWithFormat:@"Mode %u", raw]
                                                            frameRate:@""]];
        }
    }

    _supportedVideoModes = [options copy];
}

- (BOOL)configureConnectedSwitcherLocked
{
    CFStringRef productName = nullptr;
    if (SUCCEEDED(_switcher->GetProductName(&productName)))
        _productName = StringFromOwnedCFString(productName);
    else
        _productName = @"ATEM Switcher";

    [self refreshSupportedVideoModesLocked];

    IBMDSwitcherMixEffectBlockIterator *meIterator = nullptr;
    if (FAILED(_switcher->CreateIterator(IID_IBMDSwitcherMixEffectBlockIterator, (void **)&meIterator)) || !meIterator)
        return NO;
    HRESULT nextResult = meIterator->Next(&_mixEffectBlock);
    meIterator->Release();
    if (nextResult != S_OK || !_mixEffectBlock)
        return NO;
    _mixEffectBlock->AddCallback(_mixEffectBlockMonitor);

    _mixEffectBlock->QueryInterface(IID_IBMDSwitcherTransitionParameters, (void **)&_transitionParameters);
    _mixEffectBlock->QueryInterface(IID_IBMDSwitcherTransitionMixParameters, (void **)&_mixParameters);
    _mixEffectBlock->QueryInterface(IID_IBMDSwitcherTransitionDipParameters, (void **)&_dipParameters);
    _mixEffectBlock->QueryInterface(IID_IBMDSwitcherTransitionWipeParameters, (void **)&_wipeParameters);
    _mixEffectBlock->QueryInterface(IID_IBMDSwitcherTransitionDVEParameters, (void **)&_dveParameters);
    _mixEffectBlock->QueryInterface(IID_IBMDSwitcherTransitionStingerParameters, (void **)&_stingerParameters);

    BMDSwitcherInputAvailability meAvailability = bmdSwitcherInputAvailabilityMixEffectBlock0;
    _mixEffectBlock->GetInputAvailabilityMask(&meAvailability);
    _mixEffectInputAvailabilityMask = (uint32_t)meAvailability;
    NSMutableArray<ATEMInputState *> *inputs = [NSMutableArray array];
    NSMutableArray<ATEMLabelTargetState *> *labelTargets = [NSMutableArray array];
    NSMutableDictionary<NSNumber *, NSString *> *inputNames = [NSMutableDictionary dictionary];
    IBMDSwitcherInputIterator *inputIterator = nullptr;
    if (SUCCEEDED(_switcher->CreateIterator(IID_IBMDSwitcherInputIterator, (void **)&inputIterator)) && inputIterator) {
        IBMDSwitcherInput *input = nullptr;
        while (inputIterator->Next(&input) == S_OK && input) {
            BMDSwitcherInputId inputID = 0;
            BMDSwitcherInputAvailability availability = (BMDSwitcherInputAvailability)0;
            BMDSwitcherPortType portType = bmdSwitcherPortTypeExternal;
            CFStringRef longName = nullptr;
            CFStringRef shortName = nullptr;
            input->GetInputId(&inputID);
            input->GetInputAvailability(&availability);
            input->GetPortType(&portType);
            input->GetLongName(&longName);
            input->GetShortName(&shortName);
            NSString *longValue = StringFromOwnedCFString(longName);
            NSString *shortValue = StringFromOwnedCFString(shortName);
            NSString *displayName = longValue.length
                ? longValue
                : (shortValue.length ? shortValue : [NSString stringWithFormat:@"Input %lld", inputID]);
            NSString *shortDisplayName = shortValue.length ? shortValue : displayName;
            inputNames[@(inputID)] = displayName;
            [labelTargets addObject:[ATEMLabelTargetState targetWithInputID:inputID
                                                                   longName:displayName
                                                                  shortName:shortDisplayName
                                                                   typeName:PortTypeName(portType)
                                                                     output:IsOutputPortType(portType)]];

            InputAPIRecord inputRecord;
            inputRecord.inputID = inputID;
            inputRecord.portType = portType;
            inputRecord.api = input;
            _inputAPIs.push_back(inputRecord);

            if (portType != bmdSwitcherPortTypeAuxOutput &&
                portType != bmdSwitcherPortTypeMultiview &&
                (uint32_t)availability != 0) {
                [inputs addObject:[[ATEMInputState alloc] initWithID:inputID
                                                          longName:longValue.length ? longValue : [NSString stringWithFormat:@"Input %lld", inputID]
                                                         shortName:shortValue.length ? shortValue : longValue
                                                  availabilityMask:(uint32_t)availability]];
            }

            if (portType == bmdSwitcherPortTypeColorGenerator) {
                IBMDSwitcherInputColor *colorGenerator = nullptr;
                if (SUCCEEDED(input->QueryInterface(IID_IBMDSwitcherInputColor, (void **)&colorGenerator)) &&
                    colorGenerator) {
                    ColorGeneratorAPIRecord record;
                    record.inputID = inputID;
                    record.api = colorGenerator;
                    record.name = displayName;
                    _colorGeneratorAPIs.push_back(record);
                }
            }

            if (portType == bmdSwitcherPortTypeAuxOutput) {
                IBMDSwitcherInputAux *aux = nullptr;
                if (SUCCEEDED(input->QueryInterface(IID_IBMDSwitcherInputAux, (void **)&aux)) && aux) {
                    AuxAPIRecord record;
                    record.inputID = inputID;
                    record.api = aux;
                    record.name = longValue.length ? longValue : [NSString stringWithFormat:@"Aux %lu", (unsigned long)_auxAPIs.size() + 1];
                    BMDSwitcherInputAvailability auxAvailability = (BMDSwitcherInputAvailability)0;
                    aux->GetInputAvailabilityMask(&auxAvailability);
                    record.inputAvailabilityMask = (uint32_t)auxAvailability;
                    _auxAPIs.push_back(record);
                }
            }
            input = nullptr;
        }
        inputIterator->Release();
    }
    _inputStates = [inputs copy];
    _labelStates = [labelTargets copy];
    _inputNamesByID = [inputNames copy];
    _pendingColorGenerators.resize(_colorGeneratorAPIs.size());

    IBMDSwitcherKeyIterator *keyIterator = nullptr;
    if (SUCCEEDED(_mixEffectBlock->CreateIterator(IID_IBMDSwitcherKeyIterator, (void **)&keyIterator)) && keyIterator) {
        IBMDSwitcherKey *key = nullptr;
        while (keyIterator->Next(&key) == S_OK && key) {
            _upstreamKeyAPIs.push_back(key);
            key = nullptr;
        }
        keyIterator->Release();
    }

    IBMDSwitcherDownstreamKeyIterator *dskIterator = nullptr;
    if (SUCCEEDED(_switcher->CreateIterator(IID_IBMDSwitcherDownstreamKeyIterator, (void **)&dskIterator)) && dskIterator) {
        IBMDSwitcherDownstreamKey *dsk = nullptr;
        while (dskIterator->Next(&dsk) == S_OK && dsk) {
            _downstreamKeyAPIs.push_back(dsk);
            dsk = nullptr;
        }
        dskIterator->Release();
    }

    IBMDSwitcherMultiViewIterator *multiviewIterator = nullptr;
    if (SUCCEEDED(_switcher->CreateIterator(IID_IBMDSwitcherMultiViewIterator, (void **)&multiviewIterator)) && multiviewIterator) {
        IBMDSwitcherMultiView *multiview = nullptr;
        while (multiviewIterator->Next(&multiview) == S_OK && multiview) {
            _multiviewAPIs.push_back(multiview);
            multiview = nullptr;
        }
        multiviewIterator->Release();
    }
    _pendingMultiviews.resize(_multiviewAPIs.size());

    if (SUCCEEDED(_switcher->QueryInterface(IID_IBMDSwitcherFairlightAudioMixer,
                                             (void **)&_fairlightMixer)) &&
        _fairlightMixer) {
        _fairlightMixer->AddCallback(_fairlightMixerMonitor);
        _fairlightMixer->SetAllLevelNotificationsEnabled(true);

        IBMDSwitcherFairlightAudioInputIterator *audioInputIterator = nullptr;
        if (SUCCEEDED(_fairlightMixer->CreateIterator(IID_IBMDSwitcherFairlightAudioInputIterator,
                                                       (void **)&audioInputIterator)) &&
            audioInputIterator) {
            IBMDSwitcherFairlightAudioInput *audioInput = nullptr;
            while (audioInputIterator->Next(&audioInput) == S_OK && audioInput) {
                BMDSwitcherAudioInputId inputID = 0;
                audioInput->GetId(&inputID);
                IBMDSwitcherFairlightAudioSourceIterator *sourceIterator = nullptr;
                if (SUCCEEDED(audioInput->CreateIterator(IID_IBMDSwitcherFairlightAudioSourceIterator,
                                                          (void **)&sourceIterator)) &&
                    sourceIterator) {
                    IBMDSwitcherFairlightAudioSource *source = nullptr;
                    NSUInteger sourceNumber = 0;
                    while (sourceIterator->Next(&source) == S_OK && source) {
                        BMDSwitcherFairlightAudioSourceId sourceID = 0;
                        source->GetId(&sourceID);
                        FairlightSourceAPIRecord record;
                        record.inputID = inputID;
                        record.sourceID = sourceID;
                        record.api = source;
                        record.monitor = new FairlightSourceMonitor(self, inputID, sourceID);
                        NSString *baseName = _inputNamesByID[@(inputID)] ?: InputNameForID(_inputStates, inputID);
                        record.name = sourceNumber == 0
                            ? baseName
                            : [NSString stringWithFormat:@"%@ %lu", baseName, (unsigned long)sourceNumber + 1];
                        source->AddCallback(record.monitor);
                        _fairlightSources.push_back(record);
                        ++sourceNumber;
                        source = nullptr;
                    }
                    sourceIterator->Release();
                }
                audioInput->Release();
                audioInput = nullptr;
            }
            audioInputIterator->Release();
        }
    }

    IBMDSwitcherHyperDeckIterator *hyperDeckIterator = nullptr;
    if (SUCCEEDED(_switcher->CreateIterator(IID_IBMDSwitcherHyperDeckIterator,
                                             (void **)&hyperDeckIterator)) &&
        hyperDeckIterator) {
        IBMDSwitcherHyperDeck *hyperDeck = nullptr;
        while (hyperDeckIterator->Next(&hyperDeck) == S_OK && hyperDeck) {
            _hyperDeckAPIs.push_back(hyperDeck);
            hyperDeck = nullptr;
        }
        hyperDeckIterator->Release();
    }

    return YES;
}

- (void)disconnect
{
    dispatch_async(_controlQueue, ^{
        [self disconnectLockedWithMessage:@"Disconnected."];
        [self publishStateLocked];
    });
}

- (void)disconnectLockedWithMessage:(NSString *)message
{
    _connecting = NO;
    _demo = NO;
    _targetAddressLocked = @"";
    _demoMultiviews.clear();
    _demoColorGenerators.clear();
    _demoAudioChannels.clear();
    _demoHyperDecks.clear();
    _pendingMultiviews.clear();
    _lastKnownMultiviews = @[];

    for (IBMDSwitcherHyperDeck *hyperDeck : _hyperDeckAPIs)
        hyperDeck->Release();
    _hyperDeckAPIs.clear();
    [_hyperDeckClipCache removeAllObjects];
    [_hyperDeckClipCacheTimes removeAllObjects];
    [_hyperDeckClipCacheCounts removeAllObjects];

    for (FairlightSourceAPIRecord &record : _fairlightSources) {
        if (record.api && record.monitor)
            record.api->RemoveCallback(record.monitor);
        if (record.api)
            record.api->Release();
        if (record.monitor)
            record.monitor->Release();
        record.api = nullptr;
        record.monitor = nullptr;
        record.name = nil;
    }
    _fairlightSources.clear();
    _masterAudioLevels.clear();
    _masterAudioPeaks.clear();
    if (_fairlightMixer) {
        _fairlightMixer->SetAllLevelNotificationsEnabled(false);
        _fairlightMixer->RemoveCallback(_fairlightMixerMonitor);
        _fairlightMixer->Release();
        _fairlightMixer = nullptr;
    }

    for (IBMDSwitcherMultiView *multiview : _multiviewAPIs)
        multiview->Release();
    _multiviewAPIs.clear();

    for (ColorGeneratorAPIRecord &record : _colorGeneratorAPIs) {
        if (record.api)
            record.api->Release();
        record.api = nullptr;
        record.name = nil;
    }
    _colorGeneratorAPIs.clear();
    _pendingColorGenerators.clear();

    for (AuxAPIRecord &record : _auxAPIs) {
        if (record.api)
            record.api->Release();
        record.api = nullptr;
        record.name = nil;
        record.inputAvailabilityMask = 0;
    }
    _auxAPIs.clear();

    for (InputAPIRecord &record : _inputAPIs) {
        if (record.api)
            record.api->Release();
        record.api = nullptr;
    }
    _inputAPIs.clear();

    for (IBMDSwitcherKey *key : _upstreamKeyAPIs)
        key->Release();
    _upstreamKeyAPIs.clear();
    for (IBMDSwitcherDownstreamKey *dsk : _downstreamKeyAPIs)
        dsk->Release();
    _downstreamKeyAPIs.clear();

    if (_transitionParameters) { _transitionParameters->Release(); _transitionParameters = nullptr; }
    if (_mixParameters) { _mixParameters->Release(); _mixParameters = nullptr; }
    if (_dipParameters) { _dipParameters->Release(); _dipParameters = nullptr; }
    if (_wipeParameters) { _wipeParameters->Release(); _wipeParameters = nullptr; }
    if (_dveParameters) { _dveParameters->Release(); _dveParameters = nullptr; }
    if (_stingerParameters) { _stingerParameters->Release(); _stingerParameters = nullptr; }
    if (_mixEffectBlock) {
        _mixEffectBlock->RemoveCallback(_mixEffectBlockMonitor);
        _mixEffectBlock->Release();
        _mixEffectBlock = nullptr;
    }
    if (_switcher) {
        _switcher->RemoveCallback(_switcherMonitor);
        _switcher->Release();
        _switcher = nullptr;
    }

    _productName = @"";
    _inputStates = @[];
    _labelStates = @[];
    _inputNamesByID = @{};
    _mixEffectInputAvailabilityMask = 0;
    _supportedVideoModes = @[];
    if (message.length)
        _statusMessage = message;
    [self publishFeatureStatesLocked];
}

- (void)sdkStateChanged
{
    dispatch_async(_controlQueue, ^{
        if (self->_switcher)
            [self publishStateLocked];
    });
}

- (void)sdkAudioStateChanged
{
    // Fairlight can emit a burst of property callbacks while a fader moves. The
    // feature timer coalesces those changes into a bounded 10 Hz UI refresh.
}

- (void)audioMasterLevelsChanged:(const double *)levels
                           count:(uint32_t)count
                      peakLevels:(const double *)peakLevels
                       peakCount:(uint32_t)peakCount
{
    std::vector<double> levelCopy;
    std::vector<double> peakCopy;
    if (levels && count)
        levelCopy.assign(levels, levels + count);
    if (peakLevels && peakCount)
        peakCopy.assign(peakLevels, peakLevels + peakCount);
    dispatch_async(_controlQueue, ^{
        if (!self->_fairlightMixer)
            return;
        self->_masterAudioLevels = levelCopy;
        self->_masterAudioPeaks = peakCopy;
    });
}

- (void)audioInput:(int64_t)inputID
             source:(int64_t)sourceID
      levelsChanged:(const double *)levels
              count:(uint32_t)count
         peakLevels:(const double *)peakLevels
          peakCount:(uint32_t)peakCount
{
    std::vector<double> levelCopy;
    std::vector<double> peakCopy;
    if (levels && count)
        levelCopy.assign(levels, levels + count);
    if (peakLevels && peakCount)
        peakCopy.assign(peakLevels, peakLevels + peakCount);
    dispatch_async(_controlQueue, ^{
        for (FairlightSourceAPIRecord &record : self->_fairlightSources) {
            if (record.inputID != inputID || record.sourceID != sourceID)
                continue;
            record.levels = levelCopy;
            record.peaks = peakCopy;
            break;
        }
    });
}

- (void)switcherDisconnectedByDevice
{
    dispatch_async(_controlQueue, ^{
        [self disconnectLockedWithMessage:@"The switcher disconnected."];
        [self publishStateLocked];
    });
}

- (void)enterDemoMode
{
    dispatch_async(_controlQueue, ^{
        [self disconnectLockedWithMessage:@""];
        self->_demo = YES;
        self->_targetAddressLocked = @"demo";
        self->_productName = @"ATEM Mini Extreme — Demo";
        self->_statusMessage = @"Demo mode: controls are simulated and no hardware commands are sent.";
        NSArray<NSString *> *names = @[@"Camera 1", @"Camera 2", @"Camera 3", @"Camera 4",
                                        @"Camera 5", @"Camera 6", @"Camera 7", @"Camera 8",
                                        @"Black", @"Color 1", @"Color 2", @"Media Player 1", @"Media Player 2"];
        NSMutableArray<ATEMInputState *> *inputs = [NSMutableArray array];
        [names enumerateObjectsUsingBlock:^(NSString *name, NSUInteger index, BOOL *stop) {
            (void)stop;
            int64_t inputID = (int64_t)index + 1;
            [inputs addObject:[[ATEMInputState alloc] initWithID:inputID
                                                       longName:name
                                                      shortName:name
                                               availabilityMask:0xFFFFFFFFU]];
        }];
        self->_inputStates = [inputs copy];
        NSMutableDictionary<NSNumber *, NSString *> *inputNames = [NSMutableDictionary dictionary];
        for (ATEMInputState *input in self->_inputStates)
            inputNames[@(input.inputID)] = input.longName;
        self->_inputNamesByID = [inputNames copy];
        NSMutableArray<ATEMLabelTargetState *> *labelTargets = [NSMutableArray array];
        for (ATEMInputState *input in self->_inputStates) {
            [labelTargets addObject:[ATEMLabelTargetState targetWithInputID:input.inputID
                                                                   longName:input.longName
                                                                  shortName:input.shortName
                                                                   typeName:@"Camera / Input"
                                                                     output:NO]];
        }
        for (NSUInteger index = 0; index < 2; ++index) {
            NSString *name = [NSString stringWithFormat:@"Aux %lu", (unsigned long)index + 1];
            [labelTargets addObject:[ATEMLabelTargetState targetWithInputID:kDemoAuxLabelBase + (int64_t)index
                                                                   longName:name
                                                                  shortName:[NSString stringWithFormat:@"A%lu", (unsigned long)index + 1]
                                                                   typeName:@"Aux Output"
                                                                     output:YES]];
        }
        for (NSUInteger index = 0; index < 2; ++index) {
            NSString *name = [NSString stringWithFormat:@"Multiview %lu", (unsigned long)index + 1];
            [labelTargets addObject:[ATEMLabelTargetState targetWithInputID:kDemoMultiviewLabelBase + (int64_t)index
                                                                   longName:name
                                                                  shortName:[NSString stringWithFormat:@"MV%lu", (unsigned long)index + 1]
                                                                   typeName:@"Multiview Output"
                                                                     output:YES]];
        }
        self->_labelStates = [labelTargets copy];
        self->_mixEffectInputAvailabilityMask = 0xFFFFFFFFU;
        self->_demoProgram = 1;
        self->_demoPreview = 2;
        self->_demoTransitionPosition = 0;
        self->_demoInTransition = NO;
        self->_demoStyle = ATEMTransitionStyleMix;
        self->_demoSelection = ATEMTransitionSelectionBackground;
        self->_demoRate = 25;
        self->_demoVideoMode = ATEMDefaultDemoVideoMode();
        self->_demoFTB = NO;
        self->_demoKeys = std::vector<bool>(4, false);
        self->_demoDSKOnAir = std::vector<bool>(2, false);
        self->_demoDSKTied = std::vector<bool>(2, false);
        self->_demoAuxSources = std::vector<int64_t>(2, 1);
        self->_demoColorGenerators.clear();
        {
            // Input IDs 10 and 11 are "Color 1" and "Color 2" in the demo input list above.
            DemoColorGenerator colorOne;
            colorOne.inputID = 10;
            colorOne.name = @"Color 1";
            colorOne.hue = 0.0;
            colorOne.saturation = 0.0;
            colorOne.luma = 0.5;  // neutral 50% gray
            self->_demoColorGenerators.push_back(colorOne);
            DemoColorGenerator colorTwo;
            colorTwo.inputID = 11;
            colorTwo.name = @"Color 2";
            colorTwo.hue = 205.0;
            colorTwo.saturation = 0.82;
            colorTwo.luma = 0.46;
            self->_demoColorGenerators.push_back(colorTwo);
        }
        self->_demoMultiviews.clear();
        for (NSUInteger multiviewIndex = 0; multiviewIndex < 2; ++multiviewIndex) {
            DemoMultiview multiview;
            multiview.layout = multiviewIndex == 0 ? ATEMMultiviewLayoutProgramTop : ATEMMultiviewLayoutProgramBottom;
            for (NSUInteger window = 0; window < 16; ++window) {
                multiview.sources.push_back((int64_t)((window + multiviewIndex * 4) % names.count) + 1);
                multiview.vuMeters.push_back(window < 8);
                multiview.safeAreas.push_back(false);
                multiview.labels.push_back(true);
                multiview.borders.push_back(true);
            }
            self->_demoMultiviews.push_back(multiview);
        }
        self->_demoMasterAudioFader = 0;
        self->_demoAudioChannels.clear();
        for (NSUInteger index = 0; index < 8; ++index) {
            DemoAudioChannel channel;
            channel.inputID = (int64_t)index + 1;
            // Fairlight source IDs are scoped to their input and commonly repeat.
            channel.sourceID = 0;
            channel.faderGain = index == 0 ? 0 : -3.0 - (double)index;
            channel.pan = 0;
            channel.mixOption = index < 4
                ? ATEMAudioMixOptionAudioFollowVideo
                : ATEMAudioMixOptionOn;
            self->_demoAudioChannels.push_back(channel);
        }
        self->_demoHyperDecks.clear();
        DemoHyperDeck deckOne;
        deckOne.deckID = 1;
        deckOne.address = @"192.168.10.50";
        deckOne.switcherInputID = 7;
        deckOne.connectionStatus = ATEMHyperDeckConnectionStatusConnected;
        deckOne.playerState = ATEMHyperDeckPlayerStateIdle;
        deckOne.currentClip = 10;
        deckOne.autoRollOnTake = true;
        deckOne.autoRollFrameDelay = 12;
        self->_demoHyperDecks.push_back(deckOne);
        DemoHyperDeck deckTwo;
        deckTwo.deckID = 2;
        deckTwo.address = @"";
        deckTwo.switcherInputID = 8;
        self->_demoHyperDecks.push_back(deckTwo);
        [self publishStateLocked];
    });
}

- (void)publishStateLocked
{
    ATEMState *state = [[ATEMState alloc] init];
    state.connected = (_switcher != nullptr) || _demo;
    state.connecting = _connecting;
    state.demo = _demo;
    state.productName = _productName ?: @"";
    state.statusMessage = _statusMessage ?: @"";
    state.inputs = _inputStates ?: @[];
    state.labelTargets = _labelStates ?: @[];
    state.mixEffectInputAvailabilityMask = _mixEffectInputAvailabilityMask;
    state.programInputID = -1;
    state.previewInputID = -1;
    state.transitionPosition = 0;
    state.transitionFramesRemaining = 0;
    state.inTransition = NO;
    state.nextTransitionStyle = ATEMTransitionStyleMix;
    state.nextTransitionSelection = ATEMTransitionSelectionBackground;
    state.transitionRate = 25;
    state.fadeToBlack = NO;
    state.fadeToBlackTransitioning = NO;
    state.fadeToBlackFramesRemaining = 0;
    state.videoMode = 0;
    state.supportedVideoModes = @[];
    state.canChangeVideoMode = NO;

    NSMutableArray<ATEMKeyState *> *keys = [NSMutableArray array];
    NSMutableArray<ATEMDownstreamKeyState *> *dsks = [NSMutableArray array];
    NSMutableArray<ATEMAuxState *> *auxes = [NSMutableArray array];
    NSMutableArray<ATEMMultiviewState *> *multiviews = [NSMutableArray array];
    NSMutableArray<ATEMColorGeneratorState *> *colorGenerators = [NSMutableArray array];

    if (_demo) {
        state.programInputID = _demoProgram;
        state.previewInputID = _demoPreview;
        state.transitionPosition = _demoTransitionPosition;
        state.inTransition = _demoInTransition;
        state.nextTransitionStyle = _demoStyle;
        state.nextTransitionSelection = _demoSelection;
        state.transitionRate = _demoRate;
        state.fadeToBlack = _demoFTB;
        state.videoMode = _demoVideoMode;
        state.supportedVideoModes = ATEMAllKnownVideoModes();
        state.canChangeVideoMode = YES;
        for (NSUInteger index = 0; index < _demoKeys.size(); ++index)
            [keys addObject:[[ATEMKeyState alloc] initWithIndex:index onAir:_demoKeys[index]]];
        for (NSUInteger index = 0; index < _demoDSKOnAir.size(); ++index) {
            [dsks addObject:[[ATEMDownstreamKeyState alloc] initWithIndex:index
                                                                   onAir:_demoDSKOnAir[index]
                                                                    tied:_demoDSKTied[index]
                                                           transitioning:NO
                                                         framesRemaining:0]];
        }
        for (NSUInteger index = 0; index < _demoAuxSources.size(); ++index) {
            [auxes addObject:[[ATEMAuxState alloc] initWithIndex:index
                                                           name:LabelLongNameForID(_labelStates,
                                                                                 kDemoAuxLabelBase + (int64_t)index,
                                                                                 [NSString stringWithFormat:@"Aux %lu", (unsigned long)index + 1])
                                                       sourceID:_demoAuxSources[index]
                                          inputAvailabilityMask:0xFFFFFFFFU]];
        }
        for (NSUInteger index = 0; index < _demoColorGenerators.size(); ++index) {
            const DemoColorGenerator &demoColor = _demoColorGenerators[index];
            ATEMColorGeneratorState *generator = [[ATEMColorGeneratorState alloc] init];
            generator.index = index;
            generator.inputID = demoColor.inputID;
            generator.name = LabelLongNameForID(_labelStates, demoColor.inputID, demoColor.name);
            generator.hue = demoColor.hue;
            generator.saturation = demoColor.saturation;
            generator.luma = demoColor.luma;
            [colorGenerators addObject:generator];
        }
        for (NSUInteger index = 0; index < _demoMultiviews.size(); ++index) {
            const DemoMultiview &demoMultiview = _demoMultiviews[index];
            ATEMMultiviewState *multiview = [[ATEMMultiviewState alloc] init];
            multiview.index = index;
            multiview.layout = demoMultiview.layout;
            multiview.canChangeLayout = YES;
            multiview.supportsQuadrantLayout = YES;
            multiview.canRouteInputs = YES;
            multiview.inputAvailabilityMask = 0xFFFFFFFFU;
            multiview.supportsVUMeters = YES;
            multiview.canAdjustVUMeterOpacity = YES;
            multiview.vuMeterOpacity = demoMultiview.vuMeterOpacity;
            multiview.canToggleSafeArea = YES;
            multiview.supportedSafeAreaTypes = 0x00000003U;
            multiview.supportsProgramPreviewSwap = YES;
            multiview.programPreviewSwapped = demoMultiview.programPreviewSwapped;
            multiview.canChangeOverlayProperties = YES;
            multiview.totalWindowCount = demoMultiview.sources.size();
            NSMutableArray<ATEMMultiviewWindowState *> *windows = [NSMutableArray array];
            std::vector<uint32_t> visibleWindowIndices =
                VisibleQuadrantWindowIndices(demoMultiview.layout);
            for (uint32_t windowIndex : visibleWindowIndices) {
                ATEMMultiviewWindowState *window = [[ATEMMultiviewWindowState alloc] init];
                window.index = windowIndex;
                window.sourceID = demoMultiview.sources[windowIndex];
                window.canRouteInput = YES;
                window.supportsVUMeter = YES;
                window.vuMeterEnabled = demoMultiview.vuMeters[windowIndex];
                window.supportsSafeArea = YES;
                window.safeAreaEnabled = demoMultiview.safeAreas[windowIndex];
                window.safeAreaType = 0x00000001U;
                window.supportsLabelOverlay = YES;
                window.labelVisible = demoMultiview.labels[windowIndex];
                window.borderVisible = demoMultiview.borders[windowIndex];
                [windows addObject:window];
            }
            multiview.windows = windows;
            [multiviews addObject:multiview];
        }
    } else if (_mixEffectBlock) {
        BMDSwitcherInputId programID = -1;
        BMDSwitcherInputId previewID = -1;
        double position = 0;
        uint32_t frames = 0;
        bool boolValue = false;
        _mixEffectBlock->GetProgramInput(&programID);
        _mixEffectBlock->GetPreviewInput(&previewID);
        _mixEffectBlock->GetTransitionPosition(&position);
        _mixEffectBlock->GetTransitionFramesRemaining(&frames);
        _mixEffectBlock->GetInTransition(&boolValue);
        state.programInputID = programID;
        state.previewInputID = previewID;
        state.transitionPosition = position;
        state.transitionFramesRemaining = frames;
        state.inTransition = boolValue;

        boolValue = false;
        _mixEffectBlock->GetFadeToBlackFullyBlack(&boolValue);
        state.fadeToBlack = boolValue;
        boolValue = false;
        _mixEffectBlock->GetFadeToBlackInTransition(&boolValue);
        state.fadeToBlackTransitioning = boolValue;
        _mixEffectBlock->GetFadeToBlackFramesRemaining(&frames);
        state.fadeToBlackFramesRemaining = frames;

        BMDSwitcherTransitionStyle style = bmdSwitcherTransitionStyleMix;
        BMDSwitcherTransitionSelection selection = bmdSwitcherTransitionSelectionBackground;
        if (_transitionParameters) {
            _transitionParameters->GetNextTransitionStyle(&style);
            _transitionParameters->GetNextTransitionSelection(&selection);
        }
        state.nextTransitionStyle = AppTransitionStyle(style);
        state.nextTransitionSelection = AppTransitionSelection(selection);

        uint32_t rate = 25;
        switch (style) {
            case bmdSwitcherTransitionStyleDip:
                if (_dipParameters) _dipParameters->GetRate(&rate);
                break;
            case bmdSwitcherTransitionStyleWipe:
                if (_wipeParameters) _wipeParameters->GetRate(&rate);
                break;
            case bmdSwitcherTransitionStyleDVE:
                if (_dveParameters) _dveParameters->GetRate(&rate);
                break;
            case bmdSwitcherTransitionStyleStinger:
                if (_stingerParameters) _stingerParameters->GetMixRate(&rate);
                break;
            case bmdSwitcherTransitionStyleMix:
            default:
                if (_mixParameters) _mixParameters->GetRate(&rate);
                break;
        }
        state.transitionRate = rate;

        BMDSwitcherVideoMode currentVideoMode = (BMDSwitcherVideoMode)0;
        if (_switcher && SUCCEEDED(_switcher->GetVideoMode(&currentVideoMode)))
            state.videoMode = (uint32_t)currentVideoMode;
        state.supportedVideoModes = _supportedVideoModes ?: @[];
        state.canChangeVideoMode = state.supportedVideoModes.count > 1;

        for (NSUInteger index = 0; index < _upstreamKeyAPIs.size(); ++index) {
            bool onAir = false;
            _upstreamKeyAPIs[index]->GetOnAir(&onAir);
            [keys addObject:[[ATEMKeyState alloc] initWithIndex:index onAir:onAir]];
        }
        for (NSUInteger index = 0; index < _downstreamKeyAPIs.size(); ++index) {
            bool onAir = false;
            bool tied = false;
            bool transitioning = false;
            uint32_t remaining = 0;
            _downstreamKeyAPIs[index]->GetOnAir(&onAir);
            _downstreamKeyAPIs[index]->GetTie(&tied);
            _downstreamKeyAPIs[index]->IsTransitioning(&transitioning);
            _downstreamKeyAPIs[index]->GetFramesRemaining(&remaining);
            [dsks addObject:[[ATEMDownstreamKeyState alloc] initWithIndex:index
                                                                   onAir:onAir
                                                                    tied:tied
                                                           transitioning:transitioning
                                                         framesRemaining:remaining]];
        }
        for (NSUInteger index = 0; index < _auxAPIs.size(); ++index) {
            BMDSwitcherInputId sourceID = -1;
            _auxAPIs[index].api->GetInputSource(&sourceID);
            [auxes addObject:[[ATEMAuxState alloc] initWithIndex:index
                                                           name:_auxAPIs[index].name ?: [NSString stringWithFormat:@"Aux %lu", (unsigned long)index + 1]
                                                       sourceID:sourceID
                                          inputAvailabilityMask:_auxAPIs[index].inputAvailabilityMask]];
        }
        if (_pendingColorGenerators.size() < _colorGeneratorAPIs.size())
            _pendingColorGenerators.resize(_colorGeneratorAPIs.size());
        for (NSUInteger index = 0; index < _colorGeneratorAPIs.size(); ++index) {
            ColorGeneratorAPIRecord &record = _colorGeneratorAPIs[index];
            PendingColorGenerator &pending = _pendingColorGenerators[index];
            ATEMColorGeneratorState *generator = [[ATEMColorGeneratorState alloc] init];
            generator.index = index;
            generator.inputID = record.inputID;
            generator.name = _inputNamesByID[@(record.inputID)] ?: record.name
                ?: [NSString stringWithFormat:@"Color %lu", (unsigned long)index + 1];

            double hue = 0, saturation = 0, luma = 0;
            HRESULT hueResult = record.api->GetHue(&hue);
            HRESULT saturationResult = record.api->GetSaturation(&saturation);
            HRESULT lumaResult = record.api->GetLuma(&luma);
            // Hue is reported in degrees, so it needs a wider acknowledgement
            // tolerance than the 0...1 parameters.
            ReconcilePendingDouble(pending.hue, hueResult, &hue, 0.1);
            ReconcilePendingDouble(pending.saturation, saturationResult, &saturation);
            ReconcilePendingDouble(pending.luma, lumaResult, &luma);
            generator.hue = ATEMWrapDegrees(hue);
            generator.saturation = ATEMClamp01(saturation);
            generator.luma = ATEMClamp01(luma);
            [colorGenerators addObject:generator];
        }
        if (_pendingMultiviews.size() < _multiviewAPIs.size())
            _pendingMultiviews.resize(_multiviewAPIs.size());
        for (NSUInteger index = 0; index < _multiviewAPIs.size(); ++index) {
            IBMDSwitcherMultiView *api = _multiviewAPIs[index];
            PendingMultiview &pending = _pendingMultiviews[index];
            ATEMMultiviewState *previous = index < _lastKnownMultiviews.count ? _lastKnownMultiviews[index] : nil;
            ATEMMultiviewState *multiview = [[ATEMMultiviewState alloc] init];
            multiview.index = index;

            bool boolValue = false;
            multiview.canChangeLayout = SUCCEEDED(api->CanChangeLayout(&boolValue))
                ? boolValue : (previous ? previous.canChangeLayout : NO);
            ATEMMultiviewLayout appLayout = previous ? previous.layout : ATEMMultiviewLayoutProgramTop;
            BMDSwitcherMultiViewLayout layout = (BMDSwitcherMultiViewLayout)appLayout;
            HRESULT layoutResult = api->GetLayout(&layout);
            if (SUCCEEDED(layoutResult))
                appLayout = (ATEMMultiviewLayout)layout;
            ReconcilePendingValue(pending.layout, layoutResult, &appLayout);
            multiview.layout = appLayout;
            boolValue = false;
            multiview.supportsQuadrantLayout = SUCCEEDED(api->SupportsQuadrantLayout(&boolValue))
                ? boolValue : (previous ? previous.supportsQuadrantLayout : NO);
            boolValue = false;
            multiview.canRouteInputs = SUCCEEDED(api->CanRouteInputs(&boolValue))
                ? boolValue : (previous ? previous.canRouteInputs : NO);
            BMDSwitcherInputAvailability availability = (BMDSwitcherInputAvailability)(previous ? previous.inputAvailabilityMask : 0);
            HRESULT availabilityResult = api->GetInputAvailabilityMask(&availability);
            multiview.inputAvailabilityMask = SUCCEEDED(availabilityResult)
                ? (uint32_t)availability : (previous ? previous.inputAvailabilityMask : 0);
            boolValue = false;
            multiview.supportsVUMeters = SUCCEEDED(api->SupportsVuMeters(&boolValue))
                ? boolValue : (previous ? previous.supportsVUMeters : NO);
            boolValue = false;
            multiview.canAdjustVUMeterOpacity = SUCCEEDED(api->CanAdjustVuMeterOpacity(&boolValue))
                ? boolValue : (previous ? previous.canAdjustVUMeterOpacity : NO);
            double previousOpacity = previous ? previous.vuMeterOpacity : 1.0;
            double opacity = previousOpacity;
            HRESULT opacityResult = api->GetVuMeterOpacity(&opacity);
            if (FAILED(opacityResult))
                opacity = previousOpacity;
            ReconcilePendingDouble(pending.vuMeterOpacity, opacityResult, &opacity);
            multiview.vuMeterOpacity = opacity;
            boolValue = false;
            multiview.canToggleSafeArea = SUCCEEDED(api->CanToggleSafeAreaEnabled(&boolValue))
                ? boolValue : (previous ? previous.canToggleSafeArea : NO);
            uint32_t safeAreaTypes = previous ? previous.supportedSafeAreaTypes : 0;
            HRESULT safeAreaTypesResult = api->GetSupportedSafeAreaTypes(&safeAreaTypes);
            multiview.supportedSafeAreaTypes = SUCCEEDED(safeAreaTypesResult)
                ? safeAreaTypes : (previous ? previous.supportedSafeAreaTypes : 0);
            boolValue = false;
            multiview.supportsProgramPreviewSwap = SUCCEEDED(api->SupportsProgramPreviewSwap(&boolValue))
                ? boolValue : (previous ? previous.supportsProgramPreviewSwap : NO);
            bool previousSwapped = previous ? previous.isProgramPreviewSwapped : false;
            bool swapped = previousSwapped;
            HRESULT swappedResult = api->GetProgramPreviewSwapped(&swapped);
            if (FAILED(swappedResult))
                swapped = previousSwapped;
            ReconcilePendingValue(pending.programPreviewSwapped, swappedResult, &swapped);
            multiview.programPreviewSwapped = swapped;
            boolValue = false;
            multiview.canChangeOverlayProperties = SUCCEEDED(api->CanChangeOverlayProperties(&boolValue))
                ? boolValue : (previous ? previous.canChangeOverlayProperties : NO);

            uint32_t totalWindowCount = previous ? (uint32_t)previous.totalWindowCount : 0;
            if (FAILED(api->GetWindowCount(&totalWindowCount)))
                totalWindowCount = previous ? (uint32_t)previous.totalWindowCount : 0;
            totalWindowCount =
                NormalizedMultiviewWindowCount(multiview.supportsQuadrantLayout,
                                               totalWindowCount);
            multiview.totalWindowCount = totalWindowCount;
            EnsurePendingMultiviewWindowCount(pending, totalWindowCount);

            std::vector<uint32_t> visibleWindowIndices;
            if (multiview.supportsQuadrantLayout) {
                visibleWindowIndices =
                    VisibleQuadrantWindowIndices(multiview.layout);
            } else {
                for (uint32_t index = 0; index < totalWindowCount; ++index)
                    visibleWindowIndices.push_back(index);
            }
            NSMutableArray<ATEMMultiviewWindowState *> *windows =
                [NSMutableArray arrayWithCapacity:visibleWindowIndices.size()];
            for (uint32_t windowIndex : visibleWindowIndices) {
                ATEMMultiviewWindowState *previousWindow =
                    MultiviewWindowStateForIndex(previous, windowIndex);
                ATEMMultiviewWindowState *window = [[ATEMMultiviewWindowState alloc] init];
                window.index = windowIndex;
                window.canRouteInput = multiview.canRouteInputs &&
                    CanRouteMultiviewWindow(multiview.supportsQuadrantLayout, windowIndex);
                BMDSwitcherInputId previousSourceID = previousWindow ? previousWindow.sourceID : -1;
                BMDSwitcherInputId sourceID = previousSourceID;
                HRESULT sourceResult = api->GetWindowInput(windowIndex, &sourceID);
                if (FAILED(sourceResult))
                    sourceID = previousSourceID;
                ReconcilePendingValue(pending.sources[windowIndex], sourceResult, &sourceID);
                window.sourceID = sourceID;
                boolValue = false;
                window.supportsVUMeter = SUCCEEDED(api->CurrentInputSupportsVuMeter(windowIndex, &boolValue))
                    ? boolValue : (previousWindow ? previousWindow.supportsVUMeter : NO);
                bool previousVUMeterEnabled = previousWindow ? previousWindow.isVUMeterEnabled : false;
                bool vuMeterEnabled = previousVUMeterEnabled;
                HRESULT vuMeterResult = api->GetVuMeterEnabled(windowIndex, &vuMeterEnabled);
                if (FAILED(vuMeterResult))
                    vuMeterEnabled = previousVUMeterEnabled;
                ReconcilePendingValue(pending.vuMeters[windowIndex], vuMeterResult, &vuMeterEnabled);
                window.vuMeterEnabled = vuMeterEnabled;
                boolValue = false;
                window.supportsSafeArea = SUCCEEDED(api->CurrentInputSupportsSafeArea(windowIndex, &boolValue))
                    ? boolValue : (previousWindow ? previousWindow.supportsSafeArea : NO);
                bool previousSafeAreaEnabled = previousWindow ? previousWindow.isSafeAreaEnabled : false;
                bool safeAreaEnabled = previousSafeAreaEnabled;
                HRESULT safeAreaResult = api->GetSafeAreaEnabled(windowIndex, &safeAreaEnabled);
                if (FAILED(safeAreaResult))
                    safeAreaEnabled = previousSafeAreaEnabled;
                ReconcilePendingValue(pending.safeAreas[windowIndex], safeAreaResult, &safeAreaEnabled);
                window.safeAreaEnabled = safeAreaEnabled;
                BMDSwitcherMultiViewSafeAreaType safeAreaType = (BMDSwitcherMultiViewSafeAreaType)(previousWindow ? previousWindow.safeAreaType : (uint32_t)bmdSwitcherMultiViewSafeAreaTypeAspect16x9);
                HRESULT safeAreaTypeResult = api->GetSafeAreaType(windowIndex, &safeAreaType);
                window.safeAreaType = SUCCEEDED(safeAreaTypeResult)
                    ? (uint32_t)safeAreaType : (previousWindow ? previousWindow.safeAreaType : (uint32_t)bmdSwitcherMultiViewSafeAreaTypeAspect16x9);
                boolValue = false;
                window.supportsLabelOverlay = SUCCEEDED(api->CurrentInputSupportsLabelOverlay(windowIndex, &boolValue))
                    ? boolValue : (previousWindow ? previousWindow.supportsLabelOverlay : NO);
                bool previousLabelVisible = previousWindow ? previousWindow.isLabelVisible : false;
                bool labelVisible = previousLabelVisible;
                HRESULT labelResult = api->GetLabelVisible(windowIndex, &labelVisible);
                if (FAILED(labelResult))
                    labelVisible = previousLabelVisible;
                ReconcilePendingValue(pending.labels[windowIndex], labelResult, &labelVisible);
                window.labelVisible = labelVisible;
                bool previousBorderVisible = previousWindow ? previousWindow.isBorderVisible : false;
                bool borderVisible = previousBorderVisible;
                HRESULT borderResult = api->GetBorderVisible(windowIndex, &borderVisible);
                if (FAILED(borderResult))
                    borderVisible = previousBorderVisible;
                ReconcilePendingValue(pending.borders[windowIndex], borderResult, &borderVisible);
                window.borderVisible = borderVisible;
                [windows addObject:window];
            }
            multiview.windows = windows;
            [multiviews addObject:multiview];
        }
        _lastKnownMultiviews = [multiviews copy];
    }

    state.upstreamKeys = keys;
    state.downstreamKeys = dsks;
    state.auxOutputs = auxes;
    state.multiviews = multiviews;
    state.colorGenerators = colorGenerators;

    NSString *targetAddress = [_targetAddressLocked copy] ?: @"";
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_shutdown)
            return;
        self.latestState = state;
        self.currentAddress = targetAddress;
        [[NSNotificationCenter defaultCenter] postNotificationName:ATEMStateDidChangeNotification
                                                            object:self];
        void (^handler)(ATEMState *) = self.stateHandler;
        if (handler)
            handler(state);
    });
}

- (NSArray<ATEMHyperDeckClipState *> *)clipsForHyperDeckLocked:(IBMDSwitcherHyperDeck *)api
                                                        deckID:(int64_t)deckID
                                                     clipCount:(NSUInteger)clipCount
{
    if (!api)
        return @[];

    NSNumber *cacheKey = @(deckID);
    NSArray<ATEMHyperDeckClipState *> *cachedClips = _hyperDeckClipCache[cacheKey];
    NSNumber *cachedCount = _hyperDeckClipCacheCounts[cacheKey];
    CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
    CFAbsoluteTime cachedAt = _hyperDeckClipCacheTimes[cacheKey].doubleValue;
    BOOL countMatches = cachedCount && cachedCount.unsignedIntegerValue == clipCount;
    if (cachedClips && countMatches && now - cachedAt < 2.0)
        return cachedClips;

    if (clipCount == 0) {
        NSArray<ATEMHyperDeckClipState *> *empty = @[];
        _hyperDeckClipCache[cacheKey] = empty;
        _hyperDeckClipCacheCounts[cacheKey] = @0;
        _hyperDeckClipCacheTimes[cacheKey] = @(now);
        return empty;
    }

    IBMDSwitcherHyperDeckClipIterator *iterator = nullptr;
    HRESULT iteratorResult = api->CreateIterator(IID_IBMDSwitcherHyperDeckClipIterator,
                                                  (void **)&iterator);
    if (FAILED(iteratorResult) || !iterator) {
        // Never leave an actionable list behind after enumeration fails. Even when
        // the count is unchanged, storage may have been replaced with new clip IDs.
        NSArray<ATEMHyperDeckClipState *> *fallback = @[];
        _hyperDeckClipCache[cacheKey] = fallback;
        _hyperDeckClipCacheCounts[cacheKey] = @(clipCount);
        _hyperDeckClipCacheTimes[cacheKey] = @(now);
        return fallback;
    }

    NSMutableArray<ATEMHyperDeckClipState *> *clips =
        [NSMutableArray arrayWithCapacity:MIN(clipCount, (NSUInteger)500)];
    IBMDSwitcherHyperDeckClip *clipAPI = nullptr;
    BOOL enumerationFailed = NO;
    while (clips.count < 500) {
        HRESULT nextResult = iterator->Next(&clipAPI);
        if (nextResult == S_FALSE)
            break;
        if (FAILED(nextResult) || !clipAPI) {
            enumerationFailed = YES;
            break;
        }
        bool valid = false;
        BMDSwitcherHyperDeckClipId clipID = -1;
        BOOL includeClip = SUCCEEDED(clipAPI->IsValid(&valid)) && valid &&
                           SUCCEEDED(clipAPI->GetId(&clipID));
        if (includeClip) {
            ATEMHyperDeckClipState *clip = [[ATEMHyperDeckClipState alloc] init];
            clip.clipID = clipID;

            bool infoAvailable = false;
            clipAPI->IsInfoAvailable(&infoAvailable);
            CFStringRef clipName = nullptr;
            if (infoAvailable && SUCCEEDED(clipAPI->GetName(&clipName)) && clipName)
                clip.name = StringFromOwnedCFString(clipName);
            if (clip.name.length == 0)
                clip.name = [NSString stringWithFormat:@"Clip %lld", clipID];

            uint16_t hours = 0;
            uint8_t minutes = 0, seconds = 0, frames = 0;
            if (infoAvailable &&
                SUCCEEDED(clipAPI->GetDuration(&hours, &minutes, &seconds, &frames)))
                clip.duration = TimecodeString(hours, minutes, seconds, frames);
            else
                clip.duration = @"";
            [clips addObject:clip];
        }
        clipAPI->Release();
        clipAPI = nullptr;
    }
    if (clipAPI)
        clipAPI->Release();
    iterator->Release();

    NSArray<ATEMHyperDeckClipState *> *result = enumerationFailed ? @[] : [clips copy];
    _hyperDeckClipCache[cacheKey] = result;
    _hyperDeckClipCacheCounts[cacheKey] = @(clipCount);
    _hyperDeckClipCacheTimes[cacheKey] = @(now);
    return result;
}

- (void)publishFeatureStatesLocked
{
    ATEMAudioState *audioState = [[ATEMAudioState alloc] init];
    audioState.available = _demo || _fairlightMixer != nullptr;
    audioState.demo = _demo;
    audioState.masterLevels = @[];
    audioState.masterPeakLevels = @[];
    audioState.channels = @[];
    audioState.masterFaderGain = 0;

    NSMutableArray<ATEMAudioChannelState *> *channels = [NSMutableArray array];
    if (_demo) {
        audioState.statusMessage = @"Demo Fairlight mixer — live meters are simulated.";
        audioState.masterFaderGain = _demoMasterAudioFader;
        CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
        double masterLeft = -18.0 + 8.0 * std::sin(now * 2.7);
        double masterRight = -20.0 + 7.0 * std::sin(now * 3.1 + 0.8);
        audioState.masterLevels = @[@(masterLeft), @(masterRight)];
        audioState.masterPeakLevels = @[@(MIN(0.0, masterLeft + 3.5)), @(MIN(0.0, masterRight + 3.0))];
        for (NSUInteger index = 0; index < _demoAudioChannels.size(); ++index) {
            const DemoAudioChannel &demoChannel = _demoAudioChannels[index];
            ATEMAudioChannelState *channel = [[ATEMAudioChannelState alloc] init];
            channel.inputID = demoChannel.inputID;
            channel.sourceID = demoChannel.sourceID;
            channel.name = _inputNamesByID[@(demoChannel.inputID)] ?: InputNameForID(_inputStates, demoChannel.inputID);
            channel.active = YES;
            channel.faderGain = demoChannel.faderGain;
            channel.pan = demoChannel.pan;
            channel.mixOption = demoChannel.mixOption;
            channel.supportedMixOptions = ATEMAudioMixOptionOff |
                                          ATEMAudioMixOptionOn |
                                          ATEMAudioMixOptionAudioFollowVideo;
            double phase = now * (2.0 + index * 0.17) + index * 0.63;
            double levelLeft = MAX(-60.0, -28.0 + 13.0 * std::sin(phase) + demoChannel.faderGain * 0.35);
            double levelRight = MAX(-60.0, -30.0 + 12.0 * std::sin(phase + 0.7) + demoChannel.faderGain * 0.35);
            channel.levels = @[@(levelLeft), @(levelRight)];
            channel.peakLevels = @[@(MIN(0.0, levelLeft + 3.0)), @(MIN(0.0, levelRight + 3.0))];
            [channels addObject:channel];
        }
    } else if (_fairlightMixer) {
        audioState.statusMessage = @"Fairlight audio levels and controls are live.";
        double masterGain = 0;
        _fairlightMixer->GetMasterOutFaderGain(&masterGain);
        audioState.masterFaderGain = masterGain;
        audioState.masterLevels = NumbersFromValues(_masterAudioLevels);
        audioState.masterPeakLevels = NumbersFromValues(_masterAudioPeaks);
        for (const FairlightSourceAPIRecord &record : _fairlightSources) {
            if (!record.api)
                continue;
            ATEMAudioChannelState *channel = [[ATEMAudioChannelState alloc] init];
            channel.inputID = record.inputID;
            channel.sourceID = record.sourceID;
            channel.name = record.name ?: _inputNamesByID[@(record.inputID)] ?: InputNameForID(_inputStates, record.inputID);
            bool active = false;
            double faderGain = 0;
            double pan = 0;
            BMDSwitcherFairlightAudioMixOption mixOption = bmdSwitcherFairlightAudioMixOptionOff;
            BMDSwitcherFairlightAudioMixOption supported = (BMDSwitcherFairlightAudioMixOption)0;
            record.api->IsActive(&active);
            record.api->GetFaderGain(&faderGain);
            record.api->GetPan(&pan);
            record.api->GetMixOption(&mixOption);
            record.api->GetSupportedMixOptions(&supported);
            channel.active = active;
            channel.faderGain = faderGain;
            channel.pan = pan;
            channel.mixOption = (ATEMAudioMixOption)(NSUInteger)mixOption;
            channel.supportedMixOptions = (NSUInteger)supported;
            channel.levels = NumbersFromValues(record.levels);
            channel.peakLevels = NumbersFromValues(record.peaks);
            [channels addObject:channel];
        }
    } else {
        audioState.statusMessage = _switcher
            ? @"This switcher does not expose a Fairlight audio mixer."
            : @"Connect an ATEM to use its Fairlight audio mixer.";
    }
    audioState.channels = channels;

    NSMutableArray<ATEMHyperDeckState *> *hyperDeckStates = [NSMutableArray array];
    if (_demo) {
        CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
        for (NSUInteger index = 0; index < _demoHyperDecks.size(); ++index) {
            const DemoHyperDeck &demoDeck = _demoHyperDecks[index];
            ATEMHyperDeckState *deck = [[ATEMHyperDeckState alloc] init];
            deck.deckID = demoDeck.deckID;
            deck.name = [NSString stringWithFormat:@"HyperDeck %lu", (unsigned long)index + 1];
            deck.modelName = index == 0 ? @"HyperDeck Studio HD Mini — Demo" : @"Unconfigured Slot";
            deck.networkAddress = demoDeck.address ?: @"";
            deck.switcherInputID = demoDeck.switcherInputID;
            deck.connectionStatus = demoDeck.connectionStatus;
            deck.remoteAccessEnabled = demoDeck.connectionStatus == ATEMHyperDeckConnectionStatusConnected;
            deck.playerState = demoDeck.playerState;
            deck.currentClip = demoDeck.currentClip;
            if (index == 0) {
                NSArray<NSDictionary<NSString *, id> *> *demoClipData = @[
                    @{@"id": @10, @"name": @"OPENING ROLL", @"duration": @"00:00:18:12"},
                    @{@"id": @42, @"name": @"INTERVIEW A", @"duration": @"00:03:24:08"},
                    @{@"id": @105, @"name": @"B-ROLL SELECTS", @"duration": @"00:01:47:19"},
                    @{@"id": @9001, @"name": @"CLOSING LOOP", @"duration": @"00:00:30:00"},
                ];
                NSMutableArray<ATEMHyperDeckClipState *> *demoClips =
                    [NSMutableArray arrayWithCapacity:demoClipData.count];
                for (NSDictionary<NSString *, id> *clipData in demoClipData) {
                    ATEMHyperDeckClipState *clip = [[ATEMHyperDeckClipState alloc] init];
                    clip.clipID = [clipData[@"id"] longLongValue];
                    clip.name = clipData[@"name"];
                    clip.duration = clipData[@"duration"];
                    [demoClips addObject:clip];
                }
                deck.clips = demoClips;
                deck.clipCount = demoClips.count;
            } else {
                deck.clips = @[];
                deck.clipCount = 0;
            }
            NSUInteger totalFrames = (NSUInteger)fmod(now * 25.0, 25.0 * 60.0 * 60.0);
            deck.timecode = TimecodeString((uint16_t)(totalFrames / (25 * 3600)),
                                           (uint8_t)((totalFrames / (25 * 60)) % 60),
                                           (uint8_t)((totalFrames / 25) % 60),
                                           (uint8_t)(totalFrames % 25));
            deck.recordTimeRemaining = @"01:42:18:00";
            deck.loopedPlayback = demoDeck.loopedPlayback;
            deck.singleClipPlayback = demoDeck.singleClipPlayback;
            deck.autoRollOnTake = demoDeck.autoRollOnTake;
            deck.autoRollFrameDelay = demoDeck.autoRollFrameDelay;
            deck.shuttleSpeed = demoDeck.shuttleSpeed;
            [hyperDeckStates addObject:deck];
        }
    } else {
        for (NSUInteger index = 0; index < _hyperDeckAPIs.size(); ++index) {
            IBMDSwitcherHyperDeck *api = _hyperDeckAPIs[index];
            ATEMHyperDeckState *deck = [[ATEMHyperDeckState alloc] init];
            BMDSwitcherHyperDeckId deckID = (BMDSwitcherHyperDeckId)index;
            api->GetId(&deckID);
            deck.deckID = deckID;
            deck.name = [NSString stringWithFormat:@"HyperDeck %lu", (unsigned long)index + 1];
            CFStringRef model = nullptr;
            if (SUCCEEDED(api->GetModelName(&model)) && model)
                deck.modelName = StringFromOwnedCFString(model);
            else
                deck.modelName = @"HyperDeck Slot";
            uint32_t address = 0;
            api->GetNetworkAddress(&address);
            deck.networkAddress = UnpackHyperDeckAddress(address);
            BMDSwitcherInputId inputID = 0;
            api->GetSwitcherInput(&inputID);
            deck.switcherInputID = inputID;
            BMDSwitcherHyperDeckConnectionStatus status = bmdSwitcherHyperDeckConnectionStatusNotConnected;
            api->GetConnectionStatus(&status);
            deck.connectionStatus = AppHyperDeckConnectionStatus(status);
            bool boolValue = false;
            api->IsRemoteAccessEnabled(&boolValue);
            deck.remoteAccessEnabled = boolValue;
            BMDSwitcherHyperDeckPlayerState playerState = bmdSwitcherHyperDeckStateUnknown;
            api->GetPlayerState(&playerState);
            deck.playerState = AppHyperDeckPlayerState(playerState);
            BMDSwitcherHyperDeckClipId clipID = -1;
            api->GetCurrentClip(&clipID);
            deck.currentClip = clipID;
            uint32_t clipCount = 0;
            api->GetClipCount(&clipCount);
            deck.clipCount = clipCount;
            deck.clips = [self clipsForHyperDeckLocked:api deckID:deckID clipCount:clipCount];
            uint16_t hours = 0;
            uint8_t minutes = 0, seconds = 0, frames = 0;
            if (SUCCEEDED(api->GetCurrentTimelineTime(&hours, &minutes, &seconds, &frames)))
                deck.timecode = TimecodeString(hours, minutes, seconds, frames);
            else
                deck.timecode = @"--:--:--:--";
            hours = 0; minutes = 0; seconds = 0; frames = 0;
            if (SUCCEEDED(api->GetEstimatedRecordTimeRemaining(&hours, &minutes, &seconds, &frames)))
                deck.recordTimeRemaining = TimecodeString(hours, minutes, seconds, frames);
            else
                deck.recordTimeRemaining = @"--:--:--:--";
            boolValue = false;
            api->GetLoopedPlayback(&boolValue);
            deck.loopedPlayback = boolValue;
            boolValue = false;
            api->GetSingleClipPlayback(&boolValue);
            deck.singleClipPlayback = boolValue;
            boolValue = false;
            api->GetAutoRollOnTake(&boolValue);
            deck.autoRollOnTake = boolValue;
            uint16_t frameDelay = 0;
            api->GetAutoRollOnTakeFrameDelay(&frameDelay);
            deck.autoRollFrameDelay = frameDelay;
            int32_t shuttleSpeed = 0;
            api->GetShuttleSpeed(&shuttleSpeed);
            deck.shuttleSpeed = shuttleSpeed;
            [hyperDeckStates addObject:deck];
        }
    }

    NSString *address = [_targetAddressLocked copy] ?: @"";
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self->_shutdown)
            return;
        self.latestAudioState = audioState;
        self.latestHyperDeckStates = hyperDeckStates;
        self.currentAddress = address;
        [[NSNotificationCenter defaultCenter] postNotificationName:ATEMAudioStateDidChangeNotification
                                                            object:self];
        [[NSNotificationCenter defaultCenter] postNotificationName:ATEMHyperDeckStateDidChangeNotification
                                                            object:self];
    });
}

- (void)setProgramInput:(int64_t)inputID
{
    dispatch_async(_controlQueue, ^{
        if (self->_demo) self->_demoProgram = inputID;
        else if (self->_mixEffectBlock) self->_mixEffectBlock->SetProgramInput(inputID);
        [self publishStateLocked];
    });
}

- (void)setPreviewInput:(int64_t)inputID
{
    dispatch_async(_controlQueue, ^{
        if (self->_demo) self->_demoPreview = inputID;
        else if (self->_mixEffectBlock) self->_mixEffectBlock->SetPreviewInput(inputID);
        [self publishStateLocked];
    });
}

- (void)performCut
{
    dispatch_async(_controlQueue, ^{
        if (self->_demo) std::swap(self->_demoProgram, self->_demoPreview);
        else if (self->_mixEffectBlock) self->_mixEffectBlock->PerformCut();
        [self publishStateLocked];
    });
}

- (void)performAutoTransition
{
    dispatch_async(_controlQueue, ^{
        if (self->_demo) {
            self->_demoInTransition = YES;
            self->_demoTransitionPosition = 0.5;
            [self publishStateLocked];
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 450 * NSEC_PER_MSEC), self->_controlQueue, ^{
                if (!self->_demo) return;
                std::swap(self->_demoProgram, self->_demoPreview);
                self->_demoInTransition = NO;
                self->_demoTransitionPosition = 0;
                [self publishStateLocked];
            });
        } else if (self->_mixEffectBlock) {
            self->_mixEffectBlock->PerformAutoTransition();
            [self publishStateLocked];
        }
    });
}

- (void)performFadeToBlack
{
    dispatch_async(_controlQueue, ^{
        if (self->_demo) self->_demoFTB = !self->_demoFTB;
        else if (self->_mixEffectBlock) self->_mixEffectBlock->PerformFadeToBlack();
        [self publishStateLocked];
    });
}

- (void)setTransitionPosition:(double)position
{
    double clamped = MAX(0.0, MIN(1.0, position));
    dispatch_async(_controlQueue, ^{
        if (self->_demo) {
            self->_demoTransitionPosition = clamped;
            self->_demoInTransition = clamped > 0.001 && clamped < 0.999;
            if (clamped >= 0.999) {
                std::swap(self->_demoProgram, self->_demoPreview);
                self->_demoTransitionPosition = 0;
                self->_demoInTransition = NO;
            }
        } else if (self->_mixEffectBlock) {
            self->_mixEffectBlock->SetTransitionPosition(clamped);
        }
        [self publishStateLocked];
    });
}

- (void)setNextTransitionStyle:(ATEMTransitionStyle)style
{
    dispatch_async(_controlQueue, ^{
        if (self->_demo) self->_demoStyle = style;
        else if (self->_transitionParameters) self->_transitionParameters->SetNextTransitionStyle(SDKTransitionStyle(style));
        [self publishStateLocked];
    });
}

- (void)setNextTransitionSelection:(ATEMTransitionSelection)selection
{
    if (selection == 0)
        selection = ATEMTransitionSelectionBackground;
    dispatch_async(_controlQueue, ^{
        if (self->_demo) self->_demoSelection = selection;
        else if (self->_transitionParameters) self->_transitionParameters->SetNextTransitionSelection(SDKTransitionSelection(selection));
        [self publishStateLocked];
    });
}

- (void)setTransitionRate:(uint32_t)frames
{
    uint32_t safeFrames = MAX(1U, MIN(250U, frames));
    dispatch_async(_controlQueue, ^{
        if (self->_demo) {
            self->_demoRate = safeFrames;
        } else if (self->_transitionParameters) {
            BMDSwitcherTransitionStyle style = bmdSwitcherTransitionStyleMix;
            self->_transitionParameters->GetNextTransitionStyle(&style);
            switch (style) {
                case bmdSwitcherTransitionStyleDip:
                    if (self->_dipParameters) self->_dipParameters->SetRate(safeFrames);
                    break;
                case bmdSwitcherTransitionStyleWipe:
                    if (self->_wipeParameters) self->_wipeParameters->SetRate(safeFrames);
                    break;
                case bmdSwitcherTransitionStyleDVE:
                    if (self->_dveParameters) self->_dveParameters->SetRate(safeFrames);
                    break;
                case bmdSwitcherTransitionStyleStinger:
                    if (self->_stingerParameters) self->_stingerParameters->SetMixRate(safeFrames);
                    break;
                case bmdSwitcherTransitionStyleMix:
                default:
                    if (self->_mixParameters) self->_mixParameters->SetRate(safeFrames);
                    break;
            }
        }
        [self publishStateLocked];
    });
}

- (void)setVideoMode:(uint32_t)videoMode
{
    dispatch_async(_controlQueue, ^{
        if (self->_demo) {
            self->_demoVideoMode = videoMode;
        } else if (self->_switcher) {
            bool supported = false;
            if (SUCCEEDED(self->_switcher->DoesSupportVideoMode((BMDSwitcherVideoMode)videoMode, &supported)) && supported)
                self->_switcher->SetVideoMode((BMDSwitcherVideoMode)videoMode);
            else
                self->_statusMessage = @"That video standard is not supported by this switcher.";
        }
        [self publishStateLocked];
    });
}

- (void)setUpstreamKey:(NSUInteger)index onAir:(BOOL)onAir
{
    dispatch_async(_controlQueue, ^{
        if (self->_demo && index < self->_demoKeys.size()) self->_demoKeys[index] = onAir;
        else if (index < self->_upstreamKeyAPIs.size()) self->_upstreamKeyAPIs[index]->SetOnAir(onAir);
        [self publishStateLocked];
    });
}

- (void)setDownstreamKey:(NSUInteger)index onAir:(BOOL)onAir
{
    dispatch_async(_controlQueue, ^{
        if (self->_demo && index < self->_demoDSKOnAir.size()) self->_demoDSKOnAir[index] = onAir;
        else if (index < self->_downstreamKeyAPIs.size()) self->_downstreamKeyAPIs[index]->SetOnAir(onAir);
        [self publishStateLocked];
    });
}

- (void)setDownstreamKey:(NSUInteger)index tied:(BOOL)tied
{
    dispatch_async(_controlQueue, ^{
        if (self->_demo && index < self->_demoDSKTied.size()) self->_demoDSKTied[index] = tied;
        else if (index < self->_downstreamKeyAPIs.size()) self->_downstreamKeyAPIs[index]->SetTie(tied);
        [self publishStateLocked];
    });
}

- (void)performDownstreamKeyAuto:(NSUInteger)index
{
    dispatch_async(_controlQueue, ^{
        if (self->_demo && index < self->_demoDSKOnAir.size()) self->_demoDSKOnAir[index] = !self->_demoDSKOnAir[index];
        else if (index < self->_downstreamKeyAPIs.size()) self->_downstreamKeyAPIs[index]->PerformAutoTransition();
        [self publishStateLocked];
    });
}

- (void)setAuxOutput:(NSUInteger)index source:(int64_t)sourceID
{
    dispatch_async(_controlQueue, ^{
        if (self->_demo && index < self->_demoAuxSources.size()) self->_demoAuxSources[index] = sourceID;
        else if (index < self->_auxAPIs.size()) self->_auxAPIs[index].api->SetInputSource(sourceID);
        [self publishStateLocked];
    });
}

- (void)setColorGenerator:(NSUInteger)index
                      hue:(double)hue
               saturation:(double)saturation
                     luma:(double)luma
{
    double wrappedHue = ATEMWrapDegrees(hue);
    double clampedSaturation = ATEMClamp01(saturation);
    double clampedLuma = ATEMClamp01(luma);
    dispatch_async(_controlQueue, ^{
        if (self->_demo) {
            if (index < self->_demoColorGenerators.size()) {
                self->_demoColorGenerators[index].hue = wrappedHue;
                self->_demoColorGenerators[index].saturation = clampedSaturation;
                self->_demoColorGenerators[index].luma = clampedLuma;
            }
        } else if (index < self->_colorGeneratorAPIs.size()) {
            IBMDSwitcherInputColor *api = self->_colorGeneratorAPIs[index].api;
            if (self->_pendingColorGenerators.size() <= index)
                self->_pendingColorGenerators.resize(index + 1);
            PendingColorGenerator &pending = self->_pendingColorGenerators[index];
            // As everywhere else in this file, only S_OK counts as an acknowledged
            // write; the SDK's S_FALSE no-op means the value already matched.
            if (api->SetHue(wrappedHue) == S_OK)
                MarkPendingValue(pending.hue, wrappedHue);
            if (api->SetSaturation(clampedSaturation) == S_OK)
                MarkPendingValue(pending.saturation, clampedSaturation);
            if (api->SetLuma(clampedLuma) == S_OK)
                MarkPendingValue(pending.luma, clampedLuma);
        }
        [self publishStateLocked];
    });
}

- (void)setLabelForInput:(int64_t)inputID longName:(NSString *)longName shortName:(NSString *)shortName
{
    NSString *requestedLongName = [longName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    NSString *requestedShortName = [shortName stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    dispatch_async(_controlQueue, ^{
        if (requestedLongName.length == 0 || requestedShortName.length == 0) {
            self->_statusMessage = @"Long and short labels cannot be empty.";
            [self publishStateLocked];
            return;
        }

        NSString *appliedLongName = requestedLongName;
        NSString *appliedShortName = requestedShortName;
        BOOL found = NO;
        BOOL succeeded = self->_demo;

        if (!self->_demo) {
            for (InputAPIRecord &record : self->_inputAPIs) {
                if (record.inputID != inputID || !record.api)
                    continue;
                found = YES;
                HRESULT longResult = record.api->SetLongName((__bridge CFStringRef)requestedLongName);
                HRESULT shortResult = record.api->SetShortName((__bridge CFStringRef)requestedShortName);
                succeeded = longResult == S_OK && shortResult == S_OK;

                CFStringRef currentLongName = nullptr;
                CFStringRef currentShortName = nullptr;
                if (SUCCEEDED(record.api->GetLongName(&currentLongName))) {
                    NSString *value = StringFromOwnedCFString(currentLongName);
                    if (value.length)
                        appliedLongName = value;
                }
                if (SUCCEEDED(record.api->GetShortName(&currentShortName))) {
                    NSString *value = StringFromOwnedCFString(currentShortName);
                    if (value.length)
                        appliedShortName = value;
                }
                break;
            }
        } else {
            for (ATEMLabelTargetState *target in self->_labelStates) {
                if (target.inputID == inputID) {
                    found = YES;
                    break;
                }
            }
        }

        if (!found) {
            self->_statusMessage = @"That switcher label endpoint is no longer available.";
            [self publishStateLocked];
            return;
        }

        NSMutableArray<ATEMLabelTargetState *> *labelTargets = [NSMutableArray arrayWithCapacity:self->_labelStates.count];
        for (ATEMLabelTargetState *target in self->_labelStates) {
            if (target.inputID == inputID) {
                [labelTargets addObject:[ATEMLabelTargetState targetWithInputID:target.inputID
                                                                       longName:appliedLongName
                                                                      shortName:appliedShortName
                                                                       typeName:target.typeName
                                                                         output:target.isOutput]];
            } else {
                [labelTargets addObject:target];
            }
        }
        self->_labelStates = [labelTargets copy];

        NSMutableArray<ATEMInputState *> *inputs = [NSMutableArray arrayWithCapacity:self->_inputStates.count];
        for (ATEMInputState *input in self->_inputStates) {
            if (input.inputID == inputID) {
                [inputs addObject:[[ATEMInputState alloc] initWithID:input.inputID
                                                           longName:appliedLongName
                                                          shortName:appliedShortName
                                                   availabilityMask:input.availabilityMask]];
            } else {
                [inputs addObject:input];
            }
        }
        self->_inputStates = [inputs copy];

        NSMutableDictionary<NSNumber *, NSString *> *inputNames = [self->_inputNamesByID mutableCopy] ?: [NSMutableDictionary dictionary];
        inputNames[@(inputID)] = appliedLongName;
        self->_inputNamesByID = [inputNames copy];
        for (AuxAPIRecord &record : self->_auxAPIs)
            if (record.inputID == inputID)
                record.name = appliedLongName;

        self->_statusMessage = succeeded
            ? [NSString stringWithFormat:@"Updated label to %@ / %@.", appliedLongName, appliedShortName]
            : @"The switcher rejected one or both labels; current values were reloaded.";
        [self publishStateLocked];
        [self publishFeatureStatesLocked];
    });
}

- (void)setMultiview:(NSUInteger)index layout:(ATEMMultiviewLayout)layout
{
    dispatch_async(_controlQueue, ^{
        if (self->_demo && index < self->_demoMultiviews.size())
            self->_demoMultiviews[index].layout = layout;
        else if (index < self->_multiviewAPIs.size()) {
            HRESULT result = self->_multiviewAPIs[index]->SetLayout((BMDSwitcherMultiViewLayout)layout);
            if (result == S_OK) {
                if (self->_pendingMultiviews.size() <= index)
                    self->_pendingMultiviews.resize(index + 1);
                MarkPendingValue(self->_pendingMultiviews[index].layout, layout);
            }
        }
        [self publishStateLocked];
    });
}

- (void)setMultiview:(NSUInteger)index programPreviewSwapped:(BOOL)swapped
{
    dispatch_async(_controlQueue, ^{
        if (self->_demo && index < self->_demoMultiviews.size())
            self->_demoMultiviews[index].programPreviewSwapped = swapped;
        else if (index < self->_multiviewAPIs.size()) {
            HRESULT result = self->_multiviewAPIs[index]->SetProgramPreviewSwapped(swapped);
            if (result == S_OK) {
                if (self->_pendingMultiviews.size() <= index)
                    self->_pendingMultiviews.resize(index + 1);
                MarkPendingValue(self->_pendingMultiviews[index].programPreviewSwapped, (bool)swapped);
            }
        }
        [self publishStateLocked];
    });
}

- (void)setMultiview:(NSUInteger)index vuMeterOpacity:(double)opacity
{
    double clamped = MAX(0.0, MIN(1.0, opacity));
    dispatch_async(_controlQueue, ^{
        if (self->_demo && index < self->_demoMultiviews.size())
            self->_demoMultiviews[index].vuMeterOpacity = clamped;
        else if (index < self->_multiviewAPIs.size()) {
            HRESULT result = self->_multiviewAPIs[index]->SetVuMeterOpacity(clamped);
            if (result == S_OK) {
                if (self->_pendingMultiviews.size() <= index)
                    self->_pendingMultiviews.resize(index + 1);
                MarkPendingValue(self->_pendingMultiviews[index].vuMeterOpacity, clamped);
            }
        }
        [self publishStateLocked];
    });
}

- (void)setMultiview:(NSUInteger)index window:(NSUInteger)window source:(int64_t)sourceID
{
    dispatch_async(_controlQueue, ^{
        if (self->_demo && index < self->_demoMultiviews.size() && window < self->_demoMultiviews[index].sources.size())
            self->_demoMultiviews[index].sources[window] = sourceID;
        else if (index < self->_multiviewAPIs.size()) {
            BOOL supportsQuadrantLayout = index < self->_lastKnownMultiviews.count
                ? self->_lastKnownMultiviews[index].supportsQuadrantLayout : NO;
            if (!CanRouteMultiviewWindow(supportsQuadrantLayout, window)) {
                [self publishStateLocked];
                return;
            }
            HRESULT result = self->_multiviewAPIs[index]->SetWindowInput((uint32_t)window, sourceID);
            if (result == S_OK) {
                if (self->_pendingMultiviews.size() <= index)
                    self->_pendingMultiviews.resize(index + 1);
                EnsurePendingMultiviewWindowCount(self->_pendingMultiviews[index], window + 1);
                MarkPendingValue(self->_pendingMultiviews[index].sources[window], sourceID);
            }
        }
        [self publishStateLocked];
    });
}

- (void)setMultiview:(NSUInteger)index window:(NSUInteger)window vuMeterEnabled:(BOOL)enabled
{
    dispatch_async(_controlQueue, ^{
        if (self->_demo && index < self->_demoMultiviews.size() && window < self->_demoMultiviews[index].vuMeters.size())
            self->_demoMultiviews[index].vuMeters[window] = enabled;
        else if (index < self->_multiviewAPIs.size()) {
            HRESULT result = self->_multiviewAPIs[index]->SetVuMeterEnabled((uint32_t)window, enabled);
            if (result == S_OK) {
                if (self->_pendingMultiviews.size() <= index)
                    self->_pendingMultiviews.resize(index + 1);
                EnsurePendingMultiviewWindowCount(self->_pendingMultiviews[index], window + 1);
                MarkPendingValue(self->_pendingMultiviews[index].vuMeters[window], (bool)enabled);
            }
        }
        [self publishStateLocked];
    });
}

- (void)setMultiview:(NSUInteger)index window:(NSUInteger)window safeAreaEnabled:(BOOL)enabled
{
    dispatch_async(_controlQueue, ^{
        if (self->_demo && index < self->_demoMultiviews.size() && window < self->_demoMultiviews[index].safeAreas.size())
            self->_demoMultiviews[index].safeAreas[window] = enabled;
        else if (index < self->_multiviewAPIs.size()) {
            HRESULT result = self->_multiviewAPIs[index]->SetSafeAreaEnabled((uint32_t)window, enabled);
            if (result == S_OK) {
                if (self->_pendingMultiviews.size() <= index)
                    self->_pendingMultiviews.resize(index + 1);
                EnsurePendingMultiviewWindowCount(self->_pendingMultiviews[index], window + 1);
                MarkPendingValue(self->_pendingMultiviews[index].safeAreas[window], (bool)enabled);
            }
        }
        [self publishStateLocked];
    });
}

- (void)setMultiview:(NSUInteger)index window:(NSUInteger)window labelVisible:(BOOL)visible
{
    dispatch_async(_controlQueue, ^{
        if (self->_demo && index < self->_demoMultiviews.size() && window < self->_demoMultiviews[index].labels.size())
            self->_demoMultiviews[index].labels[window] = visible;
        else if (index < self->_multiviewAPIs.size()) {
            HRESULT result = self->_multiviewAPIs[index]->SetLabelVisible((uint32_t)window, visible);
            if (result == S_OK) {
                if (self->_pendingMultiviews.size() <= index)
                    self->_pendingMultiviews.resize(index + 1);
                EnsurePendingMultiviewWindowCount(self->_pendingMultiviews[index], window + 1);
                MarkPendingValue(self->_pendingMultiviews[index].labels[window], (bool)visible);
            }
        }
        [self publishStateLocked];
    });
}

- (void)setMultiview:(NSUInteger)index window:(NSUInteger)window borderVisible:(BOOL)visible
{
    dispatch_async(_controlQueue, ^{
        if (self->_demo && index < self->_demoMultiviews.size() && window < self->_demoMultiviews[index].borders.size())
            self->_demoMultiviews[index].borders[window] = visible;
        else if (index < self->_multiviewAPIs.size()) {
            HRESULT result = self->_multiviewAPIs[index]->SetBorderVisible((uint32_t)window, visible);
            if (result == S_OK) {
                if (self->_pendingMultiviews.size() <= index)
                    self->_pendingMultiviews.resize(index + 1);
                EnsurePendingMultiviewWindowCount(self->_pendingMultiviews[index], window + 1);
                MarkPendingValue(self->_pendingMultiviews[index].borders[window], (bool)visible);
            }
        }
        [self publishStateLocked];
    });
}

- (void)setMultiview:(NSUInteger)index allLabelsVisible:(BOOL)visible
{
    dispatch_async(_controlQueue, ^{
        if (self->_demo && index < self->_demoMultiviews.size()) {
            for (NSUInteger window = 0; window < self->_demoMultiviews[index].labels.size(); ++window)
                self->_demoMultiviews[index].labels[window] = visible;
        } else if (index < self->_multiviewAPIs.size()) {
            IBMDSwitcherMultiView *api = self->_multiviewAPIs[index];
            uint32_t windowCount = index < self->_lastKnownMultiviews.count
                ? (uint32_t)self->_lastKnownMultiviews[index].totalWindowCount : 0;
            if (FAILED(api->GetWindowCount(&windowCount)))
                windowCount = index < self->_lastKnownMultiviews.count
                    ? (uint32_t)self->_lastKnownMultiviews[index].totalWindowCount : 0;
            BOOL supportsQuadrantLayout = index < self->_lastKnownMultiviews.count
                ? self->_lastKnownMultiviews[index].supportsQuadrantLayout : NO;
            windowCount =
                NormalizedMultiviewWindowCount(supportsQuadrantLayout, windowCount);
            if (self->_pendingMultiviews.size() <= index)
                self->_pendingMultiviews.resize(index + 1);
            EnsurePendingMultiviewWindowCount(self->_pendingMultiviews[index], windowCount);
            for (uint32_t window = 0; window < windowCount; ++window) {
                if (api->SetLabelVisible(window, visible) == S_OK)
                    MarkPendingValue(self->_pendingMultiviews[index].labels[window], (bool)visible);
            }
        }
        [self publishStateLocked];
    });
}

- (void)setMultiview:(NSUInteger)index allBordersVisible:(BOOL)visible
{
    dispatch_async(_controlQueue, ^{
        if (self->_demo && index < self->_demoMultiviews.size()) {
            for (NSUInteger window = 0; window < self->_demoMultiviews[index].borders.size(); ++window)
                self->_demoMultiviews[index].borders[window] = visible;
        } else if (index < self->_multiviewAPIs.size()) {
            IBMDSwitcherMultiView *api = self->_multiviewAPIs[index];
            uint32_t windowCount = index < self->_lastKnownMultiviews.count
                ? (uint32_t)self->_lastKnownMultiviews[index].totalWindowCount : 0;
            if (FAILED(api->GetWindowCount(&windowCount)))
                windowCount = index < self->_lastKnownMultiviews.count
                    ? (uint32_t)self->_lastKnownMultiviews[index].totalWindowCount : 0;
            BOOL supportsQuadrantLayout = index < self->_lastKnownMultiviews.count
                ? self->_lastKnownMultiviews[index].supportsQuadrantLayout : NO;
            windowCount =
                NormalizedMultiviewWindowCount(supportsQuadrantLayout, windowCount);
            if (self->_pendingMultiviews.size() <= index)
                self->_pendingMultiviews.resize(index + 1);
            EnsurePendingMultiviewWindowCount(self->_pendingMultiviews[index], windowCount);
            for (uint32_t window = 0; window < windowCount; ++window) {
                if (api->SetBorderVisible(window, visible) == S_OK)
                    MarkPendingValue(self->_pendingMultiviews[index].borders[window], (bool)visible);
            }
        }
        [self publishStateLocked];
    });
}

- (void)setAudioInput:(int64_t)inputID source:(int64_t)sourceID faderGain:(double)gain
{
    dispatch_async(_controlQueue, ^{
        if (self->_demo) {
            for (DemoAudioChannel &channel : self->_demoAudioChannels)
                if (channel.inputID == inputID && channel.sourceID == sourceID)
                    channel.faderGain = gain;
        } else {
            for (FairlightSourceAPIRecord &record : self->_fairlightSources)
                if (record.inputID == inputID && record.sourceID == sourceID && record.api)
                    record.api->SetFaderGain(gain);
        }
    });
}

- (void)setAudioInput:(int64_t)inputID source:(int64_t)sourceID pan:(double)pan
{
    dispatch_async(_controlQueue, ^{
        if (self->_demo) {
            for (DemoAudioChannel &channel : self->_demoAudioChannels)
                if (channel.inputID == inputID && channel.sourceID == sourceID)
                    channel.pan = pan;
        } else {
            for (FairlightSourceAPIRecord &record : self->_fairlightSources)
                if (record.inputID == inputID && record.sourceID == sourceID && record.api)
                    record.api->SetPan(pan);
        }
    });
}

- (void)setAudioInput:(int64_t)inputID source:(int64_t)sourceID mixOption:(ATEMAudioMixOption)mixOption
{
    dispatch_async(_controlQueue, ^{
        if (self->_demo) {
            for (DemoAudioChannel &channel : self->_demoAudioChannels)
                if (channel.inputID == inputID && channel.sourceID == sourceID)
                    channel.mixOption = mixOption;
        } else {
            for (FairlightSourceAPIRecord &record : self->_fairlightSources)
                if (record.inputID == inputID && record.sourceID == sourceID && record.api)
                    record.api->SetMixOption((BMDSwitcherFairlightAudioMixOption)mixOption);
        }
        [self publishFeatureStatesLocked];
    });
}

- (void)setAudioMasterFaderGain:(double)gain
{
    dispatch_async(_controlQueue, ^{
        if (self->_demo)
            self->_demoMasterAudioFader = gain;
        else if (self->_fairlightMixer)
            self->_fairlightMixer->SetMasterOutFaderGain(gain);
    });
}

- (void)resetAudioPeakLevels
{
    dispatch_async(_controlQueue, ^{
        if (self->_fairlightMixer)
            self->_fairlightMixer->ResetAllPeakLevels();
        self->_masterAudioPeaks.clear();
        for (FairlightSourceAPIRecord &record : self->_fairlightSources)
            record.peaks.clear();
        [self publishFeatureStatesLocked];
    });
}

- (void)setHyperDeck:(int64_t)deckID networkAddress:(NSString *)address
{
    NSString *trimmed = [address stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    dispatch_async(_controlQueue, ^{
        if (self->_demo) {
            for (DemoHyperDeck &deck : self->_demoHyperDecks) {
                if (deck.deckID != deckID)
                    continue;
                deck.address = [trimmed copy];
                deck.connectionStatus = trimmed.length
                    ? ATEMHyperDeckConnectionStatusConnected
                    : ATEMHyperDeckConnectionStatusNotConnected;
            }
        } else {
            uint32_t packedAddress = 0;
            if (trimmed.length && !PackHyperDeckAddress(trimmed, &packedAddress))
                return;
            for (IBMDSwitcherHyperDeck *api : self->_hyperDeckAPIs) {
                BMDSwitcherHyperDeckId candidateID = -1;
                api->GetId(&candidateID);
                if (candidateID == deckID)
                    api->SetNetworkAddress(packedAddress);
            }
        }
        [self publishFeatureStatesLocked];
    });
}

- (void)setHyperDeck:(int64_t)deckID switcherInput:(int64_t)inputID
{
    dispatch_async(_controlQueue, ^{
        if (self->_demo) {
            for (DemoHyperDeck &deck : self->_demoHyperDecks)
                if (deck.deckID == deckID)
                    deck.switcherInputID = inputID;
        } else {
            for (IBMDSwitcherHyperDeck *api : self->_hyperDeckAPIs) {
                BMDSwitcherHyperDeckId candidateID = -1;
                api->GetId(&candidateID);
                if (candidateID == deckID)
                    api->SetSwitcherInput(inputID);
            }
        }
        [self publishFeatureStatesLocked];
    });
}

- (void)playHyperDeck:(int64_t)deckID
{
    dispatch_async(_controlQueue, ^{
        if (self->_demo) {
            for (DemoHyperDeck &deck : self->_demoHyperDecks)
                if (deck.deckID == deckID)
                    deck.playerState = ATEMHyperDeckPlayerStatePlay;
        } else {
            for (IBMDSwitcherHyperDeck *api : self->_hyperDeckAPIs) {
                BMDSwitcherHyperDeckId candidateID = -1;
                api->GetId(&candidateID);
                if (candidateID == deckID)
                    api->Play();
            }
        }
        [self publishFeatureStatesLocked];
    });
}

- (void)recordHyperDeck:(int64_t)deckID
{
    dispatch_async(_controlQueue, ^{
        if (self->_demo) {
            for (DemoHyperDeck &deck : self->_demoHyperDecks)
                if (deck.deckID == deckID)
                    deck.playerState = ATEMHyperDeckPlayerStateRecord;
        } else {
            for (IBMDSwitcherHyperDeck *api : self->_hyperDeckAPIs) {
                BMDSwitcherHyperDeckId candidateID = -1;
                api->GetId(&candidateID);
                if (candidateID == deckID)
                    api->Record();
            }
        }
        [self publishFeatureStatesLocked];
    });
}

- (void)stopHyperDeck:(int64_t)deckID
{
    dispatch_async(_controlQueue, ^{
        if (self->_demo) {
            for (DemoHyperDeck &deck : self->_demoHyperDecks)
                if (deck.deckID == deckID)
                    deck.playerState = ATEMHyperDeckPlayerStateIdle;
        } else {
            for (IBMDSwitcherHyperDeck *api : self->_hyperDeckAPIs) {
                BMDSwitcherHyperDeckId candidateID = -1;
                api->GetId(&candidateID);
                if (candidateID == deckID)
                    api->Stop();
            }
        }
        [self publishFeatureStatesLocked];
    });
}

- (void)jogHyperDeck:(int64_t)deckID frames:(NSInteger)frames
{
    dispatch_async(_controlQueue, ^{
        if (!self->_demo) {
            for (IBMDSwitcherHyperDeck *api : self->_hyperDeckAPIs) {
                BMDSwitcherHyperDeckId candidateID = -1;
                api->GetId(&candidateID);
                if (candidateID == deckID)
                    api->Jog((int32_t)frames);
            }
        }
        [self publishFeatureStatesLocked];
    });
}

- (void)shuttleHyperDeck:(int64_t)deckID speed:(NSInteger)speedPercent
{
    dispatch_async(_controlQueue, ^{
        if (self->_demo) {
            for (DemoHyperDeck &deck : self->_demoHyperDecks) {
                if (deck.deckID == deckID) {
                    deck.shuttleSpeed = speedPercent;
                    deck.playerState = ATEMHyperDeckPlayerStateShuttle;
                }
            }
        } else {
            for (IBMDSwitcherHyperDeck *api : self->_hyperDeckAPIs) {
                BMDSwitcherHyperDeckId candidateID = -1;
                api->GetId(&candidateID);
                if (candidateID == deckID)
                    api->Shuttle((int32_t)speedPercent);
            }
        }
        [self publishFeatureStatesLocked];
    });
}

- (void)setHyperDeck:(int64_t)deckID currentClip:(int64_t)clipID
{
    dispatch_async(_controlQueue, ^{
        if (self->_demo) {
            for (DemoHyperDeck &deck : self->_demoHyperDecks)
                if (deck.deckID == deckID)
                    deck.currentClip = clipID;
        } else {
            for (IBMDSwitcherHyperDeck *api : self->_hyperDeckAPIs) {
                BMDSwitcherHyperDeckId candidateID = -1;
                api->GetId(&candidateID);
                if (candidateID == deckID)
                    api->SetCurrentClip(clipID);
            }
        }
        [self publishFeatureStatesLocked];
    });
}

- (void)setHyperDeck:(int64_t)deckID loopedPlayback:(BOOL)enabled
{
    dispatch_async(_controlQueue, ^{
        if (self->_demo) {
            for (DemoHyperDeck &deck : self->_demoHyperDecks)
                if (deck.deckID == deckID)
                    deck.loopedPlayback = enabled;
        } else {
            for (IBMDSwitcherHyperDeck *api : self->_hyperDeckAPIs) {
                BMDSwitcherHyperDeckId candidateID = -1;
                api->GetId(&candidateID);
                if (candidateID == deckID)
                    api->SetLoopedPlayback(enabled);
            }
        }
        [self publishFeatureStatesLocked];
    });
}

- (void)setHyperDeck:(int64_t)deckID singleClipPlayback:(BOOL)enabled
{
    dispatch_async(_controlQueue, ^{
        if (self->_demo) {
            for (DemoHyperDeck &deck : self->_demoHyperDecks)
                if (deck.deckID == deckID)
                    deck.singleClipPlayback = enabled;
        } else {
            for (IBMDSwitcherHyperDeck *api : self->_hyperDeckAPIs) {
                BMDSwitcherHyperDeckId candidateID = -1;
                api->GetId(&candidateID);
                if (candidateID == deckID)
                    api->SetSingleClipPlayback(enabled);
            }
        }
        [self publishFeatureStatesLocked];
    });
}

- (void)setHyperDeck:(int64_t)deckID autoRollOnTake:(BOOL)enabled
{
    dispatch_async(_controlQueue, ^{
        if (self->_demo) {
            for (DemoHyperDeck &deck : self->_demoHyperDecks)
                if (deck.deckID == deckID)
                    deck.autoRollOnTake = enabled;
        } else {
            for (IBMDSwitcherHyperDeck *api : self->_hyperDeckAPIs) {
                BMDSwitcherHyperDeckId candidateID = -1;
                api->GetId(&candidateID);
                if (candidateID == deckID)
                    api->SetAutoRollOnTake(enabled);
            }
        }
        [self publishFeatureStatesLocked];
    });
}

- (void)setHyperDeck:(int64_t)deckID autoRollFrameDelay:(NSUInteger)frames
{
    dispatch_async(_controlQueue, ^{
        uint16_t frameDelay = (uint16_t)MIN(frames, (NSUInteger)UINT16_MAX);
        if (self->_demo) {
            for (DemoHyperDeck &deck : self->_demoHyperDecks)
                if (deck.deckID == deckID)
                    deck.autoRollFrameDelay = frameDelay;
        } else {
            for (IBMDSwitcherHyperDeck *api : self->_hyperDeckAPIs) {
                BMDSwitcherHyperDeckId candidateID = -1;
                api->GetId(&candidateID);
                if (candidateID == deckID)
                    api->SetAutoRollOnTakeFrameDelay(frameDelay);
            }
        }
        [self publishFeatureStatesLocked];
    });
}

- (void)shutdown
{
    if (_shutdown)
        return;
    _shutdown = YES;
    self.stateHandler = nil;
    if (_pollTimer) {
        dispatch_source_cancel(_pollTimer);
        _pollTimer = nil;
    }
    if (_featureTimer) {
        dispatch_source_cancel(_featureTimer);
        _featureTimer = nil;
    }
    dispatch_sync(_controlQueue, ^{
        [self disconnectLockedWithMessage:@""];
        if (self->_discovery) {
            self->_discovery->Release();
            self->_discovery = nullptr;
        }
    });
    if (_switcherMonitor) {
        _switcherMonitor->Release();
        _switcherMonitor = nullptr;
    }
    if (_mixEffectBlockMonitor) {
        _mixEffectBlockMonitor->Release();
        _mixEffectBlockMonitor = nullptr;
    }
    if (_fairlightMixerMonitor) {
        _fairlightMixerMonitor->Release();
        _fairlightMixerMonitor = nullptr;
    }
}

- (void)dealloc
{
    [self shutdown];
}

@end


int ATEMRunSelfTest(void)
{
    @autoreleasepool {
        BOOL runtimeExists = [ATEMController isRuntimeInstalled];
        printf("runtime bundle: %s\n", runtimeExists ? "ok" : "missing");
        if (!runtimeExists)
            return 1;

        IBMDSwitcherDiscovery *discovery = CreateBMDSwitcherDiscoveryInstance();
        printf("discovery instance: %s\n", discovery ? "ok" : "failed");
        if (!discovery)
            return 2;
        discovery->Release();

        if (SDKTransitionStyle(ATEMTransitionStyleWipe) != bmdSwitcherTransitionStyleWipe)
            return 3;
        if (AppTransitionStyle(bmdSwitcherTransitionStyleDVE) != ATEMTransitionStyleDVE)
            return 4;
        printf("transition mapping: ok\n");
        uint32_t packedAddress = 0;
        if (!PackHyperDeckAddress(@"192.168.1.42", &packedAddress) ||
            packedAddress != 0x2A01A8C0U ||
            ![UnpackHyperDeckAddress(packedAddress) isEqualToString:@"192.168.1.42"] ||
            PackHyperDeckAddress(@"192.168.1.999", &packedAddress))
            return 12;
        printf("HyperDeck IPv4 packing: ok\n");
        const std::vector<std::vector<uint32_t>> expectedQuadrantWindows = {
            {0, 2, 8, 10},
            {0, 1, 2, 4, 5, 8, 10},
            {0, 2, 3, 6, 7, 8, 10},
            {0, 1, 2, 3, 4, 5, 6, 7, 8, 10},
            {0, 2, 8, 9, 10, 12, 13},
            {0, 1, 2, 4, 5, 8, 9, 10, 12, 13},
            {0, 2, 3, 6, 7, 8, 9, 10, 12, 13},
            {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 12, 13},
            {0, 2, 8, 10, 11, 14, 15},
            {0, 1, 2, 4, 5, 8, 10, 11, 14, 15},
            {0, 2, 3, 6, 7, 8, 10, 11, 14, 15},
            {0, 1, 2, 3, 4, 5, 6, 7, 8, 10, 11, 14, 15},
            {0, 2, 8, 9, 10, 11, 12, 13, 14, 15},
            {0, 1, 2, 4, 5, 8, 9, 10, 11, 12, 13, 14, 15},
            {0, 2, 3, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15},
            {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15},
        };
        for (uint32_t layoutMask = 0; layoutMask < expectedQuadrantWindows.size(); ++layoutMask) {
            std::vector<uint32_t> actualWindows =
                VisibleQuadrantWindowIndices((ATEMMultiviewLayout)layoutMask);
            if (actualWindows != expectedQuadrantWindows[layoutMask] ||
                actualWindows.size() != ActiveQuadrantWindowCount((ATEMMultiviewLayout)layoutMask))
                return 14;
        }
        if (NormalizedMultiviewWindowCount(YES, 0) != 16 ||
            NormalizedMultiviewWindowCount(YES, 4) != 16 ||
            NormalizedMultiviewWindowCount(YES, 16) != 16 ||
            NormalizedMultiviewWindowCount(NO, 10) != 10 ||
            !CanRouteMultiviewWindow(YES, 0) ||
            CanRouteMultiviewWindow(NO, 0) ||
            CanRouteMultiviewWindow(NO, 1) ||
            !CanRouteMultiviewWindow(NO, 2))
            return 14;
        printf("quadrant physical window mapping (all 16 layouts): ok\n");

        // Colour-generator maths. 75% SMPTE bars are the reference case: every
        // bar is a pair of 0.0/0.75 primaries, which must land on saturation
        // 100% and luma 37.5% with only the hue changing.
        const double barComponents[6][3] = {
            {0.75, 0.75, 0.00},  // yellow
            {0.00, 0.75, 0.75},  // cyan
            {0.00, 0.75, 0.00},  // green
            {0.75, 0.00, 0.75},  // magenta
            {0.75, 0.00, 0.00},  // red
            {0.00, 0.00, 0.75},  // blue
        };
        const double expectedBarHues[6] = {60.0, 180.0, 120.0, 300.0, 0.0, 240.0};
        for (size_t barIndex = 0; barIndex < 6; ++barIndex) {
            ATEMHSL hsl = ATEMHSLFromRGB(barComponents[barIndex][0],
                                         barComponents[barIndex][1],
                                         barComponents[barIndex][2]);
            if (std::fabs(hsl.hue - expectedBarHues[barIndex]) > 0.001 ||
                std::fabs(hsl.saturation - 1.0) > 0.001 ||
                std::fabs(hsl.luma - 0.375) > 0.001)
                return 15;
            ATEMRGB rgb = ATEMRGBFromHSL(hsl.hue, hsl.saturation, hsl.luma);
            if (std::fabs(rgb.red - barComponents[barIndex][0]) > 0.001 ||
                std::fabs(rgb.green - barComponents[barIndex][1]) > 0.001 ||
                std::fabs(rgb.blue - barComponents[barIndex][2]) > 0.001)
                return 15;
        }
        // A neutral has zero saturation and survives the round trip unchanged.
        ATEMHSL neutral = ATEMHSLFromRGB(0.5, 0.5, 0.5);
        if (std::fabs(neutral.saturation) > 1e-9 || std::fabs(neutral.luma - 0.5) > 1e-9)
            return 15;
        printf("HSL colour conversion (75%% bars round trip): ok\n");

        // One stop is a doubling of emitted light, not of the signal number, so
        // it scales luma by 2^(1/gamma). Up then down must return where it started.
        double exposedUp = ATEMLumaAfterStops(0.5, 1.0);
        if (std::fabs(exposedUp - 0.5 * std::pow(2.0, 1.0 / kATEMDisplayGamma)) > 1e-9 ||
            std::fabs(ATEMLumaAfterStops(exposedUp, -1.0) - 0.5) > 1e-9 ||
            std::fabs(ATEMStopsBetweenLuma(0.5, exposedUp) - 1.0) > 1e-9 ||
            std::fabs(ATEMStopsBetweenLuma(0.5, 0.5)) > 1e-9)
            return 16;
        // Black has no light to double, and nothing may exceed legal white.
        if (ATEMLumaAfterStops(0.0, 4.0) != 0.0 ||
            ATEMLumaAfterStops(0.9, 6.0) != 1.0 ||
            ATEMStopsBetweenLuma(0.0, 0.5) != 0.0)
            return 16;
        printf("exposure offset in stops: ok\n");

        ATEMController *controller = [[ATEMController alloc] init];
        ATEMController *secondController = [[ATEMController alloc] init];
        __block ATEMState *observedState = nil;
        __block ATEMState *secondObservedState = nil;
        controller.stateHandler = ^(ATEMState *state) {
            observedState = state;
        };
        secondController.stateHandler = ^(ATEMState *state) {
            secondObservedState = state;
        };
        [controller enterDemoMode];
        [secondController enterDemoMode];
        NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:1.0];
        while ((!observedState.isDemo || !secondObservedState.isDemo || observedState.inputs.count == 0 ||
                !controller.latestAudioState.isAvailable || controller.latestHyperDeckStates.count != 2) &&
               deadline.timeIntervalSinceNow > 0)
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
        if (!observedState.isDemo || observedState.inputs.count != 13 ||
            observedState.upstreamKeys.count != 4 || observedState.downstreamKeys.count != 2 ||
            observedState.labelTargets.count != 17 ||
            observedState.multiviews.count != 2 || observedState.multiviews.firstObject.windows.count != 10 ||
            !secondObservedState.isDemo || !controller.latestAudioState.isAvailable ||
            controller.latestAudioState.channels.count != 8 ||
            controller.latestHyperDeckStates.count != 2 ||
            controller.latestHyperDeckStates.firstObject.clipCount != 4 ||
            controller.latestHyperDeckStates.firstObject.clips.count != 4 ||
            controller.latestHyperDeckStates.firstObject.clips.firstObject.clipID != 10 ||
            controller.latestHyperDeckStates.firstObject.clips[1].clipID != 42 ||
            ![controller.latestHyperDeckStates.firstObject.clips.firstObject.name isEqualToString:@"OPENING ROLL"]) {
            [controller shutdown];
            [secondController shutdown];
            return 5;
        }
        [controller setLabelForInput:1 longName:@"Wide Camera" shortName:@"WIDE"];
        [controller setLabelForInput:kDemoAuxLabelBase longName:@"Stage Feed" shortName:@"STG"];
        deadline = [NSDate dateWithTimeIntervalSinceNow:1.0];
        while ((![LabelTargetForID(observedState.labelTargets, 1).longName isEqualToString:@"Wide Camera"] ||
                ![LabelTargetForID(observedState.labelTargets, kDemoAuxLabelBase).longName isEqualToString:@"Stage Feed"] ||
                ![observedState.inputs.firstObject.shortName isEqualToString:@"WIDE"] ||
                ![observedState.auxOutputs.firstObject.name isEqualToString:@"Stage Feed"]) &&
               deadline.timeIntervalSinceNow > 0) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                     beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
        }
        if (![LabelTargetForID(observedState.labelTargets, 1).longName isEqualToString:@"Wide Camera"] ||
            ![LabelTargetForID(observedState.labelTargets, 1).shortName isEqualToString:@"WIDE"] ||
            ![LabelTargetForID(observedState.labelTargets, kDemoAuxLabelBase).longName isEqualToString:@"Stage Feed"] ||
            ![observedState.inputs.firstObject.longName isEqualToString:@"Wide Camera"] ||
            ![observedState.auxOutputs.firstObject.name isEqualToString:@"Stage Feed"]) {
            [controller shutdown];
            [secondController shutdown];
            return 15;
        }
        [controller setPreviewInput:4];
        [controller performCut];
        deadline = [NSDate dateWithTimeIntervalSinceNow:1.0];
        while (observedState.programInputID != 4 && deadline.timeIntervalSinceNow > 0)
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
        if (observedState.programInputID != 4) {
            [controller shutdown];
            [secondController shutdown];
            return 6;
        }
        for (NSUInteger window = 0; window < 16; ++window)
            [controller setMultiview:0 window:window source:(int64_t)(window % 13) + 1];
        for (uint32_t layoutMask = 0; layoutMask < expectedQuadrantWindows.size(); ++layoutMask) {
            [controller setMultiview:0 layout:(ATEMMultiviewLayout)layoutMask];
            deadline = [NSDate dateWithTimeIntervalSinceNow:1.0];
            while ((observedState.multiviews.firstObject.layout != (ATEMMultiviewLayout)layoutMask ||
                    observedState.multiviews.firstObject.windows.count != expectedQuadrantWindows[layoutMask].size()) &&
                   deadline.timeIntervalSinceNow > 0) {
                [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                         beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
            }
            ATEMMultiviewState *layoutState = observedState.multiviews.firstObject;
            BOOL layoutMatches = layoutState.layout == (ATEMMultiviewLayout)layoutMask &&
                layoutState.totalWindowCount == 16 &&
                layoutState.windows.count == expectedQuadrantWindows[layoutMask].size();
            if (layoutMatches) {
                for (NSUInteger position = 0; position < layoutState.windows.count; ++position) {
                    ATEMMultiviewWindowState *window = layoutState.windows[position];
                    NSUInteger expectedIndex = expectedQuadrantWindows[layoutMask][position];
                    int64_t expectedSource = (int64_t)(expectedIndex % 13) + 1;
                    if (window.index != expectedIndex || window.sourceID != expectedSource) {
                        layoutMatches = NO;
                        break;
                    }
                }
            }
            if (!layoutMatches) {
                [controller shutdown];
                [secondController shutdown];
                return 15;
            }
        }
        [controller setMultiview:0 layout:(ATEMMultiviewLayout)0];
        deadline = [NSDate dateWithTimeIntervalSinceNow:1.0];
        while (observedState.multiviews.firstObject.windows.count != 4 && deadline.timeIntervalSinceNow > 0)
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
        ATEMMultiviewState *fourWindowMultiview = observedState.multiviews.firstObject;
        if (fourWindowMultiview.windows.count != 4 ||
            fourWindowMultiview.totalWindowCount != 16 ||
            fourWindowMultiview.windows[0].index != 0 ||
            fourWindowMultiview.windows[1].index != 2 ||
            fourWindowMultiview.windows[2].index != 8 ||
            fourWindowMultiview.windows[3].index != 10) {
            [controller shutdown];
            [secondController shutdown];
            return 7;
        }
        [controller setMultiview:0 window:8 source:11];
        [controller setMultiview:0 window:10 source:12];
        deadline = [NSDate dateWithTimeIntervalSinceNow:1.0];
        while ((MultiviewWindowStateForIndex(observedState.multiviews.firstObject, 8).sourceID != 11 ||
                MultiviewWindowStateForIndex(observedState.multiviews.firstObject, 10).sourceID != 12) &&
               deadline.timeIntervalSinceNow > 0) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                     beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
        }
        if (MultiviewWindowStateForIndex(observedState.multiviews.firstObject, 8).sourceID != 11 ||
            MultiviewWindowStateForIndex(observedState.multiviews.firstObject, 10).sourceID != 12) {
            [controller shutdown];
            [secondController shutdown];
            return 7;
        }
        [controller setMultiview:0 allLabelsVisible:NO];
        [controller setMultiview:0 allBordersVisible:NO];
        deadline = [NSDate dateWithTimeIntervalSinceNow:1.0];
        while ((observedState.multiviews.firstObject.windows.firstObject.isLabelVisible ||
                observedState.multiviews.firstObject.windows.firstObject.isBorderVisible) &&
               deadline.timeIntervalSinceNow > 0) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                     beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
        }
        ATEMMultiviewLayout allQuadrants = (ATEMMultiviewLayout)(ATEMMultiviewLayoutTopLeftSmall |
                                                                 ATEMMultiviewLayoutTopRightSmall |
                                                                 ATEMMultiviewLayoutBottomLeftSmall |
                                                                 ATEMMultiviewLayoutBottomRightSmall);
        [controller setMultiview:0 layout:allQuadrants];
        [controller setMultiview:0 window:15 source:7];
        [controller setMultiview:0 window:0 labelVisible:NO];
        [controller setMultiview:0 vuMeterOpacity:0.35];
        deadline = [NSDate dateWithTimeIntervalSinceNow:1.0];
        while ((observedState.multiviews.firstObject.layout != allQuadrants ||
                observedState.multiviews.firstObject.windows.count != 16 ||
                observedState.multiviews.firstObject.windows[15].sourceID != 7 ||
                observedState.multiviews.firstObject.windows.firstObject.isLabelVisible ||
                observedState.multiviews.firstObject.windows[15].isLabelVisible ||
                observedState.multiviews.firstObject.windows[15].isBorderVisible ||
                observedState.multiviews.firstObject.vuMeterOpacity > 0.351) && deadline.timeIntervalSinceNow > 0) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
        }
        if (observedState.multiviews.firstObject.layout != allQuadrants ||
            observedState.multiviews.firstObject.windows.count != 16 ||
            observedState.multiviews.firstObject.windows[15].sourceID != 7 ||
            observedState.multiviews.firstObject.windows.firstObject.isLabelVisible ||
            observedState.multiviews.firstObject.windows[15].isLabelVisible ||
            observedState.multiviews.firstObject.windows[15].isBorderVisible ||
            observedState.multiviews.firstObject.vuMeterOpacity > 0.351) {
            [controller shutdown];
            [secondController shutdown];
            return 8;
        }

        ATEMMultiviewLayout multiview2Layout = ATEMMultiviewLayoutBottomRightSmall;
        [controller setMultiview:1 layout:multiview2Layout];
        [controller setMultiview:1 window:0 source:12];
        [controller setMultiview:1 allLabelsVisible:NO];
        [controller setMultiview:1 allBordersVisible:NO];
        deadline = [NSDate dateWithTimeIntervalSinceNow:1.0];
        while ((observedState.multiviews[1].layout != multiview2Layout ||
                observedState.multiviews[1].windows.firstObject.sourceID != 12 ||
                observedState.multiviews[1].windows.firstObject.isLabelVisible ||
                observedState.multiviews[1].windows.firstObject.isBorderVisible) && deadline.timeIntervalSinceNow > 0) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
        }
        ATEMMultiviewState *multiview1 = observedState.multiviews[0];
        ATEMMultiviewState *multiview2 = observedState.multiviews[1];
        BOOL multiview2OverlaysOff = YES;
        for (ATEMMultiviewWindowState *window in multiview2.windows)
            multiview2OverlaysOff &= !window.isLabelVisible && !window.isBorderVisible;
        if (multiview1.layout != allQuadrants || multiview1.windows.count != 16 ||
            multiview1.windows[15].sourceID != 7 || multiview1.vuMeterOpacity > 0.351 ||
            multiview2.layout != multiview2Layout || multiview2.windows.firstObject.sourceID != 12 ||
            !multiview2OverlaysOff) {
            [controller shutdown];
            [secondController shutdown];
            return 9;
        }

        [controller setMultiview:0 allLabelsVisible:YES];
        [controller setMultiview:0 allBordersVisible:YES];
        deadline = [NSDate dateWithTimeIntervalSinceNow:1.0];
        while ((!observedState.multiviews[0].windows.firstObject.isLabelVisible ||
                !observedState.multiviews[0].windows.firstObject.isBorderVisible) && deadline.timeIntervalSinceNow > 0) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
        }
        multiview1 = observedState.multiviews[0];
        multiview2 = observedState.multiviews[1];
        BOOL multiview1OverlaysOn = YES;
        multiview2OverlaysOff = YES;
        for (ATEMMultiviewWindowState *window in multiview1.windows)
            multiview1OverlaysOn &= window.isLabelVisible && window.isBorderVisible;
        for (ATEMMultiviewWindowState *window in multiview2.windows)
            multiview2OverlaysOff &= !window.isLabelVisible && !window.isBorderVisible;
        if (!multiview1OverlaysOn || !multiview2OverlaysOff) {
            [controller shutdown];
            [secondController shutdown];
            return 10;
        }
        if (secondObservedState.programInputID != 1 ||
            secondObservedState.multiviews.firstObject.layout != ATEMMultiviewLayoutProgramTop) {
            [controller shutdown];
            [secondController shutdown];
            return 11;
        }
        // Colour generators: set Color 1 to a 40% gray, then expose it down a
        // third of a stop the way the Media window does, and check the model
        // followed both writes.
        double startingLuma = 0.4;
        [controller setColorGenerator:0 hue:0 saturation:0 luma:startingLuma];
        deadline = [NSDate dateWithTimeIntervalSinceNow:1.0];
        while (std::fabs(controller.latestState.colorGenerators.firstObject.luma - startingLuma) > 0.001 &&
               deadline.timeIntervalSinceNow > 0) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
        }
        ATEMColorGeneratorState *colorOne = controller.latestState.colorGenerators.firstObject;
        if (controller.latestState.colorGenerators.count != 2 ||
            !colorOne ||
            colorOne.inputID != 10 ||
            std::fabs(colorOne.luma - startingLuma) > 0.001 ||
            std::fabs(colorOne.saturation) > 0.001) {
            [controller shutdown];
            [secondController shutdown];
            return 17;
        }
        double exposedDown = ATEMLumaAfterStops(colorOne.luma, -1.0 / 3.0);
        [controller setColorGenerator:0 hue:colorOne.hue saturation:colorOne.saturation luma:exposedDown];
        deadline = [NSDate dateWithTimeIntervalSinceNow:1.0];
        while (std::fabs(controller.latestState.colorGenerators.firstObject.luma - exposedDown) > 0.001 &&
               deadline.timeIntervalSinceNow > 0) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
        }
        if (std::fabs(ATEMStopsBetweenLuma(startingLuma,
                                           controller.latestState.colorGenerators.firstObject.luma) + 1.0 / 3.0) > 0.001 ||
            std::fabs(controller.latestState.colorGenerators[1].hue - 205.0) > 0.001) {
            [controller shutdown];
            [secondController shutdown];
            return 17;
        }

        [controller setAudioInput:1 source:0 faderGain:-12.0];
        [controller recordHyperDeck:1];
        [controller setHyperDeck:1 currentClip:9001];
        deadline = [NSDate dateWithTimeIntervalSinceNow:1.0];
        while ((controller.latestAudioState.channels.firstObject.faderGain > -11.99 ||
                controller.latestHyperDeckStates.firstObject.playerState != ATEMHyperDeckPlayerStateRecord ||
                controller.latestHyperDeckStates.firstObject.currentClip != 9001) &&
               deadline.timeIntervalSinceNow > 0) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.02]];
        }
        if (controller.latestAudioState.channels.firstObject.faderGain > -11.99 ||
            controller.latestAudioState.channels[1].faderGain < -4.01 ||
            controller.latestHyperDeckStates.firstObject.playerState != ATEMHyperDeckPlayerStateRecord ||
            controller.latestHyperDeckStates.firstObject.currentClip != 9001) {
            [controller shutdown];
            [secondController shutdown];
            return 13;
        }
        [controller shutdown];
        [secondController shutdown];
        printf("asynchronous demo controller: ok\n");
        printf("input and output label model: ok\n");
        printf("independent dual sessions: ok\n");
        printf("multiview configuration model (all 16 layouts): ok\n");
        printf("independent multiview outputs: ok\n");
        printf("global multiview overlays: ok\n");
        printf("Fairlight audio model: ok\n");
        printf("HyperDeck transport model: ok\n");
        printf("HyperDeck opaque clip IDs: ok\n");
        printf("colour generator model and exposure offset: ok\n");
        printf("self-test: passed\n");
        return 0;
    }
}

int ATEMPrintDiagnostics(void)
{
    @autoreleasepool {
        NSProcessInfo *processInfo = NSProcessInfo.processInfo;
        NSBundle *runtimeBundle = [NSBundle bundleWithPath:ATEMController.runtimePath];
        NSString *runtimeVersion = [runtimeBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
        if (runtimeVersion.length == 0)
            runtimeVersion = [runtimeBundle objectForInfoDictionaryKey:@"CFBundleVersion"];
        if (runtimeVersion.length == 0)
            runtimeVersion = @"unknown";
        printf("ATEM CNTRL diagnostics\n");
        printf("macOS: %s\n", processInfo.operatingSystemVersionString.UTF8String);
#if defined(__arm64__)
        printf("architecture: arm64\n");
#elif defined(__x86_64__)
        printf("architecture: x86_64\n");
#else
        printf("architecture: unknown\n");
#endif
        printf("runtime path: %s\n", ATEMController.runtimePath.UTF8String);
        printf("runtime installed: %s\n", ATEMController.isRuntimeInstalled ? "yes" : "no");
        printf("runtime version: %s\n", runtimeVersion.UTF8String);
        printf("independent switcher sessions: 2\n");
        printf("multiview configuration API: enabled\n");
        printf("Fairlight audio API: enabled (10 Hz feature refresh)\n");
        printf("ATEM-managed HyperDeck API: enabled (opaque clip IDs)\n");
        printf("camera-control API in main process: no\n");
        printf("isolated camera helper bundled: yes\n");
        return ATEMController.isRuntimeInstalled ? 0 : 1;
    }
}

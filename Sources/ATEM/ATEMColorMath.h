//
//  ATEMColorMath.h
//
//  Colour maths shared by the Media window and the self-test.
//
//  The ATEM colour generators are described in HSL: hue in degrees, saturation
//  0...1, and luma 0...1. Luma here is HSL *lightness* — it is a signal level,
//  not a scene-light value, so a naive "double the number" is not a photographic
//  stop. Everything in this header is header-only and free of AppKit and SDK
//  types so ATEMController.mm can verify it in `--self-test`.
//

#ifndef ATEMColorMath_h
#define ATEMColorMath_h

#include <math.h>

/// Display transfer gamma used to convert a colour-generator luma (a signal
/// level) to and from linear light before applying an exposure offset.
///
/// 2.4 is the BT.1886 reference display EOTF, which is what a Rec.709 monitor
/// or an LED-wall processor applies to the signal the ATEM sends. Exposing "one
/// stop down" therefore means halving *emitted light*, which is what a camera
/// pointed at the wall actually meters — not halving the signal number.
static const double kATEMDisplayGamma = 2.4;

typedef struct {
    double hue;        ///< degrees, 0...360
    double saturation; ///< 0...1
    double luma;       ///< 0...1 (HSL lightness)
} ATEMHSL;

typedef struct {
    double red;   ///< 0...1
    double green; ///< 0...1
    double blue;  ///< 0...1
} ATEMRGB;

static inline double ATEMClamp01(double value)
{
    if (!(value > 0.0))  // also catches NaN
        return 0.0;
    return value > 1.0 ? 1.0 : value;
}

static inline double ATEMWrapDegrees(double degrees)
{
    double wrapped = fmod(degrees, 360.0);
    if (wrapped < 0.0)
        wrapped += 360.0;
    return wrapped;
}

static inline ATEMHSL ATEMHSLFromRGB(double red, double green, double blue)
{
    red = ATEMClamp01(red);
    green = ATEMClamp01(green);
    blue = ATEMClamp01(blue);

    double maximum = fmax(red, fmax(green, blue));
    double minimum = fmin(red, fmin(green, blue));
    double delta = maximum - minimum;

    ATEMHSL hsl;
    hsl.luma = (maximum + minimum) / 2.0;

    if (delta < 1e-9) {
        hsl.hue = 0.0;
        hsl.saturation = 0.0;
        return hsl;
    }

    double denominator = 1.0 - fabs(2.0 * hsl.luma - 1.0);
    hsl.saturation = denominator > 1e-9 ? ATEMClamp01(delta / denominator) : 0.0;

    double hue;
    if (maximum == red)
        hue = 60.0 * fmod((green - blue) / delta, 6.0);
    else if (maximum == green)
        hue = 60.0 * (((blue - red) / delta) + 2.0);
    else
        hue = 60.0 * (((red - green) / delta) + 4.0);
    hsl.hue = ATEMWrapDegrees(hue);
    return hsl;
}

static inline ATEMRGB ATEMRGBFromHSL(double hue, double saturation, double luma)
{
    hue = ATEMWrapDegrees(hue);
    saturation = ATEMClamp01(saturation);
    luma = ATEMClamp01(luma);

    double chroma = (1.0 - fabs(2.0 * luma - 1.0)) * saturation;
    double sector = hue / 60.0;
    double second = chroma * (1.0 - fabs(fmod(sector, 2.0) - 1.0));
    double match = luma - chroma / 2.0;

    double red = 0.0, green = 0.0, blue = 0.0;
    if (sector < 1.0)      { red = chroma; green = second; blue = 0.0; }
    else if (sector < 2.0) { red = second; green = chroma; blue = 0.0; }
    else if (sector < 3.0) { red = 0.0;    green = chroma; blue = second; }
    else if (sector < 4.0) { red = 0.0;    green = second; blue = chroma; }
    else if (sector < 5.0) { red = second; green = 0.0;    blue = chroma; }
    else                   { red = chroma; green = 0.0;    blue = second; }

    ATEMRGB rgb;
    rgb.red = ATEMClamp01(red + match);
    rgb.green = ATEMClamp01(green + match);
    rgb.blue = ATEMClamp01(blue + match);
    return rgb;
}

/// Luma after shifting exposure by `stops` of emitted light.
///
/// Because the display transfer function is a pure power law, scaling linear
/// light by 2^stops is the same as scaling the signal by 2^(stops / gamma) —
/// so one stop up multiplies luma by about 1.33, not 2.
///
/// Black stays black: there is no light to double.
static inline double ATEMLumaAfterStops(double luma, double stops)
{
    luma = ATEMClamp01(luma);
    if (luma <= 0.0)
        return 0.0;
    return ATEMClamp01(luma * pow(2.0, stops / kATEMDisplayGamma));
}

/// Exposure difference in stops between two luma values. Zero when either end
/// is black, since the ratio is undefined there.
static inline double ATEMStopsBetweenLuma(double fromLuma, double toLuma)
{
    fromLuma = ATEMClamp01(fromLuma);
    toLuma = ATEMClamp01(toLuma);
    if (fromLuma <= 0.0 || toLuma <= 0.0)
        return 0.0;
    return kATEMDisplayGamma * log2(toLuma / fromLuma);
}

/// Rec.709 opto-electronic transfer function: scene reflectance to signal.
/// Used only by the chart presets ("18% gray", "90% white").
static inline double ATEMRec709SignalForSceneLinear(double linear)
{
    linear = ATEMClamp01(linear);
    if (linear < 0.018)
        return ATEMClamp01(4.5 * linear);
    return ATEMClamp01(1.099 * pow(linear, 0.45) - 0.099);
}

#endif /* ATEMColorMath_h */

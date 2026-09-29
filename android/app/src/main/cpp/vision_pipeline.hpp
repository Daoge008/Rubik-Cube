#pragma once
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
#include <deque>
#include <map>
#include <string>
#include <vector>

struct Point2D {
    float x;
    float y;
};

enum class DetectedColor : int {
    WHITE = 0,
    RED = 1,
    GREEN = 2,
    YELLOW = 3,
    ORANGE = 4,
    BLUE = 5,
    UNKNOWN = -1
};

struct LabColor {
    float L;
    float a;
    float b;
};

struct RgbColor {
    float r;
    float g;
    float b;
};

// ---------------------------------------------------------------------------
// Colour spaces
// ---------------------------------------------------------------------------

inline float clampChannel(float v) {
    return v < 0.0f ? 0.0f : (v > 255.0f ? 255.0f : v);
}

/// Inverse sRGB transfer function (encoded -> linear light).
inline float srgbChannelToLinear(float channel) {
    const float v = channel / 255.0f;
    return (v <= 0.04045f) ? (v / 12.92f) : std::pow((v + 0.055f) / 1.055f, 2.4f);
}

/// sRGB -> CIELAB under a D65 white point.
///
/// Every sticker comparison happens in Lab rather than RGB because the cube is
/// read under whatever light the room happens to have. In RGB the same numeric
/// difference means "clearly different" between two dark stickers and
/// "identical" between two bright ones, which is exactly the ambiguity that
/// makes red and orange swap places.
inline LabColor rgbToLab(const RgbColor& c) {
    const float r = srgbChannelToLinear(c.r);
    const float g = srgbChannelToLinear(c.g);
    const float b = srgbChannelToLinear(c.b);

    // sRGB (D65) -> CIE XYZ
    const float x = (0.4124564f * r + 0.3575761f * g + 0.1804375f * b) / 0.95047f;
    const float y = (0.2126729f * r + 0.7151522f * g + 0.0721750f * b) / 1.00000f;
    const float z = (0.0193339f * r + 0.1191920f * g + 0.9503041f * b) / 1.08883f;

    auto f = [](float t) {
        return (t > 0.008856f) ? std::cbrt(t) : (7.787f * t + 16.0f / 116.0f);
    };
    const float fx = f(x);
    const float fy = f(y);
    const float fz = f(z);

    return { 116.0f * fy - 16.0f, 500.0f * (fx - fy), 200.0f * (fy - fz) };
}

/// YCbCr (BT.601, video range) -> sRGB.
///
/// This is the layout Android camera streams arrive in. Rec.601 rather than
/// Rec.709 because that is what CameraX specifies for YUV_420_888, and using
/// the wrong matrix shifts saturated colours noticeably - greens and reds worst
/// of all, which are two of the six sticker colours.
inline RgbColor yuvToRgb(int y, int u, int v) {
    const float yy = static_cast<float>(y) - 16.0f;
    const float uu = static_cast<float>(u) - 128.0f;
    const float vv = static_cast<float>(v) - 128.0f;
    return {
        clampChannel(1.164f * yy + 1.596f * vv),
        clampChannel(1.164f * yy - 0.392f * uu - 0.813f * vv),
        clampChannel(1.164f * yy + 2.017f * uu),
    };
}

inline float computeDeltaE94(const LabColor& lab1, const LabColor& lab2) {
    const float dL = lab1.L - lab2.L;
    const float da = lab1.a - lab2.a;
    const float db = lab1.b - lab2.b;

    const float c1 = std::sqrt(lab1.a * lab1.a + lab1.b * lab1.b);
    const float c2 = std::sqrt(lab2.a * lab2.a + lab2.b * lab2.b);
    const float dC = c1 - c2;
    float dH2 = da * da + db * db - dC * dC;
    const float dH = (dH2 > 0.0f) ? std::sqrt(dH2) : 0.0f;

    const float kL = 1.0f, kC = 1.0f, kH = 1.0f;
    const float K1 = 0.045f, K2 = 0.015f;

    const float sL = 1.0f;
    const float sC = 1.0f + K1 * c1;
    const float sH = 1.0f + K2 * c1;

    const float vL = dL / (kL * sL);
    const float vC = dC / (kC * sC);
    const float vH = dH / (kH * sH);

    return std::sqrt(vL * vL + vC * vC + vH * vH);
}

/// Orders four loose corner points into top-left, top-right, bottom-right,
/// bottom-left. Kept for the future corner-detector driven mode; the current
/// centred-grid sampler produces an axis aligned quad and does not need it.
inline std::vector<Point2D> orderCorners(const std::vector<Point2D>& pts) {
    if (pts.size() != 4) return pts;
    std::vector<Point2D> ordered(4);

    Point2D center{ 0.0f, 0.0f };
    for (const auto& p : pts) {
        center.x += p.x;
        center.y += p.y;
    }
    center.x *= 0.25f;
    center.y *= 0.25f;

    std::vector<std::pair<float, Point2D>> angles;
    for (const auto& p : pts) {
        angles.push_back({ std::atan2(p.y - center.y, p.x - center.x), p });
    }
    std::sort(angles.begin(), angles.end(),
              [](const auto& a, const auto& b) { return a.first < b.first; });

    int tlIdx = 0;
    float minSum = 1e9f;
    for (int i = 0; i < 4; ++i) {
        const float sum = angles[i].second.x + angles[i].second.y;
        if (sum < minSum) {
            minSum = sum;
            tlIdx = i;
        }
    }
    for (int i = 0; i < 4; ++i) {
        ordered[i] = angles[(tlIdx + i) % 4].second;
    }
    return ordered;
}

// ---------------------------------------------------------------------------
// Frame access
// ---------------------------------------------------------------------------

/// One plane of a packed camera image.
///
/// CameraX does not hand over tightly packed buffers: rows are padded up to an
/// alignment boundary, and on NV21 style layouts the chroma planes are
/// interleaved with a pixel stride of two. Both have to be honoured, otherwise
/// every sample after the first row is read from the wrong address.
struct PlaneView {
    const uint8_t* data = nullptr;
    int stride = 0;
    int pixelStride = 1;

    bool valid() const { return data != nullptr && stride > 0 && pixelStride > 0; }
};

/// Read-only view over one camera frame, in either of the two layouts the app
/// actually feeds in.
class FrameView {
public:
    enum class Format { Rgba8888, Yuv420 };

    static FrameView rgba(const uint8_t* data, int width, int height,
                          int bytesPerRow, int rotationDegrees = 0) {
        FrameView f;
        f.format_ = Format::Rgba8888;
        f.width_ = width;
        f.height_ = height;
        f.rotation_ = normalizeRotation(rotationDegrees);
        f.y_ = { data, bytesPerRow, 4 };
        return f;
    }

    static FrameView yuv420(const PlaneView& y, const PlaneView& u, const PlaneView& v,
                            int width, int height, int rotationDegrees = 0) {
        FrameView f;
        f.format_ = Format::Yuv420;
        f.width_ = width;
        f.height_ = height;
        f.rotation_ = normalizeRotation(rotationDegrees);
        f.y_ = y;
        f.u_ = u;
        f.v_ = v;
        return f;
    }

    bool valid() const {
        if (width_ <= 0 || height_ <= 0 || !y_.valid()) return false;
        if (format_ == Format::Yuv420) return u_.valid() && v_.valid();
        return true;
    }

    int rawWidth() const { return width_; }
    int rawHeight() const { return height_; }

    /// Frame size after undoing the sensor rotation. This is the coordinate
    /// system both the on-screen guide box and the sampling grid live in.
    int uprightWidth() const { return isQuarterTurn() ? height_ : width_; }
    int uprightHeight() const { return isQuarterTurn() ? width_ : height_; }

    /// Reads the pixel at upright coordinates ([u], [v]), returning black for
    /// anything outside the frame so sampling can never read out of bounds.
    RgbColor pixelUpright(float u, float v) const {
        int x = 0;
        int y = 0;
        mapUprightToRaw(static_cast<int>(u), static_cast<int>(v), x, y);
        if (x < 0 || y < 0 || x >= width_ || y >= height_) return { 0.0f, 0.0f, 0.0f };
        return readRaw(x, y);
    }

private:
    static int normalizeRotation(int degrees) {
        int d = degrees % 360;
        if (d < 0) d += 360;
        // Anything that is not an exact quarter turn is treated as upright.
        // Interpolating a bad angle would silently shear the sampling grid.
        return (d / 90) * 90;
    }

    bool isQuarterTurn() const { return rotation_ == 90 || rotation_ == 270; }

    /// The sensor is mounted sideways on nearly every phone, so the stream
    /// arrives rotated by a multiple of 90 degrees. Both the guide box and the
    /// sampling grid are defined in upright space, so the mapping is applied
    /// once here instead of at every call site.
    void mapUprightToRaw(int u, int v, int& x, int& y) const {
        switch (rotation_) {
            case 90:  x = v;                 y = height_ - 1 - u; break;
            case 180: x = width_ - 1 - u;    y = height_ - 1 - v; break;
            case 270: x = width_ - 1 - v;    y = u;               break;
            default:  x = u;                 y = v;               break;
        }
    }

    RgbColor readRaw(int x, int y) const {
        const uint8_t* p = y_.data +
            static_cast<size_t>(y) * static_cast<size_t>(y_.stride) +
            static_cast<size_t>(x) * static_cast<size_t>(y_.pixelStride);

        if (format_ == Format::Rgba8888) {
            return { static_cast<float>(p[0]), static_cast<float>(p[1]),
                     static_cast<float>(p[2]) };
        }

        // Chroma is stored at half resolution in both directions.
        const int cx = x / 2;
        const int cy = y / 2;
        const uint8_t uu = u_.data[static_cast<size_t>(cy) * static_cast<size_t>(u_.stride) +
                                   static_cast<size_t>(cx) * static_cast<size_t>(u_.pixelStride)];
        const uint8_t vv = v_.data[static_cast<size_t>(cy) * static_cast<size_t>(v_.stride) +
                                   static_cast<size_t>(cx) * static_cast<size_t>(v_.pixelStride)];
        return yuvToRgb(p[0], uu, vv);
    }

    Format format_ = Format::Rgba8888;
    int width_ = 0;
    int height_ = 0;
    int rotation_ = 0;
    PlaneView y_;
    PlaneView u_;
    PlaneView v_;
};

// ---------------------------------------------------------------------------
// Face sampling
// ---------------------------------------------------------------------------

/// One face's nine stickers plus the quad they were read from.
///
/// Both colour spaces are kept. The classifier works in Lab, but the white
/// balance stage has to act on the raw reading before any conversion - a gain
/// applied to an already converted Lab value cannot undo a per-channel cast.
struct FaceSample {
    RgbColor rgb[9];
    LabColor lab[9];
    Point2D corners[4];
    bool ok = false;
};

/// Samples one face as a centred 3x3 grid.
///
/// The grid geometry is deliberately fixed - a centred square spanning
/// [sideFraction] of the shorter upright edge - so that the guide box drawn in
/// the UI and the region actually measured are the same rectangle by
/// construction. Nothing has to project one onto the other, which removes a
/// whole class of "it locked onto the wrong thing" bugs, and it keeps working
/// when the preview is letterboxed.
///
/// A future corner detector can replace this with a perspective corrected quad
/// without the rest of the pipeline noticing, because everything downstream
/// only sees nine Lab colours.
inline FaceSample sampleFaceGrid(const FrameView& frame,
                                 float sideFraction = 0.72f,
                                 float cellInnerFraction = 0.55f,
                                 int maxSamplesPerCell = 20) {
    FaceSample out{};  // value initialised so a failed sample has no junk in it
    if (!frame.valid()) return out;

    const float uw = static_cast<float>(frame.uprightWidth());
    const float uh = static_cast<float>(frame.uprightHeight());
    const float side = std::min(uw, uh) * sideFraction;
    if (side < 3.0f) return out;

    const float left = (uw - side) * 0.5f;
    const float top = (uh - side) * 0.5f;
    const float cell = side / 3.0f;

    out.corners[0] = { left, top };
    out.corners[1] = { left + side, top };
    out.corners[2] = { left + side, top + side };
    out.corners[3] = { left, top + side };

    for (int gy = 0; gy < 3; ++gy) {
        for (int gx = 0; gx < 3; ++gx) {
            // Only the middle of each cell is averaged. The outer ring of a
            // sticker sits next to the black plastic between stickers, and
            // including it drags every average towards grey - which is exactly
            // what makes yellow and orange collapse into each other.
            const float inner = cell * cellInnerFraction;
            const float x0 = left + cell * (gx + 0.5f) - inner * 0.5f;
            const float y0 = top + cell * (gy + 0.5f) - inner * 0.5f;

            const float step = std::max(1.0f, inner / static_cast<float>(maxSamplesPerCell));
            double r = 0.0;
            double g = 0.0;
            double b = 0.0;
            int n = 0;
            for (float y = y0; y < y0 + inner; y += step) {
                for (float x = x0; x < x0 + inner; x += step) {
                    const RgbColor c = frame.pixelUpright(x, y);
                    r += c.r;
                    g += c.g;
                    b += c.b;
                    ++n;
                }
            }
            if (n == 0) return out;  // leave ok = false rather than guess

            // Averaging in sRGB and converting once per cell keeps the
            // expensive cube roots to nine per frame instead of one per
            // sampled pixel.
            const int idx = gy * 3 + gx;
            out.rgb[idx] = { static_cast<float>(r / n),
                             static_cast<float>(g / n),
                             static_cast<float>(b / n) };
            out.lab[idx] = rgbToLab(out.rgb[idx]);
        }
    }
    out.ok = true;
    return out;
}

// ---------------------------------------------------------------------------
// Colour classification
// ---------------------------------------------------------------------------

/// Nearest neighbour sticker classifier in CIELAB, with a white balance stage.
///
/// Anchors are held in sRGB rather than Lab on purpose. A phone camera's white
/// balance shifts the channels independently by 20% or more, which is easily
/// enough to swap red and orange, and a per-channel gain is applied to the
/// anchors in exactly the space the camera distorted them. The same correction
/// expressed in Lab could not be written down.
class AdaptiveColorClassifier {
public:
    static constexpr int kColorCount = 6;

    AdaptiveColorClassifier() {
        // Typical vinyl sticker colours rather than pure sRGB primaries. Real
        // cube stickers are less saturated than primaries, and starting from
        // primaries biases the classifier towards confidently wrong answers.
        anchors_[0] = { 245.0f, 245.0f, 242.0f };  // white
        anchors_[1] = { 196.0f,  34.0f,  42.0f };  // red
        anchors_[2] = {  32.0f, 168.0f,  74.0f };  // green
        anchors_[3] = { 246.0f, 214.0f,  46.0f };  // yellow
        anchors_[4] = { 238.0f, 138.0f,  28.0f };  // orange
        anchors_[5] = {  28.0f,  88.0f, 186.0f };  // blue
        rebuildAnchorLab();
    }

    /// Teaches the classifier the camera's white point.
    ///
    /// One measured white sticker is enough. The camera rendered a standard
    /// white ([kWhiteTarget]) as [measured], so every anchor's expected reading
    /// under this light is `anchor * (measured / kWhiteTarget)` - the gain is
    /// derived, not accumulated, which keeps a rescan from stacking correction
    /// on top of correction. The caller feeds the centre sticker of the first
    /// scanned face, which is why the UI asks the user to hold the white side
    /// up first: it is the one sample whose true colour is known in advance.
    void calibrateWhite(const RgbColor& measured) {
        gain_.r = std::max(measured.r, 1.0f) / kWhiteTarget;
        gain_.g = std::max(measured.g, 1.0f) / kWhiteTarget;
        gain_.b = std::max(measured.b, 1.0f) / kWhiteTarget;
        whiteCalibrated_ = true;
        rebuildAnchorLab();
    }

    bool hasWhiteReference() const { return whiteCalibrated_; }

    /// Nudges one anchor towards a freshly measured sticker.
    ///
    /// Deliberately slow. This absorbs the gap between the nominal vinyl colour
    /// and the particular cube in the user's hands, and a fast gain would let a
    /// single misclassified sticker drag an anchor onto its neighbour.
    void updateAnchor(DetectedColor color, const RgbColor& measured) {
        const int idx = static_cast<int>(color);
        if (idx < 0 || idx >= kColorCount) return;

        // Undo the lighting gain first. Anchors describe the sticker under
        // standard light, so folding the room's cast into them would silently
        // cancel the white balance correction on the very next frame.
        const RgbColor normalized{
            measured.r / std::max(gain_.r, 1e-3f),
            measured.g / std::max(gain_.g, 1e-3f),
            measured.b / std::max(gain_.b, 1e-3f),
        };

        if (!observed_[idx]) {
            anchors_[idx] = normalized;
            observed_[idx] = true;
        } else {
            constexpr float kAlpha = 0.15f;
            anchors_[idx].r += kAlpha * (normalized.r - anchors_[idx].r);
            anchors_[idx].g += kAlpha * (normalized.g - anchors_[idx].g);
            anchors_[idx].b += kAlpha * (normalized.b - anchors_[idx].b);
        }
        rebuildAnchorLab();
    }

    static constexpr float kMaxStickerDistance = 32.0f;

    DetectedColor classify(const LabColor& sample) const {
        const auto m = nearest(sample);
        if (m.distance > kMaxStickerDistance) {
            return DetectedColor::UNKNOWN;
        }
        return m.color;
    }

    /// How much the runner-up lost by, as a ratio in [0, 1].
    ///
    /// Near 0 the sample is unambiguously one colour; near 1 the two closest
    /// anchors were equally plausible. Surfaced through the detection result so
    /// the UI can tell the user "hold it closer" instead of leaving them to
    /// guess whether a subtle colour was read correctly.
    float ambiguity(const LabColor& sample) const {
        float best = 1e9f;
        float second = 1e9f;
        for (int i = 0; i < kColorCount; ++i) {
            const float d = computeDeltaE94(sample, anchorLab_[i]);
            if (d < best) {
                second = best;
                best = d;
            } else if (d < second) {
                second = d;
            }
        }
        if (second <= 1e-6f) return 1.0f;
        return std::min(1.0f, best / second);
    }

private:
    struct Match {
        DetectedColor color = DetectedColor::UNKNOWN;
        float distance = 1e9f;
    };

    Match nearest(const LabColor& sample) const {
        Match best;
        for (int i = 0; i < kColorCount; ++i) {
            const float d = computeDeltaE94(sample, anchorLab_[i]);
            if (d < best.distance) {
                best.distance = d;
                best.color = static_cast<DetectedColor>(i);
            }
        }
        return best;
    }

    void rebuildAnchorLab() {
        for (int i = 0; i < kColorCount; ++i) {
            anchorLab_[i] = rgbToLab({
                clampChannel(anchors_[i].r * gain_.r),
                clampChannel(anchors_[i].g * gain_.g),
                clampChannel(anchors_[i].b * gain_.b),
            });
        }
    }

    static constexpr float kWhiteTarget = 245.0f;

    RgbColor anchors_[kColorCount];
    LabColor anchorLab_[kColorCount];
    bool observed_[kColorCount] = { false, false, false, false, false, false };
    RgbColor gain_{ 1.0f, 1.0f, 1.0f };
    bool whiteCalibrated_ = false;
};

// ---------------------------------------------------------------------------
// Temporal aggregation
// ---------------------------------------------------------------------------

/// Turns a stream of single-frame classifications into locked faces.
///
/// One frame is never trusted on its own: a hand held cube wobbles, autofocus
/// hunts, and a single bad frame would otherwise lock a wrong sticker into the
/// state with no way to notice afterwards. A face is accepted only once the
/// same nine colours have won a clear majority across a full window of frames.
class MultiFrameAggregator {
public:
    static constexpr size_t kWindowSize = 8;
    static constexpr int kMajorityVotes = 6;

    void reset() {
        history_.clear();
        stableFaces_.clear();
        lastCenter_ = DetectedColor::UNKNOWN;
        ++version_;
    }

    /// Feeds one frame worth of classified stickers.
    ///
    /// Frames are bucketed by their centre sticker, which is both the most
    /// reliably read cell (it is the largest solid area) and the one that
    /// identifies which physical face is being looked at.
    void pushFrame(const std::array<DetectedColor, 9>& stickers) {
        const DetectedColor center = stickers[4];
        if (center == DetectedColor::UNKNOWN) return;

        lastCenter_ = center;
        auto& q = history_[center];
        q.push_back(stickers);
        while (q.size() > kWindowSize) q.pop_front();
        if (q.size() < kWindowSize) return;

        std::array<DetectedColor, 9> candidate;
        bool confident = true;
        for (int i = 0; i < 9 && confident; ++i) {
            std::map<DetectedColor, int> votes;
            for (const auto& record : q) votes[record[i]]++;

            DetectedColor top = DetectedColor::UNKNOWN;
            int maxVotes = 0;
            for (const auto& [color, count] : votes) {
                if (count > maxVotes) {
                    maxVotes = count;
                    top = color;
                }
            }
            if (maxVotes < kMajorityVotes) confident = false;
            candidate[i] = top;
        }

        if (confident) {
            stableFaces_[center] = candidate;
            ++version_;
        }
    }

    /// Bumped whenever a locked face is added or replaced.
    ///
    /// Lets the caller skip re-running the 4096-way orientation search on every
    /// frame once six faces are in: while the scan keeps refining itself the
    /// answer can still change, but between changes it cannot.
    unsigned int version() const { return version_; }

    int getScannedFaceCount() const { return static_cast<int>(stableFaces_.size()); }

    bool isAllFacesScanned() const { return stableFaces_.size() == 6; }

    /// Frames accumulated for the face currently in front of the camera, so the
    /// UI can show a settling progress bar instead of a frozen count.
    int currentFaceFrameCount() const {
        const auto it = history_.find(lastCenter_);
        return (it == history_.end()) ? 0 : static_cast<int>(it->second.size());
    }

    DetectedColor lastCenterColor() const { return lastCenter_; }

    bool isFaceLocked(DetectedColor center) const {
        return stableFaces_.find(center) != stableFaces_.end();
    }

    const std::map<DetectedColor, std::array<DetectedColor, 9>>& stableFaces() const {
        return stableFaces_;
    }

private:
    std::map<DetectedColor, std::deque<std::array<DetectedColor, 9>>> history_;
    std::map<DetectedColor, std::array<DetectedColor, 9>> stableFaces_;
    DetectedColor lastCenter_ = DetectedColor::UNKNOWN;
    unsigned int version_ = 0;
};

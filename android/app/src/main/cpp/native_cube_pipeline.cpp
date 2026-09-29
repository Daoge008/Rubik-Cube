#include "native_cube_pipeline.h"
#include "cube_model.hpp"
#include "kociemba_solver.hpp"
#include "cfop_pipeline.hpp"
#include "vision_pipeline.hpp"
#include "face_assembler.hpp"
#include "ar_engine.hpp"
#include "step_validation_engine.hpp"
#include <cstring>
#include <cstdlib>
#include <cstdio>
#include <sstream>

// The engine lives in `rubik` (see kociemba_solver.hpp, cfop_pipeline.hpp),
// while this file is a thin `extern "C"` boundary whose only job is to adapt
// C strings and POD structs for the Dart side. Qualifying every call in a file
// that is nothing but forwarding would add noise without adding safety, so the
// directive is used here - and only here. It must never appear in a header.
using namespace rubik;

namespace {

/// Escapes a UTF-8 string for a JSON string literal.
///
/// The guide text is authored in C++ and only contains Chinese plus algorithm
/// notation, so it should never need escaping - but a future hint containing a
/// quote or a newline would silently turn the whole payload into invalid JSON,
/// and the Dart side would then fail to decode it with no useful error. Doing
/// it here costs nothing and removes that entire class of bug.
std::string jsonEscape(const std::string& in) {
    std::string out;
    out.reserve(in.size() + 8);
    for (unsigned char c : in) {
        switch (c) {
            case '"':  out += "\\\""; break;
            case '\\': out += "\\\\"; break;
            case '\n': out += "\\n";  break;
            case '\r': out += "\\r";  break;
            case '\t': out += "\\t";  break;
            default:
                if (c < 0x20) {
                    char buf[8];
                    std::snprintf(buf, sizeof(buf), "\\u%04x", c);
                    out += buf;
                } else {
                    // Bytes >= 0x80 are UTF-8 continuation/lead bytes and pass
                    // through untouched, which is what the JSON spec wants.
                    out += static_cast<char>(c);
                }
        }
    }
    return out;
}

}  // namespace

struct PipelineContext {
    AdaptiveColorClassifier classifier;
    MultiFrameAggregator aggregator;
    StepValidationEngine stepValidator;
    float fx, fy, cx, cy;

    /// Outcome of stitching the six locked faces into one facelet string.
    FaceAssembler::Result assembly;
    /// Aggregator version the cached [assembly] was computed from.
    unsigned int assembledVersion = 0;
    /// Set once the user has been told the scan is unusable, so the state is
    /// computed once per change rather than re-derived on every frame.
    bool assemblyAttempted = false;
};

namespace {

/// Minimum total sRGB for a first frame to be accepted as the white reference.
///
/// The UI asks the user to start on the white face so the scanner can learn the
/// camera's white point. A hand-held first frame is often aimed at the table, a
/// whole cube at an angle, or a shadow - so the centre sticker also has to be
/// bright before it is trusted. One dark wrong reading would otherwise scale
/// every anchor and misclassify the entire scan.
constexpr float kWhiteReferenceMinSum = 300.0f;

/// Runner-up ratio above which a cell is reported as ambiguous to the UI.
constexpr float kAmbiguityWarnRatio = 0.75f;

/// Mean Lab lightness below which the guide box is looking at nothing.
///
/// A phone resting on a desk, or a cube held outside the box, gives a near
/// black sample. Nearest neighbour classification always returns *something*,
/// and near-black lands closest to blue - which would then be voted into the
/// scan as a real face. Reporting "not detected" instead lets the UI ask the
/// user to aim, and lets the app auto-correct a wrong sensor rotation by
/// noticing that nothing was ever seen.
constexpr float kMinFaceLightness = 18.0f;

/// Re-stitches the six faces, but only when the locked set actually changed.
void refreshAssembly(PipelineContext* ctx) {
    if (!ctx->aggregator.isAllFacesScanned()) return;
    if (ctx->assemblyAttempted && ctx->assembledVersion == ctx->aggregator.version()) return;

    ctx->assembly = FaceAssembler::solve(ctx->aggregator.stableFaces());
    ctx->assembledVersion = ctx->aggregator.version();
    ctx->assemblyAttempted = true;
}

/// Shared body of both frame entry points.
///
/// Format handling stops at the [FrameView]; everything downstream deals in the
/// nine sampled colours and is unaware of where they came from.
void runFrame(PipelineContext* ctx, const FrameView& frame, NativeDetectionResult* out) {
    out->isDetected = 0;
    out->stepAdvanced = 0;
    out->ambiguousCells = 0;
    out->faceFrameCount = ctx->aggregator.currentFaceFrameCount();
    out->windowSize = static_cast<int>(MultiFrameAggregator::kWindowSize);
    out->assemblyState = 0;
    out->assemblyScore = 0;
    out->currentStepIndex = static_cast<int>(ctx->stepValidator.getCurrentStepIndex());
    out->totalSteps = static_cast<int>(ctx->stepValidator.getTotalSteps());

    const FaceSample sample = sampleFaceGrid(frame);
    if (!sample.ok) {
        out->centerColor = static_cast<int>(DetectedColor::UNKNOWN);
        for (int i = 0; i < 9; ++i) {
            out->stickers[i] = static_cast<int>(DetectedColor::UNKNOWN);
        }
        return;
    }

    for (int i = 0; i < 4; ++i) {
        out->corners[i] = { sample.corners[i].x, sample.corners[i].y };
    }

    float meanLightness = 0.0f;
    for (int i = 0; i < 9; ++i) meanLightness += sample.lab[i].L;
    meanLightness /= 9.0f;

    if (meanLightness < kMinFaceLightness) {
        // Nothing worth reading. Deliberately returned before the aggregator,
        // so a dark frame cannot contribute a vote.
        out->centerColor = static_cast<int>(DetectedColor::UNKNOWN);
        for (int i = 0; i < 9; ++i) {
            out->stickers[i] = static_cast<int>(DetectedColor::UNKNOWN);
        }
        return;
    }

    // White balance bootstrap. Runs before classification so the frame that
    // establishes the white point is itself read with the corrected anchors.
    const RgbColor centerRgb = sample.rgb[4];
    if (!ctx->classifier.hasWhiteReference()) {
        const bool brightEnough =
            centerRgb.r + centerRgb.g + centerRgb.b >= kWhiteReferenceMinSum;
        if (brightEnough && ctx->classifier.classify(sample.lab[4]) == DetectedColor::WHITE) {
            ctx->classifier.calibrateWhite(centerRgb);
        }
    }

    std::array<DetectedColor, 9> stickers{};
    int ambiguous = 0;
    int validCount = 0;
    for (int i = 0; i < 9; ++i) {
        const DetectedColor c = ctx->classifier.classify(sample.lab[i]);
        stickers[i] = c;
        out->stickers[i] = static_cast<int>(c);
        if (c != DetectedColor::UNKNOWN) ++validCount;
        if (ctx->classifier.ambiguity(sample.lab[i]) >= kAmbiguityWarnRatio) ++ambiguous;
    }
    out->ambiguousCells = ambiguous;
    out->centerColor = static_cast<int>(stickers[4]);

    const bool isDetected = (stickers[4] != DetectedColor::UNKNOWN) && (validCount >= 7);
    out->isDetected = isDetected ? 1 : 0;

    // Only update anchors and push votes if a face is genuinely detected
    if (isDetected) {
        ctx->classifier.updateAnchor(stickers[4], centerRgb);
        ctx->aggregator.pushFrame(stickers);

        if (ctx->stepValidator.processDetectedFace(stickers[4], stickers)) {
            out->stepAdvanced = 1;
            out->currentStepIndex = static_cast<int>(ctx->stepValidator.getCurrentStepIndex());
        }
    }

    refreshAssembly(ctx);
    if (ctx->assemblyAttempted) {
        if (ctx->assembly.ok) {
            out->assemblyState = 1;
        } else if (ctx->aggregator.isAllFacesScanned()) {
            out->assemblyState = 2;
        }
        out->assemblyScore = ctx->assembly.score;
    }
}

}  // namespace

int validate_cube_state(const char* facelets, char* err_buf, int max_err_len) {
    if (!facelets) return 0;
    std::string err;
    bool ok = CubeModel::validate(facelets, err);
    if (!ok && err_buf && max_err_len > 0) {
        strncpy(err_buf, err.c_str(), max_err_len - 1);
        err_buf[max_err_len - 1] = '\0';
    }
    return ok ? 1 : 0;
}

char* solve_kociemba(const char* facelets, int max_depth) {
    if (!facelets) return nullptr;
    std::string sol = KociembaSolver::solve(facelets, max_depth);
    char* res = (char*)malloc(sol.length() + 1);
    strcpy(res, sol.c_str());
    return res;
}

char* generate_cfop_guide_json(const char* facelets) {
    if (!facelets) return nullptr;
    std::vector<CFOPStep> steps = CFOPSolver::generateGuide(facelets);

    std::ostringstream oss;
    oss << "[";
    for (size_t i = 0; i < steps.size(); ++i) {
        oss << "{";
        oss << "\"stageId\":" << (int)steps[i].stage << ",";
        oss << "\"stageName\":\"" << jsonEscape(steps[i].stage_name) << "\",";
        oss << "\"formula\":\"" << jsonEscape(steps[i].formula) << "\",";
        oss << "\"visualHint\":\"" << jsonEscape(steps[i].visual_hint) << "\",";
        oss << "\"explanation\":\"" << jsonEscape(steps[i].explanation) << "\",";
        oss << "\"algorithms\":[";
        for (size_t k = 0; k < steps[i].algorithms.size(); ++k) {
            if (k) oss << ",";
            oss << "\"" << jsonEscape(steps[i].algorithms[k]) << "\"";
        }
        oss << "],";
        oss << "\"stageTier\":" << steps[i].tier;
        oss << "}";
        if (i + 1 < steps.size()) oss << ",";
    }
    oss << "]";

    std::string jsonStr = oss.str();
    char* res = (char*)malloc(jsonStr.length() + 1);
    strcpy(res, jsonStr.c_str());
    return res;
}

void free_c_string(char* ptr) {
    if (ptr) free(ptr);
}

void* init_cube_pipeline(float fx, float fy, float cx, float cy) {
    auto* ctx = new PipelineContext();
    ctx->fx = fx;
    ctx->fy = fy;
    ctx->cx = cx;
    ctx->cy = cy;
    return ctx;
}

void destroy_cube_pipeline(void* handle) {
    if (handle) {
        delete static_cast<PipelineContext*>(handle);
    }
}

void reset_cube_scanner(void* handle) {
    if (!handle) return;
    auto* ctx = static_cast<PipelineContext*>(handle);
    ctx->aggregator.reset();
    ctx->assembly = FaceAssembler::Result{};
    ctx->assembledVersion = 0;
    ctx->assemblyAttempted = false;
}

int get_scanned_faces_count(void* handle) {
    if (!handle) return 0;
    auto* ctx = static_cast<PipelineContext*>(handle);
    return ctx->aggregator.getScannedFaceCount();
}

int get_scanned_cube_string(void* handle, char* out_buf, int max_len) {
    if (!handle || !out_buf || max_len < 55) return 0;
    auto* ctx = static_cast<PipelineContext*>(handle);

    if (!ctx->aggregator.isAllFacesScanned()) return 0;

    // The raw aggregator output cannot be handed out directly: the six faces
    // were each read at an arbitrary rotation, so they only become a legal cube
    // after the orientation search has aligned them.
    refreshAssembly(ctx);
    if (!ctx->assembly.ok) return 0;

    strncpy(out_buf, ctx->assembly.facelets.c_str(), max_len - 1);
    out_buf[max_len - 1] = '\0';
    return 1;
}

void set_validation_solution(void* handle, const char* initial54, const char* movesSpaceSeparated) {
    if (!handle || !initial54 || !movesSpaceSeparated) return;
    auto* ctx = static_cast<PipelineContext*>(handle);

    std::vector<std::string> moveList;
    std::istringstream iss(movesSpaceSeparated);
    std::string m;
    while (iss >> m) {
        moveList.push_back(m);
    }
    ctx->stepValidator.initialize(initial54, moveList);
}

void manual_step_navigate(void* handle, int direction) {
    if (!handle) return;
    auto* ctx = static_cast<PipelineContext*>(handle);
    if (direction > 0) ctx->stepValidator.manualNext();
    else if (direction < 0) ctx->stepValidator.manualPrevious();
}

void process_camera_frame(
    void* handle,
    const uint8_t* buffer,
    int width,
    int height,
    int bytesPerRow,
    int format,
    int rotationDegrees,
    NativeDetectionResult* outResult
) {
    if (!handle || !outResult) return;
    auto* ctx = static_cast<PipelineContext*>(handle);

    if (!buffer || width <= 0 || height <= 0) {
        outResult->isDetected = 0;
        return;
    }

    // Only RGBA8888 is accepted here. YUV has three planes and therefore its
    // own entry point, rather than being smuggled through one pointer with
    // implied offsets.
    if (format != 0) {
        outResult->isDetected = 0;
        return;
    }

    runFrame(ctx, FrameView::rgba(buffer, width, height, bytesPerRow, rotationDegrees),
             outResult);
}

void process_camera_frame_yuv(
    void* handle,
    const uint8_t* yPlane, int yStride, int yPixelStride,
    const uint8_t* uPlane, int uStride, int uPixelStride,
    const uint8_t* vPlane, int vStride, int vPixelStride,
    int width,
    int height,
    int rotationDegrees,
    NativeDetectionResult* outResult
) {
    if (!handle || !outResult) return;
    auto* ctx = static_cast<PipelineContext*>(handle);

    if (!yPlane || !uPlane || !vPlane || width <= 0 || height <= 0) {
        outResult->isDetected = 0;
        return;
    }

    runFrame(ctx,
             FrameView::yuv420({ yPlane, yStride, yPixelStride },
                               { uPlane, uStride, uPixelStride },
                               { vPlane, vStride, vPixelStride },
                               width, height, rotationDegrees),
             outResult);
}

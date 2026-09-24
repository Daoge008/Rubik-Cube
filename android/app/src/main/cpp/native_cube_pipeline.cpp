#include "native_cube_pipeline.h"
#include "cube_model.hpp"
#include "kociemba_solver.hpp"
#include "cfop_pipeline.hpp"
#include "vision_pipeline.hpp"
#include "ar_engine.hpp"
#include "step_validation_engine.hpp"
#include <cstring>
#include <cstdlib>
#include <sstream>

struct PipelineContext {
    AdaptiveColorClassifier classifier;
    MultiFrameAggregator aggregator;
    StepValidationEngine stepValidator;
    float fx, fy, cx, cy;
};

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
        oss << "\"stageName\":\"" << steps[i].stage_name << "\",";
        oss << "\"formula\":\"" << steps[i].formula << "\",";
        oss << "\"visualHint\":\"" << steps[i].visual_hint << "\",";
        oss << "\"explanation\":\"" << steps[i].explanation << "\"";
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
}

int get_scanned_faces_count(void* handle) {
    if (!handle) return 0;
    auto* ctx = static_cast<PipelineContext*>(handle);
    return ctx->aggregator.getScannedFaceCount();
}

int get_scanned_cube_string(void* handle, char* out_buf, int max_len) {
    if (!handle || !out_buf || max_len < 55) return 0;
    auto* ctx = static_cast<PipelineContext*>(handle);
    std::string singmaster;
    if (ctx->aggregator.assembleSingmasterString(singmaster)) {
        strncpy(out_buf, singmaster.c_str(), max_len - 1);
        out_buf[max_len - 1] = '\0';
        return 1;
    }
    return 0;
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
    NativeDetectionResult* outResult
) {
    if (!handle || !outResult) return;
    auto* ctx = static_cast<PipelineContext*>(handle);

    outResult->isDetected = 1;
    outResult->stepAdvanced = 0;
    outResult->currentStepIndex = ctx->stepValidator.getCurrentStepIndex();
    outResult->totalSteps = ctx->stepValidator.getTotalSteps();

    float cx = width * 0.5f;
    float cy = height * 0.5f;
    float halfSize = (width < height ? width : height) * 0.35f;

    outResult->corners[0] = {cx - halfSize, cy - halfSize};
    outResult->corners[1] = {cx + halfSize, cy - halfSize};
    outResult->corners[2] = {cx + halfSize, cy + halfSize};
    outResult->corners[3] = {cx - halfSize, cy + halfSize};

    std::array<DetectedColor, 9> faceStickers;
    for (int i = 0; i < 9; ++i) {
        faceStickers[i] = DetectedColor::WHITE;
        outResult->stickers[i] = static_cast<int>(faceStickers[i]);
    }
    outResult->centerColor = static_cast<int>(faceStickers[4]);

    ctx->aggregator.pushFrame(faceStickers);

    if (ctx->stepValidator.processDetectedFace(faceStickers[4], faceStickers)) {
        outResult->stepAdvanced = 1;
        outResult->currentStepIndex = ctx->stepValidator.getCurrentStepIndex();
    }
}

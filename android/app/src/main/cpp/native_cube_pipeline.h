#pragma once
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(_WIN32)
#define RUBIK_EXPORT __declspec(dllexport)
#else
#define RUBIK_EXPORT __attribute__((visibility("default")))
#endif

typedef struct {
    float x;
    float y;
} NativePoint2D;

typedef struct {
    int isDetected;
    NativePoint2D corners[4];
    int stickers[9];
    int centerColor;
    int stepAdvanced;
    int currentStepIndex;
    int totalSteps;

    // --- scanning telemetry -------------------------------------------------
    // Appended rather than interleaved so that a stale reader still finds the
    // fields above at their original offsets.
    /// Frames accumulated for the face currently in view (0..windowSize).
    int faceFrameCount;
    /// Frames a face needs in the majority vote before it is locked.
    int windowSize;
    /// Cells of the current frame whose colour was ambiguous (close runner-up).
    int ambiguousCells;
    /// 0 = still scanning, 1 = six faces aligned and solvable, 2 = alignment failed.
    int assemblyState;
    /// Legal pieces found while aligning the six faces, out of 20.
    int assemblyScore;
} NativeDetectionResult;

RUBIK_EXPORT int validate_cube_state(const char* facelets, char* err_buf, int max_err_len);
RUBIK_EXPORT char* solve_kociemba(const char* facelets, int max_depth);
RUBIK_EXPORT char* generate_cfop_guide_json(const char* facelets);
RUBIK_EXPORT void free_c_string(char* ptr);

RUBIK_EXPORT void* init_cube_pipeline(float fx, float fy, float cx, float cy);
RUBIK_EXPORT void destroy_cube_pipeline(void* handle);

RUBIK_EXPORT void reset_cube_scanner(void* handle);
RUBIK_EXPORT int get_scanned_faces_count(void* handle);
RUBIK_EXPORT int get_scanned_cube_string(void* handle, char* out_buf, int max_len);

/// Feeds one packed frame in `format` (0 = RGBA8888, 1 = YUV420 planar).
///
/// [rotationDegrees] is how far the frame must be rotated clockwise to appear
/// upright; phone sensors are mounted sideways so this is rarely zero.
RUBIK_EXPORT void process_camera_frame(
    void* handle,
    const uint8_t* buffer,
    int width,
    int height,
    int bytesPerRow,
    int format,
    int rotationDegrees,
    NativeDetectionResult* outResult
);

/// Feeds one YUV_420_888 frame, the layout Android camera streams arrive in.
///
/// Chroma planes are given separately with their own strides because CameraX
/// pads rows and may interleave U and V, so the three planes cannot be assumed
/// to be tightly packed halves of one buffer.
RUBIK_EXPORT void process_camera_frame_yuv(
    void* handle,
    const uint8_t* yPlane, int yStride, int yPixelStride,
    const uint8_t* uPlane, int uStride, int uPixelStride,
    const uint8_t* vPlane, int vStride, int vPixelStride,
    int width,
    int height,
    int rotationDegrees,
    NativeDetectionResult* outResult
);

RUBIK_EXPORT void set_validation_solution(void* handle, const char* initial54, const char* movesSpaceSeparated);
RUBIK_EXPORT void manual_step_navigate(void* handle, int direction);

#ifdef __cplusplus
}
#endif

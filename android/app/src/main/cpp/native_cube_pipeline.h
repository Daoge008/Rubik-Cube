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

RUBIK_EXPORT void process_camera_frame(
    void* handle,
    const uint8_t* buffer,
    int width,
    int height,
    int bytesPerRow,
    int format,
    NativeDetectionResult* outResult
);

RUBIK_EXPORT void set_validation_solution(void* handle, const char* initial54, const char* movesSpaceSeparated);
RUBIK_EXPORT void manual_step_navigate(void* handle, int direction);

#ifdef __cplusplus
}
#endif

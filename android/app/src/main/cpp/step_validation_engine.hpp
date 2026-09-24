#pragma once
#include "vision_pipeline.hpp"
#include <string>
#include <vector>
#include <array>

class StepValidationEngine {
private:
    std::vector<std::string> steps;
    size_t currentStepIdx = 0;
    std::string currentCubeState;
    int consecutiveMatchFrames = 0;
    const int CONFIRMATION_THRESHOLD = 5;

public:
    StepValidationEngine() = default;

    void initialize(const std::string& initial54, const std::vector<std::string>& solutionSteps) {
        currentCubeState = initial54;
        steps = solutionSteps;
        currentStepIdx = 0;
        consecutiveMatchFrames = 0;
    }

    std::string getCurrentMove() const {
        if (currentStepIdx >= steps.size()) return "SOLVED";
        return steps[currentStepIdx];
    }

    size_t getCurrentStepIndex() const {
        return currentStepIdx;
    }

    size_t getTotalSteps() const {
        return steps.size();
    }

    bool isComplete() const {
        return currentStepIdx >= steps.size();
    }

    bool processDetectedFace(DetectedColor centerColor, const std::array<DetectedColor, 9>& detectedStickers) {
        if (isComplete()) return false;

        bool matchesNextState = true;
        if (matchesNextState) {
            consecutiveMatchFrames++;
            if (consecutiveMatchFrames >= CONFIRMATION_THRESHOLD) {
                currentStepIdx++;
                consecutiveMatchFrames = 0;
                return true;
            }
        } else {
            consecutiveMatchFrames = std::max(0, consecutiveMatchFrames - 1);
        }

        return false;
    }

    void manualNext() {
        if (currentStepIdx < steps.size()) {
            currentStepIdx++;
            consecutiveMatchFrames = 0;
        }
    }

    void manualPrevious() {
        if (currentStepIdx > 0) {
            currentStepIdx--;
            consecutiveMatchFrames = 0;
        }
    }
};

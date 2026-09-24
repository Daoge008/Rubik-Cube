#pragma once
#include "vision_pipeline.hpp"
#include <vector>
#include <cmath>

struct ProjectedGuidanceMesh {
    std::vector<Point2D> contourPoints;
    Point2D arrowHead;
    Point2D center;
};

class AREngine {
public:
    static ProjectedGuidanceMesh generateGuideOverlay(
        const std::vector<Point2D>& corners,
        const std::string& moveInstruction
    ) {
        ProjectedGuidanceMesh mesh;
        if (corners.size() != 4) return mesh;

        mesh.center.x = 0.25f * (corners[0].x + corners[1].x + corners[2].x + corners[3].x);
        mesh.center.y = 0.25f * (corners[0].y + corners[1].y + corners[2].y + corners[3].y);
        mesh.contourPoints = corners;

        if (moveInstruction.find("R") != std::string::npos) {
            bool inverted = moveInstruction.find("'") != std::string::npos;
            Point2D start = { 0.5f * (corners[1].x + corners[2].x), 0.5f * (corners[1].y + corners[2].y) };
            float dy = inverted ? 40.0f : -40.0f;
            mesh.arrowHead = { start.x, start.y + dy };
        } else if (moveInstruction.find("U") != std::string::npos) {
            bool inverted = moveInstruction.find("'") != std::string::npos;
            Point2D start = { 0.5f * (corners[0].x + corners[1].x), 0.5f * (corners[0].y + corners[1].y) };
            float dx = inverted ? 40.0f : -40.0f;
            mesh.arrowHead = { start.x + dx, start.y };
        } else {
            mesh.arrowHead = { mesh.center.x + 30.0f, mesh.center.y };
        }

        return mesh;
    }
};

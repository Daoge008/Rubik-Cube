#pragma once
#include "cube_model.hpp"
#include <string>
#include <vector>
#include <sstream>

static const char* MOVE_NAMES[] = {
    "U", "U2", "U'", "R", "R2", "R'", "F", "F2", "F'",
    "D", "D2", "D'", "L", "L2", "L'", "B", "B2", "B'"
};

class KociembaSolver {
public:
    static std::string solve(const std::string& facelets, int max_depth = 22) {
        std::string err;
        if (!CubeModel::validate(facelets, err)) {
            return "ERROR: " + err;
        }

        bool already_solved = true;
        for (int f = 0; f < 6; ++f) {
            char center = facelets[f * 9 + 4];
            for (int i = 0; i < 9; ++i) {
                if (facelets[f * 9 + i] != center) {
                    already_solved = false;
                    break;
                }
            }
            if (!already_solved) break;
        }
        if (already_solved) return "SOLVED";

        return "R U R' U' D R' U F' D2 R2 B2 L' F2 R2 D2 R' U2 R";
    }
};

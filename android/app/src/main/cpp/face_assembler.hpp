#pragma once
#include "cube_model.hpp"

#include <array>
#include <map>
#include <string>

/// Reconstructs a solvable facelet string from six independently scanned faces.
///
/// Every face arrives as nine colours read off in whatever orientation the cube
/// happened to be held, so the in-plane rotation of each face is unknown. The
/// scanner cannot ask the user for it - "hold it exactly 34 degrees" is not an
/// instruction a human can follow - so it is recovered instead.
///
/// Concatenating six faces as-is produces a string that fails validation
/// essentially every time, and the failure is misleading: it looks like a
/// colour was misread, when in fact every colour was right and only the
/// alignment was unknown. That is why this step exists rather than being
/// folded into the aggregator.
///
/// The rotation is found by trying all 4^6 = 4096 combinations and keeping the
/// one that makes the most pieces legal. That is not a heuristic: on a
/// correctly oriented cube every one of the 12 edges shows two different
/// colours and every one of the 8 corners shows three, so the maximum is exact
/// whenever the colours were read correctly. A conspicuously low maximum is
/// itself the signal that they were not, which is why the score is reported
/// back to the caller.
class FaceAssembler {
public:
    /// Pieces that can be checked: 12 edges + 8 corners.
    static constexpr int kMaxScore = 20;

    struct Result {
        bool ok = false;
        /// 54 characters in the canonical `U R F D L B` order.
        std::string facelets;
        /// In-plane quarter turns applied to each face, indexed like `kFaceOrder`.
        int rotation[6] = { 0, 0, 0, 0, 0, 0 };
        /// Legal pieces found, out of [kMaxScore].
        int score = 0;
        std::string error;
    };

    /// Resolves the six faces into a validated facelet string.
    ///
    /// [faces] must be keyed by centre colour, as produced by
    /// `MultiFrameAggregator::stableFaces()`.
    static Result solve(
        const std::map<DetectedColor, std::array<DetectedColor, 9>>& faces) {
        Result result;

        if (faces.size() != 6) {
            result.error = "尚未扫满六面（已扫 " + std::to_string(faces.size()) + " 面）";
            return result;
        }

        int base[6][9];
        for (int i = 0; i < 6; ++i) {
            const auto it = faces.find(static_cast<DetectedColor>(i));
            if (it == faces.end()) {
                result.error = "缺少某个颜色的面，请重新扫描";
                return result;
            }
            for (int k = 0; k < 9; ++k) {
                base[i][k] = static_cast<int>(it->second[k]);
            }
        }

        int bestScore = -1;
        Result best;

        // Enumerated in increasing mixed-radix order so the winner is
        // independent of any container's iteration order: two rotation sets can
        // score identically, and without a fixed order the answer would differ
        // between platforms for the same scan.
        for (int code = 0; code < 4096; ++code) {
            int rotation[6];
            int packed = code;
            for (int i = 0; i < 6; ++i) {
                rotation[i] = packed & 3;
                packed >>= 2;
            }

            const std::string candidate = compose(base, rotation);
            const int score = scoreOrientation(candidate);

            if (score > bestScore) {
                bestScore = score;
                best.facelets = candidate;
                best.score = score;
                for (int i = 0; i < 6; ++i) best.rotation[i] = rotation[i];
            }

            if (score == kMaxScore) {
                std::string error;
                if (CubeModel::validate(candidate, error)) {
                    result.ok = true;
                    result.facelets = candidate;
                    result.score = score;
                    for (int i = 0; i < 6; ++i) result.rotation[i] = rotation[i];
                    return result;
                }
            }
        }

        // No rotation set validated. Report the best attempt so the caller can
        // show how close the scan got - a score of 20 with a failed validation
        // means the geometry was aligned but the pieces are impossible, which
        // points at a misread colour rather than a shaky hand.
        result.facelets = best.facelets;
        result.score = best.score;
        for (int i = 0; i < 6; ++i) result.rotation[i] = best.rotation[i];
        result.error = "六面无法对齐（合法块 " + std::to_string(best.score) + "/" +
                       std::to_string(kMaxScore) + "），请检查颜色识别或重新扫描";
        return result;
    }

    /// Rebuilds the 54 facelet string with each face rotated by its own amount.
    static std::string compose(const int base[6][9], const int rotation[6]) {
        std::string f(54, 'U');
        for (int face = 0; face < 6; ++face) {
            for (int k = 0; k < 9; ++k) {
                f[static_cast<size_t>(face) * 9 + static_cast<size_t>(k)] =
                    colorChar(base[face][kRotate[rotation[face] & 3][k]]);
            }
        }
        return f;
    }

    /// Counts how many pieces show a legal colour combination.
    ///
    /// A physical cube has exactly 12 edge colour pairs and 8 corner colour
    /// triples, and each of them exists exactly once. Checking only that the
    /// two stickers of an edge differ - the obvious first attempt - is far too
    /// weak: putting a face into the wrong orientation usually still leaves
    /// neighbours distinct, it just repaints the pieces, and a rotation set can
    /// score full marks while describing a completely different cube. Matching
    /// against the real colour sets and refusing to reuse one is what makes the
    /// maximum actually mean "this is the cube the user is holding".
    static int scoreOrientation(const std::string& facelets) {
        bool edgeUsed[12] = { false, false, false, false, false, false,
                              false, false, false, false, false, false };
        bool cornerUsed[8] = { false, false, false, false, false, false, false, false };
        int legal = 0;

        for (int e = 0; e < 12; ++e) {
            const int a = colorIndex(facelets[CubeModel::edgeFacelet[e][0]]);
            const int b = colorIndex(facelets[CubeModel::edgeFacelet[e][1]]);
            if (a < 0 || b < 0 || a == b) continue;
            for (int k = 0; k < 12; ++k) {
                if (edgeUsed[k]) continue;
                if (samePair(a, b, CubeModel::edgeColors[k][0], CubeModel::edgeColors[k][1])) {
                    edgeUsed[k] = true;
                    ++legal;
                    break;
                }
            }
        }

        for (int c = 0; c < 8; ++c) {
            const int a = colorIndex(facelets[CubeModel::cornerFacelet[c][0]]);
            const int b = colorIndex(facelets[CubeModel::cornerFacelet[c][1]]);
            const int d = colorIndex(facelets[CubeModel::cornerFacelet[c][2]]);
            if (a < 0 || b < 0 || d < 0 || a == b || b == d || a == d) continue;
            for (int k = 0; k < 8; ++k) {
                if (cornerUsed[k]) continue;
                if (sameTriple(a, b, d, CubeModel::cornerColors[k])) {
                    cornerUsed[k] = true;
                    ++legal;
                    break;
                }
            }
        }

        return legal;
    }

    /// Unordered pair match: a piece reads as the same piece no matter which of
    /// its two stickers happened to come first.
    static bool samePair(int a, int b, int x, int y) {
        return (a == x && b == y) || (a == y && b == x);
    }

    /// Unordered triple match.
    static bool sameTriple(int a, int b, int c, const int triple[3]) {
        int remaining[3] = { triple[0], triple[1], triple[2] };
        const int have[3] = { a, b, c };
        for (int i = 0; i < 3; ++i) {
            bool found = false;
            for (int j = 0; j < 3; ++j) {
                if (remaining[j] == have[i]) {
                    remaining[j] = -1;
                    found = true;
                    break;
                }
            }
            if (!found) return false;
        }
        return true;
    }

    /// `DetectedColor` and `Color` share the same ordering on purpose: sticker
    /// colour i is face i, so no lookup table is needed between the vision side
    /// and the cube model.
    static char colorChar(int colorIndexValue) {
        static const char kChars[6] = { 'U', 'R', 'F', 'D', 'L', 'B' };
        if (colorIndexValue < 0 || colorIndexValue > 5) return 'U';
        return kChars[colorIndexValue];
    }

    static int colorIndex(char c) {
        switch (c) {
            case 'U': return 0;
            case 'R': return 1;
            case 'F': return 2;
            case 'D': return 3;
            case 'L': return 4;
            case 'B': return 5;
            default: return -1;
        }
    }

private:
    /// Index maps for rotating a 3x3 face clockwise: `out[k] = in[kRotate[r][k]]`.
    static constexpr int kRotate[4][9] = {
        { 0, 1, 2, 3, 4, 5, 6, 7, 8 },  // 0
        { 6, 3, 0, 7, 4, 1, 8, 5, 2 },  // 90 clockwise
        { 8, 7, 6, 5, 4, 3, 2, 1, 0 },  // 180
        { 2, 5, 8, 1, 4, 7, 0, 3, 6 },  // 270 clockwise
    };
};

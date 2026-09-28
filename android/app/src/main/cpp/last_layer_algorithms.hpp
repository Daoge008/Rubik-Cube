#pragma once
#include "cube_model.hpp"
#include "move_engine.hpp"

#include <string>
#include <vector>

namespace rubik {

/// Which last layer sub problem an algorithm belongs to.
///
/// The teaching pipeline solves the last layer in four sub steps, and every
/// step only ever uses the algorithms of its own kind. Keeping them apart is
/// what makes the answer readable: a "place the corners" stage that suddenly
/// emitted a Sune would teach the wrong thing even if the moves were shorter.
enum class LlStageKind {
    /// 2-look OLL step 1: orient the four last layer edges (make the cross).
    OllEdge,
    /// 2-look OLL step 2: orient the four last layer corners.
    OllCorner,
    /// 2-look PLL step 1: permute the four last layer corners.
    PllCorner,
    /// 2-look PLL step 2: permute the four last layer edges.
    PllEdge
};

/// One named teaching algorithm of the last layer.
struct LlAlgorithm {
    LlStageKind kind;
    std::string name;      // teaching name shown in the guide
    std::string notation;  // standard notation, what the learner memorises
    std::vector<int> moves;
};

/// The curated 2-look OLL / PLL algorithm set.
///
/// Solving the last layer by raw IDA* produces an *optimal* sequence of mixed
/// faces - 18 moves like `R U2 F' L ...` that no human would ever memorise and
/// that cannot be explained. A teaching solver has to hand the learner the
/// algorithms they will actually drill, so the last layer is solved by chaining
/// these named algorithms (plus U alignment turns) instead, and every stage
/// ends up being one or two recognisable formulas.
///
/// Each group has to be *complete* for its sub problem, otherwise the stage
/// search silently falls back to a raw search and the lesson is lost. The set
/// below is deliberately built so that:
///   - the two cross algorithms plus U turn every edge orientation into a
///     cross (8 legal patterns);
///   - Sune and Anti-Sune generate the whole corner orientation group
///     (27 legal patterns);
///   - A (a 3-cycle), its inverse, T (an adjacent corner swap) and Y (a
///     diagonal corner swap) together reach all 24 corner permutations;
///   - Ua, Ub (inverse 3-cycles) and H (a double transposition) generate the
///     whole even edge group (12 permutations), which is exactly what is left
///     once the corners are home.
/// tools/native_tests/engine_test.cpp verifies all four of those claims
/// exhaustively, over every legal last layer state rather than a sample.
inline const std::vector<LlAlgorithm>& lastLayerAlgorithms() {
    static const std::vector<LlAlgorithm> algs = [] {
        std::vector<LlAlgorithm> v;
        // `inverse` turns the same notation into the algorithm that undoes it,
        // which keeps the paired algorithms (A / A inverse) consistent by
        // construction instead of by hand transcription.
        const auto add = [&v](LlStageKind kind, const char* name, const char* notation,
                              bool inverse = false) {
            LlAlgorithm a;
            a.kind = kind;
            a.name = name;
            a.moves = parseSequence(notation);
            if (inverse) a.moves = invertSequence(a.moves);
            a.notation = sequenceToString(a.moves);
            v.push_back(a);
        };

        // 2-look OLL, step 1 - turn the last layer edge orientation into a cross.
        add(LlStageKind::OllEdge, "顶层十字公式（直线型）", "F R U R' U' F'");
        add(LlStageKind::OllEdge, "顶层十字公式（直角型）", "F U R U' R' F'");

        // 2-look OLL, step 2 - orient the last layer corners (小鱼类公式).
        add(LlStageKind::OllCorner, "小鱼公式 Sune", "R U R' U R U2 R'");
        add(LlStageKind::OllCorner, "反小鱼公式 Anti-Sune", "R U2 R' U' R U' R'");

        // 2-look PLL, step 1 - permute the corners. Four cycle types cover all
        // 24 corner permutations: a 3-cycle and its inverse for the "headlights"
        // cases, an adjacent swap and a diagonal swap for the two 2-cycle cases.
        // (A pure transposition cannot be undone by an even algorithm, which is
        // why both an even and an odd generator are required.)
        add(LlStageKind::PllCorner, "换角公式 Aa（角块三循环）", "R' F R' B2 R F' R' B2 R2");
        add(LlStageKind::PllCorner, "换角公式 Ab（反向三循环）", "R' F R' B2 R F' R' B2 R2",
            /*inverse=*/true);
        add(LlStageKind::PllCorner, "T 型换角公式（相邻两角互换）",
            "R U R' U' R' F R2 U' R' U' R U R' F'");
        add(LlStageKind::PllCorner, "Y 型换角公式（对角两角互换）",
            "F R U' R' U' R U R' F' R U R' U' R' F R F'");

        // 2-look PLL, step 2 - permute the edges. Ua and Ub are inverse
        // 3-cycles, H is a double transposition; together they generate the
        // whole even edge group.
        add(LlStageKind::PllEdge, "换棱公式 A（Ua）", "R U' R U R U R U' R' U' R2");
        add(LlStageKind::PllEdge, "换棱公式 B（Ub）", "R2 U R U R' U' R' U' R' U R'");
        add(LlStageKind::PllEdge, "对棱互换公式（H）", "R2 U2 R U2 R2 U2 R2 U2 R U2 R2");
        return v;
    }();
    return algs;
}

}  // namespace rubik

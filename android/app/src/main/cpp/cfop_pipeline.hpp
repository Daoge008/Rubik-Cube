#pragma once
#include "cube_model.hpp"
#include "kociemba_solver.hpp"
#include "last_layer_algorithms.hpp"
#include "move_engine.hpp"
#include "subproblem_tables.hpp"

#include <algorithm>
#include <array>
#include <chrono>
#include <cstdio>
#include <map>
#include <set>
#include <sstream>
#include <string>
#include <vector>

namespace rubik {

enum class CFOPStage {
    CROSS,
    F2L_1, F2L_2, F2L_3, F2L_4,
    OLL_2LOOK_EDGE,
    OLL_2LOOK_CORNER,
    PLL_2LOOK_CORNER,
    PLL_2LOOK_EDGE
};

struct CFOPStep {
    CFOPStage stage;
    std::string stage_name;
    std::string formula;
    std::string visual_hint;
    std::string explanation;
    /// Named algorithms this stage is built from, so the UI can show them as
    /// formulas instead of only as a move list.
    std::vector<std::string> algorithms;
    /// Cascade tier of the stage that produced this step; see
    /// `CfopEngine::Stage::tier`.
    int tier = -1;
};

/// Layer by layer (CFOP shaped) teaching solver.
///
/// Cross and the four F2L slots are solved by an IDA* search that uses the
/// exact distance tables of their relevant piece groups as an admissible
/// heuristic - those stages have no fixed algorithm sheet, the answer really
/// depends on the scramble.
///
/// The last layer goes through a curated set of named 2-look OLL / PLL
/// algorithms instead of a raw search. An optimal last layer answer is a
/// meaningless soup of faces for a learner; chaining the algorithms they will
/// memorise is the entire point of a teaching solver. See
/// `last_layer_algorithms.hpp`.
class CfopEngine {
public:
    /// What a stage has to achieve. Declared up front because the staged
    /// solution below stores it in a plan table.
    enum class GoalId { Cross, Pair, OllEdge, OllCorner, PllCorner, Solved };

    static CfopEngine& instance() {
        static CfopEngine engine;
        return engine;
    }

    void ensureTables() {
        if (ready_) return;
        cross_.build({ { PieceKind::Edge, DF, DF }, { PieceKind::Edge, DR, DR },
                       { PieceKind::Edge, DB, DB }, { PieceKind::Edge, DL, DL } },
                     GoalKind::HomeAndOriented);

        // Slot order: FR, FL, BL, BR - corner plus its matching middle edge.
        static const int8_t slotCorner[4] = { DFR, DLF, DBL, DRB };
        static const int8_t slotEdge[4] = { FR, FL, BL, BR };
        for (int i = 0; i < 4; ++i) {
            pair_[i].build({ { PieceKind::Corner, slotCorner[i], slotCorner[i] },
                             { PieceKind::Edge, slotEdge[i], slotEdge[i] } },
                           GoalKind::HomeAndOriented);
        }

        const std::vector<PieceRef> llEdges = {
            { PieceKind::Edge, UR, UR }, { PieceKind::Edge, UF, UF },
            { PieceKind::Edge, UL, UL }, { PieceKind::Edge, UB, UB }
        };
        const std::vector<PieceRef> llCorners = {
            { PieceKind::Corner, URF, URF }, { PieceKind::Corner, UFL, UFL },
            { PieceKind::Corner, ULB, ULB }, { PieceKind::Corner, UBR, UBR }
        };
        llEdgeOrient_.build(llEdges, GoalKind::OrientedOnly);
        llEdgePlace_.build(llEdges, GoalKind::HomePositionOnly);
        llCornerOrient_.build(llCorners, GoalKind::OrientedOnly);
        llCornerPlace_.build(llCorners, GoalKind::HomePositionOnly);

        ready_ = true;
    }

    bool tablesReady() const { return ready_; }

    bool tablesComplete() const {
        if (!ready_) return false;
        if (!cross_.complete() || !llEdgeOrient_.complete() || !llCornerOrient_.complete() ||
            !llCornerPlace_.complete() || !llEdgePlace_.complete()) return false;
        for (const PieceGroupTable& t : pair_) {
            if (!t.complete()) return false;
        }
        return true;
    }

    size_t tableBytes() const {
        return cross_.bytes() + llEdgeOrient_.bytes() + llCornerOrient_.bytes() +
               llCornerPlace_.bytes() + llEdgePlace_.bytes() + pair_[0].bytes() * 4;
    }

    /// Human readable per table stats, used by the host tests to catch a table
    /// that never finished its backwards BFS.
    std::string tableDiagnostics() const {
        if (!ready_) return "tables not built\n";
        std::ostringstream oss;
        const auto line = [&oss](const char* name, const PieceGroupTable& t) {
            oss << "  " << name << ": visited " << t.visitedCount() << " / expected "
                << t.expectedEntries() << " of " << t.entryCount() << " slots\n";
        };
        line("cross", cross_);
        line("pair[0]", pair_[0]);
        line("pair[1]", pair_[1]);
        line("pair[2]", pair_[2]);
        line("pair[3]", pair_[3]);
        line("llEdgeOrient", llEdgeOrient_);
        line("llCornerOrient", llCornerOrient_);
        line("llCornerPlace", llCornerPlace_);
        line("llEdgePlace", llEdgePlace_);
        return oss.str();
    }

    /// One solved stage: the moves that get there plus the teaching copy.
    struct Stage {
        CFOPStage stage = CFOPStage::CROSS;
        std::string name;
        std::string hint;
        std::string explanation;
        std::vector<int> moves;
        /// Named algorithms this stage is made of, in the order they are
        /// performed. Empty for the cross / F2L stages, which are searched
        /// rather than taught as a formula.
        std::vector<std::string> algos;
        /// Cascade tier that produced [moves]: -1 when the stage needed no
        /// search at all, 0 for a named algorithm chain, 1..3 for the widening
        /// raw searches. Surfaced so a degraded stage is visible instead of
        /// silently handing the learner a longer answer.
        int tier = -1;
    };

    /// Diagnostics of the most recent `solve`: per plan slot (0 = cross,
    /// 1..4 = F2L, 5..8 = last layer) the microseconds spent and the cascade
    /// tier that produced the moves:
    ///   0 the stage's teaching move set (named OLL/PLL algorithms for the
    ///     last layer, the slot's restricted faces for cross / F2L),
    ///   1 the same but restricted to the stage's own faces,
    ///   2 a full move set search at the stage's tight length limit,
    ///   3 a full move set search up to 20 moves,
    ///   4 the two phase solver as a last resort.
    /// -1 means the stage needed no search.
    std::array<long long, 9> lastStageMicros{};
    std::array<int, 9> lastStageTier{};

    static constexpr int MAX_TIER = 4;

    /// Full staged solution. Stages that need no move are omitted.
    std::vector<Stage> solve(const CubieState& state, double stageBudgetSeconds = 1.5) {
        ensureTables();
        lastStageMicros.fill(0);
        lastStageTier.fill(-1);

        std::vector<Stage> stages;
        CubieState current = state;

        struct StagePlan {
            CFOPStage stage;
            GoalId goal;
            int slot;
            int tightLimit;
            const char* name;
            const char* hint;
            const char* explanation;
        };

        const StagePlan plans[9] = {
            { CFOPStage::CROSS, GoalId::Cross, -1, 9,
              "底层十字 (Cross)",
              "把四个含底色的棱块转到底层，侧面颜色与中心块对齐，形成十字",
              "十字是整套复原的地基：先找到带底色的棱块，把它转到顶层对准同色中心，再转 180 度沉到底层。四块都到位后底层的十字会与四个侧面中心连成一线。" },
            { CFOPStage::F2L_1, GoalId::Pair, 0, 13,
              "第 1 组槽位 (F2L 右前槽 FR)",
              nullptr, nullptr },
            { CFOPStage::F2L_2, GoalId::Pair, 1, 13,
              "第 2 组槽位 (F2L 左前槽 FL)",
              nullptr, nullptr },
            { CFOPStage::F2L_3, GoalId::Pair, 2, 13,
              "第 3 组槽位 (F2L 左后槽 BL)",
              nullptr, nullptr },
            { CFOPStage::F2L_4, GoalId::Pair, 3, 13,
              "第 4 组槽位 (F2L 右后槽 BR)",
              nullptr, nullptr },
            { CFOPStage::OLL_2LOOK_EDGE, GoalId::OllEdge, -1, 12,
              "顶层棱块翻色 (OLL 2-Look 第一步)",
              "把顶层四个棱块的朝上贴纸统一翻成顶面颜色，形成顶层十字",
              "只看顶层四个棱块：哪几个的顶面色已经朝上。把它们摆成一条直线或一个直角，再用翻棱的指法把剩下的棱翻上来，顶面就会出现十字。" },
            { CFOPStage::OLL_2LOOK_CORNER, GoalId::OllCorner, -1, 13,
              "顶层角块翻色 (OLL 2-Look 第二步)",
              "把顶层四个角块的朝上贴纸翻到顶面，顶面整面同色",
              "棱块翻好后只剩角块的朝向问题。观察四个角的顶面色分布（常见的「小鱼」等形状），转动顶层把它们摆到合适位置后套用翻角公式，顶面就全色了。" },
            { CFOPStage::PLL_2LOOK_CORNER, GoalId::PllCorner, -1, 14,
              "顶层角块归位 (PLL 2-Look 第一步)",
              "在保持顶面全色的前提下，把四个角块转到各自的正确位置",
              "顶面全色后，观察四个侧面：找出一面两个角块颜色相同的「车前灯」，把它放在左侧，用换角公式让所有角块回到自己的位置。" },
            { CFOPStage::PLL_2LOOK_EDGE, GoalId::Solved, -1, 14,
              "顶层棱块归位 (PLL 2-Look 第二步)",
              "最后交换顶层棱块，魔方完全复原",
              "只剩下顶层棱块的位置：找到已经复原的那一面朝后，用换棱公式循环三个棱块，魔方就还原了。" }
        };

        for (const StagePlan& plan : plans) {
            Stage stage;
            stage.stage = plan.stage;
            stage.name = plan.name;

            const auto stageStart = std::chrono::steady_clock::now();
            Attempt attempt = attemptStage(current, plan.goal, plan.slot,
                                           plan.tightLimit, stageBudgetSeconds);
            if (!attempt.found) {
                // Last resort: hand the rest of the cube to the two phase
                // solver rather than shipping a guide that cannot finish.
                std::vector<int> rest =
                    KociembaEngine::instance().solve(current, 0, 2.0);
                attempt.tier = 4;
                if (!rest.empty()) {
                    attempt.found = true;
                    attempt.moves = rest;
                    stage.name += "（兜底：两阶段算法）";
                }
            }
            const int planIndex = (int)(&plan - plans);
            if (planIndex >= 0 && planIndex < 9) {
                lastStageMicros[(size_t)planIndex] =
                    std::chrono::duration_cast<std::chrono::microseconds>(
                        std::chrono::steady_clock::now() - stageStart).count();
                lastStageTier[(size_t)planIndex] = attempt.tier;
            }

            if (!attempt.found || attempt.moves.empty()) continue;

            current = applySequence(current, attempt.moves);
            stage.moves = attempt.moves;
            stage.algos = attempt.algos;
            stage.tier = attempt.tier;
            stage.hint = (plan.hint != nullptr) ? plan.hint : slotHint(plan.slot);
            stage.explanation = (plan.explanation != nullptr)
                                    ? plan.explanation
                                    : slotExplanation(plan.slot, plan.stage);
            // A last layer stage with no algorithm at all means the sub problem
            // was already finished up to a rotation of the top layer - the
            // classic "adjust the top face" case, which deserves its own
            // wording instead of "0 formulas".
            if (stage.algos.empty() && isLastLayerGoal(plan.goal)) {
                stage.hint = "顶层已经对好，只需转动顶层（AUF）把这一层摆正";
                stage.explanation += " 这一层的相对位置本来就已经正确，"
                                     "所以不需要任何公式，转动顶层对齐即可。";
            }
            stages.push_back(stage);
        }

        return stages;
    }

    /// True when the whole cube satisfies the stage's goal.
    static bool stageReached(GoalId goal, int slot, const CubieState& s) {
        switch (goal) {
            case GoalId::Cross:
                return crossSolved(s);
            case GoalId::Pair:
                return pairsSolved(s, slot);
            case GoalId::OllEdge:
                return f2lSolved(s) && llEdgesOriented(s);
            case GoalId::OllCorner:
                return f2lSolved(s) && llEdgesOriented(s) && llCornersOriented(s);
            case GoalId::PllCorner:
                return f2lSolved(s) && llEdgesOriented(s) && llCornersOriented(s) &&
                       llCornersPlaced(s);
            case GoalId::Solved:
                return CubeModel::isSolved(s);
        }
        return false;
    }

    /// Public entry point for the last layer stage search.
    ///
    /// Exposed so the host tests can verify the algorithm set is *complete*
    /// for each sub problem: they enumerate every legal last layer state and
    /// require a chain for each. A gap here would silently demote a teaching
    /// stage to a raw search, which is exactly the failure this refactor set
    /// out to remove.
    bool solveLastLayerStage(GoalId goal, int slot, const CubieState& state,
                             std::vector<int>& moves,
                             std::vector<std::string>& algos) {
        return solveLastLayerChain(state, goal, slot, moves, algos);
    }

private:
    CfopEngine() = default;

    struct SearchContext {
        GoalId goal = GoalId::Cross;
        int slot = -1;
        int faceMask = FULL_MASK;
        std::array<const PieceGroupTable*, 9> tables{};
        int tableCount = 0;
        long long nodes = 0;
        bool timedOut = false;
        std::chrono::steady_clock::time_point deadline{};
    };

    struct Attempt {
        bool found = false;
        int tier = 0;   // see lastStageTier for the meaning of each tier
        std::vector<int> moves;
        std::vector<std::string> algos;
    };

    static constexpr int FULL_MASK = 0x3F;

    static bool crossSolved(const CubieState& s) {
        return s.ep[DF] == DF && s.eo[DF] == 0 &&
               s.ep[DR] == DR && s.eo[DR] == 0 &&
               s.ep[DB] == DB && s.eo[DB] == 0 &&
               s.ep[DL] == DL && s.eo[DL] == 0;
    }

    static bool pairSolved(const CubieState& s, int slot) {
        static const int8_t slotCorner[4] = { DFR, DLF, DBL, DRB };
        static const int8_t slotEdge[4] = { FR, FL, BL, BR };
        const int c = slotCorner[slot];
        const int e = slotEdge[slot];
        return s.cp[c] == c && s.co[c] == 0 && s.ep[e] == e && s.eo[e] == 0;
    }

    static bool f2lSolved(const CubieState& s) {
        if (!crossSolved(s)) return false;
        for (int i = 0; i < 4; ++i) {
            if (!pairSolved(s, i)) return false;
        }
        return true;
    }

    static bool llEdgesOriented(const CubieState& s) {
        return s.eo[UR] == 0 && s.eo[UF] == 0 && s.eo[UL] == 0 && s.eo[UB] == 0;
    }

    static bool llCornersOriented(const CubieState& s) {
        return s.co[URF] == 0 && s.co[UFL] == 0 && s.co[ULB] == 0 && s.co[UBR] == 0;
    }

    static bool llCornersPlaced(const CubieState& s) {
        return s.cp[URF] == URF && s.cp[UFL] == UFL &&
               s.cp[ULB] == ULB && s.cp[UBR] == UBR;
    }

    static bool pairsSolved(const CubieState& s, int lastSlot) {
        if (!crossSolved(s)) return false;
        for (int i = 0; i <= lastSlot; ++i) {
            if (!pairSolved(s, i)) return false;
        }
        return true;
    }

    static const char* colorName(int color) {
        switch (color) {
            case U: return "白";
            case D: return "黄";
            case F: return "绿";
            case R: return "红";
            case L: return "橙";
            case B: return "蓝";
            default: return "?";
        }
    }

    static std::string slotHint(int slot) {
        static const char* slotName[4] = { "右前", "左前", "左后", "右后" };
        return std::string("把底层的角块与相邻中层棱块配成一组，一起塞进") +
               slotName[slot] + "槽位，同时不破坏已完成的十字";
    }

    static std::string slotExplanation(int slot, CFOPStage stage) {
        static const int8_t slotCorner[4] = { DFR, DLF, DBL, DRB };
        static const int8_t slotEdge[4] = { FR, FL, BL, BR };
        static const char* slotName[4] = { "右前", "左前", "左后", "右后" };
        const int c = slotCorner[slot];
        const int e = slotEdge[slot];

        std::string cornerDesc = std::string(colorName(CubeModel::cornerColors[c][0])) + "-" +
                                 colorName(CubeModel::cornerColors[c][1]) + "-" +
                                 colorName(CubeModel::cornerColors[c][2]);
        std::string edgeDesc = std::string(colorName(CubeModel::edgeColors[e][0])) + "-" +
                               colorName(CubeModel::edgeColors[e][1]);

        std::string text = "本阶段的目标是" + std::string(slotName[slot]) + "槽位：先把 " +
                           cornerDesc + " 角块与 " + edgeDesc +
                           " 棱块都转到顶层并让它们成为「配对」状态，再一起转进槽位。"
                           "配对的关键是让角块的底色与棱块的侧面色朝向一致，这样一次转动就能同时到位。";
        if (stage == CFOPStage::F2L_4) {
            text += " 这是最后一组槽位，完成后前两层就全部就位。";
        }
        return text;
    }

    /// Builds the table list for a stage, which doubles as its heuristic.
    void fillTables(SearchContext& ctx) const {
        ctx.tableCount = 0;
        const auto add = [&ctx](const PieceGroupTable& t) {
            ctx.tables[ctx.tableCount++] = &t;
        };
        switch (ctx.goal) {
            case GoalId::Cross:
                add(cross_);
                break;
            case GoalId::Pair:
                add(cross_);
                for (int i = 0; i <= ctx.slot; ++i) add(pair_[i]);
                break;
            case GoalId::OllEdge:
                add(cross_);
                for (int i = 0; i < 4; ++i) add(pair_[i]);
                add(llEdgeOrient_);
                break;
            case GoalId::OllCorner:
                add(cross_);
                for (int i = 0; i < 4; ++i) add(pair_[i]);
                add(llEdgeOrient_);
                add(llCornerOrient_);
                break;
            case GoalId::PllCorner:
                add(cross_);
                for (int i = 0; i < 4; ++i) add(pair_[i]);
                add(llEdgeOrient_);
                add(llCornerOrient_);
                add(llCornerPlace_);
                break;
            case GoalId::Solved:
                add(cross_);
                for (int i = 0; i < 4; ++i) add(pair_[i]);
                add(llEdgeOrient_);
                add(llCornerOrient_);
                add(llCornerPlace_);
                add(llEdgePlace_);
                break;
        }
    }

    /// Move set that is enough to finish a stage.
    ///
    /// This is a search space hint, not a correctness requirement - the goal
    /// test is what actually enforces the stage, and intermediate states are
    /// free to disturb earlier work - so the only restriction worth making is
    /// "never turn the bottom face", which is exactly how every CFOP step is
    /// executed in practice: the cross, the four F2L slots and the whole last
    /// layer are all done without a single D turn.
    ///
    /// Narrowing it further per slot (U plus the slot's two side faces, as an
    /// earlier revision did) looks tidier but is simply wrong: a pair whose
    /// corner is buried in the opposite slot cannot be extracted without the
    /// far side face, so a third of the F2L searches were timing out and
    /// silently falling through to an unconstrained search.
    static int teachingMask(GoalId goal) {
        if (goal == GoalId::Cross) return FULL_MASK;
        return FULL_MASK & ~(1 << D);
    }

    /// Tries the teaching friendly move set first, then widens. The last tier
    /// (20 moves, all faces) always succeeds because the solved cube - which
    /// satisfies every stage goal - is reachable from any state within 20
    /// moves.
    Attempt attemptStage(const CubieState& start, GoalId goal, int slot,
                          int tightLimit, double budgetSeconds) {
        Attempt done;
        if (stageReached(goal, slot, start)) {
            done.found = true;
            done.tier = -1;
            return done;
        }

        // Last layer stages are answered with the named 2-look OLL / PLL
        // algorithms, not with a raw search: that is what a learner needs, and
        // it is also far cheaper than searching the same sub problem.
        if (isLastLayerGoal(goal)) {
            Attempt teaching;
            if (solveLastLayerChain(start, goal, slot, teaching.moves, teaching.algos)) {
                teaching.found = true;
                teaching.tier = 0;
                return teaching;
            }
#ifdef RUBIK_CHAIN_DEBUG
            // Should be unreachable: the host tests enumerate every legal last
            // layer state for each stage and require a chain for each. Kept so a
            // future algorithm set change reports itself instead of silently
            // demoting the stage to a raw search.
            std::fprintf(stderr,
                         "[chain-miss] goal=%d slot=%d f2l=%d cp[%d %d %d %d] co[%d %d %d %d] "
                         "ep[%d %d %d %d] eo[%d %d %d %d]\n",
                         (int)goal, slot, stageReached(GoalId::Pair, 3, start) ? 1 : 0,
                         start.cp[URF], start.cp[UFL], start.cp[ULB], start.cp[UBR],
                         start.co[URF], start.co[UFL], start.co[ULB], start.co[UBR],
                         start.ep[UR], start.ep[UF], start.ep[UL], start.ep[UB],
                         start.eo[UR], start.eo[UF], start.eo[UL], start.eo[UB]);
#endif
        }

        const int mask = teachingMask(goal);
        if (mask != FULL_MASK) {
            Attempt a = searchWithMask(start, goal, slot, mask, tightLimit,
                                       budgetSeconds * 0.3);
            if (a.found) {
                a.tier = 1;
                return a;
            }
        }

        Attempt a = searchWithMask(start, goal, slot, FULL_MASK, tightLimit,
                                    budgetSeconds * 0.8);
        if (a.found) {
            a.tier = 2;
            return a;
        }

        a = searchWithMask(start, goal, slot, FULL_MASK, 20, budgetSeconds * 2.0);
        a.tier = 3;
        return a;
    }

    /// True for the four stages that are solved with named algorithms.
    static bool isLastLayerGoal(GoalId goal) {
        return goal == GoalId::OllEdge || goal == GoalId::OllCorner ||
               goal == GoalId::PllCorner || goal == GoalId::Solved;
    }

    static LlStageKind algorithmKindFor(GoalId goal) {
        switch (goal) {
            case GoalId::OllEdge: return LlStageKind::OllEdge;
            case GoalId::OllCorner: return LlStageKind::OllCorner;
            case GoalId::PllCorner: return LlStageKind::PllCorner;
            default: return LlStageKind::PllEdge;
        }
    }

    /// Compact key of a state for the chain search's visited set.
    static std::array<int8_t, 40> packState(const CubieState& s) {
        std::array<int8_t, 40> out{};
        for (int i = 0; i < 8; ++i) {
            out[(size_t)i] = s.cp[i];
            out[(size_t)(8 + i)] = s.co[i];
        }
        for (int i = 0; i < 12; ++i) {
            out[(size_t)(16 + i)] = s.ep[i];
            out[(size_t)(28 + i)] = s.eo[i];
        }
        return out;
    }

    /// Collapses consecutive turns of the same face (U U' -> nothing,
    /// U U -> U2), so the emitted algorithm chains read like real notation.
    static std::vector<int> simplifySequence(const std::vector<int>& moves) {
        std::vector<int> out;
        for (int m : moves) {
            const int face = m / 3;
            int amount = m % 3 + 1;
            while (!out.empty() && out.back() / 3 == face) {
                amount += out.back() % 3 + 1;
                out.pop_back();
            }
            amount %= 4;
            if (amount != 0) out.push_back(face * 3 + (amount - 1));
        }
        return out;
    }

    /// Solves one last layer stage as a chain of named algorithms plus U
    /// alignment turns.
    ///
    /// Uniform cost search on the number of moves, not on the number of
    /// algorithms: a single 17 move Y perm beats a T perm plus an A perm, and a
    /// plain U alignment beats everything - which is exactly how a human picks
    /// between the cases of a 2-look stage. That also means the loop closes on
    /// the real "2-look" promise, one or two formulas, or a bare "adjust the
    /// top layer" when the sub problem happens to be solved up to a rotation.
    ///
    /// The goal test is the same one the raw search uses, so the two can never
    /// disagree about what "stage finished" means.
    bool solveLastLayerChain(const CubieState& start, GoalId goal, int slot,
                             std::vector<int>& outMoves,
                             std::vector<std::string>& outNames) {
        outMoves.clear();
        outNames.clear();
        if (stageReached(goal, slot, start)) return true;

        // Generators: U alignment turns, then this stage's own algorithms.
        struct Generator {
            bool isUTurn = false;
            int algorithmIndex = -1;
            std::vector<int> moves;
        };
        std::vector<Generator> gens;
        for (const char* u : { "U", "U2", "U'" }) {
            gens.push_back({ true, -1, parseSequence(u) });
        }
        const std::vector<LlAlgorithm>& all = lastLayerAlgorithms();
        const LlStageKind kind = algorithmKindFor(goal);
        for (size_t i = 0; i < all.size(); ++i) {
            if (all[i].kind != kind) continue;
            gens.push_back({ false, (int)i, all[i].moves });
        }

        struct Node {
            CubieState state;
            int parent;
            int generator;
            int cost;       // moves spent to get here
        };
        std::vector<Node> nodes;
        nodes.push_back({ start, -1, -1, 0 });

        using Key = std::array<int8_t, 40>;
        std::map<Key, int> best;      // cheapest known cost for each state
        best[packState(start)] = 0;

        // Ties are broken by insertion order instead of being left to the heap
        // implementation. Two chains of equal cost are otherwise ordered by
        // whatever `std::pop_heap` happens to do with equivalent elements, and
        // MSVC's STL and Android's libc++ do not agree: the same scramble used
        // to yield a 15 move last layer step on the host and a 16 move one on
        // the phone. Insertion order is itself fixed (the generators are walked
        // in a fixed order), so this turns the comparator into a total order and
        // the guide becomes identical on every platform.
        const auto later = [&nodes](int a, int b) {
            if (nodes[(size_t)a].cost != nodes[(size_t)b].cost) {
                return nodes[(size_t)a].cost > nodes[(size_t)b].cost;
            }
            return a > b;
        };
        std::vector<int> heap{ 0 };

        constexpr int kMaxExpansions = 20000;   // never reached: the last layer
                                                // state space is a few hundred

        for (int expanded = 0; expanded < kMaxExpansions && !heap.empty(); ++expanded) {
            std::pop_heap(heap.begin(), heap.end(), later);
            const int nodeIndex = heap.back();
            heap.pop_back();

            const Node& node = nodes[(size_t)nodeIndex];
            // A cheaper path to this state was found after this entry was
            // queued, so the entry is stale. `find` rather than `operator[]`:
            // the latter would insert a zero cost entry for a state that is
            // missing from the map, which then makes every later visit look
            // stale and silently prunes the search.
            const auto bestIt = best.find(packState(node.state));
            if (bestIt != best.end() && node.cost > bestIt->second) continue;

            if (stageReached(goal, slot, node.state)) {
                // Popping in cost order means this is the cheapest chain, and
                // replaying the parent pointers yields it.
                std::vector<int> moves;
                std::vector<std::string> names;
                for (int cur = nodeIndex; cur > 0; cur = nodes[(size_t)cur].parent) {
                    const Generator& gen = gens[(size_t)nodes[(size_t)cur].generator];
                    moves.insert(moves.begin(), gen.moves.begin(), gen.moves.end());
                    if (!gen.isUTurn) {
                        names.insert(names.begin(), all[(size_t)gen.algorithmIndex].name);
                    }
                }
                outMoves = simplifySequence(moves);
                outNames = names;
                return true;
            }

            // Two U turns in a row are one U turn with a smaller amount, so the
            // search skips them and stays canonical.
            const bool lastWasU =
                node.generator >= 0 && gens[(size_t)node.generator].isUTurn;
            for (size_t g = 0; g < gens.size(); ++g) {
                if (lastWasU && gens[g].isUTurn) continue;
                const CubieState moved = applySequence(node.state, gens[g].moves);
                const Key key = packState(moved);
                const int cost = node.cost + (int)gens[g].moves.size();
                const auto it = best.find(key);
                if (it != best.end() && it->second <= cost) continue;

                best[key] = cost;
                nodes.push_back({ moved, nodeIndex, (int)g, cost });
                heap.push_back((int)nodes.size() - 1);
                std::push_heap(heap.begin(), heap.end(), later);
            }
        }
        return false;
    }

    Attempt searchWithMask(const CubieState& start, GoalId goal, int slot,
                           int faceMask, int maxLen, double budgetSeconds) {
        SearchContext ctx;
        ctx.goal = goal;
        ctx.slot = slot;
        ctx.faceMask = faceMask;
        fillTables(ctx);
        ctx.deadline = std::chrono::steady_clock::now() +
            std::chrono::duration_cast<std::chrono::steady_clock::duration>(
                std::chrono::duration<double>(budgetSeconds));

        CubieState s = start;
        for (int limit = heuristic(ctx, s); limit <= maxLen; ++limit) {
            ctx.timedOut = false;
            path_.clear();
            if (dfsStage(s, ctx, 0, limit, -1)) {
                Attempt a;
                a.found = true;
                a.moves = path_;
                return a;
            }
            if (ctx.timedOut) break;
        }
        return Attempt{};
    }

    /// Heuristic of the current node, built from one pass over the state.
    int heuristic(const SearchContext& ctx, const CubieState& s) const {
        int8_t cornerPos[8] = {-1,-1,-1,-1,-1,-1,-1,-1};
        int8_t cornerOri[8] = {0,0,0,0,0,0,0,0};
        int8_t edgePos[12] = {-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1};
        int8_t edgeOri[12] = {0,0,0,0,0,0,0,0,0,0,0,0};
        for (int i = 0; i < 8; ++i) {
            cornerPos[s.cp[i]] = (int8_t)i;
            cornerOri[s.cp[i]] = s.co[i];
        }
        for (int i = 0; i < 12; ++i) {
            edgePos[s.ep[i]] = (int8_t)i;
            edgeOri[s.ep[i]] = s.eo[i];
        }

        int h = 0;
        for (int i = 0; i < ctx.tableCount; ++i) {
            const int d = ctx.tables[i]->distFromMaps(cornerPos, cornerOri, edgePos, edgeOri);
            if (d > h) h = d;
        }
        return h;
    }

    bool dfsStage(CubieState& s, SearchContext& ctx, int depth, int limit, int lastFace) {
        if (stageReached(ctx.goal, ctx.slot, s)) return true;

        if ((++ctx.nodes & 0x1FFF) == 0 &&
            std::chrono::steady_clock::now() > ctx.deadline) {
            ctx.timedOut = true;
            return false;
        }

        const int h = heuristic(ctx, s);
        if (depth + h > limit) return false;

        for (int face = 0; face < 6; ++face) {
            if (face == lastFace) continue;
            if (!(ctx.faceMask & (1 << face))) continue;
            // U/D, R/L and F/B commute: keep one canonical order.
            if (lastFace >= 0 && face == OPPOSITE_FACE[lastFace] && face > lastFace) continue;
            for (int amount = 0; amount < 3; ++amount) {
                const int move = face * 3 + amount;
                applyMoveInPlace(s, move);
                path_.push_back(move);
                if (dfsStage(s, ctx, depth + 1, limit, face)) return true;
                path_.pop_back();
                applyMoveInPlace(s, inverseMove(move));
                if (ctx.timedOut) return false;
            }
        }
        return false;
    }

    static constexpr int OPPOSITE_FACE[6] = { 3, 4, 5, 0, 1, 2 };

    PieceGroupTable cross_;
    PieceGroupTable pair_[4];
    PieceGroupTable llEdgeOrient_;
    PieceGroupTable llCornerOrient_;
    PieceGroupTable llCornerPlace_;
    PieceGroupTable llEdgePlace_;
    bool ready_ = false;
    std::vector<int> path_;
};

/// JSON facing facade kept for the existing FFI contract.
class CFOPSolver {
public:
    static std::vector<CFOPStep> generateGuide(const std::string& facelets) {
        CubieState state{};
        std::string err;
        if (!CubeModel::faceletsToCubie(facelets, state, err)) return {};
        if (!CubeModel::validate(facelets, err)) return {};

        const std::vector<CfopEngine::Stage> stages = CfopEngine::instance().solve(state);
        std::vector<CFOPStep> steps;
        steps.reserve(stages.size());
        for (const CfopEngine::Stage& stage : stages) {
            CFOPStep step;
            step.stage = stage.stage;
            step.stage_name = stage.name;
            step.formula = sequenceToString(stage.moves);
            step.visual_hint = stage.hint;
            step.algorithms = stage.algos;
            step.tier = stage.tier;
            step.explanation = stage.explanation + "（本阶段共 " +
                               std::to_string(stage.moves.size()) + " 步）";
            if (!stage.algos.empty()) {
                // Naming the formulas is what turns the move list into a
                // lesson: the learner is told which algorithm they just used,
                // not handed ten anonymous turns.
                std::string named;
                for (size_t i = 0; i < stage.algos.size(); ++i) {
                    if (i) named += " → ";
                    named += stage.algos[i];
                }
                step.explanation += "；本阶段用到的公式：" + named;
            }
            steps.push_back(step);
        }
        return steps;
    }
};

}  // namespace rubik

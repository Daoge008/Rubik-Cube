// CFOP diagnostics probe.
//
// Not a test: it runs the teaching solver over many scrambles and reports,
// per plan slot, how long the stage search takes, which cascade tier produced
// the moves and how long that stage's answer is. Used to find the stages that
// still fall through to the two phase fallback instead of a real CFOP step.
//
// Build and run with tools/native_tests/probe.bat
#include "cube_model.hpp"
#include "cfop_pipeline.hpp"
#include "move_engine.hpp"

#include <algorithm>
#include <chrono>
#include <cstdio>
#include <cstdlib>
#include <vector>

using namespace rubik;

struct Rng {
    uint32_t s;
    explicit Rng(uint32_t seed) : s(seed) {}
    uint32_t next() {
        s = s * 1664525u + 1013904223u;
        return s;
    }
    int below(int n) { return (int)(next() % (uint32_t)n); }
};

static std::vector<int> randomScramble(Rng& rng, int length) {
    std::vector<int> moves;
    int lastFace = -1;
    while ((int)moves.size() < length) {
        const int face = rng.below(6);
        if (face == lastFace) continue;
        lastFace = face;
        moves.push_back(face * 3 + rng.below(3));
    }
    return moves;
}

static const char* kPlanName[9] = { "cross", "f2l1", "f2l2", "f2l3", "f2l4",
                                    "oll-e", "oll-c", "pll-c", "pll-e" };

/// Plan slot a produced stage belongs to.
static int planIndexOf(CFOPStage stage) { return (int)stage; }

int main(int argc, char** argv) {
    CfopEngine& engine = CfopEngine::instance();
    engine.ensureTables();

    int cases = 40;
    if (argc > 1) cases = std::atoi(argv[1]);
    if (cases <= 0) cases = 40;

    struct Stat {
        long long micros = 0;
        int maxLen = 0;
        int tierHist[5] = { 0, 0, 0, 0, 0 };
        int invoked = 0;
        std::vector<int> lens;
    };
    Stat stats[9];

    Rng rng(777001);
    for (int c = 0; c < cases; ++c) {
        const std::vector<int> scramble = randomScramble(rng, 25);
        const CubieState scrambled = applySequence(CubeModel::solvedState(), scramble);

        const std::vector<CfopEngine::Stage> stages = engine.solve(scrambled);

        for (int p = 0; p < 9; ++p) {
            const int tier = engine.lastStageTier[p];
            if (tier < 0) continue;
            stats[p].invoked++;
            stats[p].tierHist[std::min(tier, 4)]++;
            stats[p].micros += engine.lastStageMicros[p];
        }
        for (const CfopEngine::Stage& st : stages) {
            const int p = planIndexOf(st.stage);
            if (p < 0 || p > 8) continue;
            const int len = (int)st.moves.size();
            stats[p].maxLen = std::max(stats[p].maxLen, len);
            stats[p].lens.push_back(len);
        }
    }

    std::printf("=== CFOP probe over %d scrambles ===\n", cases);
    for (int p = 0; p < 9; ++p) {
        const Stat& s = stats[p];
        if (s.invoked == 0) continue;
        std::printf("  %-6s inv %3d  avg %6.1f ms  maxlen %2d  tiers t0=%d t1=%d t2=%d t3=%d t4=%d  lens:",
                    kPlanName[p], s.invoked, (double)s.micros / 1000.0 / s.invoked,
                    s.maxLen, s.tierHist[0], s.tierHist[1], s.tierHist[2], s.tierHist[3],
                    s.tierHist[4]);
        int counts[40] = { 0 };
        int shown = 0;
        for (int len : s.lens) {
            if (len >= 0 && len < 40) counts[len]++;
        }
        for (int len = 0; len < 40; ++len) {
            if (counts[len] == 0) continue;
            std::printf(" %dx%d", len, counts[len]);
            (void)shown;
        }
        std::printf("\n");
    }

    // Table sanity.
    std::printf("tables: %s, %.2f MB\n",
                engine.tablesComplete() ? "complete" : "INCOMPLETE",
                engine.tableBytes() / 1024.0 / 1024.0);
    std::printf("%s", engine.tableDiagnostics().c_str());
    return 0;
}

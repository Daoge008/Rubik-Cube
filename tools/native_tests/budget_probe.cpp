// Is the CFOP guide reproducible?
//
// The stage searches run under a wall clock budget, so a machine that finishes
// a search slightly faster can take a different cascade tier than a slower one
// and end up with a different - still correct - guide. This probe solves one
// fixed scramble under a range of budgets and prints the stage breakdown, so
// the sensitivity is visible instead of guessed at.
//
// Build and run with tools/native_tests/probe.bat budget_probe.cpp
#include "cube_model.hpp"
#include "cfop_pipeline.hpp"
#include "move_engine.hpp"

#include <cstdio>
#include <string>
#include <vector>

using namespace rubik;

// Vector #6 from gen_vectors.cpp, the state where the phone and the host
// disagreed about the stage count.
static const char* kFacelets =
    "DUULUDUUFUBLBRRLDFBLRRFUDLUBFBRDLDFLFBRFLDBBLFFRRBUDDR";

int main() {
    CubieState state;
    std::string error;
    if (!CubeModel::faceletsToCubie(kFacelets, state, error)) {
        std::fprintf(stderr, "bad vector: %s\n", error.c_str());
        return 1;
    }

    const double budgets[] = { 0.02, 0.1, 0.5, 1.5, 10.0, 1000.0 };
    for (double budget : budgets) {
        const std::vector<CfopEngine::Stage> stages =
            CfopEngine::instance().solve(state, budget);

        int total = 0;
        std::printf("budget %8.2f s  stages=%d  lens=[", budget,
                    (int)stages.size());
        for (size_t i = 0; i < stages.size(); ++i) {
            total += (int)stages[i].moves.size();
            std::printf("%s%d", i == 0 ? "" : ", ", (int)stages[i].moves.size());
        }
        std::printf("]  total=%d\n", total);
    }

    // Cross platform agreement needs the search to be deterministic, so print
    // the tier each stage landed on for the budget the app actually uses.
    std::printf("\ntiers at the default 1.5 s budget:\n");
    CfopEngine::instance().solve(state, 1.5);
    static const char* names[9] = { "cross", "f2l1", "f2l2", "f2l3", "f2l4",
                                    "oll-e", "oll-c", "pll-c", "pll-e" };
    for (int i = 0; i < 9; ++i) {
        if (CfopEngine::instance().lastStageTier[i] < 0) continue;
        std::printf("  %-6s tier=%d  %.1f ms\n", names[i],
                    CfopEngine::instance().lastStageTier[i],
                    CfopEngine::instance().lastStageMicros[i] / 1000.0);
    }
    return 0;
}

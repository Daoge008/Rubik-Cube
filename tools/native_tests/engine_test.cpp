// Host side tests for the native cube engine.
//
// Build and run with tools/native_tests/run_tests.bat - it compiles this file
// with the host MSVC toolchain and executes it. The Android library and this
// test share the very same headers, so a green run here means the C++ engine
// is arithmetically correct before it ever reaches a phone.
#include "cube_model.hpp"
#include "move_engine.hpp"
#include "kociemba_solver.hpp"
#include "cfop_pipeline.hpp"
#include "last_layer_algorithms.hpp"
#include "vision_pipeline.hpp"
#include "face_assembler.hpp"

#include <algorithm>
#include <chrono>
#include <cstdio>
#include <string>
#include <vector>

using namespace rubik;

static int g_failures = 0;
static int g_checks = 0;

static void check(bool ok, const char* what, int line) {
    g_checks++;
    if (!ok) {
        g_failures++;
        std::printf("  FAIL (line %d): %s\n", line, what);
    }
}

#define CHECK(cond) check((cond), #cond, __LINE__)

static void checkStr(const std::string& actual, const std::string& expected,
                     const char* what, int line) {
    g_checks++;
    if (actual != expected) {
        g_failures++;
        std::printf("  FAIL (line %d): %s\n    expected %s\n    actual   %s\n",
                    line, what, expected.c_str(), actual.c_str());
    }
}

#define CHECK_STR(actual, expected) checkStr((actual), (expected), #actual, __LINE__)

/// Small deterministic LCG so failures reproduce exactly.
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

static bool onlyUTurns(const std::vector<int>& moves) {
    for (int m : moves) {
        if (m / 3 != 0) return false;
    }
    return true;
}

/// A 2-look last layer stage is at worst an awkward corner case: the longest
/// two algorithms in the set (a 14 move T perm plus a 17 move Y perm) plus the
/// U alignment either side. Anything longer means the stage fell back to a raw
/// search, which is precisely the regression this cap exists to catch.
static constexpr int kLastLayerStageCap = 34;

// ---------------------------------------------------------------- facelets

static void testFaceletsRoundTrip() {
    std::printf("[test] facelet <-> cubie round trip\n");
    const std::string& solved = CubeModel::solvedFacelets();
    CHECK_STR(CubeModel::cubieToFacelets(CubeModel::solvedState()), solved);

    std::string err;
    CubieState decoded{};
    CHECK(CubeModel::faceletsToCubie(solved, decoded, err));
    CHECK(CubeModel::isSolved(decoded));

    Rng rng(20260925);
    for (int i = 0; i < 200; ++i) {
        const CubieState scrambled =
            applySequence(CubeModel::solvedState(), randomScramble(rng, 30));
        const std::string facelets = CubeModel::cubieToFacelets(scrambled);
        CubieState back{};
        if (!CubeModel::faceletsToCubie(facelets, back, err)) {
            g_failures++;
            std::printf("  FAIL: decode rejected a legal state: %s\n", err.c_str());
            continue;
        }
        bool same = true;
        for (int k = 0; k < 8 && same; ++k) {
            same = back.cp[k] == scrambled.cp[k] && back.co[k] == scrambled.co[k];
        }
        for (int k = 0; k < 12 && same; ++k) {
            same = back.ep[k] == scrambled.ep[k] && back.eo[k] == scrambled.eo[k];
        }
        CHECK(same);
    }
}

// ------------------------------------------------------------- move tables

static void testSingleTurns() {
    std::printf("[test] single turns against hand derived facelets\n");

    // U (clockwise seen from above) rotates the side faces' top rows:
    // F <- R, R <- B, B <- L, L <- F.
    const CubieState afterU = applyMove(CubeModel::solvedState(), 0 * 3 + 0);
    CHECK_STR(CubeModel::cubieToFacelets(afterU),
              "UUUUUUUUU"     // U
              "BBBRRRRRR"     // R <- B
              "RRRFFFFFF"     // F <- R
              "DDDDDDDDD"     // D
              "FFFLLLLLL"     // L <- F
              "LLLBBBBBB");   // B <- L

    // R (clockwise seen from the right) sends the top layer towards the back:
    // the U-R-F corner travels to U-B-R and the U-R edge to B-R.
    const CubieState afterR = applyMove(CubeModel::solvedState(), 1 * 3 + 0);
    CHECK(afterR.cp[UBR] == URF);
    CHECK(afterR.cp[DFR] == DRB);
    CHECK(afterR.ep[BR] == UR);
    CHECK(afterR.ep[FR] == DR);

    // A right face turn is a rotation about the X axis, so D -> F -> U -> B:
    // the corner arriving at U-R-F brings its F sticker to the U face and its
    // D sticker to the F face, while its R sticker stays on the R face.
    const std::string rf = CubeModel::cubieToFacelets(afterR);
    CHECK(rf[8] == 'F');    // U9: D-F-R's F sticker now faces up
    CHECK(rf[20] == 'D');   // F3: the same corner's D sticker now faces front
    CHECK(rf[9] == 'R');    // R1: its R sticker never left the R face
    CHECK(rf[5] == 'F');    // U6: the U-R edge position now holds F-R
    CHECK(rf[23] == 'D');   // F6: the D-R edge lands in the F-R position

    // Every face turn is an involution of order four.
    for (int face = 0; face < 6; ++face) {
        CubieState s = CubeModel::solvedState();
        for (int k = 0; k < 4; ++k) applyMoveInPlace(s, face * 3 + 0);
        CHECK(CubeModel::isSolved(s));

        CubieState t = CubeModel::solvedState();
        applyMoveInPlace(t, face * 3 + 0);
        applyMoveInPlace(t, face * 3 + 2);
        CHECK(CubeModel::isSolved(t));

        // half turn equals two quarter turns
        CubieState a = applyMove(CubeModel::solvedState(), face * 3 + 0);
        a = applyMove(a, face * 3 + 0);
        const CubieState b = applyMove(CubeModel::solvedState(), face * 3 + 1);
        bool same = true;
        for (int i = 0; i < 8 && same; ++i) same = a.cp[i] == b.cp[i] && a.co[i] == b.co[i];
        for (int i = 0; i < 12 && same; ++i) same = a.ep[i] == b.ep[i] && a.eo[i] == b.eo[i];
        CHECK(same);
    }
}

static void testMoveGroupOrders() {
    std::printf("[test] group orders / known identities\n");

    // <R, U> has order 105 - a classic check on move table conventions.
    {
        CubieState s = CubeModel::solvedState();
        for (int k = 0; k < 104; ++k) {
            applyMoveInPlace(s, 1 * 3 + 0);
            applyMoveInPlace(s, 0 * 3 + 0);
        }
        CHECK(!CubeModel::isSolved(s));
        applyMoveInPlace(s, 1 * 3 + 0);
        applyMoveInPlace(s, 0 * 3 + 0);
        CHECK(CubeModel::isSolved(s));
    }

    // The sexy move is an order 6 element.
    {
        const std::vector<int> sexy = parseSequence("R U R' U'");
        CubieState s = CubeModel::solvedState();
        for (int k = 0; k < 6; ++k) s = applySequence(s, sexy);
        CHECK(CubeModel::isSolved(s));
    }

    // A sequence followed by its inverse is the identity.
    Rng rng(7);
    for (int i = 0; i < 50; ++i) {
        const std::vector<int> seq = randomScramble(rng, 25);
        const CubieState scrambled = applySequence(CubeModel::solvedState(), seq);
        CHECK(CubeModel::isSolved(applySequence(scrambled, invertSequence(seq))));
    }

    // Parsing and printing round trip.
    CHECK_STR(sequenceToString(parseSequence("R U2 F' D L2 B'")), "R U2 F' D L2 B'");
}

// -------------------------------------------------------------- validation

static void testValidationRejectsIllegalStates() {
    std::printf("[test] validation rejects illegal states\n");
    std::string err;

    CubieState s = CubeModel::solvedState();
    s.eo[0] = 1;   // a single flipped edge is impossible
    CHECK(!CubeModel::validate(CubeModel::cubieToFacelets(s), err));

    s = CubeModel::solvedState();
    s.co[0] = 1;   // a single twisted corner is impossible
    CHECK(!CubeModel::validate(CubeModel::cubieToFacelets(s), err));

    s = CubeModel::solvedState();
    s.ep[0] = 1;   // duplicated edge, DB missing
    s.ep[1] = 1;
    CHECK(!CubeModel::validate(CubeModel::cubieToFacelets(s), err));

    s = CubeModel::solvedState();
    s.cp[0] = 1;   // duplicated corner
    s.cp[1] = 1;
    CHECK(!CubeModel::validate(CubeModel::cubieToFacelets(s), err));

    CHECK(!CubeModel::validate("TOO SHORT", err));
    CHECK(!CubeModel::validate(std::string(54, 'U'), err));   // one color only

    CHECK(CubeModel::validate(CubeModel::solvedFacelets(), err));
}

// ------------------------------------------------------------ coordinates

static void testCoordinates() {
    std::printf("[test] solver coordinates\n");

    // Every coordinate must read 0 for the solved cube: the IDA* goal tests
    // and the backwards BFS both assume it.
    {
        const CubieState solved = CubeModel::solvedState();
        CHECK(twistCoord(solved) == 0);
        CHECK(flipCoord(solved) == 0);
        CHECK(sliceCoord(solved) == 0);
        CHECK(cornerPermCoord(solved) == 0);
        CHECK(edgePermCoord(solved) == 0);
        CHECK(slicePermCoord(solved) == 0);
        CHECK(inPhase2Subgroup(solved));
        // ... and the solved slice lives on positions 8..11
        CHECK(sliceIndexToMask()[0] == 0x0F00);
    }

    // permutation rank <-> unrank round trip
    uint8_t p[8];
    for (int n : {4, 8}) {
        const int limit = (n == 4) ? 24 : 40320;
        for (int r = 0; r < limit; ++r) {
            permUnrank(r, p, n);
            CHECK(permRank(p, n) == r);
        }
    }
    for (int r = 0; r < 24; r += 7) {
        permUnrank(r, p, 4);
        for (int i = 0; i < 4; ++i) CHECK(p[i] < 4);
    }

    // every coordinate stays inside its documented range and is stable
    Rng rng(99);
    for (int i = 0; i < 500; ++i) {
        const CubieState s = applySequence(CubeModel::solvedState(), randomScramble(rng, 20));
        CHECK(twistCoord(s) >= 0 && twistCoord(s) < 2187);
        CHECK(flipCoord(s) >= 0 && flipCoord(s) < 2048);
        CHECK(sliceCoord(s) >= 0 && sliceCoord(s) < 495);
        CHECK(cornerPermCoord(s) >= 0 && cornerPermCoord(s) < 40320);
        CHECK(slicePermCoord(s) >= 0 && slicePermCoord(s) < 24);
    }

    // the slice coordinate is exactly the set of positions holding slice edges
    for (int index = 0; index < 495; ++index) {
        const int mask = sliceIndexToMask()[index];
        CHECK(sliceMaskToIndex()[mask] == index);
    }
}

// --------------------------------------------------------------- solver

static void testKociemba() {
    std::printf("[test] kociemba two phase solver\n");

    KociembaEngine& engine = KociembaEngine::instance();
    const auto t0 = std::chrono::steady_clock::now();
    engine.ensureTables();
    const double buildMs = std::chrono::duration<double, std::milli>(
                               std::chrono::steady_clock::now() - t0).count();
    std::printf("  tables built in %.0f ms, %.2f MB\n", buildMs,
                engine.tableBytes() / 1048576.0);
    CHECK(engine.pruningTablesComplete());
    CHECK(buildMs < 30000.0);

    // already solved cubes produce no moves
    CHECK(engine.solve(CubeModel::solvedState()).empty());
    CHECK(KociembaEngine::solveFacelets(CubeModel::solvedFacelets()) == "SOLVED");

    // invalid input is rejected with a readable error
    const std::string bad = KociembaEngine::solveFacelets(std::string(54, 'U'));
    CHECK(bad.rfind("ERROR:", 0) == 0);

    // random scrambles: solve, replay, expect the identity
    Rng rng(20260925);
    int solvedCount = 0;
    int minLen = 1 << 30;
    int maxLen = 0;
    long long totalLen = 0;
    long long totalUsec = 0;
    const int cases = 200;
    for (int i = 0; i < cases; ++i) {
        const std::vector<int> scramble = randomScramble(rng, 30);
        const CubieState scrambled = applySequence(CubeModel::solvedState(), scramble);

        const auto start = std::chrono::steady_clock::now();
        const std::vector<int> solution = engine.solve(scrambled, 22, 2.5);
        totalUsec += std::chrono::duration_cast<std::chrono::microseconds>(
                         std::chrono::steady_clock::now() - start).count();

        if (solution.empty()) {
            g_failures++;
            std::printf("  FAIL: no solution for case %d\n", i);
            continue;
        }
        // Every returned move must be a legal token.
        CHECK(!parseSequence(sequenceToString(solution)).empty());
        CHECK((int)parseSequence(sequenceToString(solution)).size() == (int)solution.size());

        const CubieState result = applySequence(scrambled, solution);
        if (CubeModel::isSolved(result)) {
            solvedCount++;
            minLen = std::min(minLen, (int)solution.size());
            maxLen = std::max(maxLen, (int)solution.size());
            totalLen += (int)solution.size();
        } else {
            g_failures++;
            std::printf("  FAIL: case %d not solved by %s\n", i,
                        sequenceToString(solution).c_str());
        }
    }
    CHECK(solvedCount == cases);
    std::printf("  %d/%d solved, moves min/avg/max = %d/%.1f/%d, avg %.0f ms\n",
                solvedCount, cases, minLen, (double)totalLen / cases, maxLen,
                totalUsec / 1000.0 / cases);
    CHECK(maxLen <= 26);

    // A facelet string round trip through the solver must match the cubie one.
    {
        const CubieState scrambled =
            applySequence(CubeModel::solvedState(), randomScramble(rng, 25));
        const std::string facelets = CubeModel::cubieToFacelets(scrambled);
        const std::string text = KociembaEngine::solveFacelets(facelets, 22);
        CHECK(text.rfind("ERROR", 0) != 0);
        const std::vector<int> moves = parseSequence(text);
        CHECK(CubeModel::isSolved(applySequence(scrambled, moves)));
    }
}

/// States that already live in <U, D, R2, F2, L2, B2> isolate phase 2.
static void testPhase2Completions() {
    std::printf("[test] phase 2 completions (states already in the subgroup)\n");

    static const int p2[10] = { 0, 1, 2, 9, 10, 11, 4, 7, 13, 16 };
    KociembaEngine& engine = KociembaEngine::instance();
    Rng rng(5);

    int failuresHere = 0;
    for (int i = 0; i < 50; ++i) {
        std::vector<int> seq;
        const int n = 4 + rng.below(9);
        for (int k = 0; k < n; ++k) seq.push_back(p2[rng.below(10)]);
        const CubieState state = applySequence(CubeModel::solvedState(), seq);
        CHECK(inPhase2Subgroup(state));

        const std::vector<int> sol = engine.solve(state, 22, 2.0);
        if (!CubeModel::isSolved(applySequence(state, sol))) {
            failuresHere++;
            if (failuresHere <= 3) {
                std::printf("  case %d: cp=%d ep=%d sp=%d\n", i,
                            cornerPermCoord(state), edgePermCoord(state),
                            slicePermCoord(state));
                std::printf("    scramble %s\n", sequenceToString(seq).c_str());
                std::printf("    solution %s -> cp=%d ep=%d sp=%d\n",
                            sequenceToString(sol).c_str(),
                            cornerPermCoord(applySequence(state, sol)),
                            edgePermCoord(applySequence(state, sol)),
                            slicePermCoord(applySequence(state, sol)));
            }
            g_failures++;
        }
    }
    std::printf("  %d/50 failed\n", failuresHere);
}

/// Phase 1 alone must land the cube inside the phase 2 subgroup.
static void testPhase1ReachesSubgroup() {
    std::printf("[test] phase 1 reaches the phase 2 subgroup\n");

    KociembaEngine& engine = KociembaEngine::instance();
    Rng rng(11);
    int bad = 0;
    for (int i = 0; i < 50; ++i) {
        const CubieState state =
            applySequence(CubeModel::solvedState(), randomScramble(rng, 25));
        const std::vector<int> sol = engine.solve(state, 22, 2.0);
        const int split = engine.lastPhase1Length();
        if (split <= 0 || split > (int)sol.size()) {
            bad++;
            continue;
        }
        std::vector<int> head(sol.begin(), sol.begin() + split);
        const CubieState after1 = applySequence(state, head);
        if (!inPhase2Subgroup(after1)) {
            bad++;
            if (bad <= 3) {
                std::printf("  case %d: phase1=%s leaves twist=%d flip=%d slice=%d\n",
                            i, sequenceToString(head).c_str(),
                            twistCoord(after1), flipCoord(after1), sliceCoord(after1));
            }
        }
    }
    CHECK(bad == 0);
    std::printf("  %d/50 phase 1 splits bad\n", bad);
}

// ------------------------------------------------------------------ CFOP

static void testCfopStages() {
    std::printf("[test] cfop staged teaching solver\n");

    CfopEngine& engine = CfopEngine::instance();
    const auto t0 = std::chrono::steady_clock::now();
    engine.ensureTables();
    const double buildMs = std::chrono::duration<double, std::milli>(
                               std::chrono::steady_clock::now() - t0).count();
    std::printf("  tables built in %.0f ms, %.2f MB\n", buildMs,
                engine.tableBytes() / 1048576.0);
    if (!engine.tablesComplete()) std::printf("%s", engine.tableDiagnostics().c_str());
    CHECK(engine.tablesComplete());

    // A solved cube needs no teaching steps at all.
    CubieState solved = CubeModel::solvedState();
    CHECK(engine.solve(solved).empty());

    // A cross-only scramble must only ask for the cross stage.
    {
        const CubieState s = applySequence(CubeModel::solvedState(), parseSequence("D R2 F2"));
        const std::vector<CfopEngine::Stage> stages = engine.solve(s);
        CHECK(!stages.empty());
        CHECK(stages.front().stage == CFOPStage::CROSS);
    }

    Rng rng(4242);
    const int cases = 40;
    int solvedCount = 0;
    int minTotal = 1 << 30;
    int maxTotal = 0;
    long long sumTotal = 0;
    long long sumUsec = 0;
    int maxStageLen = 0;
    int maxEarlyStageLen = 0;
    int fallbacks = 0;
    for (int i = 0; i < cases; ++i) {
        const CubieState scrambled =
            applySequence(CubeModel::solvedState(), randomScramble(rng, 25));

        const auto start = std::chrono::steady_clock::now();
        const std::vector<CfopEngine::Stage> stages = engine.solve(scrambled);
        sumUsec += std::chrono::duration_cast<std::chrono::microseconds>(
                       std::chrono::steady_clock::now() - start).count();

        if (stages.empty()) {
            g_failures++;
            std::printf("  FAIL: case %d produced no stages\n", i);
            continue;
        }

        int total = 0;
        for (const CfopEngine::Stage& stage : stages) {
            if (stage.moves.empty()) {
                g_failures++;
                std::printf("  FAIL: case %d has an empty stage %s\n", i,
                            stage.name.c_str());
            }
            total += (int)stage.moves.size();
            maxStageLen = std::max(maxStageLen, (int)stage.moves.size());
            if (stage.stage < CFOPStage::OLL_2LOOK_EDGE) {
                maxEarlyStageLen = std::max(maxEarlyStageLen, (int)stage.moves.size());
            }

            // A last layer stage must be a chain of named algorithms, not a
            // raw search dump: that is the whole teaching requirement. The one
            // legitimate exception is the "adjust the top face" case, where the
            // sub problem is already finished up to a U rotation and the stage
            // is a bare U turn.
            if (stage.stage >= CFOPStage::OLL_2LOOK_EDGE) {
                if (stage.algos.empty() && !onlyUTurns(stage.moves)) {
                    g_failures++;
                    std::printf("  FAIL: case %d last layer stage %s has no named algorithm"
                                " and is not a plain top layer adjustment (%s)\n",
                                i, stage.name.c_str(),
                                sequenceToString(stage.moves).c_str());
                }
                if (stage.moves.size() > kLastLayerStageCap) {
                    g_failures++;
                    std::printf("  FAIL: case %d last layer stage %s is %d moves\n",
                                i, stage.name.c_str(), (int)stage.moves.size());
                }
            }
        }
        for (int k = 0; k < 9; ++k) {
            if (engine.lastStageTier[k] == CfopEngine::MAX_TIER) fallbacks++;
        }

        // Replaying every stage in order must solve the cube.
        std::vector<int> all;
        for (const CfopEngine::Stage& stage : stages) {
            all.insert(all.end(), stage.moves.begin(), stage.moves.end());
        }
        if (CubeModel::isSolved(applySequence(scrambled, all))) {
            solvedCount++;
            minTotal = std::min(minTotal, total);
            maxTotal = std::max(maxTotal, total);
            sumTotal += total;
        } else {
            g_failures++;
            std::printf("  FAIL: case %d (=%d moves) does not solve the cube\n", i, total);
        }

        // Stage order must follow the method.
        static const int order[9] = { 0, 1, 2, 3, 4, 5, 6, 7, 8 };
        size_t previous = 0;
        for (const CfopEngine::Stage& stage : stages) {
            const size_t rank = (size_t)stage.stage;
            if (rank < previous) {
                g_failures++;
                std::printf("  FAIL: case %d stage order broken\n", i);
                break;
            }
            previous = rank;
        }
        (void)order;
    }

    CHECK(solvedCount == cases);
    std::printf("  %d/%d solved, total moves min/avg/max = %d/%.1f/%d, longest stage %d (cross/F2L %d), avg %.0f ms, two phase fallbacks %d\n",
                solvedCount, cases, minTotal, (double)sumTotal / cases, maxTotal,
                maxStageLen, maxEarlyStageLen, sumUsec / 1000.0 / cases, fallbacks);
    {
        static const char* planName[9] = { "cross", "f2l1", "f2l2", "f2l3", "f2l4",
                                           "oll-e", "oll-c", "pll-c", "pll-e" };
        std::printf("  per stage: ");
        for (int k = 0; k < 9; ++k) {
            std::printf("%s=%.0fms/t%d ", planName[k],
                        engine.lastStageMicros[k] / 1000.0, engine.lastStageTier[k]);
        }
        std::printf("\n");
    }
    // Cross and F2L are searched, and their tight limits are 9 and 13, so a
    // 20 move stage there would already mean a fallback fired. The last layer
    // is bounded separately by kLastLayerStageCap inside the loop.
    CHECK(maxEarlyStageLen <= 20);
    CHECK(maxStageLen <= kLastLayerStageCap);
    // Nothing in a 40 case sample should have needed the two phase crutch: a
    // stage that falls through to it is a stage the teaching pipeline failed
    // to express with its own method.
    CHECK(fallbacks == 0);

    // Invalid input yields no guide instead of garbage.
    CHECK(CFOPSolver::generateGuide(std::string(54, 'U')).empty());

    // The JSON facing facade returns one entry per produced stage.
    {
        const CubieState scrambled =
            applySequence(CubeModel::solvedState(), randomScramble(rng, 20));
        const std::vector<CFOPStep> steps =
            CFOPSolver::generateGuide(CubeModel::cubieToFacelets(scrambled));
        CHECK(!steps.empty());
        for (const CFOPStep& step : steps) {
            CHECK(!step.stage_name.empty());
            CHECK(!step.formula.empty());
            CHECK(!step.visual_hint.empty());
            CHECK(!step.explanation.empty());

            // The teaching facade must name the formulas, not just list moves.
            // The one exception is the top layer alignment case, where the
            // explanation says so instead.
            if (step.stage >= CFOPStage::OLL_2LOOK_EDGE) {
                if (step.algorithms.empty()) {
                    CHECK(onlyUTurns(parseSequence(step.formula)));
                    CHECK(step.visual_hint.find("对齐") != std::string::npos);
                } else {
                    CHECK(step.explanation.find(step.algorithms.front()) !=
                          std::string::npos);
                }
            } else {
                CHECK(step.algorithms.empty());
            }
        }
        std::vector<int> all;
        for (const CFOPStep& step : steps) {
            const std::vector<int> m = parseSequence(step.formula);
            CHECK(!m.empty());
            all.insert(all.end(), m.begin(), m.end());
        }
        CHECK(CubeModel::isSolved(applySequence(scrambled, all)));
    }
}

// ------------------------------------------- last layer teaching algorithms

static bool f2lSolved(const CubieState& s) {
    return CfopEngine::stageReached(CfopEngine::GoalId::Pair, 3, s);
}

/// The curated 2-look OLL / PLL set has to be trustworthy.
///
/// A mis-transcribed algorithm would not crash anything - the stage search
/// would simply never use it, or would hand the learner a formula that
/// destroys the two layers they just built. Every entry is checked for the
/// property that matters (keeps F2L intact) and the raw last layer effect is
/// printed, so a wrong transcription is visible at a glance. The sub goal
/// check happens in testLastLayerCompleteness, which is the one that can be
/// stated without hand-derived expectations.
static void testLastLayerAlgorithms() {
    std::printf("[test] last layer teaching algorithms\n");

    static const char* kindName[4] = { "oll-e", "oll-c", "pll-c", "pll-e" };
    int counts[4] = { 0, 0, 0, 0 };

    for (const LlAlgorithm& alg : lastLayerAlgorithms()) {
        const CubieState after = applySequence(CubeModel::solvedState(), alg.moves);
        const int kind = (int)alg.kind;

        CHECK(!alg.moves.empty());
        CHECK(alg.moves.size() == parseSequence(alg.notation).size());

        if (!f2lSolved(after)) {
            g_failures++;
            std::printf("  FAIL: %s breaks the first two layers\n", alg.name.c_str());
        }

        counts[kind]++;
        std::printf("  %-5s %-30s %-34s cp[%d%d%d%d] co[%d%d%d%d] ep[%d%d%d%d] eo[%d%d%d%d]\n",
                    kindName[kind], alg.name.c_str(), alg.notation.c_str(),
                    after.cp[URF], after.cp[UFL], after.cp[ULB], after.cp[UBR],
                    after.co[URF], after.co[UFL], after.co[ULB], after.co[UBR],
                    after.ep[UR], after.ep[UF], after.ep[UL], after.ep[UB],
                    after.eo[UR], after.eo[UF], after.eo[UL], after.eo[UB]);
    }

    // Each sub step needs enough generators to reach every state:
    // two cross algorithms, two corner orientation algorithms, an even and an
    // odd corner permutation, and a pair of 3-cycles plus a double
    // transposition for the edges.
    CHECK(counts[0] >= 2);
    CHECK(counts[1] >= 2);
    CHECK(counts[2] >= 4);
    CHECK(counts[3] >= 3);
}

// ------------------------------------------------ last layer completeness

/// A last layer state with the first two layers solved: the pieces that are not
/// in the last layer keep their home position and orientation, the four corners
/// and four edges of the last layer are placed by the given permutations.
static CubieState makeLastLayerState(const int* cp, const int* co,
                                     const int* ep, const int* eo) {
    CubieState s = CubeModel::solvedState();
    for (int i = 0; i < 4; ++i) {
        s.cp[i] = (int8_t)cp[i];
        s.co[i] = (int8_t)co[i];
        s.ep[i] = (int8_t)ep[i];
        s.eo[i] = (int8_t)eo[i];
    }
    return s;
}

/// Parity of a permutation given as "the piece sitting at position `i`".
static int permParity(const int* p, int n) {
    int inversions = 0;
    for (int i = 0; i < n; ++i) {
        for (int j = i + 1; j < n; ++j) {
            if (p[i] > p[j]) inversions++;
        }
    }
    return inversions % 2;
}

/// Every legal last layer state must be reachable with the named algorithms.
///
/// This is the test that actually protects the teaching guarantee. A hole in
/// an algorithm group is not an error the compiler or the end to end test would
/// ever report: the stage search would simply fall through to a raw IDA*
/// search and quietly hand the learner a 25 move soup instead of a formula.
/// Enumerating the whole legal space of each sub problem is the only way to
/// know the promise "one or two recognisable formulas per stage" holds for
/// every scramble rather than for the ones we happened to sample.
static void testLastLayerCompleteness() {
    std::printf("[test] last layer algorithm groups are complete\n");

    CfopEngine& engine = CfopEngine::instance();
    engine.ensureTables();

    int perms[24][4];
    int permCount = 0;
    {
        int a[4] = { 0, 1, 2, 3 };
        do {
            for (int i = 0; i < 4; ++i) perms[permCount][i] = a[i];
            permCount++;
        } while (std::next_permutation(a, a + 4));
    }
    CHECK(permCount == 24);

    const int co0[4] = { 0, 0, 0, 0 };
    const int eo0[4] = { 0, 0, 0, 0 };
    const int home[4] = { 0, 1, 2, 3 };

    std::vector<int> moves;
    std::vector<std::string> algos;
    int tried = 0;
    int failed = 0;
    int worstLen = 0;
    int worstAlgos = 0;
    int lenHist[64] = { 0 };

    const auto attempt = [&](CfopEngine::GoalId goal, const CubieState& state,
                             const char* what) {
        moves.clear();
        algos.clear();
        tried++;
        if (!engine.solveLastLayerStage(goal, -1, state, moves, algos)) {
            failed++;
            if (failed <= 8) std::printf("  FAIL: no algorithm chain for %s\n", what);
            return;
        }
        // The chain has to do what it claims, not merely exist.
        if (!CfopEngine::stageReached(goal, -1, applySequence(state, moves))) {
            failed++;
            std::printf("  FAIL: chain for %s does not reach the goal\n", what);
            return;
        }
        const int len = (int)moves.size();
        worstLen = std::max(worstLen, len);
        worstAlgos = std::max(worstAlgos, (int)algos.size());
        if (len >= 0 && len < 64) lenHist[len]++;
    };

    // Edge orientation: the 8 patterns with an even number of flipped edges.
    for (int mask = 0; mask < 16; ++mask) {
        int eo[4];
        int flipped = 0;
        for (int i = 0; i < 4; ++i) {
            eo[i] = (mask >> i) & 1;
            flipped += eo[i];
        }
        if (flipped % 2) continue;
        attempt(CfopEngine::GoalId::OllEdge,
                makeLastLayerState(home, co0, home, eo), "edge orientation");
    }

    // Corner orientation: the 27 patterns whose twist sum is 0 mod 3.
    for (int mask = 0; mask < 81; ++mask) {
        int co[4];
        int rest = mask;
        int sum = 0;
        for (int i = 0; i < 4; ++i) {
            co[i] = rest % 3;
            rest /= 3;
            sum += co[i];
        }
        if (sum % 3) continue;
        attempt(CfopEngine::GoalId::OllCorner,
                makeLastLayerState(home, co, home, eo0), "corner orientation");
    }

    // Corner placement: all 24 corner permutations against all edge
    // permutations of matching parity - the states this step can really face.
    int placementStates = 0;
    for (int ci = 0; ci < permCount; ++ci) {
        for (int ei = 0; ei < permCount; ++ei) {
            if (permParity(perms[ci], 4) != permParity(perms[ei], 4)) continue;
            placementStates++;
            attempt(CfopEngine::GoalId::PllCorner,
                    makeLastLayerState(perms[ci], co0, perms[ei], eo0),
                    "corner placement");
        }
    }
    CHECK(placementStates == 288);

    // Edge placement: corners home, so only the 12 even edge permutations are left.
    for (int ei = 0; ei < permCount; ++ei) {
        if (permParity(perms[ei], 4) != 0) continue;
        attempt(CfopEngine::GoalId::Solved,
                makeLastLayerState(home, co0, perms[ei], eo0), "edge placement");
    }

    std::printf("  %d states, %d unsolved, longest chain %d moves (up to %d algorithms)\n",
                tried, failed, worstLen, worstAlgos);
    std::printf("  chain lengths:");
    for (int len = 0; len < 64; ++len) {
        if (lenHist[len]) std::printf(" %dx%d", len, lenHist[len]);
    }
    std::printf("\n");
    CHECK(failed == 0);
    // "2-look" has to stay a promise: an algorithm, maybe a setup turn either
    // side, and for the awkward corner cases one extra algorithm.
    CHECK(worstAlgos <= 3);
}

// ---------------------------------------------------------------------------
// Vision: sampling, colour classification, face assembly
// ---------------------------------------------------------------------------

/// Renders a 3x3 sticker grid into an RGBA frame the pipeline can read.
///
/// [cast] simulates a white balance error by scaling the channels, which is the
/// single largest source of real world misreads.
///
/// Synthetic frames are the only way to test this half of the engine: a phone
/// camera cannot be reproduced on a build machine, but "the camera saw exactly
/// these pixels" is just an array, and everything downstream of the pixels can
/// be checked exactly.
static std::vector<uint8_t> renderFaceRgba(int width, int height,
                                           const RgbColor cells[9],
                                           const RgbColor& cast = { 1.0f, 1.0f, 1.0f }) {
    std::vector<uint8_t> px(
        static_cast<size_t>(width) * static_cast<size_t>(height) * 4, 0);

    const float side = std::min(width, height) * 0.72f;
    const float left = (static_cast<float>(width) - side) * 0.5f;
    const float top = (static_cast<float>(height) - side) * 0.5f;
    const float cell = side / 3.0f;

    for (int y = 0; y < height; ++y) {
        for (int x = 0; x < width; ++x) {
            const float fx = static_cast<float>(x) - left;
            const float fy = static_cast<float>(y) - top;
            // Outside the guide box the camera sees the table: black.
            if (fx < 0.0f || fy < 0.0f || fx >= side || fy >= side) continue;

            const int gx = std::min(2, static_cast<int>(fx / cell));
            const int gy = std::min(2, static_cast<int>(fy / cell));
            const RgbColor c = cells[gy * 3 + gx];

            uint8_t* p = &px[(static_cast<size_t>(y) * static_cast<size_t>(width) + x) * 4];
            p[0] = static_cast<uint8_t>(clampChannel(c.r * cast.r));
            p[1] = static_cast<uint8_t>(clampChannel(c.g * cast.g));
            p[2] = static_cast<uint8_t>(clampChannel(c.b * cast.b));
            p[3] = 255;
        }
    }
    return px;
}

/// Sticker colours close to, but deliberately not equal to, the classifier's
/// anchors. Feeding the anchors back in would prove the lookup table works
/// while saying nothing about actual cubes and actual cameras.
static const RgbColor kTestStickers[6] = {
    { 250.0f, 250.0f, 250.0f },  // white
    { 210.0f,  40.0f,  50.0f },  // red
    {  40.0f, 175.0f,  80.0f },  // green
    { 250.0f, 220.0f,  60.0f },  // yellow
    { 235.0f, 150.0f,  40.0f },  // orange
    {  35.0f,  95.0f, 195.0f },  // blue
};

static const DetectedColor kTestLayout[9] = {
    DetectedColor::WHITE,  DetectedColor::RED,    DetectedColor::GREEN,
    DetectedColor::YELLOW, DetectedColor::WHITE,  DetectedColor::BLUE,
    DetectedColor::ORANGE, DetectedColor::RED,    DetectedColor::GREEN,
};

static void fillTestCells(RgbColor cells[9]) {
    for (int i = 0; i < 9; ++i) cells[i] = kTestStickers[static_cast<int>(kTestLayout[i])];
}

static void testVisionSampling() {
    std::printf("[test] vision sampling and colour classification\n");

    RgbColor cells[9];
    fillTestCells(cells);

    constexpr int kW = 480;
    constexpr int kH = 480;
    const std::vector<uint8_t> frame = renderFaceRgba(kW, kH, cells);

    const FaceSample sample = sampleFaceGrid(FrameView::rgba(frame.data(), kW, kH, kW * 4));
    CHECK(sample.ok);

    AdaptiveColorClassifier classifier;
    int misread = 0;
    for (int i = 0; i < 9; ++i) {
        if (classifier.classify(sample.lab[i]) != kTestLayout[i]) ++misread;
    }
    if (misread != 0) {
        g_failures++;
        std::printf("  FAIL: %d/9 cells misread on a clean frame\n", misread);
    }

    // The same colours through a landscape sensor frame, read both raw and
    // quarter turned. The grid is centred, so both must land on the stickers:
    // if the rotation mapping were wrong the sampler would be reading the black
    // background and every cell would come back dark.
    const std::vector<uint8_t> landscape = renderFaceRgba(640, 480, cells);
    const FaceSample raw =
        sampleFaceGrid(FrameView::rgba(landscape.data(), 640, 480, 640 * 4, 0));
    const FaceSample turned =
        sampleFaceGrid(FrameView::rgba(landscape.data(), 640, 480, 640 * 4, 90));
    CHECK(raw.ok);
    CHECK(turned.ok);

    // A quarter turned frame shows the same face rotated a quarter turn, so the
    // expectation has to be rotated too - comparing against the raw layout
    // would be testing the sticker order, not the geometry.
    DetectedColor expectedTurned[9];
    for (int r = 0; r < 3; ++r) {
        for (int c = 0; c < 3; ++c) {
            expectedTurned[r * 3 + c] = kTestLayout[(2 - c) * 3 + r];
        }
    }

    int rawWrong = 0;
    int turnedWrong = 0;
    AdaptiveColorClassifier probe;
    for (int i = 0; i < 9; ++i) {
        if (probe.classify(raw.lab[i]) != kTestLayout[i]) ++rawWrong;
        if (probe.classify(turned.lab[i]) != expectedTurned[i]) ++turnedWrong;
    }
    if (rawWrong != 0 || turnedWrong != 0) {
        g_failures++;
        std::printf("  FAIL: sensor orientation changed the reading (raw %d, turned %d wrong)\n",
                    rawWrong, turnedWrong);
    }

    // --- white balance ------------------------------------------------------
    // The same cube under a strong warm cast, the way a phone renders it near a
    // tungsten lamp. Uncorrected, the factory anchors mistake warm white for
    // orange and yellow for orange - the exact failure users describe as "it
    // thinks my cube is impossible".
    const RgbColor warmCast{ 1.00f, 0.72f, 0.42f };
    const std::vector<uint8_t> warmFrame = renderFaceRgba(kW, kH, cells, warmCast);
    const FaceSample warmSample =
        sampleFaceGrid(FrameView::rgba(warmFrame.data(), kW, kH, kW * 4));
    CHECK(warmSample.ok);

    AdaptiveColorClassifier warm;
    int wrongBefore = 0;
    for (int i = 0; i < 9; ++i) {
        if (warm.classify(warmSample.lab[i]) != kTestLayout[i]) ++wrongBefore;
    }
    if (wrongBefore == 0) {
        g_failures++;
        std::printf("  FAIL: the warm cast was too mild to prove anything\n");
    }

    warm.calibrateWhite(warmSample.rgb[4]);
    CHECK(warm.hasWhiteReference());

    int wrongAfter = 0;
    for (int i = 0; i < 9; ++i) {
        if (warm.classify(warmSample.lab[i]) != kTestLayout[i]) ++wrongAfter;
    }
    if (wrongAfter != 0) {
        g_failures++;
        std::printf("  FAIL: white balance left %d/9 cells wrong (was %d)\n",
                    wrongAfter, wrongBefore);
    }
    std::printf("  clean frame 0/9 wrong, warm cast %d/9 wrong -> %d/9 after white balance\n",
                wrongBefore, wrongAfter);
}

/// Rebuilds the six face grids a scanner would produce from [facelets].
///
/// Each face is rotated by a random amount, which is the whole point: a user
/// holding a cube has no way to present a face at a known orientation.
static std::map<DetectedColor, std::array<DetectedColor, 9>> scannedFaces(
    const std::string& facelets, Rng& rng) {
    static const int kRot[4][9] = {
        { 0, 1, 2, 3, 4, 5, 6, 7, 8 },
        { 6, 3, 0, 7, 4, 1, 8, 5, 2 },
        { 8, 7, 6, 5, 4, 3, 2, 1, 0 },
        { 2, 5, 8, 1, 4, 7, 0, 3, 6 },
    };

    std::map<DetectedColor, std::array<DetectedColor, 9>> faces;
    for (int face = 0; face < 6; ++face) {
        const int rot = static_cast<int>(rng.below(4));
        std::array<DetectedColor, 9> grid{};
        for (int k = 0; k < 9; ++k) {
            const char ch = facelets[static_cast<size_t>(face) * 9 +
                                      static_cast<size_t>(kRot[rot][k])];
            grid[k] = static_cast<DetectedColor>(FaceAssembler::colorIndex(ch));
        }
        faces[static_cast<DetectedColor>(face)] = grid;
    }
    return faces;
}

/// The multiset of piece colourings: for every corner and edge, the sorted list
/// of colours it carries.
///
/// This is the sound way to compare two descriptions of the same physical cube
/// without enumerating its 24 orientations. An overall rotation moves pieces
/// around but never repaints them, so the multiset is invariant - and it is
/// exactly the property a wrongly stitched face breaks, because a bad relative
/// rotation repaints pieces while leaving the face count intact. (It is a
/// necessary rather than sufficient condition, which is fine here: the
/// assembler already rejects anything that is not a legal cube, so this only
/// has to catch a legal cube that is the *wrong* legal cube.)
static std::vector<std::string> pieceColourings(const CubieState& s) {
    std::vector<std::string> out;
    out.reserve(20);

    for (int i = 0; i < 8; ++i) {
        std::string k = "c";
        for (int j = 0; j < 3; ++j) {
            k += FaceAssembler::colorChar(CubeModel::cornerColors[s.cp[i]][j]);
        }
        std::sort(k.begin() + 1, k.end());
        out.push_back(k);
    }
    for (int i = 0; i < 12; ++i) {
        std::string k = "e";
        for (int j = 0; j < 2; ++j) {
            k += FaceAssembler::colorChar(CubeModel::edgeColors[s.ep[i]][j]);
        }
        std::sort(k.begin() + 1, k.end());
        out.push_back(k);
    }

    std::sort(out.begin(), out.end());
    return out;
}

static void testFaceAssembly() {
    std::printf("[test] face assembly and orientation recovery\n");

    Rng rng(20260928);
    const int cases = 60;
    int recovered = 0;

    for (int c = 0; c < cases; ++c) {
        const CubieState scrambled =
            applySequence(CubeModel::solvedState(), randomScramble(rng, 25));
        const std::string facelets = CubeModel::cubieToFacelets(scrambled);

        const FaceAssembler::Result r =
            FaceAssembler::solve(scannedFaces(facelets, rng));
        if (!r.ok) {
            g_failures++;
            std::printf("  FAIL: case %d assembly failed (score %d/%d): %s\n", c,
                        r.score, FaceAssembler::kMaxScore, r.error.c_str());
            continue;
        }
        if (r.score != FaceAssembler::kMaxScore) {
            g_failures++;
            std::printf("  FAIL: case %d validated with score %d\n", c, r.score);
        }

        CubieState got{};
        std::string err;
        if (!CubeModel::faceletsToCubie(r.facelets, got, err)) {
            g_failures++;
            std::printf("  FAIL: case %d produced an undecodable state: %s\n",
                        c, err.c_str());
            continue;
        }
        if (pieceColourings(got) != pieceColourings(scrambled)) {
            g_failures++;
            std::printf("  FAIL: case %d assembled into a different cube\n", c);
            continue;
        }
        ++recovered;
    }

    std::printf("  %d/%d scrambled cubes recovered from randomly rotated faces\n",
                recovered, cases);

    // A misread sticker has to be visible rather than silently accepted: two
    // swapped cells on one face leave the alignment perfect but the pieces
    // impossible, which is exactly what the score is for.
    Rng badRng(77);
    const CubieState state =
        applySequence(CubeModel::solvedState(), randomScramble(badRng, 20));
    auto faces = scannedFaces(CubeModel::cubieToFacelets(state), badRng);
    auto damaged = faces[DetectedColor::WHITE];
    std::swap(damaged[0], damaged[1]);
    faces[DetectedColor::WHITE] = damaged;

    const FaceAssembler::Result broken = FaceAssembler::solve(faces);
    if (broken.ok) {
        g_failures++;
        std::printf("  FAIL: a swapped sticker pair was accepted as a valid cube\n");
    }
    CHECK(broken.score < FaceAssembler::kMaxScore);
}

int main() {
    std::printf("=== Rubik native engine tests ===\n");
    testFaceletsRoundTrip();
    testSingleTurns();
    testMoveGroupOrders();
    testValidationRejectsIllegalStates();
    testCoordinates();
    testKociemba();
    testPhase2Completions();
    testPhase1ReachesSubgroup();
    testLastLayerAlgorithms();
    testLastLayerCompleteness();
    testCfopStages();
    testVisionSampling();
    testFaceAssembly();

    std::printf("---\n%d checks, %d failures\n", g_checks, g_failures);
    if (g_failures == 0) std::printf("ALL TESTS PASSED\n");
    return g_failures == 0 ? 0 : 1;
}

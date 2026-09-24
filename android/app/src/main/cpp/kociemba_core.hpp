#pragma once
// Kociemba two-phase Rubik's cube solver -- core engine.
//
// Deliberately free of the C++ standard library: no std::string, no
// std::vector, no heap and no exceptions.  Everything lives in fixed-size
// arrays so the very same code runs inside the Android .so and inside a
// wasm32 build used by the offline test harness.
//
// Coordinate frame: x = R, y = U, z = F.
// Face order (Kociemba / URFDLB): U=0 R=1 F=2 D=3 L=4 B=5.

#include <stdint.h>

namespace rubik {

enum {
    N_MOVES = 18,
    N_TWIST = 2187,      // 3^7 corner orientations
    N_FLIP = 2048,       // 2^11 edge orientations
    N_SLICE = 495,       // C(12,4) positions of the four middle edges
    N_CPERM = 40320,     // 8!
    N_EPERM = 40320,     // 8!  (U/D layer edge permutation)
    N_SPERM = 24         // 4!  (middle slice edge permutation)
};

static const char* const MOVE_NAMES[N_MOVES] = {
    "U", "U2", "U'", "R", "R2", "R'", "F", "F2", "F'",
    "D", "D2", "D'", "L", "L2", "L'", "B", "B2", "B'"
};

static constexpr uint8_t MOVE_FACE[N_MOVES] = {
    0, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4, 5, 5, 5
};
static constexpr uint8_t MOVE_POWER[N_MOVES] = {
    1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3, 1, 2, 3
};
// generators that keep the cube inside the subgroup G1
static constexpr uint8_t PHASE2_MOVES[10] = {0, 1, 2, 9, 10, 11, 4, 13, 7, 16};
static constexpr int N_PHASE2 = 10;

// Cubie indices
enum { URF = 0, UFL, ULB, UBR, DFR, DLF, DBL, DRB };
enum { UR = 0, UF, UL, UB, DR, DF, DL, DB, FR, FL, BL, BR };

// Sticker indices of each cubie in its home position.  BL/BR are {50,39}
// and {48,14} -- facelet 50 lies on the B face at x=+1 (BR's corner) and 48
// at x=-1 (BL's corner).  These two used to be swapped in cube_model.hpp.
static constexpr uint8_t CORNER_FACELET[8][3] = {
    { 8,  9, 20 }, { 6, 18, 38 }, { 0, 36, 47 }, { 2, 45, 11 },
    { 29, 26, 15 }, { 27, 44, 24 }, { 33, 53, 42 }, { 35, 17, 51 }
};
static constexpr uint8_t EDGE_FACELET[12][2] = {
    { 5, 10 }, { 7, 19 }, { 3, 37 }, { 1, 46 },
    { 32, 16 }, { 28, 25 }, { 30, 43 }, { 34, 52 },
    { 23, 12 }, { 21, 41 }, { 50, 39 }, { 48, 14 }
};

struct Cubie {
    int8_t cp[8];
    int8_t co[8];
    int8_t ep[12];
    int8_t eo[12];
};

// ------------------------------------------------------------------ helpers
static inline int8_t char_to_color(char c) {
    switch (c) {
        case 'U': case 'W': return 0;
        case 'R': return 1;
        case 'F': case 'G': return 2;
        case 'D': case 'Y': return 3;
        case 'L': case 'O': return 4;
        case 'B': return 5;
        default: return -1;
    }
}

static inline int match_corner(int a, int b, int c) {
    if (a > b) { int t = a; a = b; b = t; }
    if (b > c) { int t = b; b = c; c = t; }
    if (a > b) { int t = a; a = b; b = t; }
    if (a == 0 && b == 1 && c == 2) return URF;
    if (a == 0 && b == 2 && c == 4) return UFL;
    if (a == 0 && b == 4 && c == 5) return ULB;
    if (a == 0 && b == 1 && c == 5) return UBR;
    if (a == 1 && b == 2 && c == 3) return DFR;
    if (a == 2 && b == 3 && c == 4) return DLF;
    if (a == 3 && b == 4 && c == 5) return DBL;
    if (a == 1 && b == 3 && c == 5) return DRB;
    return -1;
}

static inline int match_edge(int a, int b) {
    int u = a < b ? a : b, v = a < b ? b : a;
    if (u == 0 && v == 1) return UR;
    if (u == 0 && v == 2) return UF;
    if (u == 0 && v == 4) return UL;
    if (u == 0 && v == 5) return UB;
    if (u == 1 && v == 3) return DR;
    if (u == 2 && v == 3) return DF;
    if (u == 3 && v == 4) return DL;
    if (u == 3 && v == 5) return DB;
    if (u == 1 && v == 2) return FR;
    if (u == 2 && v == 4) return FL;
    if (u == 4 && v == 5) return BL;
    if (u == 1 && v == 5) return BR;
    return -1;
}

// --------------------------------------------------------------- the engine
class Engine {
public:
    bool ready() const { return ready_; }

    // Decodes a 54 character facelet string.  Returns 0 on success and a
    // negative code when the string is not a legal cube state.
    int decode(const char* f, Cubie& out) const {
        int8_t col[54];
        for (int i = 0; i < 54; ++i) {
            int8_t c = char_to_color(f[i]);
            if (c < 0) return -1;
            col[i] = c;
        }
        for (int i = 0; i < 8; ++i) {
            int f0 = col[CORNER_FACELET[i][0]];
            int f1 = col[CORNER_FACELET[i][1]];
            int f2 = col[CORNER_FACELET[i][2]];
            int ori = (f1 == 0 || f1 == 3) ? 1 : ((f2 == 0 || f2 == 3) ? 2 : 0);
            int tri[3] = {f0, f1, f2};
            out.co[i] = (int8_t)ori;
            int c = match_corner(tri[(3 - ori) % 3], tri[(4 - ori) % 3],
                                 tri[(5 - ori) % 3]);
            if (c < 0) return -2;
            out.cp[i] = (int8_t)c;
        }
        for (int i = 0; i < 12; ++i) {
            int c1 = col[EDGE_FACELET[i][0]];
            int c2 = col[EDGE_FACELET[i][1]];
            int ori;
            if (c1 == 0 || c1 == 3) ori = 0;
            else if (c2 == 0 || c2 == 3) ori = 1;
            else if (c1 == 2 || c1 == 5) ori = 0;
            else ori = 1;
            out.eo[i] = (int8_t)ori;
            int e = match_edge(c1, c2);
            if (e < 0) return -3;
            out.ep[i] = (int8_t)e;
        }
        int twist = 0;
        for (int i = 0; i < 8; ++i) twist += out.co[i];
        if (twist % 3 != 0) return -4;
        int flip = 0;
        for (int i = 0; i < 12; ++i) flip += out.eo[i];
        if (flip % 2 != 0) return -5;
        if (perm_parity(out.cp, 8) != perm_parity(out.ep, 12)) return -6;
        return 0;
    }

    void solved(Cubie& c) const {
        for (int i = 0; i < 8; ++i) { c.cp[i] = (int8_t)i; c.co[i] = 0; }
        for (int i = 0; i < 12; ++i) { c.ep[i] = (int8_t)i; c.eo[i] = 0; }
    }

    // Applies one move (by index) to a cubie state.
    void apply(Cubie& c, int mi) const {
        int face = MOVE_FACE[mi];
        for (int p = 0; p < MOVE_POWER[mi]; ++p) {
            const int8_t* mc = cm_cp_[face];
            const int8_t* mco = cm_co_[face];
            const int8_t* me = cm_ep_[face];
            const int8_t* meo = cm_eo_[face];
            int8_t ncp[8], nco[8], nep[12], neo[12];
            for (int i = 0; i < 8; ++i) {
                ncp[i] = c.cp[mc[i]];
                nco[i] = (int8_t)((c.co[mc[i]] + mco[i]) % 3);
            }
            for (int i = 0; i < 12; ++i) {
                nep[i] = c.ep[me[i]];
                neo[i] = (int8_t)((c.eo[me[i]] + meo[i]) % 2);
            }
            for (int i = 0; i < 8; ++i) { c.cp[i] = ncp[i]; c.co[i] = nco[i]; }
            for (int i = 0; i < 12; ++i) { c.ep[i] = nep[i]; c.eo[i] = neo[i]; }
        }
    }

    // Applies a list of move indices.
    void apply_all(Cubie& c, const int* moves, int n) const {
        for (int i = 0; i < n; ++i) apply(c, moves[i]);
    }

    // Applies a space separated move string to a facelet state in place.
    // Returns 0 on success, -1 on an unknown token.
    int apply_moves_facelets(char* state, const char* moves) const {
        const char* p = moves;
        while (*p) {
            while (*p == ' ') ++p;
            if (!*p) break;
            int mi = -1;
            for (int i = 0; i < N_MOVES; ++i) {
                const char* mn = MOVE_NAMES[i];
                int k = 0;
                while (mn[k] && p[k] == mn[k]) ++k;
                if (!mn[k] && (p[k] == ' ' || p[k] == '\0')) { mi = i; break; }
            }
            if (mi < 0) return -1;
            while (*p && *p != ' ') ++p;
            char tmp[54];
            for (int rep = 0; rep < MOVE_POWER[mi]; ++rep) {
                for (int i = 0; i < 54; ++i) tmp[i] = state[facelet_perm_[MOVE_FACE[mi]][i]];
                for (int i = 0; i < 54; ++i) state[i] = tmp[i];
            }
        }
        return 0;
    }

    bool is_solved(const Cubie& c) const {
        for (int i = 0; i < 8; ++i) if (c.cp[i] != i || c.co[i] != 0) return false;
        for (int i = 0; i < 12; ++i) if (c.ep[i] != i || c.eo[i] != 0) return false;
        return true;
    }

    // Solves a cubie state.  Writes move indices into `out` (capacity
    // max_moves) and returns the number of moves, or -1 when no solution was
    // found within the internal limits.
    int solve(const Cubie& start, int* out, int max_moves) {
        if (!ready_) build();
        if (is_solved(start)) return 0;

        int tw = get_twist(start.co);
        int fl = get_flip(start.eo);
        int sl = get_slice(start.ep);

        path_len_ = 0;
        int p1 = -1;
        for (int d = 0; d <= 12; ++d) {
            if (dfs1(tw, fl, sl, d, -1)) { p1 = path_len_; break; }
        }
        if (p1 < 0) return -1;

        Cubie mid = start;
        for (int i = 0; i < p1; ++i) apply(mid, path_[i]);

        int c = get_perm(mid.cp, 8);
        int e = get_perm(mid.ep, 8);
        int8_t rel[4];
        for (int i = 0; i < 4; ++i) rel[i] = (int8_t)(mid.ep[8 + i] - 8);
        int sp = get_perm(rel, 4);

        path2_len_ = 0;
        int p2 = -1;
        for (int d = 0; d <= 18; ++d) {
            if (dfs2(c, e, sp, d, -1)) { p2 = path2_len_; break; }
        }
        if (p2 < 0) return -1;

        if (p1 + p2 > max_moves) return -1;
        for (int i = 0; i < p1; ++i) out[i] = path_[i];
        for (int i = 0; i < p2; ++i) out[p1 + i] = path2_[i];
        return p1 + p2;
    }

    // Builds every table.  Safe to call repeatedly.
    void build() {
        if (ready_) return;
        build_geometry();
        build_cubie_moves();
        build_move_tables();
        build_pruning();
        ready_ = true;
    }

    // ---- diagnostics / partial solves (also used by the test harness) ----

    // Runs phase 1 alone.  Returns the move count, or -1 when the search
    // failed.  `out` receives the move indices (clamped to max_moves).
    int solve_phase1(const Cubie& start, int* out, int max_moves) {
        if (!ready_) build();
        int tw = get_twist(start.co);
        int fl = get_flip(start.eo);
        int sl = get_slice(start.ep);
        path_len_ = 0;
        for (int d = 0; d <= 12; ++d) {
            if (dfs1(tw, fl, sl, d, -1)) {
                int n = path_len_ < max_moves ? path_len_ : max_moves;
                for (int i = 0; i < n; ++i) out[i] = path_[i];
                return path_len_;
            }
        }
        return -1;
    }

    // Writes the six working coordinates of a state.
    void coords(const Cubie& c, int* out6) const {
        out6[0] = get_twist(c.co);
        out6[1] = get_flip(c.eo);
        out6[2] = get_slice(c.ep);
        out6[3] = get_perm(c.cp, 8);
        out6[4] = get_perm(c.ep, 8);
        int8_t rel[4];
        for (int i = 0; i < 4; ++i) rel[i] = (int8_t)(c.ep[8 + i] - 8);
        out6[5] = get_perm(rel, 4);
    }

    // Pruning distance for the phase 1 coordinates (255 = unreachable).
    int prune_phase1(int tw, int fl, int sl) const {
        int h = pt_ts_[tw * N_SLICE + sl];
        int h2 = pt_fs_[fl * N_SLICE + sl];
        return h2 > h ? h2 : h;
    }

    int prune_phase2(int c, int e, int s) const {
        int h = pt_cs_[c * N_SPERM + s];
        int h2 = pt_es_[e * N_SPERM + s];
        return h2 > h ? h2 : h;
    }

    // The cubie permutation / orientation deltas of one clockwise turn of
    // `face`.  new position i holds the cubie that was at position cp[i].
    void face_turn(int face, int8_t* cp, int8_t* co, int8_t* ep, int8_t* eo) const {
        for (int i = 0; i < 8; ++i) { cp[i] = cm_cp_[face][i]; co[i] = cm_co_[face][i]; }
        for (int i = 0; i < 12; ++i) { ep[i] = cm_ep_[face][i]; eo[i] = cm_eo_[face][i]; }
    }

private:
    bool ready_ = false;
    int8_t facelet_perm_[6][54];
    int8_t cm_cp_[6][8];
    int8_t cm_co_[6][8];
    int8_t cm_ep_[6][12];
    int8_t cm_eo_[6][12];

    uint16_t twist_move_[N_TWIST][N_MOVES];
    uint16_t flip_move_[N_FLIP][N_MOVES];
    uint16_t slice_move_[N_SLICE][N_MOVES];
    uint16_t cp_move_[N_CPERM][N_MOVES];
    uint16_t ep_move_[N_EPERM][N_MOVES];
    uint16_t sp_move_[N_SPERM][N_MOVES];

    uint8_t pt_ts_[N_TWIST * N_SLICE];
    uint8_t pt_fs_[N_FLIP * N_SLICE];
    uint8_t pt_cs_[N_CPERM * N_SPERM];
    uint8_t pt_es_[N_EPERM * N_SPERM];

    // +1: every state can be enqueued exactly once, so the tail may legally
    // reach N_TWIST * N_SLICE.
    uint32_t queue_[N_TWIST * N_SLICE + 1];

    int path_[24];
    int path2_[24];
    int path_len_ = 0;
    int path2_len_ = 0;

    // ------------------------------------------------------- small utilities
    static int perm_parity(const int8_t* a, int n) {
        int inv = 0;
        for (int i = 0; i < n - 1; ++i)
            for (int j = i + 1; j < n; ++j)
                if (a[i] > a[j]) ++inv;
        return inv & 1;
    }

    // C(n,k) for n,k <= 12
    static int cnk(int n, int k) {
        if (k < 0 || k > n) return 0;
        static const int C[13][13] = {
            {1,0,0,0,0,0,0,0,0,0,0,0,0},
            {1,1,0,0,0,0,0,0,0,0,0,0,0},
            {1,2,1,0,0,0,0,0,0,0,0,0,0},
            {1,3,3,1,0,0,0,0,0,0,0,0,0},
            {1,4,6,4,1,0,0,0,0,0,0,0,0},
            {1,5,10,10,5,1,0,0,0,0,0,0,0},
            {1,6,15,20,15,6,1,0,0,0,0,0,0},
            {1,7,21,35,35,21,7,1,0,0,0,0,0},
            {1,8,28,56,70,56,28,8,1,0,0,0,0},
            {1,9,36,84,126,126,84,36,9,1,0,0,0},
            {1,10,45,120,210,252,210,120,45,10,1,0,0},
            {1,11,55,165,330,462,462,330,165,55,11,1,0},
            {1,12,66,220,495,792,924,792,495,220,66,12,1}
        };
        return C[n][k];
    }

    static int fact(int n) {
        static const int F[13] = {1,1,2,6,24,120,720,5040,40320,362880,
                                  3628800,39916800,479001600};
        return F[n];
    }

    // ------------------------------------------------------------- geometry
    struct Vec3 { int8_t x, y, z; };

    static Vec3 rot(Vec3 v, int face) {
        // v[a], v[b] = -v[b], v[a]  -- clockwise seen from outside the face
        static const int IA[6] = {0, 2, 1, 2, 1, 0};
        static const int IB[6] = {2, 1, 0, 0, 2, 1};
        int a = IA[face], b = IB[face];
        int arr[3] = {v.x, v.y, v.z};
        int na = -arr[b], nb = arr[a];
        arr[a] = na;
        arr[b] = nb;
        return Vec3{(int8_t)arr[0], (int8_t)arr[1], (int8_t)arr[2]};
    }

    static void facelet_geo(Vec3* pos, Vec3* nrm) {
        for (int f = 0; f < 6; ++f)
            for (int r = 0; r < 3; ++r)
                for (int c = 0; c < 3; ++c) {
                    int i = f * 9 + r * 3 + c;
                    switch (f) {
                        case 0: pos[i] = Vec3{(int8_t)(c - 1), 1, (int8_t)(r - 1)};
                                nrm[i] = Vec3{0, 1, 0}; break;
                        case 1: pos[i] = Vec3{1, (int8_t)(1 - r), (int8_t)(1 - c)};
                                nrm[i] = Vec3{1, 0, 0}; break;
                        case 2: pos[i] = Vec3{(int8_t)(c - 1), (int8_t)(1 - r), 1};
                                nrm[i] = Vec3{0, 0, 1}; break;
                        case 3: pos[i] = Vec3{(int8_t)(c - 1), -1, (int8_t)(1 - r)};
                                nrm[i] = Vec3{0, -1, 0}; break;
                        case 4: pos[i] = Vec3{-1, (int8_t)(1 - r), (int8_t)(c - 1)};
                                nrm[i] = Vec3{-1, 0, 0}; break;
                        default: pos[i] = Vec3{(int8_t)(1 - c), (int8_t)(1 - r), -1};
                                nrm[i] = Vec3{0, 0, -1}; break;
                    }
                }
    }

    void build_geometry() {
        Vec3 pos[54], nrm[54];
        facelet_geo(pos, nrm);
        static const int LAYER_AXIS[6] = {1, 0, 2, 1, 0, 2};
        static const int LAYER_VAL[6] = {1, 1, 1, -1, -1, -1};
        for (int f = 0; f < 6; ++f) {
            for (int i = 0; i < 54; ++i) facelet_perm_[f][i] = (int8_t)i;
            for (int i = 0; i < 54; ++i) {
                int arr[3] = {pos[i].x, pos[i].y, pos[i].z};
                if (arr[LAYER_AXIS[f]] != LAYER_VAL[f]) continue;
                Vec3 np = rot(pos[i], f);
                Vec3 nn = rot(nrm[i], f);
                for (int j = 0; j < 54; ++j) {
                    if (np.x == pos[j].x && np.y == pos[j].y && np.z == pos[j].z &&
                        nn.x == nrm[j].x && nn.y == nrm[j].y && nn.z == nrm[j].z) {
                        facelet_perm_[f][j] = (int8_t)i;
                        break;
                    }
                }
            }
        }
    }

    void build_cubie_moves() {
        static const char SOLVED_STR[] =
            "UUUUUUUUURRRRRRRRRFFFFFFFFFDDDDDDDDDLLLLLLLLLBBBBBBBBB";
        for (int f = 0; f < 6; ++f) {
            char st[54];
            for (int i = 0; i < 54; ++i) st[i] = SOLVED_STR[i];
            char tmp[54];
            for (int i = 0; i < 54; ++i) tmp[i] = st[facelet_perm_[f][i]];
            for (int i = 0; i < 54; ++i) st[i] = tmp[i];
            Cubie c;
            decode(st, c);
            for (int i = 0; i < 8; ++i) { cm_cp_[f][i] = c.cp[i]; cm_co_[f][i] = c.co[i]; }
            for (int i = 0; i < 12; ++i) { cm_ep_[f][i] = c.ep[i]; cm_eo_[f][i] = c.eo[i]; }
        }
    }

    // --------------------------------------------------------- coordinates
    static int get_twist(const int8_t* co) {
        int t = 0;
        for (int i = 0; i < 7; ++i) t = t * 3 + co[i];
        return t;
    }

    static void set_twist(int t, int8_t* co) {
        int s = 0;
        for (int i = 6; i >= 0; --i) { co[i] = (int8_t)(t % 3); s += co[i]; t /= 3; }
        co[7] = (int8_t)((3 - s % 3) % 3);
    }

    static int get_flip(const int8_t* eo) {
        int t = 0;
        for (int i = 0; i < 11; ++i) t = t * 2 + eo[i];
        return t;
    }

    static void set_flip(int t, int8_t* eo) {
        int s = 0;
        for (int i = 10; i >= 0; --i) { eo[i] = (int8_t)(t & 1); s ^= eo[i]; t >>= 1; }
        eo[11] = (int8_t)s;
    }

    static int get_slice(const int8_t* ep) {
        int a = 0, x = 0;
        for (int j = 0; j < 12; ++j) {
            if (ep[j] >= 8) { a += cnk(j, x + 1); ++x; }
        }
        return a;
    }

    static void set_slice(int idx, int8_t* ep) {
        for (int j = 0; j < 12; ++j) ep[j] = -1;
        int x = 3;
        for (int j = 11; j >= 0; --j) {
            if (idx >= cnk(j, x + 1)) {
                ep[j] = (int8_t)(8 + x);
                idx -= cnk(j, x + 1);
                --x;
            }
        }
        x = 0;
        for (int j = 0; j < 12; ++j) if (ep[j] == -1) ep[j] = (int8_t)x++;
    }

    static int get_perm(const int8_t* arr, int n) {
        int idx = 0;
        for (int i = 0; i < n; ++i) {
            int cnt = 0;
            for (int j = i + 1; j < n; ++j) if (arr[j] < arr[i]) ++cnt;
            idx += cnt * fact(n - 1 - i);
        }
        return idx;
    }

    static void set_perm(int idx, int8_t* arr, int n) {
        bool used[8];
        for (int i = 0; i < n; ++i) used[i] = false;
        for (int i = 0; i < n; ++i) {
            int f = fact(n - 1 - i);
            int c = idx / f;
            idx -= c * f;
            int cnt = -1, k = -1;
            for (int v = 0; v < n; ++v) {
                if (used[v]) continue;
                if (++cnt == c) { k = v; break; }
            }
            arr[i] = (int8_t)k;
            used[k] = true;
        }
    }

    // --------------------------------------------------------- move tables
    void build_move_tables() {
        Cubie c;
        int8_t vals[12];
        for (int t = 0; t < N_TWIST; ++t) {
            set_twist(t, c.co);
            for (int i = 0; i < 8; ++i) c.cp[i] = (int8_t)i;
            for (int i = 0; i < 12; ++i) { c.ep[i] = (int8_t)i; c.eo[i] = 0; }
            for (int mi = 0; mi < N_MOVES; ++mi) {
                Cubie d = c;
                apply(d, mi);
                twist_move_[t][mi] = (uint16_t)get_twist(d.co);
            }
        }
        for (int fl = 0; fl < N_FLIP; ++fl) {
            set_flip(fl, c.eo);
            for (int i = 0; i < 8; ++i) { c.cp[i] = (int8_t)i; c.co[i] = 0; }
            for (int i = 0; i < 12; ++i) c.ep[i] = (int8_t)i;
            for (int mi = 0; mi < N_MOVES; ++mi) {
                Cubie d = c;
                apply(d, mi);
                flip_move_[fl][mi] = (uint16_t)get_flip(d.eo);
            }
        }
        for (int s = 0; s < N_SLICE; ++s) {
            set_slice(s, c.ep);
            for (int i = 0; i < 8; ++i) { c.cp[i] = (int8_t)i; c.co[i] = 0; }
            for (int i = 0; i < 12; ++i) c.eo[i] = 0;
            for (int mi = 0; mi < N_MOVES; ++mi) {
                Cubie d = c;
                apply(d, mi);
                slice_move_[s][mi] = (uint16_t)get_slice(d.ep);
            }
        }
        for (int v = 0; v < N_CPERM; ++v) {
            for (int i = 0; i < N_MOVES; ++i) cp_move_[v][i] = 0;
            set_perm(v, c.cp, 8);
            for (int i = 0; i < 8; ++i) c.co[i] = 0;
            for (int i = 0; i < 12; ++i) { c.ep[i] = (int8_t)i; c.eo[i] = 0; }
            for (int k = 0; k < N_PHASE2; ++k) {
                int mi = PHASE2_MOVES[k];
                Cubie d = c;
                apply(d, mi);
                cp_move_[v][mi] = (uint16_t)get_perm(d.cp, 8);
            }
        }
        for (int v = 0; v < N_EPERM; ++v) {
            for (int i = 0; i < N_MOVES; ++i) ep_move_[v][i] = 0;
            set_perm(v, c.ep, 8);
            for (int i = 8; i < 12; ++i) c.ep[i] = (int8_t)i;
            for (int i = 0; i < 8; ++i) { c.cp[i] = (int8_t)i; c.co[i] = 0; }
            for (int i = 0; i < 12; ++i) c.eo[i] = 0;
            for (int k = 0; k < N_PHASE2; ++k) {
                int mi = PHASE2_MOVES[k];
                Cubie d = c;
                apply(d, mi);
                ep_move_[v][mi] = (uint16_t)get_perm(d.ep, 8);
            }
        }
        for (int v = 0; v < N_SPERM; ++v) {
            for (int i = 0; i < N_MOVES; ++i) sp_move_[v][i] = 0;
            set_perm(v, vals, 4);
            for (int i = 0; i < 4; ++i) c.ep[8 + i] = (int8_t)(8 + vals[i]);
            for (int i = 0; i < 8; ++i) c.ep[i] = (int8_t)i;
            for (int i = 0; i < 8; ++i) { c.cp[i] = (int8_t)i; c.co[i] = 0; }
            for (int i = 0; i < 12; ++i) c.eo[i] = 0;
            for (int k = 0; k < N_PHASE2; ++k) {
                int mi = PHASE2_MOVES[k];
                Cubie d = c;
                apply(d, mi);
                int8_t rel[4];
                for (int i = 0; i < 4; ++i) rel[i] = (int8_t)(d.ep[8 + i] - 8);
                sp_move_[v][mi] = (uint16_t)get_perm(rel, 4);
            }
        }
    }

    // ------------------------------------------------------ pruning tables
    void build_pruning() {
        for (int i = 0; i < N_TWIST * N_SLICE; ++i) pt_ts_[i] = 0xFF;
        pt_ts_[0] = 0;
        int head = 0, tail = 0;
        queue_[tail++] = 0;
        while (head < tail) {
            uint32_t idx = queue_[head++];
            int a = (int)(idx / N_SLICE), b = (int)(idx % N_SLICE);
            uint8_t d = (uint8_t)(pt_ts_[idx] + 1);
            for (int mi = 0; mi < N_MOVES; ++mi) {
                int ni = twist_move_[a][mi] * N_SLICE + slice_move_[b][mi];
                if (pt_ts_[ni] == 0xFF) { pt_ts_[ni] = d; queue_[tail++] = (uint32_t)ni; }
            }
        }
        for (int i = 0; i < N_FLIP * N_SLICE; ++i) pt_fs_[i] = 0xFF;
        pt_fs_[0] = 0;
        head = tail = 0;
        queue_[tail++] = 0;
        while (head < tail) {
            uint32_t idx = queue_[head++];
            int a = (int)(idx / N_SLICE), b = (int)(idx % N_SLICE);
            uint8_t d = (uint8_t)(pt_fs_[idx] + 1);
            for (int mi = 0; mi < N_MOVES; ++mi) {
                int ni = flip_move_[a][mi] * N_SLICE + slice_move_[b][mi];
                if (pt_fs_[ni] == 0xFF) { pt_fs_[ni] = d; queue_[tail++] = (uint32_t)ni; }
            }
        }
        for (int i = 0; i < N_CPERM * N_SPERM; ++i) pt_cs_[i] = 0xFF;
        pt_cs_[0] = 0;
        head = tail = 0;
        queue_[tail++] = 0;
        while (head < tail) {
            uint32_t idx = queue_[head++];
            int a = (int)(idx / N_SPERM), b = (int)(idx % N_SPERM);
            uint8_t d = (uint8_t)(pt_cs_[idx] + 1);
            for (int k = 0; k < N_PHASE2; ++k) {
                int mi = PHASE2_MOVES[k];
                int ni = cp_move_[a][mi] * N_SPERM + sp_move_[b][mi];
                if (pt_cs_[ni] == 0xFF) { pt_cs_[ni] = d; queue_[tail++] = (uint32_t)ni; }
            }
        }
        for (int i = 0; i < N_EPERM * N_SPERM; ++i) pt_es_[i] = 0xFF;
        pt_es_[0] = 0;
        head = tail = 0;
        queue_[tail++] = 0;
        while (head < tail) {
            uint32_t idx = queue_[head++];
            int a = (int)(idx / N_SPERM), b = (int)(idx % N_SPERM);
            uint8_t d = (uint8_t)(pt_es_[idx] + 1);
            for (int k = 0; k < N_PHASE2; ++k) {
                int mi = PHASE2_MOVES[k];
                int ni = ep_move_[a][mi] * N_SPERM + sp_move_[b][mi];
                if (pt_es_[ni] == 0xFF) { pt_es_[ni] = d; queue_[tail++] = (uint32_t)ni; }
            }
        }
    }

    // -------------------------------------------------------------- search
    bool dfs1(int tw, int fl, int sl, int depth, int last_face) {
        int h = pt_ts_[tw * N_SLICE + sl];
        int h2 = pt_fs_[fl * N_SLICE + sl];
        if (h2 > h) h = h2;
        if (h > depth) return false;
        if (tw == 0 && fl == 0 && sl == 0) return true;
        if (depth == 0) return false;
        for (int mi = 0; mi < N_MOVES; ++mi) {
            int f = MOVE_FACE[mi];
            if (f == last_face) continue;
            path_[path_len_++] = mi;
            if (dfs1(twist_move_[tw][mi], flip_move_[fl][mi], slice_move_[sl][mi],
                     depth - 1, f))
                return true;
            --path_len_;
        }
        return false;
    }

    bool dfs2(int c, int e, int s, int depth, int last_face) {
        int h = pt_cs_[c * N_SPERM + s];
        int h2 = pt_es_[e * N_SPERM + s];
        if (h2 > h) h = h2;
        if (h > depth) return false;
        if (c == 0 && e == 0 && s == 0) return true;
        if (depth == 0) return false;
        for (int k = 0; k < N_PHASE2; ++k) {
            int mi = PHASE2_MOVES[k];
            int f = MOVE_FACE[mi];
            if (f == last_face) continue;
            path2_[path2_len_++] = mi;
            if (dfs2(cp_move_[c][mi], ep_move_[e][mi], sp_move_[s][mi],
                     depth - 1, f))
                return true;
            --path2_len_;
        }
        return false;
    }
};

}  // namespace rubik

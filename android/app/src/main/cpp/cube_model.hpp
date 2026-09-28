#pragma once
#include <string>
#include <vector>
#include <array>
#include <algorithm>
#include <cstdint>

enum Color { U = 0, R = 1, F = 2, D = 3, L = 4, B = 5 };
enum Corner { URF = 0, UFL = 1, ULB = 2, UBR = 3, DFR = 4, DLF = 5, DBL = 6, DRB = 7 };
enum Edge { UR = 0, UF = 1, UL = 2, UB = 3, DR = 4, DF = 5, DL = 6, DB = 7, FR = 8, FL = 9, BL = 10, BR = 11 };

/// Corner/edge level views of a cube. Kept for the pipeline facing API.
struct CornerCubie { int8_t cp[8]; int8_t co[8]; };
struct EdgeCubie { int8_t ep[12]; int8_t eo[12]; };

/// Full cubie level state.
///
/// `cp[i]` is the corner piece sitting at position `i`, `co[i]` its twist
/// (0..2). `ep[i]` / `eo[i]` are the edge equivalents. Move application lives
/// in `move_engine.hpp`; this header only owns the facelet <-> cubie mapping.
struct CubieState {
    int8_t cp[8];
    int8_t co[8];
    int8_t ep[12];
    int8_t eo[12];
};

class CubeModel {
public:
    static constexpr int cornerFacelet[8][3] = {
        { 8,  9, 20 }, { 6, 18, 38 }, { 0, 36, 47 }, { 2, 45, 11 },
        { 29, 26, 15 }, { 27, 44, 24 }, { 33, 53, 42 }, { 35, 17, 51 }
    };

    static constexpr int edgeFacelet[12][2] = {
        { 5, 10 }, { 7, 19 }, { 3, 37 }, { 1, 46 },
        { 32, 16 }, { 28, 25 }, { 30, 43 }, { 34, 52 },
        { 23, 12 }, { 21, 41 }, { 48, 39 }, { 50, 14 }
    };

    /// Face colors of every corner piece, ordered exactly like
    /// `cornerFacelet`: index 0 is the U/D facing sticker.
    static constexpr int cornerColors[8][3] = {
        { U, R, F }, { U, F, L }, { U, L, B }, { U, B, R },
        { D, F, R }, { D, L, F }, { D, B, L }, { D, R, B }
    };

    /// Face colors of every edge piece, ordered like `edgeFacelet`:
    /// index 0 is the U/D sticker for U/D edges, the F/B sticker otherwise.
    static constexpr int edgeColors[12][2] = {
        { U, R }, { U, F }, { U, L }, { U, B },
        { D, R }, { D, F }, { D, L }, { D, B },
        { F, R }, { F, L }, { B, L }, { B, R }
    };

    /// Solved facelet string in the canonical `U R F D L B` order.
    static const std::string& solvedFacelets() {
        static const std::string s = "UUUUUUUUURRRRRRRRRFFFFFFFFFDDDDDDDDDLLLLLLLLLBBBBBBBBB";
        return s;
    }

    static CubieState solvedState() {
        CubieState s{};
        for (int i = 0; i < 8; ++i) { s.cp[i] = (int8_t)i; s.co[i] = 0; }
        for (int i = 0; i < 12; ++i) { s.ep[i] = (int8_t)i; s.eo[i] = 0; }
        return s;
    }

    static bool isSolved(const CubieState& s) {
        for (int i = 0; i < 8; ++i) {
            if (s.cp[i] != i || s.co[i] != 0) return false;
        }
        for (int i = 0; i < 12; ++i) {
            if (s.ep[i] != i || s.eo[i] != 0) return false;
        }
        return true;
    }

    /// Decodes a 54 character facelet string into cubie form.
    ///
    /// Returns false (with `err` filled in) when a corner/edge combination
    /// does not correspond to a real piece or when a piece shows up twice.
    static bool faceletsToCubie(const std::string& f, CubieState& out, std::string& err) {
        if (f.size() != 54) {
            err = "Invalid length: facelet string must be exactly 54 characters.";
            return false;
        }

        int counts[6] = {0};
        for (char c : f) {
            int idx = charToColorIndex(c);
            if (idx < 0) {
                err = std::string("Unknown color facelet detected: ") + c;
                return false;
            }
            counts[idx]++;
        }
        for (int i = 0; i < 6; ++i) {
            if (counts[i] != 9) {
                err = "Each of the 6 colors must appear exactly 9 times.";
                return false;
            }
        }

        bool cornerSeen[8] = {false};
        bool edgeSeen[12] = {false};

        for (int i = 0; i < 8; ++i) {
            const int fac[3] = {
                charToColorIndex(f[cornerFacelet[i][0]]),
                charToColorIndex(f[cornerFacelet[i][1]]),
                charToColorIndex(f[cornerFacelet[i][2]])
            };
            // `co` is the index of the facelet carrying the U/D sticker, which
            // is also the index of the piece's first color in `cornerColors`.
            int ori = 0;
            if (fac[1] == U || fac[1] == D) ori = 1;
            else if (fac[2] == U || fac[2] == D) ori = 2;
            out.co[i] = (int8_t)ori;

            int piece = matchCorner(fac[0], fac[1], fac[2]);
            if (piece < 0) {
                err = "Invalid corner piece arrangement detected.";
                return false;
            }
            if (cornerSeen[piece]) {
                err = "Duplicate corner piece detected: a corner appears twice.";
                return false;
            }
            cornerSeen[piece] = true;
            out.cp[i] = (int8_t)piece;
        }

        for (int i = 0; i < 12; ++i) {
            const int c1 = charToColorIndex(f[edgeFacelet[i][0]]);
            const int c2 = charToColorIndex(f[edgeFacelet[i][1]]);
            int ori = 0;
            if (c1 == U || c1 == D) ori = 0;
            else if (c2 == U || c2 == D) ori = 1;
            else if (c1 == F || c1 == B) ori = 0;
            else ori = 1;
            out.eo[i] = (int8_t)ori;

            int piece = matchEdge(c1, c2);
            if (piece < 0) {
                err = "Invalid edge piece arrangement detected.";
                return false;
            }
            if (edgeSeen[piece]) {
                err = "Duplicate edge piece detected: an edge appears twice.";
                return false;
            }
            edgeSeen[piece] = true;
            out.ep[i] = (int8_t)piece;
        }

        return true;
    }

    /// Inverse of `faceletsToCubie`, in the canonical `U R F D L B` order.
    static std::string cubieToFacelets(const CubieState& s) {
        // The six centers always show their own face color, so every block
        // starts out solved and only the corners/edges are overwritten.
        std::string f(54, 'U');
        for (int face = 0; face < 6; ++face) {
            for (int i = 0; i < 9; ++i) f[face * 9 + i] = colorChar(face);
        }

        for (int c = 0; c < 8; ++c) {
            const int piece = s.cp[c];
            const int ori = s.co[c] % 3;
            for (int j = 0; j < 3; ++j) {
                // Color j of the piece sits on the facelet `ori` steps further
                // round the corner, because `co` indexes the facelet holding
                // color 0.
                const int slot = (ori + j) % 3;
                f[cornerFacelet[c][slot]] = colorChar(cornerColors[piece][j]);
            }
        }

        for (int e = 0; e < 12; ++e) {
            const int piece = s.ep[e];
            const int ori = s.eo[e] % 2;
            f[edgeFacelet[e][0]] = colorChar(edgeColors[piece][ori]);
            f[edgeFacelet[e][1]] = colorChar(edgeColors[piece][1 - ori]);
        }

        return f;
    }

    static bool validate(const std::string& facelets, std::string& error_msg) {
        CubieState cc;
        if (!faceletsToCubie(facelets, cc, error_msg)) {
            return false;
        }

        int twist_sum = 0;
        for (int i = 0; i < 8; ++i) twist_sum += cc.co[i];
        if (twist_sum % 3 != 0) {
            error_msg = "Corner twist parity error: sum(twist) % 3 != 0 (A corner is twisted).";
            return false;
        }

        int flip_sum = 0;
        for (int i = 0; i < 12; ++i) flip_sum += cc.eo[i];
        if (flip_sum % 2 != 0) {
            error_msg = "Edge flip parity error: sum(flip) % 2 != 0 (An edge is flipped).";
            return false;
        }

        int corner_parity = getPermutationParity(cc.cp, 8);
        int edge_parity = getPermutationParity(cc.ep, 12);
        if (corner_parity != edge_parity) {
            error_msg = "Permutation parity mismatch: corner parity must equal edge parity.";
            return false;
        }

        return true;
    }

    static int charToColorIndex(char c) {
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

    static char colorChar(int color) {
        switch (color) {
            case U: return 'U';
            case R: return 'R';
            case F: return 'F';
            case D: return 'D';
            case L: return 'L';
            case B: return 'B';
            default: return '?';
        }
    }

private:
    template <typename T>
    static int getPermutationParity(const T* arr, int n) {
        int inversions = 0;
        for (int i = 0; i < n - 1; ++i) {
            for (int j = i + 1; j < n; ++j) {
                if (arr[i] > arr[j]) inversions++;
            }
        }
        return inversions % 2;
    }

    /// Returns the corner piece built from its three colors, or -1 when the
    /// color triple does not correspond to any real corner.
    ///
    /// Matching is order independent: the three stickers of an illegal corner
    /// are still only ever a subset comparison, but real cubes can only ever
    /// show the colors of an existing piece, so the set is enough to identify
    /// it. Returning `int` (instead of `Corner`) is what makes the -1 test
    /// meaningful - the old `(Corner)-1 == -1` comparison was always false.
    static int matchCorner(int c1, int c2, int c3) {
        int sorted[3] = {c1, c2, c3};
        std::sort(sorted, sorted + 3);
        for (int p = 0; p < 8; ++p) {
            int cols[3] = {cornerColors[p][0], cornerColors[p][1], cornerColors[p][2]};
            std::sort(cols, cols + 3);
            if (sorted[0] == cols[0] && sorted[1] == cols[1] && sorted[2] == cols[2]) return p;
        }
        return -1;
    }

    static int matchEdge(int c1, int c2) {
        for (int p = 0; p < 12; ++p) {
            const int* cols = edgeColors[p];
            if ((c1 == cols[0] && c2 == cols[1]) ||
                (c1 == cols[1] && c2 == cols[0])) return p;
        }
        return -1;
    }
};

#pragma once
#include <string>
#include <vector>
#include <array>
#include <algorithm>
#include <numeric>
#include <cstdint>

enum Color { U = 0, R = 1, F = 2, D = 3, L = 4, B = 5 };
enum Corner { URF = 0, UFL = 1, ULB = 2, UBR = 3, DFR = 4, DLF = 5, DBL = 6, DRB = 7 };
enum Edge { UR = 0, UF = 1, UL = 2, UB = 3, DR = 4, DF = 5, DL = 6, DB = 7, FR = 8, FL = 9, BL = 10, BR = 11 };

struct CornerCubie {
    int8_t cp[8];
    int8_t co[8];
};

struct EdgeCubie {
    int8_t ep[12];
    int8_t eo[12];
};

class CubeModel {
public:
    static constexpr int cornerFacelet[8][3] = {
        { 8,  9, 20 }, { 6, 18, 38 }, { 0, 36, 47 }, { 2, 45, 11 },
        { 29, 26, 15 }, { 27, 44, 24 }, { 33, 53, 42 }, { 35, 17, 51 }
    };

    // BL is {50,39} and BR is {48,14}: facelet 50 sits on the B face at
    // x=+1 (BR's corner) and 48 at x=-1 (BL's corner).  These two entries
    // used to be swapped, which made every scrambled cube look invalid.
    static constexpr int edgeFacelet[12][2] = {
        { 5, 10 }, { 7, 19 }, { 3, 37 }, { 1, 46 },
        { 32, 16 }, { 28, 25 }, { 30, 43 }, { 34, 52 },
        { 23, 12 }, { 21, 41 }, { 50, 39 }, { 48, 14 }
    };

    static bool validate(const std::string& facelets, std::string& error_msg) {
        if (facelets.length() != 54) {
            error_msg = "Invalid length: facelet string must be exactly 54 characters.";
            return false;
        }

        int counts[6] = {0};
        for (char c : facelets) {
            int idx = charToColorIndex(c);
            if (idx < 0) {
                error_msg = std::string("Unknown color facelet detected: ") + c;
                return false;
            }
            counts[idx]++;
        }
        for (int i = 0; i < 6; ++i) {
            if (counts[i] != 9) {
                error_msg = "Each of the 6 colors must appear exactly 9 times.";
                return false;
            }
        }

        CornerCubie cc;
        EdgeCubie ec;
        if (!toCubie(facelets, cc, ec, error_msg)) {
            return false;
        }

        int twist_sum = 0;
        for (int i = 0; i < 8; ++i) twist_sum += cc.co[i];
        if (twist_sum % 3 != 0) {
            error_msg = "Corner twist parity error: sum(twist) % 3 != 0 (A corner is twisted).";
            return false;
        }

        int flip_sum = 0;
        for (int i = 0; i < 12; ++i) flip_sum += ec.eo[i];
        if (flip_sum % 2 != 0) {
            error_msg = "Edge flip parity error: sum(flip) % 2 != 0 (An edge is flipped).";
            return false;
        }

        int corner_parity = getPermutationParity(cc.cp, 8);
        int edge_parity = getPermutationParity(ec.ep, 12);
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

    static bool toCubie(const std::string& f, CornerCubie& cc, EdgeCubie& ec, std::string& err) {
        for (int i = 0; i < 8; ++i) {
            int fac[3] = { charToColorIndex(f[cornerFacelet[i][0]]),
                           charToColorIndex(f[cornerFacelet[i][1]]),
                           charToColorIndex(f[cornerFacelet[i][2]]) };
            int ori = 0;
            if (fac[1] == U || fac[1] == D) ori = 1;
            else if (fac[2] == U || fac[2] == D) ori = 2;
            cc.co[i] = ori;
            int col1 = fac[(3 - ori) % 3], col2 = fac[(4 - ori) % 3], col3 = fac[(5 - ori) % 3];
            cc.cp[i] = matchCorner(col1, col2, col3);
            if (cc.cp[i] == -1) {
                err = "Invalid corner piece arrangement detected.";
                return false;
            }
        }

        for (int i = 0; i < 12; ++i) {
            int c1 = charToColorIndex(f[edgeFacelet[i][0]]);
            int c2 = charToColorIndex(f[edgeFacelet[i][1]]);
            int ori = 0;
            if (c1 == U || c1 == D) ori = 0;
            else if (c2 == U || c2 == D) ori = 1;
            else if (c1 == F || c1 == B) ori = 0;
            else ori = 1;
            ec.eo[i] = ori;
            ec.ep[i] = matchEdge(c1, c2);
            if (ec.ep[i] == -1) {
                err = "Invalid edge piece arrangement detected.";
                return false;
            }
        }
        return true;
    }

    static int matchCorner(int c1, int c2, int c3) {
        std::vector<int> cols = {c1, c2, c3};
        std::sort(cols.begin(), cols.end());
        if (cols == std::vector<int>{0, 1, 2}) return URF;
        if (cols == std::vector<int>{0, 2, 4}) return UFL;
        if (cols == std::vector<int>{0, 4, 5}) return ULB;
        if (cols == std::vector<int>{0, 1, 5}) return UBR;
        if (cols == std::vector<int>{1, 2, 3}) return DFR;
        if (cols == std::vector<int>{2, 3, 4}) return DLF;
        if (cols == std::vector<int>{3, 4, 5}) return DBL;
        if (cols == std::vector<int>{1, 3, 5}) return DRB;
        return -1;
    }

    static int matchEdge(int c1, int c2) {
        int u = std::min(c1, c2), v = std::max(c1, c2);
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
};

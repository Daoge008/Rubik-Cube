#pragma once
#include "cube_model.hpp"
#include <array>
#include <cstdint>
#include <sstream>
#include <string>
#include <vector>

namespace rubik {

/// One face turn expressed as "where every piece comes from".
///
/// `cp[i]` is the source position of the corner that lands on position `i`
/// after the turn, and `co[i]` the twist added to it. This is the standard
/// Kociemba table layout, so the tables can be lifted verbatim and the whole
/// engine stays comparable with published references.
struct MovePerm {
    int8_t cp[8];
    int8_t co[8];
    int8_t ep[12];
    int8_t eo[12];
};

/// Faces are ordered U, R, F, D, L, B - identical to `Color` and to the order
/// of the nine-facelet blocks in a facelet string.
inline constexpr int8_t BASE_CP[6][8] = {
    { 3, 0, 1, 2, 4, 5, 6, 7 },   // U
    { 4, 1, 2, 0, 7, 5, 6, 3 },   // R
    { 1, 5, 2, 3, 0, 4, 6, 7 },   // F
    { 0, 1, 2, 3, 5, 6, 7, 4 },   // D
    { 0, 2, 6, 3, 4, 1, 5, 7 },   // L
    { 0, 1, 3, 7, 4, 5, 2, 6 }    // B
};

inline constexpr int8_t BASE_CO[6][8] = {
    { 0, 0, 0, 0, 0, 0, 0, 0 },   // U
    { 2, 0, 0, 1, 1, 0, 0, 2 },   // R
    { 1, 2, 0, 0, 2, 1, 0, 0 },   // F
    { 0, 0, 0, 0, 0, 0, 0, 0 },   // D
    { 0, 1, 2, 0, 0, 2, 1, 0 },   // L
    { 0, 0, 1, 2, 0, 0, 2, 1 }    // B
};

inline constexpr int8_t BASE_EP[6][12] = {
    { 3, 0, 1, 2, 4, 5, 6, 7, 8, 9, 10, 11 },   // U
    { 8, 1, 2, 3, 11, 5, 6, 7, 4, 9, 10, 0 },   // R
    { 0, 9, 2, 3, 4, 8, 6, 7, 1, 5, 10, 11 },   // F
    { 0, 1, 2, 3, 5, 6, 7, 4, 8, 9, 10, 11 },   // D
    { 0, 1, 10, 3, 4, 5, 9, 7, 8, 2, 6, 11 },   // L
    { 0, 1, 2, 11, 4, 5, 6, 10, 8, 9, 3, 7 }    // B
};

inline constexpr int8_t BASE_EO[6][12] = {
    { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },     // U
    { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },     // R
    { 0, 1, 0, 0, 0, 1, 0, 0, 1, 1, 0, 0 },     // F
    { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },     // D
    { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 },     // L
    { 0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 1, 1 }      // B
};

/// Applies one base face turn to `in`, writing the result to `out`.
inline void applyBaseMove(const CubieState& in, int face, CubieState& out) {
    for (int i = 0; i < 8; ++i) {
        const int src = BASE_CP[face][i];
        out.cp[i] = in.cp[src];
        out.co[i] = (int8_t)((in.co[src] + BASE_CO[face][i]) % 3);
    }
    for (int i = 0; i < 12; ++i) {
        const int src = BASE_EP[face][i];
        out.ep[i] = in.ep[src];
        out.eo[i] = (int8_t)((in.eo[src] + BASE_EO[face][i]) % 2);
    }
}

/// The 18 quarter/half/three-quarter turns, indexed `face * 3 + (amount - 1)`.
///
/// Built once by turning a solved cube, which turns each base table into the
/// composed table for R2 / R' / ... without any hand written permutations.
inline const std::array<MovePerm, 18>& moveTables() {
    static const std::array<MovePerm, 18> tables = [] {
        std::array<MovePerm, 18> t{};
        for (int face = 0; face < 6; ++face) {
            CubieState s = CubeModel::solvedState();
            for (int amount = 1; amount <= 3; ++amount) {
                CubieState next{};
                applyBaseMove(s, face, next);
                s = next;
                MovePerm& m = t[face * 3 + (amount - 1)];
                for (int i = 0; i < 8; ++i) { m.cp[i] = s.cp[i]; m.co[i] = s.co[i]; }
                for (int i = 0; i < 12; ++i) { m.ep[i] = s.ep[i]; m.eo[i] = s.eo[i]; }
            }
        }
        return t;
    }();
    return tables;
}

/// Applies move `move` (0..17) to `s`.
inline CubieState applyMove(const CubieState& s, int move) {
    const MovePerm& m = moveTables()[move];
    CubieState out{};
    for (int i = 0; i < 8; ++i) {
        const int src = m.cp[i];
        out.cp[i] = s.cp[src];
        out.co[i] = (int8_t)((s.co[src] + m.co[i]) % 3);
    }
    for (int i = 0; i < 12; ++i) {
        const int src = m.ep[i];
        out.ep[i] = s.ep[src];
        out.eo[i] = (int8_t)((s.eo[src] + m.eo[i]) % 2);
    }
    return out;
}

inline void applyMoveInPlace(CubieState& s, int move) {
    s = applyMove(s, move);
}

/// Face letter plus optional `2` / `'`.
inline std::string moveToString(int move) {
    static const char faces[6] = { 'U', 'R', 'F', 'D', 'L', 'B' };
    const int face = move / 3;
    const int amount = move % 3 + 1;
    std::string s(1, faces[face]);
    if (amount == 2) s += '2';
    else if (amount == 3) s += '\'';
    return s;
}

inline int moveFromToken(const std::string& token) {
    if (token.empty()) return -1;
    int face = -1;
    switch (token[0]) {
        case 'U': face = 0; break;
        case 'R': face = 1; break;
        case 'F': face = 2; break;
        case 'D': face = 3; break;
        case 'L': face = 4; break;
        case 'B': face = 5; break;
        default: return -1;
    }
    int amount = 1;
    if (token.size() >= 2) {
        if (token[1] == '2') amount = 2;
        else if (token[1] == '\'') amount = 3;
        else if (token[1] == '3') amount = 3;
        else return -1;
    }
    return face * 3 + (amount - 1);
}

inline std::vector<int> parseSequence(const std::string& text) {
    std::vector<int> moves;
    std::istringstream iss(text);
    std::string token;
    while (iss >> token) {
        const int m = moveFromToken(token);
        if (m >= 0) moves.push_back(m);
    }
    return moves;
}

inline std::string sequenceToString(const std::vector<int>& moves) {
    std::string out;
    for (size_t i = 0; i < moves.size(); ++i) {
        if (i) out += ' ';
        out += moveToString(moves[i]);
    }
    return out;
}

inline CubieState applySequence(const CubieState& s, const std::vector<int>& moves) {
    CubieState cur = s;
    for (int m : moves) applyMoveInPlace(cur, m);
    return cur;
}

inline CubieState applySequence(const CubieState& s, const std::string& moves) {
    return applySequence(s, parseSequence(moves));
}

/// Inverse of `face * 3 + (amount - 1)`, i.e. U <-> U', R2 stays R2.
inline int inverseMove(int move) {
    const int face = move / 3;
    const int amount = move % 3 + 1;      // 1, 2 or 3
    const int inverseAmount = 4 - amount; // 1 -> 3, 2 -> 2, 3 -> 1
    return face * 3 + (inverseAmount - 1);
}

/// The move sequence that undoes `moves`.
inline std::vector<int> invertSequence(const std::vector<int>& moves) {
    std::vector<int> out;
    out.reserve(moves.size());
    for (auto it = moves.rbegin(); it != moves.rend(); ++it) {
        out.push_back(inverseMove(*it));
    }
    return out;
}

}  // namespace rubik

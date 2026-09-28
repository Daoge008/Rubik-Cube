#pragma once
#include "cube_model.hpp"
#include "move_engine.hpp"

#include <array>
#include <cstdint>
#include <vector>

namespace rubik {

enum class PieceKind { Corner, Edge };

/// Which requirement the table measures the distance to.
enum class GoalKind {
    /// Each piece back on its home position with orientation 0 (a cross edge
    /// or an F2L pair slot).
    HomeAndOriented,
    /// Each piece oriented, position free (last layer edge/corner orientation).
    OrientedOnly,
    /// Each piece on its home position, orientation free (last layer
    /// permutation).
    HomePositionOnly
};

struct PieceRef {
    PieceKind kind;
    int8_t piece;     // Corner / Edge enum value
    int8_t homePos;   // position the piece belongs to (equal to `piece` here)
};

/// Exact distance-to-goal for a small group of pieces (one to four), measured
/// in the relaxed problem where every other piece is free to move.
///
/// The coordinate is the group's (position, orientation) pairs, using radix 24
/// for both piece kinds (corners: 3 * pos + ori, edges: 2 * pos + ori), so a
/// one piece table holds 24 entries and a four piece table 24^4 = 331,776.
///
/// Because a move changes a piece's own (position, orientation) independently
/// of every other piece, the coordinate transition is well defined, which
/// makes the distance an admissible heuristic for the full cube problem.
class PieceGroupTable {
public:
    static constexpr int MAX_PIECES = 4;

    void build(const std::vector<PieceRef>& pieces, GoalKind kind) {
        pieces_ = pieces;
        kind_ = kind;
        count_ = (int)pieces_.size();
        size_ = 1;
        for (int i = 0; i < count_; ++i) size_ *= 24;

        dist_.assign((size_t)size_, 0xFF);

        std::vector<uint32_t> frontier;
        std::vector<uint32_t> next;

        if (kind == GoalKind::HomeAndOriented) {
            int digits[MAX_PIECES] = { 0, 0, 0, 0 };
            for (int k = 0; k < count_; ++k) {
                const int radix = (pieces_[k].kind == PieceKind::Corner) ? 3 : 2;
                digits[k] = pieces_[k].homePos * radix;
            }
            const uint32_t start = (uint32_t)encode(digits);
            dist_[start] = 0;
            frontier.push_back(start);
        } else {
            for (int index = 0; index < size_; ++index) {
                int digits[MAX_PIECES] = { 0, 0, 0, 0 };
                decode(index, digits);
                // Only seed *consistent* goal configurations. Seeding two
                // pieces on the same position would let the BFS wander through
                // states no real cube can reach and would poison the table
                // with distances that are too small.
                if (consistent(digits) && satisfies(digits)) {
                    dist_[(size_t)index] = 0;
                    frontier.push_back((uint32_t)index);
                }
            }
        }

        uint8_t depth = 0;
        while (!frontier.empty()) {
            ++depth;
            next.clear();
            for (uint32_t index : frontier) {
                int digits[MAX_PIECES] = { 0, 0, 0, 0 };
                decode((int)index, digits);
                const CubieState state = stateFromDigits(digits);
                for (int m = 0; m < 18; ++m) {
                    const CubieState moved = applyMove(state, m);
                    const int target = coordOf(moved);
                    if (target < 0 || dist_[(size_t)target] != 0xFF) continue;
                    dist_[(size_t)target] = depth;
                    next.push_back((uint32_t)target);
                }
            }
            frontier.swap(next);
        }
    }

    bool ready() const { return !dist_.empty(); }

    /// How many of the 24^n coordinate combinations are actually realisable
    /// for a group of `c` corners and `e` edges: 8Pc * 3^c * 12Pe * 2^e. The
    /// remaining combinations (two pieces sharing a position) are unreachable
    /// by construction and keep the 0xFF marker forever.
    int expectedEntries() const {
        int corners = 0;
        int edges = 0;
        for (const PieceRef& p : pieces_) {
            if (p.kind == PieceKind::Corner) corners++;
            else edges++;
        }
        long long total = 1;
        for (int i = 0; i < corners; ++i) total *= (8 - i);
        for (int i = 0; i < corners; ++i) total *= 3;
        for (int i = 0; i < edges; ++i) total *= (12 - i);
        for (int i = 0; i < edges; ++i) total *= 2;
        return (int)total;
    }

    int visitedCount() const {
        int n = 0;
        for (uint8_t d : dist_) {
            if (d != 0xFF) n++;
        }
        return n;
    }

    /// True when the backwards BFS reached exactly the realisable part of the
    /// coordinate space and the solved state reads as distance 0. Anything
    /// less means the search would see "distance unknown" entries.
    bool complete() const {
        if (!ready()) return false;
        if (visitedCount() != expectedEntries()) return false;
        const CubieState solved = CubeModel::solvedState();
        const int goalIndex = coordOf(solved);
        return goalIndex >= 0 && dist_[(size_t)goalIndex] == 0;
    }

    /// Table size in bytes.
    size_t bytes() const { return dist_.size(); }

    int entryCount() const { return size_; }

    /// Distance of `s` to this group's goal. 0 when already satisfied.
    uint8_t dist(const CubieState& s) const {
        const int index = coordOf(s);
        if (index < 0 || (size_t)index >= dist_.size()) return 0;
        return dist_[(size_t)index];
    }

    int coordOf(const CubieState& s) const {
        int digits[MAX_PIECES] = { 0, 0, 0, 0 };
        for (int k = 0; k < count_; ++k) {
            bool ok = true;
            digits[k] = digitOf(s, pieces_[k], ok);
            if (!ok) return -1;
        }
        return encode(digits);
    }

    /// Same as `coordOf` but reads a piece -> (position, orientation) lookup
    /// that the caller built once for the whole state. The heuristic is
    /// evaluated millions of times during a search, so avoiding a fresh scan
    /// per table matters.
    int coordFromMaps(const int8_t* cornerPos, const int8_t* cornerOri,
                      const int8_t* edgePos, const int8_t* edgeOri) const {
        int digits[MAX_PIECES] = { 0, 0, 0, 0 };
        for (int k = 0; k < count_; ++k) {
            const PieceRef& p = pieces_[k];
            if (p.kind == PieceKind::Corner) {
                const int pos = cornerPos[p.piece];
                if (pos < 0) return -1;
                digits[k] = pos * 3 + cornerOri[p.piece];
            } else {
                const int pos = edgePos[p.piece];
                if (pos < 0) return -1;
                digits[k] = pos * 2 + edgeOri[p.piece];
            }
        }
        return encode(digits);
    }

    /// `dist` counterpart of `coordFromMaps`.
    uint8_t distFromMaps(const int8_t* cornerPos, const int8_t* cornerOri,
                         const int8_t* edgePos, const int8_t* edgeOri) const {
        const int index = coordFromMaps(cornerPos, cornerOri, edgePos, edgeOri);
        if (index < 0 || (size_t)index >= dist_.size()) return 0;
        return dist_[(size_t)index];
    }

private:
    int encode(const int* digits) const {
        int index = 0;
        for (int k = 0; k < count_; ++k) index = index * 24 + digits[k];
        return index;
    }

    void decode(int index, int* digits) const {
        for (int k = count_ - 1; k >= 0; --k) {
            digits[k] = index % 24;
            index /= 24;
        }
    }

    /// No two pieces of the same kind may claim the same position.
    bool consistent(const int* digits) const {
        int cornerPos = -1;
        int cornerMask = 0;
        int edgeMask = 0;
        for (int k = 0; k < count_; ++k) {
            const PieceRef& p = pieces_[k];
            if (p.kind == PieceKind::Corner) {
                const int pos = digits[k] / 3;
                if (cornerMask & (1 << pos)) return false;
                cornerMask |= 1 << pos;
            } else {
                const int pos = digits[k] / 2;
                if (edgeMask & (1 << pos)) return false;
                edgeMask |= 1 << pos;
            }
        }
        (void)cornerPos;
        return true;
    }

    bool satisfies(const int* digits) const {
        for (int k = 0; k < count_; ++k) {
            const PieceRef& p = pieces_[k];
            const int radix = (p.kind == PieceKind::Corner) ? 3 : 2;
            const int pos = digits[k] / radix;
            const int ori = digits[k] % radix;
            switch (kind_) {
                case GoalKind::HomeAndOriented:
                    if (pos != p.homePos || ori != 0) return false;
                    break;
                case GoalKind::OrientedOnly:
                    if (ori != 0) return false;
                    break;
                case GoalKind::HomePositionOnly:
                    if (pos != p.homePos) return false;
                    break;
            }
        }
        return true;
    }

    static int digitOf(const CubieState& s, const PieceRef& p, bool& ok) {
        if (p.kind == PieceKind::Corner) {
            for (int i = 0; i < 8; ++i) {
                if (s.cp[i] == p.piece) return i * 3 + s.co[i];
            }
        } else {
            for (int i = 0; i < 12; ++i) {
                if (s.ep[i] == p.piece) return i * 2 + s.eo[i];
            }
        }
        ok = false;
        return 0;
    }

    /// A state that realises `digits`. Only reachable (therefore consistent)
    /// digit combinations ever reach `applyMove`, so a plain "place the group,
    /// then fill the leftover positions" construction is enough.
    CubieState stateFromDigits(const int* digits) const {
        CubieState s{};
        bool cornerUsed[8] = {false};
        bool edgeUsed[12] = {false};
        int8_t cp[8];
        int8_t co[8];
        int8_t ep[12];
        int8_t eo[12];
        for (int i = 0; i < 8; ++i) { cp[i] = -1; co[i] = 0; }
        for (int i = 0; i < 12; ++i) { ep[i] = -1; eo[i] = 0; }

        for (int k = 0; k < count_; ++k) {
            const PieceRef& p = pieces_[k];
            if (p.kind == PieceKind::Corner) {
                const int pos = digits[k] / 3;
                if (pos < 0 || pos > 7) continue;
                cp[pos] = p.piece;
                co[pos] = (int8_t)(digits[k] % 3);
                cornerUsed[p.piece] = true;
            } else {
                const int pos = digits[k] / 2;
                if (pos < 0 || pos > 11) continue;
                ep[pos] = p.piece;
                eo[pos] = (int8_t)(digits[k] % 2);
                edgeUsed[p.piece] = true;
            }
        }

        int nextCorner = 0;
        for (int pos = 0; pos < 8; ++pos) {
            if (cp[pos] >= 0) continue;
            while (nextCorner < 8 && cornerUsed[nextCorner]) nextCorner++;
            if (nextCorner >= 8) break;
            cp[pos] = (int8_t)nextCorner;
            cornerUsed[nextCorner] = true;
        }
        int nextEdge = 0;
        for (int pos = 0; pos < 12; ++pos) {
            if (ep[pos] >= 0) continue;
            while (nextEdge < 12 && edgeUsed[nextEdge]) nextEdge++;
            if (nextEdge >= 12) break;
            ep[pos] = (int8_t)nextEdge;
            edgeUsed[nextEdge] = true;
        }

        for (int i = 0; i < 8; ++i) { s.cp[i] = cp[i]; s.co[i] = co[i]; }
        for (int i = 0; i < 12; ++i) { s.ep[i] = ep[i]; s.eo[i] = eo[i]; }
        return s;
    }

    std::vector<PieceRef> pieces_;
    GoalKind kind_ = GoalKind::HomeAndOriented;
    int count_ = 0;
    int size_ = 0;
    std::vector<uint8_t> dist_;
};

}  // namespace rubik

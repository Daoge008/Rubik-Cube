#pragma once
#include <vector>
#include <array>
#include <cmath>
#include <algorithm>
#include <map>
#include <deque>
#include <string>

struct Point2D {
    float x;
    float y;
};

enum class DetectedColor : int {
    WHITE = 0,
    RED = 1,
    GREEN = 2,
    YELLOW = 3,
    ORANGE = 4,
    BLUE = 5,
    UNKNOWN = -1
};

struct LabColor {
    float L;
    float a;
    float b;
};

inline std::vector<Point2D> orderCorners(const std::vector<Point2D>& pts) {
    if (pts.size() != 4) return pts;
    std::vector<Point2D> ordered(4);

    Point2D center{0.0f, 0.0f};
    for (const auto& p : pts) {
        center.x += p.x;
        center.y += p.y;
    }
    center.x *= 0.25f;
    center.y *= 0.25f;

    std::vector<std::pair<float, Point2D>> angles;
    for (const auto& p : pts) {
        float angle = std::atan2(p.y - center.y, p.x - center.x);
        angles.push_back({angle, p});
    }
    std::sort(angles.begin(), angles.end(), [](const auto& a, const auto& b) {
        return a.first < b.first;
    });

    int tl_idx = 0;
    float min_dist = 1e9f;
    for (int i = 0; i < 4; ++i) {
        float sum = angles[i].second.x + angles[i].second.y;
        if (sum < min_dist) {
            min_dist = sum;
            tl_idx = i;
        }
    }

    for (int i = 0; i < 4; ++i) {
        ordered[i] = angles[(tl_idx + i) % 4].second;
    }
    return ordered;
}

inline float computeDeltaE94(const LabColor& lab1, const LabColor& lab2) {
    float dL = lab1.L - lab2.L;
    float da = lab1.a - lab2.a;
    float db = lab1.b - lab2.b;

    float c1 = std::sqrt(lab1.a * lab1.a + lab1.b * lab1.b);
    float c2 = std::sqrt(lab2.a * lab2.a + lab2.b * lab2.b);
    float dC = c1 - c2;
    float dH2 = da * da + db * db - dC * dC;
    float dH = (dH2 > 0.0f) ? std::sqrt(dH2) : 0.0f;

    const float kL = 1.0f, kC = 1.0f, kH = 1.0f;
    const float K1 = 0.045f, K2 = 0.015f;

    float sL = 1.0f;
    float sC = 1.0f + K1 * c1;
    float sH = 1.0f + K2 * c1;

    float vL = dL / (kL * sL);
    float vC = dC / (kC * sC);
    float vH = dH / (kH * sH);

    return std::sqrt(vL * vL + vC * vC + vH * vH);
}

class AdaptiveColorClassifier {
public:
    std::map<DetectedColor, LabColor> anchors;
    bool isAnchored[6] = {false};

    AdaptiveColorClassifier() {
        anchors[DetectedColor::WHITE]  = {95.0f, 0.0f, 3.0f};
        anchors[DetectedColor::YELLOW] = {85.0f, -8.0f, 85.0f};
        anchors[DetectedColor::RED]    = {45.0f, 65.0f, 45.0f};
        anchors[DetectedColor::ORANGE] = {60.0f, 45.0f, 68.0f};
        anchors[DetectedColor::BLUE]   = {35.0f, 10.0f, -50.0f};
        anchors[DetectedColor::GREEN]  = {55.0f, -60.0f, 35.0f};
    }

    void updateAnchor(DetectedColor color, const LabColor& measuredLab) {
        int idx = static_cast<int>(color);
        if (idx < 0 || idx >= 6) return;

        if (!isAnchored[idx]) {
            anchors[color] = measuredLab;
            isAnchored[idx] = true;
        } else {
            anchors[color].L = 0.8f * anchors[color].L + 0.2f * measuredLab.L;
            anchors[color].a = 0.8f * anchors[color].a + 0.2f * measuredLab.a;
            anchors[color].b = 0.8f * anchors[color].b + 0.2f * measuredLab.b;
        }
    }

    DetectedColor classify(const LabColor& targetLab) const {
        DetectedColor bestColor = DetectedColor::UNKNOWN;
        float minDelta = 1e9f;

        for (const auto& [color, anchorLab] : anchors) {
            float dist = computeDeltaE94(targetLab, anchorLab);
            if (dist < minDelta) {
                minDelta = dist;
                bestColor = color;
            }
        }
        return bestColor;
    }
};

class MultiFrameAggregator {
private:
    const size_t WINDOW_SIZE = 8;
    std::map<DetectedColor, std::deque<std::array<DetectedColor, 9>>> history;
    std::map<DetectedColor, std::array<DetectedColor, 9>> stableFaces;

public:
    void reset() {
        history.clear();
        stableFaces.clear();
    }

    void pushFrame(const std::array<DetectedColor, 9>& currentStickers) {
        DetectedColor centerColor = currentStickers[4];
        if (centerColor == DetectedColor::UNKNOWN) return;

        auto& q = history[centerColor];
        q.push_back(currentStickers);
        if (q.size() > WINDOW_SIZE) {
            q.pop_front();
        }

        if (q.size() == WINDOW_SIZE) {
            std::array<DetectedColor, 9> candidate;
            bool highConfidence = true;

            for (int i = 0; i < 9; ++i) {
                std::map<DetectedColor, int> voteCount;
                for (const auto& record : q) {
                    voteCount[record[i]]++;
                }

                DetectedColor topColor = DetectedColor::UNKNOWN;
                int maxVotes = 0;
                for (auto& [c, count] : voteCount) {
                    if (count > maxVotes) {
                        maxVotes = count;
                        topColor = c;
                    }
                }

                if (maxVotes < 6) {
                    highConfidence = false;
                    break;
                }
                candidate[i] = topColor;
            }

            if (highConfidence) {
                stableFaces[centerColor] = candidate;
            }
        }
    }

    int getScannedFaceCount() const {
        return static_cast<int>(stableFaces.size());
    }

    bool isAllFacesScanned() const {
        return stableFaces.size() == 6;
    }

    bool assembleSingmasterString(std::string& outCubeString) const {
        if (!isAllFacesScanned()) return false;

        std::map<DetectedColor, int> totalCount;
        for (const auto& [center, grid] : stableFaces) {
            for (DetectedColor c : grid) {
                totalCount[c]++;
            }
        }

        for (int i = 0; i < 6; ++i) {
            if (totalCount[static_cast<DetectedColor>(i)] != 9) {
                return false;
            }
        }

        const char colorNotationMap[6] = {'U', 'R', 'F', 'D', 'L', 'B'};
        const std::vector<DetectedColor> faceOrder = {
            DetectedColor::WHITE, DetectedColor::RED, DetectedColor::GREEN,
            DetectedColor::YELLOW, DetectedColor::ORANGE, DetectedColor::BLUE
        };

        outCubeString.clear();
        for (DetectedColor f : faceOrder) {
            if (stableFaces.find(f) == stableFaces.end()) return false;
            const auto& grid = stableFaces.at(f);
            for (DetectedColor c : grid) {
                outCubeString += colorNotationMap[static_cast<int>(c)];
            }
        }
        return true;
    }
};

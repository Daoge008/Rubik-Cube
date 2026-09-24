#pragma once
#include "cube_model.hpp"
#include <string>
#include <vector>

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
};

class CFOPSolver {
public:
    static std::vector<CFOPStep> generateGuide(const std::string& facelets) {
        std::vector<CFOPStep> steps;

        steps.push_back({
            CFOPStage::CROSS,
            "底层白色十字 (White Cross)",
            "D R' F D2",
            "旋转前层与底层，使4个白色棱块归位并对齐四周中心色",
            "在顶层或中层找到白色棱块，将侧面颜色与对应中心块对齐后，旋转对应层沉入底面。"
        });

        steps.push_back({
            CFOPStage::F2L_1,
            "第一组槽位 (F2L Slot FR)",
            "U R U' R' U' F' U F",
            "在顶层配对白红绿角块与红绿棱块，插入右前槽位",
            "将角块与棱块同色朝向调整到顶层，合成'角棱对'，一并旋转压入中底层槽位。"
        });

        steps.push_back({
            CFOPStage::F2L_2,
            "第二组槽位 (F2L Slot FL)",
            "U' L' U L U F U' F'",
            "配对白绿橙角块与绿橙棱块，插入左前槽位",
            "利用顶层旋转避开已还原槽位，完成配对后切入左前夹角。"
        });

        steps.push_back({
            CFOPStage::F2L_3,
            "第三组槽位 (F2L Slot BR)",
            "U R' U' R U' R' U R",
            "配对白红蓝角块与红蓝棱块，插入右后槽位",
            "保持底面不动，利用右手公式组合完成右后方嵌合。"
        });

        steps.push_back({
            CFOPStage::F2L_4,
            "第四组槽位 (F2L Slot BL)",
            "U' L U L' U L U' L'",
            "配对白橙蓝角块与橙蓝棱块，插入最后左后槽位",
            "前两层(前中层)全部还原完毕，准备进入顶层阶段。"
        });

        steps.push_back({
            CFOPStage::OLL_2LOOK_EDGE,
            "顶层黄色十字 (OLL Edge 2-Look)",
            "F R U R' U' F'",
            "将顶面黄色一字形或折角转动为黄色十字",
            "观察黄色棱块分布：若为折角形使用 f R U R' U' f'，若为一字形水平放置后使用 F R U R' U' F'。"
        });

        steps.push_back({
            CFOPStage::OLL_2LOOK_CORNER,
            "顶层黄色全翻满 (OLL Corner - Sune)",
            "R U R' U R U2 R'",
            "小鱼形黄色角块全部翻转朝上，顶面全黄",
            "将鱼头朝向左前方，执行小鱼公式将四周黄色全部翻转到顶层。"
        });

        steps.push_back({
            CFOPStage::PLL_2LOOK_CORNER,
            "顶层角块归位 (PLL 2-Look Corner - T-Perm)",
            "R U R' U' R' F R2 U' R' U' R U R' F'",
            "对齐顶层 4 个角块颜色位置",
            "找到一侧同色的'车前灯'置于左手面，使用 T-Perm 还原所有四个角块位置。"
        });

        steps.push_back({
            CFOPStage::PLL_2LOOK_EDGE,
            "顶层最后三棱复原 (PLL 2-Look Edge - Ua-Perm)",
            "R U' R U R U R U' R' U' R2",
            "顺时针换三棱，魔方完全复原",
            "将已还原好的完整一面置于后方，对剩余三棱执行换棱公式完成全魔方还原！"
        });

        return steps;
    }
};

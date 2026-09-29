import 'package:flutter/material.dart';

class BeginnerGuideSheet extends StatelessWidget {
  const BeginnerGuideSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const BeginnerGuideSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: Color(0xFF1E1E2C),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.school_rounded, color: Color(0xFF00E676), size: 26),
                const SizedBox(width: 10),
                const Text(
                  '魔方新手入门指南',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white12, height: 1),
          // Scrollable content
          Flexible(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              children: [
                _buildSectionCard(
                  title: '1. 持握基准视向（极其重要）',
                  icon: Icons.pan_tool_rounded,
                  iconColor: const Color(0xFFFFD600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '现实操作中请严格遵循如下基准朝向：',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildFaceTag('白色朝上 (U)', Colors.white, Colors.black),
                          const SizedBox(width: 8),
                          _buildFaceTag('绿色朝前 (F)', const Color(0xFF43A047), Colors.white),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '• 此时你左手边是橙色(L)，右手边是红色(R)，底下是黄色(D)，背后是蓝色(B)。\n• 按照此标准持握，3D动画的转动方向与你手里的魔方完全一致！',
                        style: TextStyle(color: Colors.white60, fontSize: 12, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _buildSectionCard(
                  title: '2. 字母符号含义与颜色对照',
                  icon: Icons.translate_rounded,
                  iconColor: const Color(0xFF40C4FF),
                  child: Column(
                    children: [
                      _buildFaceRow('U', 'Up', '顶层', '白色面', Colors.white, '顺时针向左拨'),
                      _buildFaceRow('D', 'Down', '底层', '黄色面', const Color(0xFFFDD835), '顺时针向右拨'),
                      _buildFaceRow('F', 'Front', '正面', '绿色面', const Color(0xFF43A047), '正对着顺时针转'),
                      _buildFaceRow('B', 'Back', '背面', '蓝色面', const Color(0xFF1E88E5), '背后层顺时针转'),
                      _buildFaceRow('L', 'Left', '左层', '橙色面', const Color(0xFFFB8C00), '左侧层向下转'),
                      _buildFaceRow('R', 'Right', '右层', '红色面', const Color(0xFFE53935), '右侧层向上推'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _buildSectionCard(
                  title: '3. 符号后缀代表的方向',
                  icon: Icons.rotate_right_rounded,
                  iconColor: const Color(0xFFFF4081),
                  child: Column(
                    children: [
                      _buildSuffixRow('单一字母（如 R）', '顺时针转 90°', '转动 1/4 圈'),
                      _buildSuffixRow("带撇号 '（如 R'）", '逆时针转 90°', '反向转 1/4 圈'),
                      _buildSuffixRow('带数字 2（如 U2）', '转动 180°', '旋转半圈（顺逆皆可）'),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _buildSectionCard(
                  title: '4. 经典必背手法口诀',
                  icon: Icons.auto_awesome_rounded,
                  iconColor: const Color(0xFF00E676),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFormulaTip(
                        name: '右手公式（上左下右）',
                        code: "R U R' U'",
                        tip: '右上推 → 顶左拨 → 右下拉 → 顶右拨',
                      ),
                      const SizedBox(height: 10),
                      _buildFormulaTip(
                        name: '左手公式（上右下左）',
                        code: "L' U' L U",
                        tip: '左上拉 → 顶右拨 → 左下拉 → 顶左拨',
                      ),
                      const SizedBox(height: 10),
                      _buildFormulaTip(
                        name: '顶层黄十字公式',
                        code: "F R U R' U' F'",
                        tip: '前顺 → 右手公式 → 前逆',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF28283C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }

  Widget _buildFaceTag(String text, Color bg, Color textCol) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(color: textCol, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildFaceRow(
    String letter,
    String eng,
    String face,
    String colorName,
    Color dotColor,
    String moveDesc,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF3F51B5).withOpacity(0.4),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              letter,
              style: const TextStyle(
                color: Color(0xFFFFD600),
                fontWeight: FontWeight.w900,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$face ($colorName)',
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Text(
            moveDesc,
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSuffixRow(String symbol, String meaning, String note) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(symbol, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          Text(meaning, style: const TextStyle(color: Color(0xFF00E676), fontSize: 13)),
          Text(note, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildFormulaTip({
    required String name,
    required String code,
    required String tip,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2C),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
              Text(
                code,
                style: const TextStyle(
                  color: Color(0xFFFFD600),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text('口诀：$tip', style: const TextStyle(color: Color(0xFF8C9EFF), fontSize: 12)),
        ],
      ),
    );
  }
}

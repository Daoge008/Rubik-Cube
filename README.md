# Rubik AR - Android 实时识别与指导还原魔方 App

[![Platform](https://img.shields.io/badge/Platform-Android%208.0%2B-blue.svg)](https://developer.android.com)
[![Framework](https://img.shields.io/badge/Framework-Flutter%203.x-02569B.svg)](https://flutter.dev)
[![Engine](https://img.shields.io/badge/Engine-C%2B%2B17%20%7C%20NDK-00599C.svg)](https://isocpp.org)

基于 Flutter + C++ NDK 的 Android 实时魔方智能识别与 AR 教学还原应用。

## 核心特性
1. **混合视觉感知**: YOLOv8-OBB 旋转框 + 局部 CIELAB ΔE94 动态中心锚定色彩聚类。
2. **自由旋转连续识别**: 镜头前自由翻转，多帧滑动窗口多数表决自动锁定 6 面并组装 54-Facelet。
3. **离线双求解内核**: Kociemba 最少步算法 (~20 步最优解) 与 CFOP 初学者 4 阶段教学引擎。
4. **真实相机 AR 空间叠加**: solvePnP 6DoF 空间位姿估计，3D 弯曲立体转动箭头贴合真实魔方。
5. **实时拧法核验与自动跳步**: 实时检测用户转动手法，验证正确后自动进入下一步，伴随触觉与音效反馈。

## 目录结构
- `android/app/src/main/cpp/`: C++ 原生高性能视觉与求解引擎 (OpenCV / Kociemba / CFOP / AR)
- `lib/`: Flutter 业务、AR Overlay 绘制与 FFI 桥接层
- `docs/`: 完备架构与技术设计文档

# 环境准备与构建运行指南 (Setup & Build)

## 依赖环境
- Android SDK 34 (最低 Android 8.0 / API 26)
- Android NDK 25+
- Flutter 3.19+
- CMake 3.22+

## 快速构建
```bash
flutter pub get
flutter run --release
flutter build apk --release --split-per-abi
```

# 环境准备与构建运行指南 (Setup & Build)

## 依赖环境（本机实测版本）
- Flutter 3.47.5（`D:\dev\flutter`）
- Android SDK：compileSdk / targetSdk 36，minSdk 与 Flutter 默认一致（API 26+）
- **Android NDK 28.2.13676358**（插件 audioplayers_android / camera_android / device_info_plus /
  flutter_plugin_android_lifecycle / jni / vibration 均要求该版本，勿降回 27.2）
- CMake 3.22.1
- **JDK 17**（`D:\dev\java\jdk-17`）。本机全局 JAVA_HOME 指向 JDK 8，跑 Gradle 必须显式覆盖，
  否则报 `Gradle requires JVM 17`
- 真机：小米 2410DPN6CC（MIUI，需在开发者选项里额外打开「USB安装」）

## 快速构建
```bash
flutter pub get
flutter run                # 调试
flutter run --profile      # 性能测试：debug 模式下 YOLO 实时识别帧率低，必须用 profile/release
flutter build apk --release --split-per-abi
```

## 原生引擎（librubik_core.so）

原生部分由 `android/app/src/main/cpp/CMakeLists.txt` 构建，Gradle 在
`android/app/build.gradle.kts` 的 `externalNativeBuild.cmake` 里接入，产物随 APK 一起打包。

改完 `cpp/` 下的代码后，**必须单独跑下面两条校验**。只看 APK 构建结果是不可靠的：
APK 里已存在旧 `librubik_core.so` 时，「构建成功」并不能说明新代码编过了。

### 1) 算法正确性 —— 宿主侧单测

`tools/native_tests/run_tests.bat` 用 MSVC 编译 `engine_test.cpp`，与 Android 库**共用同一份头文件**，
所以在电脑上全绿就意味着引擎在进手机之前算术是对的。覆盖 facelet↔cubie 往返、单步手推校验、
群阶、非法态拒绝、Kociemba 200 例、**顶层公式表完备性穷举（335 个合法状态）**、CFOP 40 例。

### 2) 真机可编译性 —— NDK 编译级校验

`tools/native_tests/syntax_check.bat` 用 NDK clang 对 `aarch64-linux-android26` 做
`-fsyntax-only`，逐个编译 `cpp/` 下所有 `.cpp`。

宿主单测**不编译** `native_cube_pipeline.cpp`（FFI 边界层），命名空间不匹配、平台专属 include
这类错误只有这一步能发现 —— 曾经因此让 `librubik_core.so` 构建失败而不自知。

### 3) 诊断工具（非测试）

`tools/native_tests/probe.bat cfop_probe.cpp [案例数]` 按阶段输出教学求解器的耗时、
级联层级与阶段长度直方图，用于定位某个阶段是否静默退化成原始搜索。

### 4) 链接级校验（需要确认导出符号时）

用 CMake + Ninja 直接编 `.so`，再用 `llvm-nm -D --defined-only` 确认 FFI 符号导出。
具体命令见 skill `flutter-android-setup-windows`。

## 已知构建注意事项

- 根 `android/build.gradle.kts` 用 `subprojects { if (!state.executed) afterEvaluate { ... } }`
  把所有插件子工程的 compileSdk 统一抬到 36，用于压掉插件里过时的 `compileSdkVersion`
  （如 vibration 2.1.0 写死 33 导致 `checkDebugAarMetadata` 报 15 条错误）。
  必须带 `state.executed` 守卫：Flutter 模板里已有 `subprojects { evaluationDependsOn(":app") }`，
  `:app` 已被评估，直接注册 `afterEvaluate` 会抛
  `Cannot run Project.afterEvaluate(Action) when the project is already evaluated`。
- `gradle.properties` 里的 `android.builtInKotlin=false` / `android.newDsl=false` 是 Flutter
  migrator 自动加的，AGP 10 会移除。
- WorkBuddy 沙箱内 `flutter` 命令一律报 `CreateFile failed 231`（Dart 建管道被拦），
  且输出经 `| Tee-Object` 也会触发。绕过方式见 skill。

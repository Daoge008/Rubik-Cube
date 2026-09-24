# 项目全面检查报告 (Project Audit)

检查时间：2026-09-24
检查范围：`lib/`(15 个 Dart) · `android/`(Gradle 配置 · Manifest · Kotlin · `cpp/` 10 个 C++ 文件) · `docs/`(5 篇) · `pubspec.yaml` / `pubspec.lock`
检查手段：
1. 逐文件通读全部源码与配置；
2. 用本机 NDK 27.2 的 `clang++ --target=aarch64-linux-android26 -std=c++17 -Wall -Wextra -fsyntax-only` 对 C++ 引擎做编译级校验（结果：**0 error / 9 warning**，其中多条警告即为"未实现"的直接证据）；
3. 尝试 `flutter analyze` / `dart analyze` —— 两者均因本机系统级故障 `CreateFile failed 231（所有管道实例都在使用中）` 无法启动语言服务器，故 **Dart 侧为人工评审结论**（详见"检查局限"）。

---

## 一、总体结论

| 维度 | 状态 | 说明 |
|---|---|---|
| 项目骨架 / 目录分层 | ✅ 良好 | 分层清晰（视觉 / 求解 / AR / FFI / UI），文件命名规范 |
| 数据模型与算法骨架 | 🟡 部分可用 | 54→Cubie 映射表、4 大守恒校验、ΔE94 色差、8 帧多数表决聚合器是**真实实现且质量不错** |
| 原生引擎功能 | ❌ **核心全部为占位假实现** | Kociemba、CFOP、视觉识别、步进校验、AR 投影 5 个引擎全部返回硬编码结果 |
| 原生 ↔ Dart 接线 | ❌ 断裂 | 原生管线句柄从未初始化，整条 FFI 管线静默失效 |
| Flutter 业务/UI | ❌ 演示级 | 无摄像头、无真实扫描，界面按钮驱动写死数据 |
| Android 构建 | 🟡 **4 处阻断已全部修复**（见第十节），配置阶段与原生编译均已实测通过；最后一步被本机 Dart 环境缺陷挡住 | 见第三节、第十节 |
| 工程化 | 🟡 缺失 | 无 lint 配置、无测试、无 `.metadata`、5 个未使用重依赖 |

**一句话**：这是一个**架构设计完整、视觉与求解的"骨架零件"有真材实料，但所有智能内核都还是占位桩、并且 Android 工程无法构建**的半成品。当前的"可运行行为"仅为：扫描页点 6 次按钮 → 立刻显示"魔方已成功复原"。

---

## 二、代码规模与文件清点

```
lib/        15 个文件   main.dart · models/(3) · core/(ar, native_bridge, solver, vision 各 1) · ui/screens/(4) · ui/widgets/(3)
android/    cpp/ 10 个文件（1 .cpp + 1 .h + 7 .hpp + CMakeLists）  ·  app/build.gradle · settings.gradle · build.gradle · AndroidManifest.xml · MainActivity.kt
docs/       5 篇 md，累计不足 40 行
assets/     仅 models/README.md（模型文件不存在）
```

---

## 三、P0-A：Android 构建阻断（4 项，当前 100% 构建失败）

### 1. `settings.gradle` 使用了已被删除的旧式插件加载方式 —— 配置阶段直接抛异常

`android/settings.gradle:11`：
```gradle
apply from: "$flutterSdkPath/packages/flutter_tools/gradle/app_plugin_loader.gradle"
```

而本机 Flutter 3.47.5 中该文件**全文只做一件事**——抛异常：
```
throw new GradleException("You are applying Flutter's app_plugin_loader Gradle plugin
imperatively using the apply script method, which is not possible anymore.")
```
→ 修复：迁移到声明式 plugins block（`pluginManagement { plugins { id "dev.flutter.flutter-plugin-loader" version "1.0.0" ... } }`）。

### 2. 三个 Gradle 插件都没有版本来源

`android/app/build.gradle` 声明了 `com.android.application` / `kotlin-android` / `dev.flutter.flutter-gradle-plugin`，但：
- `android/build.gradle` **完全没有 `buildscript { dependencies { classpath ... } }` 块**（已全目录检索确认无 `buildscript` / `classpath` / `pluginManagement` 任何出现，仅 `gradlew` 脚本自带的一处无关 `-classpath`）；
- `settings.gradle` 也没有 `pluginManagement` + `plugins` 版本声明。

→ 三个插件均无解析来源，Gradle 会以 `Plugin [id: 'com.android.application'] was not found in any of the following sources` 失败。

### 3. `res/` 目录整个不存在

`android/app/src/main/` 下只有 `cpp/`、`kotlin/`、`java/`、`AndroidManifest.xml`，**`res/` 目录不存在**。而 Manifest 引用了：
- `android:icon="@mipmap/ic_launcher"`
- `android:theme="@style/LaunchTheme"` / `@style/NormalTheme`

→ 资源链接（`processDebugResources`）必然失败。缺失清单：`values/styles.xml`、`values-night/styles.xml`、`drawable/launch_background.xml`、`mipmap-{mdpi..xxxhdpi}/ic_launcher.png`。

### 4. 指定的 NDK 版本本机未安装

`android/app/build.gradle:28`：`ndkVersion "25.1.8937393"`
本机 `Android/Sdk/ndk/` 下**只有 `27.2.12479018`**。
→ 报 "NDK not configured / 指定版本未安装"。改 `ndkVersion` 或补装 25.1。

### 附：其他构建相关风险
- `android/gradle.properties` 仅有两条 migrator 标记（`android.builtInKotlin=false` / `android.newDsl=false`），**缺 `android.useAndroidX=true`**（AndroidX 依赖未开启会直接报错），也缺 `org.gradle.jvmargs=-Xmx…`。
- 缺 Flutter 模板标配的 `src/debug/AndroidManifest.xml` 与 `src/profile/AndroidManifest.xml`（debug 版负责注入 `INTERNET` 权限，缺失会影响调试期联网/热重载链路）。
- `release` 构建用的是 `signingConfigs.debug` 签名 → 可安装测试，但无法上架。
- ✅ 正常项：`gradle-wrapper.properties` 指向腾讯镜像 gradle-8.4；`compileSdk 34 / minSdk 26 / Java 17` 配置自洽；CMake 产物名 `librubik_core.so` 与 Dart 侧 `DynamicLibrary.open("librubik_core.so")` 一致；FFI 结构体 C/Dart 双侧布局一致（`int + Point2D[4] + int[9] + 4×int`，4 字节对齐）。

---

## 四、P0-B：核心功能全部是"假实现"（本项目最重要的问题）

编译警告本身就是证据（`-Wunused-parameter` / `-Wtautological-constant-out-of-range-compare`）。

| 引擎 | 文件 | 实际行为 | 证据 |
|---|---|---|---|
| **Kociemba 最少步求解** | `kociemba_solver.hpp:33` | 校验通过且未还原时，**无条件返回同一串硬编码动作** `"R U R' U' D R' U F' D2 R2 B2 L' F2 R2 D2 R' U2 R"`，与输入无关 | 警告：`unused parameter 'max_depth'` |
| **CFOP 教学引擎** | `cfop_pipeline.hpp:25-100` | 固定 `push_back` 9 个写死的教学步骤，任何输入输出相同 | 警告：`unused parameter 'facelets'` |
| **YOLO-OBB 视觉识别** | `native_cube_pipeline.cpp:124` | `process_camera_frame` **完全不读入参 `buffer` 一个字节**；四角写死为画面中心正方形；9 个色块全部写死 `DetectedColor::WHITE` | 警告：`unused parameter 'buffer' / 'bytesPerRow' / 'format'` |
| **步进校验 / 自动跳步** | `step_validation_engine.hpp:45` | `bool matchesNextState = true;` **恒真** → 只要连续 5 帧就无条件推进，从不比对任何状态；成员 `currentCubeState` 从未被使用 | 警告：`unused parameter 'centerColor' / 'detectedStickers'` |
| **AR 空间投影** | `ar_engine.hpp` | 无 `solvePnP`、无 3D 投影、无曲面箭头，只是 4 角取平均 + 固定 ±40px 偏移；**且 `generateGuideOverlay` 在全项目无任何调用点（死代码）** | 全项目检索无调用 |

补充事实：
- `CMakeLists.txt` **只编译 `native_cube_pipeline.cpp` 一个源文件，只链接 `log`** —— 没有任何 OpenCV / TFLite / NCNN / 推理库，`find_library(log-lib log)` 甚至根本没被用到。所以"YOLOv8-OBB + warpPerspective + TFLite"只存在于文档里。
- `assets/models/` 下只有一份 `README.md`（写着"请把模型权重放这里"），**模型文件不存在**。
- `README.md` / `docs/*.md` 描述的 5 大核心特性（混合视觉感知、自由旋转连续识别、离线双引擎、真实相机 AR 叠加、实时拧法核验）**目前 0 项落地**。

---

## 五、P1：接线断裂与逻辑缺陷

### 1. 原生管线句柄从未初始化 —— 整条 FFI 管线静默失效（最隐蔽的坑）
`lib/core/native_bridge/rubik_ffi_bridge.dart`：
- `_initPipeline` 只做了 `lookup`（第 140 行），**全项目从未调用 `init_cube_pipeline`**；
- `_pipelineHandle` 除 `dispose()` 里置 null 外，没有任何赋值点 → **恒为 null**；
- 而所有带句柄的接口都有 `if (_pipelineHandle == null) return;` 前置判断 → `resetScanner` / `getScannedFacesCount` / `getScannedCubeString` / `setValidationSolution` / `stepNavigate` **全部静默 no-op，不报任何错**；
- `_processCameraFrame` 与 `_resultPtr` 从未被使用，也没有对外暴露方法。

### 2. 死代码 / 未接线组件
- `lib/core/vision/scanner_service.dart`（`ScannerService`）：定义了但**全项目无人引用**。
- `lib/ui/widgets/ar_overlay_painter.dart`（`ArOverlayPainter`）：只在 `scan_screen.dart`、`solver_screen.dart` 里被 `import`，**从未实例化** → 两处 `unused_import` 警告，且 `solver_screen` 里根本没有 AR 叠加层。

### 3. UI 是"演示壳"
- `ScanScreen` **没有摄像头**：只有一个「模拟扫描并记录第 N 面」按钮；点满 6 次后走 `_startSolve()`，而该函数**硬编码传入已还原的魔方** `CubeState.fromSingmaster("UUU…BBB")` → 求解返回 `SOLVED` → 步骤列表为空 → `isSolved` 为真 → 立刻显示"魔方已成功复原！"。
- `pubspec.yaml` 装了 `camera: ^0.10.5+9` 且插件注册代码已生成（`camera_android`），但 Dart 侧**没有任何 `CameraController` / 图像流代码**。
- `SolverScreen` 直接 `Center(StepGuideCard)`，无相机预览、无 AR、无实时反馈。

### 4. 校验器的漏判风险
`cube_model.hpp:123 / 139`：
```cpp
if (cc.cp[i] == -1) { ... }   // 编译器判定：恒为 false
if (ec.ep[i] == -1) { ... }   // 编译器判定：恒为 false
```
clang 明确给出 `-Wtautological-constant-out-of-range-compare`：`matchCorner` 返回的 `(Corner)-1` 与 `-1` 比较**永远不成立**，即"非法角块/棱块拼装"这条错误分支是**死代码**。同时 `validate()` 只做了 twist/flip/奇偶校验，**没有检查 `cp`/`ep` 是否为真正的排列（元素是否重复）**——例如同一角块在状态串里出现两次、另一块缺失，在多数情况下不会被早筛拦下，存在错误状态被判定为合法的可能。

### 5. 其他
- `solution_step.dart:10`：`final visualHint;` 漏了类型标注（隐式 `dynamic`），类型不安全。
- `cube_state.dart:7`：用 `assert` 做 54 长度校验 → **release 构建下 assert 被剥离**，非法状态静默通过。
- `solver_screen.dart:28`：`initState` 内同步调用 FFI 求解且无 `try/catch`。原生返回 `"ERROR: …"` 时 `solve()` 直接 `throw` → 首帧构建期异常崩溃；`_isLoading` 同步执行后立刻置 false，加载态分支形同虚设。
- `step_validation_engine.processDetectedFace` 里 `else` 分支（`consecutiveMatchFrames--`）因条件恒真而**永不可达**。
- `kociemba` 模式的 `maxDepth`（默认 22）未从 Dart 透传。

---

## 六、P2：工程化缺失

- **无 `analysis_options.yaml`** → `dev_dependencies` 里的 `flutter_lints: ^3.0.0` 完全没启用，等于没有任何 lint 门禁（已发现的 `unused_import`、隐式 `dynamic` 等本应被拦下）。
- **无 `test/` 目录** → `flutter_test` 零测试。求解器/校验器这类纯算法模块是最容易也最该单测的部分。
- **无 `.metadata`** → Flutter 项目元数据缺失，`flutter create .` 无法正确补齐/迁移平台工程（这也正是 `res/`、`debug/AndroidManifest.xml` 大面积缺失的根因）。
- **5 个声明了但未使用的依赖**：`camera`、`flutter_riverpod`、`google_fonts`、`vibration`、`audioplayers`（`cupertino_icons` 亦未使用）。其中 4 个是带原生插件的重依赖，白白增加包体与构建时间；`riverpod` 引入后却用 `ChangeNotifier` 手写状态管理，属于方案摇摆。
- **文档与实现严重脱节**：`docs/` 5 篇合计不足 40 行，基本是 README 要点的复述，缺少接口契约、状态机图、YOLO 模型 I/O 规范（输入尺寸、类别定义）、54 面块索引宏定义等真正需要沉淀的内容；`SETUP_AND_BUILD.md` 写"NDK 25+/Flutter 3.19+"，与实际（NDK 27.2 / Flutter 3.47.5）不符。

---

## 七、值得肯定、可直接复用的部分

不要推翻重写，这几块是**真材实料**，建议保留：

1. **`cube_model.hpp` 的 54→Cubie 映射**：`cornerFacelet[8][3]` 与 `edgeFacelet[12][2]` 逐项核对，与 Kociemba 官方实现完全一致（U=1..9 / R=10..18 / F=19..27 / D=28..36 / L=37..45 / B=46..54 的 0-based 映射无误）；角块/棱块朝向判定（`fac[1]==U||D → ori=1`、`c1==U||D → ori=0` 等）也符合标准算法。
2. **4 大守恒校验**：颜色计数（每色 9 块）、`sum(twist)%3==0`、`sum(flip)%2==0`、角/棱置换奇偶一致——逻辑正确（仅需补"排列去重"检查）。
3. **`computeDeltaE94`**：CIELAB ΔE94 色差公式实现规范（kL/kC/kH=1、K1=0.045、K2=0.015、dH 用 sqrt 且做非负保护）。
4. **`AdaptiveColorClassifier`**：6 色 LAB 锚点初值（白 95/0/3、黄 85/-8/85、蓝 35/10/-50 等）量级合理，EMA 平滑（0.8/0.2）设计正确。
5. **`MultiFrameAggregator`**：8 帧滑动窗口 + 逐格多数表决 + **≥6 票置信门限** + 集齐 6 面后按 `U R F D L B` 顺序拼装 54 字符串 + 每色 9 块复核 + 缺面返回 false——**这块写得相当扎实**，是全项目完成度最高的模块，可直接用于真实视觉管线。
6. `orderCorners`（角度排序后旋转到左上角起点）思路合理，可直接用于角点规范化。

---

## 八、建议推进路线（按性价比排序）

**第 1 步：让 App 能装能跑（工作量小、收益最大）**
1. 迁移 `settings.gradle` 到声明式 plugins block，补齐 `android/build.gradle` 的 `buildscript.classpath`（AGP + Kotlin）与插件版本；
2. 补齐 `android/app/src/main/res/`（styles/launch_background/mipmap 图标，可从 `flutter create` 的标准模板复制）；
3. 把 `ndkVersion` 改为本机已有的 `27.2.12479018`；
4. `gradle.properties` 补 `android.useAndroidX=true` + `org.gradle.jvmargs`；
5. 补 `src/debug/AndroidManifest.xml`、`src/profile/AndroidManifest.xml`；
6. Dart 侧在 `main()` 或 `SolverScreen.initState` 里真正调用 `initCubePipeline()` 并按相机内参初始化句柄，让 FFI 管线活过来（至少让 `getScannedFacesCount` 等不再静默 no-op）。

> 说明：第 1~5 项属于平台工程修复，**最省事的做法是备份 `lib/`、`android/app/src/main/cpp/` 后跑一次 `flutter create --platforms=android .` 用官方模板覆盖平台目录**，再把 cpp/ 与 `build.gradle` 中的 `externalNativeBuild` 段贴回去。

**第 2 步：打通"真求解"（无外部依赖，可完全离线，性价比最高）**
- 路径建议：**先做手动涂色校准 → 真求解**。`ManualEditScreen` + `Cube2DNet` 已经是可用的输入界面，只差一个真求解器。
- 求解器选型（按成本从低到高）：
  - ① **分层/CFOP 求解器**（自己写约 800~1200 行，保证有解，步数多但天然适配你已规划的"教学"路线，`CFOPStage` 枚举可直接复用）；
  - ② 移植 **min2phase**（Kociemba 两阶段，公开 C++ 实现约 2k 行，含 pruning table）——想真做"最少步"就选它；
  - ③ 自研 Kociemba 两阶段需实现坐标（twist/flip/slice/相位置换）与 pruning table，约 1.5k~3k 行，**不建议在项目早期做**。
- 顺手把 `cube_model.hpp` 的两个恒假比较修掉（改为 `matchCorner` 返回 `int`，或 `if (cols.empty())` 之类），并给 `validate` 补排列去重。

**第 3 步：真视觉（可分两级，不必一上来就 YOLO）**
- 3a：**先做"用户对准 + 居中方形 ROI"的取色方案**——用 `camera` 插件取帧 → 中心区域划分 3×3 → 采样取中位数 → 送进已有的 `computeDeltaE94` + `MultiFrameAggregator`。这条路线不改 C++ 架构，就能得到"可用的真扫描"，并把已经写好的色彩分类/聚合代码真正激活。
- 3b：之后再引入 YOLOv8-OBB（需补 TFLite/NCNN 依赖进 CMake、训练/导出模型、补 `assets/models/` 真模型），实现"自由旋转连续识别"。同时把 `process_camera_frame` 的 `buffer/bytesPerRow/format` 真正用起来（含 NV21/YUV420 转换与 `warpPerspective`）。

**第 4 步：AR 与自动跳步（最后做）**
- 补 `solvePnP`（需相机内参标定）、把 `AREngine` 接进 `SolverScreen` 叠加层；
- 把 `StepValidationEngine` 的 `matchesNextState` 换成"用当前识别出的 54 态与"执行完第 k 步后的期望态"做比对（这需要一个真正的走子引擎 `applyMove(state, move)`，和求解器共用同一套 cubie 表示）。

**工程化（可并行）**：补 `analysis_options.yaml`、`test/`（优先给验证器/求解器写单测）、`.metadata`；删掉 5 个未使用依赖（或明确保留理由）。

---

## 九、检查局限（需要说明）

1. **Dart 静态分析未能执行**：本机 `flutter analyze` 与 `dart analyze` 均在启动语言服务器时报
   `CreateFile failed 231（所有的管道实例都在使用中）` / `ProcessException: … process_win.cc:744`。
   这是本机**系统级**问题（命名管道被第三方内核组件拦截/耗尽），与项目代码无关，重启或排查安全软件驱动后可恢复。
   因此第四节以外的 Dart 结论均来自**人工逐行评审**，可能存在个别未被发现的编译级问题（已人工核对的重点嫌疑项：`solution_step.dart` 的隐式 `dynamic`、两处 `unused_import`）。
2. **Gradle 未能实际执行构建**（本机 Git Bash PATH 损坏 + 上述管道问题），构建阻断项是基于**配置文件与 Flutter SDK 源码的静态比对**得出的确定性结论（例如 `app_plugin_loader.gradle` 抛异常、`res/` 目录不存在、插件版本无来源，这三条无需运行即可确认必然失败）。
3. C++ 侧已通过真实编译校验（clang++ syntax-only），结论确凿。

---

# 十、第 1 步修复进展（2026-09-24）

目标：让 APK 能装能跑 + 接通原生 FFI 管线。

## 10.1 已修复：4 处构建阻断全部消除，并用真实构建验证

修复原则：**以本机 Flutter 3.47.5 自带模板为基准**，用 `flutter create --no-pub` 生成一份对照工程，逐文件比对本项目的 Android 目录后按官方内容重建，避免凭记忆拼版本号。

| 原阻断项 | 修复方式 | 实测验证结果 |
|---|---|---|
| `settings.gradle` 使用已被删除的 `app_plugin_loader.gradle`（该文件在本机 SDK 里第一件事就是 `throw`） | 删除旧 Groovy 文件，新建 `android/settings.gradle.kts`：官方声明式插件加载（`pluginManagement { includeBuild("<flutter sdk>/packages/flutter_tools/gradle") }` + `plugins { dev.flutter.flutter-plugin-loader 1.0.0 / com.android.application 9.1.0 / org.jetbrains.kotlin.android 2.4.0 }`） | Gradle 9.3.1 下配置阶段通过；Flutter Gradle 插件从源码编译成功（`:gradle:jar`） |
| `com.android.application` / `kotlin-android` / `dev.flutter.flutter-gradle-plugin` 三个插件无版本来源（无 `buildscript`、无 `pluginManagement`） | 版本改由 `settings.gradle.kts` 的 `plugins` 块声明；`android/build.gradle.kts` 按官方模板重建（仅额外加仓库镜像） | `> Configure project :app` 无报错；`:audioplayers_android` 等插件工程正常配置 |
| `res/` 目录整体不存在，而 Manifest 引用 `@mipmap/ic_launcher`、`@style/LaunchTheme`、`@style/NormalTheme` | 从官方模板生成物复制完整 `res/`：`values/styles.xml`、`values-night/styles.xml`、`drawable/` 与 `drawable-v21/launch_background.xml`、`mipmap-{m,h,xh,xxh,xxxh}dpi/ic_launcher.png`；同时补 `src/debug/AndroidManifest.xml`、`src/profile/AndroidManifest.xml` | 所有被引用的资源均已有对应文件 |
| `ndkVersion "25.1.8937393"` 本机未安装（只有 `27.2.12479018`） | 固定为已安装的 `27.2.12479018`，并在 `app/build.gradle.kts` 留注释说明取舍 | **`:app:buildCMakeDebug` → BUILD SUCCESSFUL（47s），arm64-v8a / armeabi-v7a / x86_64 三个 ABI 全部产出 `librubik_core.so`** |
| 缺 `android.useAndroidX=true` | `gradle.properties` 按官方模板重建（含 `useAndroidX` 与 `jvmargs`），保留原有 `builtInKotlin` / `newDsl` 标记 | 配置阶段通过 |

### 关键修复：dl.google.com 直连失败的真正原因

现象：Gradle 依赖解析需要 `dl.google.com`（AGP、androidx），但 `curl` 测出 **IPv4 可达（200）、IPv6 不可达（000）**，而 JVM 默认优先 IPv6 → 连接挂死。这正是原项目当初改用阿里云镜像的原因。

处理：在 `gradle.properties` 的 `org.gradle.jvmargs` 追加 `-Djava.net.preferIPv4Stack=true`（**项目内**解决，不改动全局 Gradle 配置），同时保留阿里云镜像作为第一优先仓库（本机直连可用且更快），Google / Maven Central / Plugin Portal 作为兜底。

另：`gradle-wrapper.properties` 升级到 Gradle 9.3.1（`mirrors.cloud.tencent.com` 已验证 200；官方 `services.gradle.org` 直连超时）。注意此前 `~/.gradle/wrapper/dists` 里那份 `gradle-9.3.1-all` 是**中断的残包**（只有 `.part`），本次已重新完整下载。

## 10.2 已完成的代码修复

1. **FFI 管线真正接通**（`lib/core/native_bridge/rubik_ffi_bridge.dart` 重写）
   - 新增 `initPipeline()` 并在 `main()` 启动时调用 → `_pipelineHandle` 不再恒为 `null`，原先 6 个静默 no-op 的接口（`resetScanner` / `getScannedFacesCount` / `getScannedCubeString` / `processFrame` / `setValidationSolution` / `stepNavigate`）全部激活。
   - 新增 `isLoaded` / `loadError` / `isPipelineInitialized` / `pipelineError`，库缺失时不再崩溃而是可观测。
   - 新增 `processFrame()`（含缓冲区长度校验）与 `FaceDetection` 结果对象，为后续接摄像头留好接缝。
2. **新增原生引擎自检横幅**（`lib/ui/widgets/native_engine_status.dart`，已挂到首页）：显示"原生引擎就绪 / 异常"，点开可看 4 项自检明细（库加载、管线句柄、`validate()`、`solve()`）。这是在真机上直接验证 FFI 链路的手段。
3. **清理死代码与隐患**
   - `ScannerService` 从"定义了但零引用"改为原生管线的真实封装（新增 `isEngineReady` / `engineError` / `processFrame` / `syncFromNative`）。
   - 删除 `scan_screen.dart`、`solver_screen.dart` 中未使用的 `ar_overlay_painter` 导入（消除 `unused_import`）。
   - `solution_step.dart`：`final visualHint;` 补上 `String` 类型标注（原为隐式 `dynamic`）。
   - `SolverScreen.initState`：同步 FFI 求解加 `try/catch`，求解失败展示错误页，不再首帧崩溃。
4. **补齐工程化文件**：`.metadata`（Flutter 项目元数据，此前缺失正是平台工程大面积不全的根因）、`analysis_options.yaml`（`flutter_lints` 由此才真正生效）。

## 10.3 仍被阻塞：本机 Dart 环境缺陷（与项目无关）

`flutter build` 的 Gradle 部分已全程通过，最终停在这里：

```
> Task :app:compileFlutterBuildDebug FAILED
CreateFile failed 231 (所有的管道范例都在使用中。)
Target build_hooks failed: ProcessException ... (at ../../runtime/bin/process_win.cc:744)
Target kernel_snapshot_program failed: ProcessException ... (at ../../runtime/bin/process_win.cc:744)
```

**最小复现**（用 SDK 自带 dart 直接跑，不涉及本项目）：

```dart
Process.runSync('cmd.exe', ['/c', 'echo hi']);   // FAIL: ERROR_PIPE_BUSY (231)
Process.start('cmd.exe', ['/c', 'echo started']); // FAIL: ERROR_PIPE_BUSY (231)
```

同步与异步两条路径**都失败** → **Dart 在本机无法启动任何子进程**，`flutter assemble` 因此无法调用 Dart 编译器（`frontend_server_aot.dart.snapshot`），任何 Flutter 项目在本环境都无法完成构建。

**已定位责任组件**（`fltmc filters` / `fltmc instances` + 驱动文件核对）：

| 组件 | 现象 | 判定 |
|---|---|---|
| `ahflt`（微软电脑管家） | 过滤器已加载 **7 个实例**、高度 385250.1、状态位 `0x04`（异常，正常为 `0x07`）；但 `System32\drivers\ahflt.sys` **文件已不存在**，`C:\Program Files\Microsoft PC Manager` 也已删除 | **幽灵驱动**：卸载残留，重启前持续挂在 `\Device\NamedPipe` 上 |
| `sysdiag`（火绒） | 驱动已加载 8 个实例（高度 324600）、`sysdiag.sys` 存在（2026-09-21）；`HipsTray` 在跑，但**无 `HipsDaemon` 进程、`HRWSCCtrl` 服务为 Stopped**，`C:\Program Files\Huorong` 不存在 | **半残状态**：内核驱动在跑、用户态守护进程缺失 |
| `WdFilter` / `UCPD` | 状态位 `0x07` / `0x0f`，正常 | Windows 自带，非责任方 |

同时排除：**不是管道泄漏**（`\\.\pipe\` 下无任何残留 `dart_*` 管道）、**不是残留进程**（无 dart / dartaotruntime 进程）。

### 重启后的操作

```powershell
cd C:\project\Rubik-Cube
flutter build apk --debug      # 或 flutter run
```

预期可产出 `app-debug.apk` —— 构建侧阻塞已全部消除，只剩 Dart 编译这一步。

若重启后仍报 231，按此顺序排查：修复或退出火绒（消除半残状态）→ 清理微软电脑管家残留（`fltmc unload ahflt`，需管理员）→ 干净启动定位。

## 10.4 回滚方式

原 6 个配置文件已备份至 `.workbuddy/backup/`：`settings.gradle`、`build.gradle`、`app-build.gradle`、`gradle.properties`、`gradle-wrapper.properties`、`AndroidManifest.xml`。

## 10.5 尚未处理（属于后续步骤）

- `camera` / `flutter_riverpod` / `google_fonts` / `vibration` / `audioplayers` 5 个依赖仍未被使用：**保留**是有意的（`camera` 属第 3 步必需），但会拉长首次构建时间并引入额外的 Dart build hook。
- NDK 建议后续升到 `28.2.13676358`（Flutter 模板默认值）：本次固定 27.2 是为了不额外下载约 1GB，且已实测可用。届时应把 `ndkVersion` 改回 `flutter.ndkVersion`。
- `ScanScreen` 仍是"模拟扫描 + 硬编码已还原魔方"的演示流程；`ScannerService` 已可用但尚无 UI 消费方——两者都留待第 3 步（真视觉）时一并改造。

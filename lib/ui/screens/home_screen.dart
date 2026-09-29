import 'package:flutter/material.dart';
import '../../models/cube_state.dart';
import '../../models/solution_step.dart';
import '../widgets/native_engine_status.dart';
import 'scan_screen.dart';
import 'manual_edit_screen.dart';
import 'cube_simulator_screen.dart';
import 'solver_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  SolveMode _selectedMode = SolveMode.kociemba;

  void _randomScrambleAndSolve() {
    final res = CubeState.generateScramble(moveCount: 22);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已生成随机打乱: ${res.scramble}'),
        duration: const Duration(seconds: 2),
        backgroundColor: const Color(0xFF1E1E2C),
      ),
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SolverScreen(
          initialState: res.state,
          mode: _selectedMode,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF12121E),
      appBar: AppBar(
        title: const Text('Rubik AR 还原助手'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3F51B5), Color(0xFF00E676)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF00E676).withValues(alpha: 0.3),
                        blurRadius: 16,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: const Icon(Icons.view_in_ar_rounded, size: 50, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'AI 实时魔方识别与还原',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  'YOLO-OBB 姿态检测 · 自由连续扫描 · 离线双求解 · 3D 虚拟模拟',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
              const SizedBox(height: 20),

              // Mode selection
              Material(
                color: const Color(0xFF1E1E2C),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    children: [
                      RadioListTile<SolveMode>(
                        value: SolveMode.kociemba,
                        groupValue: _selectedMode,
                        activeColor: const Color(0xFF00E676),
                        title: const Text('最少步模式 (Kociemba 两阶段)', style: TextStyle(color: Colors.white, fontSize: 14)),
                        subtitle: const Text('约 20 步还原，速度最快', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        onChanged: (val) => setState(() => _selectedMode = val!),
                      ),
                      const Divider(color: Colors.white10, height: 1),
                      RadioListTile<SolveMode>(
                        value: SolveMode.cfop,
                        groupValue: _selectedMode,
                        activeColor: const Color(0xFF00E676),
                        title: const Text('教学模式 (CFOP 初学者层先法)', style: TextStyle(color: Colors.white, fontSize: 14)),
                        subtitle: const Text('Cross → F2L → OLL → PLL 分阶段教学', style: TextStyle(color: Colors.white54, fontSize: 11)),
                        onChanged: (val) => setState(() => _selectedMode = val!),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Button 1: Camera Free Scan
              ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('摄像头自由扫描 (推荐)', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ScanScreen(mode: _selectedMode)));
                },
              ),

              const SizedBox(height: 10),

              // Button 2: 3D Virtual Cube Simulator
              ElevatedButton.icon(
                icon: const Icon(Icons.threed_rotation_rounded),
                label: const Text('3D 虚拟魔方 (自由模拟 / 练习)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF28283E),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Color(0xFF3F51B5), width: 1.2),
                  ),
                ),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => CubeSimulatorScreen(mode: _selectedMode)));
                },
              ),

              const SizedBox(height: 10),

              // Button Row: Random Scramble & Solve, and Manual Edit
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.shuffle_rounded, size: 18),
                      label: const Text('随机打乱求解', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: _randomScrambleAndSolve,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: const Text('手动涂色校准', style: TextStyle(fontSize: 13)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => ManualEditScreen(mode: _selectedMode)));
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 8),
              const NativeEngineStatusBanner(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

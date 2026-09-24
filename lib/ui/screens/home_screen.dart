import 'package:flutter/material.dart';
import '../../models/solution_step.dart';
import '../widgets/native_engine_status.dart';
import 'scan_screen.dart';
import 'manual_edit_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  SolveMode _selectedMode = SolveMode.kociemba;

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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF3F51B5), Color(0xFF00E676)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Icon(Icons.view_in_ar_rounded, size: 56, color: Colors.white),
                ),
              ),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'AI 实时魔方识别与还原',
                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'YOLO-OBB 姿态检测 · 自由连续扫描 · 离线双求解 · AR 实时校验',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2C),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white12),
                ),
                child: Column(
                  children: [
                    RadioListTile<SolveMode>(
                      value: SolveMode.kociemba,
                      groupValue: _selectedMode,
                      activeColor: const Color(0xFF00E676),
                      title: const Text('最少步模式 (Kociemba 两阶段)', style: TextStyle(color: Colors.white)),
                      subtitle: const Text('约 20 步还原，速度最快', style: TextStyle(color: Colors.white54, fontSize: 11)),
                      onChanged: (val) => setState(() => _selectedMode = val!),
                    ),
                    RadioListTile<SolveMode>(
                      value: SolveMode.cfop,
                      groupValue: _selectedMode,
                      activeColor: const Color(0xFF00E676),
                      title: const Text('教学模式 (CFOP 初学者层先法)', style: TextStyle(color: Colors.white)),
                      subtitle: const Text('Cross → F2L → OLL → PLL 分阶段教学', style: TextStyle(color: Colors.white54, fontSize: 11)),
                      onChanged: (val) => setState(() => _selectedMode = val!),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.camera_alt_rounded),
                label: const Text('摄像头自由扫面 (推荐)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00E676),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ScanScreen(mode: _selectedMode)));
                },
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_note_rounded),
                label: const Text('手动涂色校准'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ManualEditScreen(mode: _selectedMode)));
                },
              ),
              const SizedBox(height: 4),
              const NativeEngineStatusBanner(),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ChallengeRecord {
  final String id;
  final int timeMs;
  final int moves;
  final double tps;
  final DateTime date;
  final String scramble;

  ChallengeRecord({
    required this.id,
    required this.timeMs,
    required this.moves,
    required this.tps,
    required this.date,
    required this.scramble,
  });

  String get formattedTime {
    final totalSeconds = timeMs / 1000.0;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    if (minutes > 0) {
      return '${minutes.toString().padLeft(2, '0')}:${seconds.toStringAsFixed(2).padLeft(5, '0')}';
    }
    return seconds.toStringAsFixed(2);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'timeMs': timeMs,
        'moves': moves,
        'tps': tps,
        'date': date.toIso8601String(),
        'scramble': scramble,
      };

  factory ChallengeRecord.fromJson(Map<String, dynamic> json) => ChallengeRecord(
        id: json['id'] as String? ?? '',
        timeMs: json['timeMs'] as int? ?? 0,
        moves: json['moves'] as int? ?? 0,
        tps: (json['tps'] as num?)?.toDouble() ?? 0.0,
        date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
        scramble: json['scramble'] as String? ?? '',
      );
}

class ChallengeRecordService {
  static const String _keyHistory = 'rubik_challenge_history';
  static const String _keyPB = 'rubik_challenge_pb_ms';

  static final ChallengeRecordService instance = ChallengeRecordService._();
  ChallengeRecordService._();

  Future<int?> getPersonalBestTimeMs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_keyPB);
  }

  Future<List<ChallengeRecord>> getHistory({int limit = 30}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_keyHistory) ?? [];
    final list = <ChallengeRecord>[];
    for (final item in raw) {
      try {
        final map = jsonDecode(item) as Map<String, dynamic>;
        list.add(ChallengeRecord.fromJson(map));
      } catch (_) {}
    }
    // Sort by best time (ascending)
    list.sort((a, b) => a.timeMs.compareTo(b.timeMs));
    if (list.length > limit) {
      return list.sublist(0, limit);
    }
    return list;
  }

  /// Saves the record and returns true if this record is a new Personal Best!
  Future<bool> saveRecord(ChallengeRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final currentPB = prefs.getInt(_keyPB);
    final isNewPB = currentPB == null || record.timeMs < currentPB;

    if (isNewPB) {
      await prefs.setInt(_keyPB, record.timeMs);
    }

    final raw = prefs.getStringList(_keyHistory) ?? [];
    raw.add(jsonEncode(record.toJson()));
    // Keep max 50 records
    if (raw.length > 50) {
      raw.removeAt(0);
    }
    await prefs.setStringList(_keyHistory, raw);
    return isNewPB;
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHistory);
    await prefs.remove(_keyPB);
  }
}

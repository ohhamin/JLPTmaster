import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_service.dart';
import 'session_store.dart';

class LevelingStatus {
  const LevelingStatus({
    required this.level,
    required this.experience,
    required this.xpRequired,
    required this.totalExperience,
    required this.dailyAttendanceXp,
    required this.roundCompletionXp,
    required this.currentAttendanceStreak,
    required this.maxAttendanceStreak,
    this.lastAttendanceDate,
  });

  final int level;
  final int experience;
  final int xpRequired;
  final int totalExperience;
  final int dailyAttendanceXp;
  final int roundCompletionXp;
  final int currentAttendanceStreak;
  final int maxAttendanceStreak;
  final String? lastAttendanceDate;

  double get progress => xpRequired <= 0 ? 0 : experience / xpRequired;

  factory LevelingStatus.fromJson(Map<String, dynamic> json) => LevelingStatus(
        level: (json['level'] as num?)?.toInt() ?? 1,
        experience: (json['experience'] as num?)?.toInt() ?? 0,
        xpRequired: (json['xp_required'] as num?)?.toInt() ?? 30,
        totalExperience: (json['total_experience'] as num?)?.toInt() ?? 0,
        dailyAttendanceXp: (json['daily_attendance_xp'] as num?)?.toInt() ?? 5,
        roundCompletionXp: (json['round_completion_xp'] as num?)?.toInt() ?? 30,
        currentAttendanceStreak:
            (json['current_attendance_streak'] as num?)?.toInt() ?? 0,
        maxAttendanceStreak:
            (json['max_attendance_streak'] as num?)?.toInt() ?? 0,
        lastAttendanceDate: json['last_attendance_date']?.toString(),
      );
}

class ExperienceReward extends LevelingStatus {
  const ExperienceReward({
    required super.level,
    required super.experience,
    required super.xpRequired,
    required super.totalExperience,
    required super.dailyAttendanceXp,
    required super.roundCompletionXp,
    required super.currentAttendanceStreak,
    required super.maxAttendanceStreak,
    required this.xpGained,
    required this.previousLevel,
    required this.levelsGained,
    required this.leveledUp,
    this.attendanceAwarded = false,
    super.lastAttendanceDate,
  });

  final int xpGained;
  final int previousLevel;
  final int levelsGained;
  final bool leveledUp;
  final bool attendanceAwarded;

  factory ExperienceReward.fromJson(Map<String, dynamic> json) => ExperienceReward(
        level: (json['level'] as num?)?.toInt() ?? 1,
        experience: (json['experience'] as num?)?.toInt() ?? 0,
        xpRequired: (json['xp_required'] as num?)?.toInt() ?? 30,
        totalExperience: (json['total_experience'] as num?)?.toInt() ?? 0,
        dailyAttendanceXp: (json['daily_attendance_xp'] as num?)?.toInt() ?? 5,
        roundCompletionXp: (json['round_completion_xp'] as num?)?.toInt() ?? 30,
        currentAttendanceStreak:
            (json['current_attendance_streak'] as num?)?.toInt() ?? 0,
        maxAttendanceStreak:
            (json['max_attendance_streak'] as num?)?.toInt() ?? 0,
        lastAttendanceDate: json['last_attendance_date']?.toString(),
        xpGained: (json['xp_gained'] as num?)?.toInt() ?? 0,
        previousLevel: (json['previous_level'] as num?)?.toInt() ?? 1,
        levelsGained: (json['levels_gained'] as num?)?.toInt() ?? 0,
        leveledUp: json['leveled_up'] == true,
        attendanceAwarded: json['attendance_awarded'] == true,
      );
}

class GamificationService {
  GamificationService._();

  static final GamificationService instance = GamificationService._();
  final http.Client _client = http.Client();

  Future<LevelingStatus> fetchStatus() async {
    final response = await _client
        .get(
          Uri.parse('${ApiService.baseUrl}/api/account/leveling'),
          headers: SessionStore.headers(),
        )
        .timeout(const Duration(seconds: 8));
    _ensureOk(response, '레벨 정보를 불러오지 못했습니다.');
    return LevelingStatus.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<ExperienceReward> claimDailyAttendance() async {
    final response = await _client
        .post(
          Uri.parse('${ApiService.baseUrl}/api/account/attendance'),
          headers: SessionStore.headers(),
        )
        .timeout(const Duration(seconds: 8));
    _ensureOk(response, '출석 경험치를 처리하지 못했습니다.');
    return ExperienceReward.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  Future<ExperienceReward> awardRound({
    required String level,
    required int chapter,
    required int roundCount,
  }) async {
    final response = await _client
        .post(
          Uri.parse('${ApiService.baseUrl}/api/account/round-reward'),
          headers: SessionStore.headers(json: true),
          body: jsonEncode({
            'level': level,
            'chapter': chapter,
            'round_count': roundCount,
          }),
        )
        .timeout(const Duration(seconds: 8));
    _ensureOk(response, '회독 경험치를 처리하지 못했습니다.');
    return ExperienceReward.fromJson(
      jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
    );
  }

  static void _ensureOk(http.Response response, String message) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    String? detail;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) {
        detail = decoded['detail']?.toString();
      }
    } catch (_) {}
    throw Exception('$message (${response.statusCode})${detail == null ? '' : ' $detail'}');
  }
}

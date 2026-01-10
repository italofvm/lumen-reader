class HabitState {
  final int dailyGoalMinutes;
  final int todaySeconds;
  final int currentStreak;
  final int bestStreak;
  final DateTime? lastReadDay;

  final bool sessionRunning;
  final DateTime? sessionStartedAt;
  final int sessionElapsedSeconds;
  final int sessionTargetSeconds;

  const HabitState({
    required this.dailyGoalMinutes,
    required this.todaySeconds,
    required this.currentStreak,
    required this.bestStreak,
    required this.lastReadDay,
    required this.sessionRunning,
    required this.sessionStartedAt,
    required this.sessionElapsedSeconds,
    required this.sessionTargetSeconds,
  });

  HabitState copyWith({
    int? dailyGoalMinutes,
    int? todaySeconds,
    int? currentStreak,
    int? bestStreak,
    DateTime? lastReadDay,
    bool lastReadDayIsSet = false,
    bool? sessionRunning,
    DateTime? sessionStartedAt,
    bool sessionStartedAtIsSet = false,
    int? sessionElapsedSeconds,
    int? sessionTargetSeconds,
  }) {
    return HabitState(
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      todaySeconds: todaySeconds ?? this.todaySeconds,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      lastReadDay: lastReadDayIsSet ? lastReadDay : this.lastReadDay,
      sessionRunning: sessionRunning ?? this.sessionRunning,
      sessionStartedAt:
          sessionStartedAtIsSet ? sessionStartedAt : this.sessionStartedAt,
      sessionElapsedSeconds: sessionElapsedSeconds ?? this.sessionElapsedSeconds,
      sessionTargetSeconds: sessionTargetSeconds ?? this.sessionTargetSeconds,
    );
  }

  static HabitState initial() {
    return const HabitState(
      dailyGoalMinutes: 20,
      todaySeconds: 0,
      currentStreak: 0,
      bestStreak: 0,
      lastReadDay: null,
      sessionRunning: false,
      sessionStartedAt: null,
      sessionElapsedSeconds: 0,
      sessionTargetSeconds: 20 * 60,
    );
  }
}

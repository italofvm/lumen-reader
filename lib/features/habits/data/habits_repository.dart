import 'package:hive_flutter/hive_flutter.dart';

class HabitsRepository {
  static const String _boxName = 'habits';

  static const String _keyDailyGoalMinutes = 'daily_goal_minutes';
  static const String _keyTodayDayKey = 'today_day_key';
  static const String _keyTodaySeconds = 'today_seconds';
  static const String _keyCurrentStreak = 'current_streak';
  static const String _keyBestStreak = 'best_streak';
  static const String _keyLastReadDayKey = 'last_read_day_key';

  Future<Box> _open() => Hive.openBox(_boxName);

  Future<int> getDailyGoalMinutes() async {
    final box = await _open();
    return (box.get(_keyDailyGoalMinutes, defaultValue: 20) as int).clamp(1, 600);
  }

  Future<void> setDailyGoalMinutes(int minutes) async {
    final box = await _open();
    await box.put(_keyDailyGoalMinutes, minutes.clamp(1, 600));
  }

  Future<String?> getTodayDayKey() async {
    final box = await _open();
    return box.get(_keyTodayDayKey) as String?;
  }

  Future<void> setTodayDayKey(String dayKey) async {
    final box = await _open();
    await box.put(_keyTodayDayKey, dayKey);
  }

  Future<int> getTodaySeconds() async {
    final box = await _open();
    return (box.get(_keyTodaySeconds, defaultValue: 0) as int).clamp(0, 60 * 60 * 24);
  }

  Future<void> setTodaySeconds(int seconds) async {
    final box = await _open();
    await box.put(_keyTodaySeconds, seconds.clamp(0, 60 * 60 * 24));
  }

  Future<int> getCurrentStreak() async {
    final box = await _open();
    return (box.get(_keyCurrentStreak, defaultValue: 0) as int).clamp(0, 9999);
  }

  Future<void> setCurrentStreak(int value) async {
    final box = await _open();
    await box.put(_keyCurrentStreak, value.clamp(0, 9999));
  }

  Future<int> getBestStreak() async {
    final box = await _open();
    return (box.get(_keyBestStreak, defaultValue: 0) as int).clamp(0, 9999);
  }

  Future<void> setBestStreak(int value) async {
    final box = await _open();
    await box.put(_keyBestStreak, value.clamp(0, 9999));
  }

  Future<String?> getLastReadDayKey() async {
    final box = await _open();
    return box.get(_keyLastReadDayKey) as String?;
  }

  Future<void> setLastReadDayKey(String? dayKey) async {
    final box = await _open();
    if (dayKey == null) {
      await box.delete(_keyLastReadDayKey);
      return;
    }
    await box.put(_keyLastReadDayKey, dayKey);
  }

  Future<void> resetForNewDay({required String newDayKey}) async {
    final box = await _open();
    await box.put(_keyTodayDayKey, newDayKey);
    await box.put(_keyTodaySeconds, 0);
  }
}

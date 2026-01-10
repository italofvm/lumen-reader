import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen_reader/features/habits/data/habits_repository.dart';
import 'package:lumen_reader/features/habits/domain/entities/habit_state.dart';

final habitsRepositoryProvider = Provider<HabitsRepository>((ref) {
  return HabitsRepository();
});

final habitsProvider = StateNotifierProvider<HabitsNotifier, HabitState>((ref) {
  final repo = ref.watch(habitsRepositoryProvider);
  return HabitsNotifier(repo)..init();
});

class HabitsNotifier extends StateNotifier<HabitState> {
  final HabitsRepository _repo;
  Timer? _timer;

  HabitsNotifier(this._repo) : super(HabitState.initial());

  String _dayKey(DateTime dt) {
    final d = DateTime(dt.year, dt.month, dt.day);
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  DateTime? _parseDayKey(String? key) {
    if (key == null || key.trim().isEmpty) return null;
    final parts = key.split('-');
    if (parts.length != 3) return null;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return null;
    return DateTime(y, m, d);
  }

  Future<void> init() async {
    final dailyGoalMinutes = await _repo.getDailyGoalMinutes();

    final todayKeyNow = _dayKey(DateTime.now());
    final savedTodayKey = await _repo.getTodayDayKey();
    if (savedTodayKey != todayKeyNow) {
      await _repo.resetForNewDay(newDayKey: todayKeyNow);
    }

    final todaySeconds = await _repo.getTodaySeconds();
    final currentStreak = await _repo.getCurrentStreak();
    final bestStreak = await _repo.getBestStreak();
    final lastRead = _parseDayKey(await _repo.getLastReadDayKey());

    state = state.copyWith(
      dailyGoalMinutes: dailyGoalMinutes,
      todaySeconds: todaySeconds,
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      lastReadDay: lastRead,
      lastReadDayIsSet: true,
      sessionTargetSeconds: dailyGoalMinutes * 60,
    );
  }

  Future<void> setDailyGoalMinutes(int minutes) async {
    await _repo.setDailyGoalMinutes(minutes);
    state = state.copyWith(
      dailyGoalMinutes: minutes,
      sessionTargetSeconds: minutes * 60,
    );
  }

  Future<void> startSession({int? targetMinutes}) async {
    if (state.sessionRunning) return;
    final targetSec = (targetMinutes ?? state.dailyGoalMinutes).clamp(1, 600) * 60;

    state = state.copyWith(
      sessionRunning: true,
      sessionStartedAt: DateTime.now(),
      sessionStartedAtIsSet: true,
      sessionElapsedSeconds: 0,
      sessionTargetSeconds: targetSec,
    );

    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!state.sessionRunning) return;
      final started = state.sessionStartedAt;
      if (started == null) return;
      final elapsed = DateTime.now().difference(started).inSeconds;
      state = state.copyWith(sessionElapsedSeconds: elapsed);
    });
  }

  Future<void> pauseSession() async {
    if (!state.sessionRunning) return;
    await _commitSessionSeconds(state.sessionElapsedSeconds);
    state = state.copyWith(
      sessionRunning: false,
      sessionStartedAt: null,
      sessionStartedAtIsSet: true,
      sessionElapsedSeconds: 0,
    );
    _timer?.cancel();
    _timer = null;
  }

  Future<void> finishSession() async {
    if (!state.sessionRunning) return;
    await _commitSessionSeconds(state.sessionElapsedSeconds);
    state = state.copyWith(
      sessionRunning: false,
      sessionStartedAt: null,
      sessionStartedAtIsSet: true,
      sessionElapsedSeconds: 0,
    );
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _commitSessionSeconds(int seconds) async {
    if (seconds <= 0) return;

    final now = DateTime.now();
    final todayKeyNow = _dayKey(now);
    final savedTodayKey = await _repo.getTodayDayKey();

    if (savedTodayKey != todayKeyNow) {
      await _repo.resetForNewDay(newDayKey: todayKeyNow);
      state = state.copyWith(todaySeconds: 0);
    }

    final prev = await _repo.getTodaySeconds();
    final next = prev + seconds;
    await _repo.setTodaySeconds(next);

    final hadReadingBefore = prev > 0;
    final isFirstReadingToday = !hadReadingBefore && next > 0;

    if (isFirstReadingToday) {
      await _updateStreakOnFirstReadOfDay(now);
    }

    state = state.copyWith(todaySeconds: next);
  }

  Future<void> _updateStreakOnFirstReadOfDay(DateTime now) async {
    final today = DateTime(now.year, now.month, now.day);
    final lastRead = state.lastReadDay;

    var currentStreak = await _repo.getCurrentStreak();
    var bestStreak = await _repo.getBestStreak();

    if (lastRead == null) {
      currentStreak = 1;
    } else {
      final last = DateTime(lastRead.year, lastRead.month, lastRead.day);
      final deltaDays = today.difference(last).inDays;
      if (deltaDays == 0) {
        // already counted
      } else if (deltaDays == 1) {
        currentStreak = currentStreak + 1;
      } else {
        currentStreak = 1;
      }
    }

    if (currentStreak > bestStreak) {
      bestStreak = currentStreak;
    }

    await _repo.setCurrentStreak(currentStreak);
    await _repo.setBestStreak(bestStreak);
    await _repo.setLastReadDayKey(_dayKey(today));

    state = state.copyWith(
      currentStreak: currentStreak,
      bestStreak: bestStreak,
      lastReadDay: today,
      lastReadDayIsSet: true,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

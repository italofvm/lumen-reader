import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen_reader/core/services/notifications/notifications_provider.dart';
import 'package:lumen_reader/features/habits/domain/providers/habits_providers.dart';
import 'package:lumen_reader/features/settings/domain/providers/settings_providers.dart';

class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  String _fmtTime(int seconds) {
    final m = (seconds ~/ 60).clamp(0, 9999);
    final s = (seconds % 60).clamp(0, 59);
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _fmtClock(int hour, int minute) {
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  Future<void> _toggleDailyReminder(
    BuildContext context,
    WidgetRef ref, {
    required bool enabled,
  }) async {
    final settingsNotifier = ref.read(readerSettingsProvider.notifier);
    final settings = ref.read(readerSettingsProvider);
    final notifications = ref.read(localNotificationServiceProvider);

    if (enabled) {
      final ok = await notifications.requestPermissionsIfNeeded();
      if (!ok) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Permissão de notificações negada. Ative nas configurações do sistema.',
              ),
            ),
          );
        }
        await settingsNotifier.setDailyReminderEnabled(false);
        return;
      }

      await settingsNotifier.setDailyReminderEnabled(true);
      await notifications.scheduleDailyReminder(
        hour: settings.dailyReminderHour,
        minute: settings.dailyReminderMinute,
      );
      return;
    }

    await settingsNotifier.setDailyReminderEnabled(false);
    await notifications.cancelDailyReminder();
  }

  Future<void> _pickReminderTime(BuildContext context, WidgetRef ref) async {
    final settingsNotifier = ref.read(readerSettingsProvider.notifier);
    final settings = ref.read(readerSettingsProvider);
    final notifications = ref.read(localNotificationServiceProvider);

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: settings.dailyReminderHour,
        minute: settings.dailyReminderMinute,
      ),
    );
    if (picked == null) return;

    await settingsNotifier.setDailyReminderTime(
      hour: picked.hour,
      minute: picked.minute,
    );

    final next = ref.read(readerSettingsProvider);
    if (next.dailyReminderEnabled) {
      await notifications.scheduleDailyReminder(
        hour: next.dailyReminderHour,
        minute: next.dailyReminderMinute,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(habitsProvider);
    final notifier = ref.read(habitsProvider.notifier);
    final settings = ref.watch(readerSettingsProvider);

    final cs = Theme.of(context).colorScheme;
    final goalSec = state.dailyGoalMinutes * 60;
    final progress = goalSec <= 0 ? 0.0 : (state.todaySeconds / goalSec).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hábito'),
        actions: [
          IconButton(
            tooltip: 'Ajustar meta diária',
            onPressed: () async {
              final controller = TextEditingController(text: state.dailyGoalMinutes.toString());
              final result = await showDialog<int>(
                context: context,
                builder: (ctx) {
                  return AlertDialog(
                    title: const Text('Meta diária (minutos)'),
                    content: TextField(
                      controller: controller,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        hintText: 'Ex: 20',
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancelar'),
                      ),
                      FilledButton(
                        onPressed: () {
                          final v = int.tryParse(controller.text.trim());
                          if (v == null) {
                            Navigator.of(ctx).pop();
                            return;
                          }
                          Navigator.of(ctx).pop(v);
                        },
                        child: const Text('Salvar'),
                      ),
                    ],
                  );
                },
              );
              controller.dispose();
              if (result != null) {
                await notifier.setDailyGoalMinutes(result);
              }
            },
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: cs.outlineVariant.withAlpha((0.35 * 255).round()),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Lembrete diário',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            settings.dailyReminderEnabled
                                ? 'Ativo — ${_fmtClock(settings.dailyReminderHour, settings.dailyReminderMinute)}'
                                : 'Desligado',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: cs.onSurface.withAlpha((0.75 * 255).round()),
                                ),
                          ),
                        ),
                        Switch(
                          value: settings.dailyReminderEnabled,
                          onChanged: (v) =>
                              _toggleDailyReminder(context, ref, enabled: v),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Horário do lembrete'),
                      subtitle: Text(
                        _fmtClock(
                          settings.dailyReminderHour,
                          settings.dailyReminderMinute,
                        ),
                      ),
                      enabled: settings.dailyReminderEnabled,
                      trailing: const Icon(Icons.schedule),
                      onTap: settings.dailyReminderEnabled
                          ? () => _pickReminderTime(context, ref)
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cs.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cs.outlineVariant.withAlpha((0.35 * 255).round())),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hoje',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 10,
                              backgroundColor: cs.surfaceContainerHighest,
                              valueColor: AlwaysStoppedAnimation(cs.primary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${(progress * 100).round()}%',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '${_fmtTime(state.todaySeconds)} de ${_fmtTime(goalSec)}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: cs.onSurface.withAlpha((0.75 * 255).round()),
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      title: 'Streak',
                      value: '${state.currentStreak}',
                      subtitle: 'Melhor: ${state.bestStreak}',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      title: 'Sessão',
                      value: state.sessionRunning ? _fmtTime(state.sessionElapsedSeconds) : '00:00',
                      subtitle: state.sessionRunning ? 'em andamento' : 'pronto',
                    ),
                  ),
                ],
              ),
              const Spacer(),
              FilledButton(
                onPressed: state.sessionRunning
                    ? () async {
                        await notifier.finishSession();
                      }
                    : () async {
                        await notifier.startSession();
                      },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                ),
                child: Text(state.sessionRunning ? 'Finalizar sessão' : 'Iniciar sessão'),
              ),
              const SizedBox(height: 10),
              if (state.sessionRunning)
                TextButton(
                  onPressed: () async {
                    await notifier.pauseSession();
                  },
                  child: const Text('Pausar'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;

  const _StatCard({
    required this.title,
    required this.value,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withAlpha((0.35 * 255).round())),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: cs.onSurface.withAlpha((0.7 * 255).round()),
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: cs.onSurface.withAlpha((0.65 * 255).round()),
                ),
          ),
        ],
      ),
    );
  }
}

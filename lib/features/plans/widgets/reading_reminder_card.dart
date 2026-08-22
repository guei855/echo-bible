import 'package:echo_bible/core/theme/app_colors.dart';
import 'package:echo_bible/features/plans/models/reading_reminder.dart';
import 'package:echo_bible/features/plans/services/reading_reminder_service.dart';
import 'package:flutter/material.dart';

class ReadingReminderCard extends StatefulWidget {
  const ReadingReminderCard({
    super.key,
    required this.planId,
    required this.planTitle,
    this.todayReading,
    this.repository,
  });

  final int planId;
  final String planTitle;
  final String? todayReading;
  final ReadingReminderRepository? repository;

  @override
  State<ReadingReminderCard> createState() => _ReadingReminderCardState();
}

class _ReadingReminderCardState extends State<ReadingReminderCard> {
  late final ReadingReminderRepository _repository =
      widget.repository ?? ReadingReminderService.repository;
  ReadingReminderPlanSettings? _settings;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ReadingReminderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.planId != widget.planId) _load();
  }

  Future<void> _load() async {
    final settings = await _repository.load(widget.planId);
    if (mounted) setState(() => _settings = settings);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final settings = _settings;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const CircleAvatar(
                backgroundColor: Color(0xFFE8EEFF),
                foregroundColor: AppColors.primary,
                child: Icon(Icons.notifications_active_outlined),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Rappel de lecture',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Suspendre ou réactiver tous les créneaux'),
                  ],
                ),
              ),
              Switch.adaptive(
                key: const Key('reading-reminders-master-switch'),
                value: settings?.enabled ?? false,
                onChanged: settings == null || _busy ? null : _togglePlan,
              ),
            ]),
            const SizedBox(height: 14),
            Text('Mes rappels',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    )),
            const SizedBox(height: 6),
            if (settings == null)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (settings.reminders.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'Ajoutez une heure pour recevoir un rappel de lecture.',
                  style: TextStyle(color: colors.onSurfaceVariant),
                ),
              )
            else
              for (final reminder in settings.reminders)
                _ReminderRow(
                  reminder: reminder,
                  planEnabled: settings.enabled,
                  busy: _busy,
                  onToggle: (enabled) => _toggleReminder(reminder, enabled),
                  onEdit: () => _chooseTime(existing: reminder),
                  onDelete: () => _remove(reminder),
                ),
            const SizedBox(height: 6),
            TextButton.icon(
              key: const Key('add-reading-reminder'),
              onPressed: settings == null || _busy ? null : _chooseTime,
              icon: const Icon(Icons.add_alarm_rounded),
              label: const Text('Ajouter un rappel'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _chooseTime({ReadingReminder? existing}) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: existing == null
          ? const TimeOfDay(hour: 7, minute: 0)
          : TimeOfDay(hour: existing.hour, minute: existing.minute),
    );
    if (selected == null) return;
    await _run(() async {
      if (existing == null) {
        await _repository.add(
          planId: widget.planId,
          hour: selected.hour,
          minute: selected.minute,
          planTitle: widget.planTitle,
          todayReading: widget.todayReading,
        );
      } else {
        await _repository.update(
          existing,
          hour: selected.hour,
          minute: selected.minute,
          planTitle: widget.planTitle,
          todayReading: widget.todayReading,
        );
      }
    });
  }

  Future<void> _togglePlan(bool enabled) async {
    await _run(() async {
      final accepted = await _repository.setPlanEnabled(
        widget.planId,
        enabled,
        planTitle: widget.planTitle,
        todayReading: widget.todayReading,
      );
      if (!accepted && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Autorisez les notifications pour activer les rappels.'),
        ));
      }
    });
  }

  Future<void> _toggleReminder(ReadingReminder reminder, bool enabled) {
    return _run(() => _repository.setReminderEnabled(
          reminder,
          enabled,
          planTitle: widget.planTitle,
          todayReading: widget.todayReading,
        ));
  }

  Future<void> _remove(ReadingReminder reminder) {
    return _run(() => _repository.remove(reminder));
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
      await _load();
    } on StateError catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _ReminderRow extends StatelessWidget {
  const _ReminderRow({
    required this.reminder,
    required this.planEnabled,
    required this.busy,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  final ReadingReminder reminder;
  final bool planEnabled;
  final bool busy;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => ListTile(
        key: Key('reading-reminder-${reminder.id}'),
        contentPadding: EdgeInsets.zero,
        minVerticalPadding: 0,
        leading: const Icon(Icons.schedule_rounded),
        title: Text(
          reminder.timeKey,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        onTap: busy ? null : onEdit,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch.adaptive(
              value: reminder.enabled,
              onChanged: busy ? null : onToggle,
            ),
            IconButton(
              tooltip: 'Supprimer ce rappel',
              onPressed: busy ? null : onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
        enabled: planEnabled,
      );
}

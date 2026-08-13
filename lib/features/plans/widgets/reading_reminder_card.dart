import 'package:echo_bible/core/theme/app_colors.dart';
import 'package:echo_bible/features/plans/services/reading_reminder_service.dart';
import 'package:flutter/material.dart';

class ReadingReminderCard extends StatefulWidget {
  const ReadingReminderCard({super.key});

  @override
  State<ReadingReminderCard> createState() => _ReadingReminderCardState();
}

class _ReadingReminderCardState extends State<ReadingReminderCard> {
  bool _enabled = false;
  TimeOfDay _time = const TimeOfDay(hour: 7, minute: 0);
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await ReadingReminderService.loadSettings();
    if (!mounted) return;
    setState(() {
      _enabled = settings.enabled;
      _time = TimeOfDay(hour: settings.hour, minute: settings.minute);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: .13),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notifications_active_outlined,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: InkWell(
              onTap: _loading ? null : _chooseTime,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Rappel de lecture',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _enabled
                        ? 'Chaque jour à ${_time.format(context)}'
                        : 'Choisissez l’heure du rappel quotidien',
                    style: TextStyle(
                      color: colors.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Switch.adaptive(
            value: _enabled,
            onChanged: _loading ? null : _toggle,
          ),
        ],
      ),
    );
  }

  Future<void> _toggle(bool enabled) async {
    if (!enabled) {
      await ReadingReminderService.disable();
      if (mounted) setState(() => _enabled = false);
      return;
    }
    final selected = await showTimePicker(context: context, initialTime: _time);
    if (selected == null) return;
    await _activate(selected);
  }

  Future<void> _chooseTime() async {
    final selected = await showTimePicker(context: context, initialTime: _time);
    if (selected == null) return;
    await _activate(selected);
  }

  Future<void> _activate(TimeOfDay selected) async {
    setState(() => _loading = true);
    final enabled = await ReadingReminderService.enable(
      hour: selected.hour,
      minute: selected.minute,
    );
    if (!mounted) return;
    setState(() {
      _time = selected;
      _enabled = enabled;
      _loading = false;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          enabled
              ? 'Rappel programmé chaque jour à ${selected.format(context)}.'
              : 'Autorisez les notifications pour activer le rappel.',
        ),
      ),
    );
  }
}

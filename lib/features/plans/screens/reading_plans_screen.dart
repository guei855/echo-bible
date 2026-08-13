import 'package:echo_bible/core/theme/app_colors.dart';
import 'package:echo_bible/features/plans/models/reading_plan.dart';
import 'package:echo_bible/features/plans/screens/create_plan_screen.dart';
import 'package:echo_bible/features/plans/services/reading_plan_service.dart';
import 'package:echo_bible/features/plans/widgets/reading_reminder_card.dart';
import 'package:flutter/material.dart';

class ReadingPlansScreen extends StatefulWidget {
  const ReadingPlansScreen({super.key});

  @override
  State<ReadingPlansScreen> createState() => _ReadingPlansScreenState();
}

class _ReadingPlansScreenState extends State<ReadingPlansScreen> {
  late Future<_PlansData> _data = _load();

  Future<_PlansData> _load() async => _PlansData(
        today: await ReadingPlanService.today(),
        personal: await ReadingPlanService.personalPlans(),
      );

  Future<void> _refresh() async {
    final result = await _load();
    if (!mounted) return;
    final data = Future.value(result);
    setState(() {
      _data = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes plans'),
        actions: [
          IconButton(
            tooltip: 'Créer un plan',
            onPressed: _create,
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: FutureBuilder<_PlansData>(
        future: _data,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            children: [
              const ReadingReminderCard(),
              const SizedBox(height: 20),
              Text(
                'Plan par défaut',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 10),
              _PlanCard(
                title: ReadingPlanService.defaultTitle,
                subtitle: 'Toute la Bible · synchronisé avec le calendrier',
                day: ReadingPlanService.calendarDay(DateTime.now()),
                duration: ReadingPlanService.defaultDuration,
                active: data.today.isDefault,
                readings: data.today.isDefault ? data.today.readings : const [],
                onActivate: () async {
                  await ReadingPlanService.activate(null);
                  _refresh();
                },
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Plans personnalisés',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: _create,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('Créer'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (data.personal.isEmpty)
                const _EmptyPersonalPlans()
              else
                for (final plan in data.personal) ...[
                  _PlanCard(
                    title: plan.title,
                    subtitle: 'Début : ${_formatDate(plan.startDate)}',
                    day: plan.dayAt(DateTime.now()),
                    duration: plan.duration,
                    active: plan.isActive,
                    readings: plan.isActive ? data.today.readings : const [],
                    onActivate: () async {
                      await ReadingPlanService.activate(plan.id);
                      _refresh();
                    },
                    onDelete: () => _delete(plan),
                  ),
                  const SizedBox(height: 12),
                ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _create() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreatePlanScreen()),
    );
    if (created == true) _refresh();
  }

  Future<void> _delete(PersonalReadingPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Supprimer ce plan ?'),
        content: Text('« ${plan.title} » sera supprimé définitivement.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ReadingPlanService.deletePersonalPlan(plan.id);
    _refresh();
  }

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final int day;
  final int duration;
  final bool active;
  final List<PlanReading> readings;
  final VoidCallback onActivate;
  final VoidCallback? onDelete;

  const _PlanCard({
    required this.title,
    required this.subtitle,
    required this.day,
    required this.duration,
    required this.active,
    required this.readings,
    required this.onActivate,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final progress = (day / duration).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: active ? AppColors.secondary : colors.outlineVariant,
          width: active ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_month_rounded,
                  color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(subtitle,
                        style: TextStyle(color: colors.onSurfaceVariant)),
                  ],
                ),
              ),
              if (onDelete != null)
                IconButton(
                  tooltip: 'Supprimer',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded),
                ),
            ],
          ),
          const SizedBox(height: 14),
          LinearProgressIndicator(value: progress.toDouble()),
          const SizedBox(height: 7),
          Text('Jour $day sur $duration'),
          if (readings.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              readings
                  .map((reading) => '${reading.bookName} ${reading.chapter}')
                  .join(' · '),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (!active) ...[
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: onActivate,
              child: const Text('Utiliser ce plan'),
            ),
          ] else ...[
            const SizedBox(height: 10),
            const Text(
              'Plan actif',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyPersonalPlans extends StatelessWidget {
  const _EmptyPersonalPlans();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        'Aucun plan personnel. Le plan « La Bible en 1 an » reste actif automatiquement.',
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _PlansData {
  final TodayReadingPlan today;
  final List<PersonalReadingPlan> personal;

  const _PlansData({required this.today, required this.personal});
}

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/store.dart';
import '../core/theme.dart';
import '../ui/components.dart';
import '../ui/shell.dart';
import 'projects.dart';

class TodayScreen extends StatefulWidget {
  final AppStore store;
  const TodayScreen(this.store, {super.key});
  @override
  State<TodayScreen> createState() => _TodayScreenState();
}

class _TodayScreenState extends State<TodayScreen> {
  String tab = 'Needs attention';
  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final attention = store.tasks
        .where((t) => ['review', 'blocked'].contains(t.status))
        .toList();
    final active = store.tasks
        .where((t) => !['done', 'cancelled'].contains(t.status))
        .toList();
    final mine = active.where((t) => t.assigneeId == store.user?.id).toList();
    final list = tab == 'My tasks'
        ? mine
        : tab == 'All active'
        ? active
        : attention;
    final tomorrow = dhakaNow
        .add(const Duration(days: 1))
        .toIso8601String()
        .substring(0, 10);
    final tomorrowTasks = active.where((t) => t.dueDate == tomorrow).toList();
    final date = dhakaNow;
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeading(
            'Manager overview',
            '${weekdays[date.weekday - 1]}, ${shortDate(businessDate)} · Here is your shared view of the day.',
            action: store.canManage
                ? FilledButton.icon(
                    onPressed: () => showNewProject(context, store),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New project'),
                  )
                : null,
          ),
          LayoutBuilder(
            builder: (context, box) {
              final compact = box.maxWidth < 650;
              final words = Padding(
                padding: EdgeInsets.all(compact ? 24 : 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.wb_sunny_outlined,
                          color: StudioColors.teal,
                          size: 17,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Hello, ${store.user?.firstName ?? 'there'}',
                            style: const TextStyle(
                              color: StudioColors.teal,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '${attention.length} details need\nyour attention.',
                      style: TextStyle(
                        fontSize: compact ? 27 : 34,
                        height: 1.2,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        color: StudioColors.ink,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'A quick review. A clear next step.\nKeep good work moving.',
                      style: TextStyle(
                        color: StudioColors.muted,
                        fontSize: 12,
                        height: 1.8,
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => setState(() => tab = 'Needs attention'),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 16),
                      label: const Text('Review today'),
                    ),
                  ],
                ),
              );
              return ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: Container(
                  color: const Color(0xFFE9F0ED),
                  child: compact
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            words,
                            SizedBox(
                              height: 145,
                              child: Image.asset(
                                'assets/images/studio.jpg',
                                fit: BoxFit.cover,
                                alignment: Alignment.center,
                              ),
                            ),
                          ],
                        )
                      : IntrinsicHeight(
                          child: Row(
                            children: [
                              Expanded(flex: 5, child: words),
                              Expanded(
                                flex: 6,
                                child: Image.asset(
                                  'assets/images/studio.jpg',
                                  height: 300,
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, box) {
              final stats = [
                (
                  'Active projects',
                  '${store.projects.length}',
                  Icons.workspaces_outline,
                  'Spaces taking shape',
                  Theme.of(context).colorScheme.primary,
                ),
                (
                  'Work in progress',
                  '${store.tasks.where((t) => t.status == 'in_progress').length}',
                  Icons.timelapse_rounded,
                  'Moving forward today',
                  Theme.of(context).colorScheme.primary,
                ),
                (
                  'Needs review',
                  '${store.tasks.where((t) => t.status == 'review').length}',
                  Icons.fact_check_outlined,
                  'Ready for your decision',
                  StudioColors.amber,
                ),
                (
                  'Blocked tasks',
                  '${store.tasks.where((t) => t.status == 'blocked').length}',
                  Icons.pause_circle_outline,
                  'A little help needed',
                  StudioColors.red,
                ),
              ];
              final cols = box.maxWidth < 650 ? 2 : 4;
              return Wrap(
                spacing: 14,
                runSpacing: 14,
                children: stats
                    .map(
                      (s) => SizedBox(
                        width: (box.maxWidth - (cols - 1) * 14) / cols,
                        child: Panel(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      s.$1,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ),
                                  Icon(s.$3, size: 18, color: s.$5),
                                ],
                              ),
                              const SizedBox(height: 13),
                              Text(
                                s.$2,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineLarge,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                s.$4,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 30),
          LayoutBuilder(
            builder: (context, box) {
              final main = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeading(
                          'A clear next step',
                          subtitle: 'The work and decisions that matter today.',
                        ),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              ['Needs attention', 'My tasks', 'All active']
                                  .map(
                                    (v) => ChoiceChip(
                                      label: Text(
                                        v,
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      selected: tab == v,
                                      onSelected: (_) =>
                                          setState(() => tab = v),
                                    ),
                                  )
                                  .toList(),
                        ),
                        const SizedBox(height: 10),
                        if (list.isEmpty)
                          const EmptyState(
                            'You are all caught up',
                            'Choose another view to see your team’s work.',
                          )
                        else
                          ...list.take(5).map((t) => TaskTile(t, store)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  SectionHeading(
                    'Spaces in progress',
                    subtitle: 'From the first sketch to the final detail.',
                    action: 'All projects',
                    onAction: () => context.go('/projects'),
                  ),
                  LayoutBuilder(
                    builder: (context, b) {
                      final cols = b.maxWidth >= 560 ? 2 : 1;
                      return Wrap(
                        spacing: 18,
                        runSpacing: 18,
                        children: store.projects
                            .take(2)
                            .map(
                              (p) => SizedBox(
                                width: (b.maxWidth - (cols - 1) * 18) / cols,
                                child: ProjectCard(p, store),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                ],
              );
              final aside = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Tomorrow, in view',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            Icon(
                              Icons.nights_stay_outlined,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'A look ahead before the 9 AM meeting.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 16),
                        const StatusPill(
                          'Scheduled tasks · Not a published plan',
                        ),
                        const SizedBox(height: 16),
                        if (tomorrowTasks.isEmpty)
                          const Text(
                            'No tasks scheduled for tomorrow yet.',
                            style: TextStyle(fontSize: 12),
                          )
                        else
                          ...tomorrowTasks
                              .take(3)
                              .map(
                                (t) => Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        margin: const EdgeInsets.only(top: 5),
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              t.title,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 3),
                                            Text(
                                              store
                                                      .person(t.assigneeId)
                                                      ?.name ??
                                                  '',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                        OutlinedButton.icon(
                          onPressed: () => context.go('/planning'),
                          icon: const Icon(
                            Icons.calendar_today_outlined,
                            size: 15,
                          ),
                          label: const Text(
                            'Review project plans',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionHeading('Studio notes'),
                        ...store.notifications
                            .take(3)
                            .map(
                              (n) => Padding(
                                padding: const EdgeInsets.only(bottom: 18),
                                child: InkWell(
                                  onTap: () => context.go(n['route']),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: Theme.of(context)
                                              .scaffoldBackgroundColor,
                                          borderRadius: BorderRadius.circular(
                                            9,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.notifications_none,
                                          size: 16,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              n['title'],
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              n['body'],
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodySmall,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        if (store.notifications.isEmpty)
                          const Text(
                            'No new notes.',
                            style: TextStyle(fontSize: 12),
                          ),
                        TextButton(
                          onPressed: () => context.go('/inbox'),
                          child: const Text(
                            'Open inbox',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: StudioColors.teal,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.edit_note_rounded,
                          color: Colors.white,
                          size: 26,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Small updates.\nBetter teamwork.',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            height: 1.35,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Share what moved forward and where you need a hand.',
                          style: TextStyle(
                            color: Color(0xFFD0E4E1),
                            fontSize: 12,
                            height: 1.7,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => context.go('/reports'),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(child: Text('Write daily report')),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward, size: 16),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
              return box.maxWidth >= 1050
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 7, child: main),
                        const SizedBox(width: 24),
                        Expanded(flex: 3, child: aside),
                      ],
                    )
                  : Column(children: [main, const SizedBox(height: 24), aside]);
            },
          ),
          const SizedBox(height: 30),
          Text(
            'Digital Source · Thoughtful spaces. Connected people.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

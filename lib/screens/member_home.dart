import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/store.dart';
import '../ui/components.dart';
import '../ui/shell.dart';

class MemberDashboardScreen extends StatelessWidget {
  final AppStore store;
  const MemberDashboardScreen(this.store, {super.key});
  @override
  Widget build(BuildContext context) {
    final mine = store.tasks
        .where(
          (t) =>
              t.assigneeId == store.user?.id &&
              !['done', 'cancelled'].contains(t.status),
        )
        .toList();
    final leads = store.projects
        .where((p) => p.leadId == store.user?.id)
        .toList();
    final personalPlans = store.plans
        .where((p) => (p['recipient_ids'] as List).contains(store.user?.id))
        .toList();
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeading(
            'My workday',
            'Hello, ${store.user?.firstName ?? 'there'}. Here is your next clear step.',
            action: FilledButton.icon(
              onPressed: () => context.go('/reports'),
              icon: const Icon(Icons.edit_note, size: 20),
              label: const Text('Write daily report'),
            ),
          ),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your focus today',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  '${mine.length} active tasks across ${store.projects.length} assigned projects.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                if (mine.isEmpty)
                  const EmptyState(
                    'You are ready for your next assignment',
                    'Your manager will assign tasks to your project team.',
                  )
                else
                  ...mine.map((t) => TaskTile(t, store)),
              ],
            ),
          ),
          if (leads.isNotEmpty) ...[
            const SizedBox(height: 24),
            const SectionHeading(
              'Your team lead responsibilities',
              subtitle: 'These permissions apply only to the projects below.',
            ),
            ...leads.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.supervisor_account_outlined,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              p.name,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                          const StatusPill('Team lead'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Assign tasks, review work and coordinate the plan for this project.',
                        style: TextStyle(fontSize: 13),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton(
                        onPressed: () => context.go('/projects/${p.id}'),
                        child: const Text('Open project workspace'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeading('Be ready for tomorrow'),
                Text(
                  personalPlans.isEmpty
                      ? 'No published plan has been assigned to you yet.'
                      : '${personalPlans.length} published plans include your tasks.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => context.go('/planning'),
                  icon: const Icon(Icons.calendar_month_outlined, size: 18),
                  label: const Text('View my plans'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SectionHeading('Your project teams'),
          if (store.projects.isEmpty)
            const EmptyState(
              'No projects assigned yet',
              'Your manager can add your profile card to a project.',
            )
          else
            ...store.projects.map(
              (p) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Panel(
                  child: Material(
                    color: Colors.transparent,
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        p.name,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text('${p.client} · ${p.progress}% verified'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.go('/projects/${p.id}'),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

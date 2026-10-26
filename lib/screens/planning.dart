import 'package:flutter/material.dart';

import '../core/store.dart';
import '../ui/components.dart';
import '../ui/shell.dart';

class PlanningScreen extends StatelessWidget {
  final AppStore store;
  const PlanningScreen(this.store, {super.key});
  @override
  Widget build(BuildContext context) {
    final today = businessDate;
    final plans = store.plans
        .where((p) => p['plan_date'].toString().compareTo(today) >= 0)
        .toList();
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeading(
            'Tomorrow starts with clarity.',
            'Publish the plan. Give everyone a clear next step.',
            action: (store.canManage || store.hasLeadProject)
                ? FilledButton.icon(
                    onPressed: () => publish(context),
                    icon: const Icon(Icons.publish_outlined, size: 18),
                    label: const Text('Publish a plan'),
                  )
                : null,
          ),
          if (plans.isEmpty)
            Panel(
              child: EmptyState(
                'No published plans yet',
                'Scheduled due dates become a shared plan when a manager publishes it.',
                icon: Icons.calendar_month_outlined,
                action: (store.canManage || store.hasLeadProject)
                    ? OutlinedButton(
                        onPressed: () => publish(context),
                        child: const Text('Prepare tomorrow'),
                      )
                    : null,
              ),
            )
          else
            ...plans.map((p) {
              final tasks = store.tasks
                  .where((t) => (p['task_ids'] as List).contains(t.id))
                  .toList();
              final recipients = List<String>.from(p['recipient_ids']);
              final acks = List<String>.from(p['acknowledged_ids']);
              final own = recipients.contains(store.user?.id),
                  seen = acks.contains(store.user?.id);
              return Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Panel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 12,
                        runSpacing: 10,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            store.project(p['project_id'])?.name ?? 'Project',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          StatusPill('Published · Revision ${p['revision']}'),
                          StatusPill(shortDate(p['plan_date'])),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${acks.length} of ${recipients.length} people have acknowledged this revision.',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: recipients
                            .map(
                              (id) => Chip(
                                avatar: PersonAvatar(
                                  store.person(id),
                                  size: 24,
                                ),
                                label: Text(
                                  '${store.person(id)?.firstName ?? 'Member'} ${acks.contains(id) ? '✓' : '· Pending'}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(height: 14),
                      ...tasks.map((t) => TaskTile(t, store)),
                      if (own) ...[
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: seen
                              ? null
                              : () async {
                                  try {
                                    await store.mutate(
                                      '/plans/${p['id']}/acknowledge',
                                      {},
                                    );
                                    if (context.mounted) {
                                      toast(
                                        context,
                                        'Your acknowledgment is saved.',
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      toast(context, e.toString());
                                    }
                                  }
                                },
                          icon: const Icon(Icons.check, size: 18),
                          label: Text(
                            seen
                                ? 'You have seen this plan'
                                : 'I have seen my plan',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          const SizedBox(height: 16),
          Text(
            'A new revision requires a new acknowledgment. Inbox reminders run while the local server is on.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Future<void> publish(BuildContext context) async {
    final projects = store.projects
        .where((p) => store.canManageProject(p.id))
        .toList();
    if (projects.isEmpty) {
      toast(context, 'Create a project and add tasks first.');
      return;
    }
    String project = projects.first.id;
    final date = TextEditingController(
      text: dhakaNow
          .add(const Duration(days: 1))
          .toIso8601String()
          .substring(0, 10),
    );
    final selected = <String>{};
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => SaveDialog(
          title: 'Prepare a shared plan',
          subtitle: 'Choose the tasks your team should focus on.',
          saveLabel: 'Publish plan',
          onSave: () async {
            if (selected.isEmpty) throw Exception('Select at least one task.');
            await store.mutate('/plans', {
              'project_id': project,
              'plan_date': date.text,
              'task_ids': selected.toList(),
            });
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                initialValue: project,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Project'),
                items: projects
                    .map(
                      (p) => DropdownMenuItem(
                        value: p.id,
                        child: Text(p.name, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() {
                  project = v!;
                  selected.clear();
                }),
              ),
              const SizedBox(height: 16),
              StudioField('Plan date (YYYY-MM-DD)', date),
              ...store.tasks
                  .where(
                    (t) =>
                        t.projectId == project &&
                        !['done', 'cancelled'].contains(t.status),
                  )
                  .map(
                    (t) => CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: selected.contains(t.id),
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(
                        t.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        store.person(t.assigneeId)?.name ?? '',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      onChanged: (value) => setState(() {
                        if (value == true) {
                          selected.add(t.id);
                        } else {
                          selected.remove(t.id);
                        }
                      }),
                    ),
                  ),
              if (!store.tasks.any(
                (t) =>
                    t.projectId == project &&
                    !['done', 'cancelled'].contains(t.status),
              ))
                const EmptyState(
                  'No active tasks',
                  'Add tasks to this project before publishing.',
                ),
            ],
          ),
        ),
      ),
    );
    date.dispose();
  }
}

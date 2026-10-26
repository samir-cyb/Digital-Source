import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/store.dart';
import '../models/models.dart';
import '../ui/components.dart';
import '../ui/shell.dart';

class EmployeeCard extends StatelessWidget {
  final Person person;
  final int workload;
  final bool selectable, selected;
  final VoidCallback onTap;
  const EmployeeCard({
    super.key,
    required this.person,
    required this.workload,
    required this.onTap,
    this.selectable = false,
    this.selected = false,
  });
  @override
  Widget build(BuildContext context) => Semantics(
    label: '${person.name}, ${person.title}',
    selected: selectable ? selected : null,
    button: true,
    child: AnimatedContainer(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: selected
            ? Theme.of(context).colorScheme.primary.withValues(alpha: .06)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outlineVariant,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PersonAvatar(person, size: selectable ? 46 : 62),
                    const Spacer(),
                    if (selectable)
                      Icon(
                        selected ? Icons.check_circle : Icons.circle_outlined,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.outlineVariant,
                        size: 23,
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).scaffoldBackgroundColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          person.employeeId,
                          style: Theme.of(context).textTheme.bodySmall!
                              .copyWith(fontSize: 10),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  person.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  person.title,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.business_center_outlined,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        person.department,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
                if (!selectable) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Divider(),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          '$workload active tasks',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      Icon(
                        Icons.arrow_outward_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class TeamScreen extends StatefulWidget {
  final AppStore store;
  const TeamScreen(this.store, {super.key});
  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  String query = '', department = 'All departments';
  @override
  Widget build(BuildContext context) {
    final people = widget.store.people
        .where(
          (p) =>
              '${p.name} ${p.title} ${p.employeeId}'.toLowerCase().contains(
                query.toLowerCase(),
              ) &&
              (department == 'All departments' || p.department == department),
        )
        .toList();
    final departments = [
      'All departments',
      ...widget.store.people.map((p) => p.department).toSet(),
    ];
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeading(
            'Good people. Great work.',
            '${widget.store.people.length} people bringing every detail together.',
          ),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              SizedBox(
                width: 320,
                child: TextField(
                  decoration: const InputDecoration(
                    hintText: 'Search by name, role or ID',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => query = v),
                ),
              ),
              SizedBox(
                width: 230,
                child: DropdownButtonFormField<String>(
                  initialValue: department,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.tune_rounded),
                  ),
                  items: departments
                      .map(
                        (d) => DropdownMenuItem(
                          value: d,
                          child: Text(d, style: const TextStyle(fontSize: 13)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => department = v!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          if (people.isEmpty)
            const EmptyState(
              'No matching people',
              'Try another name or department.',
            )
          else
            LayoutBuilder(
              builder: (context, box) {
                final cols = box.maxWidth >= 1050
                    ? 4
                    : box.maxWidth >= 760
                    ? 3
                    : box.maxWidth >= 500
                    ? 2
                    : 1;
                final width = (box.maxWidth - (cols - 1) * 18) / cols;
                return Wrap(
                  spacing: 18,
                  runSpacing: 18,
                  children: people
                      .map(
                        (p) => SizedBox(
                          width: width,
                          child: EmployeeCard(
                            person: p,
                            workload: widget.store.workload(p.id),
                            onTap: () => context.go('/team/${p.id}'),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          const SizedBox(height: 24),
          Text(
            'Development workspace · Sample profiles and photographs',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  final AppStore store;
  final String id;
  const ProfileScreen(this.store, this.id, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = store.person(id);
    if (p == null) {
      return const EmptyState(
        'Profile not found',
        'Return to People to choose an active member.',
      );
    }
    final projects = store.projects
        .where((x) => x.memberIds.contains(id))
        .toList();
    final tasks = store.tasks
        .where(
          (x) =>
              x.assigneeId == id && !['done', 'cancelled'].contains(x.status),
        )
        .toList();
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => context.go('/team'),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('All people'),
          ),
          const SizedBox(height: 20),
          Panel(
            child: LayoutBuilder(
              builder: (context, box) => Wrap(
                spacing: 24,
                runSpacing: 20,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PersonAvatar(p, size: 100),
                  SizedBox(
                    width: box.maxWidth < 400 ? box.maxWidth : 320,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        StatusPill(p.employeeId),
                        const SizedBox(height: 10),
                        Text(
                          p.name,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${p.title} · ${p.department}',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          p.email,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${tasks.length}',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const Text('Active tasks'),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${projects.length}',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const Text('Projects'),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 28),
          const SectionHeading('Project team memberships'),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: projects
                .map(
                  (project) => ActionChip(
                    label: Text(project.name),
                    avatar: const Icon(Icons.workspaces_outline, size: 17),
                    onPressed: () => context.go('/projects/${project.id}'),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 28),
          Panel(
            child: Column(
              children: [
                const SectionHeading('Current responsibilities'),
                if (tasks.isEmpty)
                  const EmptyState(
                    'No active tasks',
                    'New assignments will appear here.',
                  )
                else
                  ...tasks.map((t) => TaskTile(t, store)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

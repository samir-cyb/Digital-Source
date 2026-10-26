import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/store.dart';
import '../core/theme.dart';
import '../models/models.dart';
import '../ui/components.dart';
import '../ui/shell.dart';
import 'team.dart';

class ProjectCard extends StatelessWidget {
  final ProjectItem project;
  final AppStore store;
  const ProjectCard(this.project, this.store, {super.key});
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: () => context.go('/projects/${project.id}'),
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: Stack(
                children: [
                  SizedBox(
                    height: 148,
                    width: double.infinity,
                    child: Image.asset(
                      project.image,
                      fit: BoxFit.cover,
                      errorBuilder: (_, error, stack) => Container(
                        color: StudioColors.soft,
                        child: const Icon(
                          Icons.architecture,
                          size: 48,
                          color: StudioColors.teal,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 14,
                    left: 14,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        project.client,
                        style: const TextStyle(
                          color: StudioColors.ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.name,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Text(
                    project.site,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Flexible(child: StatusPill(project.phase)),
                      const Spacer(),
                      Text(
                        '${project.progress}%',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: project.progress / 100,
                      minHeight: 5,
                      backgroundColor: Theme.of(context)
                          .scaffoldBackgroundColor,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      SizedBox(
                        width: project.memberIds.length.clamp(1, 4) * 20.0 + 14,
                        height: 30,
                        child: Stack(
                          children: [
                            for (
                              int i = 0;
                              i < project.memberIds.length.clamp(0, 4);
                              i++
                            )
                              Positioned(
                                left: i * 20.0,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .surface,
                                  ),
                                  child: PersonAvatar(
                                    store.person(project.memberIds[i]),
                                    size: 26,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        shortDate(project.dueDate),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class ProjectsScreen extends StatefulWidget {
  final AppStore store;
  const ProjectsScreen(this.store, {super.key});
  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  String query = '', phase = 'All projects';
  @override
  Widget build(BuildContext context) {
    final projects = widget.store.projects
        .where(
          (p) =>
              '${p.name} ${p.client}'.toLowerCase().contains(
                query.toLowerCase(),
              ) &&
              (phase == 'All projects' || p.phase == phase),
        )
        .toList();
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeading(
            'Spaces taking shape.',
            'Every project, every detail, one shared view.',
            action: widget.store.canManage
                ? FilledButton.icon(
                    onPressed: () => showNewProject(context, widget.store),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('New project'),
                  )
                : null,
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ['All projects', 'Design', 'Sourcing', 'Installation']
                .map(
                  (v) => ChoiceChip(
                    label: Text(v, style: const TextStyle(fontSize: 12)),
                    selected: phase == v,
                    onSelected: (_) => setState(() => phase = v),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Search projects or clients',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => query = v),
            ),
          ),
          const SizedBox(height: 24),
          if (projects.isEmpty)
            const EmptyState(
              'No projects here yet',
              'Create a project or try a different search.',
            )
          else
            LayoutBuilder(
              builder: (context, box) {
                final cols = box.maxWidth >= 1000
                    ? 3
                    : box.maxWidth >= 580
                    ? 2
                    : 1;
                final width = (box.maxWidth - (cols - 1) * 20) / cols;
                return Wrap(
                  spacing: 20,
                  runSpacing: 20,
                  children: projects
                      .map(
                        (p) => SizedBox(
                          width: width,
                          child: ProjectCard(p, widget.store),
                        ),
                      )
                      .toList(),
                );
              },
            ),
        ],
      ),
    );
  }
}

Future<void> showNewProject(BuildContext context, AppStore store) async {
  await showDialog(
    context: context,
    builder: (context) => NewProjectDialog(store),
  );
}

class NewProjectDialog extends StatefulWidget {
  final AppStore store;
  const NewProjectDialog(this.store, {super.key});
  @override
  State<NewProjectDialog> createState() => _NewProjectDialogState();
}

class _NewProjectDialogState extends State<NewProjectDialog> {
  final name = TextEditingController(),
      client = TextEditingController(),
      site = TextEditingController(),
      search = TextEditingController();
  late final TextEditingController due = TextEditingController(
    text: dhakaNow
        .add(const Duration(days: 30))
        .toIso8601String()
        .substring(0, 10),
  );
  final form = GlobalKey<FormState>();
  final selected = <String>{};
  bool busy = false;
  String? error;
  @override
  void dispose() {
    for (final c in [name, client, site, due, search]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    if (selected.isEmpty) {
      setState(() => error = 'Select at least one team member.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.mutate('/projects', {
        'name': name.text,
        'client': client.text,
        'site': site.text,
        'due_date': due.text,
        'member_ids': selected.toList(),
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final matches = widget.store.people
        .where(
          (p) => '${p.name} ${p.title}'.toLowerCase().contains(
            search.text.toLowerCase(),
          ),
        )
        .toList();
    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Bring a new project to life',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      onPressed: busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                      tooltip: 'Close',
                    ),
                  ],
                ),
                Text(
                  'Start with the essentials. Build the right team.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                StudioField('Project name', name),
                StudioField('Client', client),
                LayoutBuilder(
                  builder: (context, box) => box.maxWidth < 480
                      ? Column(
                          children: [
                            StudioField('Site location', site),
                            dateField(context),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: StudioField('Site location', site)),
                            const SizedBox(width: 16),
                            Expanded(child: dateField(context)),
                          ],
                        ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Choose your team',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    StatusPill('${selected.length} selected'),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Select a person to add their identity card. Permissions stay unchanged.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: search,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    hintText: 'Find a person or skill',
                    prefixIcon: Icon(Icons.search),
                  ),
                ),
                if (selected.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: selected.map((id) {
                        final p = widget.store.person(id)!;
                        return InputChip(
                          avatar: PersonAvatar(p, size: 22),
                          label: Text(p.firstName),
                          onDeleted: busy
                              ? null
                              : () => setState(() => selected.remove(id)),
                        );
                      }).toList(),
                    ),
                  ),
                const SizedBox(height: 16),
                if (matches.isEmpty)
                  const EmptyState(
                    'No matching people',
                    'Your previous selections are still kept.',
                  )
                else
                  LayoutBuilder(
                    builder: (context, box) {
                      final cols = box.maxWidth >= 600
                          ? 3
                          : box.maxWidth >= 380
                          ? 2
                          : 1;
                      final width = (box.maxWidth - (cols - 1) * 12) / cols;
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: matches
                            .map(
                              (p) => SizedBox(
                                width: width,
                                child: EmployeeCard(
                                  person: p,
                                  workload: widget.store.workload(p.id),
                                  selectable: true,
                                  selected: selected.contains(p.id),
                                  onTap: () {
                                    if (!busy) {
                                      setState(() {
                                        if (!selected.add(p.id)) {
                                          selected.remove(p.id);
                                        }
                                      });
                                    }
                                  },
                                ),
                              ),
                            )
                            .toList(),
                      );
                    },
                  ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      error!,
                      style: const TextStyle(color: StudioColors.red),
                    ),
                  ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: busy ? null : () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: busy ? null : save,
                      icon: busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.add, size: 18),
                      label: const Text('Create project'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget dateField(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: due,
      readOnly: true,
      decoration: const InputDecoration(
        labelText: 'Project deadline',
        suffixIcon: Icon(Icons.calendar_today_outlined, size: 18),
      ),
      onTap: () async {
        final day = DateTime(dhakaNow.year, dhakaNow.month, dhakaNow.day);
        final chosen = await showDatePicker(
          context: context,
          initialDate: DateTime.tryParse(due.text) ?? day,
          firstDate: day,
          lastDate: day.add(const Duration(days: 3650)),
        );
        if (chosen != null) {
          due.text = chosen.toIso8601String().substring(0, 10);
        }
      },
      validator: (v) =>
          DateTime.tryParse(v ?? '') == null ? 'Choose a deadline.' : null,
    ),
  );
}

class ProjectDetailScreen extends StatelessWidget {
  final AppStore store;
  final String id;
  const ProjectDetailScreen(this.store, this.id, {super.key});
  @override
  Widget build(BuildContext context) {
    final p = store.project(id);
    if (p == null) {
      return const EmptyState(
        'Project not found',
        'You may not have access to this project.',
      );
    }
    final tasks = store.tasks.where((t) => t.projectId == id).toList();
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextButton.icon(
            onPressed: () => context.go('/projects'),
            icon: const Icon(Icons.arrow_back, size: 16),
            label: const Text('All projects'),
          ),
          const SizedBox(height: 16),
          PageHeading(
            p.name,
            '${p.client} · ${p.site}',
            action: store.canManageProject(id)
                ? FilledButton.icon(
                    onPressed: () => showNewTask(context, store, p),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add task'),
                  )
                : null,
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Image.asset(
              p.image,
              width: double.infinity,
              height: 230,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(height: 24),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 20,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusPill(p.phase),
                    Text('Due ${shortDate(p.dueDate)}'),
                    Text(
                      '${p.completedCount} of ${p.taskCount} tasks verified',
                    ),
                    if (p.blockedCount > 0)
                      StatusPill(
                        '${p.blockedCount} blocked',
                        color: StudioColors.red,
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: p.progress / 100,
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      '${p.progress}%',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Project team',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: p.memberIds.map((uid) {
                    final member = store.person(uid);
                    return ActionChip(
                      avatar: PersonAvatar(member, size: 24),
                      label: Text(
                        (member?.name ?? 'Member') +
                            (p.leadId == uid ? ' (Team lead)' : ''),
                      ),
                      onPressed: () => context.go('/team/$uid'),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          if (!store.canFinance) ...[
            ProjectLeadPanel(store, p),
            const SizedBox(height: 24),
          ],
          if (!store.canFinance)
            Panel(
              child: Column(
                children: [
                  const SectionHeading(
                    'The work ahead',
                    subtitle:
                        'A shared view of ownership, progress and next steps.',
                  ),
                  if (tasks.isEmpty)
                    const EmptyState(
                      'Ready for the first task',
                      'Add a task and give someone a clear next step.',
                    )
                  else
                    ...tasks.map((t) => TaskTile(t, store, showProject: false)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class ProjectLeadPanel extends StatelessWidget {
  final AppStore store;
  final ProjectItem project;
  const ProjectLeadPanel(this.store, this.project, {super.key});
  @override
  Widget build(BuildContext context) {
    final lead = project.leadId == null ? null : store.person(project.leadId!);
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(
            'Project team lead',
            subtitle: 'One temporary lead for this project.',
          ),
          Row(
            children: [
              PersonAvatar(lead, size: 46),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      lead?.name ?? 'No lead assigned',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      lead == null ? 'A manager can choose a team member.' : 'Coordinates tasks, reviews work and publishes this project’s plans.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (store.canManage) ...[
            const SizedBox(height: 18),
            OutlinedButton.icon(
              key: const Key('change-project-lead'),
              onPressed: () => chooseLead(context),
              icon: const Icon(Icons.supervisor_account_outlined, size: 18),
              label: Text(
                lead == null ? 'Assign team lead' : 'Change team lead',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> chooseLead(BuildContext context) async {
    String selected = project.leadId ?? '';
    final eligible = project.memberIds
        .map(store.person)
        .whereType<Person>()
        .where((p) => p.roles.contains('member'))
        .toList();
    await showDialog(
      context: context,
      builder: (context) => SaveDialog(
        title: 'Choose the project team lead',
        subtitle: project.name,
        saveLabel: 'Save lead assignment',
        onSave: () => store.mutate('/projects/${project.id}/lead', {
          'user_id': selected.isEmpty ? null : selected,
        }, method: 'PATCH'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DropdownButtonFormField<String>(
              key: const Key('project-lead-select'),
              initialValue: selected,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Team member'),
              items: [
                const DropdownMenuItem(value: '', child: Text('No team lead')),
                ...eligible.map(
                  (p) => DropdownMenuItem(
                    value: p.id,
                    child: Row(
                      children: [
                        PersonAvatar(p, size: 28),
                        const SizedBox(width: 10),
                        Expanded(child: Text(p.name)),
                      ],
                    ),
                  ),
                ),
              ],
              onChanged: (value) => selected = value!,
            ),
            const SizedBox(height: 18),
            const Text(
              'Replacing or removing a lead ends their extra permissions for this project. Their Team member account stays the same.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> showNewTask(
  BuildContext context,
  AppStore store,
  ProjectItem project,
) async {
  final title = TextEditingController();
  final eligible = project.memberIds
      .where((id) => store.person(id)?.roles.contains('finance') == false)
      .toList();
  if (eligible.isEmpty) {
    toast(context, 'Add a team member to this project first.');
    return;
  }
  String assignee = eligible.first;
  final due = TextEditingController(text: businessDate);
  await showDialog(
    context: context,
    builder: (context) => SaveDialog(
      title: 'Create a clear next step',
      subtitle: project.name,
      saveLabel: 'Add task',
      onSave: () => store.mutate('/tasks', {
        'project_id': project.id,
        'title': title.text,
        'assignee_id': assignee,
        'due_date': due.text,
      }),
      child: Column(
        children: [
          StudioField('Task title', title),
          DropdownButtonFormField<String>(
            initialValue: assignee,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Responsible person'),
            items: eligible
                .map(
                  (id) => DropdownMenuItem(
                    value: id,
                    child: Text(store.person(id)?.name ?? 'Member'),
                  ),
                )
                .toList(),
            onChanged: (v) => assignee = v!,
          ),
          const SizedBox(height: 16),
          StudioField('Due date (YYYY-MM-DD)', due),
        ],
      ),
    ),
  );
  title.dispose();
  due.dispose();
}

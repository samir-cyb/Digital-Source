import 'package:flutter/material.dart';

import '../core/store.dart';
import '../core/theme.dart';
import '../models/models.dart';

String shortDate(String value) {
  final d = DateTime.tryParse(value);
  if (d == null) return value;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${d.day} ${months[d.month - 1]}';
}

DateTime get dhakaNow => DateTime.now().toUtc().add(const Duration(hours: 6));
String get businessDate => dhakaNow.toIso8601String().substring(0, 10);
String moneyLabel(String value) {
  final parts = value.split('.');
  final whole = parts.first.replaceAllMapped(
    RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
    (m) => '${m[1]},',
  );
  return '৳ $whole${parts.length > 1 && parts[1] != '00' ? '.${parts[1]}' : ''}';
}

int moneyCents(String value) {
  final parts = value.split('.');
  return int.parse(parts[0]) * 100 +
      int.parse(
        (parts.length > 1 ? parts[1] : '').padRight(2, '0').substring(0, 2),
      );
}

void toast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      showCloseIcon: true,
    ),
  );
}

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
    ),
    child: child,
  );
}

class SectionHeading extends StatelessWidget {
  final String title;
  final String? subtitle, action;
  final VoidCallback? onAction;
  const SectionHeading(
    this.title, {
    super.key,
    this.subtitle,
    this.action,
    this.onAction,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null)
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
        if (action != null)
          Flexible(
            child: TextButton(
              onPressed: onAction,
              child: Text(action!, textAlign: TextAlign.end),
            ),
          ),
      ],
    ),
  );
}

class PageHeading extends StatelessWidget {
  final String title, subtitle;
  final Widget? action;
  const PageHeading(this.title, this.subtitle, {super.key, this.action});
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final words = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: 28),
        child: box.maxWidth < 560
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  words,
                  if (action != null) ...[const SizedBox(height: 16), action!],
                ],
              )
            : Row(
                children: [
                  Expanded(child: words),
                  ?action,
                ],
              ),
      );
    },
  );
}

class PersonAvatar extends StatelessWidget {
  final Person? person;
  final double size;
  const PersonAvatar(this.person, {super.key, this.size = 40});
  @override
  Widget build(BuildContext context) => Semantics(
    label: person?.name,
    child: ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: person?.avatar.isNotEmpty == true
            ? Image.asset(
                person!.avatar,
                fit: BoxFit.cover,
                errorBuilder: (_, error, stack) => _fallback(context),
              )
            : _fallback(context),
      ),
    ),
  );
  Widget _fallback(BuildContext context) => ColoredBox(
    color: StudioColors.soft,
    child: Center(
      child: Text(
        person?.initials ?? 'DS',
        style: TextStyle(
          color: StudioColors.teal,
          fontWeight: FontWeight.w800,
          fontSize: size * .3,
        ),
      ),
    ),
  );
}

class StatusPill extends StatelessWidget {
  final String label;
  final Color? color;
  const StatusPill(this.label, {super.key, this.color});
  @override
  Widget build(BuildContext context) {
    final c =
        color ??
        switch (label.toLowerCase()) {
          'blocked' => StudioColors.red,
          'needs review' || 'pending' || 'sourcing' => StudioColors.amber,
          'completed' || 'approved' || 'received' => StudioColors.green,
          _ => Theme.of(context).colorScheme.primary,
        };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String title, message;
  final IconData icon;
  final Widget? action;
  const EmptyState(
    this.title,
    this.message, {
    super.key,
    this.icon = Icons.inbox_outlined,
    this.action,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 44, horizontal: 20),
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 16),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    ),
  );
}

class StudioField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final int lines;
  final bool requiredField;
  final TextInputType? keyboard;
  const StudioField(
    this.label,
    this.controller, {
    super.key,
    this.lines = 1,
    this.requiredField = true,
    this.keyboard,
  });
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      maxLines: lines,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label),
      validator: requiredField
          ? (value) => value == null || value.trim().isEmpty
                ? 'Enter ${label.toLowerCase()}.'
                : null
          : null,
    ),
  );
}

class SaveDialog extends StatefulWidget {
  final String title, subtitle, saveLabel;
  final Widget child;
  final Future<void> Function() onSave;
  const SaveDialog({
    super.key,
    required this.title,
    required this.child,
    required this.onSave,
    this.subtitle = '',
    this.saveLabel = 'Save',
  });
  @override
  State<SaveDialog> createState() => _SaveDialogState();
}

class _SaveDialogState extends State<SaveDialog> {
  final form = GlobalKey<FormState>();
  bool busy = false;
  String? error;
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.onSave();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
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
              if (widget.subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Text(
                    widget.subtitle,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              const SizedBox(height: 12),
              widget.child,
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    error!,
                    style: const TextStyle(color: StudioColors.red),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: busy ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: busy ? null : save,
                    child: busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(widget.saveLabel),
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

class TaskTile extends StatelessWidget {
  final TaskItem task;
  final AppStore store;
  final bool showProject;
  const TaskTile(this.task, this.store, {super.key, this.showProject = true});
  @override
  Widget build(BuildContext context) {
    final done = task.status == 'done';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => showTaskDialog(context, store, task),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: done
                    ? StudioColors.green.withValues(alpha: .08)
                    : Theme.of(context).scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                done
                    ? Icons.check_rounded
                    : task.status == 'blocked'
                    ? Icons.pause_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 18,
                color: done
                    ? StudioColors.green
                    : task.status == 'blocked'
                    ? StudioColors.red
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      decoration: done ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Wrap(
                    spacing: 8,
                    runSpacing: 5,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (showProject)
                        Text(
                          store.project(task.projectId)?.client ?? '',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      Text(
                        shortDate(task.dueDate),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      StatusPill(task.statusLabel),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            PersonAvatar(store.person(task.assigneeId), size: 30),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right, size: 17),
          ],
        ),
      ),
    );
  }
}

Future<void> showTaskDialog(
  BuildContext context,
  AppStore store,
  TaskItem task,
) async {
  final note = TextEditingController();
  final assignee = store.person(task.assigneeId);
  final manage = store.canManageProject(task.projectId);
  final own = task.assigneeId == store.user?.id;
  final options = <String, String>{};
  if (manage || own) {
    if (task.status == 'todo') options['in_progress'] = 'Start work';
    if (task.status == 'in_progress') options['review'] = 'Submit for review';
    if (task.status == 'blocked') options['in_progress'] = 'Resume work';
    if (task.status == 'review' && manage) {
      options['done'] = 'Approve completion';
      options['in_progress'] = 'Request changes';
    }
    if (['todo', 'in_progress', 'review'].contains(task.status)) {
      options['blocked'] = 'Report blocker';
    }
  }
  String? selected = options.keys.firstOrNull;
  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => SaveDialog(
        title: task.title,
        subtitle: store.project(task.projectId)?.name ?? 'Task',
        saveLabel: selected == null ? 'Close' : options[selected]!,
        onSave: () async {
          if (selected != null) {
            await store.mutate('/tasks/${task.id}', {
              'status': selected,
              'version': task.version,
              'note': note.text,
            }, method: 'PATCH');
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                PersonAvatar(assignee),
                const SizedBox(width: 12),
                Expanded(child: Text(assignee?.name ?? 'Assigned member')),
                StatusPill(task.statusLabel),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Due ${shortDate(task.dueDate)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (task.blocker != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  task.blocker!,
                  style: const TextStyle(color: StudioColors.red),
                ),
              ),
            if (selected != null) ...[
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: selected,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Next action'),
                items: options.entries
                    .map(
                      (e) =>
                          DropdownMenuItem(value: e.key, child: Text(e.value)),
                    )
                    .toList(),
                onChanged: (v) => setState(() => selected = v),
              ),
              const SizedBox(height: 16),
              StudioField(
                'Note or blocker reason',
                note,
                lines: 3,
                requiredField:
                    selected == 'blocked' ||
                    task.status == 'blocked' ||
                    (task.status == 'review' && selected == 'in_progress'),
              ),
            ],
          ],
        ),
      ),
    ),
  );
  note.dispose();
}

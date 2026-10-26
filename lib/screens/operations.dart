import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/store.dart';
import '../core/theme.dart';
import '../ui/components.dart';
import '../ui/shell.dart';

class SourcingScreen extends StatelessWidget {
  final AppStore store;
  const SourcingScreen(this.store, {super.key});
  @override
  Widget build(BuildContext context) => PageBody(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          'The right pieces, on time.',
          'Keep materials, suppliers and deliveries connected.',
          action: store.canSource
              ? FilledButton.icon(
                  onPressed: () => newMaterial(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Material request'),
                )
              : null,
        ),
        if (store.materials.isEmpty)
          const EmptyState(
            'No material requests yet',
            'Start with what your project needs.',
          )
        else
          ...store.materials.map((m) {
            final remaining =
                num.parse(m['quantity']) - num.parse(m['received']);
            final supplier = store.suppliers
                .where((s) => s['id'] == m['supplier_id'])
                .firstOrNull;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
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
                          m['item'],
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        StatusPill(
                          remaining == 0 ? 'Received' : 'Partial delivery',
                          color: remaining == 0
                              ? StudioColors.green
                              : StudioColors.amber,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${store.project(m['project_id'])?.name ?? ''} · ${supplier?['name'] ?? 'Supplier not assigned'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 28,
                      runSpacing: 16,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _quantity(
                          context,
                          'Ordered',
                          '${num.parse(m['quantity'])} ${m['unit']}',
                        ),
                        _quantity(
                          context,
                          'Received',
                          '${num.parse(m['received'])} ${m['unit']}',
                        ),
                        _quantity(
                          context,
                          'Outstanding',
                          '$remaining ${m['unit']}',
                        ),
                        _quantity(
                          context,
                          'Expected',
                          shortDate(m['due_date']),
                        ),
                        if (remaining > 0 &&
                            store.canManageProject(m['project_id']))
                          OutlinedButton.icon(
                            onPressed: () => receive(context, m),
                            icon: const Icon(Icons.add_task, size: 16),
                            label: const Text('Record delivery'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value:
                            num.parse(m['received']) / num.parse(m['quantity']),
                        minHeight: 5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    ),
  );
  Widget _quantity(BuildContext context, String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 4),
      Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    ],
  );
  Future<void> receive(BuildContext context, Map<String, dynamic> m) async {
    final qty = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => SaveDialog(
        title: 'Record a delivery',
        subtitle: m['item'],
        saveLabel: 'Confirm received',
        child: StudioField(
          'Quantity received',
          qty,
          keyboard: TextInputType.number,
        ),
        onSave: () => store.mutate('/materials/${m['id']}/receive', {
          'quantity': qty.text,
        }),
      ),
    );
    qty.dispose();
  }

  Future<void> newMaterial(BuildContext context) async {
    final projects = store.projects
        .where((p) => store.canManageProject(p.id))
        .toList();
    if (projects.isEmpty) {
      toast(context, 'Create a project before requesting materials.');
      return;
    }
    String project = projects.first.id;
    String? supplier = store.suppliers.firstOrNull?['id'];
    final item = TextEditingController(),
        qty = TextEditingController(),
        unit = TextEditingController(text: 'pieces'),
        due = TextEditingController(text: businessDate);
    await showDialog(
      context: context,
      builder: (context) => SaveDialog(
        title: 'Request the right materials',
        subtitle: 'Link every order to a project.',
        saveLabel: 'Create request',
        onSave: () => store.mutate('/materials', {
          'project_id': project,
          'supplier_id': supplier,
          'item': item.text,
          'quantity': qty.text,
          'unit': unit.text,
          'due_date': due.text,
        }),
        child: Column(
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
              onChanged: (v) => project = v!,
            ),
            const SizedBox(height: 16),
            StudioField('Material / specification', item),
            StudioField('Quantity', qty, keyboard: TextInputType.number),
            StudioField('Unit', unit),
            DropdownButtonFormField<String>(
              initialValue: supplier,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Supplier'),
              items: store.suppliers
                  .map(
                    (s) => DropdownMenuItem<String>(
                      value: s['id'],
                      child: Text(s['name']),
                    ),
                  )
                  .toList(),
              onChanged: (v) => supplier = v,
            ),
            const SizedBox(height: 16),
            StudioField('Expected date (YYYY-MM-DD)', due),
          ],
        ),
      ),
    );
    for (final c in [item, qty, unit, due]) {
      c.dispose();
    }
  }
}

class FinanceScreen extends StatelessWidget {
  final AppStore store;
  const FinanceScreen(this.store, {super.key});
  @override
  Widget build(BuildContext context) {
    if (!store.canFinance) {
      return const EmptyState(
        'Restricted financial records',
        'Your role does not include access to company money records.',
        icon: Icons.lock_outline,
      );
    }
    int sum(String kind) => store.money
        .where((m) => m['kind'] == kind && m['status'] == 'approved')
        .fold(0, (n, m) => n + moneyCents(m['amount']));
    String amount(int cents) => moneyLabel((cents / 100).toStringAsFixed(2));
    return PageBody(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeading(
            'Finance overview',
            'A clear record of who paid whom, and why.',
            action: FilledButton.icon(
              onPressed: () => newMoney(context),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Record money'),
            ),
          ),
          LayoutBuilder(
            builder: (context, box) {
              final cols = box.maxWidth >= 700 ? 3 : 1;
              final values = [
                (
                  'Client receipts',
                  amount(sum('client_receipt')),
                  Icons.south_west,
                ),
                ('Project expenses', amount(sum('expense')), Icons.north_east),
                ('Advances issued', amount(sum('advance')), Icons.swap_horiz),
              ];
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: values
                    .map(
                      (v) => SizedBox(
                        width: (box.maxWidth - (cols - 1) * 16) / cols,
                        child: Panel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      v.$1,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ),
                                  Icon(
                                    v.$3,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                    size: 18,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                v.$2,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium,
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Approved records only',
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
          const SizedBox(height: 16),
          Text(
            'Advances are transfers, not project expenses. Reversed records are excluded.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 28),
          const SectionHeading(
            'Money trail',
            subtitle: 'Open a record to review its details.',
          ),
          if (store.money.isEmpty)
            const EmptyState(
              'Your money trail starts here',
              'Record a receipt, advance or expense.',
            )
          else
            ...store.money.map(
              (m) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => review(context, m),
                  child: Panel(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary
                                .withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            m['kind'] == 'client_receipt'
                                ? Icons.south_west
                                : Icons.north_east,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m['purpose'],
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                '${m['payer']} → ${m['payee']}',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              const SizedBox(height: 5),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  StatusPill(
                                    m['kind'].toString().replaceAll('_', ' '),
                                  ),
                                  StatusPill(m['status']),
                                  Text(
                                    shortDate(m['entry_date']),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          moneyLabel(m['amount']),
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> review(BuildContext context, Map<String, dynamic> m) async {
    final pending = m['status'] == 'pending',
        approved = m['status'] == 'approved';
    await showDialog(
      context: context,
      builder: (context) => SaveDialog(
        title: moneyLabel(m['amount']),
        subtitle: m['purpose'],
        saveLabel: pending
            ? 'Approve record'
            : approved
            ? 'Reverse record'
            : 'Close',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('From: ${m['payer']}'),
            Text('To: ${m['payee']}'),
            Text('Project: ${store.project(m['project_id'])?.name ?? ''}'),
            Text('Method: ${m['method']}'),
            Text('Date: ${shortDate(m['entry_date'])}'),
            const SizedBox(height: 12),
            StatusPill(m['status']),
            const SizedBox(height: 16),
            Text(
              pending
                  ? 'The creator cannot approve their own record.'
                  : approved
                  ? 'Reversing preserves this record and creates a linked correction.'
                  : 'This record remains in the audit history.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        onSave: () async {
          if (pending || approved) {
            await store.mutate(
              '/money/${m['id']}/${pending ? 'approve' : 'reverse'}',
              {},
            );
          }
        },
      ),
    );
  }

  Future<void> newMoney(BuildContext context) async {
    if (store.projects.isEmpty) {
      toast(context, 'Create a project first.');
      return;
    }
    String project = store.projects.first.id, kind = 'expense', method = 'bank';
    final amount = TextEditingController(),
        payer = TextEditingController(),
        payee = TextEditingController(),
        purpose = TextEditingController();
    final submissionKey = 'ui-${DateTime.now().microsecondsSinceEpoch}';
    await showDialog(
      context: context,
      builder: (context) => SaveDialog(
        title: 'Record a money movement',
        subtitle: 'This records an amount. It does not transfer money.',
        saveLabel: 'Save pending record',
        onSave: () => store.mutate('/money', {
          'project_id': project,
          'kind': kind,
          'amount': amount.text,
          'payer': payer.text,
          'payee': payee.text,
          'purpose': purpose.text,
          'method': method,
          'idempotency_key': submissionKey,
        }),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              initialValue: project,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Project'),
              items: store.projects
                  .map(
                    (p) => DropdownMenuItem(
                      value: p.id,
                      child: Text(p.name, overflow: TextOverflow.ellipsis),
                    ),
                  )
                  .toList(),
              onChanged: (v) => project = v!,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: kind,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: 'expense', child: Text('Expense')),
                DropdownMenuItem(value: 'advance', child: Text('Advance')),
                DropdownMenuItem(value: 'refund', child: Text('Refund')),
                DropdownMenuItem(
                  value: 'client_receipt',
                  child: Text('Client receipt'),
                ),
              ],
              onChanged: (v) => kind = v!,
            ),
            const SizedBox(height: 16),
            StudioField(
              'Amount in BDT',
              amount,
              keyboard: const TextInputType.numberWithOptions(decimal: true),
            ),
            StudioField('Paid by', payer),
            StudioField('Paid to', payee),
            StudioField('Purpose', purpose, lines: 2),
            DropdownButtonFormField<String>(
              initialValue: method,
              decoration: const InputDecoration(labelText: 'Method'),
              items: [
                'bank',
                'cash',
                'mobile banking',
              ].map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
              onChanged: (v) => method = v!,
            ),
          ],
        ),
      ),
    );
    for (final c in [amount, payer, payee, purpose]) {
      c.dispose();
    }
  }
}

class ReportsScreen extends StatefulWidget {
  final AppStore store;
  const ReportsScreen(this.store, {super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final completed = TextEditingController(),
      remaining = TextEditingController(),
      help = TextEditingController();
  final form = GlobalKey<FormState>();
  bool busy = false;
  String? error;
  @override
  void initState() {
    super.initState();
    final existing = widget.store.reports
        .where((r) => r['report_date'] == businessDate)
        .firstOrNull;
    if (existing != null) {
      completed.text = existing['completed'];
      remaining.text = existing['remaining'];
      help.text = existing['help_needed'];
    }
  }

  @override
  void dispose() {
    completed.dispose();
    remaining.dispose();
    help.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.mutate('/reports', {
        'completed': completed.text,
        'remaining': remaining.text,
        'help_needed': help.text,
      });
      if (mounted) toast(context, 'Daily report saved.');
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageBody(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          'A small update goes a long way.',
          'Share your progress and make tomorrow easier.',
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: Panel(
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SectionHeading(
                    'Your daily report',
                    subtitle:
                        '${shortDate(businessDate)} · One clear update for your team.',
                  ),
                  StudioField('What moved forward today?', completed, lines: 4),
                  StudioField(
                    'What is still remaining?',
                    remaining,
                    lines: 3,
                    requiredField: false,
                  ),
                  StudioField(
                    'Where do you need help?',
                    help,
                    lines: 3,
                    requiredField: false,
                  ),
                  if (error != null)
                    Text(
                      error!,
                      style: const TextStyle(color: StudioColors.red),
                    ),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: busy ? null : save,
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: Text(busy ? 'Saving…' : 'Save daily report'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        SectionHeading(
          widget.store.user?.hasAny(['manager']) == true
              ? 'Team report history'
              : 'Your previous updates',
        ),
        if (widget.store.reports.isEmpty)
          const EmptyState(
            'No reports yet',
            'Your saved updates will appear here.',
          )
        else
          ...widget.store.reports.map(
            (r) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    StatusPill(shortDate(r['report_date'])),
                    if (r['author_id'] != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        widget.store.person(r['author_id'])?.name ?? '',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(r['completed']),
                    if (r['remaining'].toString().isNotEmpty)
                      Text(
                        'Remaining: ${r['remaining']}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    if (r['help_needed'].toString().isNotEmpty)
                      Text(
                        'Help needed: ${r['help_needed']}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class InboxScreen extends StatelessWidget {
  final AppStore store;
  const InboxScreen(this.store, {super.key});
  @override
  Widget build(BuildContext context) => PageBody(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeading(
          'The updates that matter.',
          '${store.unread} unread notes across your workspace.',
        ),
        if (store.notifications.isEmpty)
          const EmptyState(
            'All caught up',
            'New assignments and decisions will appear here.',
          )
        else
          ...store.notifications.map(
            (n) => Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Panel(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      n['read'] == true
                          ? Icons.notifications_none
                          : Icons.notifications_active_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n['title'],
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            n['body'],
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: () => context.go(n['route']),
                                child: const Text('Open'),
                              ),
                              if (n['read'] != true)
                                TextButton(
                                  onPressed: () async {
                                    try {
                                      await store.mutate(
                                        '/notifications/${n['id']}/read',
                                        {},
                                      );
                                    } catch (e) {
                                      if (context.mounted) {
                                        toast(context, e.toString());
                                      }
                                    }
                                  },
                                  child: const Text('Mark as read'),
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
          ),
      ],
    ),
  );
}

class SettingsScreen extends StatelessWidget {
  final AppStore store;
  const SettingsScreen(this.store, {super.key});
  @override
  Widget build(BuildContext context) => PageBody(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const PageHeading(
          'Make yourself at home.',
          'Your profile and workspace preferences.',
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  PersonAvatar(store.user, size: 64),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          store.user?.name ?? '',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        Text(
                          store.user?.title ?? '',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Appearance',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    [
                          (ThemeMode.light, 'Light', Icons.light_mode_outlined),
                          (ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
                          (
                            ThemeMode.system,
                            'System',
                            Icons.settings_brightness_outlined,
                          ),
                        ]
                        .map(
                          (v) => ChoiceChip(
                            avatar: Icon(v.$3, size: 16),
                            label: Text(v.$2),
                            selected: store.themeMode == v.$1,
                            onSelected: (_) => store.setTheme(v.$1),
                          ),
                        )
                        .toList(),
              ),
              const SizedBox(height: 24),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.schedule),
                title: Text('Workspace timezone'),
                subtitle: Text('Asia/Dhaka · UTC+06:00'),
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.shield_outlined),
                title: Text('Local development workspace'),
                subtitle: Text(
                  'Sample data. Production security checks are still in progress.',
                ),
              ),
              const Divider(),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await store.logout();
                  } catch (e) {
                    if (context.mounted) toast(context, e.toString());
                  }
                },
                icon: const Icon(Icons.logout, size: 18),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

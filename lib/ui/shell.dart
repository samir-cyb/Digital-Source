import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/store.dart';
import '../core/theme.dart';
import 'components.dart';

class StudioShell extends StatelessWidget {
  final AppStore store;
  final Widget child;
  const StudioShell({super.key, required this.store, required this.child});
  List<(String, String, IconData)> get destinations => [
    (
      store.homeRoute,
      store.canManage
          ? 'Manager home'
          : store.canFinance
          ? 'Finance home'
          : 'My work',
      Icons.space_dashboard_outlined,
    ),
    (
      '/projects',
      store.canManage
          ? 'Projects'
          : store.canFinance
          ? 'Project context'
          : 'My projects',
      Icons.workspaces_outline,
    ),
    if (store.canManage) ('/team', 'People', Icons.people_outline_rounded),
    if (!store.canFinance)
      ('/planning', 'Tomorrow', Icons.calendar_month_outlined),
    if (store.canSource) ('/sourcing', 'Sourcing', Icons.inventory_2_outlined),
    if (!store.canFinance)
      ('/reports', 'Daily reports', Icons.edit_note_rounded),
    ('/inbox', 'Inbox', Icons.notifications_none_rounded),
  ];
  List<(String, String, IconData)> get mobilePrimary => [
    destinations[0],
    destinations[1],
    store.canManage
        ? ('/team', 'People', Icons.people_outline_rounded)
        : store.canFinance
        ? ('/inbox', 'Inbox', Icons.notifications_none_rounded)
        : ('/planning', 'Tomorrow', Icons.calendar_month_outlined),
  ];
  Widget mobileNavigation(BuildContext context, String path) {
    final primary = mobilePrimary;
    final index = primary.indexWhere(
      (d) => path == d.$1 || path.startsWith('${d.$1}/'),
    );
    return NavigationBar(
      height: 74,
      selectedIndex: index < 0 ? 3 : index,
      onDestinationSelected: (i) {
        if (i < 3) {
          context.go(primary[i].$1);
          return;
        }
        showModalBottomSheet(
          context: context,
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...destinations
                      .where((d) => !primary.any((p) => p.$1 == d.$1))
                      .map(
                        (d) => ListTile(
                          leading: Icon(d.$3),
                          title: Text(d.$2),
                          onTap: () {
                            Navigator.pop(context);
                            context.go(d.$1);
                          },
                        ),
                      ),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Settings'),
                    onTap: () {
                      Navigator.pop(context);
                      context.go('/settings');
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
      destinations: [
        ...primary.map(
          (d) => NavigationDestination(icon: Icon(d.$3), label: d.$2),
        ),
        const NavigationDestination(
          icon: Icon(Icons.grid_view_rounded),
          label: 'More',
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final mobile = width < 720, compact = width < 1100;
    final path = GoRouterState.of(context).uri.path;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            if (!mobile)
              Container(
                width: compact ? 84 : 228,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  border: Border(
                    right: BorderSide(
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 18 : 24,
                        vertical: 30,
                      ),
                      child: Row(
                        children: [
                          const BrandMark(),
                          if (!compact) ...[
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Digital\nSource',
                                style: TextStyle(
                                  fontSize: 18,
                                  height: 1.1,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -.6,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!compact)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 26),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant,
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.business_outlined, size: 18),
                              SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Studio workspace',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Icon(Icons.unfold_more, size: 16),
                            ],
                          ),
                        ),
                      ),
                    Expanded(
                      child: ListView(
                        padding: EdgeInsets.symmetric(
                          horizontal: compact ? 12 : 14,
                        ),
                        children: destinations.map((d) {
                          final selected =
                              path == d.$1 || path.startsWith('${d.$1}/');
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 7),
                            child: Tooltip(
                              message: compact ? d.$2 : '',
                              child: Material(
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                          .withValues(alpha: .09)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(10),
                                  onTap: () => context.go(d.$1),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 14,
                                    ),
                                    child: Row(
                                      mainAxisAlignment: compact
                                          ? MainAxisAlignment.center
                                          : MainAxisAlignment.start,
                                      children: [
                                        Icon(
                                          d.$3,
                                          size: 21,
                                          color: selected
                                              ? Theme.of(context)
                                                    .colorScheme
                                                    .primary
                                              : Theme.of(context)
                                                    .colorScheme
                                                    .onSurfaceVariant,
                                        ),
                                        if (!compact) ...[
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              d.$2,
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: selected
                                                    ? FontWeight.w800
                                                    : FontWeight.w500,
                                                color: selected
                                                    ? Theme.of(context)
                                                          .colorScheme
                                                          .primary
                                                    : Theme.of(context)
                                                          .colorScheme
                                                          .onSurfaceVariant,
                                              ),
                                            ),
                                          ),
                                          if (d.$1 == '/inbox' &&
                                              store.unread > 0)
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 7,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .primary,
                                                borderRadius:
                                                    BorderRadius.circular(5),
                                              ),
                                              child: Text(
                                                '${store.unread}',
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Theme.of(context)
                                                      .colorScheme
                                                      .onPrimary,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    if (!compact)
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Container(
                          padding: const EdgeInsets.all(15),
                          decoration: BoxDecoration(
                            color: Theme.of(context).scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.wb_sunny_outlined,
                                    size: 18,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                                  const SizedBox(width: 8),
                                  const Expanded(
                                    child: Text(
                                      'A little clarity, daily.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                store.canFinance
                                    ? 'Keep financial records clear and linked to the right project.'
                                    : 'Keep your next steps ready before the 9 AM meeting.',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              TextButton(
                                onPressed: () => context.go(
                                  store.canFinance ? '/finance' : '/reports',
                                ),
                                child: Text(
                                  store.canFinance
                                      ? 'Review money records'
                                      : 'Write your update',
                                  style: TextStyle(fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const Divider(),
                    InkWell(
                      onTap: () => context.go('/settings'),
                      child: Padding(
                        padding: EdgeInsets.all(compact ? 18 : 20),
                        child: Row(
                          children: [
                            PersonAvatar(store.user, size: 36),
                            if (!compact) ...[
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      store.user?.name ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      store.user?.title ?? '',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall!
                                          .copyWith(fontSize: 10),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.more_horiz, size: 18),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Column(
                children: [
                  Container(
                    height: 76,
                    padding: EdgeInsets.symmetric(horizontal: mobile ? 20 : 32),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        if (mobile) ...[
                          const BrandMark(size: 30),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text(
                              'Digital Source',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ] else ...[
                          Text(
                            'Workspace',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10),
                            child: Icon(Icons.chevron_right, size: 14),
                          ),
                          Text(
                            destinations
                                    .where((d) => path.startsWith(d.$1))
                                    .firstOrNull
                                    ?.$2 ??
                                'Settings',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const Spacer(),
                        if (!mobile) StatusPill(store.roleLabel),
                        IconButton(
                          onPressed: () => showSearchDialog(context, store),
                          icon: const Icon(Icons.search_rounded, size: 22),
                          tooltip: 'Search workspace',
                        ),
                        IconButton(
                          onPressed: () => context.go('/inbox'),
                          icon: Badge(
                            isLabelVisible: store.unread > 0,
                            smallSize: 7,
                            child: const Icon(
                              Icons.notifications_none_rounded,
                              size: 22,
                            ),
                          ),
                          tooltip: 'Open inbox',
                        ),
                        if (!mobile) ...[
                          const SizedBox(width: 12),
                          PersonAvatar(store.user, size: 34),
                        ],
                      ],
                    ),
                  ),
                  if (store.loading)
                    const LinearProgressIndicator(minHeight: 2),
                  if (store.error != null)
                    MaterialBanner(
                      content: Text(store.error!),
                      actions: [
                        TextButton(
                          onPressed: () {
                            store.reload().catchError((_) {});
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  Expanded(child: child),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: mobile ? mobileNavigation(context, path) : null,
    );
  }
}

class BrandMark extends StatelessWidget {
  final double size;
  const BrandMark({super.key, this.size = 38});
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: StudioColors.teal,
      borderRadius: BorderRadius.circular(size * .28),
    ),
    child: Icon(
      Icons.view_in_ar_rounded,
      color: Colors.white,
      size: size * .62,
    ),
  );
}

class PageBody extends StatelessWidget {
  final Widget child;
  const PageBody({super.key, required this.child});
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 720 ? 20 : 32),
    child: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1500),
        child: child,
      ),
    ),
  );
}

Future<void> showSearchDialog(BuildContext context, AppStore store) async {
  String query = '';
  await showDialog(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 560),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  autofocus: true,
                  decoration: const InputDecoration(
                    hintText: 'Find a project, person or task',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) =>
                      setState(() => query = v.toLowerCase().trim()),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      if (query.isEmpty)
                        const EmptyState(
                          'Find your next step',
                          'Search across your accessible workspace.',
                        ),
                      if (query.isNotEmpty) ...[
                        ...store.projects
                            .where(
                              (p) => '${p.name} ${p.client}'
                                  .toLowerCase()
                                  .contains(query),
                            )
                            .map(
                              (p) => ListTile(
                                leading: const Icon(Icons.workspaces_outline),
                                title: Text(p.name),
                                subtitle: Text(p.client),
                                onTap: () {
                                  Navigator.pop(context);
                                  context.go('/projects/${p.id}');
                                },
                              ),
                            ),
                        ...store.people
                            .where((p) => p.name.toLowerCase().contains(query))
                            .map(
                              (p) => ListTile(
                                leading: PersonAvatar(p),
                                title: Text(p.name),
                                subtitle: Text(p.title),
                                onTap: () {
                                  Navigator.pop(context);
                                  context.go('/team/${p.id}');
                                },
                              ),
                            ),
                        ...store.tasks
                            .where((t) => t.title.toLowerCase().contains(query))
                            .map(
                              (t) => ListTile(
                                leading: const Icon(Icons.task_alt),
                                title: Text(t.title),
                                onTap: () {
                                  Navigator.pop(context);
                                  showTaskDialog(context, store, t);
                                },
                              ),
                            ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

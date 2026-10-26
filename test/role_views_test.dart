import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:digital_source/core/api.dart';
import 'package:digital_source/core/store.dart';
import 'package:digital_source/main.dart';

AppStore roleStore(
  String role, {
  bool projectLead = false,
  List<String>? revokedProjects,
  void Function(Map<String, dynamic>)? capture,
}) {
  final data = Map<String, dynamic>.from(
    jsonDecode(File('test/fixtures/workspace.json').readAsStringSync()),
  );
  data['user'] = (data['people'] as List).firstWhere(
    (p) => projectLead
        ? p['email'] == 'farhana@digitalsource.local'
        : (p['roles'] as List).contains(role),
  );
  if (role == 'finance') {
    data['tasks'] = [];
    data['reports'] = [];
    data['materials'] = [];
    data['plans'] = [];
  }
  return AppStore(
    api: ApiClient(
      client: MockClient((req) async {
        if (req.url.path.endsWith('/auth/me')) {
          return http.Response(jsonEncode(data['user']), 200);
        }
        if (req.method == 'PATCH' && req.url.path.endsWith('/lead')) {
          final body = Map<String, dynamic>.from(jsonDecode(req.body));
          capture?.call(body);
          final id = req.url.pathSegments[req.url.pathSegments.length - 2];
          final project = (data['projects'] as List).firstWhere(
            (p) => p['id'] == id,
          );
          project['lead_id'] = body['user_id'];
          return http.Response(jsonEncode(project), 200);
        }
        for (final project in data['projects']) {
          if (revokedProjects?.contains(project['id']) == true) {
            project['lead_id'] = null;
          }
        }
        return http.Response(jsonEncode(data), 200);
      }),
    ),
  );
}

Future<void> desktop(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1440, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  for (final entry in [
    ('manager', 'Manager overview'),
    ('member', 'My workday'),
    ('finance', 'Finance overview'),
  ]) {
    testWidgets('${entry.$1} opens its own landing and navigation', (
      tester,
    ) async {
      await desktop(tester);
      final store = roleStore(entry.$1);
      await store.restore();
      await tester.pumpWidget(DigitalSourceApp(store: store));
      await tester.pumpAndSettle();
      expect(find.text(entry.$2), findsOneWidget);
      expect(
        find.text('People'),
        entry.$1 == 'manager' ? findsOneWidget : findsNothing,
      );
      expect(
        find.text('Finance home'),
        entry.$1 == 'finance' ? findsWidgets : findsNothing,
      );
      expect(
        find.text('Write your update'),
        entry.$1 == 'finance' ? findsNothing : findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('member is redirected away from manager and finance routes', (
    tester,
  ) async {
    await desktop(tester);
    final store = roleStore('member');
    await store.restore();
    await tester.pumpWidget(DigitalSourceApp(store: store));
    await tester.pumpAndSettle();
    final router =
        tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig
            as GoRouter;
    for (final path in ['/manager', '/finance', '/team']) {
      router.go(path);
      await tester.pumpAndSettle();
      expect(find.text('My workday'), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
  testWidgets('project lead gets scoped tools and loses them on refresh', (
    tester,
  ) async {
    await desktop(tester);
    final revoked = <String>[];
    final store = roleStore(
      'member',
      projectLead: true,
      revokedProjects: revoked,
    );
    await store.restore();
    await tester.pumpWidget(DigitalSourceApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Your team lead responsibilities'), findsOneWidget);
    final project = store.projects.first;
    expect(store.canManageProject(project.id), isTrue);
    expect(store.role, 'member');
    revoked.addAll(store.projects.map((p) => p.id));
    await store.reload();
    await tester.pumpAndSettle();
    expect(store.canManageProject(project.id), isFalse);
    expect(find.text('Your team lead responsibilities'), findsNothing);
    expect(find.text('People'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('manager can select a project lead from eligible members', (
    tester,
  ) async {
    await desktop(tester);
    Map<String, dynamic>? body;
    final store = roleStore('manager', capture: (v) => body = v);
    await store.restore();
    final project = store.projects.first;
    final arif = store.people.firstWhere(
      (p) => p.email == 'arif@digitalsource.local',
    );
    await tester.pumpWidget(DigitalSourceApp(store: store));
    await tester.pumpAndSettle();
    final router =
        tester.widget<MaterialApp>(find.byType(MaterialApp)).routerConfig
            as GoRouter;
    router.go('/projects/${project.id}');
    await tester.pumpAndSettle();
    final change = find.byKey(const Key('change-project-lead'));
    await tester.ensureVisible(change);
    await tester.tap(change);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('project-lead-select')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(arif.name).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save lead assignment'));
    await tester.pumpAndSettle();
    expect(body?['user_id'], arif.id);
    expect(store.project(project.id)?.leadId, arif.id);
    expect(tester.takeException(), isNull);
  });
}

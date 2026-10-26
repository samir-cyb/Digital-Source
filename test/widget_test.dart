import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:digital_source/main.dart';
import 'package:digital_source/core/api.dart';
import 'package:digital_source/core/store.dart';
import 'package:digital_source/core/theme.dart';
import 'package:digital_source/screens/projects.dart';
import 'package:digital_source/screens/team.dart';

Map<String, dynamic> fixture() =>
    jsonDecode(File('test/fixtures/workspace.json').readAsStringSync());
AppStore makeStore({
  void Function(http.Request)? capture,
  String role = "manager",
}) {
  final data = fixture();
  data["user"] = (data["people"] as List).firstWhere(
    (p) => (p["roles"] as List).contains(role),
  );
  final api = ApiClient(
    client: MockClient((req) async {
      capture?.call(req);
      if (req.url.path.endsWith('/auth/me')) {
        return http.Response(jsonEncode(data['user']), 200);
      }
      if (req.method == 'POST') return http.Response('{}', 201);
      return http.Response(jsonEncode(data), 200);
    }),
  );
  return AppStore(api: api);
}

Future<void> ready(AppStore store) async {
  await store.restore();
}

void main() {
  testWidgets('desktop workspace has working project and people navigation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = makeStore();
    await ready(store);
    await tester.pumpWidget(DigitalSourceApp(store: store));
    await tester.pumpAndSettle();
    expect(find.text('Manager overview'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('People').first);
    await tester.pumpAndSettle();
    expect(find.byType(EmployeeCard), findsNWidgets(7));
    await tester.tap(find.text('Projects').first);
    await tester.pumpAndSettle();
    expect(find.text('Spaces taking shape.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile Today and More navigation fit without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = makeStore(role: "finance");
    await ready(store);
    await tester.pumpWidget(DigitalSourceApp(store: store));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('More').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings').last);
    await tester.pumpAndSettle();
    expect(find.text('Make yourself at home.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'employee card selection survives search and is sent on creation',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? submitted;
      final store = makeStore(
        capture: (req) {
          if (req.url.path.endsWith('/projects') && req.method == 'POST') {
            submitted = jsonDecode(req.body);
          }
        },
      );
      await ready(store);
      await tester.pumpWidget(
        MaterialApp(
          theme: studioTheme(Brightness.light),
          home: Scaffold(body: NewProjectDialog(store)),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Project name'),
        'New showroom',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Client'),
        'Sample client',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Site location'),
        'Dhaka',
      );
      await tester.tap(find.byType(EmployeeCard).at(1));
      await tester.pumpAndSettle();
      expect(find.text('1 selected'), findsOneWidget);
      final search = find.widgetWithText(TextField, 'Find a person or skill');
      await tester.enterText(search, 'Arif');
      await tester.pumpAndSettle();
      expect(find.byType(EmployeeCard), findsOneWidget);
      await tester.tap(find.byType(EmployeeCard));
      await tester.pumpAndSettle();
      expect(find.text('2 selected'), findsOneWidget);
      await tester.ensureVisible(find.text('Create project'));
      await tester.tap(find.text('Create project'));
      await tester.pumpAndSettle();
      expect(submitted?['name'], 'New showroom');
      expect((submitted?['member_ids'] as List).length, 2);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('dark desktop and enlarged mobile text keep usable layouts', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = makeStore();
    await ready(store);
    store.setTheme(ThemeMode.dark);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: DigitalSourceApp(store: store),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('People').last);
    await tester.pumpAndSettle();
    expect(find.byType(EmployeeCard), findsNWidgets(7));
    expect(tester.takeException(), isNull);
  });

  testWidgets('session restore preserves the requested deep link', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = makeStore();
    await tester.pumpWidget(DigitalSourceApp(store: store));
    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    (app.routerConfig as GoRouter).go('/team');
    await tester.pump();
    await store.restore();
    await tester.pumpAndSettle();
    expect(find.text('Good people. Great work.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

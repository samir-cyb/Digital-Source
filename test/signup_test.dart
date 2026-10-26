import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:digital_source/core/api.dart';
import 'package:digital_source/core/store.dart';
import 'package:digital_source/main.dart';

Map<String, dynamic> sample() =>
    jsonDecode(File('test/fixtures/workspace.json').readAsStringSync());
AppStore signupStore({
  int signupStatus = 201,
  void Function(Map<String, dynamic>)? capture,
}) {
  final fixture = sample();
  return AppStore(
    api: ApiClient(
      client: MockClient((request) async {
        final path = request.url.path;
        if (path.endsWith('/auth/registration')) {
          return http.Response(
            jsonEncode({
              'roles': ['manager', 'member', 'finance'],
              'manager_code_required': true,
              'database': 'sqlite',
            }),
            200,
          );
        }
        if (path.endsWith('/auth/signup')) {
          final data = Map<String, dynamic>.from(jsonDecode(request.body));
          capture?.call(data);
          fixture["user"] = {
            ...fixture["user"],
            "roles": [data["role"] ?? "member"],
          };
          if (signupStatus != 201) {
            return http.Response(
              jsonEncode({
                'detail': 'An account with this email already exists. Sign in instead.',
              }),
              signupStatus,
            );
          }
          return http.Response(
            jsonEncode({'token': 'test-session', 'user': fixture['user']}),
            201,
          );
        }
        return http.Response(jsonEncode(fixture), 200);
      }),
    ),
  )..booting = false;
}

Future<void> openSignup(WidgetTester tester, AppStore store) async {
  await tester.pumpWidget(DigitalSourceApp(store: store));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Create an account'));
  await tester.tap(find.text('Create an account'));
  await tester.pumpAndSettle();
}

Future<void> fillSignup(
  WidgetTester tester, {
  String confirm = 'A long new passphrase!',
}) async {
  await tester.enterText(find.byKey(const Key('signup-name')), 'Studio Owner');
  await tester.enterText(
    find.byKey(const Key('signup-email')),
    'owner@example.com',
  );
  await tester.enterText(
    find.byKey(const Key('signup-password')),
    'A long new passphrase!',
  );
  await tester.enterText(find.byKey(const Key('signup-confirm')), confirm);
}

void main() {
  testWidgets('signup opens from login and creates a local account', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map<String, dynamic>? submitted;
    final store = signupStore(capture: (data) => submitted = data);
    await openSignup(tester, store);
    expect(find.text('Create account'), findsOneWidget);
    await fillSignup(tester);
    await tester.ensureVisible(find.text('Create account'));
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(submitted?['name'], 'Studio Owner');
    expect(submitted?['roles'], isNull);
    expect(find.text('My workday'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'signup keeps form values on duplicate and rejects mismatched passwords',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      int requests = 0;
      final store = signupStore(signupStatus: 409, capture: (_) => requests++);
      await openSignup(tester, store);
      await fillSignup(tester, confirm: 'Different passphrase!');
      await tester.ensureVisible(find.text('Create account'));
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(find.text('Passwords do not match.'), findsOneWidget);
      expect(requests, 0);
      await tester.enterText(
        find.byKey(const Key('signup-confirm')),
        'A long new passphrase!',
      );
      await tester.ensureVisible(find.text('Create account'));
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(requests, 1);
      expect(
        find.text(
          'An account with this email already exists. Sign in instead.',
        ),
        findsOneWidget,
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('signup-email')))
            .controller
            ?.text,
        'owner@example.com',
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Sign in'));
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Sign in to your workspace'), findsOneWidget);
    },
  );

  testWidgets('signup action stays visible on a short login viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(450, 500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = signupStore();
    await tester.pumpWidget(DigitalSourceApp(store: store));
    await tester.pumpAndSettle();
    final signup = find.text('Sign up');
    expect(signup.hitTestable(), findsOneWidget);
    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    expect(signup.hitTestable(), findsOneWidget);
    await tester.tap(signup);
    await tester.pumpAndSettle();
    expect(find.text('Create account'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final position in [
    ('manager', 'Manager', 'Manager overview'),
    ('finance', 'Finance', 'Finance overview'),
  ]) {
    testWidgets(
      'signup selects ${position.$2} and opens the matching dashboard',
      (tester) async {
        tester.view.physicalSize = const Size(1440, 1100);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        Map<String, dynamic>? sent;
        final store = signupStore(capture: (data) => sent = data);
        await openSignup(tester, store);
        await tester.tap(find.byKey(const Key('signup-role')));
        await tester.pumpAndSettle();
        await tester.tap(find.text(position.$2).last);
        await tester.pumpAndSettle();
        await fillSignup(tester);
        if (position.$1 == 'manager') {
          await tester.ensureVisible(find.text('Create account'));
          await tester.tap(find.text('Create account'));
          await tester.pumpAndSettle();
          expect(find.text('Enter the manager access code.'), findsOneWidget);
          expect(sent, isNull);
          await tester.enterText(
            find.byKey(const Key('signup-manager-code')),
            '1234',
          );
        } else {
          expect(find.byKey(const Key('signup-manager-code')), findsNothing);
        }
        await tester.ensureVisible(find.text('Create account'));
        await tester.tap(find.text('Create account'));
        await tester.pumpAndSettle();
        expect(sent?['role'], position.$1);
        expect(
          sent?['manager_code'],
          position.$1 == 'manager' ? '1234' : isNull,
        );
        expect(find.text(position.$3), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}

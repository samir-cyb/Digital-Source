import 'package:flutter/material.dart';

import '../models/models.dart';
import 'api.dart';

class AppStore extends ChangeNotifier {
  final ApiClient api;
  Person? user;
  List<Person> people = [];
  List<ProjectItem> projects = [];
  List<TaskItem> tasks = [];
  List<Map<String, dynamic>> materials = [],
      suppliers = [],
      money = [],
      reports = [],
      notifications = [];
  List<Map<String, dynamic>> plans = [];
  bool booting = true, loading = false;
  String? error;
  ThemeMode themeMode = ThemeMode.light;
  AppStore({ApiClient? api}) : api = api ?? ApiClient();
  String get role => user?.roles.firstOrNull ?? 'member';
  String get roleLabel => switch (role) {
    'manager' => 'Manager',
    'finance' => 'Finance',
    _ => 'Team member',
  };
  String get homeRoute => switch (role) {
    'manager' => '/manager',
    'finance' => '/finance',
    _ => '/my-work',
  };
  bool get canManage => role == 'manager';
  bool get canFinance => role == 'finance';
  bool get hasLeadProject =>
      role == 'member' && projects.any((p) => p.leadId == user?.id);
  bool get canSource => canManage || hasLeadProject;
  bool canManageProject(String id) =>
      canManage || (role == 'member' && project(id)?.leadId == user?.id);
  bool canAccess(String path) {
    if (path == '/manager') return canManage;
    if (path == '/my-work') return role == 'member';
    if (path == '/finance') return canFinance;
    if (path == '/team') return canManage;
    if (path == '/sourcing') return canSource;
    if (path == '/planning' || path == '/reports') return !canFinance;
    return true;
  }

  int get unread => notifications.where((n) => n['read'] != true).length;
  Future<void> restore() async {
    try {
      user = Person.fromJson(
        Map<String, dynamic>.from(await api.request('/auth/me')),
      );
      await reload();
    } on ApiError catch (e) {
      if (e.status != 401) error = e.message;
    } finally {
      booting = false;
      notifyListeners();
    }
  }

  Future<void> login(String email, String password) async {
    final j = await api.request(
      '/auth/login',
      method: 'POST',
      data: {'email': email, 'password': password},
    );
    api.token = j['token'];
    user = Person.fromJson(Map<String, dynamic>.from(j['user']));
    await reload();
  }

  Future<void> signup({
    required String name,
    required String email,
    required String password,
    required String title,
    required String department,
    required String role,
    String managerCode = "",
  }) async {
    final j = await api.request(
      '/auth/signup',
      method: 'POST',
      data: {
        'name': name,
        'email': email,
        'password': password,
        'title': title,
        'department': department,
        'role': role,
        if (role == 'manager') 'manager_code': managerCode,
      },
    );
    api.token = j['token'];
    user = Person.fromJson(Map<String, dynamic>.from(j['user']));
    await reload();
  }

  Future<void> reload() async {
    loading = true;
    error = null;
    notifyListeners();
    try {
      final j = await api.request('/workspace');
      user = Person.fromJson(Map<String, dynamic>.from(j['user']));
      people = (j['people'] as List)
          .map((x) => Person.fromJson(Map<String, dynamic>.from(x)))
          .toList();
      projects = (j['projects'] as List)
          .map((x) => ProjectItem.fromJson(Map<String, dynamic>.from(x)))
          .toList();
      tasks = (j['tasks'] as List)
          .map((x) => TaskItem.fromJson(Map<String, dynamic>.from(x)))
          .toList();
      List<Map<String, dynamic>> maps(String key) =>
          (j[key] as List).map((x) => Map<String, dynamic>.from(x)).toList();
      materials = maps('materials');
      suppliers = maps('suppliers');
      money = maps('money');
      reports = maps('reports');
      plans = (j['plans'] as List? ?? [])
          .map((x) => Map<String, dynamic>.from(x))
          .toList();
      notifications = maps('notifications');
    } on ApiError catch (e) {
      error = e.message;
      if (e.status == 401) {
        user = null;
        api.token = null;
      }
      rethrow;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  Future<void> mutate(
    String path,
    Map<String, dynamic> data, {
    String method = 'POST',
  }) async {
    try {
      await api.request(path, method: method, data: data);
      await reload();
    } on ApiError catch (e) {
      if (e.status == 401) {
        user = null;
        api.token = null;
        notifyListeners();
      }
      rethrow;
    }
  }

  Future<void> logout() async {
    await api.request('/auth/logout', method: 'POST');
    api.token = null;
    user = null;
    projects = [];
    tasks = [];
    people = [];
    money = [];
    materials = [];
    reports = [];
    notifications = [];
    plans = [];
    notifyListeners();
  }

  Person? person(String id) {
    for (final p in people) {
      if (p.id == id) return p;
    }
    return null;
  }

  ProjectItem? project(String id) {
    for (final p in projects) {
      if (p.id == id) return p;
    }
    return null;
  }

  int workload(String id) => tasks
      .where(
        (t) => t.assigneeId == id && !['done', 'cancelled'].contains(t.status),
      )
      .length;
  void setTheme(ThemeMode mode) {
    themeMode = mode;
    notifyListeners();
  }

  @override
  void dispose() {
    api.close();
    super.dispose();
  }
}

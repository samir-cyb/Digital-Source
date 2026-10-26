class Person {
  final String id, employeeId, name, email, title, department, avatar;
  final List<String> roles;
  Person.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      employeeId = j['employee_id'],
      name = j['name'],
      email = j['email'],
      title = j['title'],
      department = j['department'],
      avatar = j['avatar'] ?? '',
      roles = List<String>.from(j['roles']);
  String get firstName => name.split(' ').first;
  String get initials => name.split(' ').take(2).map((s) => s[0]).join();
  bool hasAny(List<String> allowed) => roles.any(allowed.contains);
}

class ProjectItem {
  final String id, name, client, site, phase, dueDate, image;
  final List<String> memberIds;
  final String? leadId;
  final Map<String, String> membershipRoles;
  final int progress, taskCount, completedCount, blockedCount;
  ProjectItem.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      name = j['name'],
      client = j['client'],
      site = j['site'],
      phase = j['phase'],
      dueDate = j['due_date'],
      image = j['image'] ?? '',
      memberIds = List<String>.from(j['member_ids']),
      leadId = j['lead_id'],
      membershipRoles = Map<String, String>.from(j['membership_roles'] ?? {}),
      progress = j['progress'],
      taskCount = j['task_count'],
      completedCount = j['completed_count'],
      blockedCount = j['blocked_count'];
}

class TaskItem {
  final String id, projectId, title, assigneeId, status, dueDate, priority;
  final String? blocker, reviewNote;
  final int version;
  TaskItem.fromJson(Map<String, dynamic> j)
    : id = j['id'],
      projectId = j['project_id'],
      title = j['title'],
      assigneeId = j['assignee_id'],
      status = j['status'],
      dueDate = j['due_date'],
      priority = j['priority'],
      blocker = j['blocker'],
      reviewNote = j['review_note'],
      version = j['version'];
  String get statusLabel => switch (status) {
    'todo' => 'To do',
    'in_progress' => 'In progress',
    'review' => 'Needs review',
    'blocked' => 'Blocked',
    'done' => 'Completed',
    _ => 'Cancelled',
  };
}

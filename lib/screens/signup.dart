import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/store.dart';
import '../core/theme.dart';
import '../ui/shell.dart';

class SignupScreen extends StatefulWidget {
  final AppStore store;
  const SignupScreen(this.store, {super.key});
  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final name = TextEditingController(),
      email = TextEditingController(),
      password = TextEditingController(),
      confirm = TextEditingController(),
      title = TextEditingController(),
      department = TextEditingController(),
      managerCode = TextEditingController();
  final form = GlobalKey<FormState>();
  bool busy = false, checking = true, hidePassword = true, hideConfirm = true;
  String role = "member";
  String? error, setupError;
  @override
  void initState() {
    super.initState();
    loadRegistration();
  }

  Future<void> loadRegistration() async {
    setState(() {
      checking = true;
      setupError = null;
    });
    try {
      final info = await widget.store.api.request('/auth/registration');
      if (info['database'] != 'sqlite') {
        throw Exception('The local workspace is not available.');
      }
    } catch (e) {
      if (mounted) setState(() => setupError = e.toString());
    } finally {
      if (mounted) setState(() => checking = false);
    }
  }

  @override
  void dispose() {
    for (final c in [
      name,
      email,
      password,
      confirm,
      title,
      department,
      managerCode,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> createAccount() async {
    if (!form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.signup(
        role: role,
        managerCode: managerCode.text,
        name: name.text,
        email: email.text,
        password: password.text,
        title: title.text.trim().isEmpty ? 'Team member' : title.text,
        department: department.text.trim().isEmpty
            ? 'General'
            : department.text,
      );
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void signIn() {
    final from = GoRouterState.of(context).uri.queryParameters['from'];
    context.go(
      from == null ? '/login' : '/login?from=${Uri.encodeComponent(from)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Expanded(
              flex: 6,
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(wide ? 40 : 24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: AutofillGroup(
                      child: Form(
                        key: form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                BrandMark(size: 42),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Digital Source',
                                    style: TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -.8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                            Text(
                              'Good work starts\nwith your people.',
                              style: Theme.of(context).textTheme.headlineLarge!
                                  .copyWith(fontSize: wide ? 34 : 30),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Create your account and find your place in the studio.',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                                fontSize: 13,
                                height: 1.7,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary
                                    .withValues(alpha: .06),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.badge_outlined,
                                    size: 19,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: checking
                                        ? const Text(
                                            'Checking workspace setup…',
                                            style: TextStyle(fontSize: 12),
                                          )
                                        : Text(
                                            'Choose your position. We will open the workspace built for your role.',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              height: 1.6,
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 20),
                            DropdownButtonFormField<String>(
                              key: const Key('signup-role'),
                              initialValue: role,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Your position',
                                prefixIcon: Icon(
                                  Icons.badge_outlined,
                                  size: 20,
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'manager',
                                  child: Text('Manager'),
                                ),
                                DropdownMenuItem(
                                  value: 'member',
                                  child: Text('Team member'),
                                ),
                                DropdownMenuItem(
                                  value: 'finance',
                                  child: Text('Finance'),
                                ),
                              ],
                              onChanged: busy
                                  ? null
                                  : (value) => setState(() {
                                      role = value!;
                                      managerCode.clear();
                                      error = null;
                                    }),
                            ),
                            const SizedBox(height: 14),
                            if (role == 'manager') ...[
                              TextFormField(
                                key: const Key('signup-manager-code'),
                                controller: managerCode,
                                obscureText: true,
                                decoration: const InputDecoration(
                                  labelText: 'Manager access code',
                                  prefixIcon: Icon(
                                    Icons.admin_panel_settings_outlined,
                                    size: 20,
                                  ),
                                ),
                                validator: (v) => v == null || v.isEmpty
                                    ? 'Enter the manager access code.'
                                    : null,
                              ),
                              const SizedBox(height: 14),
                            ],
                            TextFormField(
                              key: const Key('signup-name'),
                              controller: name,
                              textCapitalization: TextCapitalization.words,
                              autofillHints: const [AutofillHints.name],
                              decoration: const InputDecoration(
                                labelText: 'Full name',
                                prefixIcon: Icon(
                                  Icons.person_outline,
                                  size: 20,
                                ),
                              ),
                              validator: (v) => v == null || v.trim().length < 2
                                  ? 'Enter your full name.'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              key: const Key('signup-email'),
                              controller: email,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              decoration: const InputDecoration(
                                labelText: 'Work email',
                                prefixIcon: Icon(Icons.mail_outline, size: 20),
                              ),
                              validator: (v) =>
                                  v == null ||
                                      !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                          .hasMatch(v.trim())
                                  ? 'Enter a valid email address.'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            LayoutBuilder(
                              builder: (context, box) {
                                final job = TextFormField(
                                  key: const Key('signup-title'),
                                  controller: title,
                                  decoration: const InputDecoration(
                                    labelText: 'Job title (optional)',
                                    hintText: 'e.g. Interior designer',
                                  ),
                                );
                                final team = TextFormField(
                                  key: const Key('signup-department'),
                                  controller: department,
                                  decoration: const InputDecoration(
                                    labelText: 'Department (optional)',
                                    hintText: 'e.g. Design',
                                  ),
                                );
                                return box.maxWidth < 420
                                    ? Column(
                                        children: [
                                          job,
                                          const SizedBox(height: 14),
                                          team,
                                        ],
                                      )
                                    : Row(
                                        children: [
                                          Expanded(child: job),
                                          const SizedBox(width: 14),
                                          Expanded(child: team),
                                        ],
                                      );
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              key: const Key('signup-password'),
                              controller: password,
                              obscureText: hidePassword,
                              autofillHints: const [AutofillHints.newPassword],
                              enableSuggestions: false,
                              autocorrect: false,
                              decoration: InputDecoration(
                                labelText: 'Password',
                                helperText: 'Use at least 12 characters.',
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  size: 20,
                                ),
                                suffixIcon: IconButton(
                                  tooltip: hidePassword
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () => setState(
                                    () => hidePassword = !hidePassword,
                                  ),
                                  icon: Icon(
                                    hidePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 20,
                                  ),
                                ),
                              ),
                              validator: (v) =>
                                  v == null || v.trim().length < 12
                                  ? 'Use at least 12 characters.'
                                  : v.length > 128
                                  ? 'Use no more than 128 characters.'
                                  : null,
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              key: const Key('signup-confirm'),
                              controller: confirm,
                              obscureText: hideConfirm,
                              enableSuggestions: false,
                              autocorrect: false,
                              onFieldSubmitted: (_) {
                                if (!busy && !checking && setupError == null) {
                                  createAccount();
                                }
                              },
                              decoration: InputDecoration(
                                labelText: 'Confirm password',
                                prefixIcon: const Icon(
                                  Icons.lock_outline,
                                  size: 20,
                                ),
                                suffixIcon: IconButton(
                                  tooltip: hideConfirm
                                      ? 'Show confirmation'
                                      : 'Hide confirmation',
                                  onPressed: () => setState(
                                    () => hideConfirm = !hideConfirm,
                                  ),
                                  icon: Icon(
                                    hideConfirm
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 20,
                                  ),
                                ),
                              ),
                              validator: (v) => v != password.text
                                  ? 'Passwords do not match.'
                                  : v == null || v.isEmpty
                                  ? 'Confirm your password.'
                                  : null,
                            ),
                            if (error != null || setupError != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 16),
                                child: Semantics(
                                  liveRegion: true,
                                  child: Text(
                                    error ?? setupError!,
                                    style: const TextStyle(
                                      color: StudioColors.red,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),
                            if (setupError != null)
                              TextButton.icon(
                                onPressed: checking ? null : loadRegistration,
                                icon: const Icon(Icons.refresh, size: 16),
                                label: const Text('Retry connection'),
                              ),
                            const SizedBox(height: 22),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton(
                                onPressed:
                                    busy || checking || setupError != null
                                    ? null
                                    : createAccount,
                                child: busy
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Text('Create account'),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Center(
                              child: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  const Text(
                                    'Already have an account?',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                  TextButton(
                                    onPressed: busy ? null : signIn,
                                    child: const Text('Sign in'),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Icon(
                                  Icons.storage_outlined,
                                  size: 16,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Your account is saved in the local workspace on this computer.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (wide)
              Expanded(
                flex: 5,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          'assets/images/residence.jpg',
                          fit: BoxFit.cover,
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x00000000), Color(0xCC122B28)],
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 40,
                          right: 40,
                          bottom: 44,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'A place for\neveryone to build.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 40,
                                  height: 1.2,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -1.2,
                                ),
                              ),
                              SizedBox(height: 18),
                              Text(
                                'Bring your people together.\nGive every detail a clear direction.',
                                style: TextStyle(
                                  color: Color(0xFFE8F0EC),
                                  fontSize: 14,
                                  height: 1.8,
                                ),
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
      ),
    );
  }
}

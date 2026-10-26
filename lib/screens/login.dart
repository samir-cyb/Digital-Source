import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/store.dart';
import '../core/theme.dart';
import '../ui/components.dart';
import '../ui/shell.dart';

class LoginScreen extends StatefulWidget {
  final AppStore store;
  const LoginScreen(this.store, {super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController(), password = TextEditingController();
  final form = GlobalKey<FormState>();
  bool busy = false, hide = true;
  String? error;
  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> signIn() async {
    if (!form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await widget.store.login(email.text.trim(), password.text);
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void openSignup() {
    final from = GoRouterState.of(context).uri.queryParameters['from'];
    context.go(
      from == null ? '/signup' : '/signup?from=${Uri.encodeComponent(from)}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 72,
        title: const Row(
          children: [
            BrandMark(size: 30),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Digital Source',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: OutlinedButton.icon(
              onPressed: busy ? null : openSignup,
              icon: const Icon(Icons.person_add_alt_1_outlined, size: 18),
              label: const Text('Sign up'),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(28),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Form(
                      key: form,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 16),
                          Text(
                            'Welcome to\nyour workday.',
                            style: Theme.of(context).textTheme.headlineLarge!
                                .copyWith(fontSize: 38, letterSpacing: -1.2),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Your people, projects and next steps.\nTogether in one thoughtful workspace.',
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              height: 1.8,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 32),
                          TextFormField(
                            controller: email,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.username],
                            decoration: const InputDecoration(
                              labelText: 'Work email',
                              prefixIcon: Icon(Icons.mail_outline, size: 20),
                            ),
                            validator: (v) => v == null || !v.contains('@')
                                ? 'Enter your work email.'
                                : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: password,
                            obscureText: hide,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) {
                              if (!busy) signIn();
                            },
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                size: 20,
                              ),
                              suffixIcon: IconButton(
                                onPressed: () => setState(() => hide = !hide),
                                tooltip: hide
                                    ? 'Show password'
                                    : 'Hide password',
                                icon: Icon(
                                  hide
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 20,
                                ),
                              ),
                            ),
                            validator: (v) => v == null || v.isEmpty
                                ? 'Enter your password.'
                                : null,
                          ),
                          if (error != null || widget.store.error != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 16),
                              child: Text(
                                error ?? widget.store.error!,
                                style: const TextStyle(
                                  color: StudioColors.red,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          const SizedBox(height: 24),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: busy || widget.store.booting
                                  ? null
                                  : signIn,
                              child: busy || widget.store.booting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text('Sign in to your workspace'),
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'New to Digital Source? Create your account to get started.',
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                          Center(
                            child: TextButton(
                              onPressed: busy
                                  ? null
                                  : () {
                                      final from = GoRouterState.of(context)
                                          .uri
                                          .queryParameters['from'];
                                      context.go(
                                        from == null
                                            ? '/signup'
                                            : '/signup?from=${Uri.encodeComponent(from)}',
                                      );
                                    },
                              child: const Text('Create an account'),
                            ),
                          ),
                          const SizedBox(height: 48),
                          const StatusPill('Local development'),
                          const SizedBox(height: 12),
                          Text(
                            'Thoughtful spaces. Connected people.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (wide)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          'assets/images/studio.jpg',
                          fit: BoxFit.cover,
                        ),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x00000000), Color(0xBB122B28)],
                            ),
                          ),
                        ),
                        const Positioned(
                          left: 44,
                          right: 44,
                          bottom: 48,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Beautiful spaces.\nBetter together.',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 44,
                                  height: 1.15,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -1.5,
                                ),
                              ),
                              SizedBox(height: 18),
                              Text(
                                'From the first idea to the final detail,\ngive your team a clearer way forward.',
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

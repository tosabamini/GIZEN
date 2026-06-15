import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nicknameCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _tabs.addListener(() => setState(() => _error = null));
  }

  @override
  void dispose() {
    _tabs.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nicknameCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    final nickname = _nicknameCtrl.text.trim();

    String? err;
    if (_tabs.index == 0) {
      err = await AuthService.signIn(email, password);
    } else {
      if (nickname.isEmpty) {
        err = 'Please enter a nickname.';
      } else {
        err = await AuthService.register(email, password, nickname);
      }
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      _error = err;
    });
    if (err == null) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = AuthService.currentUser != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
        backgroundColor: const Color(0xFF00C853),
        foregroundColor: Colors.white,
      ),
      body: isLoggedIn ? _buildProfile() : _buildAuthForm(),
    );
  }

  Widget _buildProfile() {
    final user = AuthService.currentUser!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: const Color(0xFF00C853),
              child: Text(
                (user.displayName?.isNotEmpty == true
                    ? user.displayName![0]
                    : user.email?[0] ?? '?').toUpperCase(),
                style: const TextStyle(fontSize: 40, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              user.displayName ?? 'No nickname',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(user.email ?? '',
                style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () async {
                await AuthService.signOut();
                if (mounted) setState(() {});
              },
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Sign Out'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding:
                    const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthForm() {
    return Column(
      children: [
        TabBar(
          controller: _tabs,
          labelColor: const Color(0xFF00C853),
          indicatorColor: const Color(0xFF00C853),
          tabs: const [Tab(text: 'Login'), Tab(text: 'Register')],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 8),
                if (!AuthService.isAvailable)
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      border: Border.all(color: Colors.orange.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '⚠️ Firebase not configured yet.\nRun "flutterfire configure" to enable login.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                AnimatedBuilder(
                  animation: _tabs,
                  builder: (context2, child) => _tabs.index == 1
                      ? _field(_nicknameCtrl, 'Nickname', Icons.badge_rounded)
                      : const SizedBox.shrink(),
                ),
                _field(_emailCtrl, 'Email', Icons.email_rounded,
                    type: TextInputType.emailAddress),
                _field(_passwordCtrl, 'Password', Icons.lock_rounded,
                    obscure: true),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_error!,
                        style: const TextStyle(color: Colors.red)),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF00C853),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2.5))
                      : AnimatedBuilder(
                          animation: _tabs,
                          builder: (ctx2, child) => Text(
                            _tabs.index == 0 ? 'Login' : 'Create Account',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label,
    IconData icon, {
    TextInputType type = TextInputType.text,
    bool obscure = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextField(
        controller: ctrl,
        keyboardType: type,
        obscureText: obscure && _obscure,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: obscure
              ? IconButton(
                  icon: Icon(
                      _obscure ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _obscure = !_obscure),
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          filled: true,
          fillColor: Colors.grey[50],
        ),
      ),
    );
  }
}

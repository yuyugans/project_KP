import 'package:flutter/material.dart';

import '../database/admin_database.dart';

class LoginScreen extends StatefulWidget {
  final Widget destination;

  const LoginScreen({super.key, required this.destination});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoggingIn = false;
  bool _isCheckingAdmin = true;
  bool _isRegisterMode = false;
  bool _canSwitchAccountMode = false;
  String? _initializationError;

  @override
  void initState() {
    super.initState();
    _checkAdminAccount();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _checkAdminAccount() async {
    setState(() {
      _isCheckingAdmin = true;
      _initializationError = null;
    });
    try {
      final hasAdmin = await AdminDatabase.instance.hasAdminUser();
      if (!mounted) return;
      setState(() {
        _isRegisterMode = !hasAdmin;
        _canSwitchAccountMode = hasAdmin;
        _isCheckingAdmin = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isCheckingAdmin = false;
        _initializationError =
            'Tidak dapat membuka database akun admin: $error';
      });
    }
  }

  Future<void> _submit() async {
    if (_isCheckingAdmin ||
        _initializationError != null ||
        !_formKey.currentState!.validate()) {
      return;
    }

    if (_isRegisterMode &&
        _passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konfirmasi password tidak cocok')),
      );
      return;
    }

    setState(() => _isLoggingIn = true);
    try {
      if (_isRegisterMode) {
        await AdminDatabase.instance.createAdminUser(
          username: _usernameController.text,
          password: _passwordController.text,
        );
      } else {
        final isValid = await AdminDatabase.instance.verifyAdminCredentials(
          username: _usernameController.text,
          password: _passwordController.text,
        );
        if (!isValid) {
          if (!mounted) return;
          setState(() => _isLoggingIn = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Username atau password admin salah')),
          );
          return;
        }
      }

      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => widget.destination));
    } catch (error) {
      if (!mounted) return;
      setState(() => _isLoggingIn = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memproses akun admin: $error')),
      );
    }
  }

  String? _validatePassword(String? value) {
    final requiredError = _required(value, 'Password');
    if (requiredError != null) {
      return requiredError;
    }
    if (_isRegisterMode && (value ?? '').length < 8) {
      return 'Password harus minimal 8 karakter';
    }
    return null;
  }

  String? _required(String? value, String label) {
    return (value ?? '').trim().isEmpty ? '$label harus diisi' : null;
  }

  void _toggleAccountMode() {
    setState(() {
      _isRegisterMode = !_isRegisterMode;
      _confirmPasswordController.clear();
      _formKey.currentState?.reset();
    });
  }

  Widget _buildAccountForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _usernameController,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: (value) => _required(value, 'Username'),
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: _isRegisterMode
                ? TextInputAction.next
                : TextInputAction.done,
            onFieldSubmitted: _isRegisterMode ? null : (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _obscurePassword
                    ? 'Tampilkan password'
                    : 'Sembunyikan password',
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: _validatePassword,
          ),
          if (_isRegisterMode) ...[
            const SizedBox(height: 14),
            TextFormField(
              controller: _confirmPasswordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: const InputDecoration(
                labelText: 'Konfirmasi password',
                prefixIcon: Icon(Icons.lock_outline),
              ),
              validator: (value) => _required(value, 'Konfirmasi password'),
            ),
          ],
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoggingIn ? null : _submit,
            child: _isLoggingIn
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(_isRegisterMode ? 'Daftar akun admin' : 'Masuk'),
          ),
          if (_canSwitchAccountMode) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _isLoggingIn ? null : _toggleAccountMode,
              child: Text(
                _isRegisterMode
                    ? 'Sudah punya akun? Masuk'
                    : 'Belum punya akun? Daftar',
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAccountContent() {
    if (_isCheckingAdmin) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (_initializationError != null) {
      return Column(
        children: [
          Text(
            _initializationError!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _checkAdminAccount,
            child: const Text('Coba lagi'),
          ),
        ],
      );
    }
    return _buildAccountForm();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 64,
                      color: Color(0xFF5B9FEF),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _isRegisterMode ? 'Daftar Akun Admin' : 'Login Admin',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isRegisterMode
                          ? 'Buat akun admin untuk mengakses POS Inventory'
                          : 'Masuk untuk mengakses POS Inventory',
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Color(0xFF7B8494)),
                    ),
                    const SizedBox(height: 28),
                    _buildAccountContent(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

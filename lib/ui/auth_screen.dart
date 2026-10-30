import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';

class AuthScreen extends StatefulWidget {
  final VoidCallback onAuthenticated;

  const AuthScreen({super.key, required this.onAuthenticated});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _auth = AuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isSignUp = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailAuth() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter both email and password.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      if (_isSignUp) {
        await _auth.signUpWithEmail(
          email,
          password,
          name.isNotEmpty ? name : 'Campus Student',
        );
      } else {
        await _auth.signInWithEmail(email, password);
      }
      widget.onAuthenticated();
    } catch (e) {
      setState(() => _errorMessage = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleAuth() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _auth.signInWithGoogle();
      if (user != null) {
        widget.onAuthenticated();
      }
    } catch (e) {
      setState(() => _errorMessage = 'Google sign-in error: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.0, -0.4),
            radius: 1.4,
            colors: [Color(0xFF0D1F38), AppColors.background],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Logo / Emblem
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.cyberCyan.withValues(alpha: 0.10),
                      border: Border.all(color: AppColors.cyberCyan, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.cyberCyan.withValues(alpha: 0.20),
                          blurRadius: 28,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      size: 40,
                      color: AppColors.cyberCyan,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'SIGNALSAFE',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 3.0,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Campus Network Threat Protection',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Card
                  Card(
                    color: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(
                        color: AppColors.borderHighlight,
                        width: 1.5,
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 28,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Sign In / Sign Up Toggle
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElevated,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                _buildToggleTab('Sign In', !_isSignUp, () {
                                  setState(() => _isSignUp = false);
                                }),
                                _buildToggleTab('New Account', _isSignUp, () {
                                  setState(() => _isSignUp = true);
                                }),
                              ],
                            ),
                          ),
                          const SizedBox(height: 22),

                          // Error banner
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.threatRed.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.threatRed.withValues(
                                    alpha: 0.4,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.error_outline_rounded,
                                    size: 16,
                                    color: AppColors.threatRed,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.threatRed,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Name field (sign-up only)
                          if (_isSignUp) ...[
                            TextField(
                              controller: _nameController,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                labelText: 'Full Name',
                                prefixIcon: Icon(
                                  Icons.person_outline,
                                  size: 20,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // Email
                          TextField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email Address',
                              hintText: 'you@college.edu',
                              prefixIcon: Icon(
                                Icons.email_outlined,
                                size: 20,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),

                          // Password
                          TextField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(
                                Icons.lock_outline,
                                size: 20,
                              ),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 18,
                                ),
                                onPressed:
                                    () => setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),

                          // Primary CTA
                          ElevatedButton(
                            onPressed: _isLoading ? null : _handleEmailAuth,
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child:
                                _isLoading
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.black,
                                      ),
                                    )
                                    : Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _isSignUp
                                              ? Icons.person_add_rounded
                                              : Icons.login_rounded,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(
                                          _isSignUp
                                              ? 'CREATE ACCOUNT'
                                              : 'SIGN IN',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.8,
                                          ),
                                        ),
                                      ],
                                    ),
                          ),
                          const SizedBox(height: 18),

                          // OR divider
                          const Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 14),
                                child: Text(
                                  'OR',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textMuted,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // Google
                          OutlinedButton(
                            onPressed: _isLoading ? null : _handleGoogleAuth,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 16,
                              ),
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF1A1A1A),
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const _GoogleLogo(),
                                const SizedBox(width: 10),
                                const Flexible(
                                  child: Text(
                                    'Continue with Google',
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),
                  // Footer
                  const Text(
                    'Protected by SignalSafe • All accounts default to Student role',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
                      height: 1.4,
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

  Widget _buildToggleTab(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color:
                active
                    ? AppColors.cyberCyan.withValues(alpha: 0.18)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? AppColors.cyberCyan : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Google "G" logo — official asset from Google's branding kit
class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/google_g_logo.png',
      width: 20,
      height: 20,
    );
  }
}

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/auth_widgets.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'main_navigation.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Preenche o email e a palavra-passe.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(email: email, password: pass);
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigation()),
          (_) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = switch (e.code) {
          'user-not-found'     => 'Email não encontrado. Cria uma conta primeiro.',
          'wrong-password'     => 'Palavra-passe incorreta.',
          'invalid-credential' => 'Email ou palavra-passe incorretos.',
          'invalid-email'      => 'Email inválido.',
          'too-many-requests'  => 'Muitas tentativas. Tenta mais tarde.',
          _                    => 'Erro (${e.code}): ${e.message}',
        };
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Escreve o teu email acima primeiro.');
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Email de recuperação enviado! ✉️'),
          backgroundColor: Color(0xFF2E7D32),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      setState(() => _error = 'Erro ao enviar email. Verifica o endereço.');
    }
  }

  Future<void> _loginWithGoogle() async {
    setState(() { _loading = true; _error = null; });
    try {
      final cred = await AuthService.signInWithGoogle();
      if (cred == null) { setState(() => _loading = false); return; }
      // Cria documento no Firestore se for o primeiro login
      if (cred.user != null) {
        await UserService.createUserDocument(cred.user!);
      }
      if (mounted) {
        Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const MainNavigation()), (_) => false);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'popup-closed-by-user' || e.code == 'cancelled-popup-request') {
        // utilizador fechou o popup — ignora
      } else if (e.code == 'operation-not-allowed') {
        setState(() => _error = 'Google Sign-In não está ativado no Firebase (Authentication → Sign-in method).');
      } else {
        setState(() => _error = 'Erro Google (${e.code}).');
      }
    } catch (e) {
      setState(() => _error = 'Erro ao entrar com Google. Verifica a ligação.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              const Text('Entrar',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1)),
              const SizedBox(height: 6),
              const Text('Bem-vindo de volta 👋',
                style: TextStyle(fontSize: 15, color: Color(0xFF888888))),
              const SizedBox(height: 36),

              AuthLabel('Email'),
              const SizedBox(height: 8),
              AuthInput(controller: _emailCtrl, hint: 'o.teu@email.com',
                icon: Icons.mail_outline_rounded, keyboard: TextInputType.emailAddress),
              const SizedBox(height: 18),

              AuthLabel('Palavra-passe'),
              const SizedBox(height: 8),
              AuthInput(
                controller: _passCtrl,
                hint: '••••••••',
                icon: Icons.lock_outline_rounded,
                obscure: _obscure,
                suffix: IconButton(
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: const Color(0xFF666666), size: 20),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _forgotPassword,
                  child: const Text('Esqueceste a palavra-passe?',
                    style: TextStyle(color: Color(0xFF888888), fontSize: 13)),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 4),
                _ErrorBox(message: _error!),
              ],
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1A1A1A),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    disabledBackgroundColor: const Color(0xFF444444),
                  ),
                  child: _loading
                      ? const SizedBox(width: 20, height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF1A1A1A)))
                      : const Text('Entrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 24),

              const _Divider(),
              const SizedBox(height: 24),

              AuthSocialBtn(icon: Icons.g_mobiledata_rounded, label: 'Continuar com Google', onTap: _loginWithGoogle),
              const SizedBox(height: 32),

              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const RegisterScreen())),
                  child: RichText(
                    text: const TextSpan(
                      text: 'Não tens conta? ',
                      style: TextStyle(color: Color(0xFF666666), fontSize: 14),
                      children: [TextSpan(text: 'Cria uma agora',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFE05D5D).withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: Color(0xFFE05D5D), size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(message, style: const TextStyle(color: Color(0xFFE05D5D), fontSize: 13))),
      ],
    ),
  );
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => Row(children: const [
    Expanded(child: Divider(color: Color(0xFF333333))),
    Padding(padding: EdgeInsets.symmetric(horizontal: 14),
      child: Text('ou', style: TextStyle(color: Color(0xFF555555), fontSize: 13))),
    Expanded(child: Divider(color: Color(0xFF333333))),
  ]);
}

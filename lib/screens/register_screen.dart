import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../widgets/auth_widgets.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'main_navigation.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameCtrl     = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  bool _obscurePass    = true;
  bool _obscureConfirm = true;
  bool _loading        = false;
  bool _acceptedTerms  = false;
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose(); _usernameCtrl.dispose();
    _emailCtrl.dispose(); _passCtrl.dispose(); _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final name    = _nameCtrl.text.trim();
    final email   = _emailCtrl.text.trim();
    final pass    = _passCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (name.isEmpty || email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Preenche todos os campos obrigatórios.'); return;
    }
    if (pass != confirm) {
      setState(() => _error = 'As palavras-passe não coincidem.'); return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'A palavra-passe deve ter pelo menos 6 caracteres.'); return;
    }
    if (!_acceptedTerms) {
      setState(() => _error = 'Aceita os termos para continuar.'); return;
    }

    final username = _usernameCtrl.text.trim().replaceAll('@', '');
    if (username.isEmpty) {
      setState(() => _error = 'Escolhe um nome de utilizador.'); return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: pass);

      // Verifica se o nome de utilizador já existe (depois de autenticar)
      final handle = '@$username';
      final existing = await FirebaseFirestore.instance.collection('users')
          .where('handle', isEqualTo: handle).limit(1).get();
      if (existing.docs.isNotEmpty) {
        // Liberta o email criado e avisa
        await cred.user?.delete();
        setState(() { _loading = false; _error = 'O nome de utilizador "@$username" já está em uso. Escolhe outro.'; });
        return;
      }

      await cred.user?.updateDisplayName(name);
      await cred.user?.reload();
      if (cred.user != null) {
        await UserService.createUserDocument(cred.user!, name: name, username: handle);
      }
      if (mounted) {
        Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const MainNavigation()), (_) => false);
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = switch (e.code) {
          'email-already-in-use' => 'Este email já está registado.',
          'invalid-email'        => 'Email inválido.',
          'weak-password'        => 'Palavra-passe demasiado fraca.',
          _                      => 'Erro ao criar conta. Tenta novamente.',
        };
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _registerWithGoogle() async {
    setState(() { _loading = true; _error = null; });
    try {
      final cred = await AuthService.signInWithGoogle();
      if (cred == null) { setState(() => _loading = false); return; }
      if (cred.user != null) {
        await UserService.createUserDocument(cred.user!);
      }
      if (mounted) {
        Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const MainNavigation()), (_) => false);
      }
    } catch (e) {
      setState(() => _error = 'Erro ao entrar com Google. Tenta novamente.');
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
              const SizedBox(height: 8),
              const Text('Criar conta',
                style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1)),
              const SizedBox(height: 6),
              const Text('Junta-te à comunidade de leitores 📚',
                style: TextStyle(fontSize: 15, color: Color(0xFF888888))),
              const SizedBox(height: 32),

              AuthLabel('Nome completo'),
              const SizedBox(height: 8),
              AuthInput(controller: _nameCtrl, hint: 'O teu nome', icon: Icons.person_outline_rounded),
              const SizedBox(height: 16),

              AuthLabel('Nome de utilizador'),
              const SizedBox(height: 8),
              AuthInput(controller: _usernameCtrl, hint: '@nomeutilizador', icon: Icons.alternate_email_rounded),
              const SizedBox(height: 16),

              AuthLabel('Email'),
              const SizedBox(height: 8),
              AuthInput(controller: _emailCtrl, hint: 'o.teu@email.com',
                icon: Icons.mail_outline_rounded, keyboard: TextInputType.emailAddress),
              const SizedBox(height: 16),

              AuthLabel('Palavra-passe'),
              const SizedBox(height: 8),
              AuthInput(
                controller: _passCtrl,
                hint: 'Mínimo 6 caracteres',
                icon: Icons.lock_outline_rounded,
                obscure: _obscurePass,
                suffix: IconButton(
                  icon: Icon(_obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: const Color(0xFF666666), size: 20),
                  onPressed: () => setState(() => _obscurePass = !_obscurePass),
                ),
              ),
              const SizedBox(height: 16),

              AuthLabel('Confirmar palavra-passe'),
              const SizedBox(height: 8),
              AuthInput(
                controller: _confirmCtrl,
                hint: 'Repete a palavra-passe',
                icon: Icons.lock_outline_rounded,
                obscure: _obscureConfirm,
                suffix: IconButton(
                  icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: const Color(0xFF666666), size: 20),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
              const SizedBox(height: 20),

              // Checkbox de termos
              GestureDetector(
                onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
                child: Row(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      width: 22, height: 22,
                      decoration: BoxDecoration(
                        color: _acceptedTerms ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _acceptedTerms ? Colors.white : const Color(0xFF555555),
                          width: 2,
                        ),
                      ),
                      child: _acceptedTerms
                          ? const Icon(Icons.check_rounded, size: 14, color: Color(0xFF1A1A1A))
                          : null,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Aceito os Termos de Serviço e a Política de Privacidade',
                        style: TextStyle(color: Color(0xFF888888), fontSize: 13, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE05D5D).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Color(0xFFE05D5D), size: 16),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_error!,
                        style: const TextStyle(color: Color(0xFFE05D5D), fontSize: 13))),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _register,
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
                      : const Text('Criar conta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 24),

              Row(children: const [
                Expanded(child: Divider(color: Color(0xFF333333))),
                Padding(padding: EdgeInsets.symmetric(horizontal: 14),
                  child: Text('ou', style: TextStyle(color: Color(0xFF555555), fontSize: 13))),
                Expanded(child: Divider(color: Color(0xFF333333))),
              ]),
              const SizedBox(height: 24),

              AuthSocialBtn(icon: Icons.g_mobiledata_rounded, label: 'Continuar com Google', onTap: _registerWithGoogle),
              const SizedBox(height: 28),

              Center(
                child: GestureDetector(
                  onTap: () => Navigator.pushReplacement(context,
                    MaterialPageRoute(builder: (_) => const LoginScreen())),
                  child: RichText(
                    text: const TextSpan(
                      text: 'Já tens conta? ',
                      style: TextStyle(color: Color(0xFF666666), fontSize: 14),
                      children: [TextSpan(text: 'Entrar',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

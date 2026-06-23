import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import 'main_navigation.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final _phoneCtrl = TextEditingController(text: '+351 ');
  final _codeCtrl = TextEditingController();
  ConfirmationResult? _confirmation;
  bool _loading = false;
  bool _codeSent = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = _phoneCtrl.text.replaceAll(' ', '').trim();
    if (phone.length < 9) {
      setState(() => _error = 'Escreve um número válido com indicativo (ex: +351 912345678).');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final conf = await AuthService.sendPhoneCode(phone);
      setState(() { _confirmation = conf; _codeSent = true; });
    } on FirebaseAuthException catch (e) {
      setState(() {
        if (e.code == 'operation-not-allowed') {
          _error = 'Login por telemóvel não está ativado no Firebase.';
        } else if (e.code == 'billing-not-enabled') {
          _error = 'O envio de SMS exige o plano pago do Firebase. Usa um número de teste ou entra com email/Google.';
        } else {
          _error = 'Erro ao enviar o código (${e.code}).';
        }
      });
    } catch (e) {
      setState(() => _error = 'Erro ao enviar o código. Verifica o número.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyCode() async {
    final code = _codeCtrl.text.trim();
    if (code.length < 6 || _confirmation == null) {
      setState(() => _error = 'Escreve o código de 6 dígitos.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final cred = await _confirmation!.confirm(code);
      if (cred.user != null) await UserService.createUserDocument(cred.user!);
      if (mounted) {
        Navigator.pushAndRemoveUntil(context,
          MaterialPageRoute(builder: (_) => const MainNavigation()), (_) => false);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.code == 'invalid-verification-code'
          ? 'Código incorreto. Tenta de novo.'
          : 'Erro ao validar (${e.code}).');
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
              const Text('Entrar com telemóvel',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1)),
              const SizedBox(height: 6),
              Text(_codeSent ? 'Escreve o código que recebeste por SMS 📩' : 'Vamos enviar-te um código por SMS 📱',
                style: const TextStyle(fontSize: 15, color: Color(0xFF888888))),
              const SizedBox(height: 36),

              if (!_codeSent) ...[
                const Text('Número de telemóvel',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF888888))),
                const SizedBox(height: 8),
                _field(_phoneCtrl, 'Ex: +351 912 345 678', Icons.phone_outlined, TextInputType.phone),
              ] else ...[
                const Text('Código de verificação',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF888888))),
                const SizedBox(height: 8),
                _field(_codeCtrl, '6 dígitos', Icons.lock_outline_rounded, TextInputType.number),
              ],

              if (_error != null) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE05D5D).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: Color(0xFFE05D5D), size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: const TextStyle(color: Color(0xFFE05D5D), fontSize: 13))),
                  ]),
                ),
              ],
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity, height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : (_codeSent ? _verifyCode : _sendCode),
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
                      : Text(_codeSent ? 'Confirmar código' : 'Enviar código',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
              if (_codeSent) ...[
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: _loading ? null : () => setState(() { _codeSent = false; _codeCtrl.clear(); _error = null; }),
                    child: const Text('Mudar número', style: TextStyle(color: Color(0xFF888888))),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController c, String hint, IconData icon, TextInputType kb) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFF2A2A2A),
      borderRadius: BorderRadius.circular(14),
    ),
    child: TextField(
      controller: c,
      keyboardType: kb,
      style: const TextStyle(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFF666666), fontSize: 15),
        prefixIcon: Icon(icon, color: const Color(0xFF666666), size: 20),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
      ),
    ),
  );
}

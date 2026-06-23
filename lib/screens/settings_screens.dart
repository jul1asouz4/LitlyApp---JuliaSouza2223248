import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';

// Scaffold base reutilizável para as páginas de definições
class _SettingsPage extends StatelessWidget {
  final String title;
  final Widget child;
  const _SettingsPage({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBg(context),
      appBar: AppBar(
        backgroundColor: appSurface(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: appText(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(title, style: TextStyle(color: appText(context), fontWeight: FontWeight.w700, fontSize: 16)),
        centerTitle: true,
      ),
      body: child,
    );
  }
}

// ── Editar perfil ─────────────────────────────────────────────────────────────
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _handleCtrl = TextEditingController();
  final _bioCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(_uid).get();
    final d = doc.data() ?? {};
    _nameCtrl.text = d['name'] ?? '';
    _handleCtrl.text = (d['handle'] ?? d['username'] ?? '').toString().replaceAll('@', '');
    _bioCtrl.text = d['bio'] ?? '';
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final raw = _handleCtrl.text.trim().replaceAll('@', '');
    final handle = raw.isEmpty ? '@${name.toLowerCase().replaceAll(' ', '')}' : '@$raw';

    // Verifica que o nome de utilizador não está em uso por outra conta
    final dup = await FirebaseFirestore.instance.collection('users')
        .where('handle', isEqualTo: handle).limit(2).get();
    final takenByOther = dup.docs.any((d) => d.id != _uid);
    if (takenByOther) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('O nome de utilizador "$handle" já está em uso.'),
          backgroundColor: const Color(0xFFE05D5D), behavior: SnackBarBehavior.floating));
      }
      return;
    }

    await FirebaseFirestore.instance.collection('users').doc(_uid).set({
      'name': name,
      'nameLower': name.toLowerCase(),
      'handle': handle,
      'bio': _bioCtrl.text.trim(),
    }, SetOptions(merge: true));
    await FirebaseAuth.instance.currentUser?.updateDisplayName(name);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Perfil atualizado! ✅'), backgroundColor: Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsPage(
      title: 'Editar perfil',
      child: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A1A1A), strokeWidth: 2))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                const Text('Nome', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF888888))),
                const SizedBox(height: 6),
                _input(_nameCtrl, 'O teu nome'),
                const SizedBox(height: 16),
                const Text('Nome de utilizador', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF888888))),
                const SizedBox(height: 6),
                _input(_handleCtrl, 'nomeutilizador'),
                const SizedBox(height: 16),
                const Text('Bio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF888888))),
                const SizedBox(height: 6),
                _input(_bioCtrl, 'Fala sobre ti...', maxLines: 3),
                const SizedBox(height: 24),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1A1A), foregroundColor: Colors.white,
                      elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _input(TextEditingController c, String hint, {int maxLines = 1}) => Container(
    decoration: BoxDecoration(color: appSurface(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: appBorder(context))),
    child: TextField(
      controller: c, maxLines: maxLines,
      style: TextStyle(fontSize: 14, color: appText(context)),
      decoration: InputDecoration(hintText: hint, hintStyle: const TextStyle(color: Color(0xFFBBBBBB)),
        border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
    ),
  );
}

// ── Privacidade ───────────────────────────────────────────────────────────────
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    return _SettingsPage(
      title: 'Privacidade',
      child: StreamBuilder<DocumentSnapshot>(
        stream: ref.snapshots(),
        builder: (_, snap) {
          final d = snap.data?.data() as Map<String, dynamic>?;
          final isPrivate = d?['isPrivate'] ?? false;
          final showReading = d?['showReading'] ?? true;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _switchTile('Conta privada', 'Só seguidores aprovados veem os teus posts',
                isPrivate, (v) async {
                  await ref.set({'isPrivate': v}, SetOptions(merge: true));
                  // Atualiza os posts já existentes para respeitarem a nova privacidade
                  final myPosts = await FirebaseFirestore.instance.collection('posts')
                      .where('authorId', isEqualTo: uid).get();
                  final batch = FirebaseFirestore.instance.batch();
                  for (final p in myPosts.docs) {
                    batch.set(p.reference, {'authorPrivate': v}, SetOptions(merge: true));
                  }
                  await batch.commit();
                }),
              _switchTile('Mostrar estado de leitura', 'Permite que outros vejam o livro que estás a ler',
                showReading, (v) => ref.set({'showReading': v}, SetOptions(merge: true))),
            ],
          );
        },
      ),
    );
  }
}

// ── Notificações ──────────────────────────────────────────────────────────────
class NotificationsSettingsScreen extends StatelessWidget {
  const NotificationsSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final ref = FirebaseFirestore.instance.collection('users').doc(uid);
    return _SettingsPage(
      title: 'Notificações',
      child: StreamBuilder<DocumentSnapshot>(
        stream: ref.snapshots(),
        builder: (_, snap) {
          final d = snap.data?.data() as Map<String, dynamic>?;
          final prefs = (d?['notifPrefs'] as Map?) ?? {};
          Widget t(String key, String title) => _switchTile(title, '',
            prefs[key] ?? true, (v) => ref.set({'notifPrefs': {key: v}}, SetOptions(merge: true)));
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              t('follows', 'Novos seguidores'),
              t('likes', 'Gostos nos meus posts'),
              t('comments', 'Comentários'),
              t('messages', 'Mensagens'),
            ],
          );
        },
      ),
    );
  }
}

// ── Aparência ─────────────────────────────────────────────────────────────────
class AppearanceScreen extends StatelessWidget {
  const AppearanceScreen({super.key});

  Future<void> _setMode(ThemeMode mode) async {
    themeNotifier.value = mode;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await FirebaseFirestore.instance.collection('users').doc(uid)
          .set({'darkMode': mode == ThemeMode.dark}, SetOptions(merge: true));
    }
  }

  @override
  Widget build(BuildContext context) => _SettingsPage(
    title: 'Aparência',
    child: ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, mode, __) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          GestureDetector(
            onTap: () => _setMode(ThemeMode.light),
            child: _radioTile('☀️  Claro', mode != ThemeMode.dark),
          ),
          GestureDetector(
            onTap: () => _setMode(ThemeMode.dark),
            child: _radioTile('🌙  Escuro', mode == ThemeMode.dark),
          ),
          const Padding(padding: EdgeInsets.all(16),
            child: Text('Escolhe o tema da aplicação. A tua preferência fica guardada.',
              style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 13))),
        ],
      ),
    ),
  );
}

// ── Língua ────────────────────────────────────────────────────────────────────
class LanguageScreen extends StatelessWidget {
  const LanguageScreen({super.key});
  @override
  Widget build(BuildContext context) => _SettingsPage(
    title: 'Língua',
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _radioTile('🇵🇹  Português', true),
        _radioTile('🇬🇧  English (em breve)', false),
        _radioTile('🇪🇸  Español (em breve)', false),
      ],
    ),
  );
}

// ── Centro de ajuda ───────────────────────────────────────────────────────────
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final faqs = [
      ('Como adiciono um livro à minha biblioteca?', 'Vai a Pesquisar, escolhe um livro e marca como "A ler", "Quero ler" ou "Lido".'),
      ('Como sigo alguém?', 'Abre o perfil da pessoa e toca em "Seguir". Ela aparecerá nas tuas bolinhas no topo.'),
      ('Como partilho o que estou a ler?', 'Toca na tua bolinha no topo do feed e cria um story com o livro.'),
      ('Como bloqueio alguém?', 'No perfil da pessoa, toca nos três pontos → Bloquear. Vês os bloqueados em Definições → Contas bloqueadas.'),
    ];
    return _SettingsPage(
      title: 'Centro de ajuda',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: faqs.map((f) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(color: appSurface(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: appBorder(context))),
          child: ExpansionTile(
            shape: const Border(),
            title: Text(f.$1, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: appText(context))),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            children: [Align(alignment: Alignment.centerLeft, child: Text(f.$2, style: const TextStyle(fontSize: 13, color: Color(0xFF666666), height: 1.5)))],
          ),
        )).toList(),
      ),
    );
  }
}

// ── Reportar problema ─────────────────────────────────────────────────────────
class ReportProblemScreen extends StatefulWidget {
  const ReportProblemScreen({super.key});
  @override
  State<ReportProblemScreen> createState() => _ReportProblemScreenState();
}

class _ReportProblemScreenState extends State<ReportProblemScreen> {
  final _ctrl = TextEditingController();
  bool _sending = false;

  Future<void> _send() async {
    if (_ctrl.text.trim().isEmpty) return;
    setState(() => _sending = true);
    await FirebaseFirestore.instance.collection('feedback').add({
      'userId': FirebaseAuth.instance.currentUser?.uid,
      'message': _ctrl.text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Obrigado pelo teu feedback! 🙏'), backgroundColor: Color(0xFF2E7D32),
        behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) => _SettingsPage(
    title: 'Reportar problema',
    child: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Descreve o problema que encontraste:', style: TextStyle(fontSize: 14, color: Color(0xFF555555))),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(color: appSurface(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: appBorder(context))),
          child: TextField(
            controller: _ctrl, maxLines: 6,
            decoration: const InputDecoration(hintText: 'O que correu mal?', hintStyle: TextStyle(color: Color(0xFFBBBBBB)),
              border: InputBorder.none, contentPadding: EdgeInsets.all(14)),
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(height: 48, child: ElevatedButton(
          onPressed: _sending ? null : _send,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1A1A1A), foregroundColor: Colors.white,
            elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          child: const Text('Enviar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
        )),
      ],
    ),
  );
}

// ── Sobre o Litly ─────────────────────────────────────────────────────────────
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});
  @override
  Widget build(BuildContext context) => _SettingsPage(
    title: 'Sobre o Litly',
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('📚', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 16),
            Text('Litly', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: appText(context))),
            const SizedBox(height: 6),
            const Text('Versão 1.0.0', style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
            const SizedBox(height: 20),
            const Text('A rede social para quem adora ler.\nPartilha leituras, segue leitores e descobre o teu próximo livro favorito.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 14, color: Color(0xFF666666), height: 1.6)),
            const SizedBox(height: 24),
            const Text('Feito com 💛 para a comunidade de leitores', style: TextStyle(fontSize: 12, color: Color(0xFFAAAAAA))),
          ],
        ),
      ),
    ),
  );
}

// ── Helpers partilhados ───────────────────────────────────────────────────────
class _switchTile extends StatelessWidget {
  final String title, subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _switchTile(this.title, this.subtitle, this.value, this.onChanged);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    decoration: BoxDecoration(color: appSurface(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: appBorder(context))),
    child: SwitchListTile(
      value: value,
      onChanged: onChanged,
      activeColor: const Color(0xFF4CAF50),
      title: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: appText(context))),
      subtitle: subtitle.isNotEmpty ? Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF999999))) : null,
    ),
  );
}

class _radioTile extends StatelessWidget {
  final String label;
  final bool selected;
  const _radioTile(this.label, this.selected);
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    decoration: BoxDecoration(color: appSurface(context), borderRadius: BorderRadius.circular(12), border: Border.all(color: appBorder(context))),
    child: ListTile(
      title: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: appText(context))),
      trailing: selected ? const Icon(Icons.check_circle, color: Color(0xFF2E7D32)) : null,
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/chat_service.dart';
import '../services/user_service.dart';
import 'other_user_profile_screen.dart';
import '../theme.dart';


class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _myId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  void _openNewChat(BuildContext context) {
    final searchCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: appSurface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (_, setModal) {
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            expand: false,
            builder: (_, scrollCtrl) => Column(
              children: [
                Container(width: 36, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 12),
                  decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2))),
                const Padding(
                  padding: EdgeInsets.only(bottom: 12),
                  child: Text('Nova conversa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(color: const Color(0xFFF0F0F0), borderRadius: BorderRadius.circular(12)),
                    child: TextField(
                      controller: searchCtrl,
                      autofocus: true,
                      onChanged: (_) => setModal(() {}),
                      decoration: const InputDecoration(
                        hintText: 'Pesquisar utilizadores...',
                        hintStyle: TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
                        prefixIcon: Icon(Icons.search, color: Color(0xFFAAAAAA), size: 18),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 11),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: searchCtrl.text.trim().length < 2
                      ? const Center(child: Text('Escreve pelo menos 2 letras', style: TextStyle(color: Color(0xFFAAAAAA))))
                      : StreamBuilder<QuerySnapshot>(
                          stream: FirebaseFirestore.instance.collection('users')
                              .where('nameLower', isGreaterThanOrEqualTo: searchCtrl.text.trim().toLowerCase())
                              .where('nameLower', isLessThan: '${searchCtrl.text.trim().toLowerCase()}z')
                              .limit(20).snapshots(),
                          builder: (_, snap) {
                            final docs = snap.data?.docs.where((d) => d.id != _myId).toList() ?? [];
                            if (docs.isEmpty) return const Center(child: Text('Nenhum utilizador encontrado', style: TextStyle(color: Color(0xFFAAAAAA))));
                            return ListView.builder(
                              controller: scrollCtrl,
                              itemCount: docs.length,
                              itemBuilder: (_, i) {
                                final u = docs[i].data() as Map<String, dynamic>;
                                final name = u['name'] ?? 'Utilizador';
                                final photo = u['photoUrl'] ?? '';
                                final letter = name.isNotEmpty ? name[0].toUpperCase() : 'U';
                                return ListTile(
                                  leading: _UserAvatar(photoUrl: photo, letter: letter, radius: 22),
                                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  subtitle: Text(u['handle'] ?? '', style: const TextStyle(color: Color(0xFF999999), fontSize: 12)),
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => ChatScreen(name: name, avatar: letter, otherId: docs[i].id, otherPhotoUrl: photo),
                                    ));
                                  },
                                );
                              },
                            );
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inDays == 0) return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
    if (diff.inDays == 1) return 'Ontem';
    if (diff.inDays < 7) {
      const days = ['Seg', 'Ter', 'Qua', 'Qui', 'Sex', 'Sáb', 'Dom'];
      return days[dt.weekday - 1];
    }
    return '${dt.day}/${dt.month}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBg(context),
      body: SafeArea(
        child: Column(
          children: [
            // AppBar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Mensagens',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: appText(context))),
                  ),
                  GestureDetector(
                    onTap: () => _openNewChat(context),
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: appSurface(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: appBorder(context)),
                      ),
                      child: Icon(Icons.edit_outlined, size: 18, color: appText(context)),
                    ),
                  ),
                ],
              ),
            ),

            // Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 38,
                decoration: BoxDecoration(color: isDark(context) ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE), borderRadius: BorderRadius.circular(10)),
                child: TabBar(
                  controller: _tabCtrl,
                  indicator: BoxDecoration(
                    color: appSurface(context),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4, offset: const Offset(0, 1))],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: appText(context),
                  unselectedLabelColor: const Color(0xFF888888),
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                  dividerColor: Colors.transparent,
                  tabs: [
                    const Tab(text: 'Mensagens'),
                    Tab(
                      child: StreamBuilder<QuerySnapshot>(
                        stream: ChatService.myConversationsStream(_myId),
                        builder: (_, snap) {
                          final n = (snap.data?.docs ?? []).where((d) {
                            final m = d.data() as Map;
                            return m['pending'] == true && m['requestedBy'] != _myId;
                          }).length;
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text('Pedidos'),
                              if (n > 0) ...[
                                const SizedBox(width: 5),
                                Container(
                                  width: 17, height: 17,
                                  decoration: const BoxDecoration(color: Color(0xFFE05D5D), shape: BoxShape.circle),
                                  child: Center(child: Text('$n',
                                    style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700))),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Stories de quem segues (anel colorido só se tiverem story)
            _StoriesRow(myId: _myId),
            const SizedBox(height: 10),

            // Conteúdo
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  // Tab Mensagens — lê do Firestore
                  StreamBuilder<QuerySnapshot>(
                    stream: ChatService.myConversationsStream(_myId),
                    builder: (context, snap) {
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Color(0xFF1A1A1A), strokeWidth: 2));
                      }
                      final docs = (snap.data?.docs ?? [])
                          // Esconde conversas falsas antigas (criadas a partir de pedidos fictícios)
                          .where((d) => !(d.data() as Map)['participants'].toString().contains('req_'))
                          // Esconde pedidos de mensagem que EU recebi (vão para a aba Pedidos)
                          .where((d) {
                            final m = d.data() as Map;
                            return m['pending'] != true || m['requestedBy'] == _myId;
                          })
                          .toList()
                        ..sort((a, b) {
                          final at = (a.data() as Map)['lastTimestamp'] as Timestamp?;
                          final bt = (b.data() as Map)['lastTimestamp'] as Timestamp?;
                          if (at == null && bt == null) return 0;
                          if (at == null) return 1;
                          if (bt == null) return -1;
                          return bt.compareTo(at);
                        });
                      if (docs.isEmpty) {
                        return const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.chat_bubble_outline_rounded, size: 48, color: Color(0xFFDDDDDD)),
                              SizedBox(height: 12),
                              Text('Sem conversas ainda.\nComeça a falar com alguém! 👋',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 14)),
                            ],
                          ),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                        itemCount: docs.length,
                        itemBuilder: (_, i) {
                          final data = docs[i].data() as Map<String, dynamic>;
                          final otherId = (data['participants'] as List)
                              .firstWhere((p) => p != _myId, orElse: () => '');
                          final lastMsg = data['lastMessage'] ?? '';
                          final lastTs = data['lastTimestamp'] as Timestamp?;
                          // Resolve o nome/foto do OUTRO participante a partir dos mapas
                          final names = (data['names'] as Map?) ?? {};
                          final photos = (data['photos'] as Map?) ?? {};
                          final otherName = (names[otherId] ?? data['otherName'] ?? 'Utilizador').toString();
                          final otherPhoto = (photos[otherId] ?? data['otherPhotoUrl'] ?? '').toString();
                          final otherAvatar = (otherName.isNotEmpty ? otherName[0] : 'U').toUpperCase();
                          return _ConvoTile(
                            name: otherName,
                            avatar: otherAvatar,
                            lastMsg: lastMsg,
                            time: _formatTime(lastTs),
                            otherId: otherId,
                            otherPhotoUrl: otherPhoto,
                          );
                        },
                      );
                    },
                  ),
                  // Tab Pedidos — pedidos de mensagem recebidos (pending && requestedBy != eu)
                  StreamBuilder<QuerySnapshot>(
                    stream: ChatService.myConversationsStream(_myId),
                    builder: (_, snap) {
                      final reqs = (snap.data?.docs ?? []).where((d) {
                        final m = d.data() as Map;
                        return m['pending'] == true && m['requestedBy'] != _myId;
                      }).toList();
                      if (reqs.isEmpty) {
                        return const Center(child: Text('Sem pedidos de mensagem.',
                          style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 14)));
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: reqs.length,
                        itemBuilder: (_, i) {
                          final cid = reqs[i].id;
                          final data = reqs[i].data() as Map<String, dynamic>;
                          final otherId = (data['participants'] as List).firstWhere((p) => p != _myId, orElse: () => '');
                          final names = (data['names'] as Map?) ?? {};
                          final photos = (data['photos'] as Map?) ?? {};
                          final name = (names[otherId] ?? 'Utilizador').toString();
                          final photo = (photos[otherId] ?? '').toString();
                          final preview = (data['lastMessage'] ?? '').toString();
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: appSurface(context), borderRadius: BorderRadius.circular(14), border: Border.all(color: appBorder(context))),
                            child: Row(children: [
                              _UserAvatar(photoUrl: photo, letter: name.isNotEmpty ? name[0].toUpperCase() : 'U', radius: 22),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: appText(context))),
                                Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
                              ])),
                              Column(children: [
                                GestureDetector(
                                  onTap: () async { await ChatService.acceptMessageRequest(cid); _tabCtrl.animateTo(0); },
                                  child: Container(height: 30, padding: const EdgeInsets.symmetric(horizontal: 12),
                                    decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(8)),
                                    child: const Center(child: Text('Aceitar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)))),
                                ),
                                const SizedBox(height: 4),
                                GestureDetector(
                                  onTap: () => ChatService.rejectMessageRequest(cid),
                                  child: Text('Rejeitar', style: TextStyle(fontSize: 11, color: appText(context).withValues(alpha: 0.6))),
                                ),
                              ]),
                            ]),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tile de conversa (lê última mensagem do Firestore) ────────────────────────
class _ConvoTile extends StatelessWidget {
  final String name, avatar, lastMsg, time, otherId, otherPhotoUrl;
  const _ConvoTile({
    required this.name, required this.avatar, required this.lastMsg,
    required this.time, required this.otherId, required this.otherPhotoUrl,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => ChatScreen(name: name, avatar: avatar, otherId: otherId, otherPhotoUrl: otherPhotoUrl),
        ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: appSurface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: appBorder(context)),
        ),
        child: StreamBuilder<DocumentSnapshot>(
          stream: otherId.isEmpty ? null
              : FirebaseFirestore.instance.collection('users').doc(otherId).snapshots(),
          builder: (_, us) {
            // Conta apagada
            final deleted = us.hasData && us.data?.exists == false;
            final ud = us.data?.data() as Map<String, dynamic>?;
            final p = deleted ? '' : (ud?['photoUrl'] ?? otherPhotoUrl).toString();
            final displayName = deleted ? 'Conta desativada' : name;
            return Row(
              children: [
                deleted
                    ? const CircleAvatar(radius: 24, backgroundColor: Color(0xFFCCCCCC),
                        child: Icon(Icons.person_off_rounded, color: Colors.white, size: 22))
                    : _UserAvatar(photoUrl: p, letter: avatar, radius: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayName, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                        color: deleted ? const Color(0xFF999999) : appText(context))),
                      const SizedBox(height: 2),
                      Text(deleted ? 'Esta conta já não existe' : lastMsg, maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF999999))),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(time, style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA))),
              ],
            );
          },
        ),
      ),
    );
  }
}


// ── Ecrã de chat individual (Firestore) ───────────────────────────────────────
class ChatScreen extends StatefulWidget {
  final String name, avatar, otherId, otherPhotoUrl;
  const ChatScreen({super.key, required this.name, required this.avatar, required this.otherId, required this.otherPhotoUrl});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _ctrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  late final String _cid;
  late final String _myId;
  String _otherPhoto = '';
  bool _deleted = false;

  final _suggestions = ['📖 Ainda não!', '😍 Adorei!', '⭐ 5 estrelas!', '👎 Não gostei', '📚 Recomendas outro?'];

  @override
  void initState() {
    super.initState();
    _myId = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
    _cid = ChatService.chatId(widget.otherId);
    _otherPhoto = widget.otherPhotoUrl;
    _loadOtherPhoto();
  }

  Future<void> _loadOtherPhoto() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.otherId).get();
      if (!doc.exists) { if (mounted) setState(() => _deleted = true); return; }
      final p = (doc.data()?['photoUrl'] ?? '').toString();
      if (p.isNotEmpty && mounted) setState(() => _otherPhoto = p);
    } catch (_) {}
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _send(String text) async {
    final t = text.trim();
    if (t.isEmpty) return;
    HapticFeedback.lightImpact();
    _ctrl.clear();
    await ChatService.sendMessage(_cid, t, otherName: widget.name, otherPhotoUrl: _otherPhoto);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  void _openMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: appSurface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4,
              margin: const EdgeInsets.only(top: 10, bottom: 12),
              decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded, color: Color(0xFF1A1A1A)),
              title: Text('Ver perfil de ${widget.name}'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(
                  builder: (_) => OtherUserProfileScreen(userId: widget.otherId, name: widget.name, avatar: widget.avatar, photoUrl: widget.otherPhotoUrl),
                ));
              },
            ),
            ListTile(
              leading: const Icon(Icons.volume_off_rounded, color: Color(0xFF555555)),
              title: const Text('Silenciar conversa'),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Conversa silenciada'), backgroundColor: Color(0xFF333333), behavior: SnackBarBehavior.floating));
              },
            ),
            ListTile(
              leading: const Icon(Icons.block_rounded, color: Color(0xFFE05D5D)),
              title: Text('Bloquear ${widget.name}', style: const TextStyle(color: Color(0xFFE05D5D))),
              onTap: () {
                Navigator.pop(context);
                _confirmBlock();
              },
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined, color: Color(0xFFE05D5D)),
              title: const Text('Reportar utilizador', style: TextStyle(color: Color(0xFFE05D5D))),
              onTap: () {
                Navigator.pop(context);
                _openReport();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFF999999)),
              title: const Text('Apagar conversa', style: TextStyle(color: Color(0xFF999999))),
              onTap: () { Navigator.pop(context); Navigator.pop(context); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _confirmBlock() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: appSurface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Bloquear ${widget.name}?', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        content: const Text('Esta pessoa não poderá enviar-te mensagens nem ver o teu perfil.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: Color(0xFF888888)))),
          TextButton(
            onPressed: () async {
              await UserService.blockUser(widget.otherId);
              if (mounted) {
                Navigator.pop(context);
                Navigator.pop(context);
              }
            },
            child: const Text('Bloquear', style: TextStyle(color: Color(0xFFE05D5D), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _openReport() {
    String? _reason;
    showModalBottomSheet(
      context: context,
      backgroundColor: appSurface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (_, setModal) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2)))),
              const Text('Reportar utilizador', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Qual o motivo?', style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
              const SizedBox(height: 14),
              ...['Spam', 'Comportamento abusivo', 'Conteúdo inapropriado', 'Perfil falso', 'Outro'].map((r) =>
                RadioListTile<String>(
                  value: r, groupValue: _reason,
                  onChanged: (v) => setModal(() => _reason = v),
                  title: Text(r, style: const TextStyle(fontSize: 14)),
                  activeColor: const Color(0xFF1A1A1A),
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                )),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 46,
                child: ElevatedButton(
                  onPressed: _reason == null ? null : () async {
                    await UserService.reportUser(widget.otherId, _reason!);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text('Reportado. Obrigado pelo feedback.'),
                      backgroundColor: Color(0xFF333333), behavior: SnackBarBehavior.floating));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A), foregroundColor: Colors.white,
                    elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    disabledBackgroundColor: const Color(0xFFCCCCCC),
                  ),
                  child: const Text('Enviar reporte', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(Timestamp? ts) {
    if (ts == null) return '';
    final dt = ts.toDate();
    return '${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBg(context),
      appBar: AppBar(
        backgroundColor: appSurface(context),
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: appText(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: GestureDetector(
          onTap: _deleted ? null : () => Navigator.push(context, MaterialPageRoute(
            builder: (_) => OtherUserProfileScreen(userId: widget.otherId, name: widget.name, avatar: widget.avatar, photoUrl: widget.otherPhotoUrl),
          )),
          child: Row(
            children: [
              _deleted
                  ? const CircleAvatar(radius: 18, backgroundColor: Color(0xFFCCCCCC),
                      child: Icon(Icons.person_off_rounded, color: Colors.white, size: 18))
                  : _UserAvatar(photoUrl: _otherPhoto, letter: widget.avatar, radius: 18),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_deleted ? 'Conta desativada' : widget.name,
                    style: TextStyle(color: _deleted ? const Color(0xFF999999) : appText(context), fontWeight: FontWeight.w700, fontSize: 15)),
                  Text(_deleted ? 'Esta conta já não existe' : 'Toca para ver o perfil',
                    style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 10)),
                ],
              ),
            ],
          ),
        ),
        actions: [
          IconButton(icon: Icon(Icons.more_vert, color: appText(context), size: 22), onPressed: _openMenu),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: appBorder(context))),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: ChatService.messagesStream(_cid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF1A1A1A), strokeWidth: 2));
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _UserAvatar(photoUrl: _otherPhoto, letter: widget.avatar, radius: 32),
                        const SizedBox(height: 12),
                        Text(widget.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: appText(context))),
                        const SizedBox(height: 8),
                        const Text('Sem mensagens ainda.\nSê o primeiro a escrever! 👋',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 14)),
                      ],
                    ),
                  );
                }
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_scrollCtrl.hasClients) {
                    _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
                  }
                });
                return ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final data = docs[i].data() as Map<String, dynamic>;
                    final isMe = data['senderId'] == _myId;
                    final ts = data['timestamp'] as Timestamp?;
                    return _Bubble(text: data['text'] ?? '', isMe: isMe, time: _formatTime(ts));
                  },
                );
              },
            ),
          ),

          // Sugestões rápidas
          SizedBox(
            height: 36,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: _suggestions.map((s) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => _send(s),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: appSurface(context), borderRadius: BorderRadius.circular(18), border: Border.all(color: appBorder(context))),
                    child: Text(s, style: TextStyle(fontSize: 12, color: appText(context))),
                  ),
                ),
              )).toList(),
            ),
          ),
          const SizedBox(height: 8),

          // Input
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(color: appSurface(context), borderRadius: BorderRadius.circular(24), border: Border.all(color: appBorder(context))),
                    child: TextField(
                      controller: _ctrl,
                      maxLines: null,
                      style: TextStyle(fontSize: 14, color: appText(context)),
                      decoration: const InputDecoration(
                        hintText: 'Escrever mensagem...',
                        hintStyle: TextStyle(color: Color(0xFFBBBBBB), fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: _send,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _send(_ctrl.text),
                  child: Container(
                    width: 44, height: 44,
                    decoration: const BoxDecoration(color: Color(0xFF1A1A1A), shape: BoxShape.circle),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bolha de mensagem ─────────────────────────────────────────────────────────
class _Bubble extends StatelessWidget {
  final String text, time;
  final bool isMe;
  const _Bubble({required this.text, required this.isMe, required this.time});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              Container(
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.68),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe
                      ? (isDark(context) ? const Color(0xFF3A3A3A) : const Color(0xFF1A1A1A))
                      : appSurface(context),
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18), topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                  border: isMe ? null : Border.all(color: appBorder(context)),
                ),
                child: Text(text, style: TextStyle(fontSize: 14, color: isMe ? Colors.white : appText(context), height: 1.4)),
              ),
              const SizedBox(height: 2),
              Text(time, style: const TextStyle(fontSize: 10, color: Color(0xFFBBBBBB))),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Avatar com foto ou letra ──────────────────────────────────────────────────
class _UserAvatar extends StatelessWidget {
  final String photoUrl, letter;
  final double radius;
  const _UserAvatar({required this.photoUrl, required this.letter, required this.radius});

  @override
  Widget build(BuildContext context) {
    final img = avatarProvider(photoUrl);
    if (img != null) {
      return CircleAvatar(radius: radius, backgroundImage: img, onBackgroundImageError: (_, __) {});
    }
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFF1A1A1A),
      child: Text(letter, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: radius * 0.7)),
    );
  }
}


// ── Linha de stories (na aba Mensagens) ───────────────────────────────────────
class _StoriesRow extends StatelessWidget {
  final String myId;
  const _StoriesRow({required this.myId});

  void _openStory(BuildContext context, String uid, Map<String, dynamic> u) {
    final name = (u['name'] ?? 'Utilizador').toString();
    final photo = (u['photoUrl'] ?? '').toString();
    final letter = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    final showReading = u['showReading'] != false;
    final currentBook = showReading ? (u['currentBook'] ?? '').toString() : '';
    final status = (u['readingStatus'] ?? '').toString();
    showModalBottomSheet(
      context: context,
      backgroundColor: appSurface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2))),
          _UserAvatar(photoUrl: photo, letter: letter, radius: 32),
          const SizedBox(height: 10),
          Text(name, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: appText(context))),
          const SizedBox(height: 16),
          if (currentBook.isNotEmpty)
            Container(
              width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark(context) ? const Color(0xFF2A2A2A) : const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(14), border: Border.all(color: appBorder(context))),
              child: Row(children: [
                const Text('📖', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 14),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(status == 'done' ? 'Acabou de ler' : 'A ler agora',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF888888), fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(currentBook, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: appText(context))),
                ])),
              ]),
            )
          else
            Text('$name não tem nenhum story.', style: const TextStyle(fontSize: 13, color: Color(0xFFAAAAAA))),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(
                builder: (_) => OtherUserProfileScreen(userId: uid, name: name, avatar: letter, photoUrl: photo))); },
              child: Container(height: 44, decoration: BoxDecoration(
                color: isDark(context) ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE), borderRadius: BorderRadius.circular(12)),
                child: Center(child: Text('Ver perfil', style: TextStyle(fontWeight: FontWeight.w700, color: appText(context))))),
            )),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(
              onTap: () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(
                builder: (_) => ChatScreen(name: name, avatar: letter, otherId: uid, otherPhotoUrl: photo))); },
              child: Container(height: 44, decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(12)),
                child: const Center(child: Text('Mensagem', style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white)))),
            )),
          ]),
        ]),
      ),
    );
  }

  // Bolinha individual (reutilizada para mim e para quem sigo)
  Widget _bubble(BuildContext context, {required String photo, required String name,
      required bool hasStory, required String labelOverride, required VoidCallback onTap}) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 72,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.all(2.5),
            decoration: hasStory
                ? const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(
                    colors: [Color(0xFFF5A623), Color(0xFFE05D5D), Color(0xFF9B59B6)],
                    begin: Alignment.topLeft, end: Alignment.bottomRight))
                : BoxDecoration(shape: BoxShape.circle, color: appBorder(context)),
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(shape: BoxShape.circle, color: appBg(context)),
              child: _UserAvatar(photoUrl: photo, letter: letter, radius: 26),
            ),
          ),
          const SizedBox(height: 4),
          Text(labelOverride, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: appText(context))),
        ]),
      ),
    );
  }

  void _openMyStory(BuildContext context, Map<String, dynamic> u) {
    final currentBook = u['showReading'] != false ? (u['currentBook'] ?? '').toString() : '';
    showModalBottomSheet(
      context: context,
      backgroundColor: appSurface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2))),
          const Text('O teu story', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          if (currentBook.isNotEmpty)
            Container(
              width: double.infinity, padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark(context) ? const Color(0xFF2A2A2A) : const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(14), border: Border.all(color: appBorder(context))),
              child: Row(children: [
                const Text('📖', style: TextStyle(fontSize: 28)),
                const SizedBox(width: 14),
                Expanded(child: Text(currentBook, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: appText(context)))),
              ]),
            )
          else
            const Text('Ainda não tens story. Publica um na página inicial (toca na tua bolinha).',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA))),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 92,
      child: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(myId).collection('following').snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          return ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: docs.length + 1,
            itemBuilder: (_, i) {
              // Índice 0 = a minha própria bolinha
              if (i == 0) {
                return StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(myId).snapshots(),
                  builder: (_, ms) {
                    final u = (ms.data?.data() as Map<String, dynamic>?) ?? {};
                    final photo = (u['photoUrl'] ?? '').toString();
                    final name = (u['name'] ?? 'Tu').toString();
                    final hasStory = u['showReading'] != false && (u['currentBook'] ?? '').toString().isNotEmpty;
                    return _bubble(context, photo: photo, name: name, hasStory: hasStory,
                      labelOverride: 'Tu', onTap: () => _openMyStory(context, u));
                  },
                );
              }
              final uid = docs[i - 1].id;
              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
                builder: (_, us) {
                  // Conta apagada → não mostra a bolinha
                  if (us.hasData && us.data?.exists == false) return const SizedBox.shrink();
                  final u = (us.data?.data() as Map<String, dynamic>?) ?? {};
                  final name = (u['name'] ?? 'Utilizador').toString();
                  final photo = (u['photoUrl'] ?? '').toString();
                  final hasStory = u['showReading'] != false && (u['currentBook'] ?? '').toString().isNotEmpty;
                  return _bubble(context, photo: photo, name: name, hasStory: hasStory,
                    labelOverride: name, onTap: () => _openStory(context, uid, u));
                },
              );
            },
          );
        },
      ),
    );
  }
}

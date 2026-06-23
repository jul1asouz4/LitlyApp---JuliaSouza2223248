import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/post_card.dart';
import '../services/auth_service.dart';
import '../services/book_service.dart';
import '../services/post_service.dart';
import '../services/user_service.dart';
import 'saved_posts_screen.dart';
import 'stats_screen.dart';
import 'profile_screen.dart';
import 'other_user_profile_screen.dart';
import 'follow_requests_screen.dart';
import 'welcome_screen.dart';
import '../theme.dart';

// ── Modelos ────────────────────────────────────────────────────────────────────

class _Notif {
  final String avatar, text, time, type;
  final String? postTexto, postAutor, userId;
  const _Notif({required this.avatar, required this.text, required this.time, required this.type, this.postTexto, this.postAutor, this.userId});
}


final _postService = PostService();

// ── HomeScreen ────────────────────────────────────────────────────────────────
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Barra de pesquisa funcional ──────────────────────────────────────────
  void _openSearch() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: appSurface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _SearchSheet(),
    );
  }

  // ── Notificações em tempo real ───────────────────────────────────────────
  void _openNotifications() {
    UserService.markNotificationsRead();
    showModalBottomSheet(
      context: context,
      backgroundColor: appSurface(context),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.93,
        minChildSize: 0.4,
        expand: false,
        builder: (_, ctrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
              child: Row(
                children: [
                  Container(width: 36, height: 4,
                    decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2))),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Notificações',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: appText(context))),
              ),
            ),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: UserService.notificationsStream(),
                builder: (_, snap) {
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.notifications_none_rounded, size: 46, color: Color(0xFFDDDDDD)),
                          SizedBox(height: 10),
                          Text('Sem notificações ainda.',
                            style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 14)),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: ctrl,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final d = docs[i].data() as Map<String, dynamic>;
                      final ts = d['createdAt'] as Timestamp?;
                      final notif = _Notif(
                        avatar: (d['fromName'] ?? 'U').toString().isNotEmpty ? d['fromName'][0].toUpperCase() : 'U',
                        text: d['text'] ?? '',
                        time: _notifTime(ts),
                        type: d['type'] ?? 'follow',
                        userId: d['fromId'],
                        postTexto: d['postTexto'],
                        postAutor: d['fromName'],
                      );
                      return _NotifTile(
                        notif: notif,
                        onTap: () {
                          Navigator.pop(ctx);
                          _handleNotifTap(notif);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _notifTime(Timestamp? ts) {
    if (ts == null) return 'agora';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    return '${diff.inDays}d';
  }

  void _handleNotifTap(_Notif n) {
    if (n.type == 'follow_request') {
      // Pedido de seguir → abre o ecrã para aceitar/rejeitar
      Navigator.push(context, MaterialPageRoute(builder: (_) => const FollowRequestsScreen()));
    } else if (n.type == 'follow' || n.type == 'follow_accept') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => OtherUserProfileScreen(
        userId: n.userId ?? '',
        name: n.postAutor ?? 'Utilizador',
        avatar: n.avatar,
        photoUrl: '',
      )));
    } else {
      // Mostra o post relacionado
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
        builder: (_) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2))),
              Row(
                children: [
                  _notifIcon(n.type),
                  const SizedBox(width: 8),
                  Text(n.text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                ],
              ),
              const SizedBox(height: 16),
              if (n.postTexto != null)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F8F8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFEEEEEE)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(n.postAutor ?? '',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
                      const SizedBox(height: 4),
                      Text(n.postTexto!,
                        style: const TextStyle(fontSize: 13, color: Color(0xFF555555), height: 1.45)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    }
  }

  Widget _notifIcon(String type) {
    final icons = {
      'like': (Icons.favorite_rounded, const Color(0xFFE05D5D)),
      'comment': (Icons.chat_bubble_rounded, const Color(0xFF1A1A1A)),
      'share': (Icons.share_rounded, const Color(0xFF555555)),
      'follow': (Icons.person_add_rounded, const Color(0xFF1A1A1A)),
    };
    final (icon, color) = icons[type] ?? (Icons.notifications_rounded, const Color(0xFF1A1A1A));
    return Icon(icon, color: color, size: 18);
  }

  // ── Menu ─────────────────────────────────────────────────────────────────
  void _openMenu() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _MenuSheet(parentContext: context),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBg(context),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── AppBar ────────────────────────────────────────────────────
            SliverAppBar(
              backgroundColor: appBg(context),
              surfaceTintColor: Colors.transparent,
              floating: true,
              snap: true,
              elevation: 0,
              toolbarHeight: 60,
              titleSpacing: 16,
              title: Row(
                children: [
                  // Logo real do Litly
                  Expanded(
                    child: Row(
                      children: [
                        _LitlyLogo(),
                        const SizedBox(width: 8),
                        Text('Litly',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: -1, color: appText(context))),
                      ],
                    ),
                  ),
                  // Pesquisa funcional
                  GestureDetector(
                    onTap: _openSearch,
                    child: Container(
                      height: 38, width: 150,
                      decoration: BoxDecoration(
                        color: appSurface(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: appBorder(context)),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(width: 10),
                          Icon(Icons.search_rounded, color: Color(0xFFAAAAAA), size: 16),
                          SizedBox(width: 6),
                          Text('Pesquisar...', style: TextStyle(color: Color(0xFFBBBBBB), fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Notificações
                  GestureDetector(
                    onTap: _openNotifications,
                    child: Stack(
                      children: [
                        Container(
                          width: 38, height: 38,
                          decoration: BoxDecoration(
                            color: appSurface(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: appBorder(context)),
                          ),
                          child: Icon(Icons.notifications_none_rounded, color: appText(context), size: 20),
                        ),
                        StreamBuilder<QuerySnapshot>(
                          stream: UserService.notificationsStream(),
                          builder: (_, snap) {
                            final unread = (snap.data?.docs ?? [])
                                .where((d) => (d.data() as Map)['read'] == false).length;
                            if (unread == 0) return const SizedBox.shrink();
                            return Positioned(
                              top: 5, right: 5,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE05D5D),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: appBg(context), width: 1.5),
                                ),
                                child: Center(child: Text('$unread',
                                  style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold))),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Menu
                  GestureDetector(
                    onTap: _openMenu,
                    child: Container(
                      width: 38, height: 38,
                      decoration: BoxDecoration(
                        color: appSurface(context),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: appBorder(context)),
                      ),
                      child: Icon(Icons.menu_rounded, color: appText(context), size: 20),
                    ),
                  ),
                ],
              ),
            ),

            // ── Stories ───────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 10, 16, 8),
                    child: Text('A ler agora',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF888888), letterSpacing: 0.3)),
                  ),
                  SizedBox(
                    height: 88,
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('users')
                          .doc(FirebaseAuth.instance.currentUser?.uid ?? '')
                          .collection('following')
                          .snapshots(),
                      builder: (_, snap) {
                        final docs = snap.data?.docs ?? [];
                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: docs.length + 1,
                          itemBuilder: (_, i) {
                            if (i == 0) return _MyStoryBtn();
                            final uid = docs[i - 1].id;
                            final f = docs[i - 1].data() as Map<String, dynamic>;
                            // Lê o nome/foto ATUAIS do utilizador
                            return StreamBuilder<DocumentSnapshot>(
                              stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
                              builder: (_, us) {
                                // Conta apagada → não mostra a bolinha
                                if (us.hasData && us.data?.exists == false) return const SizedBox.shrink();
                                final ud = us.data?.data() as Map<String, dynamic>?;
                                final name = (ud?['name'] ?? f['name'] ?? 'Utilizador').toString();
                                final photo = (ud?['photoUrl'] ?? f['photoUrl'] ?? '').toString();
                                return _FollowStoryAvatar(
                                  userId: uid,
                                  name: name,
                                  photoUrl: photo,
                                  onTap: () => _openFollowStory(uid, name, photo),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Text('Feed',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF888888), letterSpacing: 0.3)),
                  ),
                ],
              ),
            ),

            // ── Feed do Firestore ─────────────────────────────────────────
            SliverToBoxAdapter(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users')
                    .doc(FirebaseAuth.instance.currentUser?.uid ?? '_').snapshots(),
                builder: (_, meSnap) {
                  final meData = meSnap.data?.data() as Map<String, dynamic>?;
                  final following = List<String>.from(meData?['followingIds'] ?? []);
                  final blocked = List<String>.from(meData?['blockedUsers'] ?? []);
                  return StreamBuilder<QuerySnapshot>(
                stream: _postService.feedStream(),
                builder: (_, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.all(40),
                      child: Center(child: CircularProgressIndicator(color: Color(0xFF1A1A1A), strokeWidth: 2)),
                    );
                  }
                  final uidF = FirebaseAuth.instance.currentUser?.uid ?? '';
                  // Esconde posts de bloqueados e de contas privadas que não sigo
                  final docs = (snap.data?.docs ?? []).where((doc) {
                    final m = doc.data() as Map<String, dynamic>;
                    final authorId = (m['authorId'] ?? '').toString();
                    if (blocked.contains(authorId)) return false;
                    if (m['authorPrivate'] != true) return true;
                    return authorId == uidF || following.contains(authorId);
                  }).toList();
                  if (docs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 40),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.auto_stories_outlined, size: 48, color: Color(0xFFDDDDDD)),
                            SizedBox(height: 12),
                            Text('Nenhum post ainda.\nSê a primeira a publicar! 📚',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF999999), fontSize: 14, height: 1.5)),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final d = docs[i].data() as Map<String, dynamic>;
                      return PostCard(
                        postId: docs[i].id,
                        data: d,
                        isOwner: d['authorId'] == uidF,
                      );
                    },
                  );
                },
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }

  // ── Story de quem seguimos — mostra o livro que está a ler ────────────────
  void _openFollowStory(String userId, String name, String photoUrl) {
    final letter = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
        builder: (_, snap) {
          final data = snap.data?.data() as Map<String, dynamic>?;
          // Respeita a definição de privacidade "Mostrar estado de leitura"
          final showReading = data?['showReading'] != false;
          final currentBook = showReading ? (data?['currentBook'] ?? '').toString() : '';
          final readingStatus = (data?['readingStatus'] ?? '').toString();
          // Lê a foto ATUAL do utilizador (a passada pode estar desatualizada)
          final currentPhoto = (data?['photoUrl'] ?? photoUrl).toString();
          return Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 36, height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2))),
                // Nome do utilizador em cima
                avatarProvider(currentPhoto) != null
                    ? CircleAvatar(radius: 32, backgroundImage: avatarProvider(currentPhoto))
                    : CircleAvatar(radius: 32, backgroundColor: const Color(0xFF1A1A1A),
                        child: Text(letter, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22))),
                const SizedBox(height: 10),
                Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
                const SizedBox(height: 20),
                // Livro que está a ler
                if (snap.connectionState == ConnectionState.waiting)
                  const Padding(padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(color: Color(0xFF1A1A1A), strokeWidth: 2))
                else if (currentBook.isNotEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8F8F8),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFEEEEEE)),
                    ),
                    child: Row(
                      children: [
                        const Text('📖', style: TextStyle(fontSize: 28)),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(readingStatus == 'done' ? 'Acabou de ler' : 'A ler agora',
                                style: const TextStyle(fontSize: 11, color: Color(0xFF888888), fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(currentBook,
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Text('$name ainda não partilhou o que está a ler.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: Color(0xFFAAAAAA))),
                // Botão de gosto no story
                if (currentBook.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _StoryLikeButton(ownerId: userId),
                ],
                const SizedBox(height: 20),
                // Botão ver perfil
                SizedBox(
                  width: double.infinity, height: 46,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(context, MaterialPageRoute(
                        builder: (_) => OtherUserProfileScreen(
                          userId: userId, name: name, avatar: letter, photoUrl: photoUrl),
                      ));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1A1A), foregroundColor: Colors.white,
                      elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Ver perfil', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _LitlyLogo() => ClipOval(
        child: Image.asset('assets/images/logo.png', width: 30, height: 30, fit: BoxFit.cover),
      );
}

// ── Botão de gosto no story ───────────────────────────────────────────────────
class _StoryLikeButton extends StatelessWidget {
  final String ownerId;
  const _StoryLikeButton({required this.ownerId});

  @override
  Widget build(BuildContext context) {
    final myId = FirebaseAuth.instance.currentUser?.uid ?? '';
    final col = FirebaseFirestore.instance.collection('users').doc(ownerId).collection('storyLikes');
    return StreamBuilder<QuerySnapshot>(
      stream: col.snapshots(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        final liked = docs.any((d) => d.id == myId);
        final count = docs.length;
        return GestureDetector(
          onTap: () async {
            HapticFeedback.lightImpact();
            if (liked) {
              await col.doc(myId).delete();
            } else {
              await col.doc(myId).set({'at': FieldValue.serverTimestamp()});
            }
          },
          child: Container(
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFF8F8F8),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFEEEEEE)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: liked ? const Color(0xFFE05D5D) : const Color(0xFF888888), size: 22),
                const SizedBox(width: 8),
                Text(liked ? 'Gostaste' : 'Gosto',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14,
                    color: liked ? const Color(0xFFE05D5D) : const Color(0xFF555555))),
                if (count > 0) ...[
                  const SizedBox(width: 6),
                  Text('· $count', style: const TextStyle(color: Color(0xFF888888), fontSize: 13)),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Bolinha de quem seguimos ─────────────────────────────────────────────────
class _FollowStoryAvatar extends StatelessWidget {
  final String userId, name, photoUrl;
  final VoidCallback onTap;
  const _FollowStoryAvatar({required this.userId, required this.name, required this.photoUrl, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 70,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [Color(0xFFE05D5D), Color(0xFFF5A623)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight),
              ),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(color: appBg(context), shape: BoxShape.circle),
                child: photoUrl.isNotEmpty
                    ? CircleAvatar(radius: 26, backgroundImage: (avatarProvider(photoUrl) ?? NetworkImage(photoUrl)))
                    : CircleAvatar(radius: 26, backgroundColor: const Color(0xFF1A1A1A),
                        child: Text(initial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
              ),
            ),
            const SizedBox(height: 4),
            Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: Color(0xFF1A1A1A))),
          ],
        ),
      ),
    );
  }
}

// ── Story próprio (bolinha do utilizador) ────────────────────────────────────
class _MyStoryBtn extends StatefulWidget {
  @override
  State<_MyStoryBtn> createState() => _MyStoryBtnState();
}

class _MyStoryBtnState extends State<_MyStoryBtn> {
  String _publishedBook = '';
  bool _hasPublished = false;
  String _publishedStatus = '';
  String _userInitial = 'U';
  String _userName = 'Tu';
  String _userPhoto = '';

  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _listen() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final name = user.displayName ?? user.email ?? 'Utilizador';
    // Listener em tempo real — a bolinha atualiza assim que mudamos foto/livro
    _sub = FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots().listen((doc) {
      final data = doc.data();
      if (!mounted) return;
      setState(() {
        final realName = (data?['name'] ?? name).toString();
        _userInitial = realName.isNotEmpty ? realName[0].toUpperCase() : 'U';
        _userName = realName.split(' ').first;
        _userPhoto = (data?['photoUrl'] ?? user.photoURL ?? '').toString();
        final book = (data?['currentBook'] ?? '').toString();
        _publishedStatus = (data?['readingStatus'] ?? '').toString();
        _publishedBook = book;
        _hasPublished = book.isNotEmpty;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final label = _hasPublished
        ? (_publishedBook.length > 8 ? '${_publishedBook.substring(0, 8)}...' : _publishedBook)
        : _userName;
    return GestureDetector(
      onTap: () => _hasPublished ? _showMyStory(context) : _showMyReading(context),
      child: Padding(
        padding: const EdgeInsets.only(right: 14, bottom: 6),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(2.5),
              decoration: _hasPublished
                  ? const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFFF5A623), Color(0xFFE05D5D), Color(0xFF9B59B6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    )
                  : const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFDDDDDD)),
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: Stack(
                  children: [
                    Container(
                      width: 50, height: 50,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1A1A1A),
                        shape: BoxShape.circle,
                        image: avatarProvider(_userPhoto) != null
                            ? DecorationImage(image: avatarProvider(_userPhoto)!, fit: BoxFit.cover)
                            : null,
                      ),
                      child: avatarProvider(_userPhoto) != null ? null : Center(
                        child: Text(_userInitial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
                      ),
                    ),
                    if (!_hasPublished)
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          width: 18, height: 18,
                          decoration: const BoxDecoration(color: Color(0xFF1A1A1A), shape: BoxShape.circle),
                          child: const Icon(Icons.add, color: Colors.white, size: 12),
                        ),
                      ),
                    if (_hasPublished)
                      Positioned(
                        bottom: 0, right: 0,
                        child: Container(
                          width: 18, height: 18,
                          decoration: const BoxDecoration(color: Color(0xFF4CAF50), shape: BoxShape.circle),
                          child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 11),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF1A1A1A), fontWeight: FontWeight.w500),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  // Mostra o meu story atual com opções de apagar / criar novo
  void _showMyStory(BuildContext context) {
    final statusLabel = _publishedStatus == 'done'
        ? '✅ Já li'
        : _publishedStatus == 'want' ? '🔖 Quero ler' : '📖 A ler agora';
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2))),
            avatarProvider(_userPhoto) != null
                ? CircleAvatar(radius: 32, backgroundImage: avatarProvider(_userPhoto))
                : CircleAvatar(radius: 32, backgroundColor: const Color(0xFF1A1A1A),
                    child: Text(_userInitial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22))),
            const SizedBox(height: 10),
            const Text('O teu story', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F8F8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEEEEEE)),
              ),
              child: Row(
                children: [
                  Text(statusLabel.split(' ').first, style: const TextStyle(fontSize: 28)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(statusLabel.substring(statusLabel.indexOf(' ') + 1),
                          style: const TextStyle(fontSize: 11, color: Color(0xFF888888), fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text(_publishedBook,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            // Botão novo story
            SizedBox(
              width: double.infinity, height: 46,
              child: ElevatedButton(
                onPressed: () { Navigator.pop(ctx); _showMyReading(context); },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A1A), foregroundColor: Colors.white,
                  elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Novo story', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
            const SizedBox(height: 10),
            // Botão apagar story
            SizedBox(
              width: double.infinity, height: 46,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final uid = FirebaseAuth.instance.currentUser?.uid;
                  if (uid != null) {
                    await FirebaseFirestore.instance.collection('users').doc(uid).update({
                      'currentBook': '', 'readingStatus': '',
                    });
                  }
                  setState(() { _hasPublished = false; _publishedBook = ''; _publishedStatus = ''; });
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE05D5D), size: 20),
                label: const Text('Apagar story', style: TextStyle(color: Color(0xFFE05D5D), fontWeight: FontWeight.w700, fontSize: 15)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFE05D5D)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMyReading(BuildContext context) {
    String currentBook = '';
    String status = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (_, setState) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 36,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2))),
              const Text('O meu estado de leitura',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
              const SizedBox(height: 6),
              const Text('Partilha o que estás a ler com os teus seguidores',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Color(0xFF888888))),
              const SizedBox(height: 20),
              // Campo de livro
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  onChanged: (v) => currentBook = v,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Nome do livro que estás a ler...',
                    hintStyle: TextStyle(color: Color(0xFFBBBBBB), fontSize: 14),
                    prefixIcon: Icon(Icons.menu_book_outlined, color: Color(0xFF888888), size: 20),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // Estado
              Row(
                children: [
                  _StatusChip(
                    label: '📖 A ler',
                    selected: status == 'reading',
                    onTap: () => setState(() => status = status == 'reading' ? '' : 'reading'),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(
                    label: '🔖 Quero ler',
                    selected: status == 'want',
                    onTap: () => setState(() => status = status == 'want' ? '' : 'want'),
                  ),
                  const SizedBox(width: 8),
                  _StatusChip(
                    label: '✅ Lido',
                    selected: status == 'done',
                    onTap: () => setState(() => status = status == 'done' ? '' : 'done'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () async {
                    if (currentBook.isNotEmpty || status.isNotEmpty) {
                      final bookName = currentBook.isNotEmpty ? currentBook : status;
                      // Atualiza UI local imediatamente
                      setState(() {
                        _publishedBook = bookName;
                        _publishedStatus = status;
                        _hasPublished = true;
                      });
                      // Guarda no Firestore
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      if (uid != null) {
                        FirebaseFirestore.instance.collection('users').doc(uid).update({
                          'currentBook': bookName,
                          'readingStatus': status,
                        });
                      }
                    }
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A1A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('Partilhar estado', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _StatusChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
          color: selected ? Colors.white : const Color(0xFF555555))),
    ),
  );
}


// ── Tile de notificação clicável ──────────────────────────────────────────────
class _NotifTile extends StatelessWidget {
  final _Notif notif;
  final VoidCallback onTap;
  const _NotifTile({required this.notif, required this.onTap});

  IconData get _icon {
    switch (notif.type) {
      case 'like': return Icons.favorite_rounded;
      case 'comment': return Icons.chat_bubble_rounded;
      case 'share': return Icons.share_rounded;
      default: return Icons.person_add_rounded;
    }
  }

  Color get _iconColor {
    switch (notif.type) {
      case 'like': return const Color(0xFFE05D5D);
      case 'comment': return const Color(0xFF1A1A1A);
      default: return const Color(0xFF555555);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFF1A1A1A),
                  child: Text(notif.avatar,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    width: 18, height: 18,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Icon(_icon, color: _iconColor, size: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(notif.text,
                    style: TextStyle(fontSize: 13, color: appText(context), height: 1.4)),
                  const SizedBox(height: 2),
                  Text(notif.time,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF999999))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFFDDDDDD), size: 18),
          ],
        ),
      ),
    );
  }
}

// ── Menu funcional ─────────────────────────────────────────────────────────────
class _MenuSheet extends StatelessWidget {
  final BuildContext parentContext;
  const _MenuSheet({required this.parentContext});

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.person_outline_rounded, 'O meu perfil', () {
        Navigator.pop(context);
        Navigator.push(parentContext, MaterialPageRoute(builder: (_) => const ProfileScreen()));
      }),
      (Icons.bookmark_border_rounded, 'Guardados', () {
        Navigator.pop(context);
        Navigator.push(parentContext, MaterialPageRoute(builder: (_) => const SavedPostsScreen()));
      }),
      (Icons.bar_chart_rounded, 'Estatísticas', () {
        Navigator.pop(context);
        Navigator.push(parentContext, MaterialPageRoute(builder: (_) => const StatsScreen()));
      }),
      (Icons.settings_outlined, 'Definições', () {
        Navigator.pop(context);
        Navigator.push(parentContext, MaterialPageRoute(builder: (_) => const SettingsScreen()));
      }),
      (Icons.help_outline_rounded, 'Ajuda', () {
        Navigator.pop(context);
        _showHelp(parentContext);
      }),
      (Icons.logout_rounded, 'Sair', () {
        Navigator.pop(context);
        _confirmLogout(parentContext);
      }),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 36, height: 4,
            decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 16),
          ...items.map((e) => ListTile(
            leading: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(e.$1,
                color: e.$2 == 'Sair' ? const Color(0xFFE05D5D) : const Color(0xFF1A1A1A),
                size: 20),
            ),
            title: Text(e.$2,
              style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w500,
                color: e.$2 == 'Sair' ? const Color(0xFFE05D5D) : const Color(0xFF1A1A1A))),
            trailing: const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC), size: 18),
            contentPadding: const EdgeInsets.symmetric(vertical: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onTap: e.$3,
          )),
        ],
      ),
    );
  }

  void _showHelp(BuildContext ctx) {
    showModalBottomSheet(
      context: ctx,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2))),
            const Text('Ajuda', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
            const SizedBox(height: 16),
            const _HelpRow(q: 'Como publicar um post?', a: 'Toca no botão + na barra de navegação.'),
            const _HelpRow(q: 'Como guardar um post?', a: 'Toca no ícone 🔖 em qualquer post.'),
            const _HelpRow(q: 'Como pesquisar livros?', a: 'Vai ao separador Pesquisar (lupa).'),
            const _HelpRow(q: 'Como editar o meu perfil?', a: 'Vai ao Perfil e toca em "Editar perfil".'),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext ctx) {
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Terminar sessão', style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text('Tens a certeza que queres sair?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Color(0xFF888888)))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await AuthService.signOut();
              if (ctx.mounted) {
                Navigator.pushAndRemoveUntil(ctx,
                  MaterialPageRoute(builder: (_) => const WelcomeScreen()), (_) => false);
              }
            },
            child: const Text('Sair', style: TextStyle(color: Color(0xFFE05D5D), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _HelpRow extends StatelessWidget {
  final String q, a;
  const _HelpRow({required this.q, required this.a});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(q, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
        const SizedBox(height: 2),
        Text(a, style: const TextStyle(fontSize: 13, color: Color(0xFF777777))),
      ],
    ),
  );
}

// ── Sheet de pesquisa funcional ───────────────────────────────────────────────
// ── Sheet de pesquisa (livros + utilizadores) ────────────────────────────────
class _SearchSheet extends StatefulWidget {
  @override
  State<_SearchSheet> createState() => _SearchSheetState();
}

class _SearchSheetState extends State<_SearchSheet> with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  late TabController _tabCtrl;
  String _query = '';
  bool _searchingBooks = false;
  bool _searchingUsers = false;
  List<dynamic> _books = [];
  List<Map<String, dynamic>> _users = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchUsers() async {
    if (_query.isEmpty) { setState(() => _users = []); return; }
    setState(() { _searchingUsers = true; });
    try {
      final q = _query.toLowerCase();
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .where('nameLower', isGreaterThanOrEqualTo: q)
          .where('nameLower', isLessThan: '${q}z')
          .limit(20)
          .get();
      if (mounted) setState(() => _users = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList());
    } catch (_) {} finally {
      if (mounted) setState(() => _searchingUsers = false);
    }
  }

  Future<void> _searchBooks() async {
    if (_query.isEmpty) return;
    setState(() { _searchingBooks = true; _books = []; });
    try {
      final results = await BookService().searchBooks(_query);
      if (mounted) setState(() => _books = results);
    } catch (_) {} finally {
      if (mounted) setState(() => _searchingBooks = false);
    }
  }

  String _coverUrl(dynamic book) {
    final links = book['volumeInfo']['imageLinks'];
    if (links == null) return '';
    return (links['thumbnail'] ?? links['smallThumbnail'] ?? '')
        .toString().replaceFirst('http://', 'https://');
  }

  void _openBookDetail(dynamic book) {
    final info = book['volumeInfo'];
    final id = book['id'] as String;
    final rawUrl = info['imageLinks']?['thumbnail'] ?? info['imageLinks']?['smallThumbnail'];
    final imageUrl = rawUrl?.toString().replaceFirst('http://', 'https://');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2))),
              if (imageUrl != null)
                ClipRRect(borderRadius: BorderRadius.circular(10),
                  child: Image.network(imageUrl, height: 180, fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(Icons.book, size: 80, color: Colors.grey)))
              else
                const Icon(Icons.book, size: 80, color: Colors.grey),
              const SizedBox(height: 14),
              Text(info['title'] ?? '', textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
              const SizedBox(height: 4),
              Text(info['authors']?.join(', ') ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF888888))),
              const SizedBox(height: 20),
              _HomeBookStatusPicker(
                bookId: id,
                bookData: {
                  'title': info['title'] ?? '',
                  'author': info['authors']?.join(', ') ?? '',
                  'image': imageUrl ?? '',
                },
              ),
              if ((info['description'] ?? '').isNotEmpty) ...[
                const SizedBox(height: 20),
                const Align(alignment: Alignment.centerLeft,
                  child: Text('Sinopse', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
                const SizedBox(height: 8),
                Text(info['description'] ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF555555), height: 1.6)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _onChanged(String v) {
    setState(() => _query = v);
    if (_tabCtrl.index == 0) _searchBooks();
    else _searchUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            // Handle
            Container(width: 36, height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 10),
              decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2))),

            // Barra de pesquisa
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: isDark(context) ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: _ctrl,
                  autofocus: true,
                  onChanged: _onChanged,
                  onSubmitted: (_) => _searchBooks(),
                  style: TextStyle(fontSize: 15, color: appText(context)),
                  decoration: InputDecoration(
                    hintText: 'Pesquisar livros ou utilizadores...',
                    hintStyle: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
                    prefixIcon: const Icon(Icons.search, color: Color(0xFFAAAAAA), size: 20),
                    suffixIcon: _query.isNotEmpty
                        ? GestureDetector(
                            onTap: () { _ctrl.clear(); setState(() { _query = ''; _books = []; }); },
                            child: const Icon(Icons.close, color: Color(0xFFAAAAAA), size: 18))
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Tabs
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  color: isDark(context) ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TabBar(
                  controller: _tabCtrl,
                  onTap: (i) {
                    if (_query.isNotEmpty) {
                      if (i == 0) _searchBooks();
                      else _searchUsers();
                    }
                  },
                  indicator: BoxDecoration(
                    color: isDark(context) ? const Color(0xFF454545) : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)],
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: appText(context),
                  unselectedLabelColor: const Color(0xFF888888),
                  labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  unselectedLabelStyle: const TextStyle(fontSize: 13),
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: '📚 Livros'),
                    Tab(text: '👤 Utilizadores'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Conteúdo
            Expanded(
              child: TabBarView(
                controller: _tabCtrl,
                children: [
                  // ── Tab Livros ─────────────────────────────────────────
                  _searchingBooks
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A1A1A), strokeWidth: 2))
                      : _books.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.menu_book_outlined, size: 44, color: Color(0xFFDDDDDD)),
                                  const SizedBox(height: 10),
                                  Text(
                                    _query.isEmpty
                                        ? 'Pesquisa um livro pelo título ou autor'
                                        : 'Nenhum livro encontrado para "$_query"',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14)),
                                  if (_query.isNotEmpty) ...[
                                    const SizedBox(height: 12),
                                    GestureDetector(
                                      onTap: _searchBooks,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1A1A1A),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Text('Tentar novamente',
                                          style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : GridView.builder(
                              controller: scrollCtrl,
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 14, childAspectRatio: 0.58),
                              itemCount: _books.length,
                              itemBuilder: (_, i) {
                                final book = _books[i];
                                final info = book['volumeInfo'];
                                final cover = _coverUrl(book);
                                return GestureDetector(
                                  onTap: () => _openBookDetail(book),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: cover.isNotEmpty
                                              ? Image.network(cover, width: double.infinity, fit: BoxFit.cover,
                                                  errorBuilder: (_, __, ___) => _bookBg())
                                              : _bookBg(),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(info['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: appText(context))),
                                      Text(info['authors']?[0] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 10, color: Color(0xFF999999))),
                                    ],
                                  ),
                                );
                              },
                            ),

                  // ── Tab Utilizadores ───────────────────────────────────
                  _query.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.people_outline_rounded, size: 44, color: Color(0xFFDDDDDD)),
                              SizedBox(height: 10),
                              Text('Pesquisa utilizadores pelo nome',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 14)),
                            ],
                          ),
                        )
                      : _searchingUsers
                          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A1A1A), strokeWidth: 2))
                          : _users.isEmpty
                              ? const Center(child: Text('Nenhum utilizador encontrado.',
                                  style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 14)))
                              : ListView.builder(
                                  controller: scrollCtrl,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  itemCount: _users.length,
                                  itemBuilder: (_, i) {
                                    final u = _users[i];
                                    final name = u['name'] ?? 'Utilizador';
                                    final handle = u['username'] ?? '';
                                    final photo = u['photoUrl'] ?? '';
                                    final avatar = name.isNotEmpty ? name[0].toUpperCase() : 'U';
                                    return ListTile(
                                      leading: photo.isNotEmpty
                                          ? CircleAvatar(radius: 22, backgroundImage: (avatarProvider(photo) ?? NetworkImage(photo)))
                                          : CircleAvatar(
                                              radius: 22,
                                              backgroundColor: const Color(0xFF1A1A1A),
                                              child: Text(avatar,
                                                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                      title: Text(name,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                                      subtitle: Text(handle,
                                        style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
                                      trailing: const Icon(Icons.chevron_right, color: Color(0xFFDDDDDD)),
                                      onTap: () {
                                        Navigator.pop(context);
                                        Navigator.push(context, MaterialPageRoute(
                                          builder: (_) => OtherUserProfileScreen(
                                            userId: u['id'] ?? u['uid'] ?? '',
                                            name: name,
                                            avatar: avatar,
                                            photoUrl: photo,
                                          ),
                                        ));
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

  Widget _bookBg() => Container(
    decoration: BoxDecoration(color: const Color(0xFFEEEEEE), borderRadius: BorderRadius.circular(8)),
    child: const Center(child: Icon(Icons.book, color: Colors.grey, size: 24)),
  );
}

// ── Picker de estado (home search sheet) ──────────────────────────────────────
class _HomeBookStatusPicker extends StatefulWidget {
  final String bookId;
  final Map<String, dynamic> bookData;
  const _HomeBookStatusPicker({required this.bookId, required this.bookData});

  @override
  State<_HomeBookStatusPicker> createState() => _HomeBookStatusPickerState();
}

class _HomeBookStatusPickerState extends State<_HomeBookStatusPicker> {
  String? _status;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('books').doc(widget.bookId).get();
    if (doc.exists && mounted) setState(() => _status = doc.data()?['status']);
  }

  Future<void> _set(String s) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final sel = _status == s;
    setState(() => _status = sel ? null : s);
    final ref = FirebaseFirestore.instance
        .collection('users').doc(uid).collection('books').doc(widget.bookId);
    if (sel) {
      await ref.delete();
    } else {
      await ref.set({...widget.bookData, 'status': s, 'bookId': widget.bookId, 'addedAt': FieldValue.serverTimestamp()});
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(sel ? 'Removido da biblioteca' : '✅ Guardado na biblioteca!'),
        backgroundColor: const Color(0xFF333333),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(milliseconds: 1800),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final opts = [('reading', Icons.menu_book_rounded, 'A ler'), ('want', Icons.bookmark_border_rounded, 'Quero ler'), ('done', Icons.check_circle_outline_rounded, 'Lido')];
    return Row(
      children: opts.map((o) {
        final sel = _status == o.$1;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => _set(o.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFF1A1A1A) : const Color(0xFFF0F0F0),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Icon(o.$2, size: 18, color: sel ? Colors.white : const Color(0xFF666666)),
                    const SizedBox(height: 3),
                    Text(o.$3, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                        color: sel ? Colors.white : const Color(0xFF666666))),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

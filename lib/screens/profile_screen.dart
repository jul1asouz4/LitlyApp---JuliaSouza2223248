import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';
import '../services/book_service.dart';
import '../widgets/post_card.dart';
import 'welcome_screen.dart';
import 'follow_list_screen.dart';
import 'follow_requests_screen.dart';
import 'blocked_users_screen.dart';
import 'settings_screens.dart';
import 'admin_panel_screen.dart';
import '../services/admin_service.dart';
import '../theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  Uint8List? _profilePhoto;
  String _displayName = '';
  String _handle = '';
  String _bio = '';
  int _followers = 0;
  int _following = 0;
  String _photoUrl = '';
  bool _hasStory = false;

  final _db = FirebaseFirestore.instance;
  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  StreamSubscription? _userSub;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _listenUserData();
  }

  void _listenUserData() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    // Listener em tempo real — o perfil atualiza assim que editamos
    _userSub = _db.collection('users').doc(user.uid).snapshots().listen((doc) {
      final data = doc.data() ?? {};
      final name = data['name'] ?? user.displayName ?? 'Utilizador';
      final handle = data['handle'] ?? data['username'] ?? '@${name.toLowerCase().replaceAll(' ', '')}';
      if (data['nameLower'] == null || data['handle'] == null) {
        _db.collection('users').doc(user.uid).set({
          'name': name, 'nameLower': name.toLowerCase(), 'handle': handle,
        }, SetOptions(merge: true));
      }
      if (mounted) {
        setState(() {
          _displayName = name;
          _handle = handle;
          _bio = data['bio'] ?? '';
          _followers = (data['followersCount'] ?? 0) as int;
          _following = (data['followingCount'] ?? 0) as int;
          _photoUrl = data['photoUrl'] ?? user.photoURL ?? '';
          _hasStory = (data['currentBook'] ?? '').toString().isNotEmpty;
        });
      }
    });
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _tabCtrl.dispose();
    super.dispose();
  }

  Widget _bookBg() => Container(
    decoration: BoxDecoration(color: const Color(0xFFEEEEEE), borderRadius: BorderRadius.circular(8)),
    child: const Center(child: Icon(Icons.book, color: Colors.grey, size: 28)),
  );

  Future<String> _fetchSynopsis(String title) async {
    if (title.isEmpty) return '';
    try {
      final results = await BookService().searchBooks(title);
      if (results.isEmpty) return '';
      return (results.first['volumeInfo']?['description'] ?? '').toString();
    } catch (_) {
      return '';
    }
  }

  void _editBookStatus(String bookId, Map<String, dynamic> book) {
    final ref = _db.collection('users').doc(_uid).collection('books').doc(bookId);
    final current = book['status'] ?? '';
    final options = [
      ('reading', '📖', 'A ler'),
      ('want', '🔖', 'Quero ler'),
      ('done', '✅', 'Lido'),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2)))),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((book['image'] ?? '').toString().isNotEmpty)
                  ClipRRect(borderRadius: BorderRadius.circular(6),
                    child: Image.network(book['image'], width: 56, height: 80, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.book, size: 56, color: Colors.grey))),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(book['title'] ?? 'Livro',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
                      const SizedBox(height: 2),
                      Text(book['author'] ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF888888))),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            // Sinopse (buscada na Google Books pelo título)
            FutureBuilder<String>(
              future: _fetchSynopsis(book['title'] ?? ''),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('A carregar sinopse...', style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA))));
                }
                final syn = snap.data ?? '';
                if (syn.isEmpty) return const SizedBox.shrink();
                return Container(
                  constraints: const BoxConstraints(maxHeight: 160),
                  margin: const EdgeInsets.only(bottom: 6),
                  child: SingleChildScrollView(
                    child: Text(syn, style: const TextStyle(fontSize: 13, color: Color(0xFF555555), height: 1.5)),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            const Text('Mudar estado de leitura',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF888888))),
            const SizedBox(height: 8),
            ...options.map((o) {
              final sel = current == o.$1;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text(o.$2, style: const TextStyle(fontSize: 22)),
                title: Text(o.$3, style: TextStyle(
                  fontSize: 15, fontWeight: sel ? FontWeight.w800 : FontWeight.w500,
                  color: const Color(0xFF1A1A1A))),
                trailing: sel ? const Icon(Icons.check_rounded, color: Color(0xFF2E7D32)) : null,
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.set({'status': o.$1}, SetOptions(merge: true));
                },
              );
            }),
            const Divider(height: 20, color: Color(0xFFF0F0F0)),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE05D5D)),
              title: const Text('Remover da biblioteca',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFFE05D5D))),
              onTap: () async {
                Navigator.pop(ctx);
                await ref.delete();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickProfilePhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final original = await picked.readAsBytes();

    // Redimensiona/comprime no próprio código (na web o image_picker não o faz).
    Uint8List bytes = original;
    try {
      final decoded = img.decodeImage(original);
      if (decoded != null) {
        final resized = img.copyResize(decoded, width: 300);
        bytes = Uint8List.fromList(img.encodeJpg(resized, quality: 70));
      }
    } catch (_) {/* usa o original se a descodificação falhar */}

    setState(() => _profilePhoto = bytes);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final dataUri = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      await _db.collection('users').doc(uid).set({'photoUrl': dataUri}, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Foto de perfil atualizada! ✅'),
          backgroundColor: Color(0xFF2E7D32), behavior: SnackBarBehavior.floating));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Erro ao guardar a foto. Tenta novamente.'),
          backgroundColor: Color(0xFFE05D5D), behavior: SnackBarBehavior.floating));
      }
    }
  }

  void _openEditProfile(BuildContext context) {
    final nameCtrl = TextEditingController(text: _displayName);
    final bioCtrl = TextEditingController(text: _bio);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 16,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2)))),
            const Text('Editar perfil', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1A1A1A))),
            const SizedBox(height: 20),
            Center(
              child: GestureDetector(
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pickProfilePhoto();
                },
                child: Stack(
                  children: [
                    _buildAvatarWidget(radius: 40),
                    Positioned(
                      bottom: 0, right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(5),
                        decoration: const BoxDecoration(color: Color(0xFF1A1A1A), shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt_rounded, size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Nome', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF888888))),
            const SizedBox(height: 6),
            _EditField(controller: nameCtrl, hint: 'O teu nome'),
            const SizedBox(height: 14),
            const Text('Bio', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF888888))),
            const SizedBox(height: 6),
            _EditField(controller: bioCtrl, hint: 'Fala sobre ti...', maxLines: 3),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 48,
              child: ElevatedButton(
                onPressed: () async {
                  final name = nameCtrl.text.trim();
                  final bio = bioCtrl.text.trim();
                  Navigator.pop(ctx);
                  if (name.isEmpty) return;
                  await _db.collection('users').doc(_uid).set({
                    'name': name,
                    'nameLower': name.toLowerCase(),
                    'bio': bio,
                  }, SetOptions(merge: true));
                  await FirebaseAuth.instance.currentUser?.updateDisplayName(name);
                  if (mounted) setState(() { _displayName = name; _bio = bio; });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A1A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Guardar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatarWidget({required double radius}) {
    if (_profilePhoto != null) {
      return CircleAvatar(radius: radius, backgroundImage: MemoryImage(_profilePhoto!));
    }
    if (_photoUrl.isNotEmpty) {
      return CircleAvatar(radius: radius, backgroundImage: (avatarProvider(_photoUrl) ?? NetworkImage(_photoUrl)));
    }
    final initial = _displayName.isNotEmpty ? _displayName[0].toUpperCase() : '?';
    return CircleAvatar(radius: radius, backgroundColor: const Color(0xFF1A1A1A),
      child: Text(initial, style: TextStyle(color: Colors.white, fontSize: radius * 0.8, fontWeight: FontWeight.bold)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBg(context),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          // AppBar
          SliverAppBar(
            backgroundColor: appBg(context),
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            floating: true,
            snap: true,
            toolbarHeight: 56,
            titleSpacing: 16,
            title: Row(
              children: [
                Expanded(
                  child: Text(_handle.isNotEmpty ? _handle : '@utilizador',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: appText(context))),
                ),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen())),
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: appSurface(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: appBorder(context)),
                    ),
                    child: Icon(Icons.settings_outlined, size: 18, color: appText(context)),
                  ),
                ),
              ],
            ),
          ),

          // Cabeçalho do perfil
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  // Avatar + estatísticas em linha (estilo Instagram)
                  Row(
                    children: [
                      GestureDetector(
                        onTap: _pickProfilePhoto,
                        child: _hasStory
                            ? Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [Color(0xFFF5A623), Color(0xFFE05D5D), Color(0xFF9B59B6)],
                                    begin: Alignment.topLeft, end: Alignment.bottomRight),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: appBg(context)),
                                  child: _buildAvatarWidget(radius: 38),
                                ),
                              )
                            : _buildAvatarWidget(radius: 41),
                      ),
                      const SizedBox(width: 20),
                      // Estatísticas
                      Expanded(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            StreamBuilder<QuerySnapshot>(
                              stream: _db.collection('posts').where('authorId', isEqualTo: _uid).snapshots(),
                              builder: (_, snap) {
                                final count = snap.data?.docs.length ?? 0;
                                return _StatBtn(value: '$count', label: 'Posts', onTap: () {});
                              },
                            ),
                            StreamBuilder<DocumentSnapshot>(
                              stream: _db.collection('users').doc(_uid).snapshots(),
                              builder: (_, snap) {
                                final d = snap.data?.data() as Map<String, dynamic>?;
                                final f = d?['followersCount'] ?? _followers;
                                return _StatBtn(value: '$f', label: 'Seguidores',
                                  onTap: () => Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => FollowListScreen(userId: _uid, mode: 'followers'))));
                              },
                            ),
                            StreamBuilder<DocumentSnapshot>(
                              stream: _db.collection('users').doc(_uid).snapshots(),
                              builder: (_, snap) {
                                final d = snap.data?.data() as Map<String, dynamic>?;
                                final f = d?['followingCount'] ?? _following;
                                return _StatBtn(value: '$f', label: 'A seguir',
                                  onTap: () => Navigator.push(context, MaterialPageRoute(
                                    builder: (_) => FollowListScreen(userId: _uid, mode: 'following'))));
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  Text(_displayName.isNotEmpty ? _displayName : 'Utilizador',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: appText(context))),
                  const SizedBox(height: 2),
                  if (_bio.isNotEmpty)
                    Text(_bio, style: TextStyle(fontSize: 13, color: appText(context).withValues(alpha: 0.7), height: 1.5)),
                  const SizedBox(height: 14),

                  // Botão Editar Perfil (estilo Instagram)
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _openEditProfile(context),
                          child: Container(
                            height: 34,
                            decoration: BoxDecoration(
                              color: isDark(context) ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text('Editar perfil',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: appText(context))),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Share.share('Segue-me no Litly! $_handle 📚'),
                          child: Container(
                            height: 34,
                            decoration: BoxDecoration(
                              color: isDark(context) ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text('Partilhar perfil',
                                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: appText(context))),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Banner de pedidos de seguir (só para contas privadas com pedidos)
                  StreamBuilder<QuerySnapshot>(
                    stream: UserService.followRequestsStream(),
                    builder: (_, rsnap) {
                      final n = rsnap.data?.docs.length ?? 0;
                      if (n == 0) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(
                            builder: (_) => const FollowRequestsScreen())),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isDark(context) ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(children: [
                              const Icon(Icons.person_add_rounded, size: 20, color: Color(0xFF1A1A1A)),
                              const SizedBox(width: 10),
                              Expanded(child: Text('$n pedido(s) para te seguir',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: appText(context)))),
                              const Icon(Icons.chevron_right, color: Color(0xFFAAAAAA), size: 18),
                            ]),
                          ),
                        ),
                      );
                    },
                  ),

                  // Leituras recentes do Firestore
                  const Text('Leituras recentes',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF888888), letterSpacing: 0.3)),
                  const SizedBox(height: 10),
                  StreamBuilder<QuerySnapshot>(
                    stream: _db.collection('users').doc(_uid).collection('books')
                        .orderBy('addedAt', descending: true).limit(10).snapshots(),
                    builder: (_, snap) {
                      final docs = snap.data?.docs ?? [];
                      if (docs.isEmpty) {
                        return const SizedBox(
                          height: 80,
                          child: Center(
                            child: Text('Ainda sem livros guardados',
                              style: TextStyle(fontSize: 12, color: Color(0xFFBBBBBB))),
                          ),
                        );
                      }
                      return SizedBox(
                        height: 80,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: docs.length,
                          itemBuilder: (_, i) {
                            final b = docs[i].data() as Map<String, dynamic>;
                            final cover = b['image'] ?? '';
                            final title = b['title'] ?? '';
                            return GestureDetector(
                              onTap: () => _editBookStatus(docs[i].id, b),
                              child: Padding(
                              padding: const EdgeInsets.only(right: 14),
                              child: Column(
                                children: [
                                  Container(
                                    width: 54, height: 54,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFFDDDDDD), width: 1.5),
                                    ),
                                    child: ClipOval(
                                      child: cover.isNotEmpty
                                          ? Image.network(cover, fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const Icon(Icons.menu_book_rounded, color: Color(0xFF888888), size: 24))
                                          : const Icon(Icons.menu_book_rounded, color: Color(0xFF888888), size: 24),
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  SizedBox(
                                    width: 56,
                                    child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(fontSize: 10, color: appText(context))),
                                  ),
                                ],
                              ),
                            ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // Tabs
          SliverPersistentHeader(
            pinned: true,
            delegate: _SliverTabBarDelegate(
              TabBar(
                controller: _tabCtrl,
                labelColor: appText(context),
                unselectedLabelColor: const Color(0xFFAAAAAA),
                indicatorColor: appText(context),
                indicatorWeight: 2,
                labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                dividerColor: appBorder(context),
                tabs: const [
                  Tab(icon: Icon(Icons.grid_on_rounded, size: 20)),
                  Tab(icon: Icon(Icons.menu_book_rounded, size: 20)),
                ],
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            // ── Publicações do Firestore ───────────────────────────────────
            StreamBuilder<QuerySnapshot>(
              stream: _db.collection('posts')
                  .where('authorId', isEqualTo: _uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF1A1A1A), strokeWidth: 2));
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.auto_stories_outlined, size: 48, color: Color(0xFFDDDDDD)),
                        SizedBox(height: 12),
                        Text('Ainda sem publicações.\nPartilha o que estás a ler! 📚',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF999999), fontSize: 14, height: 1.5)),
                      ],
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: docs.length,
                  itemBuilder: (_, i) => PostCard(
                    key: ValueKey(docs[i].id),
                    postId: docs[i].id,
                    data: docs[i].data() as Map<String, dynamic>,
                    isOwner: true,
                  ),
                );
              },
            ),

            // ── Livros do Firestore ─────────────────────────────────────────
            StreamBuilder<QuerySnapshot>(
              stream: _db.collection('users').doc(_uid).collection('books')
                  .orderBy('addedAt', descending: true).snapshots(),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF1A1A1A), strokeWidth: 2));
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.menu_book_outlined, size: 48, color: Color(0xFFDDDDDD)),
                        SizedBox(height: 12),
                        Text('Nenhum livro guardado ainda.\nMarca livros no Pesquisar! 🔖',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF999999), fontSize: 14, height: 1.5)),
                      ],
                    ),
                  );
                }
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.62,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (_, i) {
                    final b = docs[i].data() as Map<String, dynamic>;
                    final bookId = docs[i].id;
                    final cover = b['image'] ?? '';
                    final title = b['title'] ?? '';
                    final status = b['status'] ?? '';
                    final statusLabel = status == 'done' ? '✅' : status == 'reading' ? '📖' : '🔖';
                    return GestureDetector(
                      onTap: () => _editBookStatus(bookId, b),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: cover.isNotEmpty
                                      ? Image.network(cover, fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => _bookBg())
                                      : _bookBg(),
                                ),
                                Positioned(
                                  top: 4, right: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(statusLabel, style: const TextStyle(fontSize: 10)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ── Estatística clicável ───────────────────────────────────────────────────────
class _StatBtn extends StatelessWidget {
  final String value, label;
  final VoidCallback onTap;
  const _StatBtn({required this.value, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: appText(context))),
          const SizedBox(height: 1),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
        ],
      ),
    );
  }
}

// ── Ecrã de lista de seguidores/a seguir ──────────────────────────────────────
class _FollowListScreen extends StatefulWidget {
  final String title;
  final List<_User> users;
  final int count;
  const _FollowListScreen({required this.title, required this.users, required this.count});

  @override
  State<_FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<_FollowListScreen> {
  final _searchCtrl = TextEditingController();
  late List<_User> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.users;
  }

  void _onSearch(String q) {
    setState(() {
      _filtered = widget.users.where((u) =>
        u.name.toLowerCase().contains(q.toLowerCase()) ||
        u.handle.toLowerCase().contains(q.toLowerCase())).toList();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBg(context),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18, color: Color(0xFF1A1A1A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(widget.title,
              style: const TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.w700, fontSize: 16)),
            Text('${widget.count}',
              style: const TextStyle(color: Color(0xFF888888), fontSize: 12)),
          ],
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(12),
              ),
              child: TextField(
                controller: _searchCtrl,
                onChanged: _onSearch,
                decoration: const InputDecoration(
                  hintText: 'Pesquisar',
                  hintStyle: TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
                  prefixIcon: Icon(Icons.search, color: Color(0xFFAAAAAA), size: 18),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),
          ),
        ),
      ),
      body: _filtered.isEmpty
          ? const Center(child: Text('Nenhum resultado.', style: TextStyle(color: Color(0xFFAAAAAA))))
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: _filtered.length,
              itemBuilder: (_, i) => _UserRow(user: _filtered[i]),
            ),
    );
  }
}

// ── Linha de utilizador ────────────────────────────────────────────────────────
class _UserRow extends StatefulWidget {
  final _User user;
  const _UserRow({required this.user});

  @override
  State<_UserRow> createState() => _UserRowState();
}

class _UserRowState extends State<_UserRow> {
  bool _following = false;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        radius: 22,
        backgroundColor: const Color(0xFFEEEEEE),
        child: Text(widget.user.name[0],
          style: const TextStyle(color: Color(0xFF555555), fontWeight: FontWeight.bold, fontSize: 16)),
      ),
      title: Text(widget.user.name,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
      subtitle: Text(widget.user.handle,
        style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
      trailing: GestureDetector(
        onTap: () => setState(() => _following = !_following),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: _following ? const Color(0xFFEEEEEE) : const Color(0xFF1A1A1A),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            _following ? 'A seguir' : 'Seguir',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _following ? const Color(0xFF555555) : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Settings ───────────────────────────────────────────────────────────────────
class SettingsScreen extends StatelessWidget {
  const SettingsScreen();

  @override
  Widget build(BuildContext context) {
    final sections = [
      {
        'title': 'Conta',
        'items': [
          (Icons.person_outline_rounded, 'Editar perfil'),
          (Icons.lock_outline_rounded, 'Privacidade'),
          (Icons.block_rounded, 'Contas bloqueadas'),
        ]
      },
      {
        'title': 'Preferências',
        'items': [
          (Icons.notifications_none_rounded, 'Notificações'),
          (Icons.palette_outlined, 'Aparência'),
          (Icons.translate_outlined, 'Língua'),
        ]
      },
      {
        'title': 'Suporte',
        'items': [
          (Icons.help_outline_rounded, 'Centro de ajuda'),
          (Icons.flag_outlined, 'Reportar problema'),
          (Icons.info_outline_rounded, 'Sobre o Litly'),
        ]
      },
    ];

    return Scaffold(
      backgroundColor: appBg(context),
      appBar: AppBar(
        backgroundColor: appSurface(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: appText(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Definições',
          style: TextStyle(color: appText(context), fontWeight: FontWeight.w700, fontSize: 17)),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Painel de Administrador (só visível para admins)
          StreamBuilder<bool>(
            stream: AdminService.isAdminStream(FirebaseAuth.instance.currentUser?.uid ?? ''),
            builder: (_, asnap) {
              if (asnap.data != true) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen())),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF9B59B6), Color(0xFF6C3483)]),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(children: [
                      Icon(Icons.shield_rounded, color: Colors.white, size: 22),
                      SizedBox(width: 12),
                      Expanded(child: Text('Painel de Administrador',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15))),
                      Icon(Icons.chevron_right, color: Colors.white70),
                    ]),
                  ),
                ),
              );
            },
          ),
          ...sections.expand((s) => [
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 6),
              child: Text((s['title'] as String),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF888888), letterSpacing: 0.5)),
            ),
            Container(
              decoration: BoxDecoration(
                color: appSurface(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: appBorder(context)),
              ),
              child: Column(
                children: (s['items'] as List).asMap().entries.map((entry) {
                  final idx = entry.key;
                  final item = entry.value as (IconData, String);
                  return Column(
                    children: [
                      ListTile(
                        leading: Icon(item.$1, color: appText(context), size: 20),
                        title: Text(item.$2,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: appText(context))),
                        trailing: const Icon(Icons.chevron_right, color: Color(0xFFCCCCCC), size: 18),
                        onTap: () {
                          final Widget? dest = switch (item.$2) {
                            'Editar perfil'      => const EditProfileScreen(),
                            'Privacidade'        => const PrivacyScreen(),
                            'Contas bloqueadas'  => const BlockedUsersScreen(),
                            'Notificações'       => const NotificationsSettingsScreen(),
                            'Aparência'          => const AppearanceScreen(),
                            'Língua'             => const LanguageScreen(),
                            'Centro de ajuda'    => const HelpScreen(),
                            'Reportar problema'  => const ReportProblemScreen(),
                            'Sobre o Litly'      => const AboutScreen(),
                            _                    => null,
                          };
                          if (dest != null) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => dest));
                          }
                        },
                      ),
                      if (idx < (s['items'] as List).length - 1)
                        const Divider(height: 1, indent: 56, color: Color(0xFFF5F5F5)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ]),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: const Text('Terminar sessão?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  content: const Text('Tens a certeza que queres sair?'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false),
                      child: const Text('Cancelar', style: TextStyle(color: Color(0xFF888888)))),
                    TextButton(onPressed: () => Navigator.pop(context, true),
                      child: const Text('Sair', style: TextStyle(color: Color(0xFFE05D5D), fontWeight: FontWeight.w700))),
                  ],
                ),
              );
              if (confirmed == true) {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                    (_) => false,
                  );
                }
              }
            },
            child: Container(
              height: 50,
              decoration: BoxDecoration(
                color: appSurface(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: appBorder(context)),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.logout_rounded, color: Color(0xFFE05D5D), size: 18),
                  SizedBox(width: 8),
                  Text('Terminar sessão',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFFE05D5D))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

// ── SliverPersistentHeader delegate ──────────────────────────────────────────
class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  const _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: appSurface(context),
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) => true;
}

// ── Modelos ───────────────────────────────────────────────────────────────────
class _User {
  final String name, handle;
  const _User({required this.name, required this.handle});
}


// ── Campo de texto para edição de perfil ─────────────────────────────────────
class _EditField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  const _EditField({required this.controller, required this.hint, this.maxLines = 1});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: const Color(0xFFF5F5F5),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: const Color(0xFFEEEEEE)),
    ),
    child: TextField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(fontSize: 14, color: Color(0xFF1A1A1A)),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFBBBBBB), fontSize: 14),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    ),
  );
}

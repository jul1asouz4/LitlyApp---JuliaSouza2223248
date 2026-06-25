import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';
import '../widgets/post_card.dart';
import 'follow_list_screen.dart';
import 'chat_list_screen.dart';
import '../theme.dart';

class OtherUserProfileScreen extends StatefulWidget {
  final String userId, name, avatar, photoUrl;
  const OtherUserProfileScreen({
    super.key,
    required this.userId,
    required this.name,
    required this.avatar,
    required this.photoUrl,
  });

  @override
  State<OtherUserProfileScreen> createState() => _OtherUserProfileScreenState();
}

class _OtherUserProfileScreenState extends State<OtherUserProfileScreen> {
  Future<void> _onFollowTap(bool following, bool pending) async {
    if (following) {
      await UserService.unfollowUser(widget.userId);
    } else if (pending) {
      await UserService.cancelFollowRequest(widget.userId);
    } else {
      await UserService.followUser(widget.userId,
          targetName: widget.name, targetPhoto: widget.photoUrl);
    }
  }

  void _reportUser() {
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
              const SizedBox(height: 14),
              ...['Spam', 'Comportamento abusivo', 'Conteúdo inapropriado', 'Perfil falso', 'Outro'].map((r) =>
                RadioListTile<String>(
                  value: r, groupValue: _reason,
                  onChanged: (v) => setModal(() => _reason = v),
                  title: Text(r, style: const TextStyle(fontSize: 14)),
                  activeColor: const Color(0xFF1A1A1A),
                  contentPadding: EdgeInsets.zero, dense: true,
                )),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity, height: 46,
                child: ElevatedButton(
                  onPressed: _reason == null ? null : () async {
                    await UserService.reportUser(widget.userId, _reason!);
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
        title: Text(widget.name, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: appText(context))),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: appText(context)),
            color: appSurface(context),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            onSelected: (v) async {
              if (v == 'block') {
                await UserService.blockUser(widget.userId);
                if (mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${widget.name} foi bloqueado.'),
                    backgroundColor: const Color(0xFF333333), behavior: SnackBarBehavior.floating));
                }
              } else if (v == 'report') {
                _reportUser();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'report', child: Row(children: [
                Icon(Icons.flag_outlined, size: 18, color: Color(0xFFE05D5D)),
                SizedBox(width: 10),
                Text('Reportar', style: TextStyle(color: Color(0xFFE05D5D))),
              ])),
              const PopupMenuItem(value: 'block', child: Row(children: [
                Icon(Icons.block_rounded, size: 18, color: Color(0xFFE05D5D)),
                SizedBox(width: 10),
                Text('Bloquear', style: TextStyle(color: Color(0xFFE05D5D))),
              ])),
            ],
          ),
        ],
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1), child: Container(height: 1, color: appField(context))),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users')
            .doc(FirebaseAuth.instance.currentUser?.uid ?? '_').snapshots(),
        builder: (context, meSnap) {
          final blocked = List<String>.from(
              (meSnap.data?.data() as Map<String, dynamic>?)?['blockedUsers'] ?? []);
          if (blocked.contains(widget.userId)) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.block_rounded, size: 48, color: Color(0xFFBBBBBB)),
                  const SizedBox(height: 14),
                  Text('Bloqueaste ${widget.name}',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: appText(context))),
                  const SizedBox(height: 6),
                  const Text('Não vês o conteúdo desta conta enquanto estiver bloqueada.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA))),
                  const SizedBox(height: 18),
                  OutlinedButton(
                    onPressed: () => UserService.unblockUser(widget.userId),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Color(0xFFDDDDDD)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    child: Text('Desbloquear', style: TextStyle(color: appText(context), fontWeight: FontWeight.w700)),
                  ),
                ]),
              ),
            );
          }
          return StreamBuilder<DocumentSnapshot>(
        stream: UserService.userStream(widget.userId),
        builder: (context, snap) {
          // Conta apagada/desativada
          if (snap.hasData && snap.data?.exists == false) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const CircleAvatar(radius: 40, backgroundColor: Color(0xFFCCCCCC),
                    child: Icon(Icons.person_off_rounded, color: Colors.white, size: 38)),
                  const SizedBox(height: 16),
                  Text('Conta desativada',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: appText(context))),
                  const SizedBox(height: 6),
                  const Text('Esta conta já não existe.',
                    textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA))),
                ]),
              ),
            );
          }
          final data = snap.data?.data() as Map<String, dynamic>?;
          final followers = data?['followersCount'] ?? 0;
          final following = data?['followingCount'] ?? 0;
          final bio = data?['bio'] ?? '';
          final photoUrl = data?['photoUrl'] ?? widget.photoUrl;
          final handle = data?['handle'] ?? data?['username'] ?? '';

          return SingleChildScrollView(
            child: Column(
              children: [
                // Cabeçalho
                Container(
                  color: appSurface(context),
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
                  child: Column(
                    children: [
                      // Avatar
                      photoUrl.isNotEmpty
                          ? CircleAvatar(radius: 44, backgroundImage: (avatarProvider(photoUrl) ?? NetworkImage(photoUrl)))
                          : CircleAvatar(radius: 44, backgroundColor: const Color(0xFF1A1A1A),
                              child: Text(widget.avatar, style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.bold))),
                      const SizedBox(height: 12),
                      Text(widget.name, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: appText(context))),
                      if (handle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(handle, style: const TextStyle(fontSize: 13, color: Color(0xFF888888))),
                      ],
                      if (bio.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(bio, textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: appText(context), height: 1.5)),
                      ],
                      const SizedBox(height: 16),

                      // Estatísticas
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance.collection('posts')
                                .where('authorId', isEqualTo: widget.userId).snapshots(),
                            builder: (_, ps) => _Stat(value: '${ps.data?.docs.length ?? 0}', label: 'Posts'),
                          ),
                          _Stat(value: '$followers', label: 'Seguidores',
                            onTap: () => Navigator.push(context, MaterialPageRoute(
                              builder: (_) => FollowListScreen(userId: widget.userId, mode: 'followers')))),
                          _Stat(value: '$following', label: 'A seguir',
                            onTap: () => Navigator.push(context, MaterialPageRoute(
                              builder: (_) => FollowListScreen(userId: widget.userId, mode: 'following')))),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Botões
                      Row(
                        children: [
                          Expanded(
                            child: StreamBuilder<bool>(
                              stream: UserService.isFollowingStream(widget.userId),
                              builder: (_, fSnap) {
                                final following = fSnap.data ?? false;
                                return StreamBuilder<bool>(
                                  stream: UserService.hasPendingRequestStream(widget.userId),
                                  builder: (_, pSnap) {
                                    final pending = pSnap.data ?? false;
                                    final isPrivate = data?['isPrivate'] == true;
                                    final label = following ? 'A seguir'
                                        : pending ? 'Pedido enviado'
                                        : isPrivate ? 'Pedir para seguir' : 'Seguir';
                                    final filled = !following && !pending;
                                    return GestureDetector(
                                      onTap: () => _onFollowTap(following, pending),
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        height: 38,
                                        decoration: BoxDecoration(
                                          color: filled ? const Color(0xFF1A1A1A) : (isDark(context) ? const Color(0xFF2A2A2A) : Colors.white),
                                          borderRadius: BorderRadius.circular(10),
                                          border: Border.all(color: filled ? const Color(0xFF1A1A1A) : appBorder(context)),
                                        ),
                                        child: Center(child: Text(label,
                                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                                            color: filled ? Colors.white : appText(context)),
                                          maxLines: 1, overflow: TextOverflow.ellipsis)),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: GestureDetector(
                              onTap: () => Navigator.push(context, MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  name: widget.name,
                                  avatar: widget.avatar,
                                  otherId: widget.userId,
                                  otherPhotoUrl: photoUrl,
                                ),
                              )),
                              child: Container(
                                height: 38,
                                decoration: BoxDecoration(
                                  color: isDark(context) ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(child: Text('Mensagem',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: appText(context)))),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),

                StreamBuilder<bool>(
                  stream: UserService.isFollowingStream(widget.userId),
                  builder: (_, fs) {
                    final isFollowing = fs.data ?? false;
                    final isSelf = widget.userId == (FirebaseAuth.instance.currentUser?.uid ?? '');
                    if ((data?['isPrivate'] == true) && !isFollowing && !isSelf) {
                      return const Padding(
                        padding: EdgeInsets.fromLTRB(24, 50, 24, 50),
                        child: Column(children: [
                          Icon(Icons.lock_outline_rounded, size: 46, color: Color(0xFFBBBBBB)),
                          SizedBox(height: 12),
                          Text('Esta conta é privada', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: Color(0xFF888888))),
                          SizedBox(height: 6),
                          Text('Segue esta conta para ver as publicações e os livros.',
                            textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA))),
                        ]),
                      );
                    }
                    return Column(children: [
                // Leituras recentes (bolinhas de livros)
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(widget.userId)
                      .collection('books').orderBy('addedAt', descending: true).limit(12).snapshots(),
                  builder: (_, bs) {
                    final books = bs.data?.docs ?? [];
                    if (books.isEmpty) return const SizedBox.shrink();
                    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 8, 16, 6),
                        child: Text('Leituras recentes',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF888888), letterSpacing: 0.3)),
                      ),
                      SizedBox(
                        height: 86,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          itemCount: books.length,
                          itemBuilder: (_, i) {
                            final b = books[i].data() as Map<String, dynamic>;
                            final cover = (b['image'] ?? '').toString();
                            final title = (b['title'] ?? '').toString();
                            return Padding(
                              padding: const EdgeInsets.only(right: 14),
                              child: Column(children: [
                                Container(
                                  width: 54, height: 54,
                                  decoration: BoxDecoration(shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFFDDDDDD), width: 1.5)),
                                  child: ClipOval(
                                    child: cover.isNotEmpty
                                        ? Image.network(cover, fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Icon(Icons.menu_book_rounded, color: Color(0xFF888888), size: 24))
                                        : const Icon(Icons.menu_book_rounded, color: Color(0xFF888888), size: 24),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                SizedBox(width: 56,
                                  child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                                    style: TextStyle(fontSize: 10, color: appText(context)))),
                              ]),
                            );
                          },
                        ),
                      ),
                    ]);
                  },
                ),
                // Publicações do utilizador
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 6),
                  child: Align(alignment: Alignment.centerLeft,
                    child: Text('Publicações',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF888888), letterSpacing: 0.3))),
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance.collection('posts')
                      .where('authorId', isEqualTo: widget.userId)
                      .snapshots(),
                  builder: (context, postsSnap) {
                    final postDocs = (postsSnap.data?.docs ?? []).toList()
                      ..sort((a, b) {
                        final at = (a.data() as Map)['createdAt'] as Timestamp?;
                        final bt = (b.data() as Map)['createdAt'] as Timestamp?;
                        if (at == null && bt == null) return 0;
                        if (at == null) return 1;
                        if (bt == null) return -1;
                        return bt.compareTo(at);
                      });
                    if (postDocs.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: Text('Sem publicações ainda.', style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 14))),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      itemCount: postDocs.length,
                      itemBuilder: (_, i) => PostCard(
                        key: ValueKey(postDocs[i].id),
                        postId: postDocs[i].id,
                        data: postDocs[i].data() as Map<String, dynamic>,
                      ),
                    );
                  },
                ),

                // Livros do utilizador
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, 6),
                  child: Align(alignment: Alignment.centerLeft,
                    child: Text('Livros',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF888888), letterSpacing: 0.3))),
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users').doc(widget.userId).collection('books').snapshots(),
                  builder: (_, bSnap) {
                    final books = bSnap.data?.docs ?? [];
                    if (books.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.fromLTRB(16, 0, 16, 24),
                        child: Center(child: Text('Sem livros guardados.', style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 14))),
                      );
                    }
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 0.62),
                      itemCount: books.length,
                      itemBuilder: (_, i) {
                        final b = books[i].data() as Map<String, dynamic>;
                        final cover = b['image'] ?? '';
                        final title = b['title'] ?? '';
                        final status = b['status'] ?? '';
                        final label = status == 'done' ? '✅' : status == 'reading' ? '📖' : '🔖';
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Stack(fit: StackFit.expand, children: [
                                ClipRRect(borderRadius: BorderRadius.circular(8),
                                  child: cover.toString().isNotEmpty
                                      ? Image.network(cover, fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(color: appField(context),
                                            child: const Icon(Icons.book, color: Colors.grey, size: 26)))
                                      : Container(color: appField(context),
                                          child: const Icon(Icons.book, color: Colors.grey, size: 26))),
                                Positioned(top: 4, right: 4,
                                  child: Container(padding: const EdgeInsets.all(3),
                                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                                    child: Text(label, style: const TextStyle(fontSize: 10)))),
                              ]),
                            ),
                            const SizedBox(height: 4),
                            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: appText(context))),
                          ],
                        );
                      },
                    );
                  },
                ),
                    ]);
                  },
                ),
              ],
            ),
          );
        },
      );
        },
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value, label;
  final VoidCallback? onTap;
  const _Stat({required this.value, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: appText(context))),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF888888))),
      ],
    ),
  );
}

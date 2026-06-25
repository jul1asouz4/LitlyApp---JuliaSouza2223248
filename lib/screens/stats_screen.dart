import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme.dart';
import '../widgets/post_card.dart';

class StatsScreen extends StatelessWidget {
  const StatsScreen({super.key});

  String get _uid => FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    final db = FirebaseFirestore.instance;
    return Scaffold(
      backgroundColor: appBg(context),
      appBar: AppBar(
        backgroundColor: appSurface(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: appText(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Estatísticas',
          style: TextStyle(color: appText(context), fontWeight: FontWeight.w700, fontSize: 17)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: appBorder(context)),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: db.collection('users').doc(_uid).collection('books').snapshots(),
        builder: (_, booksSnap) {
          final books = booksSnap.data?.docs ?? [];
          int read = 0, reading = 0, want = 0;
          final genres = <String, int>{};
          for (final b in books) {
            final data = b.data() as Map<String, dynamic>;
            switch (data['status']) {
              case 'done': read++; break;
              case 'reading': reading++; break;
              case 'want': want++; break;
            }
            final g = (data['genre'] ?? data['category'] ?? '').toString();
            if (g.isNotEmpty) genres[g] = (genres[g] ?? 0) + 1;
          }

          return StreamBuilder<QuerySnapshot>(
            stream: db.collection('posts').where('authorId', isEqualTo: _uid).snapshots(),
            builder: (_, postsSnap) {
              final posts = postsSnap.data?.docs ?? [];
              int likesReceived = 0;
              for (final p in posts) {
                final data = p.data() as Map<String, dynamic>;
                likesReceived += List.from(data['likedBy'] ?? []).length;
              }

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _SectionTitle('Resumo'),
                  const SizedBox(height: 10),
                  Row(children: [
                    _StatCard(value: '$read', label: 'Livros lidos', icon: Icons.menu_book_rounded, color: appText(context),
                      onTap: () => _openBookList(context, 'done', 'Livros lidos')),
                    const SizedBox(width: 10),
                    _StatCard(value: '${books.length}', label: 'Livros na biblioteca', icon: Icons.library_books_outlined, color: appText(context),
                      onTap: () => _openBookList(context, 'all', 'Livros na biblioteca')),
                  ]),
                  const SizedBox(height: 10),
                  Row(children: [
                    _StatCard(value: '${posts.length}', label: 'Posts publicados', icon: Icons.edit_outlined, color: appText(context),
                      onTap: () => _openMyPosts(context, title: 'Posts publicados')),
                    const SizedBox(width: 10),
                    _StatCard(value: '$likesReceived', label: 'Gostos recebidos', icon: Icons.favorite_rounded, color: const Color(0xFFE05D5D),
                      onTap: () => _openMyPosts(context, title: 'Gostos recebidos', likedOnly: true)),
                  ]),
                  const SizedBox(height: 24),

                  _SectionTitle('Biblioteca pessoal'),
                  const SizedBox(height: 10),
                  _LibraryRow(label: 'Lidos', count: read, icon: Icons.check_circle_outline_rounded, color: const Color(0xFF4CAF50),
                    onTap: () => _openBookList(context, 'done', 'Lidos')),
                  _LibraryRow(label: 'A ler', count: reading, icon: Icons.menu_book_rounded, color: appText(context),
                    onTap: () => _openBookList(context, 'reading', 'A ler')),
                  _LibraryRow(label: 'Quero ler', count: want, icon: Icons.bookmark_border_rounded, color: const Color(0xFFF5A623),
                    onTap: () => _openBookList(context, 'want', 'Quero ler')),
                  const SizedBox(height: 24),

                  if (genres.isNotEmpty) ...[
                    _SectionTitle('Géneros favoritos'),
                    const SizedBox(height: 10),
                    ..._topGenres(genres, books.length),
                    const SizedBox(height: 24),
                  ],

                  _SectionTitle('Meta de leitura ${DateTime.now().year}'),
                  const SizedBox(height: 12),
                  StreamBuilder<DocumentSnapshot>(
                    stream: db.collection('users').doc(_uid).snapshots(),
                    builder: (_, uSnap) {
                      final goal = ((uSnap.data?.data() as Map<String, dynamic>?)?['readingGoal'] ?? 52) as int;
                      return _GoalWidget(current: read, goal: goal,
                        onEdit: () => _editGoal(context, goal));
                    },
                  ),
                  const SizedBox(height: 32),
                ],
              );
            },
          );
        },
      ),
    );
  }

  void _editGoal(BuildContext context, int current) {
    final ctrl = TextEditingController(text: '$current');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: appSurface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Meta de leitura', style: TextStyle(fontWeight: FontWeight.w700, color: appText(context))),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          style: TextStyle(color: appText(context)),
          decoration: const InputDecoration(
            hintText: 'Quantos livros este ano?',
            suffixText: 'livros',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF888888)))),
          TextButton(
            onPressed: () async {
              final v = int.tryParse(ctrl.text.trim());
              if (v != null && v > 0) {
                await FirebaseFirestore.instance.collection('users').doc(_uid)
                    .set({'readingGoal': v}, SetOptions(merge: true));
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: const Text('Guardar', style: TextStyle(color: Color(0xFF2E7D32), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _openBookList(BuildContext context, String status, String title) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _BookStatusListScreen(uid: _uid, status: status, title: title)));
  }

  void _openMyPosts(BuildContext context, {required String title, bool likedOnly = false}) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _MyPostsListScreen(uid: _uid, title: title, likedOnly: likedOnly)));
  }

  List<Widget> _topGenres(Map<String, int> genres, int total) {
    final sorted = genres.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(4).map((e) => _GenreBar(genre: e.key, pct: total > 0 ? e.value / total : 0)).toList();
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF888888), letterSpacing: 0.3));
}

class _StatCard extends StatelessWidget {
  final String value, label;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _StatCard({required this.value, required this.label, required this.icon, required this.color, this.onTap});
  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: appSurface(context),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: appBorder(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, color: color, size: 22),
              const Spacer(),
              if (onTap != null) const Icon(Icons.chevron_right, color: Color(0xFFAAAAAA), size: 18),
            ]),
            const SizedBox(height: 10),
            Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: appText(context))),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
          ],
        ),
      ),
    ),
  );
}

class _LibraryRow extends StatelessWidget {
  final String label;
  final int count;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  const _LibraryRow({required this.label, required this.count, required this.icon, required this.color, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: appSurface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appBorder(context)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: appText(context)))),
          Text('$count livros', style: const TextStyle(fontSize: 13, color: Color(0xFF888888), fontWeight: FontWeight.w600)),
          const SizedBox(width: 6),
          const Icon(Icons.chevron_right, color: Color(0xFFAAAAAA), size: 18),
        ],
      ),
    ),
  );
}

// ── Lista de livros por estado ────────────────────────────────────────────────
class _BookStatusListScreen extends StatelessWidget {
  final String uid, status, title;
  const _BookStatusListScreen({required this.uid, required this.status, required this.title});

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
      body: StreamBuilder<QuerySnapshot>(
        stream: status == 'all'
            ? FirebaseFirestore.instance.collection('users').doc(uid).collection('books').snapshots()
            : FirebaseFirestore.instance
                .collection('users').doc(uid).collection('books')
                .where('status', isEqualTo: status).snapshots(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(child: Text('Sem livros em "$title".',
              style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14)));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 14, childAspectRatio: 0.6),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final b = docs[i].data() as Map<String, dynamic>;
              final cover = (b['image'] ?? '').toString();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: cover.isNotEmpty
                          ? Image.network(cover, width: double.infinity, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(color: appField(context),
                                child: const Icon(Icons.book, color: Colors.grey)))
                          : Container(color: appField(context),
                              child: const Icon(Icons.book, color: Colors.grey)),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(b['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: appText(context))),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _GenreBar extends StatelessWidget {
  final String genre;
  final double pct;
  const _GenreBar({required this.genre, required this.pct});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(genre, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: appText(context))),
            Text('${(pct * 100).toInt()}%', style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct, minHeight: 7,
            backgroundColor: isDark(context) ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEEE),
            valueColor: AlwaysStoppedAnimation<Color>(appText(context)),
          ),
        ),
      ],
    ),
  );
}

class _GoalWidget extends StatelessWidget {
  final int current, goal;
  final VoidCallback? onEdit;
  const _GoalWidget({required this.current, required this.goal, this.onEdit});
  @override
  Widget build(BuildContext context) {
    final pct = (current / goal).clamp(0.0, 1.0);
    final remaining = goal - current;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: appSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appBorder(context)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$current de $goal livros',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: appText(context))),
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark(context) ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(8)),
                  child: Text('${(pct * 100).toInt()}%',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: appText(context))),
                ),
                if (onEdit != null) ...[
                  const SizedBox(width: 8),
                  GestureDetector(onTap: onEdit,
                    child: const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF888888))),
                ],
              ]),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: pct, minHeight: 10,
              backgroundColor: isDark(context) ? const Color(0xFF2C2C2C) : const Color(0xFFEEEEEE),
              valueColor: AlwaysStoppedAnimation<Color>(appText(context)),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            current == 0 ? 'Marca livros como "Lido" para começares! 📖'
                : remaining > 0 ? 'Faltam $remaining livros para atingires a meta! 💪'
                : '🎉 Meta atingida! Parabéns!',
            style: const TextStyle(fontSize: 13, color: Color(0xFF888888)),
          ),
        ],
      ),
    );
  }
}

// ── Lista de posts (publicados / com gostos) ─────────────────────────────────
class _MyPostsListScreen extends StatelessWidget {
  final String uid, title;
  final bool likedOnly;
  const _MyPostsListScreen({required this.uid, required this.title, this.likedOnly = false});

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
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('posts').where('authorId', isEqualTo: uid).snapshots(),
        builder: (_, snap) {
          var docs = snap.data?.docs ?? [];
          if (likedOnly) {
            docs = docs.where((d) =>
                List.from((d.data() as Map<String, dynamic>)['likedBy'] ?? []).isNotEmpty).toList();
          }
          // Mais recentes primeiro
          docs.sort((a, b) {
            final ta = (a.data() as Map<String, dynamic>)['createdAt'];
            final tb = (b.data() as Map<String, dynamic>)['createdAt'];
            if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
            return 0;
          });
          if (docs.isEmpty) {
            return Center(child: Text(
              likedOnly ? 'Ainda não recebeste gostos.' : 'Ainda não publicaste nada.',
              style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14)));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              return PostCard(
                key: ValueKey(docs[i].id),
                postId: docs[i].id,
                data: d,
                isOwner: true,
              );
            },
          );
        },
      ),
    );
  }
}

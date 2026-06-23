import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/admin_service.dart';
import '../theme.dart';
import 'other_user_profile_screen.dart';

class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});
  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> with SingleTickerProviderStateMixin {
  late TabController _tab;
  @override
  void initState() { super.initState(); _tab = TabController(length: 5, vsync: this); }
  @override
  void dispose() { _tab.dispose(); super.dispose(); }

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
        title: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.shield_rounded, size: 18, color: Color(0xFF9B59B6)),
          const SizedBox(width: 8),
          Text('Administrador', style: TextStyle(color: appText(context), fontWeight: FontWeight.w700, fontSize: 16)),
        ]),
        centerTitle: true,
        bottom: TabBar(
          controller: _tab,
          isScrollable: true,
          labelColor: appText(context),
          unselectedLabelColor: const Color(0xFF888888),
          indicatorColor: const Color(0xFF9B59B6),
          tabs: const [
            Tab(text: '📊 Estatísticas'),
            Tab(text: '📝 Publicações'),
            Tab(text: '🚩 Reports'),
            Tab(text: '💬 Feedback'),
            Tab(text: '👥 Utilizadores'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tab,
        children: const [_StatsTab(), _PostsTab(), _ReportsTab(), _FeedbackTab(), _UsersTab()],
      ),
    );
  }
}

// ── Estatísticas globais ──────────────────────────────────────────────────────
class _StatsTab extends StatelessWidget {
  const _StatsTab();
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: AdminService.usersStream(),
      builder: (_, usnap) {
        final users = usnap.data?.docs ?? [];
        final privateN = users.where((d) => (d.data() as Map)['isPrivate'] == true).length;
        return StreamBuilder<QuerySnapshot>(
          stream: AdminService.postsCountStream(),
          builder: (_, psnap) {
            final posts = psnap.data?.docs ?? [];
            final writings = posts.where((d) => (d.data() as Map)['kind'] == 'writing').length;
            int likes = 0;
            for (final p in posts) {
              likes += List.from((p.data() as Map)['likedBy'] ?? []).length;
            }
            return GridView.count(
              padding: const EdgeInsets.all(16),
              crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5,
              children: [
                _statCard(context, '${users.length}', 'Utilizadores', Icons.people_rounded, const Color(0xFF1A1A1A)),
                _statCard(context, '${posts.length}', 'Publicações', Icons.article_rounded, const Color(0xFF3498DB)),
                _statCard(context, '$writings', 'Escritas', Icons.edit_note_rounded, const Color(0xFF9B59B6)),
                _statCard(context, '$likes', 'Gostos totais', Icons.favorite_rounded, const Color(0xFFE05D5D)),
                _statCard(context, '$privateN', 'Contas privadas', Icons.lock_rounded, const Color(0xFFF5A623)),
                _statCard(context, '${users.length - privateN}', 'Contas públicas', Icons.public_rounded, const Color(0xFF4CAF50)),
              ],
            );
          },
        );
      },
    );
  }

  Widget _statCard(BuildContext context, String value, String label, IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: appSurface(context), borderRadius: BorderRadius.circular(16), border: Border.all(color: appBorder(context))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: color, size: 26),
      const SizedBox(height: 8),
      Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: appText(context))),
      Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
    ]),
  );
}

// ── Publicações (moderação) ───────────────────────────────────────────────────
class _PostsTab extends StatelessWidget {
  const _PostsTab();

  void _confirmDelete(BuildContext context, String postId, String preview) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: appSurface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Apagar publicação?', style: TextStyle(fontWeight: FontWeight.w700, color: appText(context))),
        content: Text(preview.isEmpty ? 'Esta ação é permanente.' : '"$preview"\n\nEsta ação é permanente.',
          style: TextStyle(color: appText(context).withValues(alpha: 0.8))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: Color(0xFF888888)))),
          TextButton(
            onPressed: () async { await AdminService.deletePost(postId); if (ctx.mounted) Navigator.pop(ctx); },
            child: const Text('Apagar', style: TextStyle(color: Color(0xFFE05D5D), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: AdminService.postsStream(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const _Empty(icon: Icons.article_outlined, text: 'Sem publicações.');
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final p = docs[i].data() as Map<String, dynamic>;
            final id = docs[i].id;
            final isWriting = p['kind'] == 'writing';
            final author = (p['authorName'] ?? 'Utilizador').toString();
            final text = (p['text'] ?? '').toString();
            final title = (p['writingTitle'] ?? '').toString();
            final preview = isWriting ? title : text;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: appSurface(context), borderRadius: BorderRadius.circular(14), border: Border.all(color: appBorder(context))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  if (isWriting)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: const Color(0xFF9B59B6).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                      child: Text('✍️ ${p['writingCategory'] ?? 'Escrita'}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF9B59B6))),
                    ),
                  Expanded(child: Text(author, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: appText(context)))),
                  if ((p['authorPrivate'] == true))
                    const Icon(Icons.lock, size: 13, color: Color(0xFFF5A623)),
                ]),
                const SizedBox(height: 6),
                if (isWriting && title.isNotEmpty)
                  Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: appText(context))),
                if (text.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(text, maxLines: 3, overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 13, color: appText(context).withValues(alpha: 0.8), height: 1.4)),
                  ),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('❤️ ${List.from(p['likedBy'] ?? []).length}', style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                  TextButton.icon(
                    onPressed: () => _confirmDelete(context, id, preview),
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Color(0xFFE05D5D)),
                    label: const Text('Apagar', style: TextStyle(color: Color(0xFFE05D5D), fontWeight: FontWeight.w700)),
                  ),
                ]),
              ]),
            );
          },
        );
      },
    );
  }
}

// ── Reports ───────────────────────────────────────────────────────────────────
class _ReportsTab extends StatelessWidget {
  const _ReportsTab();
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: AdminService.reportsStream(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const _Empty(icon: Icons.flag_outlined, text: 'Sem reports pendentes.');
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final r = docs[i].data() as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: appSurface(context), borderRadius: BorderRadius.circular(14), border: Border.all(color: appBorder(context))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.flag_rounded, color: Color(0xFFE05D5D), size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text('Motivo: ${r['reason'] ?? '—'}',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: appText(context)))),
                ]),
                const SizedBox(height: 6),
                Text('Utilizador reportado: ${r['targetUid'] ?? '—'}',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF888888))),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => AdminService.dismissReport(docs[i].id),
                    child: const Text('Resolver', style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            );
          },
        );
      },
    );
  }
}

// ── Feedback ──────────────────────────────────────────────────────────────────
class _FeedbackTab extends StatelessWidget {
  const _FeedbackTab();
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: AdminService.feedbackStream(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const _Empty(icon: Icons.chat_bubble_outline_rounded, text: 'Sem feedback.');
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final f = docs[i].data() as Map<String, dynamic>;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: appSurface(context), borderRadius: BorderRadius.circular(14), border: Border.all(color: appBorder(context))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(f['message'] ?? '', style: TextStyle(fontSize: 14, color: appText(context), height: 1.4)),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => AdminService.dismissFeedback(docs[i].id),
                    child: const Text('Marcar como lido', style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.w700)),
                  ),
                ),
              ]),
            );
          },
        );
      },
    );
  }
}

// ── Utilizadores ──────────────────────────────────────────────────────────────
class _UsersTab extends StatelessWidget {
  const _UsersTab();
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: AdminService.usersStream(),
      builder: (_, snap) {
        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) return const _Empty(icon: Icons.people_outline, text: 'Sem utilizadores.');
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: docs.length,
          itemBuilder: (_, i) {
            final u = docs[i].data() as Map<String, dynamic>;
            final id = docs[i].id;
            final name = (u['name'] ?? 'Utilizador').toString();
            final photo = (u['photoUrl'] ?? '').toString();
            final suspended = u['suspended'] == true;
            final isAdmin = u['isAdmin'] == true;
            final letter = name.isNotEmpty ? name[0].toUpperCase() : 'U';
            return ListTile(
              leading: avatarProvider(photo) != null
                  ? CircleAvatar(radius: 22, backgroundImage: avatarProvider(photo))
                  : CircleAvatar(radius: 22, backgroundColor: const Color(0xFF1A1A1A),
                      child: Text(letter, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
              title: Row(children: [
                Flexible(child: Text(name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: appText(context)))),
                if (isAdmin) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.shield, size: 14, color: Color(0xFF9B59B6))),
                if (suspended) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.block, size: 14, color: Color(0xFFE05D5D))),
              ]),
              subtitle: Text('${u['handle'] ?? ''} · ${u['followersCount'] ?? 0} seguidores',
                style: const TextStyle(color: Color(0xFF999999), fontSize: 12)),
              trailing: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: appText(context)),
                color: appSurface(context),
                onSelected: (v) {
                  if (v == 'profile') {
                    Navigator.push(context, MaterialPageRoute(builder: (_) =>
                      OtherUserProfileScreen(userId: id, name: name, avatar: letter, photoUrl: photo)));
                  } else if (v == 'suspend') {
                    AdminService.setSuspended(id, !suspended);
                  } else if (v == 'admin') {
                    AdminService.setAdmin(id, !isAdmin);
                  } else if (v == 'delete') {
                    showDialog(context: context, builder: (ctx) => AlertDialog(
                      backgroundColor: appSurface(context),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      title: Text('Apagar "$name"?', style: TextStyle(fontWeight: FontWeight.w700, color: appText(context))),
                      content: Text('Apaga o perfil e as publicações desta conta. Permanente.',
                        style: TextStyle(color: appText(context).withValues(alpha: 0.8))),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: Color(0xFF888888)))),
                        TextButton(onPressed: () async { await AdminService.deleteUser(id); if (ctx.mounted) Navigator.pop(ctx); },
                          child: const Text('Apagar', style: TextStyle(color: Color(0xFFE05D5D), fontWeight: FontWeight.w700))),
                      ],
                    ));
                  }
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'profile', child: Text('Ver perfil')),
                  PopupMenuItem(value: 'suspend', child: Text(suspended ? 'Reativar conta' : 'Suspender conta')),
                  PopupMenuItem(value: 'admin', child: Text(isAdmin ? 'Retirar admin' : 'Tornar admin')),
                  const PopupMenuItem(value: 'delete', child: Text('Apagar conta', style: TextStyle(color: Color(0xFFE05D5D)))),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Empty({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 46, color: const Color(0xFFDDDDDD)),
      const SizedBox(height: 10),
      Text(text, style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14)),
    ]),
  );
}

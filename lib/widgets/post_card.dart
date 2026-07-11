import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../screens/other_user_profile_screen.dart';
import '../services/book_service.dart';
import '../services/post_service.dart';
import '../theme.dart';

class PostCard extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> data;
  final bool isOwner;
  final VoidCallback? onDelete;
  final bool expanded; // true = ecrã de detalhe (texto completo, sem abrir de novo)

  const PostCard({
    super.key,
    required this.postId,
    required this.data,
    this.isOwner = false,
    this.onDelete,
    this.expanded = false,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  bool _liked = false;
  int _likes = 0;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _syncLikes();
    _checkSaved();
  }

  // A contagem deriva sempre do array likedBy (nunca fica negativa)
  void _syncLikes() {
    final likedBy = List<String>.from(widget.data['likedBy'] ?? []);
    _likes = likedBy.length;
    _liked = likedBy.contains(_uid);
  }

  // O ListView reutiliza o State entre posts diferentes: ao mudar de post,
  // recalcula as curtidas a partir dos dados novos (evita contagem "fantasma").
  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.postId != widget.postId) {
      _syncLikes();
      _checkSaved();
    }
  }

  Future<void> _checkSaved() async {
    if (_uid.isEmpty) return;
    final doc = await _db.collection('users').doc(_uid).collection('saved').doc(widget.postId).get();
    if (mounted) setState(() => _saved = doc.exists);
  }

  Future<void> _toggleLike() async {
    if (_uid.isEmpty) return;
    HapticFeedback.lightImpact();
    final newLiked = !_liked;
    setState(() {
      _liked = newLiked;
      _likes = (_likes + (newLiked ? 1 : -1)).clamp(0, 1 << 30);
    });
    final ref = _db.collection('posts').doc(widget.postId);
    // Só mexe no array; a contagem é sempre o tamanho do array
    await ref.set({
      'likedBy': newLiked ? FieldValue.arrayUnion([_uid]) : FieldValue.arrayRemove([_uid]),
    }, SetOptions(merge: true));

    // Cria notificação para o autor do post (se não for o próprio)
    final authorId = (widget.data['authorId'] ?? '').toString();
    if (newLiked && authorId.isNotEmpty && authorId != _uid) {
      final me = FirebaseAuth.instance.currentUser;
      await _db.collection('users').doc(authorId).collection('notifications').add({
        'type': 'like',
        'fromId': _uid,
        'fromName': me?.displayName ?? 'Alguém',
        'fromPhoto': me?.photoURL ?? '',
        'text': '${me?.displayName ?? 'Alguém'} gostou do teu post.',
        'postId': widget.postId,
        'postTexto': widget.data['text'] ?? '',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> _toggleSave() async {
    HapticFeedback.lightImpact();
    final ref = _db.collection('users').doc(_uid).collection('saved').doc(widget.postId);
    if (_saved) {
      await ref.delete();
    } else {
      await ref.set({...widget.data, 'postId': widget.postId, 'savedAt': FieldValue.serverTimestamp()});
    }
    setState(() => _saved = !_saved);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_saved ? 'Post guardado! ✅' : 'Post removido dos guardados'),
        backgroundColor: const Color(0xFF333333),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(milliseconds: 1500),
      ));
    }
  }

  void _openAuthorProfile() {
    final authorId = widget.data['authorId'] ?? '';
    if (authorId.isEmpty || authorId == _uid) return;
    final autor = widget.data['authorName'] ?? widget.data['autor'] ?? 'Utilizador';
    final authorPhoto = widget.data['authorPhoto'] ?? '';
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => OtherUserProfileScreen(
        userId: authorId,
        name: autor,
        avatar: autor.isNotEmpty ? autor[0].toUpperCase() : 'U',
        photoUrl: authorPhoto,
      ),
    ));
  }

  void _openBookDetail(BuildContext context, Map<String, dynamic> book) {
    final title = (book['title'] ?? '').toString();
    // Id estável a partir do título (não temos o id do Google aqui)
    final bookId = 'b_${title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}';
    final ref = _db.collection('users').doc(_uid).collection('books').doc(bookId);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: appSurface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2)))),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if ((book['image'] ?? '').toString().isNotEmpty)
                ClipRRect(borderRadius: BorderRadius.circular(6),
                  child: Image.network(book['image'], width: 56, height: 80, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.book, size: 56, color: Colors.grey))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(title, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: appText(context))),
                const SizedBox(height: 2),
                Text(book['author'] ?? '', style: const TextStyle(fontSize: 13, color: Color(0xFF888888))),
              ])),
            ]),
            const SizedBox(height: 14),
            FutureBuilder<String>(
              future: _fetchSynopsis(title),
              builder: (_, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text('A carregar sinopse...', style: TextStyle(fontSize: 13, color: Color(0xFFAAAAAA))));
                }
                final syn = snap.data ?? '';
                if (syn.isEmpty) return const SizedBox.shrink();
                return Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  margin: const EdgeInsets.only(bottom: 8),
                  child: SingleChildScrollView(
                    child: Text(syn, style: TextStyle(fontSize: 13, color: appText(context).withValues(alpha: 0.75), height: 1.5))),
                );
              },
            ),
            const SizedBox(height: 6),
            const Text('Adicionar à minha biblioteca',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF888888))),
            const SizedBox(height: 8),
            ...[('reading', '📖', 'A ler'), ('want', '🔖', 'Quero ler'), ('done', '✅', 'Lido')].map((o) =>
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Text(o.$2, style: const TextStyle(fontSize: 22)),
                title: Text(o.$3, style: TextStyle(fontSize: 15, color: appText(context))),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.set({
                    'title': title, 'author': book['author'] ?? '', 'image': book['image'] ?? '',
                    'status': o.$1, 'bookId': bookId, 'addedAt': FieldValue.serverTimestamp(),
                  }, SetOptions(merge: true));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Adicionado: ${o.$3}'), backgroundColor: const Color(0xFF333333),
                      behavior: SnackBarBehavior.floating));
                  }
                },
              )),
          ],
        ),
      ),
    );
  }

  Future<String> _fetchSynopsis(String title) async {
    if (title.isEmpty) return '';
    try {
      final r = await BookService().searchBooks(title);
      if (r.isEmpty) return '';
      return (r.first['volumeInfo']?['description'] ?? '').toString();
    } catch (_) { return ''; }
  }

  void _editPost(BuildContext context) {
    final titleCtrl = TextEditingController(text: (widget.data['writingTitle'] ?? '').toString());
    final bodyCtrl = TextEditingController(text: (widget.data['text'] ?? '').toString());
    const categories = ['Não é escrita', 'Crónica', 'Poema', 'Conto', 'Reflexão', 'Outro'];
    // Categoria atual (ou "Não é escrita" se for um post normal)
    String cat = widget.data['kind'] == 'writing'
        ? (widget.data['writingCategory'] ?? 'Crónica').toString()
        : 'Não é escrita';
    if (!categories.contains(cat)) cat = 'Crónica';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: appSurface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final isWriting = cat != 'Não é escrita';
          return Padding(
            padding: EdgeInsets.only(left: 20, right: 20, top: 16,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 36, height: 4, margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2)))),
                Text('Editar publicação',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: appText(context))),
                const SizedBox(height: 14),
                // Seletor de tipo/categoria
                const Text('Tipo', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF888888))),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    children: categories.map((c) {
                      final sel = cat == c;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: () => setSheet(() => cat = c),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: sel ? const Color(0xFF1A1A1A) : appSurface(context),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: sel ? const Color(0xFF1A1A1A) : appBorder(context))),
                            child: Text(c, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                              color: sel ? Colors.white : appText(context))),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 14),
                if (isWriting) ...[
                  Container(
                    decoration: BoxDecoration(color: isDark(context) ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(10)),
                    child: TextField(
                      controller: titleCtrl,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: appText(context)),
                      decoration: const InputDecoration(hintText: 'Título', border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                Container(
                  decoration: BoxDecoration(color: isDark(context) ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(10)),
                  child: TextField(
                    controller: bodyCtrl,
                    maxLines: 6, minLines: 3,
                    style: TextStyle(fontSize: 14, color: appText(context), height: 1.5),
                    decoration: const InputDecoration(hintText: 'Texto...', border: InputBorder.none,
                      contentPadding: EdgeInsets.all(14)),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity, height: 48,
                  child: ElevatedButton(
                    onPressed: () async {
                      final body = bodyCtrl.text.trim();
                      if (body.isEmpty) return;
                      Navigator.pop(ctx);
                      final update = <String, dynamic>{'text': body, 'editedAt': FieldValue.serverTimestamp()};
                      if (isWriting) {
                        update['kind'] = 'writing';
                        update['writingCategory'] = cat;
                        update['writingTitle'] = titleCtrl.text.trim();
                      } else {
                        // Deixou de ser escrita → volta a post normal
                        update['kind'] = FieldValue.delete();
                        update['writingCategory'] = FieldValue.delete();
                        update['writingTitle'] = FieldValue.delete();
                      }
                      await _db.collection('posts').doc(widget.postId).set(update, SetOptions(merge: true));
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A1A1A), foregroundColor: Colors.white,
                      elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                    child: const Text('Guardar alterações', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openDetail() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => PostDetailScreen(postId: widget.postId, data: widget.data, isOwner: widget.isOwner),
    ));
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: appSurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _CommentsSheet(
        postId: widget.postId,
        authorId: (widget.data['authorId'] ?? '').toString(),
        postText: (widget.data['text'] ?? '').toString(),
      ),
    );
  }

  String _timeAgo(Timestamp? ts) {
    if (ts == null) return '';
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) return 'agora';
    if (diff.inMinutes < 60) return 'há ${diff.inMinutes}m';
    if (diff.inHours < 24) return 'há ${diff.inHours}h';
    return 'há ${diff.inDays}d';
  }

  @override
  Widget build(BuildContext context) {
    final autor = widget.data['authorName'] ?? widget.data['autor'] ?? 'Utilizador';
    final texto = widget.data['text'] ?? widget.data['texto'] ?? '';
    final authorPhoto = widget.data['authorPhoto'] ?? '';
    final imageUrl = widget.data['imageUrl'] ?? '';
    final book = widget.data['book'] as Map<String, dynamic>?;
    final ts = widget.data['createdAt'] as Timestamp?;
    final isWriting = widget.data['kind'] == 'writing';
    final writingTitle = (widget.data['writingTitle'] ?? '').toString();
    final writingCategory = (widget.data['writingCategory'] ?? '').toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: appSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: appBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(
              children: [
                // Avatar + nome lidos em TEMPO REAL do perfil do autor
                StreamBuilder<DocumentSnapshot>(
                  stream: (widget.data['authorId'] ?? '').toString().isEmpty ? null
                      : _db.collection('users').doc(widget.data['authorId']).snapshots(),
                  builder: (_, asnap) {
                    final ad = asnap.data?.data() as Map<String, dynamic>?;
                    final curName = (ad?['name'] ?? autor).toString();
                    final curPhoto = (ad?['photoUrl'] ?? authorPhoto).toString();
                    final curLetter = curName.isNotEmpty ? curName[0].toUpperCase() : 'U';
                    return Expanded(
                      child: Row(children: [
                        GestureDetector(
                          onTap: _openAuthorProfile,
                          child: avatarProvider(curPhoto) != null
                              ? CircleAvatar(radius: 18, backgroundImage: avatarProvider(curPhoto))
                              : CircleAvatar(radius: 18, backgroundColor: const Color(0xFF1A1A1A),
                                  child: Text(curLetter, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14))),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: _openAuthorProfile,
                            behavior: HitTestBehavior.opaque,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(curName, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: appText(context))),
                                Text('${_timeAgo(ts)}${widget.data['editedAt'] != null ? ' · editado' : ''}',
                                  style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA))),
                              ],
                            ),
                          ),
                        ),
                      ]),
                    );
                  },
                ),
                GestureDetector(
                  onTap: () => _showOptions(context),
                  child: const Icon(Icons.more_horiz, color: Color(0xFFAAAAAA), size: 20),
                ),
              ],
            ),
          ),

          // Cabeçalho de escrita (categoria + título)
          if (isWriting)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF9B59B6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20)),
                    child: Text('✍️ ${writingCategory.isEmpty ? 'Escrita' : writingCategory}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF9B59B6))),
                  ),
                  if (writingTitle.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(writingTitle,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: appText(context), height: 1.3)),
                  ],
                ],
              ),
            ),

          // Texto / corpo (toca para abrir o post completo)
          if (texto.isNotEmpty)
            GestureDetector(
              onTap: widget.expanded ? null : _openDetail,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                child: Text(texto,
                  maxLines: (isWriting && !widget.expanded) ? 6 : null,
                  overflow: (isWriting && !widget.expanded) ? TextOverflow.ellipsis : TextOverflow.clip,
                  style: TextStyle(fontSize: isWriting ? 14.5 : 14, color: appText(context),
                    height: isWriting ? 1.7 : 1.55,
                    fontStyle: isWriting ? FontStyle.italic : FontStyle.normal)),
              ),
            ),

          // Imagem do post (data URI base64 ou URL)
          if (imageUrl.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: appImage(imageUrl, width: double.infinity),
              ),
            ),

          // Livro associado (clicável → detalhe com sinopse + estado)
          if (book != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: GestureDetector(
                onTap: () => _openBookDetail(context, book),
                child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark(context) ? const Color(0xFF2A2A2A) : const Color(0xFFF8F8F8),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: appBorder(context)),
                ),
                child: Row(
                  children: [
                    if ((book['image'] ?? '').isNotEmpty)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Image.network(book['image'], width: 32, height: 44, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(Icons.book, size: 32, color: Colors.grey)),
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(book['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: appText(context))),
                          Text(book['author'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, color: Color(0xFF999999))),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, size: 16, color: Color(0xFFAAAAAA)),
                  ],
                ),
              ),
              ),
            ),

          // Acções
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
            child: Row(
              children: [
                // Gosto
                GestureDetector(
                  onTap: _toggleLike,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Row(
                      children: [
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            key: ValueKey(_liked),
                            color: _liked ? const Color(0xFFE05D5D) : const Color(0xFFAAAAAA),
                            size: 21,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text('$_likes',
                          style: const TextStyle(fontSize: 13, color: Color(0xFF888888), fontWeight: FontWeight.w500)),
                      ],
                    ),
                  ),
                ),
                // Comentários
                GestureDetector(
                  onTap: widget.expanded ? _openComments : _openDetail,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: StreamBuilder<QuerySnapshot>(
                      stream: _db.collection('posts').doc(widget.postId).collection('comments').snapshots(),
                      builder: (_, snap) {
                        final count = snap.data?.docs.length ?? 0;
                        return Row(
                          children: [
                            const Icon(Icons.chat_bubble_outline_rounded, color: Color(0xFFAAAAAA), size: 20),
                            const SizedBox(width: 4),
                            Text('$count',
                              style: const TextStyle(fontSize: 13, color: Color(0xFF888888), fontWeight: FontWeight.w500)),
                          ],
                        );
                      },
                    ),
                  ),
                ),
                const Spacer(),
                // Partilhar
                GestureDetector(
                  onTap: () => Share.share(texto),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Icon(Icons.share_outlined, color: Color(0xFFAAAAAA), size: 20),
                  ),
                ),
                // Guardar
                GestureDetector(
                  onTap: _toggleSave,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        _saved ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                        key: ValueKey(_saved),
                        color: _saved ? const Color(0xFF1A1A1A) : const Color(0xFFAAAAAA),
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: appSurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2))),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Partilhar'),
              onTap: () { Navigator.pop(context); Share.share(widget.data['text'] ?? ''); },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark_border_rounded),
              title: const Text('Guardar'),
              onTap: () { Navigator.pop(context); _toggleSave(); },
            ),
            if (widget.isOwner) ...[
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Editar post'),
                onTap: () { Navigator.pop(context); _editPost(context); },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Color(0xFFE05D5D)),
                title: const Text('Apagar post', style: TextStyle(color: Color(0xFFE05D5D))),
                onTap: () async {
                  Navigator.pop(context);
                  await PostService.deletePost(widget.postId,
                      authorId: (widget.data['authorId'] ?? '').toString());
                  widget.onDelete?.call();
                },
              ),
            ]
            else
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Color(0xFFE05D5D)),
                title: const Text('Reportar', style: TextStyle(color: Color(0xFFE05D5D))),
                onTap: () => Navigator.pop(context),
              ),
          ],
        ),
      ),
    );
  }
}

// ── Sheet de comentários com Firestore ────────────────────────────────────────
class _CommentsSheet extends StatefulWidget {
  final String postId;
  final String authorId;
  final String postText;
  const _CommentsSheet({required this.postId, this.authorId = '', this.postText = ''});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _ctrl = TextEditingController();
  final _db = FirebaseFirestore.instance;
  final _user = FirebaseAuth.instance.currentUser;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _user == null) return;
    HapticFeedback.lightImpact();
    _ctrl.clear();
    await _db.collection('posts').doc(widget.postId).collection('comments').add({
      'text': text,
      'authorId': _user.uid,
      'authorName': _user.displayName ?? _user.email ?? 'Utilizador',
      'authorPhoto': _user.photoURL ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Notifica o autor do post (se não for o próprio)
    if (widget.authorId.isNotEmpty && widget.authorId != _user.uid) {
      await _db.collection('users').doc(widget.authorId).collection('notifications').add({
        'type': 'comment',
        'fromId': _user.uid,
        'fromName': _user.displayName ?? 'Alguém',
        'fromPhoto': _user.photoURL ?? '',
        'text': '${_user.displayName ?? 'Alguém'} comentou no teu post.',
        'postId': widget.postId,
        'postTexto': widget.postText,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.65,
        maxChildSize: 0.93,
        minChildSize: 0.4,
        expand: false,
        builder: (_, scrollCtrl) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Column(
                children: [
                  Container(width: 36, height: 4,
                    decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Comentários',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: appText(context))),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: const Icon(Icons.close, color: Color(0xFF888888), size: 22),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Divider(height: 1, color: appField(context)),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _db.collection('posts').doc(widget.postId).collection('comments')
                    .orderBy('createdAt', descending: false).snapshots(),
                builder: (_, snap) {
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 40, color: Color(0xFFDDDDDD)),
                          SizedBox(height: 10),
                          Text('Sê a primeira a comentar!',
                            style: TextStyle(fontSize: 14, color: Color(0xFF999999))),
                        ],
                      ),
                    );
                  }
                  return ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: docs.length,
                    itemBuilder: (_, i) {
                      final c = docs[i].data() as Map<String, dynamic>;
                      final photo = c['authorPhoto'] ?? '';
                      final name = c['authorName'] ?? 'Utilizador';
                      final ts = c['createdAt'] as Timestamp?;
                      final diff = ts != null ? DateTime.now().difference(ts.toDate()) : null;
                      final time = diff == null ? '' : diff.inMinutes < 60 ? 'há ${diff.inMinutes}m' : 'há ${diff.inHours}h';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            photo.isNotEmpty
                                ? CircleAvatar(radius: 17, backgroundImage: (avatarProvider(photo) ?? NetworkImage(photo)))
                                : CircleAvatar(
                                    radius: 17,
                                    backgroundColor: const Color(0xFF1A1A1A),
                                    child: Text(name[0].toUpperCase(),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(name,
                                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: appText(context))),
                                      const SizedBox(width: 6),
                                      Text(time,
                                        style: const TextStyle(fontSize: 11, color: Color(0xFFAAAAAA))),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(c['text'] ?? '',
                                    style: TextStyle(fontSize: 14, color: appText(context), height: 1.45)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: appSurface(context),
                border: Border(top: BorderSide(color: appField(context))),
              ),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Row(
                children: [
                  (_user?.photoURL ?? '').isNotEmpty
                      ? CircleAvatar(radius: 17, backgroundImage: (avatarProvider(_user!.photoURL) ?? NetworkImage(_user!.photoURL!)))
                      : CircleAvatar(
                          radius: 17,
                          backgroundColor: const Color(0xFF1A1A1A),
                          child: Text((_user?.displayName ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: appField(context),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: TextField(
                        controller: _ctrl,
                        maxLines: null,
                        style: const TextStyle(fontSize: 14),
                        decoration: const InputDecoration(
                          hintText: 'Adicionar comentário...',
                          hintStyle: TextStyle(color: Color(0xFFBBBBBB), fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        ),
                        onSubmitted: (_) => _submit(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _submit,
                    child: Container(
                      width: 38, height: 38,
                      decoration: const BoxDecoration(color: Color(0xFF1A1A1A), shape: BoxShape.circle),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                    ),
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

// ── Ecrã de post aberto (estilo Twitter) ──────────────────────────────────────
class PostDetailScreen extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> data;
  final bool isOwner;
  const PostDetailScreen({super.key, required this.postId, required this.data, this.isOwner = false});

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _ctrl = TextEditingController();
  final _db = FirebaseFirestore.instance;
  final _user = FirebaseAuth.instance.currentUser;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _user == null) return;
    HapticFeedback.lightImpact();
    _ctrl.clear();
    await _db.collection('posts').doc(widget.postId).collection('comments').add({
      'text': text,
      'authorId': _user.uid,
      'authorName': _user.displayName ?? _user.email ?? 'Utilizador',
      'authorPhoto': _user.photoURL ?? '',
      'createdAt': FieldValue.serverTimestamp(),
    });
    // Notifica o autor do post
    final authorId = (widget.data['authorId'] ?? '').toString();
    if (authorId.isNotEmpty && authorId != _user.uid) {
      await _db.collection('users').doc(authorId).collection('notifications').add({
        'type': 'comment',
        'fromId': _user.uid,
        'fromName': _user.displayName ?? 'Alguém',
        'fromPhoto': _user.photoURL ?? '',
        'text': '${_user.displayName ?? 'Alguém'} comentou no teu post.',
        'postId': widget.postId,
        'postTexto': widget.data['text'] ?? '',
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
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
        title: Text('Publicação', style: TextStyle(color: appText(context), fontWeight: FontWeight.w700, fontSize: 16)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
              children: [
                // Post completo (sem cortar)
                PostCard(postId: widget.postId, data: widget.data, isOwner: widget.isOwner, expanded: true),
                const Padding(
                  padding: EdgeInsets.fromLTRB(6, 8, 6, 8),
                  child: Text('Comentários',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF888888), letterSpacing: 0.3)),
                ),
                StreamBuilder<QuerySnapshot>(
                  stream: _db.collection('posts').doc(widget.postId).collection('comments')
                      .orderBy('createdAt', descending: false).snapshots(),
                  builder: (_, snap) {
                    final docs = snap.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const Padding(padding: EdgeInsets.all(24),
                        child: Center(child: Text('Sê o primeiro a comentar!',
                          style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 14))));
                    }
                    return Column(
                      children: docs.map((d) {
                        final c = d.data() as Map<String, dynamic>;
                        final photo = (c['authorPhoto'] ?? '').toString();
                        final name = (c['authorName'] ?? 'Utilizador').toString();
                        final canDelete = c['authorId'] == _user?.uid
                            || (widget.data['authorId'] ?? '') == _user?.uid; // autor do comentário ou do post
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(6, 0, 6, 14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              avatarProvider(photo) != null
                                  ? CircleAvatar(radius: 17, backgroundImage: avatarProvider(photo))
                                  : CircleAvatar(radius: 17, backgroundColor: const Color(0xFF1A1A1A),
                                      child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
                                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13))),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: appText(context))),
                                    const SizedBox(height: 2),
                                    Text(c['text'] ?? '', style: TextStyle(fontSize: 14, color: appText(context).withValues(alpha: 0.85), height: 1.45)),
                                  ],
                                ),
                              ),
                              if (canDelete)
                                GestureDetector(
                                  onTap: () => _db.collection('posts').doc(widget.postId)
                                      .collection('comments').doc(d.id).delete(),
                                  child: const Padding(
                                    padding: EdgeInsets.only(left: 6, top: 2),
                                    child: Icon(Icons.close_rounded, size: 16, color: Color(0xFFBBBBBB)),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
          // Caixa de comentar
          Container(
            decoration: BoxDecoration(
              color: appSurface(context),
              border: Border(top: BorderSide(color: appBorder(context))),
            ),
            padding: EdgeInsets.fromLTRB(12, 8, 12, MediaQuery.of(context).viewInsets.bottom + 10),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark(context) ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(22)),
                    child: TextField(
                      controller: _ctrl,
                      maxLines: null,
                      style: TextStyle(fontSize: 14, color: appText(context)),
                      decoration: const InputDecoration(
                        hintText: 'Adicionar comentário...',
                        hintStyle: TextStyle(color: Color(0xFFBBBBBB), fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _submit,
                  child: Container(
                    width: 38, height: 38,
                    decoration: const BoxDecoration(color: Color(0xFF1A1A1A), shape: BoxShape.circle),
                    child: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
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

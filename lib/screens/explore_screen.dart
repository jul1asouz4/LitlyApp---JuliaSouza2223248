import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/book_service.dart';
import '../services/post_service.dart';
import '../widgets/post_card.dart';
import 'other_user_profile_screen.dart';
import '../theme.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final _searchController = TextEditingController();
  final _bookService = BookService();
  List<dynamic> _books = [];
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = false;
  bool _hasSearched = false;
  bool _searchPeople = false;
  bool _showWritings = false;
  final Map<String, int> _ratings = {};

  // Categorias em destaque (Goodreads-style)
  final _categories = ['Romance', 'Ficção Científica', 'Mistério', 'Terror', 'Fantasia', 'Biografia', 'Clássicos'];

  @override
  void initState() {
    super.initState();
    _loadTrending();
  }

  Future<void> _loadTrending() async {
    setState(() => _isLoading = true);
    try {
      final results = await _bookService.searchBooks('bestseller ficção 2024');
      if (mounted) setState(() => _books = results);
    } catch (_) {} finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _search([String? query]) async {
    final q = query ?? _searchController.text.trim();
    if (q.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() { _isLoading = true; _hasSearched = true; });
    if (_searchPeople) {
      await _searchUsers(q);
      return;
    }
    try {
      final results = await _bookService.searchBooks(q);
      setState(() => _books = results);
    } catch (_) {
      setState(() => _books = []);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _searchUsers(String query) async {
    final q = query.toLowerCase();
    try {
      // Procura por nameLower (contas novas) e por name (contas antigas), e junta
      final byLower = await FirebaseFirestore.instance
          .collection('users')
          .where('nameLower', isGreaterThanOrEqualTo: q)
          .where('nameLower', isLessThan: '${q}z')
          .limit(20).get();
      final cap = query[0].toUpperCase() + query.substring(1);
      final byName = await FirebaseFirestore.instance
          .collection('users')
          .where('name', isGreaterThanOrEqualTo: cap)
          .where('name', isLessThan: '${cap}z')
          .limit(20).get();

      final myId = FirebaseAuth.instance.currentUser?.uid;
      final Map<String, Map<String, dynamic>> merged = {};
      for (final d in [...byLower.docs, ...byName.docs]) {
        if (d.id == myId) continue;
        merged[d.id] = {'id': d.id, ...d.data()};
      }
      if (mounted) setState(() => _users = merged.values.toList());
    } catch (_) {
      if (mounted) setState(() => _users = []);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _coverUrl(dynamic book) {
    final links = book['volumeInfo']['imageLinks'];
    if (links == null) return '';
    return (links['thumbnail'] ?? links['smallThumbnail'] ?? '').toString().replaceFirst('http://', 'https://');
  }

  void _openBook(dynamic book) {
    final info = book['volumeInfo'];
    final id = book['id'] as String;
    final rawUrl = info['imageLinks']?['thumbnail'] ?? info['imageLinks']?['smallThumbnail'];
    final imageUrl = rawUrl?.toString().replaceFirst('http://', 'https://');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: appSurface(context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => DraggableScrollableSheet(
          initialChildSize: 0.78,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          expand: false,
          builder: (_, scrollCtrl) => SingleChildScrollView(
            controller: scrollCtrl,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Handle
                  Container(
                    width: 36, height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2)),
                  ),

                  // Capa
                  if (imageUrl != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(imageUrl, height: 200, fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => Container(
                          height: 200, width: 130,
                          decoration: BoxDecoration(color: appField(context), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.book, size: 60, color: Colors.grey),
                        )),
                    )
                  else
                    Container(
                      height: 200, width: 130,
                      decoration: BoxDecoration(color: appField(context), borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.book, size: 60, color: Colors.grey),
                    ),

                  const SizedBox(height: 18),

                  Text(info['title'] ?? 'Sem título',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: appText(context), height: 1.3)),
                  const SizedBox(height: 5),
                  Text(info['authors']?.join(', ') ?? 'Autor desconhecido',
                    style: const TextStyle(fontSize: 14, color: Color(0xFF888888))),

                  const SizedBox(height: 18),

                  // Estrelas
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) => GestureDetector(
                      onTap: () {
                        final newRating = i + 1;
                        setModal(() {});
                        setState(() => _ratings[id] = newRating);
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 3),
                        child: Icon(
                          (_ratings[id] ?? 0) > i ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: const Color(0xFFF5A623),
                          size: 34,
                        ),
                      ),
                    )),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _ratings[id] != null
                        ? ['', 'Não gostei', 'Razoável', 'Gostei', 'Muito bom', 'Incrível!'][_ratings[id]!]
                        : 'Toca para avaliar',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF999999)),
                  ),

                  const SizedBox(height: 20),

                  // Botões estado leitura
                  _ReadStatusPicker(
                    bookId: id,
                    bookData: {
                      'title': info['title'] ?? '',
                      'author': info['authors']?.join(', ') ?? '',
                      'image': imageUrl ?? '',
                    },
                  ),

                  const SizedBox(height: 22),

                  // Sinopse
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Sinopse', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: appText(context))),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    info['description'] ?? 'Sem descrição disponível para este livro.',
                    style: TextStyle(fontSize: 14, color: appText(context), height: 1.65),
                  ),

                  // Meta info
                  if (info['publishedDate'] != null) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        _MetaChip(label: info['publishedDate'].toString().substring(0, 4), icon: Icons.calendar_today_outlined),
                        const SizedBox(width: 8),
                        if (info['pageCount'] != null)
                          _MetaChip(label: '${info["pageCount"]} pág.', icon: Icons.menu_book_outlined),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBg(context),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // AppBar
            SliverAppBar(
              backgroundColor: appBg(context),
              surfaceTintColor: Colors.transparent,
              floating: true,
              snap: true,
              elevation: 0,
              toolbarHeight: 56,
              titleSpacing: 16,
              title: Text('Pesquisar',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5, color: appText(context))),
            ),

            // Barra de pesquisa
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 46,
                        decoration: BoxDecoration(
                          color: appSurface(context),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: appBorder(context)),
                        ),
                        child: TextField(
                          controller: _searchController,
                          onSubmitted: (_) => _search(),
                          onChanged: (v) {
                            if (v.trim().isEmpty) {
                              setState(() { _hasSearched = false; _users = []; });
                              if (!_searchPeople) _loadTrending();
                            }
                          },
                          style: TextStyle(fontSize: 15, color: appText(context)),
                          decoration: InputDecoration(
                            hintText: _searchPeople ? 'Nome de utilizador...' : 'Título, autor, ISBN...',
                            suffixIcon: _searchController.text.isNotEmpty
                                ? GestureDetector(
                                    onTap: () {
                                      _searchController.clear();
                                      setState(() { _hasSearched = false; _users = []; });
                                      if (!_searchPeople) _loadTrending();
                                    },
                                    child: const Icon(Icons.close_rounded, color: Color(0xFFAAAAAA), size: 18))
                                : null,
                            hintStyle: TextStyle(color: Color(0xFFBBBBBB), fontSize: 15),
                            prefixIcon: Icon(Icons.search_rounded, color: Color(0xFFAAAAAA), size: 20),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 13),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    GestureDetector(
                      onTap: () => _search(),
                      child: Container(
                        height: 46,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Center(
                          child: Text('Ir', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Toggle Livros / Pessoas
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Row(
                  children: [
                    _ToggleChip(
                      label: '📚 Livros',
                      selected: !_searchPeople && !_showWritings,
                      onTap: () {
                        setState(() { _searchPeople = false; _showWritings = false; });
                        if (_hasSearched) _search();
                        else if (_books.isEmpty && !_isLoading) _loadTrending();
                      },
                    ),
                    const SizedBox(width: 8),
                    _ToggleChip(
                      label: '👤 Pessoas',
                      selected: _searchPeople,
                      onTap: () {
                        setState(() { _searchPeople = true; _showWritings = false; });
                        if (_searchController.text.trim().isNotEmpty) _search();
                      },
                    ),
                    const SizedBox(width: 8),
                    _ToggleChip(
                      label: '✍️ Escritas',
                      selected: _showWritings,
                      onTap: () => setState(() { _showWritings = true; _searchPeople = false; }),
                    ),
                  ],
                ),
              ),
            ),

            // Escritas da comunidade
            if (_showWritings) ...[
              SliverToBoxAdapter(
                child: StreamBuilder<QuerySnapshot>(
                  stream: PostService().writingsStream(),
                  builder: (_, wsnap) {
                    if (wsnap.connectionState == ConnectionState.waiting) {
                      return const Padding(padding: EdgeInsets.all(40),
                        child: Center(child: CircularProgressIndicator(color: Color(0xFF1A1A1A), strokeWidth: 2)));
                    }
                    final docs = (wsnap.data?.docs ?? []).toList()
                      ..sort((a, b) {
                        final at = (a.data() as Map)['createdAt'] as Timestamp?;
                        final bt = (b.data() as Map)['createdAt'] as Timestamp?;
                        if (at == null && bt == null) return 0;
                        if (at == null) return 1;
                        if (bt == null) return -1;
                        return bt.compareTo(at);
                      });
                    if (docs.isEmpty) {
                      return const Padding(padding: EdgeInsets.all(40),
                        child: Center(child: Text('Ainda não há escritas.\nSê o primeiro a publicar uma! ✍️',
                          textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 14))));
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: docs.length,
                      itemBuilder: (_, i) => PostCard(
                        key: ValueKey(docs[i].id),
                        postId: docs[i].id,
                        data: docs[i].data() as Map<String, dynamic>,
                      ),
                    );
                  },
                ),
              ),
            ]
            // Resultados de pessoas
            else if (_searchPeople) ...[
              if (_isLoading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: Color(0xFF1A1A1A), strokeWidth: 2)),
                )
              else if (!_hasSearched)
                const SliverFillRemaining(
                  child: Center(child: Text('Pesquisa por nome de utilizador 👤',
                    style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 14))),
                )
              else if (_users.isEmpty)
                const SliverFillRemaining(
                  child: Center(child: Text('Nenhum utilizador encontrado.',
                    style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 14))),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      final u = _users[i];
                      final name = u['name'] ?? 'Utilizador';
                      final handle = u['handle'] ?? u['username'] ?? '';
                      final photo = u['photoUrl'] ?? '';
                      final letter = name.isNotEmpty ? name[0].toUpperCase() : 'U';
                      return ListTile(
                        leading: avatarProvider(photo) != null
                            ? CircleAvatar(radius: 22, backgroundImage: avatarProvider(photo))
                            : CircleAvatar(radius: 22, backgroundColor: const Color(0xFF1A1A1A),
                                child: Text(letter, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        title: Text(name, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: appText(context))),
                        subtitle: handle.isNotEmpty
                            ? Text(handle, style: const TextStyle(color: Color(0xFF999999), fontSize: 12))
                            : null,
                        onTap: () => Navigator.push(context, MaterialPageRoute(
                          builder: (_) => OtherUserProfileScreen(
                            userId: u['id'], name: name, avatar: letter, photoUrl: photo),
                        )),
                      );
                    },
                    childCount: _users.length,
                  ),
                ),
            ]
            // Conteúdo de livros
            else if (!_hasSearched) ...[
              // Categorias
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Explorar por categoria',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF888888), letterSpacing: 0.3)),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _categories.map((c) => GestureDetector(
                          onTap: () {
                            _searchController.text = c;
                            _search(c);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: appSurface(context),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: appBorder(context)),
                            ),
                            child: Text(c, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: appText(context))),
                          ),
                        )).toList(),
                      ),
                      const SizedBox(height: 20),
                      const Text('Tendências 📚',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF888888), letterSpacing: 0.3)),
                    ],
                  ),
                ),
              ),
              if (_isLoading)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: Center(child: CircularProgressIndicator(color: Color(0xFF1A1A1A), strokeWidth: 2)),
                  ),
                )
              else if (_books.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(30),
                    child: Center(
                      child: Column(children: [
                        const Text('Não foi possível carregar as tendências.',
                          textAlign: TextAlign.center, style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 14)),
                        const SizedBox(height: 12),
                        GestureDetector(
                          onTap: _loadTrending,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(20)),
                            child: const Text('Recarregar', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ]),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  sliver: SliverGrid(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3, crossAxisSpacing: 10, mainAxisSpacing: 16, childAspectRatio: 0.55),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final book = _books[i];
                        final info = book['volumeInfo'];
                        final cover = _coverUrl(book);
                        return GestureDetector(
                          onTap: () => _openBook(book),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: cover.isNotEmpty
                                      ? Image.network(cover, fit: BoxFit.cover, width: double.infinity,
                                          errorBuilder: (_, __, ___) => _bookBg())
                                      : _bookBg(),
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(info['title'] ?? '', maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: appText(context), height: 1.35)),
                              Text(info['authors']?[0] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 10, color: Color(0xFF999999))),
                            ],
                          ),
                        );
                      },
                      childCount: _books.length,
                    ),
                  ),
                ),
            ] else if (_isLoading) ...[
              const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator(color: Color(0xFF1A1A1A), strokeWidth: 2)),
              ),
            ] else if (_books.isEmpty) ...[
              const SliverFillRemaining(
                child: Center(
                  child: Text('Nenhum resultado encontrado.',
                    style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 14)),
                ),
              ),
            ] else ...[
              // Contador
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Text('${_books.length} resultados',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF999999), fontWeight: FontWeight.w500)),
                ),
              ),
              // Grid de livros
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.55,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (_, i) {
                      final book = _books[i];
                      final id = book['id'] as String;
                      final info = book['volumeInfo'];
                      final cover = _coverUrl(book);
                      final rating = _ratings[id];

                      return GestureDetector(
                        onTap: () => _openBook(book),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: cover.isNotEmpty
                                        ? Image.network(cover, fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => _bookBg())
                                        : _bookBg(),
                                  ),
                                  if (rating != null)
                                    Positioned(
                                      top: 6, right: 6,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF5A623),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.star_rounded, size: 10, color: Colors.white),
                                            const SizedBox(width: 2),
                                            Text('$rating', style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.w700)),
                                          ],
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(info['title'] ?? '',
                              maxLines: 2, overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: appText(context), height: 1.35)),
                            Text(info['authors']?[0] ?? '',
                              maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10, color: Color(0xFF999999))),
                          ],
                        ),
                      );
                    },
                    childCount: _books.length,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _bookBg() => Container(
    decoration: BoxDecoration(
      color: appField(context),
      borderRadius: BorderRadius.circular(10),
    ),
    child: const Center(child: Icon(Icons.book, color: Colors.grey, size: 28)),
  );
}

// ── Chip de alternância Livros/Pessoas ────────────────────────────────────────
class _ToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ToggleChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? appText(context) : appSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? appText(context) : appBorder(context)),
      ),
      child: Text(label, style: TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600,
        color: selected ? appSurface(context) : appText(context))),
    ),
  );
}

// ── Picker de estado de leitura com Firestore ─────────────────────────────────
class _ReadStatusPicker extends StatefulWidget {
  final String bookId;
  final Map<String, dynamic> bookData;
  const _ReadStatusPicker({required this.bookId, required this.bookData});

  @override
  State<_ReadStatusPicker> createState() => _ReadStatusPickerState();
}

class _ReadStatusPickerState extends State<_ReadStatusPicker> {
  String? _status;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  Future<void> _loadStatus() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance
        .collection('users').doc(uid).collection('books').doc(widget.bookId).get();
    if (doc.exists && mounted) {
      setState(() => _status = doc.data()?['status']);
    }
  }

  Future<void> _setStatus(String newStatus) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _saving) return;
    final sel = _status == newStatus;
    setState(() { _status = sel ? null : newStatus; _saving = true; });
    final ref = FirebaseFirestore.instance
        .collection('users').doc(uid).collection('books').doc(widget.bookId);
    if (sel) {
      await ref.delete();
    } else {
      await ref.set({
        ...widget.bookData,
        'status': newStatus,
        'bookId': widget.bookId,
        'addedAt': FieldValue.serverTimestamp(),
      });
    }
    if (mounted) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(sel ? 'Livro removido da biblioteca' : '✅ Guardado na tua biblioteca!'),
        backgroundColor: const Color(0xFF333333),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(milliseconds: 1800),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = [
      ('reading', Icons.menu_book_rounded, 'A ler'),
      ('want', Icons.bookmark_border_rounded, 'Quero ler'),
      ('done', Icons.check_circle_outline_rounded, 'Lido'),
    ];

    return Row(
      children: options.map((o) {
        final sel = _status == o.$1;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: GestureDetector(
              onTap: () => _setStatus(o.$1),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? const Color(0xFF1A1A1A) : appField(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  children: [
                    Icon(o.$2, size: 18, color: sel ? Colors.white : const Color(0xFF666666)),
                    const SizedBox(height: 3),
                    Text(o.$3,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
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

// ── Meta chip ─────────────────────────────────────────────────────────────────
class _MetaChip extends StatelessWidget {
  final String label;
  final IconData icon;
  const _MetaChip({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: appField(context),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFF888888)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF666666))),
        ],
      ),
    );
  }
}


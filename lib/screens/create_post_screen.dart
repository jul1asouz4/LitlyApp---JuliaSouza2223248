import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/book_service.dart';
import '../services/post_service.dart';
import '../theme.dart';

class CreatePostScreen extends StatefulWidget {
  const CreatePostScreen({super.key});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final _searchController = TextEditingController();
  final _postController = TextEditingController();
  final _bookService = BookService();
  final _postService = PostService();
  final _logger = Logger();

  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  String _writingCategory = 'Crónica';
  final _categories = ['Crónica', 'Poema', 'Conto', 'Reflexão', 'Outro'];
  bool _writingMode = false;

  List _books = [];
  bool _isPublishing = false;
  bool _isSearching = false;
  bool _hasSearched = false;
  dynamic _selectedBook;
  Uint8List? _selectedImage;
  String _userInitial = 'U';
  String _userPhoto = '';

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final name = doc.data()?['name'] ?? user.displayName ?? 'Utilizador';
    if (mounted) {
      setState(() {
        _userInitial = name.isNotEmpty ? name[0].toUpperCase() : 'U';
        _userPhoto = doc.data()?['photoUrl'] ?? user.photoURL ?? '';
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _postController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  Future<void> _publishWriting() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();
    if (title.isEmpty || body.isEmpty) {
      _showSnack('Dá um título e escreve o texto antes de publicar.');
      return;
    }
    setState(() => _isPublishing = true);
    try {
      await _postService.publishWriting(title: title, category: _writingCategory, body: body);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _showSnack('Erro ao publicar. Tenta novamente.');
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final original = await picked.readAsBytes();
    // Redimensiona no código (a web não comprime via image_picker)
    Uint8List bytes = original;
    try {
      final decoded = img.decodeImage(original);
      if (decoded != null) {
        final resized = img.copyResize(decoded, width: 800);
        bytes = Uint8List.fromList(img.encodeJpg(resized, quality: 65));
      }
    } catch (_) {}
    setState(() => _selectedImage = bytes);
  }

  Future<void> _publishPost() async {
    final text = _postController.text.trim();
    if (text.isEmpty && _selectedBook == null && _selectedImage == null) {
      _showSnack('Escreve algo, adiciona uma foto ou um livro antes de publicar.');
      return;
    }

    setState(() => _isPublishing = true);

    try {
      // Imagem guardada como data URI no Firestore (já vem redimensionada, sem Storage)
      String? imageUrl;
      if (_selectedImage != null) {
        imageUrl = 'data:image/jpeg;base64,${base64Encode(_selectedImage!)}';
      }

      await _postService.publishPost(text: text, book: _selectedBook, imageUrl: imageUrl);
      _logger.i("Post publicado!");

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      _logger.e("Erro ao publicar: $e");
      if (mounted) _showSnack('Erro ao publicar: ${e.toString().length > 60 ? "Verifica a ligação e tenta novamente." : e}');
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  void _showSnack(String msg, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: success ? const Color(0xFF2E7D32) : const Color(0xFF333333),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(milliseconds: 1800),
    ));
  }

  void _searchBooks() async {
    final q = _searchController.text.trim();
    if (q.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() { _isSearching = true; _hasSearched = true; _books = []; });

    try {
      final results = await _bookService.searchBooks(q);
      setState(() => _books = results);
    } catch (e) {
      _logger.e("Falha: $e");
      if (mounted) _showSnack('Erro na pesquisa. Verifica a ligação.');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _showBookDetails(dynamic book) {
    final info = book['volumeInfo'];
    final rawUrl = info['imageLinks']?['thumbnail'] ?? info['imageLinks']?['smallThumbnail'];
    final imageUrl = rawUrl?.toString().replaceFirst('http://', 'https://');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          left: 24, right: 24, top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 36,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(color: const Color(0xFFDDDDDD), borderRadius: BorderRadius.circular(2))),
            if (imageUrl != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(imageUrl, height: 160, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(Icons.book, size: 80, color: Colors.grey)),
              )
            else
              const Icon(Icons.book, size: 80, color: Colors.grey),
            const SizedBox(height: 16),
            Text(info['title'] ?? 'Sem título',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF1A1A1A))),
            const SizedBox(height: 4),
            Text(info['authors']?.join(', ') ?? 'Autor desconhecido',
              style: const TextStyle(fontSize: 13, color: Color(0xFF888888))),
            const SizedBox(height: 12),
            if ((info['description'] ?? '').isNotEmpty)
              Text(info['description'] ?? '',
                maxLines: 4, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: Color(0xFF555555), height: 1.55)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  setState(() => _selectedBook = book);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A1A1A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Adicionar ao post', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _coverUrl(dynamic book) {
    final links = book['volumeInfo']['imageLinks'];
    if (links == null) return '';
    return (links['smallThumbnail'] ?? links['thumbnail'] ?? '').toString().replaceFirst('http://', 'https://');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: appBg(context),
      appBar: AppBar(
        backgroundColor: appSurface(context),
        elevation: 0,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: Row(
          children: [
            // Cancelar
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Text('Cancelar',
                style: TextStyle(color: Color(0xFF888888), fontSize: 15, fontWeight: FontWeight.w500)),
            ),
            const Spacer(),
            Text('Novo post',
              style: TextStyle(color: appText(context), fontSize: 16, fontWeight: FontWeight.w700)),
            const Spacer(),
            // Botão Publicar
            GestureDetector(
              onTap: _isPublishing ? null : (_writingMode ? _publishWriting : _publishPost),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: _isPublishing ? const Color(0xFF888888) : const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Center(
                  child: _isPublishing
                      ? const SizedBox(
                          width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Publicar',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                ),
              ),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: appBorder(context)),
        ),
      ),
      body: Column(
        children: [
          _modeToggle(),
          if (_writingMode)
            Expanded(child: _buildWritingForm())
          else ...[
          // Área de texto
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _userPhoto.isNotEmpty
                    ? CircleAvatar(radius: 21, backgroundImage: NetworkImage(_userPhoto))
                    : CircleAvatar(
                        radius: 21,
                        backgroundColor: const Color(0xFF1A1A1A),
                        child: Text(_userInitial, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _postController,
                    maxLines: null,
                    autofocus: false,
                    style: TextStyle(fontSize: 16, color: appText(context), height: 1.5),
                    decoration: const InputDecoration(
                      hintText: 'O que estás a ler?',
                      hintStyle: TextStyle(color: Color(0xFF999999), fontSize: 16),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Preview da imagem selecionada
          if (_selectedImage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(50, 10, 16, 0),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(_selectedImage!, height: 180, width: double.infinity, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 6, right: 6,
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedImage = null),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                        child: const Icon(Icons.close_rounded, size: 16, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Preview do livro selecionado
          if (_selectedBook != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(50, 10, 16, 0),
              child: _SelectedBookCard(
                book: _selectedBook,
                onRemove: () => setState(() => _selectedBook = null),
              ),
            ),

          const SizedBox(height: 12),
          Container(height: 1, color: appBorder(context)),

          // Barra de acções (foto + livro)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.image_outlined, size: 18, color: Color(0xFF555555)),
                        SizedBox(width: 6),
                        Text('Foto', style: TextStyle(fontSize: 13, color: Color(0xFF555555), fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.menu_book_outlined, size: 20, color: Color(0xFF888888)),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    onSubmitted: (_) => _searchBooks(),
                    style: TextStyle(fontSize: 14, color: appText(context)),
                    decoration: const InputDecoration(
                      hintText: 'Adicionar livro...',
                      hintStyle: TextStyle(color: Color(0xFFAAAAAA), fontSize: 14),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: _searchBooks,
                  child: Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text('Pesquisar',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1A1A1A))),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(height: 1, color: appBorder(context)),

          // Resultados
          Expanded(
            child: _isSearching
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1A1A1A), strokeWidth: 2),
                  )
                : !_hasSearched
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.search_rounded, size: 40, color: Color(0xFFDDDDDD)),
                            const SizedBox(height: 8),
                            const Text('Pesquisa um livro para adicionar ao post',
                              style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 13),
                              textAlign: TextAlign.center),
                          ],
                        ),
                      )
                    : _books.isEmpty
                        ? const Center(
                            child: Text('Nenhum resultado encontrado.',
                              style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 13)),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            itemCount: _books.length,
                            separatorBuilder: (_, __) => const Divider(
                              height: 1, indent: 76, endIndent: 0, color: Color(0xFFF5F5F5)),
                            itemBuilder: (_, i) {
                              final book = _books[i];
                              final info = book['volumeInfo'];
                              final cover = _coverUrl(book);
                              return ListTile(
                                onTap: () => _showBookDetails(book),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(5),
                                  child: cover.isNotEmpty
                                      ? Image.network(cover,
                                          width: 42, height: 60, fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => _placeholder())
                                      : _placeholder(),
                                ),
                                title: Text(info['title'] ?? 'Sem título',
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: appText(context))),
                                subtitle: Text(info['authors']?.join(', ') ?? '',
                                  maxLines: 1, overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF999999))),
                                trailing: const Icon(Icons.add_circle_outline_rounded,
                                  color: Color(0xFFAAAAAA), size: 20),
                              );
                            },
                          ),
          ),
          ],
        ],
      ),
    );
  }

  // Toggle Post / Escrita
  Widget _modeToggle() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
    child: Container(
      height: 38,
      decoration: BoxDecoration(
        color: isDark(context) ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
        borderRadius: BorderRadius.circular(10)),
      child: Row(children: [
        _modeBtn('📝 Post', !_writingMode, () => setState(() => _writingMode = false)),
        _modeBtn('✍️ Escrita', _writingMode, () => setState(() => _writingMode = true)),
      ]),
    ),
  );

  Widget _modeBtn(String label, bool sel, VoidCallback onTap) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: sel ? appSurface(context) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: sel ? [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 4)] : null,
        ),
        child: Center(child: Text(label, style: TextStyle(
          fontSize: 13, fontWeight: FontWeight.w600,
          color: sel ? appText(context) : const Color(0xFF888888)))),
      ),
    ),
  );

  // Formulário de escrita (crónica, poema...)
  Widget _buildWritingForm() => ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
    children: [
      // Categoria
      SizedBox(
        height: 36,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: _categories.map((c) {
            final sel = _writingCategory == c;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => setState(() => _writingCategory = c),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: sel ? const Color(0xFF1A1A1A) : appSurface(context),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: sel ? const Color(0xFF1A1A1A) : appBorder(context)),
                  ),
                  child: Text(c, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                    color: sel ? Colors.white : appText(context))),
                ),
              ),
            );
          }).toList(),
        ),
      ),
      const SizedBox(height: 16),
      // Título
      TextField(
        controller: _titleController,
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: appText(context)),
        decoration: const InputDecoration(
          hintText: 'Título da tua escrita',
          hintStyle: TextStyle(color: Color(0xFFAAAAAA), fontSize: 20, fontWeight: FontWeight.w800),
          border: InputBorder.none,
        ),
      ),
      const Divider(),
      const SizedBox(height: 8),
      // Corpo
      TextField(
        controller: _bodyController,
        maxLines: null,
        minLines: 10,
        style: TextStyle(fontSize: 15, height: 1.6, color: appText(context)),
        decoration: const InputDecoration(
          hintText: 'Escreve aqui a tua crónica, poema, conto...',
          hintStyle: TextStyle(color: Color(0xFFBBBBBB), fontSize: 15),
          border: InputBorder.none,
        ),
      ),
    ],
  );

  Widget _placeholder() => Container(
    width: 42, height: 60,
    decoration: BoxDecoration(
      color: const Color(0xFFEEEEEE),
      borderRadius: BorderRadius.circular(5),
    ),
    child: const Icon(Icons.book, color: Colors.grey, size: 20),
  );
}

// ── Card do livro selecionado ─────────────────────────────────────────────────
class _SelectedBookCard extends StatelessWidget {
  final dynamic book;
  final VoidCallback onRemove;
  const _SelectedBookCard({required this.book, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final info = book['volumeInfo'];
    final rawUrl = info['imageLinks']?['smallThumbnail'] ?? info['imageLinks']?['thumbnail'];
    final imageUrl = rawUrl?.toString().replaceFirst('http://', 'https://');

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark(context) ? const Color(0xFF2A2A2A) : const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: appBorder(context)),
      ),
      child: Row(
        children: [
          if (imageUrl != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(5),
              child: Image.network(imageUrl, width: 36, height: 50, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.book, size: 36, color: Colors.grey)),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(info['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: appText(context))),
                const SizedBox(height: 2),
                Text(info['authors']?[0] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF999999))),
              ],
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: Container(
              padding: const EdgeInsets.all(4),
              child: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF999999)),
            ),
          ),
        ],
      ),
    );
  }
}


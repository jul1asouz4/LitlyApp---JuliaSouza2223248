import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PostService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Apaga um post e limpa as notificações associadas (gostos/comentários),
  /// que ficam na subcoleção de notificações do autor do post.
  static Future<void> deletePost(String postId, {String? authorId}) async {
    final db = FirebaseFirestore.instance;
    // Se não sabemos o autor, lê-o do próprio post antes de apagar.
    var author = authorId ?? '';
    if (author.isEmpty) {
      final doc = await db.collection('posts').doc(postId).get();
      author = (doc.data()?['authorId'] ?? '').toString();
    }
    if (author.isNotEmpty) {
      final notifs = await db.collection('users').doc(author)
          .collection('notifications').where('postId', isEqualTo: postId).get();
      for (final n in notifs.docs) {
        await n.reference.delete();
      }
    }
    await db.collection('posts').doc(postId).delete();
  }

  Future<void> publishPost({required String text, required dynamic book, String? imageUrl}) async {
    final user = FirebaseAuth.instance.currentUser;
    // Lê o nome/foto/privacidade atuais do Firestore (mais fiável que o Auth)
    var authorName = user?.displayName ?? user?.email ?? 'Utilizador';
    var authorPhoto = user?.photoURL ?? '';
    var authorPrivate = false;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final d = doc.data();
      if (d != null) {
        authorName = (d['name'] ?? authorName).toString();
        authorPhoto = (d['photoUrl'] ?? authorPhoto).toString();
        authorPrivate = d['isPrivate'] == true;
      }
    }
    await _firestore.collection('posts').add({
      'text': text,
      'authorId': user?.uid ?? '',
      'authorName': authorName,
      'authorPhoto': authorPhoto,
      'authorPrivate': authorPrivate,
      'imageUrl': imageUrl ?? '',
      'book': book != null ? {
        'title': book['volumeInfo']['title'],
        'author': book['volumeInfo']['authors']?[0] ?? 'Autor desconhecido',
        'image': (book['volumeInfo']['imageLinks']?['smallThumbnail'] ?? '')
            .toString().replaceFirst('http://', 'https://'),
      } : null,
      'createdAt': FieldValue.serverTimestamp(),
      'likes': 0,
    });
  }

  // Publica uma escrita (crónica, poema, conto...) — guardada como post com kind='writing'
  Future<void> publishWriting({required String title, required String category, required String body}) async {
    final user = FirebaseAuth.instance.currentUser;
    var authorName = user?.displayName ?? user?.email ?? 'Utilizador';
    var authorPhoto = user?.photoURL ?? '';
    var authorPrivate = false;
    if (user != null) {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      final d = doc.data();
      if (d != null) {
        authorName = (d['name'] ?? authorName).toString();
        authorPhoto = (d['photoUrl'] ?? authorPhoto).toString();
        authorPrivate = d['isPrivate'] == true;
      }
    }
    await _firestore.collection('posts').add({
      'kind': 'writing',
      'writingTitle': title,
      'writingCategory': category,
      'text': body,
      'authorId': user?.uid ?? '',
      'authorName': authorName,
      'authorPhoto': authorPhoto,
      'authorPrivate': authorPrivate,
      'imageUrl': '',
      'createdAt': FieldValue.serverTimestamp(),
      'likes': 0,
    });
  }

  Stream<QuerySnapshot> feedStream() => _firestore
      .collection('posts')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots();

  // Escritas da comunidade (para o Explorar)
  Stream<QuerySnapshot> writingsStream() => _firestore
      .collection('posts')
      .where('kind', isEqualTo: 'writing')
      .limit(50)
      .snapshots();
}


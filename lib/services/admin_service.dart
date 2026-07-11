import 'package:cloud_firestore/cloud_firestore.dart';
import 'post_service.dart';

class AdminService {
  static final _db = FirebaseFirestore.instance;

  // Streams para o painel
  static Stream<QuerySnapshot> reportsStream() =>
      _db.collection('reports').orderBy('timestamp', descending: true).limit(100).snapshots();

  static Stream<QuerySnapshot> feedbackStream() =>
      _db.collection('feedback').orderBy('createdAt', descending: true).limit(100).snapshots();

  static Stream<QuerySnapshot> usersStream() =>
      _db.collection('users').limit(200).snapshots();

  static Stream<QuerySnapshot> postsCountStream() =>
      _db.collection('posts').snapshots();

  // Publicações recentes (para moderação)
  static Stream<QuerySnapshot> postsStream() =>
      _db.collection('posts').orderBy('createdAt', descending: true).limit(100).snapshots();

  // Ações de moderação
  static Future<void> deletePost(String postId) async {
    // Apaga também as notificações associadas ao post
    await PostService.deletePost(postId);
  }

  static Future<void> dismissReport(String reportId) async {
    await _db.collection('reports').doc(reportId).delete();
  }

  static Future<void> dismissFeedback(String feedbackId) async {
    await _db.collection('feedback').doc(feedbackId).delete();
  }

  // Suspende/reativa uma conta (campo 'suspended' no doc do utilizador)
  static Future<void> setSuspended(String uid, bool suspended) async {
    await _db.collection('users').doc(uid).set({'suspended': suspended}, SetOptions(merge: true));
  }

  // Concede/retira admin
  static Future<void> setAdmin(String uid, bool admin) async {
    await _db.collection('users').doc(uid).set({'isAdmin': admin}, SetOptions(merge: true));
  }

  // Apaga a conta: posts, relações de seguir (em ambos os lados) e o documento.
  static Future<void> deleteUser(String uid) async {
    final userRef = _db.collection('users').doc(uid);
    final batch = _db.batch();

    // Posts da conta
    final posts = await _db.collection('posts').where('authorId', isEqualTo: uid).get();
    for (final p in posts.docs) { batch.delete(p.reference); }

    // Quem seguia esta conta → remover esta conta do "a seguir" deles
    final followers = await userRef.collection('followers').get();
    for (final f in followers.docs) {
      batch.delete(_db.collection('users').doc(f.id).collection('following').doc(uid));
      batch.set(_db.collection('users').doc(f.id),
          {'followingCount': FieldValue.increment(-1), 'followingIds': FieldValue.arrayRemove([uid])},
          SetOptions(merge: true));
      batch.delete(f.reference);
    }

    // Quem esta conta seguia → remover esta conta dos seguidores deles
    final following = await userRef.collection('following').get();
    for (final g in following.docs) {
      batch.delete(_db.collection('users').doc(g.id).collection('followers').doc(uid));
      batch.set(_db.collection('users').doc(g.id),
          {'followersCount': FieldValue.increment(-1)}, SetOptions(merge: true));
      batch.delete(g.reference);
    }

    batch.delete(userRef);
    await batch.commit();
  }

  // Verifica se o doc do utilizador atual tem a flag de admin
  static Future<bool> isCurrentUserAdmin(String uid) async {
    if (uid.isEmpty) return false;
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['isAdmin'] == true;
  }

  static Stream<bool> isAdminStream(String uid) {
    if (uid.isEmpty) return Stream.value(false);
    return _db.collection('users').doc(uid).snapshots().map((d) => d.data()?['isAdmin'] == true);
  }
}

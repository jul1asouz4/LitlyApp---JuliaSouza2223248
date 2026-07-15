import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class UserService {
  static final _db = FirebaseFirestore.instance;
  static final _storage = FirebaseStorage.instance;

  static Future<void> createUserDocument(User user, {String? name, String? username}) async {
    final doc = _db.collection('users').doc(user.uid);
    final resolvedName = name ?? user.displayName ?? 'Utilizador';
    final handle = username ?? '@${user.email?.split('@')[0] ?? 'user'}';

    final exists = (await doc.get()).exists;
    if (exists) {
      // O documento já existe (p.ex. criado por um listener durante o registo).
      // Se o registo forneceu nome/username explícitos, garante que ficam
      // guardados — sem eles, o username escolhido perder-se-ia numa corrida.
      if (name != null || username != null) {
        await doc.set({
          'name': resolvedName,
          'nameLower': resolvedName.toLowerCase(),
          'handle': handle,
        }, SetOptions(merge: true));
      }
      return;
    }

    await doc.set({
      'uid': user.uid,
      'name': resolvedName,
      'nameLower': resolvedName.toLowerCase(),
      'handle': handle,
      'email': user.email ?? '',
      'bio': '',
      'photoUrl': user.photoURL ?? '',
      'followersCount': 0,
      'followingCount': 0,
      'postsCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
      'blockedUsers': [],
    });
  }

  // Backfill: preenche nameLower/handle em contas antigas que não os têm,
  // para que apareçam na pesquisa. Idempotente — corre uma vez e não repete.
  static Future<void> backfillSearchFields() async {
    try {
      final snap = await _db.collection('users').get();
      final batch = _db.batch();
      var changed = 0;
      for (final doc in snap.docs) {
        final d = doc.data();
        final hasLower = d['nameLower'] != null && (d['nameLower'] as String).isNotEmpty;
        final hasHandle = d['handle'] != null && (d['handle'] as String).isNotEmpty;
        if (hasLower && hasHandle) continue;
        final name = (d['name'] ?? 'Utilizador').toString();
        batch.set(doc.reference, {
          'name': name,
          if (!hasLower) 'nameLower': name.toLowerCase(),
          if (!hasHandle) 'handle': (d['username'] ?? '@${name.toLowerCase().replaceAll(' ', '')}'),
        }, SetOptions(merge: true));
        changed++;
      }
      if (changed > 0) await batch.commit();
    } catch (_) {
      // silencioso — não bloqueia a app
    }
  }

  static Future<Map<String, dynamic>?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data();
  }

  static Stream<DocumentSnapshot> userStream(String uid) =>
      _db.collection('users').doc(uid).snapshots();

  static Future<String?> uploadProfilePhoto(String uid, Uint8List bytes) async {
    final ref = _storage.ref().child('profiles/$uid/avatar.jpg');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();
    await _db.collection('users').doc(uid).update({'photoUrl': url});
    await FirebaseAuth.instance.currentUser?.updatePhotoURL(url);
    return url;
  }

  static Future<String?> uploadPostPhoto(String uid, Uint8List bytes) async {
    final name = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref().child('posts/$uid/$name');
    await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    return await ref.getDownloadURL();
  }

  // ── Sistema de seguir ──────────────────────────────────────────────────────
  static Stream<bool> isFollowingStream(String targetUid) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return Stream.value(false);
    return _db.collection('users').doc(myUid)
        .collection('following').doc(targetUid)
        .snapshots().map((d) => d.exists);
  }

  // Stream que indica se já enviei um pedido de seguir (conta privada) a este alvo.
  static Stream<bool> hasPendingRequestStream(String targetUid) {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return Stream.value(false);
    return _db.collection('users').doc(targetUid)
        .collection('followRequests').doc(myUid)
        .snapshots().map((d) => d.exists);
  }

  // Devolve 'following' (seguiu já) ou 'requested' (pediu, conta privada).
  static Future<String> followUser(String targetUid, {String targetName = '', String targetPhoto = ''}) async {
    final me = FirebaseAuth.instance.currentUser;
    final myUid = me?.uid;
    if (myUid == null || myUid == targetUid) return 'following';

    final myName = me?.displayName ?? 'Utilizador';
    final myPhoto = me?.photoURL ?? '';

    // Conta privada → cria pedido em vez de seguir diretamente
    final targetDoc = await _db.collection('users').doc(targetUid).get();
    final isPrivate = targetDoc.data()?['isPrivate'] == true;
    if (isPrivate) {
      final batch = _db.batch();
      batch.set(_db.collection('users').doc(targetUid).collection('followRequests').doc(myUid),
          {'at': FieldValue.serverTimestamp(), 'name': myName, 'photoUrl': myPhoto});
      batch.set(_db.collection('users').doc(targetUid).collection('notifications').doc(), {
        'type': 'follow_request',
        'fromId': myUid, 'fromName': myName, 'fromPhoto': myPhoto,
        'text': '$myName pediu para te seguir.',
        'read': false, 'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
      return 'requested';
    }

    await _linkFollow(myUid, myName, myPhoto, targetUid, targetName, targetPhoto, notify: true);
    return 'following';
  }

  // Estabelece a relação seguidor/seguido + contadores (+ notificação opcional).
  static Future<void> _linkFollow(String myUid, String myName, String myPhoto,
      String targetUid, String targetName, String targetPhoto, {bool notify = true}) async {
    final batch = _db.batch();
    batch.set(_db.collection('users').doc(myUid).collection('following').doc(targetUid),
        {'at': FieldValue.serverTimestamp(), 'name': targetName, 'photoUrl': targetPhoto});
    batch.set(_db.collection('users').doc(targetUid).collection('followers').doc(myUid),
        {'at': FieldValue.serverTimestamp(), 'name': myName, 'photoUrl': myPhoto});
    batch.set(_db.collection('users').doc(targetUid),
        {'followersCount': FieldValue.increment(1)}, SetOptions(merge: true));
    batch.set(_db.collection('users').doc(myUid),
        {'followingCount': FieldValue.increment(1),
         'followingIds': FieldValue.arrayUnion([targetUid])}, SetOptions(merge: true));
    if (notify) {
      batch.set(_db.collection('users').doc(targetUid).collection('notifications').doc(), {
        'type': 'follow',
        'fromId': myUid, 'fromName': myName, 'fromPhoto': myPhoto,
        'text': '$myName começou a seguir-te.',
        'read': false, 'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  // ── Pedidos de seguir (contas privadas) ────────────────────────────────────
  static Stream<QuerySnapshot> followRequestsStream() {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return _db.collection('users').doc(myUid).collection('followRequests')
        .orderBy('at', descending: true).snapshots();
  }

  static Future<void> cancelFollowRequest(String targetUid) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;
    await _db.collection('users').doc(targetUid).collection('followRequests').doc(myUid).delete();
  }

  // Eu (dono privado) aceito o pedido de [requesterId].
  static Future<void> acceptFollowRequest(String requesterId, String requesterName, String requesterPhoto) async {
    final me = FirebaseAuth.instance.currentUser;
    final myUid = me?.uid;
    if (myUid == null) return;
    final myName = me?.displayName ?? 'Utilizador';
    final myPhoto = me?.photoURL ?? '';

    // O requester passa a seguir-me (sem nova notificação de "começou a seguir")
    await _linkFollow(requesterId, requesterName, requesterPhoto, myUid, myName, myPhoto, notify: false);
    // Remove o pedido + notifica o requester que foi aceite
    final batch = _db.batch();
    batch.delete(_db.collection('users').doc(myUid).collection('followRequests').doc(requesterId));
    batch.set(_db.collection('users').doc(requesterId).collection('notifications').doc(), {
      'type': 'follow_accept',
      'fromId': myUid, 'fromName': myName, 'fromPhoto': myPhoto,
      'text': '$myName aceitou o teu pedido para seguir.',
      'read': false, 'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  static Future<void> rejectFollowRequest(String requesterId) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;
    await _db.collection('users').doc(myUid).collection('followRequests').doc(requesterId).delete();
  }

  static Future<void> unfollowUser(String targetUid) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;

    final batch = _db.batch();
    batch.delete(_db.collection('users').doc(myUid).collection('following').doc(targetUid));
    batch.delete(_db.collection('users').doc(targetUid).collection('followers').doc(myUid));
    batch.set(_db.collection('users').doc(targetUid),
        {'followersCount': FieldValue.increment(-1)}, SetOptions(merge: true));
    batch.set(_db.collection('users').doc(myUid),
        {'followingCount': FieldValue.increment(-1),
         'followingIds': FieldValue.arrayRemove([targetUid])}, SetOptions(merge: true));
    await batch.commit();
  }

  // ── Notificações ───────────────────────────────────────────────────────────
  static Stream<QuerySnapshot> notificationsStream() {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return _db.collection('users').doc(myUid).collection('notifications')
        .orderBy('createdAt', descending: true).limit(50).snapshots();
  }

  static Future<void> markNotificationsRead() async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;
    final unread = await _db.collection('users').doc(myUid)
        .collection('notifications').where('read', isEqualTo: false).get();
    final batch = _db.batch();
    for (final d in unread.docs) {
      batch.update(d.reference, {'read': true});
    }
    await batch.commit();
  }

  static Future<void> blockUser(String targetUid) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;
    await _db.collection('users').doc(myUid).set({
      'blockedUsers': FieldValue.arrayUnion([targetUid]),
    }, SetOptions(merge: true));
    // Deixa de seguir, apenas se já seguia (evita contadores negativos)
    final f = await _db.collection('users').doc(myUid)
        .collection('following').doc(targetUid).get();
    if (f.exists) await unfollowUser(targetUid);
  }

  static Future<void> unblockUser(String targetUid) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    if (myUid == null) return;
    await _db.collection('users').doc(myUid).set({
      'blockedUsers': FieldValue.arrayRemove([targetUid]),
    }, SetOptions(merge: true));
  }

  static Stream<List<String>> blockedUsersStream() {
    final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return _db.collection('users').doc(myUid).snapshots().map((d) {
      final data = d.data();
      return List<String>.from(data?['blockedUsers'] ?? []);
    });
  }

  static Future<void> reportUser(String targetUid, String reason) async {
    final myUid = FirebaseAuth.instance.currentUser?.uid;
    await _db.collection('reports').add({
      'reportedBy': myUid,
      'targetUid': targetUid,
      'reason': reason,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}

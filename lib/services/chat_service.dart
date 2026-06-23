import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChatService {
  static final _db = FirebaseFirestore.instance;

  static String chatId(String otherUserId) {
    final myId = FirebaseAuth.instance.currentUser?.uid ?? 'anon';
    final ids = [myId, otherUserId]..sort();
    return ids.join('_');
  }

  static Stream<QuerySnapshot> messagesStream(String cid) => _db
      .collection('chats')
      .doc(cid)
      .collection('messages')
      .orderBy('timestamp', descending: false)
      .snapshots();

  // Stream de todas as conversas do utilizador actual (sem orderBy para evitar índice composto)
  static Stream<QuerySnapshot> myConversationsStream(String myId) => _db
      .collection('chats')
      .where('participants', arrayContains: myId)
      .snapshots();

  static Future<void> sendMessage(String cid, String text, {String otherName = '', String otherPhotoUrl = ''}) async {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid ?? 'anon';
    final chatRef = _db.collection('chats').doc(cid);

    final myName = user?.displayName ?? user?.email ?? 'Utilizador';
    final myPhoto = user?.photoURL ?? '';
    final participants = cid.split('_');
    final otherId = participants.firstWhere((p) => p != uid, orElse: () => '');

    // Se a conversa é nova, verifica se deve ser um PEDIDO de mensagem
    // (é pedido se o destinatário não me segue).
    final existing = await chatRef.get();
    final isNew = !existing.exists;
    bool pending = false;
    if (isNew && otherId.isNotEmpty) {
      final follows = await _db.collection('users').doc(otherId).collection('following').doc(uid).get();
      pending = !follows.exists;
    }

    // Grava a mensagem
    await chatRef.collection('messages').add({
      'text': text,
      'senderId': uid,
      'timestamp': FieldValue.serverTimestamp(),
    });

    final summary = <String, dynamic>{
      'lastMessage': text,
      'lastTimestamp': FieldValue.serverTimestamp(),
      'participants': participants,
      'names': {uid: myName, otherId: otherName},
      'photos': {uid: myPhoto, otherId: otherPhotoUrl},
    };
    if (isNew) {
      summary['pending'] = pending;
      summary['requestedBy'] = uid;
    }
    await chatRef.set(summary, SetOptions(merge: true));
  }

  // Aceitar / rejeitar um pedido de mensagem
  static Future<void> acceptMessageRequest(String cid) async {
    await _db.collection('chats').doc(cid).set({'pending': false}, SetOptions(merge: true));
  }

  static Future<void> rejectMessageRequest(String cid) async {
    // Apaga as mensagens e a conversa
    final msgs = await _db.collection('chats').doc(cid).collection('messages').get();
    final batch = _db.batch();
    for (final m in msgs.docs) { batch.delete(m.reference); }
    batch.delete(_db.collection('chats').doc(cid));
    await batch.commit();
  }
}

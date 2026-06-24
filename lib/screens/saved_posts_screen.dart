import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/post_card.dart';
import '../theme.dart';

class SavedPostsScreen extends StatelessWidget {
  const SavedPostsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    return Scaffold(
      backgroundColor: appBg(context),
      appBar: AppBar(
        backgroundColor: appSurface(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 18, color: appText(context)),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Guardados',
          style: TextStyle(color: appText(context), fontWeight: FontWeight.w700, fontSize: 17)),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: appBorder(context)),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users').doc(uid).collection('saved')
            .orderBy('savedAt', descending: true)
            .snapshots(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1A1A1A), strokeWidth: 2));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72, height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F0F0),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.bookmark_border_rounded, size: 34, color: Color(0xFFBBBBBB)),
                  ),
                  const SizedBox(height: 16),
                  Text('Nenhum post guardado ainda',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: appText(context))),
                  const SizedBox(height: 6),
                  const Text('Toca no 🔖 de qualquer post para guardar',
                    style: TextStyle(fontSize: 13, color: Color(0xFF999999))),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final postId = d['postId'] as String? ?? docs[i].id;
              return PostCard(key: ValueKey(postId), postId: postId, data: d);
            },
          );
        },
      ),
    );
  }
}

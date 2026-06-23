import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'other_user_profile_screen.dart';
import '../theme.dart';

/// Mostra a lista de seguidores ou de "a seguir" de qualquer utilizador.
class FollowListScreen extends StatelessWidget {
  final String userId;
  final String mode; // 'followers' ou 'following'
  const FollowListScreen({super.key, required this.userId, required this.mode});

  @override
  Widget build(BuildContext context) {
    final title = mode == 'followers' ? 'Seguidores' : 'A seguir';
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
            .collection('users').doc(userId).collection(mode).snapshots(),
        builder: (_, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Color(0xFF1A1A1A), strokeWidth: 2));
          }
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return Center(child: Text(
              mode == 'followers' ? 'Ainda sem seguidores.' : 'Ainda não segue ninguém.',
              style: const TextStyle(color: Color(0xFFAAAAAA), fontSize: 14)));
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final id = docs[i].id;
              return StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('users').doc(id).snapshots(),
                builder: (_, us) {
                  // Conta apagada → não mostra na lista
                  if (us.hasData && us.data?.exists == false) return const SizedBox.shrink();
                  final ud = us.data?.data() as Map<String, dynamic>?;
                  final name = (ud?['name'] ?? d['name'] ?? 'Utilizador').toString();
                  final photo = (ud?['photoUrl'] ?? d['photoUrl'] ?? '').toString();
                  final letter = name.isNotEmpty ? name[0].toUpperCase() : 'U';
                  return ListTile(
                    leading: avatarProvider(photo) != null
                        ? CircleAvatar(radius: 22, backgroundImage: avatarProvider(photo))
                        : CircleAvatar(radius: 22, backgroundColor: const Color(0xFF1A1A1A),
                            child: Text(letter, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                    title: Text(name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: appText(context))),
                    onTap: () => Navigator.push(context, MaterialPageRoute(
                      builder: (_) => OtherUserProfileScreen(
                        userId: id, name: name, avatar: letter, photoUrl: photo),
                    )),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

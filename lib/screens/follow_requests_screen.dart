import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';
import '../theme.dart';
import 'other_user_profile_screen.dart';

class FollowRequestsScreen extends StatelessWidget {
  const FollowRequestsScreen({super.key});

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
        title: Text('Pedidos de seguir',
          style: TextStyle(color: appText(context), fontWeight: FontWeight.w700, fontSize: 16)),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: UserService.followRequestsStream(),
        builder: (_, snap) {
          final docs = snap.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.person_add_disabled_rounded, size: 46, color: Color(0xFFDDDDDD)),
                SizedBox(height: 10),
                Text('Sem pedidos de seguir.', style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 14)),
              ]),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: docs.length,
            itemBuilder: (_, i) {
              final d = docs[i].data() as Map<String, dynamic>;
              final id = docs[i].id;
              final letter0 = (d['name'] ?? 'U').toString();
              final letter = letter0.isNotEmpty ? letter0[0].toUpperCase() : 'U';
              return ListTile(
                onTap: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => OtherUserProfileScreen(
                    userId: id,
                    name: (d['name'] ?? 'Utilizador').toString(),
                    avatar: letter,
                    photoUrl: (d['photoUrl'] ?? '').toString(),
                  ),
                )),
                leading: StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('users').doc(id).snapshots(),
                  builder: (_, us) {
                    final ud = us.data?.data() as Map<String, dynamic>?;
                    final photo = (ud?['photoUrl'] ?? d['photoUrl'] ?? '').toString();
                    return avatarProvider(photo) != null
                        ? CircleAvatar(radius: 22, backgroundImage: avatarProvider(photo))
                        : CircleAvatar(radius: 22, backgroundColor: const Color(0xFF1A1A1A),
                            child: Text(letter, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)));
                  },
                ),
                title: Text((d['name'] ?? 'Utilizador').toString(), style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: appText(context))),
                subtitle: const Text('Pediu para te seguir · toca para ver o perfil', style: TextStyle(color: Color(0xFF999999), fontSize: 12)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  GestureDetector(
                    onTap: () => UserService.rejectFollowRequest(id),
                    child: Container(
                      height: 32, padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: isDark(context) ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
                        borderRadius: BorderRadius.circular(8)),
                      child: Center(child: Text('Rejeitar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: appText(context)))),
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () => UserService.acceptFollowRequest(
                      id, (d['name'] ?? 'Utilizador').toString(), (d['photoUrl'] ?? '').toString()),
                    child: Container(
                      height: 32, padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(color: const Color(0xFF1A1A1A), borderRadius: BorderRadius.circular(8)),
                      child: const Center(child: Text('Aceitar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white))),
                    ),
                  ),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

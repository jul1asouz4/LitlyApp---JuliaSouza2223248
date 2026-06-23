import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/user_service.dart';
import '../theme.dart';

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

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
        title: Text('Contas bloqueadas',
          style: TextStyle(color: appText(context), fontWeight: FontWeight.w700, fontSize: 16)),
        centerTitle: true,
      ),
      body: StreamBuilder<List<String>>(
        stream: UserService.blockedUsersStream(),
        builder: (_, snap) {
          final ids = snap.data ?? [];
          if (ids.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.block_rounded, size: 46, color: Color(0xFFDDDDDD)),
                  SizedBox(height: 10),
                  Text('Não tens contas bloqueadas.',
                    style: TextStyle(color: Color(0xFFAAAAAA), fontSize: 14)),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 6),
            itemCount: ids.length,
            itemBuilder: (_, i) => _BlockedTile(uid: ids[i]),
          );
        },
      ),
    );
  }
}

class _BlockedTile extends StatelessWidget {
  final String uid;
  const _BlockedTile({required this.uid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(uid).get(),
      builder: (_, snap) {
        final d = snap.data?.data() as Map<String, dynamic>?;
        final name = d?['name'] ?? 'Utilizador';
        final photo = d?['photoUrl'] ?? '';
        final letter = name.isNotEmpty ? name[0].toUpperCase() : 'U';
        return ListTile(
          leading: photo.isNotEmpty
              ? CircleAvatar(radius: 22, backgroundImage: NetworkImage(photo))
              : CircleAvatar(radius: 22, backgroundColor: const Color(0xFF1A1A1A),
                  child: Text(letter, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          trailing: OutlinedButton(
            onPressed: () => UserService.unblockUser(uid),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1A1A1A),
              side: const BorderSide(color: Color(0xFFDDDDDD)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Desbloquear', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        );
      },
    );
  }
}

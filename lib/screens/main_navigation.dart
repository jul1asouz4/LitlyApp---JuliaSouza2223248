import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/user_service.dart';
import '../theme.dart';
import 'home_screen.dart';
import 'explore_screen.dart';
import 'create_post_screen.dart';
import 'chat_list_screen.dart';
import 'profile_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadTheme();
    // Corrige contas antigas para aparecerem na pesquisa (corre uma vez, idempotente)
    UserService.backfillSearchFields();
  }

  Future<void> _loadTheme() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final dark = doc.data()?['darkMode'] == true;
    themeNotifier.value = dark ? ThemeMode.dark : ThemeMode.light;
  }

  // IndexedStack mantém o estado de cada tab (como Instagram)
  final List<Widget> _screens = [
    const HomeScreen(),
    const ExploreScreen(),
    const SizedBox(), // placeholder — criar post abre como modal
    const ChatListScreen(),
    const ProfileScreen(),
  ];

  void _onTap(int index) {
    if (index == 2) {
      // Criar post abre como bottom sheet modal full-screen
      HapticFeedback.mediumImpact();
      Navigator.push(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const CreatePostScreen(),
          transitionsBuilder: (_, anim, __, child) {
            return SlideTransition(
              position: Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
                  .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
              child: child,
            );
          },
        ),
      );
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: _LitlyBottomBar(
        selectedIndex: _selectedIndex,
        onTap: _onTap,
      ),
    );
  }
}

// ── Bottom bar personalizada (estilo Instagram) ────────────────────────────────
class _LitlyBottomBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const _LitlyBottomBar({required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = [
      _NavItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: ''),
      _NavItem(icon: Icons.search_outlined, activeIcon: Icons.search_rounded, label: ''),
      _NavItem(icon: Icons.add_box_outlined, activeIcon: Icons.add_box_rounded, label: '', isCta: true),
      _NavItem(icon: Icons.chat_bubble_outline_rounded, activeIcon: Icons.chat_bubble_rounded, label: ''),
      _NavItem(icon: Icons.person_outline_rounded, activeIcon: Icons.person_rounded, label: ''),
    ];

    return Container(
      decoration: BoxDecoration(
        color: appSurface(context),
        border: Border(top: BorderSide(color: appBorder(context), width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 54,
          child: Row(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final selected = selectedIndex == i;

              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Center(
                    child: item.isCta
                        // Botão + central com destaque
                        ? AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1A1A1A),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
                          )
                        : item.badge != null
                            // Ícone com badge (chat)
                            ? Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Icon(
                                    selected ? item.activeIcon : item.icon,
                                    color: selected ? appText(context) : const Color(0xFFAAAAAA),
                                    size: 26,
                                  ),
                                  Positioned(
                                    top: -4,
                                    right: -6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE05D5D),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Colors.white, width: 1.5),
                                      ),
                                      child: Text(
                                        '${item.badge}',
                                        style: const TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w700),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            // Ícone normal
                            : Icon(
                                selected ? item.activeIcon : item.icon,
                                color: selected ? appText(context) : const Color(0xFFAAAAAA),
                                size: 26,
                              ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool isCta;
  final int? badge;

  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    this.isCta = false,
    this.badge,
  });
}

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'screens/welcome_screen.dart';
import 'screens/main_navigation.dart';
import 'firebase_options.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Erro Firebase: $e');
  }
  runApp(const LitlyApp());
}

class LitlyApp extends StatelessWidget {
  const LitlyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, mode, _) => MaterialApp(
        title: 'Litly',
        debugShowCheckedModeBanner: false,
        theme: buildLightTheme(),
        darkTheme: buildDarkTheme(),
        themeMode: mode,
        // Em ecrãs largos (desktop/web) limita a app a uma largura "mobile" centrada
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          if (mq.size.width <= 600) return child!;
          final dark = Theme.of(context).brightness == Brightness.dark;
          return ColoredBox(
            color: dark ? const Color(0xFF000000) : const Color(0xFFD8D8DA),
            child: Center(
              child: ClipRect(
                child: SizedBox(
                  width: 480,
                  child: MediaQuery(
                    data: mq.copyWith(size: Size(480, mq.size.height)),
                    child: child!,
                  ),
                ),
              ),
            ),
          );
        },
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                backgroundColor: Color(0xFF1A1A1A),
                body: Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
              );
            }
            if (snapshot.hasData && snapshot.data != null) {
              return const MainNavigation();
            }
            return const WelcomeScreen();
          },
        ),
      ),
    );
  }
}

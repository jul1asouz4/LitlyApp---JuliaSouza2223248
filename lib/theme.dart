import 'dart:convert';
import 'package:flutter/material.dart';

/// Notifier global do modo de tema. Alterar isto reconstrói o MaterialApp.
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

/// Devolve um ImageProvider que funciona tanto para URLs normais como para
/// imagens guardadas como data URI (base64) no Firestore. Devolve null se vazio.
ImageProvider? avatarProvider(String? url) {
  if (url == null || url.isEmpty) return null;
  if (url.startsWith('data:')) {
    try {
      return MemoryImage(base64Decode(url.substring(url.indexOf(',') + 1)));
    } catch (_) {
      return null;
    }
  }
  return NetworkImage(url);
}

/// Widget de imagem robusto: usa Image.memory para data URIs (base64) e
/// Image.network para URLs normais. Trata erros com um fallback.
Widget appImage(String? url, {double? width, double? height, BoxFit fit = BoxFit.cover, Widget? error}) {
  final fallback = error ?? const SizedBox.shrink();
  if (url == null || url.isEmpty) return fallback;
  Widget eb(_, __, ___) => fallback;
  if (url.startsWith('data:')) {
    try {
      final bytes = base64Decode(url.substring(url.indexOf(',') + 1));
      return Image.memory(bytes, width: width, height: height, fit: fit, errorBuilder: eb);
    } catch (_) {
      return fallback;
    }
  }
  return Image.network(url, width: width, height: height, fit: fit, errorBuilder: eb);
}

// ── Cores semânticas (adaptam-se ao tema) ─────────────────────────────────────
bool isDark(BuildContext c) => Theme.of(c).brightness == Brightness.dark;

/// Fundo geral dos ecrãs
Color appBg(BuildContext c) => isDark(c) ? const Color(0xFF121212) : const Color(0xFFF7F7F5);

/// Superfícies (cards, app bars, barras)
Color appSurface(BuildContext c) => isDark(c) ? const Color(0xFF1E1E1E) : Colors.white;

/// Texto principal
Color appText(BuildContext c) => isDark(c) ? const Color(0xFFF0F0F0) : const Color(0xFF1A1A1A);

/// Bordas e divisórias
Color appBorder(BuildContext c) => isDark(c) ? const Color(0xFF2C2C2C) : const Color(0xFFF0F0F0);

/// Preenchimento subtil (chips, campos, cartões internos, placeholders).
/// Claro no tema claro, cinza-escuro no tema escuro.
Color appField(BuildContext c) => isDark(c) ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0);

/// Cor de "destaque escuro" (botões pretos / avatares). Inverte no modo escuro
/// para continuar legível sobre fundo escuro.
Color appAccent(BuildContext c) => isDark(c) ? const Color(0xFF2A2A2A) : const Color(0xFF1A1A1A);

// ── ThemeData ─────────────────────────────────────────────────────────────────
ThemeData buildLightTheme() => ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: const Color(0xFFF7F7F5),
  fontFamily: 'SF Pro Display',
  cardColor: Colors.white,
  dividerColor: const Color(0xFFF0F0F0),
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF1A1A1A),
    surface: Colors.white,
    onSurface: Color(0xFF1A1A1A),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    elevation: 0,
    iconTheme: IconThemeData(color: Color(0xFF1A1A1A)),
    titleTextStyle: TextStyle(color: Color(0xFF1A1A1A), fontWeight: FontWeight.bold, fontSize: 20),
  ),
);

ThemeData buildDarkTheme() => ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: const Color(0xFF121212),
  fontFamily: 'SF Pro Display',
  cardColor: const Color(0xFF1E1E1E),
  dividerColor: const Color(0xFF2C2C2C),
  colorScheme: const ColorScheme.dark(
    primary: Colors.white,
    surface: Color(0xFF1E1E1E),
    onSurface: Color(0xFFF0F0F0),
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1E1E1E),
    elevation: 0,
    iconTheme: IconThemeData(color: Color(0xFFF0F0F0)),
    titleTextStyle: TextStyle(color: Color(0xFFF0F0F0), fontWeight: FontWeight.bold, fontSize: 20),
  ),
);

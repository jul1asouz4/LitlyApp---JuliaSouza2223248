import 'dart:convert';
import 'package:http/http.dart' as http;

class BookService {
  final String _baseUrl = "https://www.googleapis.com/books/v1/volumes?q=";
  final String _apiKey = "AIzaSyDRfw7WjusvEkhtKuembHMwTN9D-V7shVQ";

  // Constrói uma URL de capa que funciona no Flutter Web (sem erros de CORS),
  // passando a imagem do Google Books pelo proxy gratuito images.weserv.nl.
  static String coverFor(String volumeId) {
    if (volumeId.isEmpty) return '';
    final source = 'ssl:books.google.com/books/content?id=$volumeId&printsec=frontcover&img=1&zoom=1';
    return 'https://images.weserv.nl/?url=${Uri.encodeComponent(source)}&w=300';
  }

  Future<List<dynamic>> searchBooks(String query) async {
    final urlString = "$_baseUrl${Uri.encodeComponent(query)}&key=$_apiKey&maxResults=20";
    // A Google Books API falha esporadicamente (503/429). Tentamos algumas vezes
    // antes de desistir, com uma pequena pausa crescente entre tentativas.
    Object? lastError;
    for (int attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await http.get(Uri.parse(urlString));
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final items = (data['items'] ?? []) as List;
          for (final item in items) {
            final id = item['id'] as String? ?? '';
            final url = coverFor(id);
            item['volumeInfo'] ??= {};
            item['volumeInfo']['imageLinks'] = {
              'thumbnail': url,
              'smallThumbnail': url,
            };
          }
          return items;
        }
        // Erros temporários (503 serviço indisponível, 429 limite) → volta a tentar
        if (response.statusCode == 503 || response.statusCode == 429) {
          lastError = Exception('Erro API: ${response.statusCode}');
          await Future.delayed(Duration(milliseconds: 400 * (attempt + 1)));
          continue;
        }
        throw Exception('Erro API: ${response.statusCode}');
      } catch (e) {
        lastError = e;
        await Future.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
    throw lastError ?? Exception('Falha ao pesquisar livros');
  }
}

// Serviço de posts guardados — usa memória local (sem Firebase necessário)
// Quando o Firebase estiver configurado, substitui a lista por Firestore

class SavedPostsService {
  SavedPostsService._();
  static final SavedPostsService instance = SavedPostsService._();

  // id do post -> dados do post
  final Map<String, Map<String, String>> _saved = {};

  bool isSaved(String postId) => _saved.containsKey(postId);

  void toggle(String postId, Map<String, String> data) {
    if (_saved.containsKey(postId)) {
      _saved.remove(postId);
    } else {
      _saved[postId] = data;
    }
  }

  List<Map<String, String>> getAll() => _saved.values.toList();
}

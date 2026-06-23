class CommentsService {
  CommentsService._();
  static final CommentsService instance = CommentsService._();

  final Map<String, List<Comment>> _comments = {};

  List<Comment> getComments(String postId) => _comments[postId] ?? [];

  void addComment(String postId, String autor, String avatar, String texto) {
    _comments.putIfAbsent(postId, () => []);
    _comments[postId]!.insert(0, Comment(
      autor: autor,
      avatar: avatar,
      texto: texto,
      time: _timeNow(),
    ));
  }

  int count(String postId) => _comments[postId]?.length ?? 0;

  String _timeNow() {
    final now = DateTime.now();
    return '${now.hour}:${now.minute.toString().padLeft(2, '0')}';
  }
}

class Comment {
  final String autor, avatar, texto, time;
  const Comment({required this.autor, required this.avatar, required this.texto, required this.time});
}

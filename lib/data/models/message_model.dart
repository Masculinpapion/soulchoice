class MessageModel {
  final String id;
  final String matchId;
  // Hesabı silinen gönderici DB'de SET NULL olur — null = silinmiş kullanıcı
  final String? senderId;
  final String content;
  final DateTime? readAt;
  final DateTime createdAt;

  const MessageModel({
    required this.id,
    required this.matchId,
    this.senderId,
    required this.content,
    this.readAt,
    required this.createdAt,
  });

  bool get isRead => readAt != null;

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
        id: json['id'] as String,
        matchId: json['match_id'] as String,
        senderId: json['sender_id'] as String?,
        content: json['content'] as String,
        readAt: json['read_at'] != null
            ? DateTime.parse(json['read_at'] as String)
            : null,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

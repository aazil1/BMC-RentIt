class ChatMessage {
  final String id;
  final String text;
  final bool isMe;
  final DateTime sentAt;

  const ChatMessage({
    required this.id,
    required this.text,
    required this.isMe,
    required this.sentAt,
  });
}

class Conversation {
  final String id;
  final String participantName;
  final String itemName;
  final String avatarText;
  final String relatedImageUrl;
  final bool unread;
  final bool archived;
  final List<ChatMessage> messages;

  const Conversation({
    required this.id,
    required this.participantName,
    required this.itemName,
    required this.avatarText,
    required this.relatedImageUrl,
    required this.unread,
    required this.archived,
    required this.messages,
  });

  String get preview => messages.isEmpty ? 'No messages yet' : messages.last.text;

  DateTime get lastUpdated =>
      messages.isEmpty ? DateTime.now() : messages.last.sentAt;
}

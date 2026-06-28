import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/storage/hive_storage.dart';
import '../models/conversation_model.dart';
import '../models/message_model.dart';

/// Repository for managing chat conversations and messages
class ChatRepository {
  final Box<ConversationModel> _conversationsBox;
  final Box<MessageModel> _messagesBox;
  final Uuid _uuid = const Uuid();

  ChatRepository()
      : _conversationsBox = HiveStorage.conversations,
        _messagesBox = HiveStorage.messages;

  // === Conversations ===

  /// Get all conversations sorted by most recent
  List<ConversationModel> getAllConversations() {
    final conversations = _conversationsBox.values.toList();
    conversations.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return conversations;
  }

  /// Create a new conversation
  ConversationModel createConversation({
    String title = 'New Chat',
    required String model,
  }) {
    final now = DateTime.now();
    final conversation = ConversationModel(
      id: _uuid.v4(),
      title: title,
      createdAt: now,
      updatedAt: now,
      model: model,
    );
    _conversationsBox.put(conversation.id, conversation);
    return conversation;
  }

  /// Update conversation title
  void updateConversationTitle(String conversationId, String title) {
    final conversation = _conversationsBox.get(conversationId);
    if (conversation != null) {
      conversation.title = title;
      conversation.updatedAt = DateTime.now();
      conversation.save();
    }
  }

  /// Delete a conversation and its messages
  void deleteConversation(String conversationId) {
    _conversationsBox.delete(conversationId);
    // Delete all messages in this conversation
    final messagesToDelete = _messagesBox.values
        .where((m) => m.conversationId == conversationId)
        .toList();
    for (final message in messagesToDelete) {
      message.delete();
    }
  }

  // === Messages ===

  /// Get all messages for a conversation
  List<MessageModel> getMessages(String conversationId) {
    final messages = _messagesBox.values
        .where((m) => m.conversationId == conversationId)
        .toList();
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return messages;
  }

  /// Add a message to a conversation
  MessageModel addMessage({
    required String conversationId,
    required MessageRole role,
    required String content,
    String? model,
  }) {
    final message = MessageModel(
      id: _uuid.v4(),
      conversationId: conversationId,
      role: role,
      content: content,
      createdAt: DateTime.now(),
      model: model,
    );
    _messagesBox.put(message.id, message);

    // Update conversation timestamp
    final conversation = _conversationsBox.get(conversationId);
    if (conversation != null) {
      conversation.updatedAt = DateTime.now();
      conversation.save();
    }

    return message;
  }

  /// Update message content (used during streaming)
  void updateMessageContent(String messageId, String content) {
    final message = _messagesBox.get(messageId);
    if (message != null) {
      message.content = content;
      message.save();
    }
  }

  /// Delete a specific message
  void deleteMessage(String messageId) {
    _messagesBox.delete(messageId);
  }
}

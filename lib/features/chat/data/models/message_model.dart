import 'package:hive/hive.dart';

part 'message_model.g.dart';

@HiveType(typeId: 0)
enum MessageRole {
  @HiveField(0)
  user,

  @HiveField(1)
  assistant,

  @HiveField(2)
  system,
}

@HiveType(typeId: 1)
class MessageModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String conversationId;

  @HiveField(2)
  final MessageRole role;

  @HiveField(3)
  String content;

  @HiveField(4)
  final DateTime createdAt;

  @HiveField(5)
  final String? model;

  MessageModel({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    required this.createdAt,
    this.model,
  });

  Map<String, dynamic> toApiMessage() {
    return {
      'role': role.name,
      'content': content,
    };
  }
}

import 'package:hive/hive.dart';

part 'conversation_model.g.dart';

@HiveType(typeId: 2)
class ConversationModel extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  final DateTime createdAt;

  @HiveField(3)
  DateTime updatedAt;

  @HiveField(4)
  final String model;

  ConversationModel({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    required this.model,
  });
}

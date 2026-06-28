import 'package:hive_flutter/hive_flutter.dart';

import '../../features/chat/data/models/conversation_model.dart';
import '../../features/chat/data/models/message_model.dart';

/// Manages Hive box initialization and access
class HiveStorage {
  static const String conversationsBox = 'conversations';
  static const String messagesBox = 'messages';
  static const String settingsBox = 'settings';

  static Future<void> initialize() async {
    // Register adapters
    Hive.registerAdapter(ConversationModelAdapter());
    Hive.registerAdapter(MessageModelAdapter());
    Hive.registerAdapter(MessageRoleAdapter());

    // Open boxes
    await Hive.openBox<ConversationModel>(conversationsBox);
    await Hive.openBox<MessageModel>(messagesBox);
    await Hive.openBox(settingsBox);
  }

  static Box<ConversationModel> get conversations =>
      Hive.box<ConversationModel>(conversationsBox);

  static Box<MessageModel> get messages =>
      Hive.box<MessageModel>(messagesBox);

  static Box get settings => Hive.box(settingsBox);
}

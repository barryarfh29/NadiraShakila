import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import '../../../../core/constants/api_constants.dart';
import '../../../../core/constants/system_prompts.dart';
import '../../../../core/services/api_service.dart';
import '../../../../core/storage/hive_storage.dart';
import '../../../agent/data/agent_changes.dart';
import '../../../agent/data/agent_approval.dart';
import '../../../agent/data/agent_tools.dart';
import '../../../agent/widgets/diff_preview.dart';
import '../../../agent/data/checkpoints_provider.dart';
import '../../../diagnostics/diagnostics_provider.dart';
import '../../../mcp/mcp_provider.dart';
import '../../../steering/steering_provider.dart';
import '../../../terminal/terminal_provider.dart';
import '../../../terminal/terminal_sessions.dart';
import '../../../workspace/providers/workspace_provider.dart';
import '../../data/models/conversation_model.dart';
import '../../data/models/message_model.dart';
import '../../data/repositories/chat_repository.dart';
import 'attached_context.dart';
import 'attached_images.dart';
import 'settings_provider.dart';

// === Providers ===

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository();
});

final apiServiceProvider = Provider<ApiService?>((ref) {
  final apiKey = ref.watch(apiKeyProvider);
  if (apiKey.isEmpty) return null;
  return ApiService(apiKey: apiKey);
});

final conversationsProvider =
    StateNotifierProvider<ConversationsNotifier, List<ConversationModel>>(
        (ref) {
  final repo = ref.watch(chatRepositoryProvider);
  return ConversationsNotifier(repo);
});

final currentConversationIdProvider = StateProvider<String?>((ref) => null);

final currentConversationProvider = Provider<ConversationModel?>((ref) {
  final conversations = ref.watch(conversationsProvider);
  final currentId = ref.watch(currentConversationIdProvider);
  if (currentId == null) return null;
  try {
    return conversations.firstWhere((c) => c.id == currentId);
  } catch (_) {
    return null;
  }
});

final messagesProvider =
    StateNotifierProvider<MessagesNotifier, List<MessageModel>>((ref) {
  final repo = ref.watch(chatRepositoryProvider);
  final conversationId = ref.watch(currentConversationIdProvider);
  return MessagesNotifier(repo, conversationId);
});

final isStreamingProvider = StateProvider<bool>((ref) => false);

/// Live status of the agent while it works (e.g. "Membaca file.dart"),
/// shown as a "working" indicator. Null when idle.
final agentStatusProvider = StateProvider<String?>((ref) => null);

/// When true (and a workspace is open), messages run through the autonomous
/// agent loop that can read/edit files and run commands.
final agentModeProvider = StateProvider<bool>((ref) {
  // ignore: deprecated_member_use
  ref.listenSelf((_, next) => HiveStorage.settings.put('agent_mode', next));
  return HiveStorage.settings.get('agent_mode', defaultValue: false) as bool;
});

/// When true, the agent runs shell commands without asking for confirmation.
final autoApproveCommandsProvider = StateProvider<bool>((ref) {
  // ignore: deprecated_member_use
  ref.listenSelf((_, next) =>
      HiveStorage.settings.put('auto_approve_commands', next));
  return HiveStorage.settings.get('auto_approve_commands', defaultValue: false)
      as bool;
});

/// A pending shell command awaiting the user's approval, surfaced to the UI.
class PendingApproval {
  final String command;
  final Completer<bool> completer;
  PendingApproval(this.command, this.completer);
}

final pendingApprovalProvider = StateProvider<PendingApproval?>((ref) => null);

/// Text to inject into the chat input (e.g. from a suggestion card).
final chatInputDraftProvider = StateProvider<String?>((ref) => null);

/// Sampling temperature for chat completions (persisted).
final temperatureProvider = StateProvider<double>((ref) {
  // ignore: deprecated_member_use
  ref.listenSelf((_, next) => HiveStorage.settings.put('temperature', next));
  return HiveStorage.settings.get('temperature', defaultValue: 0.7) as double;
});

final selectedModelProvider = StateProvider<String>((ref) {
  // ignore: deprecated_member_use
  ref.listenSelf((_, next) => HiveStorage.settings.put('selected_model', next));
  return HiveStorage.settings
      .get('selected_model', defaultValue: ApiConstants.autoModelId) as String;
});

/// Dynamic model list fetched from API
final availableModelsProvider =
    StateNotifierProvider<AvailableModelsNotifier, List<String>>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  return AvailableModelsNotifier(apiService);
});

class AvailableModelsNotifier extends StateNotifier<List<String>> {
  final ApiService? _apiService;

  AvailableModelsNotifier(this._apiService) : super([]) {
    _fetchModels();
  }

  Future<void> _fetchModels() async {
    if (_apiService == null) return;
    try {
      final models = await _apiService.fetchModels();
      final ids = models
          .map((m) => m['id'] as String? ?? '')
          .where((id) => id.isNotEmpty)
          .toList();
      ids.sort();
      state = ids;
    } catch (_) {
      // Use fallback list
      state = ApiConstants.autoModelPriority;
    }
  }

  void refresh() => _fetchModels();
}

// === Notifiers ===

class ConversationsNotifier extends StateNotifier<List<ConversationModel>> {
  final ChatRepository _repo;

  ConversationsNotifier(this._repo) : super([]) {
    _loadConversations();
  }

  void _loadConversations() {
    state = _repo.getAllConversations();
  }

  ConversationModel createConversation(String model) {
    final conversation = _repo.createConversation(model: model);
    state = _repo.getAllConversations();
    return conversation;
  }

  void updateTitle(String conversationId, String title) {
    _repo.updateConversationTitle(conversationId, title);
    state = _repo.getAllConversations();
  }

  void deleteConversation(String conversationId) {
    _repo.deleteConversation(conversationId);
    state = _repo.getAllConversations();
  }

  void refresh() {
    state = _repo.getAllConversations();
  }
}

class MessagesNotifier extends StateNotifier<List<MessageModel>> {
  final ChatRepository _repo;
  final String? _conversationId;

  MessagesNotifier(this._repo, this._conversationId) : super([]) {
    _loadMessages();
  }

  void _loadMessages() {
    if (_conversationId == null) {
      state = [];
      return;
    }
    state = _repo.getMessages(_conversationId);
  }

  MessageModel addMessage({
    required MessageRole role,
    required String content,
    String? model,
  }) {
    if (_conversationId == null) {
      throw StateError('No active conversation');
    }
    final message = _repo.addMessage(
      conversationId: _conversationId,
      role: role,
      content: content,
      model: model,
    );
    state = [...state, message];
    return message;
  }

  void updateLastAssistantMessage(String content) {
    if (state.isEmpty) return;
    final lastMessage = state.last;
    if (lastMessage.role == MessageRole.assistant) {
      _repo.updateMessageContent(lastMessage.id, content);
      state = [
        ...state.sublist(0, state.length - 1),
        MessageModel(
          id: lastMessage.id,
          conversationId: lastMessage.conversationId,
          role: lastMessage.role,
          content: content,
          createdAt: lastMessage.createdAt,
          model: lastMessage.model,
        ),
      ];
    }
  }

  void refresh() {
    _loadMessages();
  }

  /// Removes the trailing assistant message (used by Regenerate).
  void removeLastAssistant() {
    if (state.isEmpty) return;
    final last = state.last;
    if (last.role == MessageRole.assistant) {
      _repo.deleteMessage(last.id);
      state = state.sublist(0, state.length - 1);
    }
  }
}

// === Chat Controller ===

final chatControllerProvider = Provider<ChatController>((ref) {
  return ChatController(ref);
});

class ChatController {
  final Ref _ref;
  StreamSubscription? _streamSubscription;
  Completer<void>? _streamCompleter;
  bool _cancelled = false;

  ChatController(this._ref);

  /// Send a message and stream the response
  Future<void> sendMessage(String content, {bool reuseLastUser = false}) async {
    final apiService = _ref.read(apiServiceProvider);
    if (apiService == null) {
      throw StateError('API key not configured');
    }

    var model = _ref.read(selectedModelProvider);
    
    // Resolve "auto" to best available model
    if (model == ApiConstants.autoModelId) {
      model = _resolveAutoModel();
    }
    
    var conversationId = _ref.read(currentConversationIdProvider);

    // Create conversation if none exists
    if (conversationId == null) {
      final conversation = _ref.read(conversationsProvider.notifier)
          .createConversation(model);
      conversationId = conversation.id;
      _ref.read(currentConversationIdProvider.notifier).state = conversationId;
    }

    final messagesNotifier = _ref.read(messagesProvider.notifier);

    // Add user message (skipped when regenerating an existing turn).
    if (!reuseLastUser) {
      messagesNotifier.addMessage(
        role: MessageRole.user,
        content: content,
      );
    }

    // Branch into the autonomous agent loop when enabled.
    final workspace = _ref.read(workspaceProvider);
    if (_ref.read(agentModeProvider) && workspace != null) {
      await _runAgentLoop(content, model, conversationId, workspace);
      return;
    }

    // Prepare API messages (system prompt + workspace context + history)
    final apiMessages = <Map<String, dynamic>>[
      {'role': 'system', 'content': SystemPrompts.defaultAssistant},
    ];

    // Inject workspace/file context so the AI is aware of the open project,
    // just like Kiro sees the active editor and folder.
    final workspaceContext = _buildWorkspaceContext();
    if (workspaceContext != null) {
      apiMessages.add({'role': 'system', 'content': workspaceContext});
    }

    apiMessages.addAll(
      _ref.read(messagesProvider)
          .where((m) => m.content.isNotEmpty) // skip empty placeholder
          .map((m) => m.toApiMessage()),
    );

    // Attach any images to the last user message as vision input.
    _injectImages(apiMessages);

    // Add empty assistant message placeholder
    messagesNotifier.addMessage(
      role: MessageRole.assistant,
      content: '',
      model: model,
    );

    // Start streaming
    _cancelled = false;
    _ref.read(isStreamingProvider.notifier).state = true;
    _ref.read(agentStatusProvider.notifier).state = 'Mengetik...';

    final completer = Completer<void>();
    final buffer = StringBuffer();
    _streamCompleter = completer;

    _streamSubscription = apiService
        .streamChatCompletion(
          messages: apiMessages,
          model: model,
          temperature: _ref.read(temperatureProvider),
          maxTokens: 4096,
        )
        .listen(
      (chunk) {
        buffer.write(chunk);
        messagesNotifier.updateLastAssistantMessage(buffer.toString());
      },
      onError: (Object e) {
        messagesNotifier.updateLastAssistantMessage(
          buffer.isEmpty
              ? '⚠️ Error: ${e.toString()}'
              : '${buffer.toString()}\n\n⚠️ Error: ${e.toString()}',
        );
        if (!completer.isCompleted) completer.complete();
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete();
      },
      cancelOnError: true,
    );

    await completer.future;
    await _streamSubscription?.cancel();
    _streamSubscription = null;
    _streamCompleter = null;

    // If the stream finished without producing any content (e.g. the model
    // returned nothing for a vision request), show a clear notice instead of
    // leaving the bubble stuck on "Thinking".
    if (!_cancelled && buffer.toString().trim().isEmpty) {
      messagesNotifier.updateLastAssistantMessage(
          '⚠️ Tidak ada balasan dari AI. Kemungkinan model tidak mendukung '
          'gambar, atau request terlalu besar. Coba model lain atau kirim '
          'tanpa gambar.');
    }

    if (!_cancelled) {
      // Auto-generate title from first message
      final allMessages = _ref.read(messagesProvider);
      if (allMessages.length <= 2) {
        _generateTitle(conversationId, content);
      }
      // Refresh conversations list for updated timestamp
      _ref.read(conversationsProvider.notifier).refresh();
    }

    _ref.read(agentStatusProvider.notifier).state = null;
    _ref.read(isStreamingProvider.notifier).state = false;
  }

  /// Builds a context block describing the current workspace and the file
  /// open in the editor, so the assistant can reason about the user's code.
  String? _buildWorkspaceContext() {
    final editor = _ref.read(editorProvider);
    final workspace = _ref.read(workspaceProvider);
    final activeFile = editor.activeFile;
    final attached = _ref.read(attachedContextProvider);

    if (workspace == null && activeFile == null && attached.isEmpty) {
      return null;
    }

    final sb = StringBuffer();
    sb.writeln('# Current IDE Context');
    sb.writeln(
        'The following describes the user\'s workspace. Use it to give precise, '
        'context-aware answers about their code. Do not repeat it back verbatim.');

    if (workspace != null) {
      sb.writeln('\nWorkspace root folder: $workspace');
      final steering = buildSteeringContext(workspace);
      if (steering != null) sb.writeln(steering);
    }

    if (editor.openFiles.isNotEmpty) {
      sb.writeln(
          'Open editor tabs: ${editor.openFiles.map((f) => f.name).join(', ')}');
    }

    if (activeFile != null) {
      const maxContextChars = 12000;
      var fileContent = activeFile.content;
      var truncated = false;
      if (fileContent.length > maxContextChars) {
        fileContent = fileContent.substring(0, maxContextChars);
        truncated = true;
      }
      sb.writeln('\n## Active file: ${activeFile.path}');
      sb.writeln('```${activeFile.extension}');
      sb.writeln(fileContent);
      if (truncated) sb.writeln('... (file truncated)');
      sb.writeln('```');
    }

    // Explicitly attached files and folders (#File / #Folder mentions).
    for (final item in attached) {
      sb.write(_buildAttachedContext(item));
    }

    return sb.toString();
  }

  /// Builds the context block for one attached context item.
  String _buildAttachedContext(ContextItem item) {
    switch (item.kind) {
      case ContextKind.problems:
        return _buildProblemsContext();
      case ContextKind.terminal:
        return _buildTerminalContext();
      case ContextKind.codebase:
        return _buildCodebaseContext();
      case ContextKind.file:
      case ContextKind.folder:
        break;
    }
    final sb = StringBuffer();
    try {
      if (item.isFolder) {
        final dir = Directory(item.path);
        if (!dir.existsSync()) return '';
        sb.writeln('\n## Attached folder: ${item.path}');
        final entries = dir
            .listSync(followLinks: false)
            .map((e) => p.basename(e.path) + (e is Directory ? '/' : ''))
            .toList()
          ..sort();
        sb.writeln('Contents: ${entries.join(', ')}');
      } else {
        final file = File(item.path);
        if (!file.existsSync()) return '';
        const maxChars = 12000;
        var content = file.readAsStringSync();
        var truncated = false;
        if (content.length > maxChars) {
          content = content.substring(0, maxChars);
          truncated = true;
        }
        final ext = p.extension(item.path).replaceFirst('.', '');
        sb.writeln('\n## Attached file: ${item.path}');
        sb.writeln('```$ext');
        sb.writeln(content);
        if (truncated) sb.writeln('... (file truncated)');
        sb.writeln('```');
      }
    } catch (_) {
      return '';
    }
    return sb.toString();
  }

  /// `#Problems` — the current diagnostics (errors/warnings) across the project.
  String _buildProblemsContext() {
    final diags = _ref.read(allDiagnosticsProvider);
    final sb = StringBuffer();
    sb.writeln('\n## Problems (current diagnostics)');
    if (diags.isEmpty) {
      sb.writeln('No problems detected.');
      return sb.toString();
    }
    const maxItems = 100;
    for (final d in diags.take(maxItems)) {
      final sev = d.severity.name.toUpperCase();
      final file = p.basename(d.filePath);
      final code = d.code != null ? ' [${d.code}]' : '';
      sb.writeln('- $sev $file:${d.line}:${d.col} — ${d.message}$code');
    }
    if (diags.length > maxItems) {
      sb.writeln('... and ${diags.length - maxItems} more.');
    }
    return sb.toString();
  }

  /// `#Terminal` — the visible output of the active terminal session.
  String _buildTerminalContext() {
    final session = _ref.read(terminalSessionsProvider).active;
    final sb = StringBuffer();
    sb.writeln('\n## Terminal output (active session)');
    if (session == null) {
      sb.writeln('No terminal is open.');
      return sb.toString();
    }
    try {
      var text = session.terminal.buffer.getText();
      text = text
          .split('\n')
          .map((l) => l.trimRight())
          .where((l) => l.isNotEmpty)
          .join('\n');
      const maxChars = 6000;
      var truncated = false;
      if (text.length > maxChars) {
        text = text.substring(text.length - maxChars);
        truncated = true;
      }
      sb.writeln('```');
      if (truncated) sb.writeln('... (earlier output truncated)');
      sb.writeln(text);
      sb.writeln('```');
    } catch (_) {
      sb.writeln('(unable to read terminal buffer)');
    }
    return sb.toString();
  }

  /// `#Codebase` — a map of files in the workspace (paths only).
  String _buildCodebaseContext() {
    final workspace = _ref.read(workspaceProvider);
    final sb = StringBuffer();
    sb.writeln('\n## Codebase file map');
    if (workspace == null) {
      sb.writeln('No workspace folder is open.');
      return sb.toString();
    }
    final files = listWorkspaceFiles(workspace, max: 600);
    sb.writeln('Workspace root: $workspace');
    sb.writeln('Files (${files.length}):');
    for (final f in files) {
      sb.writeln('- $f');
    }
    return sb.toString();
  }

  // === Agent mode ===

  /// Re-runs the last user turn: deletes the previous assistant reply and
  /// generates a fresh one.
  Future<void> regenerateLast() async {
    if (_ref.read(isStreamingProvider)) return;
    final messagesNotifier = _ref.read(messagesProvider.notifier);
    final messages = _ref.read(messagesProvider);
    if (messages.isEmpty) return;
    if (messages.last.role == MessageRole.assistant) {
      messagesNotifier.removeLastAssistant();
    }
    final remaining = _ref.read(messagesProvider);
    String? lastUser;
    for (var i = remaining.length - 1; i >= 0; i--) {
      if (remaining[i].role == MessageRole.user) {
        lastUser = remaining[i].content;
        break;
      }
    }
    if (lastUser == null) return;
    await sendMessage(lastUser, reuseLastUser: true);
  }

  /// Rewrites the last user message into multimodal content (text + images)
  /// when the user attached images, then clears the attachment buffer.
  void _injectImages(List<Map<String, dynamic>> apiMessages) {
    final images = _ref.read(attachedImagesProvider);
    if (images.isEmpty) return;
    for (var i = apiMessages.length - 1; i >= 0; i--) {
      if (apiMessages[i]['role'] == 'user') {
        final text = apiMessages[i]['content'];
        apiMessages[i] = {
          'role': 'user',
          'content': [
            {'type': 'text', 'text': text is String ? text : ''},
            for (final img in images)
              {
                'type': 'image_url',
                'image_url': {'url': img.dataUrl}
              },
          ],
        };
        break;
      }
    }
    _ref.read(attachedImagesProvider.notifier).clear();
  }

  /// Combined tool catalog: built-in tools plus any connected MCP tools.
  String _buildToolsDoc() {
    final builtin = AgentToolExecutor.toolsDoc();
    final mcp = _ref.read(mcpManagerProvider.notifier).toolsDoc();
    if (mcp.trim().isEmpty) return builtin;
    return '$builtin\n# MCP tools (from connected servers)\n$mcp';
  }

  /// Routes a tool call to the built-in executor or an MCP server.
  Future<ToolResult> _executeTool(AgentToolExecutor executor, String tool,
      Map<String, dynamic> args) async {
    final mcp = _ref.read(mcpManagerProvider.notifier);
    if (mcp.hasTool(tool)) {
      final out = await mcp.callRoutedTool(tool, args);
      return ToolResult(out);
    }
    return executor.execute(tool, args);
  }

  /// Runs an autonomous tool-use loop: the model reads/edits files and runs
  /// commands until it produces a final answer. The single assistant message
  /// is used as a live transcript of the agent's actions.
  Future<void> _runAgentLoop(
    String userContent,
    String model,
    String conversationId,
    String workspace,
  ) async {
    final apiService = _ref.read(apiServiceProvider);
    if (apiService == null) return;
    final messagesNotifier = _ref.read(messagesProvider.notifier);
    final executor = AgentToolExecutor(
      workspace,
      onExecuteCommand: (cmd) async {
        // Show terminal panel and send command to terminal UI
        _ref.read(bottomPanelProvider.notifier).state = BottomTab.terminal;
        await Future.delayed(const Duration(milliseconds: 150));
        _ref.read(terminalSessionsProvider.notifier).runCommand(cmd);
      },
      onReadTerminal: () {
        // Read the active terminal buffer so the agent can see terminal output
        final session = _ref.read(terminalSessionsProvider).active;
        if (session == null) return '';
        try {
          var text = session.terminal.buffer.getText();
          text = text
              .split('\n')
              .map((l) => l.trimRight())
              .where((l) => l.isNotEmpty)
              .join('\n');
          const maxChars = 6000;
          if (text.length > maxChars) {
            text = text.substring(text.length - maxChars);
          }
          return text;
        } catch (_) {
          return '(unable to read terminal buffer)';
        }
      },
    );

    final systemPrompt = SystemPrompts.agentMode
        .replaceAll('{{TOOLS}}', _buildToolsDoc());

    // Conversation sent to the model.
    final convo = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
      {
        'role': 'system',
        'content':
            _buildWorkspaceContext() ?? 'Workspace root folder: $workspace',
      },
      ..._ref.read(messagesProvider)
          .where((m) => m.content.isNotEmpty)
          .map((m) => m.toApiMessage()),
    ];
    _injectImages(convo);

    // Single assistant message acts as a growing transcript.
    messagesNotifier.addMessage(
      role: MessageRole.assistant,
      content: '',
      model: model,
    );
    final transcript = StringBuffer();
    void render() =>
        messagesNotifier.updateLastAssistantMessage(transcript.toString());

    _cancelled = false;
    _ref.read(isStreamingProvider.notifier).state = true;
    _ref.read(agentChangesProvider.notifier).clear();

    const maxSteps = 16;
    try {
      for (var step = 0; step < maxSteps; step++) {
        if (_cancelled) break;

        _ref.read(agentStatusProvider.notifier).state = 'Berpikir...';
        render(); // Force UI update so user sees "Berpikir..." while waiting

        // Stream the response token by token so user sees it building up
        final responseBuffer = StringBuffer();
        await for (final chunk in apiService.streamChatCompletion(
          messages: convo,
          model: model,
          temperature: 0.3,
          maxTokens: 4096,
        )) {
          if (_cancelled) break;
          responseBuffer.write(chunk);
        }
        final response = responseBuffer.toString();

        final call = _parseToolCall(response);

        // No tool call → final answer.
        if (call == null) {
          final steps = transcript.toString().trim();
          final answer = response.trim();
          if (steps.isNotEmpty) {
            messagesNotifier.updateLastAssistantMessage(
                '[[STEPS]]\n$steps\n[[/STEPS]]\n\n$answer');
          } else {
            messagesNotifier.updateLastAssistantMessage(answer);
          }
          convo.add({'role': 'assistant', 'content': response});
          break;
        }

        // Optional explanatory text before the tool block.
        if (call.preamble.trim().isNotEmpty) {
          transcript.writeln(call.preamble.trim());
          transcript.writeln();
        }
        transcript.writeln(_toolCallCard(call.tool, call.args));
        render();
        _ref.read(agentStatusProvider.notifier).state =
            _statusFor(call.tool, call.args);

        // Snapshot files before the agent mutates them (for Revert).
        if (call.tool == 'write_file' ||
            call.tool == 'str_replace' ||
            call.tool == 'delete_file') {
          final rel = call.args['path']?.toString() ?? '';
          if (rel.isNotEmpty) {
            final abs = p.normalize(p.join(workspace, rel));
            _ref.read(agentChangesProvider.notifier).record(abs);
          }
        }

        // Risky actions require user approval unless auto-approved.
        ToolResult result;
        final needsApproval = _needsApproval(call.tool, call.args);

        // For file writes/edits, show diff preview instead of simple approval
        if ((call.tool == 'write_file' || call.tool == 'str_replace') &&
            needsApproval && !_isAutoApproved(call.tool)) {
          final accepted = await _showDiffPreview(call.tool, call.args, workspace);
          if (_cancelled) break;
          if (!accepted) {
            result = const ToolResult(
              'The user rejected the file change. Do not retry it; '
              'consider an alternative or ask the user.',
              isError: true,
            );
            transcript.writeln('> &nbsp;&nbsp;🚫 Ditolak user');
          } else {
            result = await _executeTool(executor, call.tool, call.args);
            transcript.writeln(_toolResultLine(call.tool, call.args, result));
          }
        } else if (needsApproval && !_isAutoApproved(call.tool)) {
          final approvalResult = await _requestToolApproval(call.tool, call.args);
          if (_cancelled) break;
          if (!approvalResult.approved) {
            result = const ToolResult(
              'The user rejected this action. Do not retry it; '
              'consider an alternative or ask the user.',
              isError: true,
            );
            transcript.writeln('> &nbsp;&nbsp;🚫 Ditolak user');
          } else {
            result = await _executeTool(executor, call.tool, call.args);
            transcript
                .writeln(_toolResultLine(call.tool, call.args, result));
          }
        } else {
          result = await _executeTool(executor, call.tool, call.args);
          transcript.writeln(_toolResultLine(call.tool, call.args, result));
        }
        transcript.writeln();
        render();

        // Reflect file changes in the editor if the file is open.
        if (result.changedPath != null) {
          _ref.read(editorProvider.notifier).reloadFromDisk(result.changedPath!);
          _ref.read(explorerRefreshProvider.notifier).state++;
        }

        convo.add({'role': 'assistant', 'content': response});
        convo.add({
          'role': 'user',
          'content': 'Tool result for ${call.tool}:\n${result.output}',
        });

        if (step == maxSteps - 1) {
          transcript.writeln(
              '\n> _Reached the maximum number of steps. Ask me to continue if needed._');
          render();
        }
      }

      final allMessages = _ref.read(messagesProvider);
      if (allMessages.length <= 2) {
        _generateTitle(conversationId, userContent);
      }
      _ref.read(conversationsProvider.notifier).refresh();
    } catch (e) {
      transcript.writeln('\n\n⚠️ Error: ${e.toString()}');
      render();
    } finally {
      _ref.read(agentStatusProvider.notifier).state = null;
      _ref.read(isStreamingProvider.notifier).state = false;
      // Save a checkpoint capturing this run's file changes (restore point).
      final changes = _ref.read(agentChangesProvider);
      if (changes.isNotEmpty) {
        _ref.read(checkpointsProvider.notifier).push(userContent, changes);
      }
    }
  }

  String _statusFor(String tool, Map<String, dynamic> args) {
    final detail = (args['path'] ?? args['command'] ?? '').toString();
    switch (tool) {
      case 'read_file':
        return 'Membaca $detail';
      case 'write_file':
        return 'Menulis $detail';
      case 'str_replace':
        return 'Mengedit $detail';
      case 'delete_file':
        return 'Menghapus $detail';
      case 'list_dir':
        return 'Melihat folder ${detail.isEmpty ? "." : detail}';
      case 'run_command':
        return 'Menjalankan: $detail';
      default:
        return 'Bekerja...';
    }
  }

  /// Parses the first `tool` (or JSON) fenced block describing a tool call.
  _ToolCall? _parseToolCall(String response) {
    final blockRe = RegExp(r'```[a-zA-Z]*\s*\n(.*?)```', dotAll: true);
    for (final m in blockRe.allMatches(response)) {
      final body = m.group(1)?.trim() ?? '';
      if (!body.startsWith('{')) continue;
      try {
        final obj = jsonDecode(body);
        if (obj is Map && obj['tool'] is String) {
          final args = (obj['args'] as Map?)?.cast<String, dynamic>() ??
              <String, dynamic>{};
          return _ToolCall(
            preamble: response.substring(0, m.start),
            tool: obj['tool'] as String,
            args: args,
          );
        }
      } catch (_) {
        // not valid JSON; keep scanning
      }
    }
    // Fallback: whole response is a bare JSON tool object.
    final trimmed = response.trim();
    if (trimmed.startsWith('{')) {
      try {
        final obj = jsonDecode(trimmed);
        if (obj is Map && obj['tool'] is String) {
          return _ToolCall(
            preamble: '',
            tool: obj['tool'] as String,
            args: (obj['args'] as Map?)?.cast<String, dynamic>() ??
                <String, dynamic>{},
          );
        }
      } catch (_) {}
    }
    return null;
  }

  /// Markdown card announcing a tool action (Kiro-style action line).
  String _toolCallCard(String tool, Map<String, dynamic> args) {
    final detail = args['path'] ?? args['command'] ?? '';
    final label = detail.toString().isEmpty ? '' : ' `$detail`';
    const icons = {
      'list_dir': '📂',
      'read_file': '📄',
      'write_file': '✍️',
      'str_replace': '✏️',
      'delete_file': '🗑️',
      'run_command': '⚡',
    };
    final icon = icons[tool] ?? '🔧';
    return '> $icon **$tool**$label';
  }

  /// Compact one-line result summary for the transcript.
  String _toolResultLine(
      String tool, Map<String, dynamic> args, ToolResult result) {
    if (result.isError) {
      final firstLine = result.output.split('\n').first;
      return '> &nbsp;&nbsp;⚠️ $firstLine';
    }
    switch (tool) {
      case 'read_file':
        return '> &nbsp;&nbsp;✅ Read (${result.output.length} chars)';
      case 'list_dir':
        final count = result.output.split('\n').length - 1;
        return '> &nbsp;&nbsp;✅ $count entries';
      case 'run_command':
        final exitLine = result.output.split('\n').first;
        return '> &nbsp;&nbsp;✅ $exitLine';
      default:
        return '> &nbsp;&nbsp;✅ ${result.output.split('\n').first}';
    }
  }

  /// Determines if a tool action needs user approval.
  bool _needsApproval(String tool, Map<String, dynamic> args) {
    switch (tool) {
      case 'run_command':
        return true;
      case 'write_file':
        return true;
      case 'delete_file':
        return true;
      default:
        return false; // read_file, list_dir, read_terminal don't need approval
    }
  }

  /// Checks if the action type is auto-approved by user settings.
  bool _isAutoApproved(String tool) {
    final settings = _ref.read(autoApproveSettingsProvider);
    switch (tool) {
      case 'run_command':
        return settings.commands ||
            _ref.read(autoApproveCommandsProvider); // backward compat
      case 'write_file':
      case 'str_replace':
        return settings.fileWrites;
      case 'delete_file':
        return settings.fileDeletes;
      default:
        return false;
    }
  }

  /// Shows the new approval UI with proper type classification.
  Future<ApprovalResult> _requestToolApproval(
      String tool, Map<String, dynamic> args) {
    final completer = Completer<ApprovalResult>();
    final ApprovalType type;
    final String title;
    final List<ApprovalItem> items;

    switch (tool) {
      case 'run_command':
        final cmd = args['command']?.toString() ?? '';
        // Detect install commands
        final isInstall = cmd.contains('install') ||
            cmd.contains('pub add') ||
            cmd.contains('pub get') ||
            cmd.contains('pip install') ||
            cmd.contains('yarn add');
        type = isInstall ? ApprovalType.install : ApprovalType.command;
        title = isInstall ? 'Install package?' : 'Jalankan command ini?';
        items = [
          ApprovalItem(label: cmd, type: type),
        ];
        break;
      case 'write_file':
        final path = args['path']?.toString() ?? '';
        type = ApprovalType.writeFile;
        title = 'Buat/overwrite file?';
        items = [
          ApprovalItem(
            label: path,
            detail: '${(args['content']?.toString().length ?? 0)} chars',
            type: type,
          ),
        ];
        break;
      case 'delete_file':
        final path = args['path']?.toString() ?? '';
        type = ApprovalType.deleteFile;
        title = 'Hapus file ini?';
        items = [
          ApprovalItem(label: path, type: type),
        ];
        break;
      default:
        type = ApprovalType.command;
        title = 'Lakukan aksi ini?';
        items = [
          ApprovalItem(label: '$tool: ${args.toString()}', type: type),
        ];
    }

    _ref.read(approvalRequestProvider.notifier).state = ApprovalRequest(
      title: title,
      type: type,
      items: items,
      completer: completer,
    );

    return completer.future;
  }

  /// Old approval method removed — using _requestToolApproval instead

  /// Shows a diff preview for file write/edit operations and waits for user decision.
  Future<bool> _showDiffPreview(
      String tool, Map<String, dynamic> args, String workspace) async {
    final relPath = args['path']?.toString() ?? '';
    final absPath = p.normalize(p.join(workspace, relPath));
    final file = File(absPath);

    String oldContent = '';
    String newContent = '';

    if (tool == 'write_file') {
      oldContent = file.existsSync() ? file.readAsStringSync() : '';
      newContent = args['content']?.toString() ?? '';
    } else if (tool == 'str_replace') {
      if (!file.existsSync()) return true; // Can't diff, just allow
      oldContent = file.readAsStringSync();
      final oldStr = args['old_str']?.toString() ?? '';
      final newStr = args['new_str']?.toString() ?? '';
      if (!oldContent.contains(oldStr)) return true; // Will fail anyway
      newContent = oldContent.replaceFirst(oldStr, newStr);
    }

    // Compute diff hunks
    final hunks = computeDiff(oldContent, newContent);
    if (hunks.isEmpty) return true; // No visible changes

    // Show diff preview and wait for user decision
    _ref.read(pendingDiffProvider.notifier).state = PendingDiff(
      filePath: relPath,
      oldContent: oldContent,
      newContent: newContent,
      hunks: hunks,
    );

    // Wait for user to accept or reject
    while (_ref.read(pendingDiffProvider) != null && !_cancelled) {
      await Future.delayed(const Duration(milliseconds: 100));
      final decision = _ref.read(diffResultProvider);
      if (decision != null) {
        _ref.read(diffResultProvider.notifier).state = null;
        return decision;
      }
    }
    return false; // Cancelled
  }

  void _generateTitle(String conversationId, String firstMessage) {
    String title = firstMessage.trim();
    if (title.length > 50) {
      title = '${title.substring(0, 47)}...';
    }
    _ref.read(conversationsProvider.notifier).updateTitle(
      conversationId,
      title,
    );
  }

  void stopStreaming() {
    _cancelled = true;
    _streamSubscription?.cancel();
    _streamSubscription = null;
    if (_streamCompleter != null && !_streamCompleter!.isCompleted) {
      _streamCompleter!.complete();
    }
    // Cancel any pending command approval so the agent loop can unwind.
    final pending = _ref.read(pendingApprovalProvider);
    if (pending != null && !pending.completer.isCompleted) {
      pending.completer.complete(false);
    }
    _ref.read(pendingApprovalProvider.notifier).state = null;
    // Cancel new approval system
    final approval = _ref.read(approvalRequestProvider);
    if (approval != null && !approval.completer.isCompleted) {
      approval.completer.complete(ApprovalResult.rejected);
    }
    _ref.read(approvalRequestProvider.notifier).state = null;
    _ref.read(agentStatusProvider.notifier).state = null;
    _ref.read(isStreamingProvider.notifier).state = false;
  }

  /// Resolve "auto" mode to the best available model
  String _resolveAutoModel() {
    final available = _ref.read(availableModelsProvider);
    if (available.isEmpty) return ApiConstants.defaultModel;

    // Pick first available from priority list
    for (final model in ApiConstants.autoModelPriority) {
      if (available.contains(model)) return model;
    }
    // Fallback
    return ApiConstants.defaultModel;
  }
}

/// A parsed tool call from the model's response.
class _ToolCall {
  final String preamble;
  final String tool;
  final Map<String, dynamic> args;

  _ToolCall({
    required this.preamble,
    required this.tool,
    required this.args,
  });
}

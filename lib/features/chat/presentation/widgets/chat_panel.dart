import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../data/models/message_model.dart';
import '../providers/chat_provider.dart';
import 'message_bubble.dart';

/// Main chat panel displaying messages
class ChatPanel extends ConsumerStatefulWidget {
  const ChatPanel({super.key});

  @override
  ConsumerState<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends ConsumerState<ChatPanel> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(messagesProvider);
    final isStreaming = ref.watch(isStreamingProvider);

    ref.listen(messagesProvider, (previous, next) {
      if (next.isNotEmpty) _scrollToBottom();
    });

    if (messages.isEmpty) {
      return _buildWelcomeScreen(context);
    }

    return Container(
      color: AppColors.background,
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 0),
              itemCount: messages.length,
              itemBuilder: (context, index) {
                final message = messages[index];
                return MessageBubble(
                  message: message,
                  isStreaming: isStreaming && index == messages.length - 1,
                );
              },
            ),
          ),
          if (isStreaming)
            const _WorkingIndicator()
          else if (messages.isNotEmpty &&
              messages.last.role == MessageRole.assistant)
            const _RegenerateBar(),
        ],
      ),
    );
  }

  Widget _buildWelcomeScreen(BuildContext context) {
    return Container(
      color: AppColors.background,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 560),
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
              // Animated gradient icon
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.15),
                      AppColors.accent.withValues(alpha: 0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.auto_awesome,
                  size: 40,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'What can I help you with?',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Ask me anything — coding, debugging, explanations, or creative tasks.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 32),

              // Suggestion cards
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _SuggestionCard(
                    icon: Icons.code,
                    label: 'Write a function',
                    color: AppColors.primary,
                    onTap: () => ref.read(chatInputDraftProvider.notifier).state =
                        'Write a function that ',
                  ),
                  _SuggestionCard(
                    icon: Icons.bug_report_outlined,
                    label: 'Debug my code',
                    color: AppColors.error,
                    onTap: () => ref.read(chatInputDraftProvider.notifier).state =
                        'Debug the current file and explain what is wrong, then fix it.',
                  ),
                  _SuggestionCard(
                    icon: Icons.school_outlined,
                    label: 'Explain a concept',
                    color: AppColors.secondary,
                    onTap: () => ref.read(chatInputDraftProvider.notifier).state =
                        'Explain this concept: ',
                  ),
                  _SuggestionCard(
                    icon: Icons.architecture_outlined,
                    label: 'Design patterns',
                    color: AppColors.warning,
                    onTap: () => ref.read(chatInputDraftProvider.notifier).state =
                        'What design pattern would fit ',
                  ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        },
      ),
    );
  }
}

/// Small bar with a "Regenerate" action shown under the last AI reply.
class _RegenerateBar extends ConsumerWidget {
  const _RegenerateBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: InkWell(
          onTap: () => ref.read(chatControllerProvider).regenerateLast(),
          borderRadius: BorderRadius.circular(6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: AppColors.border),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.refresh, size: 13, color: AppColors.textSecondary),
                SizedBox(width: 6),
                Text('Regenerate',
                    style: TextStyle(
                        color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SuggestionCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  State<_SuggestionCard> createState() => _SuggestionCardState();
}

class _SuggestionCardState extends State<_SuggestionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _hovered ? AppColors.surfaceVariant : AppColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered
                  ? widget.color.withValues(alpha: 0.4)
                  : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 14, color: widget.color),
              const SizedBox(width: 8),
              Text(
                widget.label,
                style: TextStyle(
                  color:
                      _hovered ? AppColors.textPrimary : AppColors.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Animated "working" bar shown while the AI / agent is processing, with the
/// current activity (e.g. "Membaca file.dart").
class _WorkingIndicator extends ConsumerStatefulWidget {
  const _WorkingIndicator();

  @override
  ConsumerState<_WorkingIndicator> createState() => _WorkingIndicatorState();
}

class _WorkingIndicatorState extends ConsumerState<_WorkingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(agentStatusProvider) ?? 'Bekerja...';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          RotationTransition(
            turns: _controller,
            child: const Icon(Icons.autorenew,
                size: 13, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              status,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ..._dots(),
        ],
      ),
    );
  }

  List<Widget> _dots() {
    return List.generate(3, (i) {
      return AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = ((_controller.value + i * 0.25) % 1.0);
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 1),
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: t < 0.5 ? 1.0 : 0.25),
              shape: BoxShape.circle,
            ),
          );
        },
      );
    });
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/theme/codicons.dart';
import '../../../workspace/providers/workspace_provider.dart';
import '../../../workspace/widgets/editor_area.dart';
import '../../data/models/message_model.dart';

/// Message display widget styled like Kiro AI
/// Uses full-width layout with role indicators, no chat bubbles
class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isStreaming;

  const MessageBubble({
    super.key,
    required this.message,
    this.isStreaming = false,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
      decoration: BoxDecoration(
        color: isUser ? AppColors.surfaceVariant : AppColors.background,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar
            _buildAvatar(isUser),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Role label + actions
                  Row(
                    children: [
                      Text(
                        isUser ? 'You' : 'Nadira Shakila',
                        style: TextStyle(
                          color: isUser
                              ? AppColors.textPrimary
                              : AppColors.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (!isUser && message.model != null) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceLight,
                            borderRadius: BorderRadius.circular(3),
                          ),
                          child: Text(
                            _shortModelName(message.model!),
                            style: const TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 9,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                      ],
                      const Spacer(),
                      _CopyButton(content: message.content),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Message content
                  if (isUser)
                    SelectableText(
                      message.content,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 13,
                        height: 1.6,
                      ),
                    )
                  else
                    _buildAssistantContent(context),

                  // Streaming indicator
                  if (isStreaming && !isUser && message.content.isNotEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: _TypingCursor(),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(bool isUser) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: isUser ? AppColors.primaryDim : AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isUser
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.border,
          width: 1,
        ),
      ),
      child: Center(
        child: isUser
            ? const Text(
                'U',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              )
            : const Icon(
                Codicons.sparkle,
                size: 13,
                color: AppColors.primary,
              ),
      ),
    );
  }

  Widget _buildAssistantContent(BuildContext context) {
    if (message.content.isEmpty) {
      return const _ThinkingIndicator();
    }

    final content = message.content;
    const startM = '[[STEPS]]';
    const endM = '[[/STEPS]]';
    if (content.startsWith(startM) && content.contains(endM)) {
      final endIdx = content.indexOf(endM);
      final steps = content.substring(startM.length, endIdx).trim();
      final answer = content.substring(endIdx + endM.length).trim();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _AgentSteps(steps: steps, styleSheet: _markdownStyle()),
          if (answer.isNotEmpty) ...[
            const SizedBox(height: 10),
            _RichAnswer(data: answer, style: _markdownStyle()),
          ],
          // Show thinking indicator if still streaming (agent working on next step)
          if (answer.isEmpty && isStreaming)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: _ThinkingIndicator(),
            ),
        ],
      );
    }

    // During agent mode streaming, if content doesn't have [[STEPS]] wrapper
    // but is still streaming, show thinking after the transcript
    if (isStreaming && content.contains('> ')) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _RichAnswer(data: content, style: _markdownStyle()),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: _ThinkingIndicator(),
          ),
        ],
      );
    }

    return _RichAnswer(data: content, style: _markdownStyle());
  }

  MarkdownStyleSheet _markdownStyle() {
    return MarkdownStyleSheet(
        p: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
          height: 1.7,
        ),
        h1: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          height: 1.4,
        ),
        h2: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
        h3: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          height: 1.4,
        ),
        code: const TextStyle(
          color: AppColors.primaryLight,
          backgroundColor: AppColors.inlineCode,
          fontFamily: 'JetBrains Mono',
          fontSize: 12,
        ),
        codeblockDecoration: BoxDecoration(
          color: AppColors.codeBlock,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppColors.codeBlockBorder),
        ),
        codeblockPadding: const EdgeInsets.all(14),
        blockquoteDecoration: const BoxDecoration(
          border: Border(
            left: BorderSide(color: AppColors.primary, width: 3),
          ),
        ),
        blockquotePadding:
            const EdgeInsets.only(left: 14, top: 4, bottom: 4),
        blockquote: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13,
          fontStyle: FontStyle.italic,
        ),
        listBullet: const TextStyle(color: AppColors.textSecondary),
        listBulletPadding: const EdgeInsets.only(right: 8),
        horizontalRuleDecoration: const BoxDecoration(
          border: Border(
            top: BorderSide(color: AppColors.border),
          ),
        ),
        a: const TextStyle(
          color: AppColors.primary,
          decoration: TextDecoration.underline,
          decorationColor: AppColors.primary,
        ),
        strong: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        em: const TextStyle(
          color: AppColors.textSecondary,
          fontStyle: FontStyle.italic,
        ),
        tableHead: const TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        tableBody: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 12,
        ),
        tableBorder: TableBorder.all(color: AppColors.border, width: 1),
        tableCellsPadding: const EdgeInsets.all(8),
    );
  }

  String _shortModelName(String model) {
    final parts = model.split('/');
    final name = parts.last.split(':').first;
    if (name.length > 16) return '${name.substring(0, 14)}..';
    return name;
  }
}

class _CopyButton extends StatefulWidget {
  final String content;

  const _CopyButton({required this.content});

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _copied ? 'Copied!' : 'Copy',
      child: InkWell(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: widget.content));
          setState(() => _copied = true);
          await Future.delayed(const Duration(seconds: 2));
          if (mounted) setState(() => _copied = false);
        },
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.all(3),
          child: Icon(
            _copied ? Codicons.check : Codicons.copy,
            size: 13,
            color: _copied ? AppColors.success : AppColors.textMuted,
          ),
        ),
      ),
    );
  }
}

class _ThinkingIndicator extends StatefulWidget {
  const _ThinkingIndicator();

  @override
  State<_ThinkingIndicator> createState() => _ThinkingIndicatorState();
}

class _ThinkingIndicatorState extends State<_ThinkingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Thinking',
              style: TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
            const SizedBox(width: 4),
            ...List.generate(3, (i) {
              final t = ((_controller.value + i * 0.2) % 1.0);
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: Color.fromRGBO(129, 140, 248, t < 0.5 ? 1.0 : 0.3),
                  shape: BoxShape.circle,
                ),
              );
            }),
          ],
        );
      },
    );
  }
}

class _TypingCursor extends StatefulWidget {
  const _TypingCursor();

  @override
  State<_TypingCursor> createState() => _TypingCursorState();
}

class _TypingCursorState extends State<_TypingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Container(
          width: 2,
          height: 14,
          color: AppColors.primary.withValues(alpha: _controller.value),
        );
      },
    );
  }
}

/// Collapsible "Thinking completed" section holding the agent's steps,
/// shown above the final answer (collapsed by default).
class _AgentSteps extends StatefulWidget {
  final String steps;
  final MarkdownStyleSheet styleSheet;

  const _AgentSteps({required this.steps, required this.styleSheet});

  @override
  State<_AgentSteps> createState() => _AgentStepsState();
}

class _AgentStepsState extends State<_AgentSteps> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 14, color: AppColors.secondary),
                  const SizedBox(width: 8),
                  const Text(
                    'Thinking completed',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded ? Icons.expand_less : Icons.expand_more,
                    size: 16,
                    color: AppColors.textMuted,
                  ),
                ],
              ),
            ),
          ),
          if (_expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: MarkdownBody(
                data: widget.steps,
                selectable: true,
                styleSheet: widget.styleSheet,
              ),
            ),
        ],
      ),
    );
  }
}

/// Renders an assistant answer, splitting fenced code blocks out so each gets
/// a header with a Copy button (ChatGPT / Kiro style).
class _RichAnswer extends StatelessWidget {
  final String data;
  final MarkdownStyleSheet style;
  const _RichAnswer({required this.data, required this.style});

  @override
  Widget build(BuildContext context) {
    final segments = _split(data);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in segments)
          if (s.isCode)
            _CodeBlock(language: s.lang, code: s.text)
          else if (s.text.trim().isNotEmpty)
            MarkdownBody(data: s.text, selectable: true, styleSheet: style),
      ],
    );
  }

  static List<_Seg> _split(String data) {
    final segs = <_Seg>[];
    final re = RegExp(r'```([\w+-]*)\n?([\s\S]*?)```', multiLine: true);
    var last = 0;
    for (final m in re.allMatches(data)) {
      if (m.start > last) {
        segs.add(_Seg(false, '', data.substring(last, m.start)));
      }
      segs.add(_Seg(true, m.group(1) ?? '', m.group(2) ?? ''));
      last = m.end;
    }
    if (last < data.length) {
      segs.add(_Seg(false, '', data.substring(last)));
    }
    if (segs.isEmpty) segs.add(_Seg(false, '', data));
    return segs;
  }
}

class _Seg {
  final bool isCode;
  final String lang;
  final String text;
  _Seg(this.isCode, this.lang, this.text);
}

class _CodeBlock extends ConsumerStatefulWidget {
  final String language;
  final String code;
  const _CodeBlock({required this.language, required this.code});

  @override
  ConsumerState<_CodeBlock> createState() => _CodeBlockState();
}

class _CodeBlockState extends ConsumerState<_CodeBlock> {
  bool _copied = false;
  bool _inserted = false;

  @override
  Widget build(BuildContext context) {
    final code = widget.code.trimRight();
    final hasEditor = ref.watch(editorProvider).activeFile != null;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.codeBlock,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.codeBlockBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: language + insert + copy button
          Container(
            padding: const EdgeInsets.fromLTRB(12, 5, 6, 5),
            decoration: const BoxDecoration(
              border: Border(
                  bottom: BorderSide(color: AppColors.codeBlockBorder)),
            ),
            child: Row(
              children: [
                Text(
                  widget.language.isEmpty ? 'code' : widget.language,
                  style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (hasEditor)
                  _CodeAction(
                    icon: _inserted ? Icons.check : Icons.input,
                    label: _inserted ? 'Inserted' : 'Insert',
                    active: _inserted,
                    onTap: () {
                      ref.read(editorInsertProvider.notifier).state = code;
                      setState(() => _inserted = true);
                      Future.delayed(const Duration(seconds: 2), () {
                        if (mounted) setState(() => _inserted = false);
                      });
                    },
                  ),
                _CodeAction(
                  icon: _copied ? Icons.check : Icons.copy_rounded,
                  label: _copied ? 'Copied' : 'Copy',
                  active: _copied,
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: code));
                    if (!mounted) return;
                    setState(() => _copied = true);
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted) setState(() => _copied = false);
                    });
                  },
                ),
              ],
            ),
          ),
          // Code body
          Padding(
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              code,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontFamily: 'JetBrains Mono',
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CodeAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _CodeAction({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.success : AppColors.textMuted;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 10.5)),
          ],
        ),
      ),
    );
  }
}

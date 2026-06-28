import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/codicons.dart';

/// A pending diff that the agent wants to apply.
class PendingDiff {
  final String filePath;
  final String oldContent;
  final String newContent;
  final List<DiffHunk> hunks;

  PendingDiff({
    required this.filePath,
    required this.oldContent,
    required this.newContent,
    required this.hunks,
  });
}

/// One hunk of a diff (a contiguous block of changes).
class DiffHunk {
  final List<DiffLine> lines;
  bool accepted;

  DiffHunk({required this.lines, this.accepted = true});
}

/// A single line in a diff.
class DiffLine {
  final DiffLineType type;
  final String text;

  const DiffLine(this.type, this.text);
}

enum DiffLineType { context, added, removed }

/// Provider for the currently shown diff preview.
final pendingDiffProvider = StateProvider<PendingDiff?>((ref) => null);

/// Computes a simple line-by-line diff between two strings.
List<DiffHunk> computeDiff(String oldText, String newText) {
  final oldLines = oldText.split('\n');
  final newLines = newText.split('\n');
  final allDiffLines = <DiffLine>[];

  // Simple LCS-based diff
  final lcs = _lcs(oldLines, newLines);
  int oi = 0, ni = 0, li = 0;

  while (oi < oldLines.length || ni < newLines.length) {
    if (li < lcs.length && oi < oldLines.length && ni < newLines.length &&
        oldLines[oi] == lcs[li] && newLines[ni] == lcs[li]) {
      allDiffLines.add(DiffLine(DiffLineType.context, oldLines[oi]));
      oi++;
      ni++;
      li++;
    } else if (oi < oldLines.length &&
        (li >= lcs.length || oldLines[oi] != lcs[li])) {
      allDiffLines.add(DiffLine(DiffLineType.removed, oldLines[oi]));
      oi++;
    } else if (ni < newLines.length &&
        (li >= lcs.length || newLines[ni] != lcs[li])) {
      allDiffLines.add(DiffLine(DiffLineType.added, newLines[ni]));
      ni++;
    }
  }

  // Group into hunks (contiguous changes with 2 lines of context)
  return _groupIntoHunks(allDiffLines, contextLines: 2);
}

/// Groups diff lines into hunks with surrounding context.
List<DiffHunk> _groupIntoHunks(List<DiffLine> lines, {int contextLines = 2}) {
  if (lines.isEmpty) return [];

  // Find ranges of changed lines
  final changed = <int>[];
  for (int i = 0; i < lines.length; i++) {
    if (lines[i].type != DiffLineType.context) {
      changed.add(i);
    }
  }

  if (changed.isEmpty) return [];

  // Build hunks around changes
  final hunks = <DiffHunk>[];
  int start = (changed.first - contextLines).clamp(0, lines.length);
  int end = start;

  for (int i = 0; i < changed.length; i++) {
    final changeEnd = (changed[i] + contextLines + 1).clamp(0, lines.length);

    if (i + 1 < changed.length && changed[i + 1] - changed[i] <= contextLines * 2 + 1) {
      // Merge with next change
      end = changeEnd;
    } else {
      // Finalize this hunk
      end = changeEnd;
      hunks.add(DiffHunk(lines: lines.sublist(start, end)));

      // Start next hunk
      if (i + 1 < changed.length) {
        start = (changed[i + 1] - contextLines).clamp(0, lines.length);
        end = start;
      }
    }
  }

  return hunks;
}

/// Longest Common Subsequence of string lists.
List<String> _lcs(List<String> a, List<String> b) {
  final m = a.length, n = b.length;
  // For large files, use a simplified approach
  if (m > 500 || n > 500) {
    return _simpleLcs(a, b);
  }

  final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));
  for (int i = 1; i <= m; i++) {
    for (int j = 1; j <= n; j++) {
      if (a[i - 1] == b[j - 1]) {
        dp[i][j] = dp[i - 1][j - 1] + 1;
      } else {
        dp[i][j] = dp[i - 1][j] > dp[i][j - 1] ? dp[i - 1][j] : dp[i][j - 1];
      }
    }
  }

  // Backtrack
  final result = <String>[];
  int i = m, j = n;
  while (i > 0 && j > 0) {
    if (a[i - 1] == b[j - 1]) {
      result.add(a[i - 1]);
      i--;
      j--;
    } else if (dp[i - 1][j] > dp[i][j - 1]) {
      i--;
    } else {
      j--;
    }
  }
  return result.reversed.toList();
}

/// Simplified LCS for large files (takes common prefix/suffix + middle sample)
List<String> _simpleLcs(List<String> a, List<String> b) {
  final result = <String>[];

  // Common prefix
  int prefixLen = 0;
  while (prefixLen < a.length && prefixLen < b.length &&
      a[prefixLen] == b[prefixLen]) {
    result.add(a[prefixLen]);
    prefixLen++;
  }

  // Common suffix
  final suffix = <String>[];
  int si = a.length - 1, sj = b.length - 1;
  while (si > prefixLen && sj > prefixLen && a[si] == b[sj]) {
    suffix.add(a[si]);
    si--;
    sj--;
  }

  result.addAll(suffix.reversed);
  return result;
}

/// Widget that shows a diff preview with Accept/Reject per hunk.
class DiffPreviewPanel extends ConsumerStatefulWidget {
  const DiffPreviewPanel({super.key});

  @override
  ConsumerState<DiffPreviewPanel> createState() => _DiffPreviewPanelState();
}

class _DiffPreviewPanelState extends ConsumerState<DiffPreviewPanel> {
  @override
  Widget build(BuildContext context) {
    final diff = ref.watch(pendingDiffProvider);
    if (diff == null) return const SizedBox.shrink();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(
              children: [
                const Icon(Codicons.edit, size: 14, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    diff.filePath,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 12,
                      fontFamily: 'JetBrains Mono',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                _ActionButton(
                  label: 'Accept All',
                  icon: Icons.check_rounded,
                  color: AppColors.secondary,
                  onTap: () => _acceptAll(diff),
                ),
                const SizedBox(width: 6),
                _ActionButton(
                  label: 'Reject All',
                  icon: Icons.close_rounded,
                  color: AppColors.error,
                  onTap: () => _rejectAll(),
                ),
              ],
            ),
          ),

          // Diff content
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: diff.hunks.length,
              itemBuilder: (context, index) {
                return _HunkWidget(
                  hunk: diff.hunks[index],
                  hunkIndex: index,
                  onToggle: () => setState(() {
                    diff.hunks[index].accepted = !diff.hunks[index].accepted;
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _acceptAll(PendingDiff diff) {
    ref.read(pendingDiffProvider.notifier).state = null;
    // Signal acceptance (the agent loop will apply the change)
    ref.read(_diffResultProvider.notifier).state = true;
  }

  void _rejectAll() {
    ref.read(pendingDiffProvider.notifier).state = null;
    ref.read(_diffResultProvider.notifier).state = false;
  }
}

/// Internal provider to communicate diff accept/reject result
final _diffResultProvider = StateProvider<bool?>((ref) => null);

/// Public accessor for the diff decision
final diffResultProvider = _diffResultProvider;

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: color, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _HunkWidget extends StatelessWidget {
  final DiffHunk hunk;
  final int hunkIndex;
  final VoidCallback onToggle;

  const _HunkWidget({
    required this.hunk,
    required this.hunkIndex,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: hunk.accepted
              ? AppColors.primary.withValues(alpha: 0.3)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hunk header with accept/reject toggle
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: const BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.vertical(top: Radius.circular(5)),
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: onToggle,
                  child: Icon(
                    hunk.accepted
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    size: 16,
                    color: hunk.accepted ? AppColors.primary : AppColors.textMuted,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Hunk ${hunkIndex + 1}',
                  style: const TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          // Diff lines
          ...hunk.lines.map((line) => _DiffLineWidget(line: line)),
        ],
      ),
    );
  }
}

class _DiffLineWidget extends StatelessWidget {
  final DiffLine line;
  const _DiffLineWidget({required this.line});

  @override
  Widget build(BuildContext context) {
    final Color bg;
    final Color textColor;
    final String prefix;

    switch (line.type) {
      case DiffLineType.added:
        bg = const Color(0x1A4EC9B0); // green tint
        textColor = const Color(0xFF4EC9B0);
        prefix = '+';
        break;
      case DiffLineType.removed:
        bg = const Color(0x1AF14C4C); // red tint
        textColor = const Color(0xFFF14C4C);
        prefix = '-';
        break;
      case DiffLineType.context:
        bg = Colors.transparent;
        textColor = AppColors.textMuted;
        prefix = ' ';
        break;
    }

    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Text(
        '$prefix ${line.text}',
        style: TextStyle(
          color: textColor,
          fontSize: 11.5,
          fontFamily: 'JetBrains Mono',
          height: 1.5,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

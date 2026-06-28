import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Types of actions that need approval
enum ApprovalType {
  command,    // Shell command execution
  install,    // Package installation (npm install, pip install, etc.)
  writeFile,  // Creating or overwriting a file
  deleteFile, // Deleting a file
  multiStep,  // Multiple actions grouped (checklist)
}

/// A single item in an approval checklist
class ApprovalItem {
  final String label;
  final String? detail;
  final ApprovalType type;
  bool checked;

  ApprovalItem({
    required this.label,
    this.detail,
    required this.type,
    this.checked = true,
  });
}

/// Approval request shown to the user
class ApprovalRequest {
  final String title;
  final String? description;
  final ApprovalType type;
  final List<ApprovalItem> items;
  final Completer<ApprovalResult> completer;

  ApprovalRequest({
    required this.title,
    this.description,
    required this.type,
    required this.items,
    required this.completer,
  });
}

/// Result from user's approval decision
class ApprovalResult {
  final bool approved;
  final bool alwaysAllow;
  final List<ApprovalItem> approvedItems;

  const ApprovalResult({
    required this.approved,
    this.alwaysAllow = false,
    this.approvedItems = const [],
  });

  static const rejected = ApprovalResult(approved: false);
}

/// Provider for the current pending approval
final approvalRequestProvider = StateProvider<ApprovalRequest?>((ref) => null);

/// Categories of auto-approved actions
class AutoApproveSettings {
  bool commands;
  bool installs;
  bool fileWrites;
  bool fileDeletes;

  AutoApproveSettings({
    this.commands = false,
    this.installs = false,
    this.fileWrites = false,
    this.fileDeletes = false,
  });

  bool isAutoApproved(ApprovalType type) {
    switch (type) {
      case ApprovalType.command:
        return commands;
      case ApprovalType.install:
        return installs;
      case ApprovalType.writeFile:
        return fileWrites;
      case ApprovalType.deleteFile:
        return fileDeletes;
      case ApprovalType.multiStep:
        return false; // Multi-step always needs confirmation
    }
  }
}

final autoApproveSettingsProvider =
    StateNotifierProvider<AutoApproveNotifier, AutoApproveSettings>((ref) {
  return AutoApproveNotifier();
});

class AutoApproveNotifier extends StateNotifier<AutoApproveSettings> {
  AutoApproveNotifier() : super(AutoApproveSettings());

  void allowCommands() => state = AutoApproveSettings(
        commands: true,
        installs: state.installs,
        fileWrites: state.fileWrites,
        fileDeletes: state.fileDeletes,
      );

  void allowInstalls() => state = AutoApproveSettings(
        commands: state.commands,
        installs: true,
        fileWrites: state.fileWrites,
        fileDeletes: state.fileDeletes,
      );

  void allowAll() => state = AutoApproveSettings(
        commands: true,
        installs: true,
        fileWrites: true,
        fileDeletes: true,
      );
}

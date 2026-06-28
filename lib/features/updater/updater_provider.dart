import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'updater_service.dart';

/// State for the update checker
enum UpdateStatus { idle, checking, available, downloading, installing, error }

class UpdateState {
  final UpdateStatus status;
  final UpdateInfo? updateInfo;
  final double downloadProgress;
  final String? errorMessage;

  const UpdateState({
    this.status = UpdateStatus.idle,
    this.updateInfo,
    this.downloadProgress = 0,
    this.errorMessage,
  });

  UpdateState copyWith({
    UpdateStatus? status,
    UpdateInfo? updateInfo,
    double? downloadProgress,
    String? errorMessage,
  }) {
    return UpdateState(
      status: status ?? this.status,
      updateInfo: updateInfo ?? this.updateInfo,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final updateProvider =
    StateNotifierProvider<UpdateNotifier, UpdateState>((ref) {
  return UpdateNotifier();
});

class UpdateNotifier extends StateNotifier<UpdateState> {
  UpdateNotifier() : super(const UpdateState()) {
    // Auto-check on app startup (after a short delay)
    Future.delayed(const Duration(seconds: 5), checkForUpdate);
  }

  /// Check GitHub for updates
  Future<void> checkForUpdate() async {
    state = state.copyWith(status: UpdateStatus.checking);

    try {
      final info = await UpdaterService.checkForUpdate();
      if (info != null) {
        state = state.copyWith(
          status: UpdateStatus.available,
          updateInfo: info,
        );
      } else {
        state = state.copyWith(status: UpdateStatus.idle);
      }
    } catch (e) {
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Download and install the update
  Future<void> installUpdate() async {
    if (state.updateInfo == null) return;

    state = state.copyWith(
      status: UpdateStatus.downloading,
      downloadProgress: 0,
    );

    try {
      final success = await UpdaterService.downloadAndApply(
        state.updateInfo!,
        onProgress: (progress) {
          state = state.copyWith(downloadProgress: progress);
        },
      );

      if (success) {
        state = state.copyWith(status: UpdateStatus.installing);
        // App will exit and the updater script will restart it
        await Future.delayed(const Duration(milliseconds: 500));
        exit(0);
      } else {
        state = state.copyWith(
          status: UpdateStatus.error,
          errorMessage: 'Update gagal. Coba lagi nanti.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        status: UpdateStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  /// Dismiss the update notification
  void dismiss() {
    state = const UpdateState(status: UpdateStatus.idle);
  }
}

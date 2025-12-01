import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

/// Ball detection data model
class BallDetectionState {
  final List<Map<String, dynamic>> detections;
  final int ballCount;
  final bool isCameraReady;
  final double? fps;
  final double? processingTimeMs;

  const BallDetectionState({
    this.detections = const [],
    this.ballCount = 0,
    this.isCameraReady = false,
    this.fps,
    this.processingTimeMs,
  });

  BallDetectionState copyWith({
    List<Map<String, dynamic>>? detections,
    int? ballCount,
    bool? isCameraReady,
    double? fps,
    double? processingTimeMs,
  }) {
    return BallDetectionState(
      detections: detections ?? this.detections,
      ballCount: ballCount ?? this.ballCount,
      isCameraReady: isCameraReady ?? this.isCameraReady,
      fps: fps ?? this.fps,
      processingTimeMs: processingTimeMs ?? this.processingTimeMs,
    );
  }
}

/// Ball detection state notifier
class BallDetectionNotifier extends StateNotifier<BallDetectionState> {
  BallDetectionNotifier() : super(const BallDetectionState());

  /// Process YOLO detection results
  void processResults(dynamic result) {
    if (result is! List) return;

    final List<Map<String, dynamic>> ballDetections = [];

    for (var item in result) {
      if (item is YOLOResult) {
        // Since this is a custom model that ONLY detects balls,
        // we don't need to filter by class name - accept all detections
        final rect = item.boundingBox;
        
        ballDetections.add({
          'class': item.className ?? 'ball',
          'confidence': item.confidence,
          'box': {
            'x1': rect.left,
            'y1': rect.top,
            'x2': rect.right,
            'y2': rect.bottom,
          },
        });
      }
    }

    // Only update state if there's a change to avoid unnecessary rebuilds
    if (ballDetections.length != state.ballCount) {
      state = state.copyWith(
        detections: ballDetections,
        ballCount: ballDetections.length,
        isCameraReady: true,
      );
    }
  }

  /// Update performance metrics (optional)
  void updatePerformance(double fps, double processingTime) {
    state = state.copyWith(
      fps: fps,
      processingTimeMs: processingTime,
    );
  }

  /// Mark camera as ready
  void setCameraReady(bool ready) {
    if (state.isCameraReady != ready) {
      state = state.copyWith(isCameraReady: ready);
    }
  }

  /// Reset state
  void reset() {
    state = const BallDetectionState();
  }
}

/// Ball detection provider
final ballDetectionProvider =
    StateNotifierProvider<BallDetectionNotifier, BallDetectionState>((ref) {
  return BallDetectionNotifier();
});

/// Individual providers for specific values (for targeted rebuilds)
final ballCountProvider = Provider<int>((ref) {
  return ref.watch(ballDetectionProvider).ballCount;
});

final detectionsProvider = Provider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(ballDetectionProvider).detections;
});

final cameraReadyProvider = Provider<bool>((ref) {
  return ref.watch(ballDetectionProvider).isCameraReady;
});


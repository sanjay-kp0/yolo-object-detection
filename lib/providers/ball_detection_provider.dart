import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';

/// Ball detection data model
class BallDetectionState {
  final List<Map<String, dynamic>> detections;
  final int ballCount;
  final bool isCameraReady;
  final double? fps;
  final double? processingTimeMs;
  final double frameWidth;   // Camera frame width from YOLO
  final double frameHeight;  // Camera frame height from YOLO

  const BallDetectionState({
    this.detections = const [],
    this.ballCount = 0,
    this.isCameraReady = false,
    this.fps,
    this.processingTimeMs,
    this.frameWidth = 1178,   // Default fallback
    this.frameHeight = 1572,  // Default fallback
  });

  BallDetectionState copyWith({
    List<Map<String, dynamic>>? detections,
    int? ballCount,
    bool? isCameraReady,
    double? fps,
    double? processingTimeMs,
    double? frameWidth,
    double? frameHeight,
  }) {
    return BallDetectionState(
      detections: detections ?? this.detections,
      ballCount: ballCount ?? this.ballCount,
      isCameraReady: isCameraReady ?? this.isCameraReady,
      fps: fps ?? this.fps,
      processingTimeMs: processingTimeMs ?? this.processingTimeMs,
      frameWidth: frameWidth ?? this.frameWidth,
      frameHeight: frameHeight ?? this.frameHeight,
    );
  }
}

/// Ball detection state notifier
class BallDetectionNotifier extends StateNotifier<BallDetectionState> {
  BallDetectionNotifier() : super(const BallDetectionState());

  /// Process raw streaming data from YOLO (includes frame size)
  void processStreamingData(Map<String, dynamic> data) {
    final List<Map<String, dynamic>> ballDetections = [];
    
    // Extract frame size (dynamic - works on all devices)
    final frameWidth = (data['frameWidth'] as num?)?.toDouble() ?? state.frameWidth;
    final frameHeight = (data['frameHeight'] as num?)?.toDouble() ?? state.frameHeight;
    
    // Extract detections
    final detections = data['detections'] as List<dynamic>? ?? [];
    
    for (var detection in detections) {
      if (detection is! Map) continue;
      
      final boundingBox = detection['boundingBox'] as Map?;
      if (boundingBox == null) continue;
      
      ballDetections.add({
        'class': detection['className'] ?? 'ball',
        'confidence': (detection['confidence'] as num?)?.toDouble() ?? 0.0,
        'box': {
          'x1': (boundingBox['left'] as num?)?.toDouble() ?? 0,
          'y1': (boundingBox['top'] as num?)?.toDouble() ?? 0,
          'x2': (boundingBox['right'] as num?)?.toDouble() ?? 0,
          'y2': (boundingBox['bottom'] as num?)?.toDouble() ?? 0,
        },
      });
    }

    // Update state with detections AND frame size
    state = state.copyWith(
      detections: ballDetections,
      ballCount: ballDetections.length,
      isCameraReady: true,
      frameWidth: frameWidth,
      frameHeight: frameHeight,
      fps: (data['fps'] as num?)?.toDouble(),
      processingTimeMs: (data['processingTimeMs'] as num?)?.toDouble(),
    );
  }

  /// Process YOLO detection results (legacy - no frame size)
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

    // Always update detections (ball position changes even if count is same)
    state = state.copyWith(
      detections: ballDetections,
      ballCount: ballDetections.length,
      isCameraReady: true,
    );
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

final frameWidthProvider = Provider<double>((ref) {
  return ref.watch(ballDetectionProvider).frameWidth;
});

final frameHeightProvider = Provider<double>((ref) {
  return ref.watch(ballDetectionProvider).frameHeight;
});


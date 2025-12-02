import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:ultralytics_yolo/widgets/yolo_controller.dart';
import 'package:ultralytics_yolo/yolo_view.dart';
import '../providers/ball_detection_provider.dart';

class BallDetectionScreen extends ConsumerStatefulWidget {
  const BallDetectionScreen({super.key});

  @override
  ConsumerState<BallDetectionScreen> createState() => _BallDetectionScreenState();
}

class _BallDetectionScreenState extends ConsumerState<BallDetectionScreen> {
  final YOLOViewController _controller = YOLOViewController();
  bool _thresholdsSet = false;

  @override
  void initState() {
    super.initState();
    // Set max 1 detection after a short delay to ensure view is ready
    Future.delayed(const Duration(milliseconds: 500), () {
      _setMaxOneDetection();
    });
  }

  Future<void> _setMaxOneDetection() async {
    if (_thresholdsSet) return;
    try {

      await _controller.setThresholds(
        confidenceThreshold: 0.30,
        iouThreshold: 0.35,
        numItemsThreshold: 1,  // MAX 1 DETECTION AT A TIME
      );
      _thresholdsSet = true;
      print("✅ Set max detections to 1");
    } catch (e) {
      print("⚠️ Could not set thresholds: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch specific providers to minimize rebuilds
    final ballCount = ref.watch(ballCountProvider);
    final detections = ref.watch(detectionsProvider);
    final isCameraReady = ref.watch(cameraReadyProvider);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black87,
        title: const Text(
          '⚽ Ball Detection',
          style: TextStyle(
            color: Colors.greenAccent,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          // Camera view with YOLO detection - OPTIMIZED FOR CUSTOM MODEL
          YOLOView(
            controller: _controller,
            // Use your custom trained model
            modelPath: Platform.isIOS ? 'nano_custom' : 'yolo11n',
            task: YOLOTask.detect,
            lensFacing: LensFacing.front,
            
            // ENABLE NATIVE OVERLAYS - Native circle drawing (faster!)
            showNativeUI: false,       // Hide sliders and FPS
            showOverlays: true,        // Show native circles
            
            // PLATFORM-SPECIFIC STREAMING CONFIG
            streamingConfig: Platform.isAndroid
                ? YOLOStreamingConfig(
                    // Android: Optimized for low-end devices
                    inferenceFrequency: 10,      // 10 FPS inference
                    maxFPS: 15,                  // 15 FPS display
                    includeMasks: false,         // Not needed for ball detection
                    includePoses: false,         // Not needed
                    includeOBB: false,          // Not needed
                    includeOriginalImage: false, // Saves memory
                    includeDetections: true,
                    includeClassifications: true,
                    includeProcessingTimeMs: true,
                    includeFps: true,
                  )
                : YOLOStreamingConfig(
                    // iOS: Better performance, higher FPS
                    inferenceFrequency: 30,      // 20 FPS inference
                    includeMasks: false,
                    includePoses: false,
                    includeOBB: false,
                    includeOriginalImage: false,
                    includeDetections: true,
                    includeClassifications: true,
                    includeProcessingTimeMs: true,
                    includeFps: true,
                  ),
            
            // Callback - uses streaming data to get frame size (dynamic for all devices)
            onStreamingData: (data) {
              ref.read(ballDetectionProvider.notifier).processStreamingData(data);
            },
          ),

          // Native overlay now draws circles directly - no Flutter painter needed!
          // The native code (iOS Swift / Android Kotlin) draws the circles for us

          // Stats overlay at the top - Only rebuilds when ballCount changes
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Consumer(
                builder: (context, ref, child) {
                  final count = ref.watch(ballCountProvider);
                  return _buildStatsOverlay(count);
                },
              ),
            ),
          ),

          // Loading indicator when camera is not ready - Only rebuilds when camera state changes
          if (!isCameraReady)
            const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Colors.greenAccent),
                  SizedBox(height: 20),
                  Text(
                    'Initializing Camera...',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),

          // Instructions at the bottom
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: Colors.greenAccent.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Text(
                'Point your camera at a ball to detect it.\n'
                'Bounding boxes will appear around detected balls.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build stats overlay widget
  Widget _buildStatsOverlay(int ballCount) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 24,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: Colors.greenAccent, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.greenAccent.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.sports_soccer,
            color: Colors.greenAccent,
            size: 28,
          ),
          const SizedBox(width: 12),
          Text(
            ballCount == 0
                ? 'No balls detected'
                : ballCount == 1
                    ? '1 Ball Detected'
                    : '$ballCount Balls Detected',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

}


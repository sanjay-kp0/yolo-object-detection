import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:ultralytics_yolo/widgets/yolo_controller.dart';
import 'package:ultralytics_yolo/yolo_view.dart';

class BallDetectionScreen extends StatefulWidget {
  const BallDetectionScreen({super.key});

  @override
  State<BallDetectionScreen> createState() => _BallDetectionScreenState();
}

class _BallDetectionScreenState extends State<BallDetectionScreen> {
  final YOLOViewController _controller = YOLOViewController();
  bool _thresholdsSet = false;
  bool _isCameraReady = false;

  @override
  void initState() {
    super.initState();
    // Set max 1 detection after a short delay to ensure view is ready
    Future.delayed(const Duration(milliseconds: 500), () {
      _setMaxOneDetection();
    });
    // Mark camera ready after short delay
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) setState(() => _isCameraReady = true);
    });
  }

  Future<void> _setMaxOneDetection() async {
    if (_thresholdsSet) return;
    try {
      await _controller.setThresholds(
        confidenceThreshold: 0.20,
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
            
            // PERFORMANCE SETTINGS - Control inference frequency
            streamingConfig: Platform.isAndroid
                ? YOLOStreamingConfig(
                    // Android: Optimized for performance
                    inferenceFrequency: 15,      // 20 FPS inference
                    includeMasks: false,
                    includePoses: false,
                    includeOBB: false,
                    includeOriginalImage: false,
                    includeDetections: true,
                    includeClassifications: false,
                    includeProcessingTimeMs: false,
                    includeFps: false,
                  )
                : YOLOStreamingConfig(
                    // iOS: Higher performance
                    inferenceFrequency: 30,      // 30 FPS inference
                    includeMasks: false,
                    includePoses: false,
                    includeOBB: false,
                    includeOriginalImage: false,
                    includeDetections: true,
                    includeClassifications: false,
                    includeProcessingTimeMs: false,
                    includeFps: false,
                  ),
            // NO Flutter callback - everything handled natively for max performance!
          ),

          // Native overlay draws circles directly - no Flutter painter needed!
          // The native code (iOS Swift / Android Kotlin) draws the circles for max performance

          // Loading indicator when camera is not ready
          if (!_isCameraReady)
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
                'Native circles will appear around detected balls.',
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
}


import 'package:flutter/material.dart';
import 'package:ultralytics_yolo/ultralytics_yolo.dart';
import 'package:ultralytics_yolo/yolo_view.dart';
import '../painters/ball_painter.dart';

class BallDetectionScreen extends StatefulWidget {
  const BallDetectionScreen({super.key});

  @override
  State<BallDetectionScreen> createState() => _BallDetectionScreenState();
}

class _BallDetectionScreenState extends State<BallDetectionScreen> {
  List<Map<String, dynamic>> _detections = [];
  int _ballCount = 0;
  bool _isCameraReady = false;
  final Size _imageSize = const Size(640, 640);

  void _onResult(dynamic result) {
    if (!mounted) return;

    print("results: $result");

    try {
      List<Map<String, dynamic>> allDetections = [];

      // Handle different result formats
      // if (result is Map) {
      //   // If result is a map with 'boxes' key
      //   if (result['boxes'] != null && result['boxes'] is List) {
      //     print("map1234");
      //     allDetections = List<Map<String, dynamic>>.from(result['boxes']);
      //   }
      //   // If result is a map with 'detections' key
      //   else if (result['detections'] != null && result['detections'] is List) {
      //     print("detections1234");
      //     allDetections = List<Map<String, dynamic>>.from(result['detections']);
      //   }
      //   // If result itself is the detection list
      //   else if (result.containsKey('class')) {
      //     print("class1234");
      //     allDetections = [Map<String, dynamic>.from(result)];
      //   }
      // } else if (result is List) {
        // print("list1234");
        allDetections = List<Map<String, dynamic>>.from(result);
      // }

      // Filter detections to only include balls
      final ballDetections =
          allDetections.where((detection) {
            final className =
                detection['class']?.toString().toLowerCase() ?? '';
            return className.contains('ball') ||
                className.contains('sports ball');
          }).toList();

      setState(() {
        _detections = ballDetections;
        _ballCount = ballDetections.length;
        _isCameraReady = true;
      });
    } catch (e) {
      debugPrint('Error processing detection result: $e');
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
          // Camera view with YOLO detection
          YOLOView(
            modelPath: 'yolo11n',
            task: YOLOTask.detect,
            confidenceThreshold: 0.1,
            iouThreshold: 0.5,
            onResult: _onResult,
          ),

          // Custom painter overlay for drawing circles
          if (_isCameraReady)
            Positioned.fill(
              child: CustomPaint(
                painter: BallPainter(
                  detections: _detections,
                  imageSize: _imageSize,
                  screenSize: MediaQuery.of(context).size,
                ),
              ),
            ),

          // Stats overlay at the top
          Positioned(
            top: 20,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
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
                      _ballCount == 0
                          ? 'No balls detected'
                          : _ballCount == 1
                          ? '1 Ball Detected'
                          : '$_ballCount Balls Detected',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Loading indicator when camera is not ready
          if (!_isCameraReady)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: Colors.greenAccent),
                  const SizedBox(height: 20),
                  Text(
                    'Initializing Camera...',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
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
                'Green circle will appear around detected balls.',
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

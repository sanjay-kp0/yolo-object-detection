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

  // Image size from YOLO model (width x height) - matches overlay dimensions
  final Size _imageSize = const Size(480, 640);

  Map<String, dynamic> _mapFromYoloResult(YOLOResult detection) {
    final box = detection.boundingBox;

    return {
      'class': detection.className ?? '',
      'classIndex': detection.classIndex,
      'confidence': detection.confidence,
      'box': {
        'x1': box.left,
        'y1': box.top,
        'x2': box.right,
        'y2': box.bottom,
      },
    };
  }

  void _onResult(dynamic result) {
    if (!mounted) return;

    try {
      List<Map<String, dynamic>> ballDetections = [];


      // Handle YOLOResult objects (List<YOLOResult>)
      if (result is List) {
        for (var item in result) {
          // Check if it's a YOLOResult object
          if (item is YOLOResult) {
            final className = item.className.toLowerCase();
            
            // Filter only balls
            if (className.contains('sports ball')) {
              // Extract bounding box from Rect
              final rect = item.boundingBox;
              
              // Convert YOLOResult to Map format for the painter
              ballDetections.add({
                'class': item.className,
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
          // Fallback: try to convert Map if needed
          else if (item is Map) {
            final className = (item['className'] ?? item['class'] ?? '').toString().toLowerCase();
            if (className.contains('ball') || className.contains('sports ball')) {
              ballDetections.add(Map<String, dynamic>.from(item));
            }
          }
        }
      }


      setState(() {
        _detections = ballDetections;
        _ballCount = ballDetections.length;
        _isCameraReady = true;
      });
    } catch (e,st) {
      debugPrint('Error processing detection result: $e place $st');
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


          Positioned(
              top: 60,
              left: 0,
              right: 0,
              child: TextButton(onPressed: (){
            try {
              YOLOViewController().switchCamera();
            }catch(er){
              print("error switching camera");
            }
          }, child: Text("Switch camera"))),

          // Custom painter overlay for drawing glowing circles around balls
          // Always show overlay (even if empty) to ensure it's on top
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: BallPainter(
                  detections: _detections,
                  imageSize: _imageSize,
                  screenSize: MediaQuery.of(context).size,
                ),
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
                'Glowing green circle will appear around detected balls.',
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

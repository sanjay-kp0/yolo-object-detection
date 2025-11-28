import 'package:flutter/material.dart';

/// Custom painter that draws circles around detected balls only
class BallPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;
  final Size imageSize;
  final Size screenSize;

  BallPainter({
    required this.detections,
    required this.imageSize,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (detections.isEmpty) {
      print("BallPainter: No detections to paint");
      return;
    }

    print("BallPainter: Painting ${detections.length} detections");
    print("BallPainter: Canvas size: $size, Screen size: $screenSize, Image size: $imageSize");

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Use canvas size for scaling (actual view size), not screen size
    // The coordinates from YOLO are likely already in screen/view coordinates
    // But if they're in normalized coordinates (0-1), we need to scale
    final scaleX = size.width / imageSize.width;
    final scaleY = size.height / imageSize.height;

    for (var detection in detections) {
      // Filter only balls - don't paint any other detected objects
      final className = detection['class']?.toString().toLowerCase() ?? '';
      if (!className.contains('ball') && !className.contains('sports ball')) {
        continue;
      }

      print("BallPainter: Processing detection: $detection");

      // Get bounding box coordinates from the 'box' map
      final box = detection['box'];
      if (box == null || box is! Map) {
        print("BallPainter: No box found in detection: $detection");
        continue;
      }

      // Extract coordinates (left, top, right, bottom from Rect)
      final x1 = (box['x1'] as num?)?.toDouble();
      final y1 = (box['y1'] as num?)?.toDouble();
      final x2 = (box['x2'] as num?)?.toDouble();
      final y2 = (box['y2'] as num?)?.toDouble();

      if (x1 == null || y1 == null || x2 == null || y2 == null) {
        print("BallPainter: Could not extract coordinates from box: $box");
        continue;
      }

      // Coordinates are in image pixel space (e.g., 640x480)
      // Scale them to canvas size
      // The image size is typically 640x480 or similar, we need to scale to actual view size
      final scaledX1 = x1 * scaleX;
      final scaledY1 = y1 * scaleY;
      final scaledX2 = x2 * scaleX;
      final scaledY2 = y2 * scaleY;

      // Calculate center and radius for the circle from the square bounding box
      final centerX = (scaledX1 + scaledX2) / 2;
      final centerY = (scaledY1 + scaledY2) / 2;
      // Use the larger dimension (width or height) to ensure circle covers the ball
      final width = scaledX2 - scaledX1;
      final height = scaledY2 - scaledY1;
      // Use the larger dimension to ensure the circle fully covers the ball
      final radius = (width > height ? width : height) / 2;
      final center = Offset(centerX, centerY);

      // Create glowing effect by drawing multiple concentric circles
      // Outer glow layers (larger, more transparent) - creates halo effect
      for (int i = 10; i >= 1; i--) {
        final glowPaint = Paint()
          ..color = Colors.greenAccent.withOpacity(0.4 / i)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 8.0 - (i * 0.6)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, i * 3.0);
        
        canvas.drawCircle(center, radius + (i * 4.0), glowPaint);
      }

      // Medium glow layers
      for (int i = 5; i >= 1; i--) {
        final mediumGlowPaint = Paint()
          ..color = Colors.greenAccent.withOpacity(0.6 / i)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6.0 - (i * 0.8)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, i * 2.0);
        
        canvas.drawCircle(center, radius + (i * 2.0), mediumGlowPaint);
      }

      // Main bright circle with strong glow
      final mainPaint = Paint()
        ..color = Colors.greenAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
      
      canvas.drawCircle(center, radius, mainPaint);

      // Inner bright circle for extra definition
      final innerPaint = Paint()
        ..color = Colors.greenAccent.withOpacity(0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0;
      
      canvas.drawCircle(center, radius - 3, innerPaint);

      // Innermost bright circle
      final corePaint = Paint()
        ..color = Colors.greenAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      
      canvas.drawCircle(center, radius - 5, corePaint);

      // Draw confidence score above the circle
      final confidence = detection['confidence'];
      if (confidence != null) {
        final confidenceText = '${(confidence * 100).toStringAsFixed(1)}%';

        textPainter.text = TextSpan(
          text: confidenceText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.black54,
          ),
        );

        textPainter.layout();
        textPainter.paint(
          canvas,
          Offset(centerX - textPainter.width / 2, centerY - radius - 30),
        );
      }

      // Draw "BALL" label below the circle
      textPainter.text = const TextSpan(
        text: 'BALL',
        style: TextStyle(
          color: Colors.greenAccent,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.black54,
        ),
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(centerX - textPainter.width / 2, centerY + radius + 10),
      );
    }
  }

  @override
  bool shouldRepaint(covariant BallPainter oldDelegate) {
    return detections != oldDelegate.detections ||
        imageSize != oldDelegate.imageSize ||
        screenSize != oldDelegate.screenSize;
  }
}

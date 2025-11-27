import 'package:flutter/material.dart';

/// Custom painter that draws circles around detected balls
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
    if (detections.isEmpty) return;

    final paint =
        Paint()
          ..color = Colors.greenAccent.withOpacity(0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Calculate scaling factors
    final scaleX = screenSize.width / imageSize.width;
    final scaleY = screenSize.height / imageSize.height;

    for (var detection in detections) {
      // Filter only balls
      final className = detection['class']?.toString().toLowerCase() ?? '';
      if (!className.contains('ball') && !className.contains('sports ball')) {
        continue;
      }

      // Get bounding box coordinates
      final box = detection['box'];
      if (box == null) continue;

      final x1 = (box['x1'] as num).toDouble() * scaleX;
      final y1 = (box['y1'] as num).toDouble() * scaleY;
      final x2 = (box['x2'] as num).toDouble() * scaleX;
      final y2 = (box['y2'] as num).toDouble() * scaleY;

      // Calculate center and radius for the circle
      final centerX = (x1 + x2) / 2;
      final centerY = (y1 + y2) / 2;
      final radius =
          ((x2 - x1) + (y2 - y1)) /
          4; // Average of width and height divided by 2

      // Draw circle around the ball
      canvas.drawCircle(Offset(centerX, centerY), radius, paint);

      // Draw a smaller filled circle at the center
      final centerPaint =
          Paint()
            ..color = Colors.red
            ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(centerX, centerY), 8.0, centerPaint);

      // Draw confidence score
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

      // Draw "BALL" label
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

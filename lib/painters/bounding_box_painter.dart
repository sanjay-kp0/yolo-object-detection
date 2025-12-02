import 'package:flutter/material.dart';

/// Custom painter that draws bounding boxes around detected balls
/// YOLO provides coordinates in camera resolution - must scale to canvas size
class BoundingBoxPainter extends CustomPainter {
  final List<Map<String, dynamic>> detections;
  final double frameWidth;   // Actual camera frame width from YOLO
  final double frameHeight;  // Actual camera frame height from YOLO

  BoundingBoxPainter({
    required this.detections,
    required this.frameWidth,
    required this.frameHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (detections.isEmpty) return;

    // Use dynamic frame size from YOLO (works on all devices)
    final double cameraWidth = frameWidth > 0 ? frameWidth : 1178;
    final double cameraHeight = frameHeight > 0 ? frameHeight : 1572;
    
    // Scale from camera resolution to canvas size
    final scaleX = size.width / cameraWidth;
    final scaleY = size.height / cameraHeight;

    debugPrint("🎨 Canvas: ${size.width}x${size.height}, Camera: ${cameraWidth}x$cameraHeight");
    debugPrint("🎨 Scale: $scaleX x $scaleY");

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (var detection in detections) {
      final box = detection['box'];
      if (box == null || box is! Map) continue;

      // Extract coordinates from YOLO (in camera resolution)
      final x1 = (box['x1'] as num?)?.toDouble() ?? 0;
      final y1 = (box['y1'] as num?)?.toDouble() ?? 0;
      final x2 = (box['x2'] as num?)?.toDouble() ?? 0;
      final y2 = (box['y2'] as num?)?.toDouble() ?? 0;

      // Scale to canvas coordinates
      final scaledX1 = x1 * scaleX;
      final scaledY1 = y1 * scaleY;
      final scaledX2 = x2 * scaleX;
      final scaledY2 = y2 * scaleY;

      debugPrint("🎨 Raw: ($x1,$y1)-($x2,$y2) → Scaled: ($scaledX1,$scaledY1)-($scaledX2,$scaledY2)");

      final rect = Rect.fromLTRB(scaledX1, scaledY1, scaledX2, scaledY2);

      // Skip invalid rects
      if (rect.width <= 0 || rect.height <= 0) continue;

      // Outer glow layers for depth effect
      for (int i = 3; i >= 1; i--) {
        final glowPaint = Paint()
          ..color = Colors.greenAccent.withOpacity(0.3 / i)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.0 + (i * 2.0)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, i * 3.0);
        
        final expandedRect = Rect.fromLTRB(
          scaledX1 - i * 2 + 10,
          scaledY1 - i * 2 + 10,
          scaledX2 + i * 2 + 10,
          scaledY2 + i * 2 + 10,
        );
        canvas.drawRect(expandedRect, glowPaint);
      }

      // Main bounding box with glow
      final mainPaint = Paint()
        ..color = Colors.greenAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.0
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0);
      
      canvas.drawRect(rect, mainPaint);

      // Inner sharp line for definition
      final innerPaint = Paint()
        ..color = Colors.greenAccent.withOpacity(0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      
      canvas.drawRect(rect, innerPaint);

      // Corner accents for modern look
      _drawCornerAccents(canvas, rect);

      // Draw confidence score at top-left of box
      final confidence = detection['confidence'];
      if (confidence != null) {
        final confidenceText = '${(confidence * 100).toStringAsFixed(0)}%';

        textPainter.text = TextSpan(
          text: confidenceText,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black,
                offset: Offset(1, 1),
                blurRadius: 3,
              ),
            ],
          ),
        );

        textPainter.layout();
        
        // Background for text
        final textBgRect = RRect.fromRectAndRadius(
          Rect.fromLTWH(
            rect.left,
            rect.top - 25,
            textPainter.width + 8,
            textPainter.height + 4,
          ),
          const Radius.circular(4),
        );
        
        final bgPaint = Paint()
          ..color = Colors.greenAccent.withOpacity(0.9);
        canvas.drawRRect(textBgRect, bgPaint);
        
        textPainter.paint(
          canvas,
          Offset(rect.left + 4, rect.top - 23),
        );
      }
    }
  }

  /// Draw corner accents for modern bounding box look
  void _drawCornerAccents(Canvas canvas, Rect rect) {
    final accentPaint = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final cornerLength = rect.width.clamp(10.0, 20.0);

    // Top-left corner
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left + cornerLength, rect.top),
      accentPaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.top),
      Offset(rect.left, rect.top + cornerLength),
      accentPaint,
    );

    // Top-right corner
    canvas.drawLine(
      Offset(rect.right, rect.top),
      Offset(rect.right - cornerLength, rect.top),
      accentPaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.top),
      Offset(rect.right, rect.top + cornerLength),
      accentPaint,
    );

    // Bottom-left corner
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.left + cornerLength, rect.bottom),
      accentPaint,
    );
    canvas.drawLine(
      Offset(rect.left, rect.bottom),
      Offset(rect.left, rect.bottom - cornerLength),
      accentPaint,
    );

    // Bottom-right corner
    canvas.drawLine(
      Offset(rect.right, rect.bottom),
      Offset(rect.right - cornerLength, rect.bottom),
      accentPaint,
    );
    canvas.drawLine(
      Offset(rect.right, rect.bottom),
      Offset(rect.right, rect.bottom - cornerLength),
      accentPaint,
    );
  }

  @override
  bool shouldRepaint(covariant BoundingBoxPainter oldDelegate) {
    return detections != oldDelegate.detections ||
           frameWidth != oldDelegate.frameWidth ||
           frameHeight != oldDelegate.frameHeight;
  }
}

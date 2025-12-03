import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'screens/ball_detection_screen_optimized.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Lock to LANDSCAPE orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  
  // Enable wakelock to keep screen on during detection
  await WakelockPlus.enable();
  
  // Wrap app with ProviderScope for Riverpod
  runApp(
    const ProviderScope(
      child: BallDetectionApp(),
    ),
  );
}

class BallDetectionApp extends StatelessWidget {
  const BallDetectionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ball Detection',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.greenAccent,
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: const BallDetectionScreen(),
    );
  }
}

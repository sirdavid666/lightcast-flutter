import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/camera_role_screen.dart';

class CameraApp extends StatelessWidget {
  const CameraApp({super.key});

  @override
  Widget build(BuildContext context) => ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'LightCast Camera',
          theme: ThemeData(
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xFF090B10),
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF3B82F6),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          home: const CameraRoleScreen(),
        ),
      );
}

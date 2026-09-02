import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../screens/director_screen.dart';
import 'theme.dart';

class DirectorApp extends StatelessWidget {
  const DirectorApp({super.key});

  @override
  Widget build(BuildContext context) => ProviderScope(
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'LightCast Director',
          theme: lightcastTheme,
          home: const DirectorScreen(),
        ),
      );
}

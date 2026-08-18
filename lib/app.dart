import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/sos_screen.dart';

class MaxiTrackChildApp extends StatelessWidget {
  const MaxiTrackChildApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ));

    return MaterialApp(
      title: 'MaxiTrack',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: const ColorScheme.dark(
          primary: Colors.red,
          secondary: Colors.red,
        ),
        scaffoldBackgroundColor: Colors.black,
        fontFamily: 'sans-serif',
      ),
      home: const SosScreen(),
    );
  }
}

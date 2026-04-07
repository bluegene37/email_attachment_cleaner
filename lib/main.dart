import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/splash_screen.dart';
import 'providers/file_process_provider.dart';
import 'providers/delete_process_provider.dart';
import 'providers/copy_files_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => FileProcessProvider()),
        ChangeNotifierProvider(create: (_) => DeleteProcessProvider()),
        ChangeNotifierProvider(create: (_) => CopyFilesProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Files Utility',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}

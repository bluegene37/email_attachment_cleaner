import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'delete_screen.dart';
import 'copy_files_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Files Utility')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 250,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TransferScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.move_to_inbox, size: 28),
                label: const Text(
                  'Transfer Files',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: 250,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CopyFilesScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.file_copy, size: 28),
                label: const Text(
                  'Copy Files',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade100,
                  foregroundColor: Colors.blue.shade900,
                ),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: 250,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const DeleteScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.delete_forever, size: 28),
                label: const Text(
                  'Delete Files',
                  style: TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade100,
                  foregroundColor: Colors.red.shade900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'delete_screen.dart';

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Email Tool')),
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
                  'Transfer Email',
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
                      builder: (context) => const DeleteScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.delete_forever, size: 28),
                label: const Text(
                  'Delete Email',
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

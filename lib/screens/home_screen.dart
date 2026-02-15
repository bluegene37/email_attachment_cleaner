import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/file_process_provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FileProcessProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Email Attachment Cleaner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Clear Progress',
            onPressed: provider.isProcessing
                ? null
                : () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Clear Progress?'),
                        content: const Text(
                          'This will reset the resume checkpoint. Are you sure?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              provider.clearProgress();
                              Navigator.pop(ctx);
                            },
                            child: const Text('Clear'),
                          ),
                        ],
                      ),
                    );
                  },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // Config Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPathRow(
                      context,
                      label: 'Source',
                      path: provider.sourcePath,
                      onPick: provider.pickSource,
                    ),
                    const SizedBox(height: 10),
                    _buildPathRow(
                      context,
                      label: 'Destination',
                      path: provider.destPath,
                      onPick: provider.pickDest,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value:
                                provider.availableClients.contains(
                                  provider.clientName,
                                )
                                ? provider.clientName
                                : provider.availableClients.isNotEmpty
                                ? provider.availableClients.first
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Client Name',
                              border: OutlineInputBorder(),
                            ),
                            items: provider.availableClients.map((
                              String value,
                            ) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) provider.setClientName(val);
                            },
                          ),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          width: 120, // Expanded width for year dropdown
                          child: DropdownButtonFormField<int>(
                            value: provider.selectedYear,
                            decoration: const InputDecoration(
                              labelText: 'Year',
                              border: OutlineInputBorder(),
                            ),
                            items: provider.availableYears.map((int value) {
                              return DropdownMenuItem<int>(
                                value: value,
                                child: Text(value.toString()),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) provider.setYear(val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text('Months:'),
                    Wrap(
                      spacing: 8.0,
                      children: provider.allMonths.map((m) {
                        final isSelected = provider.validMonths.contains(m);
                        return FilterChip(
                          label: Text(m),
                          selected: isSelected,
                          onSelected: (bool selected) {
                            provider.toggleMonth(m);
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Actions
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (!provider.isProcessing)
                  ElevatedButton.icon(
                    onPressed:
                        (provider.sourcePath != null &&
                            provider.destPath != null)
                        ? provider.startProcessing
                        : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Processing'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 15,
                      ),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    onPressed: provider.stop,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 15,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Progress / Status
            Text(
              provider.currentStatus,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text('Moved: ${provider.filesMoved} | Errors: ${provider.errors}'),
            const Divider(),

            // Logs
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  color: Colors.black12,
                ),
                child: ListView.builder(
                  itemCount: provider.logs.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 2.0,
                      ),
                      child: Text(
                        provider.logs[index],
                        style: const TextStyle(
                          fontFamily: 'Consolas',
                          fontSize: 12,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPathRow(
    BuildContext context, {
    required String label,
    String? path,
    required VoidCallback onPick,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            '$label:',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade400),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              path ?? 'Not Selected',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: path == null ? Colors.grey : Colors.black,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        ElevatedButton(onPressed: onPick, child: const Text('Browse')),
      ],
    );
  }
}

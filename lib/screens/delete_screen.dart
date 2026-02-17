import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/delete_process_provider.dart';

class DeleteScreen extends StatelessWidget {
  const DeleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DeleteProcessProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Delete Files')),
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
                      label: 'Target Folder',
                      path: provider.targetPath,
                      onPick: provider.pickTarget,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 100,
                          child: DropdownButtonFormField<int>(
                            value: provider.selectedYear,
                            decoration: const InputDecoration(
                              labelText: 'Year',
                              border: OutlineInputBorder(),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 0,
                              ),
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
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Months:',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8.0,
                                runSpacing: 4.0,
                                children: provider.allMonths.map((m) {
                                  final isSelected = provider.validMonths
                                      .contains(m);
                                  return FilterChip(
                                    label: Text(m),
                                    selected: isSelected,
                                    onSelected: (bool selected) {
                                      provider.toggleMonth(m);
                                    },
                                    visualDensity: VisualDensity.compact,
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
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
                if (!provider.isProcessing) ...[
                  ElevatedButton.icon(
                    onPressed: provider.targetPath != null
                        ? () => _showDeleteConfirmation(context, provider)
                        : null,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Delete All'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
                        vertical: 15,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: provider.clearLogs,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Clear Logs'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 15,
                      ),
                    ),
                  ),
                ] else
                  ElevatedButton.icon(
                    onPressed: provider.stop,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildStatCard(
                  'Deleted',
                  provider.deletedCount.toString(),
                  Colors.redAccent,
                  Icons.delete,
                ),
                _buildStatCard(
                  'Errors',
                  provider.errorCount.toString(),
                  Colors.orange,
                  Icons.error_outline,
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Logs
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade800),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.all(8),
                  reverse: true,
                  itemCount: provider.logs.length,
                  itemBuilder: (context, index) {
                    return Text(
                      provider.logs[index],
                      style: const TextStyle(
                        fontFamily: 'Consolas',
                        fontSize: 12,
                        color: Colors.redAccent,
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

  Widget _buildStatCard(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Expanded(
      child: Card(
        elevation: 2,
        color: color.withOpacity(0.1),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: color.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(title, style: TextStyle(color: color)),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    DeleteProcessProvider provider,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Are you sure you want to delete EVERYTHING inside:'),
            const SizedBox(height: 8),
            Text(
              provider.targetPath ?? '',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Filter: Year ${provider.selectedYear}, Months: ${provider.validMonths}',
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 8),
            const Text(
              'This action cannot be undone!',
              style: TextStyle(color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              provider.deleteFiles();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('DELETE', style: TextStyle(color: Colors.white)),
          ),
        ],
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

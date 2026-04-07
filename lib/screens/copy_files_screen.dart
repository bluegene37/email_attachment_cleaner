import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/copy_files_provider.dart';

class CopyFilesScreen extends StatelessWidget {
  const CopyFilesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<CopyFilesProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Copy Files')),
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
                      onPick: provider.isProcessing ? null : provider.pickSource,
                    ),
                    const SizedBox(height: 10),
                    _buildPathRow(
                      context,
                      label: 'Destination',
                      path: provider.destPath,
                      onPick: provider.isProcessing ? null : provider.pickDest,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _buildDatePicker(
                            context,
                            label: 'From Date',
                            date: provider.fromDate,
                            onPicked: provider.isProcessing ? (date) {} : (date) => provider.setFromDate(date),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildDatePicker(
                            context,
                            label: 'To Date',
                            date: provider.toDate,
                            onPicked: provider.isProcessing ? (date) {} : (date) => provider.setToDate(date),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Checkbox(
                          value: provider.enableTimeWindow,
                          onChanged: provider.isProcessing ? null : (val) => provider.setEnableTimeWindow(val ?? false),
                        ),
                        const Text('Limit Run Time', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _buildTimePicker(
                            context,
                            label: 'From',
                            time: provider.runFromTime,
                            enabled: !provider.isProcessing && provider.enableTimeWindow,
                            onPicked: provider.isProcessing ? (time) {} : (time) => provider.setRunFromTime(time),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildTimePicker(
                            context,
                            label: 'To',
                            time: provider.runToTime,
                            enabled: !provider.isProcessing && provider.enableTimeWindow,
                            onPicked: provider.isProcessing ? (time) {} : (time) => provider.setRunToTime(time),
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
                    onPressed:
                        (provider.sourcePath != null &&
                            provider.destPath != null)
                        ? provider.startProcessing
                        : null,
                    icon: const Icon(Icons.copy),
                    label: const Text('Start Copying'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 30,
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
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildStatCard(
                  'Copied',
                  provider.filesCopied.toString(),
                  Colors.blue,
                  Icons.file_copy,
                ),
                _buildStatCard(
                  'Errors',
                  provider.errors.toString(),
                  Colors.red,
                  Icons.error,
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
                        color: Colors.lightBlueAccent,
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

  Widget _buildDatePicker(
    BuildContext context, {
    required String label,
    required DateTime date,
    required ValueChanged<DateTime> onPicked,
  }) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final provider = Provider.of<CopyFilesProvider>(context, listen: false);
    return InkWell(
      onTap: provider.isProcessing ? null : () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2010),
          lastDate: DateTime(DateTime.now().year + 2),
        );
        if (picked != null) {
          onPicked(picked);
        }
      },
      child: Opacity(
        opacity: provider.isProcessing ? 0.5 : 1.0,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            suffixIcon: const Icon(Icons.calendar_today, size: 18),
          ),
          child: Text(dateFormat.format(date)),
        ),
      ),
    );
  }

  Widget _buildTimePicker(
    BuildContext context, {
    required String label,
    required TimeOfDay time,
    required bool enabled,
    required ValueChanged<TimeOfDay> onPicked,
  }) {
    return InkWell(
      onTap: enabled
          ? () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: time,
              );
              if (picked != null) {
                onPicked(picked);
              }
            }
          : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            suffixIcon: const Icon(Icons.access_time, size: 18),
          ),
          child: Text(time.format(context)),
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
        color: color.withValues(alpha: 0.1),
        shape: RoundedRectangleBorder(
          side: BorderSide(color: color.withValues(alpha: 0.5)),
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

  Widget _buildPathRow(
    BuildContext context, {
    required String label,
    String? path,
    required VoidCallback? onPick,
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

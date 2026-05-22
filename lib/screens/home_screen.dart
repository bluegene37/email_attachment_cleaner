import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/file_process_provider.dart';

class TransferScreen extends StatelessWidget {
  const TransferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<FileProcessProvider>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Files Utility')),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          children: [
            // Config Section
            Card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildPathRow(
                      context,
                      label: 'Source',
                      path: provider.sourcePath,
                      onPick: provider.pickSource,
                    ),
                    const SizedBox(height: 6),
                    _buildPathRow(
                      context,
                      label: 'Destination',
                      path: provider.destPath,
                      onPick: provider.pickDest,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 250, // Fixed proportional width
                          child: InputDecorator(
                            decoration: const InputDecoration(
                              labelText: 'Client Name',
                              border: OutlineInputBorder(
                                borderSide: BorderSide(color: Colors.grey),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                            ),
                            child: Text(
                              provider.clientName,
                              style: const TextStyle(fontSize: 16),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        SizedBox(
                          width: 100, // Fixed width for year
                          child: DropdownButtonFormField<int>(
                            initialValue: provider.selectedYear,
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
                    const SizedBox(height: 8),
                    // Run Time row
                    Row(
                      children: [
                        SizedBox(
                          width: 24, height: 24,
                          child: Checkbox(
                            value: provider.enableTimeWindow,
                            onChanged: provider.isProcessing ? null : (val) => provider.setEnableTimeWindow(val ?? false),
                            visualDensity: VisualDensity.compact,
                            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text('Run Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: 100,
                          child: _buildTimePicker(
                            context,
                            label: 'From',
                            time: provider.runFromTime,
                            enabled: !provider.isProcessing && provider.enableTimeWindow,
                            onPicked: provider.isProcessing ? (time) {} : (time) => provider.setRunFromTime(time),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          width: 100,
                          child: _buildTimePicker(
                            context,
                            label: 'To',
                            time: provider.runToTime,
                            enabled: !provider.isProcessing && provider.enableTimeWindow,
                            onPicked: provider.isProcessing ? (time) {} : (time) => provider.setRunToTime(time),
                          ),
                        ),
                        const SizedBox(width: 16),
                        const VerticalDivider(width: 1, thickness: 1),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 2,
                            children: [
                              for (final entry in {1: 'Mon', 2: 'Tue', 3: 'Wed', 4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun'}.entries)
                                FilterChip(
                                  label: Text(entry.value, style: const TextStyle(fontSize: 11)),
                                  selected: provider.runDays[entry.key] ?? false,
                                  onSelected: provider.isProcessing
                                      ? null
                                      : (val) => provider.setRunDay(entry.key, val),
                                  visualDensity: VisualDensity.compact,
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // When Complete row
                    Row(
                      children: [
                        const SizedBox(width: 30),
                        const Text('When Complete', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 12),
                        ToggleButtons(
                          isSelected: [
                            provider.onCompletionAction == 'pause',
                            provider.onCompletionAction == 'stop',
                          ],
                          onPressed: provider.isProcessing ? null : (index) {
                            provider.setOnCompletionAction(index == 0 ? 'pause' : 'stop');
                          },
                          borderRadius: BorderRadius.circular(6),
                          constraints: const BoxConstraints(minHeight: 30, minWidth: 80),
                          textStyle: const TextStyle(fontSize: 12),
                          children: const [
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.pause_circle_outline, size: 16),
                                  SizedBox(width: 4),
                                  Text('Pause'),
                                ],
                              ),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 8),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.stop_circle_outlined, size: 16),
                                  SizedBox(width: 4),
                                  Text('Stop'),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        Text(
                          provider.onCompletionAction == 'pause'
                              ? 'Will re-run at the next start time'
                              : 'Will stop after completion',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 6),

            // Actions, Status, and Stats – all on one compact row
            Row(
              children: [
                if (!provider.isProcessing) ...[
                  ElevatedButton.icon(
                    onPressed:
                        (provider.sourcePath != null &&
                            provider.destPath != null)
                        ? provider.startProcessing
                        : null,
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('Start'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
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
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Clear Progress'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                    ),
                  ),
                ] else
                  ElevatedButton.icon(
                    onPressed: provider.stop,
                    icon: const Icon(Icons.stop, size: 18),
                    label: const Text('Stop'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                  ),
                const SizedBox(width: 16),
                // Status
                Expanded(
                  child: Text(
                    provider.currentStatus,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                // Stats as compact inline badges
                _buildSmallStatBadge('Moved', provider.filesMoved.toString(), Colors.green, Icons.check_circle),
                const SizedBox(width: 8),
                _buildSmallStatBadge('Errors', provider.errors.toString(), Colors.red, Icons.error),
              ],
            ),
            const SizedBox(height: 6),

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
                        color: Colors.greenAccent,
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

  Widget _buildSmallStatBadge(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 6),
          Text(
            '$title: $value',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
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
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            suffixIcon: const Icon(Icons.access_time, size: 16),
          ),
          child: Text(time.format(context)),
        ),
      ),
    );
  }
}

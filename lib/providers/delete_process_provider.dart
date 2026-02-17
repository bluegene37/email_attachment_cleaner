import 'dart:async';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

class DeleteProcessProvider with ChangeNotifier {
  final Logger _log = Logger('DeleteProcessProvider');

  String? targetPath;
  bool isProcessing = false;
  List<String> logs = [];
  String currentStatus = 'Idle';
  int deletedCount = 0;
  int errorCount = 0;
  bool _stopRequested = false;
  Timer? _refreshTimer;

  int selectedYear = 2025;
  List<String> validMonths = ['Jan'];

  List<String> allMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  List<int> get availableYears {
    List<int> years = [];
    int currentYear = DateTime.now().year;
    for (int i = 2010; i <= currentYear + 5; i++) {
      years.add(i);
    }
    return years.reversed.toList();
  }

  void setYear(int year) {
    selectedYear = year;
    notifyListeners();
  }

  void toggleMonth(String month) {
    if (validMonths.contains(month)) {
      validMonths.remove(month);
    } else {
      validMonths.add(month);
    }
    notifyListeners();
  }

  void _startTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 200), (timer) {
      notifyListeners();
    });
  }

  void _stopTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    notifyListeners(); // Ensure final state is updated
  }

  void _addLog(String message) {
    final timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
    logs.insert(0, '[$timestamp] $message');
    if (logs.length > 1000) logs.removeLast();
    // notifyListeners();
  }

  Future<void> pickTarget() async {
    final path = await getDirectoryPath();
    if (path != null) {
      targetPath = path;
      _addLog('Target selected: $targetPath');
      notifyListeners();
    }
  }

  void stop() {
    _stopRequested = true;
    currentStatus = 'Stopping...';
    notifyListeners();
  }

  void clearLogs() {
    logs.clear();
    deletedCount = 0;
    errorCount = 0;
    currentStatus = 'Idle';
    notifyListeners();
  }

  Future<void> deleteFiles() async {
    if (targetPath == null) {
      _addLog('Error: No target directory selected.');
      return;
    }

    if (validMonths.isEmpty) {
      _addLog('Error: No months selected. Please select at least one month.');
      return;
    }

    isProcessing = true;
    _stopRequested = false;
    deletedCount = 0;
    errorCount = 0;
    currentStatus = 'Starting deletion...';
    notifyListeners();

    _addLog('Starting deletion in: $targetPath');
    _addLog('Filter: Year $selectedYear, Months $validMonths');

    _startTimer();

    try {
      final targetDir = Directory(targetPath!);
      if (!await targetDir.exists()) {
        _addLog('Error: Target directory does not exist.');
        return;
      }

      await _processDirectory(targetDir);

      if (_stopRequested) {
        _addLog('Stopped by user.');
      } else {
        _addLog('Deletion completed.');
      }
    } catch (e, stack) {
      _addLog('Critical Error: $e');
      _log.severe(e, stack);
    } finally {
      isProcessing = false;
      currentStatus = 'Idle';
      _stopTimer();
    }
  }

  Future<void> _processDirectory(Directory dir) async {
    try {
      // Process files first
      await for (final entity in dir.list(
        recursive:
            false, // We will recurse manually to handle post-order directory deletion
        followLinks: false,
      )) {
        if (_stopRequested) return;

        if (entity is File) {
          await _checkAndDeleteFile(entity);
        } else if (entity is Directory) {
          await _processDirectory(entity);
        }
      }

      // Check if directory is empty after processing children
      if (dir.path != targetPath) {
        // Don't delete the root target
        if (await _isEmpty(dir)) {
          try {
            await dir.delete();
            _addLog('Deleted empty folder: ${p.basename(dir.path)}');
          } catch (e) {
            _addLog('Failed to delete folder ${p.basename(dir.path)}: $e');
          }
        }
      }
    } catch (e) {
      _addLog('Error scanning directory: $e');
      errorCount++;
    }
  }

  Future<bool> _isEmpty(Directory dir) async {
    try {
      return await dir.list().isEmpty;
    } catch (e) {
      return false;
    }
  }

  Future<void> _checkAndDeleteFile(File file) async {
    try {
      FileStat stats = await file.stat();
      DateTime modified = stats.modified;

      String yearStr = DateFormat('yyyy').format(modified);
      String monthStr = DateFormat('MMM').format(modified);

      // Check filters
      if (int.parse(yearStr) == selectedYear &&
          validMonths.contains(monthStr)) {
        await _deleteFile(file);
      }
    } catch (e) {
      _addLog('Error checking ${p.basename(file.path)}: $e');
      errorCount++;
    }
  }

  // Previous simple _deleteFile was calling notifyListeners too often?
  // Maybe just keep it simple.
  Future<void> _deleteFile(File file) async {
    try {
      await file.delete();
      deletedCount++;
      _addLog('Deleted: ${p.basename(file.path)}');
      // notifyListeners();
    } catch (e) {
      _addLog('Failed to delete ${p.basename(file.path)}: $e');
      errorCount++;
    }
  }
}

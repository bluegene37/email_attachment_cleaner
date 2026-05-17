import 'dart:async';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/file_logger.dart';

class CountFilesProvider with ChangeNotifier {
  final FileLogger _fileLogger = FileLogger();

  String? targetPath;
  bool isCounting = false;
  List<String> logs = [];
  String currentStatus = 'Idle';
  int totalFiles = 0;
  int totalFolders = 0;
  int errors = 0;
  bool _stopRequested = false;
  Timer? _refreshTimer;

  CountFilesProvider() {
    _loadSettings();
  }

  void _addLog(String message) {
    final timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
    logs.insert(0, '[$timestamp] $message');
    if (logs.length > 1000) logs.removeLast();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    targetPath = prefs.getString('count_targetPath');
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (targetPath != null) {
      await prefs.setString('count_targetPath', targetPath!);
    }
  }

  Future<void> pickTarget() async {
    final path = await getDirectoryPath(initialDirectory: targetPath);
    if (path != null) {
      targetPath = path;
      _saveSettings();
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
    totalFiles = 0;
    totalFolders = 0;
    errors = 0;
    currentStatus = 'Idle';
    notifyListeners();
  }

  void _startTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 200), (_) {
      notifyListeners();
    });
  }

  void _stopTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    notifyListeners();
  }

  Future<void> startCounting() async {
    if (targetPath == null) {
      _addLog('Error: No target directory selected.');
      return;
    }

    isCounting = true;
    _stopRequested = false;
    totalFiles = 0;
    totalFolders = 0;
    errors = 0;
    currentStatus = 'Counting...';
    notifyListeners();

    _addLog('Starting file count in: $targetPath');

    await _fileLogger.logRunStart(
      operation: 'Count',
      targetPath: targetPath,
    );

    _startTimer();

    try {
      final targetDir = Directory(targetPath!);
      if (!await targetDir.exists()) {
        _addLog('Error: Target directory does not exist.');
        await _fileLogger.error('Count', 'Target directory does not exist: $targetPath');
        return;
      }

      await _countDirectory(targetDir);

      if (_stopRequested) {
        _addLog('Stopped by user.');
        _addLog('Count so far — Files: $totalFiles, Folders: $totalFolders');
      } else {
        _addLog('Count completed.');
        _addLog('Total Files: $totalFiles');
        _addLog('Total Folders: $totalFolders');
      }

      await _fileLogger.info('Count', 'Total Files: $totalFiles');
      await _fileLogger.info('Count', 'Total Folders: $totalFolders');
      if (errors > 0) {
        await _fileLogger.error('Count', 'Errors encountered: $errors');
      }
    } catch (e) {
      _addLog('Critical Error: $e');
      await _fileLogger.error('Count', 'Critical Error: $e');
    } finally {
      await _fileLogger.logRunEnd(
        operation: 'Count',
        filesProcessed: totalFiles,
        errors: errors,
        wasStopped: _stopRequested,
      );
      isCounting = false;
      currentStatus = 'Idle';
      _stopTimer();
    }
  }

  Future<void> _countDirectory(Directory dir) async {
    try {
      await for (final entity in dir.list(recursive: false, followLinks: false)) {
        if (_stopRequested) return;

        if (entity is File) {
          totalFiles++;
        } else if (entity is Directory) {
          totalFolders++;
          currentStatus = 'Scanning: ${entity.path}';
          await _countDirectory(entity);
        }
      }
    } catch (e) {
      _addLog('Error accessing: ${dir.path} — $e');
      await _fileLogger.error('Count', 'Error accessing: ${dir.path} — $e');
      errors++;
    }
  }
}

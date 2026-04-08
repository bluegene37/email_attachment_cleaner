import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/file_logger.dart';

/// Message sent FROM the background isolate TO the main isolate.
class _IsolateProgress {
  final String? logMessage;
  final String? status;
  final int filesCopied;
  final int filesSkipped;
  final int filesAlreadyExist;
  final int errors;
  final bool done;
  final String? criticalError;

  _IsolateProgress({
    this.logMessage,
    this.status,
    this.filesCopied = 0,
    this.filesSkipped = 0,
    this.filesAlreadyExist = 0,
    this.errors = 0,
    this.done = false,
    this.criticalError,
  });
}

/// Parameters sent TO the background isolate.
class _IsolateParams {
  final String sourcePath;
  final String destPath;
  final bool enableDateRange;
  final int fromEpochMs;
  final int toEpochMs;
  final SendPort sendPort;

  _IsolateParams({
    required this.sourcePath,
    required this.destPath,
    required this.enableDateRange,
    required this.fromEpochMs,
    required this.toEpochMs,
    required this.sendPort,
  });
}

/// Mutable counters passed through the recursive walk inside the isolate.
class _CountState {
  int filesCopied = 0;
  int filesSkipped = 0;
  int filesAlreadyExist = 0;
  int errors = 0;
  int directoriesScanned = 0;
}

class _CopyTask {
  final File source;
  final String destFilePath;

  _CopyTask(this.source, this.destFilePath);
}


class CopyFilesProvider with ChangeNotifier {
  final Logger _log = Logger('CopyFilesProvider');
  final FileLogger _fileLogger = FileLogger();

  // State
  String? sourcePath;
  String? destPath;

  // Date range filter (from/to inclusive)
  bool enableDateRange = false;
  DateTime fromDate = DateTime(2025, 1, 1);
  DateTime toDate = DateTime(2025, 1, 31);

  // Time Schedule Feature
  bool enableTimeWindow = false;
  TimeOfDay runFromTime = const TimeOfDay(hour: 0, minute: 0);
  TimeOfDay runToTime = const TimeOfDay(hour: 6, minute: 0);

  bool isProcessing = false;
  List<String> logs = [];
  String currentStatus = 'Idle';

  // Stats
  int filesCopied = 0;
  int filesSkipped = 0;
  int errors = 0;

  Isolate? _workerIsolate;
  ReceivePort? _receivePort;
  StreamSubscription? _progressSubscription;
  
  // Pause/Schedule State
  Capability? _pauseCapability;
  bool isPaused = false;
  Timer? _scheduleTimer;

  CopyFilesProvider() {
    _loadSettings();
  }

  void _addLog(String message) {
    final timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
    logs.insert(0, '[$timestamp] $message');
    if (logs.length > 1000) logs.removeLast();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    sourcePath = prefs.getString('copy_sourcePath');
    destPath = prefs.getString('copy_destPath');

    final fromMs = prefs.getInt('copy_fromDateMs');
    final toMs = prefs.getInt('copy_toDateMs');
    if (fromMs != null) {
      fromDate = DateTime.fromMillisecondsSinceEpoch(fromMs);
    }
    if (toMs != null) {
      toDate = DateTime.fromMillisecondsSinceEpoch(toMs);
    }
    
    enableDateRange = prefs.getBool('copy_enableDateRange') ?? false;

    enableTimeWindow = prefs.getBool('copy_enableTimeWindow') ?? false;
    
    final fromHour = prefs.getInt('copy_runFromHour');
    final fromMinute = prefs.getInt('copy_runFromMinute');
    if (fromHour != null && fromMinute != null) {
      runFromTime = TimeOfDay(hour: fromHour, minute: fromMinute);
    }

    final toHour = prefs.getInt('copy_runToHour');
    final toMinute = prefs.getInt('copy_runToMinute');
    if (toHour != null && toMinute != null) {
      runToTime = TimeOfDay(hour: toHour, minute: toMinute);
    }

    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (sourcePath != null) {
      await prefs.setString('copy_sourcePath', sourcePath!);
    }
    if (destPath != null) {
      await prefs.setString('copy_destPath', destPath!);
    }
    await prefs.setInt('copy_fromDateMs', fromDate.millisecondsSinceEpoch);
    await prefs.setInt('copy_toDateMs', toDate.millisecondsSinceEpoch);
    await prefs.setBool('copy_enableDateRange', enableDateRange);

    await prefs.setBool('copy_enableTimeWindow', enableTimeWindow);
    await prefs.setInt('copy_runFromHour', runFromTime.hour);
    await prefs.setInt('copy_runFromMinute', runFromTime.minute);
    await prefs.setInt('copy_runToHour', runToTime.hour);
    await prefs.setInt('copy_runToMinute', runToTime.minute);
  }

  void setSourcePath(String? path) {
    sourcePath = path;
    _saveSettings();
    notifyListeners();
  }

  void setDestPath(String? path) {
    destPath = path;
    _saveSettings();
    notifyListeners();
  }

  void setEnableDateRange(bool val) {
    enableDateRange = val;
    _saveSettings();
    notifyListeners();
  }

  void setFromDate(DateTime date) {
    fromDate = date;
    if (fromDate.isAfter(toDate)) toDate = fromDate;
    _saveSettings();
    notifyListeners();
  }

  void setToDate(DateTime date) {
    toDate = date;
    if (toDate.isBefore(fromDate)) fromDate = toDate;
    _saveSettings();
    notifyListeners();
  }

  void setEnableTimeWindow(bool val) {
    enableTimeWindow = val;
    _saveSettings();
    notifyListeners();
    _evaluateSchedule();
  }

  void setRunFromTime(TimeOfDay time) {
    runFromTime = time;
    _saveSettings();
    notifyListeners();
    _evaluateSchedule();
  }

  void setRunToTime(TimeOfDay time) {
    runToTime = time;
    _saveSettings();
    notifyListeners();
    _evaluateSchedule();
  }

  Future<void> pickSource() async {
    final path = await getDirectoryPath();
    if (path != null) setSourcePath(path);
  }

  Future<void> pickDest() async {
    final path = await getDirectoryPath();
    if (path != null) setDestPath(path);
  }

  void stop() {
    _workerIsolate?.kill(priority: Isolate.immediate);
    _workerIsolate = null;
    _progressSubscription?.cancel();
    _progressSubscription = null;
    _receivePort?.close();
    _receivePort = null;
    _scheduleTimer?.cancel();
    _scheduleTimer = null;
    
    _pauseCapability = null;
    isPaused = false;
    currentStatus = 'Stopped by user.';
    _addLog('Stopped by user.');
    isProcessing = false;
    notifyListeners();

    _fileLogger.logRunEnd(
      operation: 'Copy',
      filesProcessed: filesCopied,
      errors: errors,
      wasStopped: true,
    );
  }

  bool _isCurrentlyInTimeWindow() {
    if (!enableTimeWindow) return true;
    final now = TimeOfDay.now();
    double nowVal = now.hour + now.minute / 60.0;
    double fromVal = runFromTime.hour + runFromTime.minute / 60.0;
    double toVal = runToTime.hour + runToTime.minute / 60.0;

    if (fromVal < toVal) {
      return nowVal >= fromVal && nowVal < toVal;
    } else if (fromVal > toVal) {
      // Midnight crossover
      return nowVal >= fromVal || nowVal < toVal;
    } else {
      // from == to, assume open window for safety or disabled. Let's say false unless exact minute tick.
      return false;
    }
  }

  void _evaluateSchedule() {
    if (!isProcessing || _workerIsolate == null) return;
    
    bool inWindow = _isCurrentlyInTimeWindow();
    
    if (inWindow && isPaused) {
      if (_pauseCapability != null) {
        _workerIsolate?.resume(_pauseCapability!);
        isPaused = false;
        currentStatus = 'Copying...';
        _addLog('Time window reached. Resuming copy...');
        notifyListeners();
      }
    } else if (!inWindow && !isPaused) {
      _pauseCapability = _workerIsolate?.pause();
      isPaused = true;
      currentStatus = 'Waiting for time window...';
      _addLog('Outside allowed time window. Paused until next run window.');
      notifyListeners();
    }
  }

  static Future<void> _processBatch(
    List<_CopyTask> batch,
    _IsolateParams params,
    _CountState counts,
  ) async {
    final futures = batch.map((task) async {
      try {
        await task.source.copy(task.destFilePath);
        counts.filesCopied++;

        if (counts.filesCopied % 10 == 0) {
          params.sendPort.send(_IsolateProgress(
            logMessage: 'Copied: ${p.basename(task.source.path)}',
            status: 'Copying: ${p.basename(task.source.path)}',
            filesCopied: counts.filesCopied,
            filesSkipped: counts.filesSkipped,
            filesAlreadyExist: counts.filesAlreadyExist,
            errors: counts.errors,
          ));
        }
      } catch (e) {
        counts.errors++;
        params.sendPort.send(_IsolateProgress(
          logMessage: 'Failed to copy ${p.basename(task.source.path)}: $e',
          errors: counts.errors,
          filesCopied: counts.filesCopied,
          filesSkipped: counts.filesSkipped,
          filesAlreadyExist: counts.filesAlreadyExist,
        ));
      }
    });

    await Future.wait(futures);
  }

  /// Manual recursive walk using async lists for maximum performance.
  static Future<void> _walkAndCopy(
    Directory dir,
    _IsolateParams params,
    _CountState counts,
    Set<String> createdDirs,
    List<_CopyTask> batch,
  ) async {
    List<FileSystemEntity> entities;
    try {
      entities = await dir.list(followLinks: false).toList();
    } catch (e) {
      counts.errors++;
      params.sendPort.send(_IsolateProgress(
        logMessage: 'Cannot access: ${dir.path} ($e)',
        errors: counts.errors,
        filesCopied: counts.filesCopied,
        filesSkipped: counts.filesSkipped,
        filesAlreadyExist: counts.filesAlreadyExist,
      ));
      return; 
    }

    counts.directoriesScanned++;

    if (counts.directoriesScanned % 20 == 0) {
      params.sendPort.send(_IsolateProgress(
        status: 'Scanning: ${p.basename(dir.path)}',
        filesCopied: counts.filesCopied,
        filesSkipped: counts.filesSkipped,
        filesAlreadyExist: counts.filesAlreadyExist,
        errors: counts.errors,
      ));
    }

    final fromDate = DateTime.fromMillisecondsSinceEpoch(params.fromEpochMs);
    final toDate = DateTime.fromMillisecondsSinceEpoch(params.toEpochMs);

    final files = entities.whereType<File>().toList();
    
    // Process files in concurrency batches of 50
    for (var i = 0; i < files.length; i += 50) {
      final chunk = files.skip(i).take(50);
      
      final futures = chunk.map((entity) async {
        try {
          bool withinDateRange = true;
          int sourceSize = -1;

          if (params.enableDateRange) {
            FileStat stats = await entity.stat();
            sourceSize = stats.size;
            DateTime modified = stats.modified;
            
            final fileDate = DateTime(modified.year, modified.month, modified.day);
            final from = DateTime(fromDate.year, fromDate.month, fromDate.day);
            final to = DateTime(toDate.year, toDate.month, toDate.day);
            if (fileDate.isBefore(from) || fileDate.isAfter(to)) {
              withinDateRange = false;
            }
          }

          if (withinDateRange) {
            String relativePath = p.relative(entity.parent.path, from: params.sourcePath);
            String destDir = p.join(params.destPath, relativePath);
            String destFilePath = p.join(destDir, p.basename(entity.path));
            
            bool shouldCopy = true;
            
            if (sourceSize == -1) {
              sourceSize = await entity.length();
            }

            File destFile = File(destFilePath);
            FileStat destStat = await destFile.stat();
            if (destStat.type != FileSystemEntityType.notFound && destStat.size == sourceSize) {
                shouldCopy = false;
            }

            if (shouldCopy) {
              if (!createdDirs.contains(destDir)) {
                createdDirs.add(destDir);
                await Directory(destDir).create(recursive: true);
              }
              batch.add(_CopyTask(entity, destFilePath));
            } else {
              counts.filesAlreadyExist++;
            }
          } else {
            counts.filesSkipped++;
          }
        } catch (e) {
          counts.errors++;
          params.sendPort.send(_IsolateProgress(
            logMessage: 'Failed to inspect/copy ${p.basename(entity.path)}: $e',
            errors: counts.errors,
            filesCopied: counts.filesCopied,
            filesSkipped: counts.filesSkipped,
            filesAlreadyExist: counts.filesAlreadyExist,
          ));
        }
      });

      await Future.wait(futures);

      if (batch.length >= 20) {
         final tasksToRun = List<_CopyTask>.from(batch);
         batch.clear();
         await _processBatch(tasksToRun, params, counts);
         await Future.delayed(Duration.zero);
      }
    }

    // Then recurse into subdirectories
    for (final entity in entities) {
      if (entity is Directory) {
        await _walkAndCopy(entity, params, counts, createdDirs, batch);
      }
    }
  }

  /// Top-level isolate entry point.
  static Future<void> _copyWorker(_IsolateParams params) async {
    final counts = _CountState();
    final createdDirs = <String>{};
    final batch = <_CopyTask>[];

    try {
      final sourceDir = Directory(params.sourcePath);
      if (!sourceDir.existsSync()) {
        params.sendPort.send(_IsolateProgress(
          logMessage: 'Error: Source directory does not exist.',
          done: true,
          errors: 1,
        ));
        return;
      }

      await _walkAndCopy(sourceDir, params, counts, createdDirs, batch);
      
      // Process remaining tasks in the final batch
      if (batch.isNotEmpty) {
        await _processBatch(batch, params, counts);
        batch.clear();
      }

      params.sendPort.send(_IsolateProgress(
        logMessage: 'Copy completed successfully.',
        status: 'Done',
        done: true,
        filesCopied: counts.filesCopied,
        filesSkipped: counts.filesSkipped,
        filesAlreadyExist: counts.filesAlreadyExist,
        errors: counts.errors,
      ));
    } catch (e) {
      params.sendPort.send(_IsolateProgress(
        logMessage: 'Critical Error: $e',
        criticalError: e.toString(),
        done: true,
        filesCopied: counts.filesCopied,
        filesSkipped: counts.filesSkipped,
        filesAlreadyExist: counts.filesAlreadyExist,
        errors: counts.errors,
      ));
    }
  }

  Future<void> startProcessing() async {
    if (sourcePath == null || destPath == null) {
      _addLog('Error: Source or Destination not selected.');
      await _fileLogger.error('Copy', 'Source or Destination not selected.');
      return;
    }

    isProcessing = true;
    currentStatus = 'Scanning...';
    filesCopied = 0;
    filesSkipped = 0;
    errors = 0;
    isPaused = false;
    _pauseCapability = null;
    notifyListeners();

    final dateFormat = DateFormat('dd/MM/yyyy');
    _addLog('Starting copy process...');
    _addLog('Source: $sourcePath');
    _addLog('Destination: $destPath');
    _addLog('Date range: ${dateFormat.format(fromDate)} — ${dateFormat.format(toDate)}');
    
    if (enableTimeWindow) {
      final String formattedFrom = '${runFromTime.hour.toString().padLeft(2, '0')}:${runFromTime.minute.toString().padLeft(2, '0')}';
      final String formattedTo = '${runToTime.hour.toString().padLeft(2, '0')}:${runToTime.minute.toString().padLeft(2, '0')}';
      _addLog('Run window bounds: $formattedFrom to $formattedTo');
    }

    await _fileLogger.logRunStart(
      operation: 'Copy',
      sourcePath: sourcePath,
      destPath: destPath,
    );

    // Create a ReceivePort and store it so we can close it on stop
    _receivePort = ReceivePort();

    final params = _IsolateParams(
      sourcePath: sourcePath!,
      destPath: destPath!,
      enableDateRange: enableDateRange,
      fromEpochMs: fromDate.millisecondsSinceEpoch,
      toEpochMs: toDate.millisecondsSinceEpoch,
      sendPort: _receivePort!.sendPort,
    );

    // Spawn the isolate
    _workerIsolate = await Isolate.spawn(_copyWorker, params);
    
    // Evaluate initial schedule state (this will pause it immediately if outside window)
    _evaluateSchedule();

    // Setup periodic schedule evaluation
    _scheduleTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _evaluateSchedule();
    });

    // Listen for progress from the isolate
    _progressSubscription = _receivePort!.listen((message) async {
      if (message is _IsolateProgress) {
        // Update stats
        filesCopied = message.filesCopied;
        filesSkipped = message.filesSkipped;
        errors = message.errors;

        if (message.status != null && !isPaused) {
          currentStatus = message.status!;
        }

        if (message.logMessage != null) {
          _addLog(message.logMessage!);
        }

        if (message.criticalError != null) {
          _log.severe('Isolate critical error: ${message.criticalError}');
          await _fileLogger.error(
              'Copy', 'Critical Error: ${message.criticalError}');
        }

        if (message.done) {
          // Log final stats
          _addLog('Files newly copied: ${message.filesCopied}');
          _addLog('Files skipped (already exist): ${message.filesAlreadyExist}');
          _addLog('Files skipped (outside date filter): ${message.filesSkipped}');
          _addLog('Errors: ${message.errors}');

          await _fileLogger.logRunEnd(
            operation: 'Copy',
            filesProcessed: filesCopied,
            errors: errors,
            wasStopped: false,
          );

          isProcessing = false;
          currentStatus = 'Idle';
          _workerIsolate = null;
          _progressSubscription?.cancel();
          _progressSubscription = null;
          _receivePort?.close();
          _receivePort = null;
          _scheduleTimer?.cancel();
          _scheduleTimer = null;
        }

        notifyListeners();
      }
    });
  }
}

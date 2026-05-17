import 'dart:io';
import 'package:intl/intl.dart';

/// Centralized file logger that writes logs to C:\temp\file transfer\
/// Log files are named by the run start date-time (e.g., 2026-04-07_14-30-00_Copy.log).
/// Each run gets its own log file, even if a run spans multiple days.
class FileLogger {
  static final FileLogger _instance = FileLogger._internal();
  factory FileLogger() => _instance;
  FileLogger._internal();

  static const String _logDirectory = r'C:\temp\file transfer';

  /// Tracks the log file for each active operation (keyed by operation/source name).
  /// Set when logRunStart is called, cleared when logRunEnd is called.
  final Map<String, File> _activeRunFiles = {};

  /// Ensures the log directory exists.
  Future<void> _ensureDirectory() async {
    final dir = Directory(_logDirectory);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// Gets the log file for the given operation source.
  /// If a run is active (started via logRunStart), uses that run's file.
  /// Otherwise, creates a new file based on the current date-time.
  File _getLogFile(String source) {
    if (_activeRunFiles.containsKey(source)) {
      return _activeRunFiles[source]!;
    }
    // Fallback for logs outside of a run (shouldn't normally happen)
    return _createRunFile(source);
  }

  /// Creates a new log file named with the current date-time and source.
  File _createRunFile(String source) {
    final dateTimeStr = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
    // Safe-guard source string just in case to be filesystem friendly
    final safeSource = source.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    return File('$_logDirectory\\${dateTimeStr}_$safeSource.log');
  }

  /// Writes a log line with timestamp and level.
  Future<void> _write(String level, String source, String message) async {
    try {
      await _ensureDirectory();
      final file = _getLogFile(source);
      final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
      final logLine = '[$timestamp] [$level] [$source] $message\r\n';
      await file.writeAsString(logLine, mode: FileMode.append);
    } catch (e) {
      // Silently fail — don't crash the app if logging fails
    }
  }

  /// Log an informational message.
  Future<void> info(String source, String message) async {
    await _write('INFO', source, message);
  }

  /// Log an error message.
  Future<void> error(String source, String message) async {
    await _write('ERROR', source, message);
  }

  /// Log the start of a run with operation details.
  /// Creates a new log file for this run, named with the current date-time.
  Future<void> logRunStart({
    required String operation,
    String? sourcePath,
    String? destPath,
    String? targetPath,
    int? year,
    List<String>? months,
  }) async {
    // Create a new log file for this run
    _activeRunFiles[operation] = _createRunFile(operation);

    await info(operation, '========== RUN STARTED ==========');
    if (sourcePath != null) await info(operation, 'Source: $sourcePath');
    if (destPath != null) await info(operation, 'Destination: $destPath');
    if (targetPath != null) await info(operation, 'Target: $targetPath');
    if (year != null) await info(operation, 'Year filter: $year');
    if (months != null) await info(operation, 'Month filter: $months');
  }

  /// Log the end of a run with summary stats.
  Future<void> logRunEnd({
    required String operation,
    required int filesProcessed,
    required int errors,
    required bool wasStopped,
  }) async {
    await info(operation, '---------- RUN SUMMARY ----------');
    await info(operation, 'Files processed: $filesProcessed');
    if (errors > 0) {
      await error(operation, 'Errors encountered: $errors');
    } else {
      await info(operation, 'Errors: 0');
    }
    if (wasStopped) {
      await info(operation, 'Status: STOPPED BY USER');
    } else {
      await info(operation, 'Status: COMPLETED SUCCESSFULLY');
    }
    await info(operation, '========== RUN ENDED ============');

    // Clear the active run file so the next run gets a fresh file
    _activeRunFiles.remove(operation);
  }
}

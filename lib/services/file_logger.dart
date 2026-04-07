import 'dart:io';
import 'package:intl/intl.dart';

/// Centralized file logger that writes logs to C:\temp\file transfer\
/// Log files are named by date (e.g., 2026-04-07.log).
class FileLogger {
  static final FileLogger _instance = FileLogger._internal();
  factory FileLogger() => _instance;
  FileLogger._internal();

  static const String _logDirectory = r'C:\temp\file transfer';

  /// Ensures the log directory exists.
  Future<void> _ensureDirectory() async {
    final dir = Directory(_logDirectory);
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
  }

  /// Gets the log file for today's date and the given operation source.
  File _getLogFile(String source) {
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    // Safe-guard source string just in case to be filesystem friendly
    final safeSource = source.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_');
    return File('$_logDirectory\\${dateStr}_$safeSource.log');
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
  Future<void> logRunStart({
    required String operation,
    String? sourcePath,
    String? destPath,
    String? targetPath,
    int? year,
    List<String>? months,
  }) async {
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
  }
}

import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

class FileProcessProvider with ChangeNotifier {
  final Logger _log = Logger('FileProcessProvider');

  // State
  String? sourcePath;
  String? destPath;
  String clientName = 'WaterBrothers'; // Default from script
  int selectedYear = 2025;
  List<String> validMonths = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
  ];
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

  List<String> availableClients = [
    'WaterBrothers',
    'FRP',
    'Chips',
    'ETS-East',
    'LPS',
    'IGPest',
  ];

  List<int> get availableYears {
    List<int> years = [];
    int currentYear = DateTime.now().year;
    for (int i = 2010; i <= currentYear + 5; i++) {
      years.add(i);
    }
    return years.reversed.toList();
  }

  bool isProcessing = false;
  List<String> logs = [];
  String currentStatus = 'Idle';

  // Resume state
  String? lastProcessedParent;
  String? lastProcessedChild;

  // Stats
  int filesMoved = 0;
  int errors = 0;

  bool _stopRequested = false;

  FileProcessProvider() {
    _loadSettings();
  }

  void _addLog(String message) {
    final timestamp = DateFormat('HH:mm:ss').format(DateTime.now());
    logs.insert(0, '[$timestamp] $message');
    if (logs.length > 1000) logs.removeLast();
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    sourcePath = prefs.getString('sourcePath');
    destPath = prefs.getString('destPath');
    clientName = prefs.getString('clientName') ?? 'WaterBrothers';
    selectedYear = prefs.getInt('selectedYear') ?? 2025;
    // validMonths loading could be added if we want to persist that selection
    lastProcessedParent = prefs.getString('lastProcessedParent');
    lastProcessedChild = prefs.getString('lastProcessedChild');
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (sourcePath != null) await prefs.setString('sourcePath', sourcePath!);
    if (destPath != null) await prefs.setString('destPath', destPath!);
    await prefs.setString('clientName', clientName);
    await prefs.setInt('selectedYear', selectedYear);
  }

  Future<void> _saveProgress(String parent, String child) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('lastProcessedParent', parent);
    await prefs.setString('lastProcessedChild', child);
    lastProcessedParent = parent;
    lastProcessedChild = child;
  }

  Future<void> clearProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('lastProcessedParent');
    await prefs.remove('lastProcessedChild');
    lastProcessedParent = null;
    lastProcessedChild = null;
    _addLog('Progress cleared.');
    notifyListeners();
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

  void setClientName(String name) {
    clientName = name;
    _saveSettings();
    notifyListeners();
  }

  void setYear(int year) {
    selectedYear = year;
    _saveSettings();
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

  Future<void> pickSource() async {
    final path = await getDirectoryPath();
    if (path != null) setSourcePath(path);
  }

  Future<void> pickDest() async {
    final path = await getDirectoryPath();
    if (path != null) setDestPath(path);
  }

  void stop() {
    _stopRequested = true;
    currentStatus = 'Stopping...';
    notifyListeners();
  }

  Future<void> startProcessing() async {
    if (sourcePath == null || destPath == null) {
      _addLog('Error: Source or Destination not selected.');
      return;
    }

    isProcessing = true;
    _stopRequested = false;
    filesMoved = 0;
    errors = 0;
    notifyListeners();

    _addLog('Starting processing...');
    _addLog('Source: $sourcePath');
    _addLog('Destination: $destPath');
    _addLog('Filter: Year $selectedYear, Months $validMonths');

    if (lastProcessedParent != null) {
      _addLog(
        'Resuming from Parent: [$lastProcessedParent], Child: [$lastProcessedChild]',
      );
    }

    try {
      final sourceDir = Directory(sourcePath!);
      if (!await sourceDir.exists()) {
        _addLog('Error: Source directory does not exist.');
        return;
      }

      await _processDirectory(sourceDir);

      if (_stopRequested) {
        _addLog('Stopped by user.');
      } else {
        _addLog('Completed successfully.');
        // Optionally clear progress on full completion
        // await clearProgress();
      }
    } catch (e, stack) {
      _addLog('Critical Error: $e');
      _log.severe(e, stack);
    } finally {
      isProcessing = false;
      currentStatus = 'Idle';
      notifyListeners();
    }
  }

  Future<void> _processDirectory(Directory rootDir) async {
    bool skippingParents = lastProcessedParent != null;

    // Sort directories to ensure consistent order for resuming
    List<FileSystemEntity> parentEntities = rootDir
        .listSync()
        .whereType<Directory>()
        .toList();
    parentEntities.sort(
      (a, b) => p.basename(a.path).compareTo(p.basename(b.path)),
    );

    for (var entity in parentEntities) {
      if (_stopRequested) return;
      if (entity is! Directory) continue;

      String parentName = p.basename(entity.path);

      if (skippingParents) {
        if (parentName == lastProcessedParent) {
          skippingParents =
              false; // Found the parent, stop skipping parents, but might skip children
        } else {
          continue; // Skip this parent
        }
      }

      currentStatus = 'Processing Parent: $parentName';
      notifyListeners();

      await _processSubDirectories(entity, parentName);

      // If we finished a parent completely without stopping, we can checkpoint here or inside the child loop
      // The original script updated start index after the loop.
    }
  }

  Future<void> _processSubDirectories(
    Directory parentDir,
    String parentName,
  ) async {
    bool skippingChildren =
        lastProcessedChild != null && lastProcessedParent == parentName;

    List<FileSystemEntity> childEntities = parentDir
        .listSync()
        .whereType<Directory>()
        .toList();
    childEntities.sort(
      (a, b) => p.basename(a.path).compareTo(p.basename(b.path)),
    );

    for (var entity in childEntities) {
      if (_stopRequested) return;
      if (entity is! Directory) continue;

      String childName = p.basename(entity.path);

      if (skippingChildren) {
        if (childName == lastProcessedChild) {
          skippingChildren = false;
          // We resume *from* this child (re-process it) or *after*?
          // Script logic: "if lNo2 >= startChildIndex". It processes the saved index too.
          // So we should process this one.
        } else {
          continue;
        }
      }

      currentStatus = 'Scanning: $parentName / $childName';
      // Don't notify on every single folder scan to avoid UI stutter, maybe throttle?

      // Save progress *before* processing? Or after?
      // Script saved `startChildIndex = lNo2` at start of loop.
      await _saveProgress(parentName, childName);

      await _processFiles(entity);
    }

    // After finishing all children of this parent, we reset child progress for next parent?
    // Actually we just set the new parent checkpoint.
  }

  Future<void> _processFiles(Directory dir) async {
    // Current logic: "if len(subdirs) == 0".
    // The script traverses `for path, subdirs, files in os.walk(finalorigin2)`.
    // And checks `if len(subdirs) == 0`. It seems it only processes leaf nodes?
    // Let's emulate that: recurse or just listSync(recursive: true)

    // Using listSync(recursive: true) might be memory intensive for huge trees.
    // Better to just walk.

    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (_stopRequested) return;
      if (entity is File) {
        // Check if it's in a leaf dir? The script says `if len(subdirs) == 0`.
        // In `os.walk`, `subdirs` is the list of directories in `path`.
        // This implies we only care about files in directories that have no subdirectories.
        // This is a specific constraint.

        // To check this efficiently:
        Directory fileParent = entity.parent;
        if (await _hasSubdirectories(fileParent)) {
          continue; // Skip files in non-leaf directories
        }

        await _checkAndMoveFile(entity);
      }
    }
  }

  Future<bool> _hasSubdirectories(Directory dir) async {
    // Quick check if dir has any subdir
    try {
      await for (final entity in dir.list(recursive: false)) {
        if (entity is Directory) return true;
      }
    } catch (e) {
      // Access denied or gone
    }
    return false;
  }

  Future<void> _checkAndMoveFile(File file) async {
    try {
      FileStat stats = await file.stat();
      DateTime modified = stats.modified;

      String yearStr = DateFormat('yyyy').format(modified);
      String monthStr = DateFormat('MMM').format(modified); // 'Jan', 'Feb'

      // Check filters
      if (int.parse(yearStr) <= selectedYear &&
          validMonths.contains(monthStr)) {
        // Move it
        await _moveFile(file, yearStr, monthStr);
      }
    } catch (e) {
      _addLog('Error accessing ${file.path}: $e');
      errors++;
    }
  }

  Future<void> _moveFile(File file, String year, String month) async {
    try {
      // Logic from script:
      // initialPath = path.split('\\', 6)  -> based on `origin` depth.
      // filterText = initialPath[6].rsplit('\\', 1)
      // finalFilterText = filterText[0]+'\\'
      // finalMoveTo = os.path.join(moveto,getyear,finalFilterText,filterText[1])

      /*
         Script Origins:
         origin = '\\\\Myflofs2\\apps\\myFloWaterBrothers\\EmailAttachments\\'
         Subdirs1 (Parent) e.g. "SomeParent"
         FinalOrigin = origin/SomeParent
         Subdirs2 (Child) e.g. "SomeChild"
         FinalOrigin2 = origin/SomeParent/SomeChild
         
         Then os.walk(FinalOrigin2).
         Path = origin/SomeParent/SomeChild/.../LeafFolder
         
         split('\\', 6)?
         0: 
         1: 
         2: Myflofs2
         3: apps
         4: myFloWaterBrothers
         5: EmailAttachments
         6: Rest of path starting with Parent/Child/...
         
         This relies heavily on the exact source path structure!
         
         In our generic app, we should probably replicate the *relative path* from Source to the file.
       */

      // Calculate relative path from source
      String relativePath = p.relative(file.parent.path, from: sourcePath!);

      // Construct destination
      // Script: moveto / year / ...
      // Let's use: dest / year / relativePath

      String destDir = p.join(destPath!, year, relativePath);
      String destFilePath = p.join(destDir, p.basename(file.path));

      Directory(destDir).createSync(recursive: true);

      // Move
      // file.renameSync fails across volumes (e.g. C: to Network Share).
      // Safe move: copy then delete.

      file.copySync(destFilePath);
      file.deleteSync();

      _addLog('Moved [$month-$year]: ${p.basename(file.path)}');
      filesMoved++;
      notifyListeners();
    } catch (e) {
      _addLog('Failed to move ${file.path}: $e');
      errors++;
    }
  }
}

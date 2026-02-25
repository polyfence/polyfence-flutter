import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// POLYFENCE EXAMPLE APP - DIAGNOSTIC LOGGER
///
/// PRIVACY-FIRST GUARANTEE:
///   - All logs stay on YOUR device (local storage only)
///   - NO uploads to servers, ever
///   - NO transmission to Polyfence or third parties
///   - NO sharing with other developers
///   - Export only via manual share button (you control it)
///
/// WHAT IT CAPTURES:
///   - Device model (set via --dart-define=DEVICE_NAME)
///   - GPS coordinates (test route locations)
///   - Battery level changes
///   - Network type changes (WiFi/Mobile/None)
///   - Polyfence events and performance metrics
///
/// WHERE LOGS ARE SAVED:
///   Local device: /Documents/polyfence_logs/
///   Access: Via share button or device file browser
///
/// YOUR DATA STAYS ON YOUR DEVICE. PERIOD.

/// Log levels for filtering and prioritization
enum LogLevel {
  debug, // Verbose output, filtered by default
  info, // Important events (default)
  warn, // Warnings and degradations
  error, // Critical failures
}

/// In-memory ring buffer with automatic disk persistence.
/// Captures all diagnostic output for GPS quality testing.
class LogBuffer {
  LogBuffer._();

  static const int _maxEntries = 5000;
  static final Queue<String> _entries = Queue<String>();
  static bool enabled = true;

  // Session tracking
  static String _deviceName = 'unknown_device';
  static DateTime? _sessionStart;
  static int? _startBattery;
  static int? _currentBattery;
  static ConnectivityResult? _startNetwork;
  static ConnectivityResult? _currentNetwork;

  // State change tracking (log changes only, not continuous)
  static int? _lastLoggedBattery;
  static String? _lastLoggedNetwork;
  static int _networkChanges = 0;
  static int _batteryChanges = 0;

  // Auto-save to disk (using absolute counters to handle ring buffer eviction)
  static File? _currentSessionFile;
  static Timer? _flushTimer;
  static int _totalEntriesAdded = 0;
  static int _totalEntriesFlushed = 0;

  // Log level filtering
  static LogLevel minimumLevel = LogLevel.info;

  /// Initialize logger - call once at app startup
  static Future<void> initialize() async {
    if (_sessionStart != null) return; // Already initialized

    _sessionStart = DateTime.now();

    // Detect device name at runtime (more reliable than --dart-define)
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // Use model (e.g., "Pixel 6a", "SM-A135F")
        _deviceName = androidInfo.model.replaceAll(' ', '_');
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        // Use name + model (e.g., "John_iPhone", "iPad")
        final name = iosInfo.name.replaceAll(' ', '_');
        _deviceName = '${name}_${iosInfo.model}';
      }
    } catch (e) {
      _deviceName = 'unknown_device';
      if (kDebugMode) print('[LogBuffer] Device detection failed: $e');
    }

    // Battery tracking
    try {
      final battery = Battery();
      _startBattery = await battery.batteryLevel;
      _currentBattery = _startBattery;
      _lastLoggedBattery = _startBattery;

      // Listen for battery changes
      battery.onBatteryStateChanged.listen((_) {
        _updateBatteryState();
      });

      // Also poll every 60s as backup
      Timer.periodic(const Duration(seconds: 60), (_) {
        _updateBatteryState();
      });
    } catch (e) {
      if (kDebugMode) print('[LogBuffer] Battery init failed: $e');
    }

    // Network tracking
    try {
      final connectivity = Connectivity();
      final result = await connectivity.checkConnectivity();
      _startNetwork = result;
      _currentNetwork = result;
      _lastLoggedNetwork = _connectivityResultToString(result);

      // Listen for network changes
      connectivity.onConnectivityChanged.listen((result) {
        final newType = _connectivityResultToString(result);
        if (newType != _lastLoggedNetwork) {
          _networkChanges++;
          logDebug(
            'Network: $_lastLoggedNetwork → $newType',
            level: LogLevel.info,
          );
          _lastLoggedNetwork = newType;
          _currentNetwork = result;
        }
      });
    } catch (e) {
      if (kDebugMode) print('[LogBuffer] Network init failed: $e');
    }

    // Create session log file
    try {
      final dir = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${dir.path}/polyfence_logs');
      await logsDir.create(recursive: true);

      final timestamp = _sessionStart!
          .toIso8601String()
          .replaceAll(':', '-')
          .split('.')
          .first;

      _currentSessionFile = File(
        '${logsDir.path}/polyfence_${_deviceName}_$timestamp.txt',
      );

      // Write header
      await _currentSessionFile!.writeAsString(await _buildHeader());

      // Start periodic flush (every 30 seconds)
      _flushTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        flush();
      });

      if (kDebugMode) {
        print('[LogBuffer] Session file: ${_currentSessionFile!.path}');
      }
    } catch (e) {
      if (kDebugMode) print('[LogBuffer] File init failed: $e');
    }
  }

  /// Update battery state (logs changes only)
  static Future<void> _updateBatteryState() async {
    try {
      final battery = await Battery().batteryLevel;
      _currentBattery = battery;

      if (_lastLoggedBattery == null) return;

      // Log every 10% drop
      final drop = _lastLoggedBattery! - battery;
      if (drop >= 10) {
        _batteryChanges++;
        logDebug(
          'Battery: $_lastLoggedBattery% → $battery% (dropped $drop%)',
          level: LogLevel.warn,
        );
        _lastLoggedBattery = battery;
      }

      // Log critical thresholds
      if (battery <= 20 && (_lastLoggedBattery ?? 100) > 20) {
        logDebug(
          'Battery: $battery% - Power saving may affect GPS',
          level: LogLevel.error,
        );
      }
      if (battery <= 15 && (_lastLoggedBattery ?? 100) > 15) {
        logDebug(
          'Battery: $battery% - Low Power Mode likely active',
          level: LogLevel.error,
        );
      }
    } catch (e) {
      // Silent fail
    }
  }

  /// Convert ConnectivityResult to readable string
  static String _connectivityResultToString(ConnectivityResult result) {
    return result.name;
  }

  /// Build header with session context
  static Future<String> _buildHeader() async {
    final battery = _startBattery ?? await Battery().batteryLevel;
    final network = _connectivityResultToString(
      _startNetwork ?? ConnectivityResult.none,
    );

    return '''
=== POLYFENCE LOG EXPORT ===
Device: $_deviceName
Session: ${_sessionStart!.toIso8601String()}
Battery: $battery% (start)
Network: $network (start)
Buffer: $_maxEntries entries max
Filter: ${minimumLevel.name.toUpperCase()} and above
===========================

''';
  }

  /// Add a timestamped log entry
  static void add(String message, {LogLevel level = LogLevel.info}) {
    if (!enabled) return;
    if (level.index < minimumLevel.index) return;

    final timestamp = DateTime.now().toIso8601String();
    final levelStr = level.name.toUpperCase().padRight(5);
    final entry = '[$timestamp] [$_deviceName] [$levelStr] $message';

    _entries.addLast(entry);
    _totalEntriesAdded++;

    // Evict oldest entries when buffer is full
    while (_entries.length > _maxEntries) {
      _entries.removeFirst();
    }

    // Immediate flush on errors (don't wait for timer)
    if (level == LogLevel.error) {
      flush();
    }
  }

  /// Flush buffered entries to disk file
  static Future<void> flush() async {
    if (_currentSessionFile == null) return;

    // Calculate how many unflushed entries exist
    final unflushedCount = _totalEntriesAdded - _totalEntriesFlushed;
    if (unflushedCount <= 0) return;

    // Get the entries to flush (may be fewer than unflushedCount if buffer wrapped)
    final entriesToFlush = unflushedCount > _entries.length
        ? _entries.toList()
        : _entries.skip(_entries.length - unflushedCount).toList();

    if (entriesToFlush.isEmpty) return;

    try {
      final sink = _currentSessionFile!.openWrite(mode: FileMode.append);
      for (final entry in entriesToFlush) {
        sink.writeln(entry);
      }
      await sink.flush();
      await sink.close();

      _totalEntriesFlushed = _totalEntriesAdded;

      if (kDebugMode) {
        print('[LogBuffer] Flushed ${entriesToFlush.length} entries to disk');
      }
    } catch (e) {
      if (kDebugMode) {
        print('[LogBuffer] Flush failed: $e');
      }
    }
  }

  /// Build final export header with session summary stats.
  /// Used when exporting from disk file (contains total session counts).
  static Future<String> _buildExportHeader() async {
    final duration = DateTime.now().difference(_sessionStart!);
    final endBattery = _currentBattery ?? await Battery().batteryLevel;
    final batteryUsed = (_startBattery ?? 100) - endBattery;

    return '''
=== POLYFENCE LOG EXPORT ===
Device: $_deviceName
Session: ${_sessionStart!.toIso8601String()}
Duration: ${duration.inHours}h ${duration.inMinutes % 60}m ${duration.inSeconds % 60}s
Battery: $_startBattery% → $endBattery% (used $batteryUsed%) - $_batteryChanges changes logged
Network: ${_connectivityResultToString(_startNetwork ?? ConnectivityResult.none)} → ${_connectivityResultToString(_currentNetwork ?? ConnectivityResult.none)} - $_networkChanges changes logged
Entries: $_totalEntriesAdded total this session (${_entries.length} in memory, $_maxEntries buffer max)
===========================

''';
  }

  /// Get in-memory buffered entries as a single string (max _maxEntries).
  /// For the complete session, use exportLogs() which reads from the disk file.
  static Future<String> dump() async {
    final header = await _buildExportHeader();
    return header + _entries.join('\n');
  }

  /// Number of entries currently buffered
  static int get length => _entries.length;

  /// Clear the buffer
  static void clear() {
    _entries.clear();
    _totalEntriesAdded = 0;
    _totalEntriesFlushed = 0;
  }

  /// Export logs via the platform share sheet.
  ///
  /// Exports the **complete session** from the disk file (all entries ever
  /// flushed), not the in-memory ring buffer (which is capped at 5000).
  /// Falls back to in-memory dump() if no disk file exists.
  /// [shareOrigin] is required on iPad for the popover anchor.
  static Future<void> exportLogs({Rect? shareOrigin}) async {
    if (_entries.isEmpty && _currentSessionFile == null) return;

    // Flush any remaining in-memory entries to disk before export
    await flush();

    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;

    // Prefer disk file (contains complete session) over in-memory buffer
    File? exportFile;
    if (_currentSessionFile != null && await _currentSessionFile!.exists()) {
      // Build export: final summary header + complete disk log
      final header = await _buildExportHeader();
      final diskContent = await _currentSessionFile!.readAsString();

      final dir = await getTemporaryDirectory();
      exportFile = File('${dir.path}/polyfence_${_deviceName}_$timestamp.txt');
      await exportFile.writeAsString(header + diskContent);
    } else {
      // Fallback: no disk file, use in-memory dump
      final logText = await dump();
      final dir = await getTemporaryDirectory();
      exportFile = File('${dir.path}/polyfence_${_deviceName}_$timestamp.txt');
      await exportFile.writeAsString(logText);
    }

    // Always share as file — reliable on both platforms and handles large logs
    await Share.shareXFiles(
      [XFile(exportFile.path)],
      subject: 'Polyfence Logs - $_deviceName',
      sharePositionOrigin: shareOrigin,
    );
  }

  /// Get list of archived log files from previous sessions
  static Future<List<File>> getArchivedLogs() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final logsDir = Directory('${dir.path}/polyfence_logs');

      if (!await logsDir.exists()) return [];

      final files = await logsDir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.txt'))
          .cast<File>()
          .toList();

      // Sort by modification time, newest first
      files.sort((a, b) =>
          b.lastModifiedSync().compareTo(a.lastModifiedSync()));

      return files;
    } catch (e) {
      return [];
    }
  }

  /// Cleanup old log files (keep last N sessions)
  static Future<void> cleanupOldLogs({int keepLast = 20}) async {
    try {
      final files = await getArchivedLogs();

      if (files.length > keepLast) {
        for (var i = keepLast; i < files.length; i++) {
          await files[i].delete();
        }
        if (kDebugMode) {
          print('[LogBuffer] Cleaned up ${files.length - keepLast} old log files');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('[LogBuffer] Cleanup failed: $e');
      }
    }
  }

  /// Dispose logger - call on app shutdown
  static Future<void> dispose() async {
    _flushTimer?.cancel();
    await flush();
  }
}

/// Debug print wrapper. Outputs to console in debug builds,
/// and always captures to the exportable ring buffer.
void logDebug(String message, {LogLevel level = LogLevel.info}) {
  // Always capture to ring buffer (debug + release)
  LogBuffer.add(message, level: level);

  // Console output only in debug builds
  if (kDebugMode) {
    debugPrint(message);
  }
}

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_up_front/feature/history/widgetsHistory/transfer_history_card.dart';

const _historyStorageKey = 'transfer_history_records';
const _maxHistoryRecords = 50;

class HistoryStats {
  final int receivedCount;
  final int sentCount;

  const HistoryStats({required this.receivedCount, required this.sentCount});
}

Future<List<TransferHistoryItem>> loadRecords() async {
  final prefs = await SharedPreferences.getInstance();
  final records = prefs.getStringList(_historyStorageKey) ?? const [];

  return records
      .map(_recordFromJson)
      .whereType<TransferHistoryItem>()
      .take(_maxHistoryRecords)
      .toList();
}

Future<HistoryStats> loadHistoryStats() async {
  final prefs = await SharedPreferences.getInstance();
  final records = prefs.getStringList(_historyStorageKey) ?? const [];
  var receivedCount = 0;
  var sentCount = 0;

  for (final record in records) {
    final data = _recordDataFromJson(record);
    if (data == null) continue;

    final direction = data['direction'];
    final fileCount = data['fileCount'];
    if (direction is! String || fileCount is! num) continue;

    if (direction == 'received') {
      receivedCount += fileCount.toInt();
    } else if (direction == 'sent') {
      sentCount += fileCount.toInt();
    }
  }

  return HistoryStats(receivedCount: receivedCount, sentCount: sentCount);
}

Future<void> sendRecords({
  required int size,
  required int fileCount,
  required DateTime time,
  required String deviceName,
  required List<String> fileNames,
}) async {
  await _saveRecord(
    direction: 'sent',
    size: size,
    fileCount: fileCount,
    time: time,
    deviceName: deviceName,
    fileNames: fileNames,
  );
}

Future<void> receiveRecords({
  required int size,
  required int fileCount,
  required DateTime time,
  required String deviceName,
  required List<String> fileNames,
}) async {
  await _saveRecord(
    direction: 'received',
    size: size,
    fileCount: fileCount,
    time: time,
    deviceName: deviceName,
    fileNames: fileNames,
  );
}

Future<void> _saveRecord({
  required String direction,
  required int size,
  required int fileCount,
  required DateTime time,
  required String deviceName,
  required List<String> fileNames,
}) async {
  if (fileCount <= 0) return;

  final prefs = await SharedPreferences.getInstance();
  final records = prefs.getStringList(_historyStorageKey) ?? const [];

  final record = jsonEncode({
    'direction': direction,
    'size': size,
    'fileCount': fileCount,
    'time': time.toIso8601String(),
    'deviceName': _cleanDeviceName(deviceName),
    'fileNames': _cleanFileNames(fileNames),
  });

  await prefs.setStringList(
    _historyStorageKey,
    [record, ...records].take(_maxHistoryRecords).toList(),
  );
}

List<String> _cleanFileNames(List<String> fileNames) {
  return fileNames
      .map((fileName) => fileName.trim())
      .where((fileName) => fileName.isNotEmpty)
      .toList();
}

String _cleanDeviceName(String deviceName) {
  final cleanName = deviceName.trim();
  if (cleanName.isNotEmpty) return cleanName;

  return 'Appareil inconnu';
}

TransferHistoryItem? _recordFromJson(String source) {
  try {
    final data = _recordDataFromJson(source);
    if (data == null) return null;

    final direction = data['direction'];
    final size = data['size'];
    final fileCount = data['fileCount'];
    final time = data['time'];
    final deviceName = data['deviceName'];

    if (direction is! String ||
        size is! num ||
        fileCount is! num ||
        time is! String ||
        deviceName is! String) {
      return null;
    }

    final parsedTime = DateTime.tryParse(time);
    if (parsedTime == null) return null;

    return TransferHistoryItem(
      deviceName: _cleanDeviceName(deviceName),
      detail: _formatDetail(fileCount.toInt()),
      timeLabel: _formatTime(parsedTime),
      sizeLabel: _formatSize(size.toInt()),
      direction: direction == 'received'
          ? TransferDirection.received
          : TransferDirection.sent,
    );
  } catch (_) {
    return null;
  }
}

Map<String, dynamic>? _recordDataFromJson(String source) {
  final data = jsonDecode(source);
  if (data is! Map<String, dynamic>) return null;

  return data;
}

String _formatDetail(int fileCount) {
  if (fileCount == 1) return '1 fichier';
  return '$fileCount fichiers';
}

String _formatTime(DateTime time) {
  final localTime = time.toLocal();
  final now = DateTime.now();
  final yesterday = now.subtract(const Duration(days: 1));
  final hour = _formatHour(localTime);

  if (_isSameDay(localTime, now)) return 'Aujourd\'hui à $hour';
  if (_isSameDay(localTime, yesterday)) return 'Hier à $hour';

  return '${_twoDigits(localTime.day)}/'
      '${_twoDigits(localTime.month)}/'
      '${localTime.year} à $hour';
}

bool _isSameDay(DateTime first, DateTime second) {
  return first.year == second.year &&
      first.month == second.month &&
      first.day == second.day;
}

String _formatHour(DateTime time) {
  return '${_twoDigits(time.hour)}:${_twoDigits(time.minute)}';
}

String _formatSize(int bytes) {
  if (bytes <= 0) return '0 B';
  if (bytes < 1024) return '$bytes B';

  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';

  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(1)} MB';

  final gb = mb / 1024;
  return '${gb.toStringAsFixed(1)} GB';
}

String _twoDigits(int value) {
  return value.toString().padLeft(2, '0');
}

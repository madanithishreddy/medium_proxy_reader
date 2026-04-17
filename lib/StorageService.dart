// ignore_for_file: file_names

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService extends ChangeNotifier {
  static const String _historyKey = 'history_urls';
  static const String _bookmarksKey = 'bookmark_urls';
  static const int _maxHistory = 100;

  final List<String> _history = <String>[];
  final Set<String> _bookmarks = <String>{};

  List<String> get history => List<String>.unmodifiable(_history);
  List<String> get bookmarks => List<String>.unmodifiable(_bookmarks.toList());

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();

    _history
      ..clear()
      ..addAll(_decodeStringList(prefs.getString(_historyKey)));

    _bookmarks
      ..clear()
      ..addAll(_decodeStringList(prefs.getString(_bookmarksKey)));

    notifyListeners();
  }

  Future<void> addToHistory(String url) async {
    if (url.isEmpty) return;

    _history.remove(url);
    _history.insert(0, url);

    if (_history.length > _maxHistory) {
      _history.removeRange(_maxHistory, _history.length);
    }

    await _persistHistory();
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _history.clear();
    await _persistHistory();
    notifyListeners();
  }

  Future<void> removeFromHistory(String url) async {
    if (url.isEmpty) return;
    if (!_history.remove(url)) return;

    await _persistHistory();
    notifyListeners();
  }

  Future<void> toggleBookmark(String url) async {
    if (url.isEmpty) return;

    if (_bookmarks.contains(url)) {
      _bookmarks.remove(url);
    } else {
      _bookmarks.add(url);
    }

    await _persistBookmarks();
    notifyListeners();
  }

  Future<void> removeBookmark(String url) async {
    if (url.isEmpty) return;
    if (!_bookmarks.remove(url)) return;

    await _persistBookmarks();
    notifyListeners();
  }

  bool isBookmarked(String url) => _bookmarks.contains(url);

  Future<void> _persistHistory() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(_history));
  }

  Future<void> _persistBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bookmarksKey, jsonEncode(_bookmarks.toList()));
  }

  List<String> _decodeStringList(String? rawJson) {
    if (rawJson == null || rawJson.isEmpty) return <String>[];

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is List) {
        return decoded.whereType<String>().toList(growable: false);
      }
    } catch (_) {
      return <String>[];
    }

    return <String>[];
  }
}

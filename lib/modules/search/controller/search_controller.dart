import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class SearchingController extends GetxController{
  final TextEditingController controller = TextEditingController();
  RxString searchQuery = ''.obs;
  RxList<String> recentSearches = <String>[].obs;
  Timer? _debounceTimer;
  
  static const String _recentSearchesKey = 'recent_searches';

  @override
  void onInit() {
    super.onInit();
    controller.addListener(() {
      // Debounce search to reduce queries
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 300), () {
        searchQuery.value = controller.text;
      });
    });
    _loadRecentSearches();
  }

  @override
  void onClose() {
    _debounceTimer?.cancel();
    controller.dispose();
    super.onClose();
  }

  Future<void> _loadRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final searchesJson = prefs.getString(_recentSearchesKey);
      if (searchesJson != null) {
        final List<dynamic> searchesList = jsonDecode(searchesJson);
        recentSearches.value = searchesList.cast<String>();
      }
    } catch (e) {
      debugPrint('Error loading recent searches: $e');
    }
  }

  Future<void> _saveRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_recentSearchesKey, jsonEncode(recentSearches.toList()));
    } catch (e) {
      debugPrint('Error saving recent searches: $e');
    }
  }

  void addToRecentSearches(String query) {
    if (query.trim().isEmpty) return;
    
    final trimmedQuery = query.trim();
    
    // Remove if already exists
    recentSearches.remove(trimmedQuery);
    
    // Add to beginning
    recentSearches.insert(0, trimmedQuery);
    
    // Keep only last 10 searches
    if (recentSearches.length > 10) {
      recentSearches.removeRange(10, recentSearches.length);
    }
    
    _saveRecentSearches();
  }

  void removeRecentSearch(String query) {
    recentSearches.remove(query);
    _saveRecentSearches();
  }

  void clearRecentSearches() {
    recentSearches.clear();
    _saveRecentSearches();
  }

  void clearSearch() {
    controller.clear();
    searchQuery.value = '';
  }
}
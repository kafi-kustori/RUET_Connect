import 'dart:convert';
import 'package:http/http.dart' as http;

// 🔗 Base Firebase URL
const String baseUrl = 'https://loveruet-default-rtdb.asia-southeast1.firebasedatabase.app';

// 📥 Get a key's value or return a default
Future<dynamic> GetKeyValue(String bucket, String key, dynamic defaultValue) async {
  final url = Uri.parse('$baseUrl/$bucket/$key.json');
  try {
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data ?? defaultValue;
    }
  } catch (e) {
    print("GetKeyValue Error: $e");
  }
  return defaultValue;
}

// 💾 Save a value to a specific key
Future<bool> SaveKey(String bucket, String key, dynamic value) async {
  final url = Uri.parse('$baseUrl/$bucket/$key.json');
  try {
    final response = await http.put(url, body: jsonEncode(value));
    return response.statusCode == 200;
  } catch (e) {
    print("SaveKey Error: $e");
    return false;
  }
}

// 📋 Get a list of items from a key
Future<List<dynamic>> GetList(String bucket, String key) async {
  final url = Uri.parse('$baseUrl/$bucket/$key.json');
  try {
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is List) {
        return data;
      } else if (data is Map) {
        return data.values.toList();
      }
    }
  } catch (e) {
    print("GetList Error: $e");
  }
  return [];
}

// ➕ Add an item to a list (auto-generated key)
Future<bool> AddToList(String bucket, String key, dynamic value) async {
  final url = Uri.parse('$baseUrl/$bucket/$key.json');
  try {
    final response = await http.post(url, body: jsonEncode(value));
    return response.statusCode == 200;
  } catch (e) {
    print("AddToList Error: $e");
    return false;
  }
}

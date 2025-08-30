import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class MaintenanceService {
  static const String maintenanceJsonUrl = 
      'https://raw.githubusercontent.com/officialprakashkumarsingh/ahamai-landingpage/main/maintenance.json';
  
  static MaintenanceInfo? _cachedInfo;
  
  static Future<MaintenanceInfo?> checkMaintenanceStatus() async {
    try {
      final response = await http.get(
        Uri.parse(maintenanceJsonUrl),
        headers: {'Cache-Control': 'no-cache'},
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        _cachedInfo = MaintenanceInfo.fromJson(json);
        return _cachedInfo;
      }
    } catch (e) {
      print('Error checking maintenance status: $e');
      // Return cached info if available when network fails
      return _cachedInfo;
    }
    return null;
  }
  
  static MaintenanceInfo? getCachedInfo() => _cachedInfo;
}

class MaintenanceInfo {
  final bool isMaintenanceMode;
  final String title;
  final String message;
  final String? estimatedEndTime;
  final String? contactEmail;
  
  MaintenanceInfo({
    required this.isMaintenanceMode,
    required this.title,
    required this.message,
    this.estimatedEndTime,
    this.contactEmail,
  });
  
  factory MaintenanceInfo.fromJson(Map<String, dynamic> json) {
    return MaintenanceInfo(
      isMaintenanceMode: json['maintenance_mode'] ?? false,
      title: json['title'] ?? 'SYSTEM MAINTENANCE',
      message: json['message'] ?? 'We are currently performing maintenance. Please check back later.',
      estimatedEndTime: json['estimated_end_time'],
      contactEmail: json['contact_email'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'maintenance_mode': isMaintenanceMode,
      'title': title,
      'message': message,
      'estimated_end_time': estimatedEndTime,
      'contact_email': contactEmail,
    };
  }
}
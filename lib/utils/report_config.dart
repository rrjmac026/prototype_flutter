import 'package:flutter/material.dart';

class ReportConfig {
  static Map<String, dynamic> getStyle(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return {
      'document': {
        'title': 'Flower Monitoring Report',
        'creator': 'Smart Flower Monitoring System',
        'watermark': 'FlowerHaven',
      },
      'theme': {
        'colors': {
          'primary': '#4CAF50',
          'secondary': '#2196F3',
          'accent': '#FFC107',
          'background': isDark ? '#121212' : '#FFFFFF',
          'surface': isDark ? '#1E1E1E' : '#F5F5F5',
          'text': isDark ? '#FFFFFF' : '#000000',
          'border': isDark ? '#404040' : '#E0E0E0',
          'chart': '#2196F3',
          'success': '#4CAF50',
          'warning': '#FFC107',
          'error': '#F44336',
        },
      },
      'layout': {
        'pageSize': 'A4',
        'margins': [40, 60, 40, 60], // left, top, right, bottom
        'spacing': 16,
        'header': {
          'height': 80,
          'logo': true,
          'border': true,
        },
        'footer': {
          'height': 40,
          'pageNumbers': true,
          'border': true,
        },
      },
      'typography': {
        'title': {
          'font': 'Roboto',
          'size': 24,
          'bold': true,
          'align': 'center',
          'spacing': 2,
        },
        'heading': {
          'font': 'Roboto',
          'size': 18,
          'bold': true,
          'spacing': 1.5,
        },
        'body': {
          'font': 'Arial',
          'size': 12,
          'spacing': 1.2,
        },
      },
      'charts': {
        'height': 200,
        'grid': true,
        'legend': true,
        'animations': false,
      },
      'tables': {
        'header': {
          'background': isDark ? '#2C2C2C' : '#EEEEEE',
          'bold': true,
        },
        'row': {
          'alternateBackground': isDark ? '#1A1A1A' : '#F9F9F9',
          'border': true,
        },
      },
    };
  }
}

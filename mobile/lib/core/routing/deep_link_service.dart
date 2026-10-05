import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class DeepLinkService {
  /// Normalizes incoming URIs and action URLs into standard GoRouter relative paths with query parameters.
  ///
  /// Examples:
  /// - `blinkist://books/atomic-habits` -> `/books/atomic-habits`
  /// - `blinkist:///books/atomic-habits` -> `/books/atomic-habits`
  /// - `blinkist://books/atomic-habits/listen?section=1&pos=45` -> `/books/atomic-habits/listen?section=1&pos=45`
  /// - `https://blinkist.com/collections/productivity` -> `/collections/productivity`
  /// - `https://www.blinkist.com/library?tab=notebook` -> `/library?tab=notebook`
  /// - `/books/deep-work` -> `/books/deep-work`
  static String normalize(String rawUrl) {
    final trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return '/';

    // If already a relative path starting with '/', return as is
    if (trimmed.startsWith('/') && !trimmed.startsWith('//')) {
      return trimmed;
    }

    try {
      final uri = Uri.parse(trimmed);

      // Handle custom scheme: blinkist://
      if (uri.scheme.toLowerCase() == 'blinkist') {
        String path = '';
        if (uri.host.isNotEmpty) {
          path = '/${uri.host}${uri.path}';
        } else {
          path = uri.path.startsWith('/') ? uri.path : '/${uri.path}';
        }

        // Clean double slashes
        path = path.replaceAll(RegExp(r'/+'), '/');

        if (uri.hasQuery) {
          return '$path?${uri.query}';
        }
        return path;
      }

      // Handle web domains: blinkist.com / www.blinkist.com
      if (uri.host.toLowerCase().contains('blinkist.com')) {
        String path = uri.path.startsWith('/') ? uri.path : '/${uri.path}';
        path = path.replaceAll(RegExp(r'/+'), '/');

        if (uri.hasQuery) {
          return '$path?${uri.query}';
        }
        return path;
      }

      // If it's a relative URL missing leading slash
      if (!uri.hasScheme) {
        final path = trimmed.startsWith('/') ? trimmed : '/$trimmed';
        return path;
      }

      // Fallback: return path from URI
      String path = uri.path.startsWith('/') ? uri.path : '/${uri.path}';
      if (uri.hasQuery) {
        return '$path?${uri.query}';
      }
      return path.isNotEmpty ? path : '/';
    } catch (_) {
      // Fallback on parse failure
      return trimmed.startsWith('/') ? trimmed : '/$trimmed';
    }
  }

  /// Dispatches navigation to the target action URL with safety checks and error handling.
  static void handleActionUrl(BuildContext context, String? rawUrl) {
    if (rawUrl == null || rawUrl.trim().isEmpty) return;

    final targetPath = normalize(rawUrl);

    try {
      // If it's one of the main tabs, use context.go to update bottom navigation bar
      if (targetPath == '/' ||
          targetPath.startsWith('/explore') ||
          targetPath.startsWith('/library') ||
          targetPath == '/profile') {
        context.go(targetPath);
      } else {
        context.push(targetPath);
      }
    } catch (e) {
      debugPrint('[DeepLinkService] Navigation error for $rawUrl ($targetPath): $e');
      // If direct push fails, attempt fallback to home or explore
      try {
        context.go('/');
      } catch (_) {}
    }
  }
}

// ignore_for_file: file_names

class UrlTransformer {
  static const String _mediumHost = 'medium.com';
  static const String _mirrorBase = 'https://freedium-mirror.cfd';
  static const String _mirrorHost = 'freedium-mirror.cfd';

  bool canHandle(String input) {
    return normalizeForReader(input) != null;
  }

  bool isMirrorUrl(String input) {
    final uri = _extractUri(input);
    if (uri == null) return false;

    return uri.host.toLowerCase() == _mirrorHost;
  }

  String? normalizeForReader(String input) {
    final uri = _extractUri(input);
    if (uri == null) return null;

    if (_isMediumHost(uri.host)) {
      return _canonicalMediumUrl(uri);
    }

    if (uri.host.toLowerCase() == _mirrorHost) {
      return uri.toString();
    }

    return null;
  }

  String? toMirrorUrl(String input) {
    final normalized = normalizeForReader(input);
    if (normalized == null) {
      return null;
    }

    final normalizedUri = Uri.parse(normalized);
    if (normalizedUri.host.toLowerCase() == _mirrorHost) {
      return normalized;
    }

    return transform(normalized);
  }

  String transform(String input) {
    final uri = Uri.parse(normalizeForReader(input) ?? input);
    final path = uri.path.isEmpty ? '/' : uri.path;

    final mirrorUri = Uri.parse('$_mirrorBase$path').replace(
      query: uri.query.isEmpty ? null : uri.query,
      fragment: uri.fragment.isEmpty ? null : uri.fragment,
    );

    return mirrorUri.toString();
  }

  bool _isMediumHost(String host) {
    final normalizedHost = host.toLowerCase();
    return normalizedHost == _mediumHost ||
        normalizedHost.endsWith('.$_mediumHost');
  }

  Uri? _extractUri(String input) {
    final trimmed = _sanitizeInput(input);
    if (trimmed.isEmpty) return null;

    final directUri = Uri.tryParse(trimmed);
    if (directUri != null && directUri.host.isNotEmpty) {
      if (directUri.scheme.isNotEmpty) {
        return directUri;
      }

      if (_looksLikeUrlHost(trimmed)) {
        return Uri.tryParse('https://$trimmed');
      }
    }

    final urlMatch = RegExp(
      r'''https?:\/\/[^\s<>"']+''',
      caseSensitive: false,
    ).firstMatch(trimmed);
    if (urlMatch != null) {
      return Uri.tryParse(urlMatch.group(0)!);
    }

    if (_looksLikeUrlHost(trimmed)) {
      return Uri.tryParse('https://$trimmed');
    }

    return null;
  }

  String _sanitizeInput(String input) {
    var text = input.trim();
    if (text.isEmpty) return text;

    // Remove simple wrapping quotes users often paste with links.
    if (text.length >= 2) {
      final first = text[0];
      final last = text[text.length - 1];
      final wrappedInQuotes =
          (first == '"' && last == '"') || (first == "'" && last == "'");
      if (wrappedInQuotes) {
        text = text.substring(1, text.length - 1).trim();
      }
    }

    // Convert encoded ampersands commonly found in copied newsletter links.
    text = text.replaceAll('&amp;', '&');
    return text;
  }

  bool _looksLikeUrlHost(String input) {
    return input.toLowerCase().startsWith(_mediumHost) ||
        input.toLowerCase().startsWith('www.medium.com') ||
        input.toLowerCase().startsWith('m.medium.com') ||
        input.toLowerCase().startsWith('freedium-mirror.cfd');
  }

  String _canonicalMediumUrl(Uri uri) {
    final path = uri.path.isEmpty ? '/' : uri.path;
    final canonicalUri = Uri(
      scheme: 'https',
      host: _mediumHost,
      path: path,
      // Mirror routing is path-based; dropping newsletter/tracking params
      // improves compatibility with copied email links.
      query: null,
      fragment: null,
    );

    return canonicalUri.toString();
  }
}

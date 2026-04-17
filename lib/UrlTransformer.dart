// ignore_for_file: file_names

class UrlTransformer {
  static const String _mediumHost = 'medium.com';
  static const String _mediumHostWww = 'www.medium.com';
  static const String _mirrorBase = 'https://freedium-mirror.cfd';
  static const String _mirrorHost = 'freedium-mirror.cfd';

  bool canHandle(String input) {
    final uri = Uri.tryParse(input);
    if (uri == null) return false;

    final isHttps = uri.scheme.toLowerCase() == 'https';
    final host = uri.host.toLowerCase();
    return isHttps && (host == _mediumHost || host == _mediumHostWww);
  }

  bool isMirrorUrl(String input) {
    final uri = Uri.tryParse(input);
    if (uri == null) return false;

    final isHttps = uri.scheme.toLowerCase() == 'https';
    return isHttps && uri.host.toLowerCase() == _mirrorHost;
  }

  String? toMirrorUrl(String input) {
    if (canHandle(input)) {
      return transform(input);
    }

    if (isMirrorUrl(input)) {
      return input;
    }

    return null;
  }

  String transform(String input) {
    final uri = Uri.parse(input);
    final path = uri.path.isEmpty ? '/' : uri.path;

    final mirrorUri = Uri.parse('$_mirrorBase$path').replace(
      query: uri.query.isEmpty ? null : uri.query,
      fragment: uri.fragment.isEmpty ? null : uri.fragment,
    );

    return mirrorUri.toString();
  }
}

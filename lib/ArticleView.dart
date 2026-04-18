// ignore_for_file: file_names

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'StorageService.dart';
import 'ThemeProvider.dart';
import 'UrlTransformer.dart';

class ArticleView extends StatefulWidget {
  const ArticleView({super.key, required this.mediumUrl});

  final String mediumUrl;

  @override
  State<ArticleView> createState() => _ArticleViewState();
}

class _ArticleViewState extends State<ArticleView> {
  final UrlTransformer _transformer = UrlTransformer();
  late final String _mirrorUrl;
  late final WebViewController _controller;

  bool _isLoading = true;
  String? _errorText;
  String? _originalUrl;
  AppThemeMode? _lastAppliedThemeMode;
  bool _pageReady = false;

  @override
  void initState() {
    super.initState();

    final resolvedMirror = _transformer.toMirrorUrl(widget.mediumUrl);

    if (resolvedMirror == null) {
      _errorText = 'Unsupported URL. Please open a medium.com article link.';
      _mirrorUrl = '';
      _controller = WebViewController();
      return;
    }

    _mirrorUrl = resolvedMirror;
    _originalUrl = _transformer.canHandle(widget.mediumUrl)
        ? widget.mediumUrl
        : null;

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _errorText = null;
              _pageReady = false;
              _lastAppliedThemeMode = null;
            });
            unawaited(
              _controller.runJavaScript('window.x1 = window.x1 || {};'),
            );
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _pageReady = true;
            });
            unawaited(_syncPageAppearance());
            unawaited(_discoverOriginalUrl());
          },
          onWebResourceError: (error) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
              _errorText =
                  'Failed to load article. Check your connection and retry.';
            });
          },
          onNavigationRequest: (request) {
            final uri = Uri.tryParse(request.url);
            if (uri == null) {
              return NavigationDecision.prevent;
            }

            final host = uri.host.toLowerCase();
            final isMirror = host == 'freedium-mirror.cfd';
            final isMedium =
                host == 'medium.com' ||
                host == 'www.medium.com' ||
                host.endsWith('.medium.com');

            if (isMirror) {
              return NavigationDecision.navigate;
            }

            if (isMedium) {
              final mirrorUrl = _transformer.toMirrorUrl(request.url);
              if (mirrorUrl != null) {
                unawaited(_controller.loadRequest(Uri.parse(mirrorUrl)));
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            }

            _openExternal(uri);
            return NavigationDecision.prevent;
          },
        ),
      )
      ..loadRequest(Uri.parse(_mirrorUrl));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<StorageService>().addToHistory(_mirrorUrl);
    });
  }

  Future<void> _openExternal(Uri uri) async {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _shareMirrorUrl() async {
    if (_mirrorUrl.isEmpty) return;

    try {
      final currentUrl = await _controller.currentUrl();
      final normalized = currentUrl == null
          ? null
          : _transformer.toMirrorUrl(currentUrl);
      final shareUrl = normalized ?? _mirrorUrl;
      await Share.share(shareUrl, subject: 'Freedium mirror article');
    } catch (_) {
      await Share.share(_mirrorUrl, subject: 'Freedium mirror article');
    }
  }

  Future<void> _retry() async {
    if (_mirrorUrl.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    await _controller.loadRequest(Uri.parse(_mirrorUrl));
  }

  Future<void> _syncPageAppearance() async {
    if (!_pageReady || _errorText != null || _mirrorUrl.isEmpty) return;

    const themeMode = AppThemeMode.original;
    if (_lastAppliedThemeMode == themeMode) {
      return;
    }

    _lastAppliedThemeMode = themeMode;

    final colors = _readerBaseColors();
    final backgroundColor = _cssColor(colors.background);
    final foregroundColor = _cssColor(colors.foreground);
    final surfaceColor = _cssColor(colors.surface);
    final mutedColor = _cssColor(colors.muted);
    final linkColor = _cssColor(colors.link);
    final borderColor = _cssColor(colors.muted);
    const overlayColor = 'rgba(15, 23, 42, 0.03)';
    const shadowColor = 'rgba(15, 23, 42, 0.1)';
    const colorScheme = 'light';

    await _controller.runJavaScript('''
(function () {
  window.x1 = window.x1 || {};
  document.documentElement.classList.remove('dark', 'androidstudio');
  document.body.classList.remove('dark', 'androidstudio');
  document.documentElement.removeAttribute('data-theme');
  document.body.removeAttribute('data-theme');

  const backgroundColor = '$backgroundColor';
  const foregroundColor = '$foregroundColor';
  const surfaceColor = '$surfaceColor';
  const mutedColor = '$mutedColor';
  const linkColor = '$linkColor';
  const borderColor = '$borderColor';
  const overlayColor = '$overlayColor';
  const shadowColor = '$shadowColor';
  const colorScheme = '$colorScheme';
  const freediumPattern = /freedium: your paywall breakthrough for medium!|additional links|patreon|ko-fi|liberapay/i;

  const applyStyles = (element) => {
    if (!element || !element.style) return;
    element.style.backgroundColor = backgroundColor;
    element.style.color = foregroundColor;
  };

  const styleId = 'mpr-reader-theme-style';
  const oldStyle = document.getElementById(styleId);
  if (oldStyle) {
    oldStyle.remove();
  }

  const style = document.createElement('style');
  style.id = styleId;
  style.textContent = `
    :root {
      color-scheme: $colorScheme !important;
    }

    html, body {
      background: $backgroundColor !important;
      color: $foregroundColor !important;
      margin: 0 !important;
      padding: 0 !important;
      line-height: 1.78 !important;
      font-size: 18px !important;
      font-family: ui-serif, Georgia, Cambria, "Times New Roman", Times, serif !important;
      text-rendering: optimizeLegibility !important;
      -webkit-font-smoothing: antialiased !important;
      word-wrap: break-word !important;
    }

    article, main, [role="main"], .postArticle-content, .meteredContent {
      max-width: 760px !important;
      margin: 0 auto !important;
      padding: 26px 18px 72px !important;
      box-sizing: border-box !important;
      background: transparent !important;
    }

    article > div, main > div {
      background: transparent !important;
    }

    h1, h2, h3 {
      color: $foregroundColor !important;
      line-height: 1.35 !important;
      letter-spacing: -0.01em !important;
      margin: 1.2em 0 0.6em !important;
    }

    h1 {
      font-size: clamp(1.8rem, 1.2rem + 2.2vw, 2.4rem) !important;
    }

    h2 {
      font-size: clamp(1.35rem, 1rem + 1vw, 1.7rem) !important;
    }

    p, li, figcaption {
      color: $foregroundColor !important;
      font-size: 1.08rem !important;
    }

    p, li {
      margin: 0 0 1em !important;
    }

    a {
      color: $linkColor !important;
      text-underline-offset: 0.14em !important;
      text-decoration-thickness: 0.08em !important;
    }

    code, pre, blockquote {
      background: $surfaceColor !important;
      color: $foregroundColor !important;
      border: 1px solid $borderColor !important;
      border-radius: 12px !important;
    }

    pre, blockquote {
      padding: 0.9em 1em !important;
      overflow-x: auto !important;
    }

    img, video {
      max-width: 100% !important;
      height: auto !important;
      border-radius: 12px !important;
      box-shadow: 0 6px 20px $shadowColor !important;
      filter: none !important;
      opacity: 1 !important;
      visibility: visible !important;
    }

    table {
      display: block !important;
      overflow-x: auto !important;
      border-collapse: collapse !important;
      max-width: 100% !important;
      border: 1px solid $borderColor !important;
      background: $surfaceColor !important;
    }

    th, td {
      border: 1px solid $borderColor !important;
      padding: 8px 10px !important;
    }

    hr {
      border-color: $borderColor !important;
      margin: 1.8em 0 !important;
    }

    mark {
      background: $overlayColor !important;
      color: $foregroundColor !important;
    }

    .freedium-header, .freedium-footer, .freedium-banner {
      display: none !important;
    }

    .freedium-menu, .freedium-floating, .freedium-action,
    [class*="freedium"][class*="menu"],
    [id*="freedium"][id*="menu"],
    [class*="floating"][class*="menu"],
    [class*="floating"][class*="share"] {
      display: none !important;
      visibility: hidden !important;
      opacity: 0 !important;
      pointer-events: none !important;
    }
  `;
  document.head.appendChild(style);

  applyStyles(document.documentElement);
  applyStyles(document.body);

  document.body.style.margin = '0';
  document.body.style.padding = '0';
  document.body.style.lineHeight = '1.75';

  // Keep this pass small to avoid UI jank on slower devices.
  const freediumCandidates = document.querySelectorAll('[class*="freedium"], [id*="freedium"], .metabar, .branch-journeys-top, .branch-journeys-bottom, [data-testid="publication-branch-journeys"]');
  freediumCandidates.forEach((element) => {
    const text = (element.textContent || '').trim();
    if (!text || freediumPattern.test(text)) {
      element.style.setProperty('display', 'none', 'important');
    }
  });

  // Hide small floating menu/share controls injected by Freedium on the right.
  const fixedCandidates = document.querySelectorAll('button, a, div');
  fixedCandidates.forEach((element) => {
    const style = window.getComputedStyle(element);
    if (!style) return;
    const isFloating = style.position === 'fixed' || style.position === 'sticky';
    if (!isFloating) return;

    const rect = element.getBoundingClientRect();
    const nearRight = rect.right >= window.innerWidth - 24;
    const nearTop = rect.top >= 40 && rect.top <= 320;
    const smallControl = rect.width <= 92 && rect.height <= 92;
    if (!(nearRight && nearTop && smallControl)) return;

    const hint = [
      element.getAttribute('aria-label') || '',
      element.getAttribute('title') || '',
      element.className || '',
      element.id || '',
      element.textContent || '',
    ].join(' ').toLowerCase();

    const looksLikeMenuOrShare = /menu|share|freedium|more|options/.test(hint) ||
      (element.querySelector && !!element.querySelector('svg'));

    if (looksLikeMenuOrShare) {
      element.style.setProperty('display', 'none', 'important');
      element.style.setProperty('visibility', 'hidden', 'important');
      element.style.setProperty('opacity', '0', 'important');
      element.style.setProperty('pointer-events', 'none', 'important');
    }
  });

  document.querySelectorAll('a').forEach((element) => {
    element.style.color = linkColor;
  });

  document.querySelectorAll('code, pre, blockquote').forEach((element) => {
    element.style.backgroundColor = surfaceColor;
    element.style.color = foregroundColor;
    element.style.borderColor = borderColor;
  });

  const originalLink = Array.from(document.querySelectorAll('a[href]')).find((element) => {
    const href = (element.href || '').toLowerCase();
    return href.includes('medium.com');
  });

  if (originalLink) {
    originalLink.scrollIntoView({ behavior: 'smooth', block: 'start' });
  }
})();
''');
  }

  Future<void> _discoverOriginalUrl() async {
    if (!_pageReady || _mirrorUrl.isEmpty) return;

    try {
      final result = await _controller.runJavaScriptReturningResult('''
(function () {
  const candidate = Array.from(document.querySelectorAll('a[href]')).find((element) => {
    const href = (element.href || '').toLowerCase();
    return href.includes('medium.com');
  });
  return candidate ? candidate.href : '';
})()
''');
      final parsed = _normalizeJavaScriptString(result);
      if (!mounted || parsed == null || parsed.isEmpty) return;

      if (_originalUrl != parsed) {
        setState(() {
          _originalUrl = parsed;
        });
      }
    } catch (_) {
      // The page may not expose a clean original link on every article.
    }
  }

  String? _normalizeJavaScriptString(Object? value) {
    if (value == null) return null;

    final text = value.toString().trim();
    if (text.isEmpty || text == 'null' || text == 'undefined') {
      return null;
    }

    if (text.length >= 2) {
      final first = text.codeUnitAt(0);
      final last = text.codeUnitAt(text.length - 1);
      final isQuoted =
          (first == 34 && last == 34) || (first == 39 && last == 39);
      if (isQuoted) {
        return text.substring(1, text.length - 1);
      }
    }

    return text;
  }

  _PageColors _readerBaseColors() {
    return const _PageColors(
      background: Color(0xFFF8FAFC),
      foreground: Color(0xFF111827),
      surface: Color(0xFFFFFFFF),
      muted: Color(0xFFE5E7EB),
      link: Color(0xFF0F62FE),
    );
  }

  String _cssColor(Color color) {
    final red = color.r.toInt().clamp(0, 255);
    final green = color.g.toInt().clamp(0, 255);
    final blue = color.b.toInt().clamp(0, 255);
    return '#${red.toRadixString(16).padLeft(2, '0')}${green.toRadixString(16).padLeft(2, '0')}${blue.toRadixString(16).padLeft(2, '0')}';
  }

  Future<void> _openOriginal() async {
    final originalUrl = _originalUrl;
    if (originalUrl == null || originalUrl.isEmpty) return;

    await launchUrl(
      Uri.parse(originalUrl),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();
    final isBookmarked =
        _mirrorUrl.isNotEmpty && storage.isBookmarked(_mirrorUrl);
    final webViewColor = Theme.of(context).colorScheme.surface;
    final pageTheme = Theme.of(context);
    final scaffoldBackground = pageTheme.colorScheme.surface;

    if (_pageReady &&
        _errorText == null &&
        _lastAppliedThemeMode != AppThemeMode.original) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_syncPageAppearance());
      });
    }

    return Scaffold(
      backgroundColor: scaffoldBackground,
      appBar: AppBar(
        title: const Text('Medium Mirror Reader'),
        actions: [
          IconButton(
            onPressed: _mirrorUrl.isEmpty ? null : _shareMirrorUrl,
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Share Freedium link',
          ),
          IconButton(
            onPressed: _originalUrl == null ? null : _openOriginal,
            icon: const Icon(Icons.launch),
            tooltip: 'Open original',
          ),
          IconButton(
            onPressed: _mirrorUrl.isEmpty
                ? null
                : () =>
                      context.read<StorageService>().toggleBookmark(_mirrorUrl),
            icon: Icon(isBookmarked ? Icons.bookmark : Icons.bookmark_border),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_errorText == null && _mirrorUrl.isNotEmpty)
            Container(
              color: webViewColor,
              child: WebViewWidget(controller: _controller),
            ),
          if (_errorText != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_errorText!, textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: _retry,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            ),
          if (_isLoading && _errorText == null)
            Center(
              child: CircularProgressIndicator(
                color: pageTheme.colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }
}

class _PageColors {
  const _PageColors({
    required this.background,
    required this.foreground,
    required this.surface,
    required this.muted,
    required this.link,
  });

  final Color background;
  final Color foreground;
  final Color surface;
  final Color muted;
  final Color link;
}

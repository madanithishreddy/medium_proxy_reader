// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _isLoading = true;
              _errorText = null;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() {
              _isLoading = false;
            });
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
            final isMedium = host == 'medium.com' || host == 'www.medium.com';

            if (isMirror || isMedium) {
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

  Future<void> _retry() async {
    if (_mirrorUrl.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    await _controller.loadRequest(Uri.parse(_mirrorUrl));
  }

  String _themeLabel(AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.original:
        return 'Theme: Original';
      case AppThemeMode.light:
        return 'Theme: Light';
      case AppThemeMode.dark:
        return 'Theme: Dark';
    }
  }

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();
    final themeProvider = context.watch<ThemeProvider>();
    final isBookmarked =
        _mirrorUrl.isNotEmpty && storage.isBookmarked(_mirrorUrl);
    final webViewColor = themeProvider.webViewBackgroundOverride;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Medium Proxy Reader'),
        actions: [
          PopupMenuButton<AppThemeMode>(
            tooltip: _themeLabel(themeProvider.themeMode),
            onSelected: (mode) {
              context.read<ThemeProvider>().setThemeMode(mode);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: AppThemeMode.original,
                child: Text('Original theme'),
              ),
              PopupMenuItem(
                value: AppThemeMode.light,
                child: Text('Light theme'),
              ),
              PopupMenuItem(
                value: AppThemeMode.dark,
                child: Text('Dark theme'),
              ),
            ],
            icon: const Icon(Icons.palette_outlined),
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
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

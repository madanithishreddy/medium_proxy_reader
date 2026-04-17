import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'ArticleView.dart';
import 'StorageService.dart';
import 'ThemeProvider.dart';
import 'UrlTransformer.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final storageService = StorageService();
  await storageService.initialize();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeProvider>(create: (_) => ThemeProvider()),
        ChangeNotifierProvider<StorageService>.value(value: storageService),
      ],
      child: const MediumProxyReaderApp(),
    ),
  );
}

class MediumProxyReaderApp extends StatelessWidget {
  const MediumProxyReaderApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'Medium Proxy Reader',
      themeMode: themeProvider.materialThemeMode,
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: const DeepLinkRouterScreen(),
    );
  }
}

class DeepLinkRouterScreen extends StatefulWidget {
  const DeepLinkRouterScreen({super.key});

  @override
  State<DeepLinkRouterScreen> createState() => _DeepLinkRouterScreenState();
}

class _DeepLinkRouterScreenState extends State<DeepLinkRouterScreen> {
  final AppLinks _appLinks = AppLinks();
  final UrlTransformer _transformer = UrlTransformer();

  StreamSubscription<Uri>? _sub;
  String? _mediumUrl;

  @override
  void initState() {
    super.initState();
    _initLinks();
  }

  Future<void> _initLinks() async {
    final initialUri = await _appLinks.getInitialLink();
    if (initialUri != null) {
      _setMediumUrl(initialUri.toString());
    }

    _sub = _appLinks.uriLinkStream.listen((uri) {
      _setMediumUrl(uri.toString());
    });
  }

  void _setMediumUrl(String rawUrl) {
    if (!_transformer.canHandle(rawUrl)) {
      return;
    }

    if (!mounted) return;
    setState(() {
      _mediumUrl = rawUrl;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_mediumUrl != null) {
      return ArticleView(mediumUrl: _mediumUrl!);
    }

    return const HomeScreen();
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = context.watch<StorageService>();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Medium Proxy Reader'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.home_outlined), text: 'Home'),
              Tab(icon: Icon(Icons.bookmark_outline), text: 'Bookmarks'),
              Tab(icon: Icon(Icons.history), text: 'History'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _HomeTab(
              bookmarkCount: storage.bookmarks.length,
              historyCount: storage.history.length,
            ),
            _ArticleListTab(
              title: 'Bookmarked Articles',
              emptyText: 'No bookmarks yet. Save articles from the reader.',
              items: storage.bookmarks,
              canClear: false,
            ),
            _ArticleListTab(
              title: 'Reading History',
              emptyText: 'No reading history yet. Open a link to get started.',
              items: storage.history,
              canClear: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({required this.bookmarkCount, required this.historyCount});

  final int bookmarkCount;
  final int historyCount;

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final gradient = isDark
        ? const [Color(0xFF13223A), Color(0xFF1E2E4A)]
        : const [Color(0xFFE9F2FF), Color(0xFFDDE8FF)];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Read Medium Without Paywall Friction',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Open any medium.com link and this app routes it through the mirror automatically.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _MetricCard(
                label: 'Bookmarks',
                value: '$bookmarkCount',
                icon: Icons.bookmark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MetricCard(
                label: 'History',
                value: '$historyCount',
                icon: Icons.history,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Reader Theme',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AppThemeMode>(
                  initialValue: themeProvider.themeMode,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      context.read<ThemeProvider>().setThemeMode(value);
                    }
                  },
                  items: const [
                    DropdownMenuItem(
                      value: AppThemeMode.original,
                      child: Text('Original'),
                    ),
                    DropdownMenuItem(
                      value: AppThemeMode.light,
                      child: Text('Light'),
                    ),
                    DropdownMenuItem(
                      value: AppThemeMode.dark,
                      child: Text('Dark'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 10),
            Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(label),
          ],
        ),
      ),
    );
  }
}

class _ArticleListTab extends StatelessWidget {
  const _ArticleListTab({
    required this.title,
    required this.emptyText,
    required this.items,
    required this.canClear,
  });

  final String title;
  final String emptyText;
  final List<String> items;
  final bool canClear;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (canClear && items.isNotEmpty)
                TextButton.icon(
                  onPressed: () {
                    context.read<StorageService>().clearHistory();
                  },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Clear'),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(emptyText, textAlign: TextAlign.center),
                  ),
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, dividerIndex) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = items[index];

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      title: Text(
                        Uri.tryParse(item)?.pathSegments.lastOrNull
                                ?.replaceAll('-', ' ')
                                .replaceAll('_', ' ') ??
                            item,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        item,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ArticleView(mediumUrl: item),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

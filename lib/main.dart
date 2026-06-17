import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app_info.dart';
import 'models/time_event.dart';
import 'screens/event_list_screen.dart';
import 'screens/files_screen.dart';
import 'screens/note_list_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/todo_screen.dart';
import 'screens/welcome_screen.dart';
import 'theme/app_theme.dart';
import 'utils/app_localizations.dart';
import 'utils/app_preferences_service.dart';
import 'utils/cloud_sync_service.dart';
import 'utils/file_library_service.dart';
import 'utils/notification_service.dart';
import 'utils/persistence.dart';

const _welcomeSeenKey = 'welcome_seen_v3';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  await NotificationService.instance.initialize();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AppPreferences>(
      valueListenable: AppPreferencesService.instance.notifier,
      builder: (context, preferences, _) {
        final l10n = AppLocalizations(preferences);
        return MaterialApp(
          title: '$appDisplayName $appVersion',
          localizationsDelegates:
              FlutterQuillLocalizations.localizationsDelegates,
          supportedLocales: FlutterQuillLocalizations.supportedLocales,
          theme: AppTheme.light(),
          home: AppBootstrap(appTitle: l10n.appName),
        );
      },
    );
  }
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key, required this.appTitle});

  final String appTitle;

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  bool? _showWelcome;

  @override
  void initState() {
    super.initState();
    _loadWelcomeState();
  }

  Future<void> _loadWelcomeState() async {
    final prefs = await SharedPreferences.getInstance();
    await AppPreferencesService.instance.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _showWelcome = !(prefs.getBool(_welcomeSeenKey) ?? false);
    });
  }

  Future<void> _dismissWelcome() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_welcomeSeenKey, true);
    if (!mounted) {
      return;
    }
    setState(() {
      _showWelcome = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final showWelcome = _showWelcome;
    if (showWelcome == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (showWelcome) {
      return WelcomeScreen(onContinue: _dismissWelcome);
    }
    return MyHomePage(title: widget.appTitle);
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late final PageController _pageController;
  final FileLibraryService _fileLibraryService = FileLibraryService();
  final GlobalKey<FilesScreenState> _filesKey = GlobalKey<FilesScreenState>();
  int _currentIndex = 0;
  List<TimeEvent> _events = [];
  Set<String> _selectedIds = {};
  bool _isSelectionMode = false;
  bool _isLoading = true;
  StreamSubscription<List<SharedMediaFile>>? _shareSubscription;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _bootstrap();
    _listenForSharedContent();
  }

  @override
  void dispose() {
    _shareSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await _loadEvents();
    unawaited(_syncAndReload());
  }

  Future<void> _syncAndReload() async {
    await CloudSyncService.instance.syncNow();
    await _loadEvents();
  }

  Future<void> _loadEvents() async {
    final events = await PersistenceService().loadEvents();
    if (!mounted) {
      return;
    }
    setState(() {
      _events = events;
      _isLoading = false;
    });
  }

  void _listenForSharedContent() {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }
    _shareSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      _handleSharedMedia,
    );
    unawaited(
      ReceiveSharingIntent.instance.getInitialMedia().then((media) {
        if (media.isNotEmpty) {
          _handleSharedMedia(media);
          ReceiveSharingIntent.instance.reset();
        }
      }),
    );
  }

  Future<void> _handleSharedMedia(List<SharedMediaFile> media) async {
    if (media.isEmpty) {
      return;
    }
    var imported = 0;
    try {
      for (final item in media) {
        if (item.type == SharedMediaType.text ||
            item.type == SharedMediaType.url) {
          final text = item.path.trim();
          if (text.isEmpty) {
            continue;
          }
          await _fileLibraryService.addSharedText(text);
        } else {
          await _fileLibraryService.addFile(item.path, mimeType: item.mimeType);
        }
        imported++;
      }
      await _filesKey.currentState?.refresh();
      if (!mounted || imported == 0) {
        return;
      }
      _navigateToFilesTab();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.addedItemsToFiles(imported))),
      );
    } on FileLibraryException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.localizeError(error.message))),
      );
    }
  }

  void _navigateToFilesTab() {
    if (Platform.isMacOS) {
      return;
    }
    const filesIndex = 4;
    if (_currentIndex == filesIndex) {
      return;
    }
    setState(() {
      _currentIndex = filesIndex;
    });
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        filesIndex,
        duration: AppTheme.medium,
        curve: Curves.easeOutCubic,
      );
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(filesIndex);
      }
    });
  }

  Future<void> _saveEvents() async {
    await PersistenceService().saveEvents(_events);
  }

  void _addEvent(TimeEvent event) {
    setState(() {
      _events.insert(0, event);
    });
    _saveEvents();
  }

  void _deleteSelected(Set<String> selectedIds) {
    setState(() {
      _selectedIds = selectedIds;
    });
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      if (!_isSelectionMode) {
        _selectedIds.clear();
      }
    });
  }

  Future<void> _performDelete() async {
    if (_selectedIds.isEmpty) {
      return;
    }

    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.l10n.deleteSelectedEntries),
            content: Text(
              context.l10n.deleteEntriesMessage(_selectedIds.length),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(context.l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(context.l10n.delete),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete || !mounted) {
      return;
    }

    setState(() {
      _events.removeWhere((event) => _selectedIds.contains(event.id));
      _selectedIds.clear();
      _isSelectionMode = false;
    });
    await _saveEvents();
  }

  void _onNavigate(int index) async {
    if (_isSelectionMode && index != 0) {
      _toggleSelectionMode();
    }
    setState(() {
      _currentIndex = index;
    });
    await _pageController.animateToPage(
      index,
      duration: AppTheme.medium,
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final filesEnabled = !Platform.isMacOS;
    final l10n = context.l10n;
    final screens = [
      EventListScreen(
        events: _events,
        onAdd: _addEvent,
        onDeleteSelected: _deleteSelected,
        isSelectionMode: _isSelectionMode,
        selectedIds: _selectedIds,
        onToggleSelectionMode: _toggleSelectionMode,
      ),
      StatisticsScreen(events: _events),
      const NoteListScreen(),
      const TodoScreen(),
      if (filesEnabled) FilesScreen(key: _filesKey),
    ];

    final navItems = [
      NavigationRailDestination(
        icon: const Icon(Icons.view_agenda_outlined),
        selectedIcon: const Icon(Icons.view_agenda),
        label: Text(l10n.navEntries),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.query_stats_outlined),
        selectedIcon: const Icon(Icons.query_stats),
        label: Text(l10n.navInsights),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.sticky_note_2_outlined),
        selectedIcon: const Icon(Icons.sticky_note_2),
        label: Text(l10n.navNotes),
      ),
      NavigationRailDestination(
        icon: const Icon(Icons.checklist_outlined),
        selectedIcon: const Icon(Icons.checklist),
        label: Text(l10n.navTasks),
      ),
      if (filesEnabled)
        NavigationRailDestination(
          icon: const Icon(Icons.folder_copy_outlined),
          selectedIcon: const Icon(Icons.folder_copy),
          label: Text(l10n.navFiles),
        ),
    ];

    return PopScope(
      canPop: !(_currentIndex == 0 && _isSelectionMode),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex == 0 && _isSelectionMode) {
          _toggleSelectionMode();
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 700;

          final pageView = PageView(
            controller: _pageController,
            onPageChanged: (index) {
              if (_isSelectionMode && index != 0) {
                _toggleSelectionMode();
              }
              setState(() {
                _currentIndex = index;
              });
            },
            children: screens,
          );

          if (isWide) {
            return Scaffold(
              body: Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      border: const Border(
                        right: BorderSide(color: AppTheme.border),
                      ),
                    ),
                    child: NavigationRail(
                      selectedIndex: _currentIndex,
                      onDestinationSelected: _onNavigate,
                      labelType: NavigationRailLabelType.all,
                      backgroundColor: AppTheme.surface,
                      indicatorColor: AppTheme.primarySoft,
                      selectedIconTheme: const IconThemeData(
                        color: AppTheme.primary,
                      ),
                      unselectedIconTheme: const IconThemeData(
                        color: AppTheme.muted,
                      ),
                      selectedLabelTextStyle: const TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      unselectedLabelTextStyle: const TextStyle(
                        color: AppTheme.muted,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                      leading: const SizedBox(height: 12),
                      destinations: navItems,
                    ),
                  ),
                  Expanded(child: pageView),
                ],
              ),
              floatingActionButton: _currentIndex == 0 && _isSelectionMode
                  ? FloatingActionButton(
                      onPressed: _performDelete,
                      backgroundColor: AppTheme.danger,
                      child: const Icon(Icons.delete),
                    )
                  : null,
            );
          }

          return Scaffold(
            body: pageView,
            bottomNavigationBar: SafeArea(
              child: Container(
                margin: const EdgeInsets.fromLTRB(14, 0, 14, 12),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: BottomNavigationBar(
                    backgroundColor: AppTheme.surface,
                    currentIndex: _currentIndex,
                    onTap: _onNavigate,
                    items: [
                      BottomNavigationBarItem(
                        icon: const Icon(Icons.view_agenda_outlined),
                        activeIcon: const Icon(Icons.view_agenda),
                        label: l10n.navEntries,
                      ),
                      BottomNavigationBarItem(
                        icon: const Icon(Icons.query_stats_outlined),
                        activeIcon: const Icon(Icons.query_stats),
                        label: l10n.navInsights,
                      ),
                      BottomNavigationBarItem(
                        icon: const Icon(Icons.sticky_note_2_outlined),
                        activeIcon: const Icon(Icons.sticky_note_2),
                        label: l10n.navNotes,
                      ),
                      BottomNavigationBarItem(
                        icon: const Icon(Icons.checklist_outlined),
                        activeIcon: const Icon(Icons.checklist),
                        label: l10n.navTasks,
                      ),
                      if (filesEnabled)
                        BottomNavigationBarItem(
                          icon: const Icon(Icons.folder_copy_outlined),
                          activeIcon: const Icon(Icons.folder_copy),
                          label: l10n.navFiles,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            floatingActionButton: _currentIndex == 0 && _isSelectionMode
                ? FloatingActionButton(
                    onPressed: _performDelete,
                    backgroundColor: AppTheme.danger,
                    child: const Icon(Icons.delete),
                  )
                : null,
          );
        },
      ),
    );
  }
}

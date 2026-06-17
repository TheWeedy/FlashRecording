import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'app_info.dart';
import 'models/time_event.dart';
import 'screens/event_list_screen.dart';
import 'screens/note_list_screen.dart';
import 'screens/statistics_screen.dart';
import 'screens/todo_screen.dart';
import 'screens/welcome_screen.dart';
import 'theme/app_theme.dart';
import 'utils/cloud_sync_service.dart';
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
    return MaterialApp(
      title: '$appDisplayName $appVersion',
      localizationsDelegates: FlutterQuillLocalizations.localizationsDelegates,
      supportedLocales: FlutterQuillLocalizations.supportedLocales,
      theme: AppTheme.light(),
      home: const AppBootstrap(),
    );
  }
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

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
    return const MyHomePage(title: 'Record My Time');
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
  int _currentIndex = 0;
  List<TimeEvent> _events = [];
  Set<String> _selectedIds = {};
  bool _isSelectionMode = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _bootstrap();
  }

  @override
  void dispose() {
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
            title: const Text('Delete selected entries?'),
            content: Text(
              'This will remove ${_selectedIds.length} selected entries from this device and the next sync snapshot.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
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
    ];

    const navItems = [
      NavigationRailDestination(
        icon: Icon(Icons.view_agenda_outlined),
        selectedIcon: Icon(Icons.view_agenda),
        label: Text('Entries'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.query_stats_outlined),
        selectedIcon: Icon(Icons.query_stats),
        label: Text('Insights'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.sticky_note_2_outlined),
        selectedIcon: Icon(Icons.sticky_note_2),
        label: Text('Notes'),
      ),
      NavigationRailDestination(
        icon: Icon(Icons.checklist_outlined),
        selectedIcon: Icon(Icons.checklist),
        label: Text('Tasks'),
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
                    items: const [
                      BottomNavigationBarItem(
                        icon: Icon(Icons.view_agenda_outlined),
                        activeIcon: Icon(Icons.view_agenda),
                        label: 'Entries',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.query_stats_outlined),
                        activeIcon: Icon(Icons.query_stats),
                        label: 'Insights',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.sticky_note_2_outlined),
                        activeIcon: Icon(Icons.sticky_note_2),
                        label: 'Notes',
                      ),
                      BottomNavigationBarItem(
                        icon: Icon(Icons.checklist_outlined),
                        activeIcon: Icon(Icons.checklist),
                        label: 'Tasks',
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

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
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: Color(0xFF2448C6),
          unselectedItemColor: Color(0xFF6B7280),
          type: BottomNavigationBarType.fixed,
          showUnselectedLabels: true,
          elevation: 12,
        ),
      ),
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
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (showWelcome) {
      return WelcomeScreen(onContinue: _dismissWelcome);
    }
    return const MyHomePage(title: '我的时间事件');
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

    final shouldDelete = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('确认删除'),
            content: Text('确定删除已选择的 ${_selectedIds.length} 条记录吗？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('删除'),
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

    return PopScope(
      canPop: !(_currentIndex == 0 && _isSelectionMode),
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentIndex == 0 && _isSelectionMode) {
          _toggleSelectionMode();
        }
      },
      child: Scaffold(
        body: PageView(
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
        ),
        bottomNavigationBar: BottomNavigationBar(
          backgroundColor: Colors.white,
          currentIndex: _currentIndex,
          onTap: (index) async {
            if (_isSelectionMode && index != 0) {
              _toggleSelectionMode();
            }
            setState(() {
              _currentIndex = index;
            });
            await _pageController.animateToPage(
              index,
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
            );
          },
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.list), label: '列表'),
            BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '统计'),
            BottomNavigationBarItem(icon: Icon(Icons.sticky_note_2), label: '笔记'),
            BottomNavigationBarItem(icon: Icon(Icons.checklist), label: '待办'),
          ],
        ),
        floatingActionButton: _currentIndex == 0 && _isSelectionMode
            ? FloatingActionButton(
                onPressed: _performDelete,
                backgroundColor: Colors.red,
                child: const Icon(Icons.delete),
              )
            : null,
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'models/time_event.dart';
import 'screens/event_list_screen.dart';
import 'screens/statistics_screen.dart';
import 'utils/persistence.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '时间事件记录',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: '我的时间事件'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _currentIndex = 0;
  List<TimeEvent> _events = [];
  Set<String> _selectedIds = {};
  bool _isSelectionMode = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final events = await PersistenceService().loadEvents();
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

  void _performDelete() {
    if (_selectedIds.isEmpty) return;
    setState(() {
      _events.removeWhere((event) => _selectedIds.contains(event.id));
      _selectedIds.clear();
      _isSelectionMode = false;
    });
    _saveEvents();
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
    ];

    return WillPopScope(
      onWillPop: () async {
        if (_currentIndex == 0 && _isSelectionMode) {
          _toggleSelectionMode();
          return false;
        }
        return true;
      },
      child: Scaffold(
        body: screens[_currentIndex],
        bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          if (_isSelectionMode && index != 0) {
            // 如果在选择模式，切到统计页前退出
            _toggleSelectionMode();
          }
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.list), label: '列表'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: '统计'),
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
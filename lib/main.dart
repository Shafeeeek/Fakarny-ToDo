// main.dart
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TodoApp());
}

const String _kThemePrefKey =
    'theme_mode_pref'; // 0 = system, 1 = light, 2 = dark

class TodoItem {
  String id;
  String title;
  bool done;
  DateTime createdAt;
  DateTime? completedAt;

  TodoItem({
    required this.id,
    required this.title,
    this.done = false,
    DateTime? createdAt,
    this.completedAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class TodoApp extends StatefulWidget {
  const TodoApp({super.key});

  @override
  State<TodoApp> createState() => _TodoAppState();
}

class _TodoAppState extends State<TodoApp> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _loadedPref = false;

  @override
  void initState() {
    super.initState();
    _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getInt(_kThemePrefKey) ?? 0;
    setState(() {
      _themeMode = (stored == 1)
          ? ThemeMode.light
          : (stored == 2)
          ? ThemeMode.dark
          : ThemeMode.system;
      _loadedPref = true;
    });
  }

  Future<void> _saveThemeMode(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    final v = (mode == ThemeMode.system)
        ? 0
        : (mode == ThemeMode.light)
        ? 1
        : 2;
    await prefs.setInt(_kThemePrefKey, v);
  }

  void _cycleThemeMode() {
    setState(() {
      if (_themeMode == ThemeMode.system)
        _themeMode = ThemeMode.light;
      else if (_themeMode == ThemeMode.light)
        _themeMode = ThemeMode.dark;
      else
        _themeMode = ThemeMode.system;
    });
    _saveThemeMode(_themeMode);
  }

  void _setThemeMode(ThemeMode mode) {
    setState(() {
      _themeMode = mode;
    });
    _saveThemeMode(mode);
  }

  @override
  Widget build(BuildContext context) {
    final lightTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.light,
      ),
      textTheme: GoogleFonts.interTextTheme(),
      scaffoldBackgroundColor: const Color(0xFFF4F6FA),
    );

    final darkTheme = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.deepPurple,
        brightness: Brightness.dark,
      ),
      textTheme: GoogleFonts.interTextTheme(),
      scaffoldBackgroundColor: const Color(0xFF0B1020),
    );

    if (!_loadedPref) {
      return MaterialApp(home: const SizedBox.shrink());
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Fakarny ToDo',
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: _themeMode,
      builder: (context, child) {
        final platformBrightness =
            WidgetsBinding.instance.window.platformBrightness;
        final effectiveTheme = (_themeMode == ThemeMode.system)
            ? (platformBrightness == Brightness.dark ? darkTheme : lightTheme)
            : (_themeMode == ThemeMode.dark ? darkTheme : lightTheme);

        return AnimatedTheme(
          data: effectiveTheme,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOut,
          child: child!,
        );
      },
      home: MainScreen(
        onCycleTheme: _cycleThemeMode,
        onSetThemeMode: _setThemeMode,
        currentThemeMode: _themeMode,
      ),
    );
  }
}

/// MainScreen holds the bottom navigation and shares the data across pages.
class MainScreen extends StatefulWidget {
  final VoidCallback onCycleTheme;
  final void Function(ThemeMode) onSetThemeMode;
  final ThemeMode currentThemeMode;

  const MainScreen({
    super.key,
    required this.onCycleTheme,
    required this.onSetThemeMode,
    required this.currentThemeMode,
  });

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  int _currentIndex = 0;

  // Data store (in-memory). Can be swapped with persistent DB later.
  final List<TodoItem> _items = [];
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  late final AnimationController _bgPulseController;

  @override
  void initState() {
    super.initState();
    _bgPulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    // sample starter item
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        final sample = TodoItem(
          id: UniqueKey().toString(),
          title: 'Welcome — add your tasks',
        );
        _items.insert(0, sample);
        _listKey.currentState?.insertItem(
          0,
          duration: const Duration(milliseconds: 400),
        );
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _bgPulseController.dispose();
    super.dispose();
  }

  void _insertItem(TodoItem item) {
    _items.insert(0, item);
    _listKey.currentState?.insertItem(
      0,
      duration: const Duration(milliseconds: 450),
    );
    setState(() {});
  }

  void _removeItem(int index) {
    if (index < 0 || index >= _items.length) return;
    final removed = _items.removeAt(index);
    _listKey.currentState?.removeItem(
      index,
      (context, animation) =>
          _buildTile(removed, index, animation, removing: true),
      duration: const Duration(milliseconds: 400),
    );
    setState(() {});
  }

  void _toggleDone(int index) {
    setState(() {
      final it = _items[index];
      it.done = !it.done;
      it.completedAt = it.done ? DateTime.now() : null;
    });
  }

  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year)
      return 'Today';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  Widget _buildTile(
    TodoItem item,
    int index,
    Animation<double> animation, {
    bool removing = false,
  }) {
    return SizeTransition(
      sizeFactor: animation,
      axisAlignment: 0.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
        child: GestureDetector(
          onTap: () => _toggleDone(index),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 350),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: item.done
                      ? LinearGradient(
                          colors: [
                            Colors.green.shade400.withOpacity(0.12),
                            Colors.transparent,
                          ],
                        )
                      : LinearGradient(
                          colors: [
                            Colors.white.withOpacity(0.05),
                            Colors.white.withOpacity(0.02),
                          ],
                        ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: Colors.white.withOpacity(0.03)),
                ),
                child: Row(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      transitionBuilder: (child, anim) =>
                          ScaleTransition(scale: anim, child: child),
                      child: item.done
                          ? const Icon(
                              Icons.check_circle,
                              key: ValueKey('done'),
                              color: Colors.white,
                            )
                          : Icon(
                              Icons.radio_button_unchecked,
                              key: const ValueKey('pending'),
                              color: Colors.grey.shade400,
                            ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 16,
                              decoration: item.done
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              color: item.done
                                  ? Colors.grey.shade400
                                  : Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                _formatDate(item.createdAt),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.6),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (!item.done)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.03),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Text(
                                    'Today',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        _removeItem(index);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('"${item.title}" removed'),
                            action: SnackBarAction(
                              label: 'Undo',
                              onPressed: () {
                                setState(() {
                                  _items.insert(index, item);
                                  _listKey.currentState?.insertItem(
                                    index,
                                    duration: const Duration(milliseconds: 350),
                                  );
                                });
                              },
                            ),
                          ),
                        );
                      },
                      child: const Icon(Icons.delete_outline, size: 22),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _themeModeIcon(ThemeMode mode) {
    final icon = (mode == ThemeMode.system)
        ? Icons.brightness_auto
        : (mode == ThemeMode.light)
        ? Icons.wb_sunny
        : Icons.dark_mode;

    final tooltip = (mode == ThemeMode.system)
        ? 'System theme'
        : (mode == ThemeMode.light ? 'Light theme' : 'Dark theme');

    return Tooltip(message: tooltip, child: Icon(icon));
  }

  // Pages
  // ignore: unused_field
  late final List<Widget> _pages = [
    // Home
    HomePage(
      listKey: _listKey,
      getItems: () => _items,
      buildTile: _buildTile,
      onAdd: (title) =>
          _insertItem(TodoItem(id: UniqueKey().toString(), title: title)),
      onToggle: (idx) => _toggleDone(idx),
      onRemove: (idx) => _removeItem(idx),
      bgPulseController: _bgPulseController,
      themeIconBuilder: () => _themeModeIcon(widget.currentThemeMode),
      onCycleTheme: widget.onCycleTheme,
    ),

    // History
    HistoryPage(
      getItems: () => _items.where((i) => i.done).toList(),
      onDeleteFromHistory: (id) {
        final idx = _items.indexWhere((e) => e.id == id);
        if (idx != -1) _removeItem(idx);
      },
    ),

    // Calendar
    CalendarPage(getItems: () => _items),

    // Settings
    SettingsPage(
      currentThemeMode: widget.currentThemeMode,
      onSetThemeMode: widget.onSetThemeMode,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final theme = Theme.of(context);

    // Rebuild pages list to pass updated references (like theme icon)
    final pages = [
      HomePage(
        listKey: _listKey,
        getItems: () => _items,
        buildTile: _buildTile,
        onAdd: (title) =>
            _insertItem(TodoItem(id: UniqueKey().toString(), title: title)),
        onToggle: (idx) => _toggleDone(idx),
        onRemove: (idx) => _removeItem(idx),
        bgPulseController: _bgPulseController,
        themeIconBuilder: () => _themeModeIcon(widget.currentThemeMode),
        onCycleTheme: widget.onCycleTheme,
      ),
      HistoryPage(
        getItems: () => _items.where((i) => i.done).toList(),
        onDeleteFromHistory: (id) {
          final idx = _items.indexWhere((e) => e.id == id);
          if (idx != -1) _removeItem(idx);
        },
      ),
      CalendarPage(getItems: () => _items),
      SettingsPage(
        currentThemeMode: widget.currentThemeMode,
        onSetThemeMode: widget.onSetThemeMode,
      ),
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Fakarny ToDo'),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: GestureDetector(
              onTap: widget.onCycleTheme,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, animation) => RotationTransition(
                  turns: animation,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: SizedBox(
                  key: ValueKey(widget.currentThemeMode),
                  width: 46,
                  height: 46,
                  child: Center(child: _themeModeIcon(widget.currentThemeMode)),
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded),
            onPressed: () {
              // open bottom sheet as a quick filter
              showModalBottomSheet<void>(
                context: context,
                backgroundColor: Theme.of(context).colorScheme.surface,
                builder: (context) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          leading: const Icon(Icons.sort),
                          title: const Text('Sort: Pending first'),
                          onTap: () {
                            Navigator.of(context).pop();
                            setState(() {
                              _items.sort((a, b) => a.done ? 1 : -1);
                            });
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.filter_list),
                          title: const Text('Show only pending'),
                          onTap: () {
                            Navigator.of(context).pop();
                            setState(() {
                              _items.retainWhere((i) => !i.done);
                            });
                          },
                        ),
                        ListTile(
                          leading: const Icon(Icons.clear_all),
                          title: const Text('Clear completed'),
                          onTap: () {
                            Navigator.of(context).pop();
                            setState(() {
                              _items.removeWhere((i) => i.done);
                            });
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _bgPulseController,
              builder: (context, child) {
                final v = _bgPulseController.value;
                final isDark = Theme.of(context).brightness == Brightness.dark;
                final start = isDark
                    ? const Color(0xFF22324A)
                    : const Color(0xFF46C4FF);
                final end = isDark
                    ? const Color(0xFF0B2B18)
                    : const Color(0xFFA8F75A);
                return Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment(-0.6 + v * 1.2, -0.5 + v * 0.6),
                      radius: 1.2,
                      colors: [start, end],
                    ),
                  ),
                );
              },
            ),
          ),
          // Selected page
          SafeArea(child: pages[_currentIndex]),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.transparent,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'History'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Calendar',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        onTap: (i) => setState(() => _currentIndex = i),
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () => _openAddSheet(),
              elevation: 6,
              label: const Text('Add task'),
              icon: const Icon(Icons.add_task_rounded),
            )
          : null,
    );
  }

  Future<void> _openAddSheet() async {
    final newTitle = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _AddTaskSheet(),
    );

    if (newTitle != null && newTitle.trim().isNotEmpty) {
      _insertItem(TodoItem(id: UniqueKey().toString(), title: newTitle.trim()));
    }
  }
}

/// Home Page (AnimatedList) - receives callbacks and state pieces from MainScreen
class HomePage extends StatelessWidget {
  final GlobalKey<AnimatedListState> listKey;
  final List<TodoItem> Function() getItems;
  final Widget Function(TodoItem, int, Animation<double>, {bool removing})
  buildTile;
  final void Function(String title) onAdd;
  final void Function(int index) onToggle;
  final void Function(int index) onRemove;
  final AnimationController bgPulseController;
  final Widget Function() themeIconBuilder;
  final VoidCallback onCycleTheme;

  const HomePage({
    super.key,
    required this.listKey,
    required this.getItems,
    required this.buildTile,
    required this.onAdd,
    required this.onToggle,
    required this.onRemove,
    required this.bgPulseController,
    required this.themeIconBuilder,
    required this.onCycleTheme,
  });

  // ignore: unused_element
  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year)
      return 'Today';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final items = getItems();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Good day,',
                    style: TextStyle(color: Colors.white.withOpacity(0.85)),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Organize your day',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              CircleAvatar(
                radius: 24,
                backgroundColor: Colors.white.withOpacity(0.12),
                child: const Icon(Icons.check, color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(28),
                topRight: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 30,
                  offset: const Offset(0, -12),
                ),
              ],
            ),
            child: Column(
              children: [
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Text(
                        'Today',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${items.length} tasks',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () {
                          // sort pending first
                          items.sort((a, b) => a.done ? 1 : -1);
                        },
                        icon: const Icon(Icons.sort),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: AnimatedList(
                    key: listKey,
                    initialItemCount: items.length,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index, animation) {
                      final item = items[index];
                      return Dismissible(
                        key: ValueKey(item.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          margin: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 6,
                          ),
                          padding: const EdgeInsets.only(right: 20),
                          alignment: Alignment.centerRight,
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        onDismissed: (dir) => onRemove(index),
                        child: buildTile(item, index, animation),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// History Page - shows completed tasks
class HistoryPage extends StatelessWidget {
  final List<TodoItem> Function() getItems;
  final void Function(String id) onDeleteFromHistory;

  const HistoryPage({
    super.key,
    required this.getItems,
    required this.onDeleteFromHistory,
  });

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final items = getItems();
    final theme = Theme.of(context);

    return Column(
      children: [
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                'History',
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Text(
                '${items.length} done',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text(
                    'No completed tasks yet',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  itemBuilder: (context, idx) {
                    final it = items[idx];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      tileColor: Colors.white.withOpacity(0.02),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      title: Text(
                        it.title,
                        style: const TextStyle(
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      subtitle: Text(
                        'Completed: ${_formatDateTime(it.completedAt)}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => onDeleteFromHistory(it.id),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Calendar Page - shows tasks for selected day (createdAt)
class CalendarPage extends StatefulWidget {
  final List<TodoItem> Function() getItems;

  const CalendarPage({super.key, required this.getItems});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  List<TodoItem> _tasksForSelectedDay() {
    final all = widget.getItems();
    final sel = _selectedDay ?? _focusedDay;
    return all.where((t) {
      final d = t.createdAt;
      return d.year == sel.year && d.month == sel.month && d.day == sel.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tasks = _tasksForSelectedDay();

    return Column(
      children: [
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2035, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) {
              if (_selectedDay == null) return false;
              return day.year == _selectedDay!.year &&
                  day.month == _selectedDay!.month &&
                  day.day == _selectedDay!.day;
            },
            onDaySelected: (selected, focused) {
              setState(() {
                _selectedDay = selected;
                _focusedDay = focused;
              });
            },
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
              selectedDecoration: BoxDecoration(
                color: theme.colorScheme.secondary,
                shape: BoxShape.circle,
              ),
              defaultTextStyle: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Text(
                'Tasks on selected day',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              Text(
                '${tasks.length} tasks',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: tasks.isEmpty
              ? Center(
                  child: Text(
                    'No tasks created on this day',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white70,
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 12,
                  ),
                  itemCount: tasks.length,
                  itemBuilder: (context, idx) {
                    final t = tasks[idx];
                    return Card(
                      color: Colors.white.withOpacity(0.03),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text(
                          t.title,
                          style: TextStyle(
                            decoration: t.done
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                          ),
                        ),
                        subtitle: Text(
                          'Created: ${t.createdAt.day}/${t.createdAt.month}/${t.createdAt.year}',
                        ),
                        trailing: t.done
                            ? const Icon(Icons.check_circle)
                            : null,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Settings Page with Theme, About, Logo, and Social Links
class SettingsPage extends StatelessWidget {
  final ThemeMode currentThemeMode;
  final void Function(ThemeMode) onSetThemeMode;

  const SettingsPage({
    super.key,
    required this.currentThemeMode,
    required this.onSetThemeMode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    ThemeMode selected = currentThemeMode;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'Settings',
            style: theme.textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 18),

          // ✅ LOGO SECTION
          Center(
            child: Column(
              children: [
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.08),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.check_circle_rounded,
                      size: 55,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Modern ToDo',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                Text(
                  'Organize your day beautifully',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ✅ THEME SECTION
          Text('Theme', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            color: Colors.white.withOpacity(0.03),
            child: Column(
              children: [
                RadioListTile<ThemeMode>(
                  value: ThemeMode.system,
                  groupValue: selected,
                  onChanged: (v) {
                    if (v != null) onSetThemeMode(v);
                  },
                  title: const Text('System'),
                  secondary: const Icon(Icons.brightness_auto),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.light,
                  groupValue: selected,
                  onChanged: (v) {
                    if (v != null) onSetThemeMode(v);
                  },
                  title: const Text('Light'),
                  secondary: const Icon(Icons.wb_sunny),
                ),
                RadioListTile<ThemeMode>(
                  value: ThemeMode.dark,
                  groupValue: selected,
                  onChanged: (v) {
                    if (v != null) onSetThemeMode(v);
                  },
                  title: const Text('Dark'),
                  secondary: const Icon(Icons.dark_mode),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ✅ ABOUT SECTION
          Text('About', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            color: Colors.white.withOpacity(0.03),
            child: ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.white70),
              title: const Text('Modern ToDo App'),
              subtitle: const Text(
                'A modern task manager with history and calendar.',
              ),
            ),
          ),

          const SizedBox(height: 24),

          // ✅ SOCIAL LINKS SECTION
          Text('Follow Me', style: theme.textTheme.titleMedium),
          const SizedBox(height: 10),

          Card(
            color: Colors.white.withOpacity(0.03),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.code, color: Colors.white),
                  title: const Text('GitHub'),
                  subtitle: const Text('github.com/Shafeeeek'),
                  onTap: () {
                    _openURL('https://github.com/Shafeeeek');
                  },
                ),
                const Divider(height: 1),

                ListTile(
                  leading: const Icon(Icons.work, color: Colors.blueAccent),
                  title: const Text('LinkedIn'),
                  subtitle: const Text('linkedin.com/in/mohamed-a-shafeek-'),
                  onTap: () {
                    _openURL('https://www.linkedin.com/in/mohamed-a-shafeek-/');
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ✅ COPYRIGHT SECTION
          Center(
            child: Column(
              children: [
                const Text(
                  'Modern ToDo © 2025',
                  style: TextStyle(
                    color: Color.fromARGB(255, 254, 137, 4),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Developed by Shafeek',
                  style: TextStyle(
                    color: const Color.fromARGB(
                      255,
                      225,
                      118,
                      4,
                    ).withOpacity(0.85),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  // ✅ Open external URLs
  Future<void> _openURL(String url) async {
    final uri = Uri.parse(url);

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint("❌ Could not open: $url");
    }
  }
}

/// Add Task Sheet (same as before)
class _AddTaskSheet extends StatefulWidget {
  const _AddTaskSheet({Key? key}) : super(key: key);

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _controller = TextEditingController();
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {
        _isValid = _controller.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 250),
      padding: EdgeInsets.only(bottom: bottom),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.95),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Add a new task',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: 'What do you want to do?',
                filled: true,
                fillColor: Colors.white.withOpacity(0.03),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (value) {
                if (_isValid) Navigator.of(context).pop(value);
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isValid
                        ? () =>
                              Navigator.of(context).pop(_controller.text.trim())
                        : null,
                    child: const Text('Add task'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

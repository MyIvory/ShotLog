import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  void _goSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: _tab,
        children: [
          HomeScreen(onSettingsTap: _goSettings),
          const _PlaceholderPage(icon: Icons.photo_library_outlined, label: 'Галерея'),
          const _PlaceholderPage(icon: Icons.bar_chart_outlined, label: 'Статистика'),
        ],
      ),
      bottomNavigationBar: _NavBar(
        selectedIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;
  const _NavBar({required this.selectedIndex, required this.onTap});

  static const _items = [
    ('assets/icons/active/ic_session.svg',
     'assets/icons/inactive/ic_session.svg', 'Сесії'),
    ('assets/icons/active/ic_gallery.svg',
     'assets/icons/inactive/ic_gallery.svg', 'Галерея'),
    ('assets/icons/active/ic_settings.svg',
     'assets/icons/inactive/ic_settings.svg', 'Статист.'),
  ];

  @override
  Widget build(BuildContext context) {
    final bot = MediaQuery.of(context).padding.bottom;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: const BoxDecoration(
            color: Color(0x14FFFFFF),
            border: Border(top: BorderSide(color: Color(0x1EFFFFFF), width: 0.5)),
          ),
          child: Padding(
      padding: EdgeInsets.only(bottom: bot),
      child: Row(
        children: [
          for (int i = 0; i < _items.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onTap(i);
                },
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SvgPicture.asset(
                        selectedIndex == i ? _items[i].$1 : _items[i].$2,
                        width: 22, height: 22,
                        colorFilter: ColorFilter.mode(
                          selectedIndex == i
                              ? const Color(0xFFE87722)
                              : const Color(0x4DF0EAE5),
                          BlendMode.srcIn,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _items[i].$3,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: selectedIndex == i
                              ? const Color(0xFFE87722)
                              : const Color(0x4DF0EAE5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
          ),
        ),
      ),
    );
  }
}

class _PlaceholderPage extends StatelessWidget {
  final IconData icon;
  final String label;
  const _PlaceholderPage({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 72, color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: 16),
            Text(label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
            const SizedBox(height: 8),
            Text('Незабаром',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    )),
          ],
        ),
      ),
    );
  }
}

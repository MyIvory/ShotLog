import 'package:flutter/material.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [
          HomeScreen(),
          _PlaceholderPage(icon: Icons.photo_library_outlined, label: 'Галерея'),
          _PlaceholderPage(icon: Icons.bar_chart_outlined, label: 'Статистика'),
          SettingsScreen(),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: Color(0xFF2A1E16))),
        ),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: (i) => setState(() => _tab = i),
          destinations: [
            _dest('assets/icons/active/ic_session.svg',
                'assets/icons/inactive/ic_session.svg', 'Сесії'),
            _dest('assets/icons/active/ic_gallery.svg',
                'assets/icons/inactive/ic_gallery.svg', 'Галерея'),
            _dest('assets/icons/active/ic_stats.svg',
                'assets/icons/inactive/ic_stats.svg', 'Статист.'),
            _dest('assets/icons/active/ic_settings.svg',
                'assets/icons/inactive/ic_settings.svg', 'Налашт.'),
          ],
        ),
      ),
    );
  }

  NavigationDestination _dest(
      String activePath, String inactivePath, String label) {
    return NavigationDestination(
      icon: SvgPicture.asset(inactivePath, width: 22, height: 22),
      selectedIcon: SvgPicture.asset(activePath, width: 22, height: 22),
      label: label,
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

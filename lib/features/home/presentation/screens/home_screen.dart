import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen_reader/features/library/presentation/screens/library_screen.dart';
import 'package:lumen_reader/features/library/presentation/screens/recent_reading_screen.dart';
import 'package:lumen_reader/features/library/presentation/screens/files_screen.dart';
import 'package:lumen_reader/features/settings/presentation/screens/settings_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2E), // Dark background
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              children: [
                // Header with logo and title
                const SizedBox(height: 60),

                // Moon icon
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFC107),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFFC107).withAlpha((0.4 * 255).round()),
                        blurRadius: 30,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.nightlight_round,
                    color: Color(0xFF1E1E2E),
                    size: 50,
                  ),
                ),

                const SizedBox(height: 32),

                Text(
                  'Lumen Reader',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 32,
                    letterSpacing: 0.5,
                  ),
                ),

                const SizedBox(height: 12),

                Text(
                  'Sua biblioteca pessoal',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.white60,
                    fontSize: 18,
                    letterSpacing: 0.2,
                  ),
                ),

                const SizedBox(height: 80),

                // Menu options
                _MenuTile(
                  icon: Icons.history,
                  title: 'Lista recente',
                  subtitle: 'Continue de onde parou',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const RecentReadingScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                _MenuTile(
                  icon: Icons.library_books,
                  title: 'Minha estante',
                  subtitle: 'Todos os seus livros',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LibraryScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 24),

                _MenuTile(
                  icon: Icons.folder_open,
                  title: 'Meus Arquivos',
                  subtitle: 'Gerencie seus documentos',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const FilesScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 60),

                // Settings button at bottom
                _MenuTile(
                  icon: Icons.settings,
                  title: 'Configurações',
                  subtitle: 'Personalize sua experiência',
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SettingsScreen(),
                      ),
                    );
                  },
                ),

                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A3E),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withAlpha((0.1 * 255).round()), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha((0.2 * 255).round()),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: const Color(0xFF5C6BC0).withAlpha((0.2 * 255).round()),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: const Color(0xFF5C6BC0), size: 28),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white60,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white30,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_sizes.dart';
import '../../../shared/widgets/sayno_scaffold.dart';
import '../../../theme/text_styles.dart';
import '../../protection/application/limit_controller.dart';
import '../../protection/application/protection_controller.dart';

class BlockedAppsScreen extends ConsumerStatefulWidget {
  const BlockedAppsScreen({super.key});

  @override
  ConsumerState<BlockedAppsScreen> createState() => _BlockedAppsScreenState();
}

class _BlockedAppsScreenState extends ConsumerState<BlockedAppsScreen> {
  final _searchController = TextEditingController();
  List<Map<String, String>> _installedApps = [];
  List<Map<String, String>> _filteredApps = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadApps();
    _searchController.addListener(_filterApps);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadApps() async {
    final platformService = ref.read(protectionPlatformServiceProvider);
    final apps = await platformService.getInstalledApps();
    
    // Sort alphabetically by label
    apps.sort((a, b) => (a['label'] ?? '').compareTo(b['label'] ?? ''));
    
    if (mounted) {
      setState(() {
        _installedApps = apps;
        _filteredApps = apps;
        _isLoading = false;
      });
    }
  }

  void _filterApps() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredApps = _installedApps;
      } else {
        _filteredApps = _installedApps.where((app) {
          final label = app['label']?.toLowerCase() ?? '';
          return label.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appLimitsAsync = ref.watch(appLimitsProvider);
    final appLimits = appLimitsAsync.value ?? const {};

    return SayNOScaffold(
      appBar: AppBar(
        title: const Text('Blocked Apps'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(AppSizes.md),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search apps...',
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.textSecondary),
                      filled: true,
                      fillColor: AppColors.surfaceElevated,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: AppSizes.md),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _filteredApps.length,
                    itemBuilder: (context, index) {
                      final app = _filteredApps[index];
                      final packageName = app['packageName']!;
                      final label = app['label'] ?? packageName;
                      final isBlocked = appLimits.containsKey(packageName);

                      return ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AppColors.surfaceElevated,
                          child: Icon(Icons.apps_rounded, color: AppColors.textSecondary, size: 20),
                        ),
                        title: Text(label, style: AppTextStyles.titleMedium),
                        subtitle: Text(packageName, style: AppTextStyles.bodySmall),
                        trailing: Switch.adaptive(
                          value: isBlocked,
                          activeTrackColor: AppColors.accent,
                          onChanged: (value) async {
                            final notifier = ref.read(appLimitsProvider.notifier);
                            if (value) {
                              await notifier.setLimit(packageName, Duration.zero);
                            } else {
                              await notifier.removeLimit(packageName);
                            }
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}

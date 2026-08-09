import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../theme/text_styles.dart';
import '../../protection/application/session_controller.dart';
import '../../protection/domain/monitored_apps.dart';
import '../application/contract_controller.dart';
import '../domain/contract_app.dart';

class ContractCreateScreen extends ConsumerStatefulWidget {
  const ContractCreateScreen({super.key});

  @override
  ConsumerState<ContractCreateScreen> createState() => _ContractCreateScreenState();
}

class _ContractCreateScreenState extends ConsumerState<ContractCreateScreen> {
  int _currentStep = 1;
  int _selectedDuration = 3; // Default 3 days
  final List<String> _selectedApps = [];
  final Map<String, Duration> _appLimits = {};
  final Map<String, RestrictionMode> _appModes = {};

  @override
  Widget build(BuildContext context) {
    final completedCountAsync = ref.watch(completedContractsCountProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () {
            if (_currentStep > 1) {
              setState(() => _currentStep--);
            } else {
              context.pop();
            }
          },
        ),
        title: Text(
          'Step $_currentStep of 4',
          style: AppTextStyles.bodyMedium.copyWith(color: const Color(0xFF9CA3AF)),
        ),
        centerTitle: true,
      ),
      body: completedCountAsync.when(
        data: (completedCount) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSizes.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: AppSizes.md),
              Expanded(
                child: _buildStepContent(completedCount),
              ),
              _buildNavigationButtons(),
              const SizedBox(height: AppSizes.xl),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
        error: (err, _) => Center(
          child: Text(
            'Error loading contract history: $err',
            style: const TextStyle(color: Colors.red),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent(int completedCount) {
    switch (_currentStep) {
      case 1:
        return _buildStep1Duration(completedCount);
      case 2:
        return _buildStep2AppSelection();
      case 3:
        return _buildStep3Limits();
      case 4:
        return _buildStep4Commit();
      default:
        return Container();
    }
  }

  Widget _buildStep1Duration(int completedCount) {
    int minDays = 1;
    int maxDays = 14;
    String recommendation = 'Recommended: 3–7 Days for beginners';

    if (completedCount == 1) {
      maxDays = 30;
      recommendation = 'Recommended: 14–21 Days for intermediate focus';
    } else if (completedCount >= 2) {
      maxDays = 365;
      recommendation = '';
    }

    // Adjust selected duration if it exceeds new bounds
    if (_selectedDuration < minDays) _selectedDuration = minDays;
    if (_selectedDuration > maxDays) _selectedDuration = maxDays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Duration', style: AppTextStyles.headlineMedium),
        const SizedBox(height: AppSizes.xs),
        Text(
          'Establish a commitment timeframe. Start small to build consistency.',
          style: AppTextStyles.bodyMedium.copyWith(color: const Color(0xFF9CA3AF)),
        ),
        const SizedBox(height: AppSizes.lg),
        if (recommendation.isNotEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSizes.md),
            decoration: BoxDecoration(
              color: const Color(0xFFFFD700).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppSizes.radiusMd),
              border: Border.all(color: const Color(0xFFFFD700).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.tips_and_updates_outlined, color: Color(0xFFFFD700), size: 20),
                const SizedBox(width: AppSizes.sm),
                Expanded(
                  child: Text(
                    recommendation,
                    style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFFFFD700)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSizes.lg),
        ],
        Text(
          'Duration: $_selectedDuration days',
          style: AppTextStyles.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        Slider(
          value: _selectedDuration.toDouble(),
          min: minDays.toDouble(),
          max: maxDays.toDouble(),
          divisions: maxDays - minDays == 0 ? 1 : maxDays - minDays,
          activeColor: Colors.white,
          inactiveColor: const Color(0xFF222222),
          onChanged: (val) {
            setState(() {
              _selectedDuration = val.round();
            });
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$minDays day', style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF4B5563))),
            Text('$maxDays days', style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF4B5563))),
          ],
        ),
      ],
    );
  }

  Widget _buildStep2AppSelection() {
    final monitoredPackages = monitoredAppsRegistry.keys.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Select Targets', style: AppTextStyles.headlineMedium),
        const SizedBox(height: AppSizes.xs),
        Text(
          'Choose which monitored apps to include in this contract. Monitoring settings remain separate.',
          style: AppTextStyles.bodyMedium.copyWith(color: const Color(0xFF9CA3AF)),
        ),
        const SizedBox(height: AppSizes.lg),
        Expanded(
          child: ListView.builder(
            itemCount: monitoredPackages.length,
            itemBuilder: (context, index) {
              final package = monitoredPackages[index];
              final label = monitoredAppsRegistry[package] ?? package;
              final isSelected = _selectedApps.contains(package);

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: InkWell(
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedApps.remove(package);
                        _appLimits.remove(package);
                        _appModes.remove(package);
                      } else {
                        _selectedApps.add(package);
                        _appLimits[package] = const Duration(minutes: 30);
                        _appModes[package] = RestrictionMode.time_limit;
                      }
                    });
                  },
                  borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                  child: Container(
                    padding: const EdgeInsets.all(AppSizes.md),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF111111) : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                      border: Border.all(
                        color: isSelected ? Colors.white.withValues(alpha: 0.3) : const Color(0xFF222222),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(label, style: AppTextStyles.bodyLarge.copyWith(color: Colors.white)),
                        Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                          color: isSelected ? Colors.white : const Color(0xFF4B5563),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStep3Limits() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Configure Limits', style: AppTextStyles.headlineMedium),
        const SizedBox(height: AppSizes.xs),
        Text(
          'Set daily allowances. Exceeding daily limits blocks access and resets streaks.',
          style: AppTextStyles.bodyMedium.copyWith(color: const Color(0xFF9CA3AF)),
        ),
        const SizedBox(height: AppSizes.lg),
        Expanded(
          child: ListView.builder(
            itemCount: _selectedApps.length,
            itemBuilder: (context, index) {
              final package = _selectedApps[index];
              final label = monitoredAppsRegistry[package] ?? package;
              final limit = _appLimits[package] ?? const Duration(minutes: 30);
              final totalCredits = limit.inMinutes * _selectedDuration;

              return Container(
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                padding: const EdgeInsets.all(AppSizes.md),
                decoration: BoxDecoration(
                  color: const Color(0xFF111111),
                  borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                  border: Border.all(color: const Color(0xFF222222), width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: AppTextStyles.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: AppSizes.xs),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Daily Limit:', style: AppTextStyles.bodyMedium.copyWith(color: const Color(0xFF9CA3AF))),
                        Text('${limit.inMinutes} mins', style: AppTextStyles.bodyLarge.copyWith(color: Colors.white)),
                      ],
                    ),
                    Slider(
                      value: limit.inMinutes.toDouble(),
                      min: 5,
                      max: 240,
                      divisions: 47,
                      activeColor: Colors.white,
                      inactiveColor: const Color(0xFF222222),
                      onChanged: (val) {
                        setState(() {
                          _appLimits[package] = Duration(minutes: val.round());
                        });
                      },
                    ),
                    const Divider(color: Color(0xFF222222)),
                    Text('Restriction Mode:', style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF9CA3AF))),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: RestrictionMode.values.map((mode) {
                        final isSelected = (_appModes[package] ?? RestrictionMode.time_limit) == mode;
                        String label = '';
                        switch (mode) {
                          case RestrictionMode.time_limit:
                            label = 'Time Limit';
                            break;
                          case RestrictionMode.utility:
                            label = 'Utility';
                            break;
                          case RestrictionMode.focus:
                            label = 'Focus';
                            break;
                          case RestrictionMode.monk:
                            label = 'Monk';
                            break;
                        }
                        return ChoiceChip(
                          label: Text(label, style: TextStyle(color: isSelected ? Colors.black : Colors.white, fontSize: 11)),
                          selected: isSelected,
                          selectedColor: Colors.white,
                          backgroundColor: const Color(0xFF1F1F1F),
                          checkmarkColor: Colors.black,
                          onSelected: (selected) {
                            if (selected) {
                              setState(() {
                                _appModes[package] = mode;
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 8),
                    _buildModeDescription(_appModes[package] ?? RestrictionMode.time_limit),
                    const Divider(color: Color(0xFF222222)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Credits Generated:', style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF9CA3AF))),
                        Text('$totalCredits mins', style: AppTextStyles.bodyMedium.copyWith(color: const Color(0xFFFFD700), fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildModeDescription(RestrictionMode mode) {
    String desc = '';
    switch (mode) {
      case RestrictionMode.time_limit:
        desc = 'Blocks the entire app when the daily limit is exceeded.';
        break;
      case RestrictionMode.utility:
        desc = 'Blocks infinite feeds (Feed, Reels, Explore) after limit; DMs/Search remain active.';
        break;
      case RestrictionMode.focus:
        desc = 'Always blocks infinite feeds. DMs/Search remain active (limit acts as standard tracker).';
        break;
      case RestrictionMode.monk:
        desc = 'Always blocks infinite feeds. Blocks the entire app once the daily limit is exceeded.';
        break;
    }
    return Text(
      desc,
      style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF9CA3AF), fontStyle: FontStyle.italic),
    );
  }

  Widget _buildStep4Commit() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Commit & Sign', style: AppTextStyles.headlineMedium),
        const SizedBox(height: AppSizes.xs),
        Text(
          'Review contract details. Once signed, the contract is locked.',
          style: AppTextStyles.bodyMedium.copyWith(color: const Color(0xFF9CA3AF)),
        ),
        const SizedBox(height: AppSizes.lg),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppSizes.lg),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111111),
                    borderRadius: BorderRadius.circular(AppSizes.radiusLg),
                    border: Border.all(color: const Color(0xFF222222), width: 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'FOCUS COMMITMENT CONTRACT',
                        style: AppTextStyles.titleMedium.copyWith(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: AppSizes.sm),
                      Text(
                        'Timeframe: $_selectedDuration Days',
                        style: AppTextStyles.bodyLarge.copyWith(color: const Color(0xFFFFD700), fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: AppSizes.md),
                      const Divider(color: Color(0xFF222222)),
                      const SizedBox(height: AppSizes.sm),
                      Text('APP ALLOWANCES & CREDIT POOLS:', style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF9CA3AF))),
                      const SizedBox(height: AppSizes.xs),
                      ..._selectedApps.map((package) {
                        final label = monitoredAppsRegistry[package] ?? package;
                        final limit = _appLimits[package] ?? const Duration(minutes: 30);
                        final total = limit.inMinutes * _selectedDuration;
                        final mode = _appModes[package] ?? RestrictionMode.time_limit;
                        final modeLabel = mode.name.toUpperCase().replaceAll('_', ' ');
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(label, style: AppTextStyles.bodyMedium.copyWith(color: Colors.white)),
                              Text('${limit.inMinutes}m ($modeLabel, Total $total mins)', style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFF9CA3AF))),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
                const SizedBox(height: AppSizes.lg),
                Container(
                  padding: const EdgeInsets.all(AppSizes.md),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppSizes.radiusMd),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    'WARNING: You cannot exit this contract or change these rules early. Borrowing minutes is a violation that marks the day as failed and resets streaks.',
                    style: AppTextStyles.bodySmall.copyWith(color: const Color(0xFFEF4444)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationButtons() {
    final bool isNextDisabled = _currentStep == 2 && _selectedApps.isEmpty;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (_currentStep > 1)
          Expanded(
            child: OutlinedButton(
              onPressed: () {
                setState(() => _currentStep--);
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF222222)),
                padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMd)),
              ),
              child: const Text('Back', style: TextStyle(color: Colors.white)),
            ),
          )
        else
          const Spacer(),
        const SizedBox(width: AppSizes.md),
        Expanded(
          child: ElevatedButton(
            onPressed: isNextDisabled
                ? null
                : () async {
                    if (_currentStep < 4) {
                      setState(() => _currentStep++);
                    } else {
                      final contractApps = _selectedApps.map((package) {
                        final limit = _appLimits[package] ?? const Duration(minutes: 30);
                        final total = limit * _selectedDuration;
                        final mode = _appModes[package] ?? RestrictionMode.time_limit;
                        return ContractApp(
                          packageName: package,
                          dailyLimit: limit,
                          totalCredits: total,
                          remainingCredits: total,
                          restrictionMode: mode,
                        );
                      }).toList();

                      await ref.read(activeContractProvider.notifier).createContract(
                            _selectedDuration,
                            contractApps,
                          );

                      if (mounted) {
                        context.pop();
                      }
                    }
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: isNextDisabled ? const Color(0xFF222222) : Colors.white,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: AppSizes.md),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppSizes.radiusMd)),
            ),
            child: Text(
              _currentStep == 4 ? 'Sign Contract' : 'Next',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }
}

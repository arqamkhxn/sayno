import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../protection/application/protection_controller.dart';
import '../../protection/domain/monitored_apps.dart';

/// Represents a single day's total usage across all monitored apps.
class DailyUsageStat {
  final DateTime date;
  final Duration totalDuration;

  const DailyUsageStat(this.date, this.totalDuration);
}

/// Computes the historical usage over the past [days] days.
/// The resulting list is ordered from oldest to newest (today).
final weeklyUsageProvider = FutureProvider<List<DailyUsageStat>>((ref) async {
  final platformService = ref.watch(protectionPlatformServiceProvider);
  final nowUtc = DateTime.now().toUtc();
  
  final List<DailyUsageStat> weeklyData = [];
  
  // We want the last 7 days, including today.
  // We'll iterate from 6 days ago up to 0 (today)
  for (int i = 6; i >= 0; i--) {
    final targetDate = nowUtc.subtract(Duration(days: i));
    final dateStr = '${targetDate.year}-${targetDate.month.toString().padLeft(2, '0')}-${targetDate.day.toString().padLeft(2, '0')}';
    
    int dailyTotalSeconds = 0;
    
    // Check all potentially tracked apps
    for (final package in monitoredAppsRegistry.keys) {
      final usageSeconds = await platformService.getUsageForPackageOnDateUtc(package, dateStr);
      dailyTotalSeconds += usageSeconds;
    }
    
    weeklyData.add(DailyUsageStat(targetDate, Duration(seconds: dailyTotalSeconds)));
  }
  
  return weeklyData;
});

/// A derived provider to calculate the weekly summary stats needed by the UI.
class WeeklySummaryData {
  final double totalHours;
  final int dailyAvgMinutes;
  final String bestDayLabel;
  
  const WeeklySummaryData({
    required this.totalHours,
    required this.dailyAvgMinutes,
    required this.bestDayLabel,
  });
}

final weeklySummaryProvider = Provider<AsyncValue<WeeklySummaryData>>((ref) {
  final weeklyDataAsync = ref.watch(weeklyUsageProvider);
  
  return weeklyDataAsync.whenData((weeklyData) {
    if (weeklyData.isEmpty) {
      return const WeeklySummaryData(
        totalHours: 0,
        dailyAvgMinutes: 0,
        bestDayLabel: 'N/A',
      );
    }
    
    int totalSeconds = 0;
    int bestDaySeconds = -1;
    String bestDayLabel = 'N/A';
    
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    
    for (final stat in weeklyData) {
      totalSeconds += stat.totalDuration.inSeconds;
      
      // The best day is the one with the lowest usage, assuming it's not 0 from before the app was installed.
      // But a day with 0 might just mean no usage. If all days are 0, best day is N/A.
      if (stat.totalDuration.inSeconds > 0) {
        if (bestDaySeconds == -1 || stat.totalDuration.inSeconds < bestDaySeconds) {
          bestDaySeconds = stat.totalDuration.inSeconds;
          bestDayLabel = weekdays[stat.date.weekday - 1];
        }
      }
    }
    
    final totalHours = totalSeconds / 3600;
    final dailyAvgMinutes = (totalSeconds / 60) ~/ weeklyData.length;
    
    // If we have no usage at all recorded
    if (bestDaySeconds == -1 && totalSeconds == 0) {
      bestDayLabel = 'N/A';
    } else if (bestDaySeconds == -1 && totalSeconds > 0) {
       bestDayLabel = 'Today'; // Edge case
    }
    
    return WeeklySummaryData(
      totalHours: totalHours,
      dailyAvgMinutes: dailyAvgMinutes,
      bestDayLabel: bestDayLabel,
    );
  });
});

// lib/features/dashboard/presentation/widgets/gst_summary_chart.dart

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../providers/dashboard_provider.dart';

class GstSummaryChart extends StatefulWidget {
  final DashboardStats stats;

  const GstSummaryChart({super.key, required this.stats});

  @override
  State<GstSummaryChart> createState() => _GstSummaryChartState();
}

class _GstSummaryChartState extends State<GstSummaryChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final hasData = widget.stats.totalCgst > 0 || widget.stats.totalSgst > 0 || widget.stats.totalIgst > 0;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'GST Breakdown'),
          const SizedBox(height: 16),
          if (!hasData)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('No GST data available this month'),
              ),
            )
          else
            Row(
              children: [
                SizedBox(
                  height: 140,
                  width: 140,
                  child: PieChart(
                    PieChartData(
                      pieTouchData: PieTouchData(
                        touchCallback: (event, response) {
                          setState(() {
                            _touchedIndex = response?.touchedSection?.touchedSectionIndex ?? -1;
                          });
                        },
                      ),
                      borderData: FlBorderData(show: false),
                      sectionsSpace: 3,
                      centerSpaceRadius: 36,
                      sections: _buildSections(),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(child: _buildLegend()),
              ],
            ),
          if (hasData) ...[
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 12),
            _buildMonthlyBars(),
          ],
        ],
      ),
    );
  }

  List<PieChartSectionData> _buildSections() {
    final total = widget.stats.totalCgst + widget.stats.totalSgst + widget.stats.totalIgst;
    if (total == 0) return [];

    final sections = <PieChartSectionData>[];

    if (widget.stats.totalCgst > 0) {
      final pct = widget.stats.totalCgst / total * 100;
      sections.add(_buildSection(pct, 'CGST', AppColors.cgstColor, 0));
    }
    if (widget.stats.totalSgst > 0) {
      final pct = widget.stats.totalSgst / total * 100;
      sections.add(_buildSection(pct, 'SGST', AppColors.sgstColor, 1));
    }
    if (widget.stats.totalIgst > 0) {
      final pct = widget.stats.totalIgst / total * 100;
      sections.add(_buildSection(pct, 'IGST', AppColors.igstColor, 2));
    }

    return sections;
  }

  PieChartSectionData _buildSection(double value, String title, Color color, int idx) {
    final isTouched = idx == _touchedIndex;
    return PieChartSectionData(
      color: color,
      value: value,
      title: '${value.toStringAsFixed(0)}%',
      radius: isTouched ? 55 : 48,
      titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
    );
  }

  Widget _buildLegend() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.stats.totalCgst > 0)
          _buildLegendItem('CGST', widget.stats.totalCgst, AppColors.cgstColor),
        if (widget.stats.totalSgst > 0) ...[
          const SizedBox(height: 8),
          _buildLegendItem('SGST', widget.stats.totalSgst, AppColors.sgstColor),
        ],
        if (widget.stats.totalIgst > 0) ...[
          const SizedBox(height: 8),
          _buildLegendItem('IGST', widget.stats.totalIgst, AppColors.igstColor),
        ],
      ],
    );
  }

  Widget _buildLegendItem(String label, double amount, Color color) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondaryLight)),
            Text(
              '₹${_fmt(amount)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMonthlyBars() {
    if (widget.stats.monthlySales.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 100,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: widget.stats.monthlySales.map((e) => e.sales).reduce((a, b) => a > b ? a : b) * 1.2,
          barTouchData: BarTouchData(enabled: false),
          titlesData: FlTitlesData(
            show: true,
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  final idx = value.toInt();
                  if (idx >= widget.stats.monthlySales.length) return const SizedBox.shrink();
                  return Text(
                    widget.stats.monthlySales[idx].month.substring(0, 3),
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondaryLight),
                  );
                },
              ),
            ),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: widget.stats.monthlySales.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: entry.value.sales,
                  color: AppColors.primary,
                  width: 16,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  String _fmt(double amount) {
    if (amount >= 100000) return '${(amount / 100000).toStringAsFixed(1)}L';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }
}


// ✅ TẠO FILE MỚI
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../screens/win_history/win_history_viewmodel.dart';
import '../../core/utils/number_utils.dart';

class ProfitChart extends StatelessWidget {
  final List<MonthlyProfit> data;

  const ProfitChart({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(
        child: Text('Chưa có dữ liệu'),
      );
    }

    return Card(
      color: const Color(0xFF1E1E1E),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Biểu đồ lợi nhuận theo tháng',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: _calculateInterval(),
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade800,
                        strokeWidth: 1,
                      );
                    },
                    getDrawingVerticalLine: (value) {
                      return FlLine(
                        color: Colors.grey.shade800,
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= data.length) {
                            return const Text('');
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              data[index].monthLabel,
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 10,
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 60,
                        interval: _calculateInterval(),
                        getTitlesWidget: (value, meta) {
                          return Text(
                            NumberUtils.formatCurrency(value),
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 10,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: Colors.grey.shade800),
                  ),
                  minX: 0,
                  maxX: (data.length - 1).toDouble(),
                  minY: _getMinY(),
                  maxY: _getMaxY(),
                  lineBarsData: [
                    LineChartBarData(
                      spots: data.asMap().entries.map((entry) {
                        return FlSpot(
                          entry.key.toDouble(),
                          entry.value.profit,
                        );
                      }).toList(),
                      isCurved: true,
                      color: _getLineColor(),
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (spot, percent, barData, index) {
                          return FlDotCirclePainter(
                            radius: 4,
                            color: _getLineColor(),
                            strokeWidth: 2,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: _getLineColor().withOpacity(0.1),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      tooltipBgColor: const Color(0xFF2C2C2C),
                      tooltipRoundedRadius: 8,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final index = spot.x.toInt();
                          if (index < 0 || index >= data.length) {
                            return null;
                          }
                          final monthData = data[index];
                          return LineTooltipItem(
                            '${monthData.monthLabel}\n'
                            'Lời: ${NumberUtils.formatCurrency(monthData.profit)}\n'
                            'Trúng: ${monthData.wins} lần',
                            const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double _calculateInterval() {
    if (data.isEmpty) return 100000;
    
    final profits = data.map((e) => e.profit).toList();
    final max = profits.reduce((a, b) => a > b ? a : b);
    final min = profits.reduce((a, b) => a < b ? a : b);
    final range = max - min;
    
    if (range < 100000) return 50000;
    if (range < 500000) return 100000;
    if (range < 1000000) return 200000;
    return 500000;
  }

  double _getMinY() {
    if (data.isEmpty) return 0;
    final profits = data.map((e) => e.profit).toList();
    final min = profits.reduce((a, b) => a < b ? a : b);
    return min < 0 ? min * 1.2 : 0;
  }

  double _getMaxY() {
    if (data.isEmpty) return 1000000;
    final profits = data.map((e) => e.profit).toList();
    final max = profits.reduce((a, b) => a > b ? a : b);
    return max * 1.2;
  }

  Color _getLineColor() {
    if (data.isEmpty) return Colors.grey;
    final totalProfit = data.fold<double>(0, (sum, e) => sum + e.profit);
    return totalProfit >= 0 ? const Color(0xFF00897B) : Colors.red;
  }
}
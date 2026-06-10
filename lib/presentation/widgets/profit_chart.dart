// ✅ TẠO FILE MỚI
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/utils/number_utils.dart';
import '../screens/win_history/win_history_viewmodel.dart';

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
              child: Row(
                children: [
                  // 1. DUMMY CHART: Trục Y cố định
                  // Kích thước 62 để chứa vừa reservedSize (60) + 2px cho phần khung vẽ (tránh lỗi chia cho 0 của fl_chart)
                  SizedBox(
                    width: 62,
                    child: LineChart(
                      LineChartData(
                        minX: 0,
                        maxX:
                            1, // Bắt buộc phải lớn hơn minX để tránh assertion error
                        minY: _getMinY(),
                        maxY: _getMaxY(),
                        gridData:
                            const FlGridData(show: false), // Không vẽ lưới
                        borderData: FlBorderData(
                          show: true,
                          border: Border(
                            // Viền phải của biểu đồ giả sẽ đóng vai trò làm trục dọc
                            right: BorderSide(
                                color: Colors.grey.shade800, width: 1),
                            // Phải vẽ viền trên/dưới để khớp pixel với biểu đồ thật
                            bottom: BorderSide(
                                color: Colors.grey.shade800, width: 1),
                            top: BorderSide(
                                color: Colors.grey.shade800, width: 1),
                            left: BorderSide.none,
                          ),
                        ),
                        lineTouchData: const LineTouchData(
                            enabled: false), // Không tương tác
                        titlesData: FlTitlesData(
                          show: true,
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize:
                                  60, // Kích thước này phải khớp với width của SizedBox trừ đi vài pixel
                              interval: _calculateInterval(),
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  NumberUtils.formatCurrency(value),
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 10,
                                  ),
                                  softWrap: false,
                                );
                              },
                            ),
                          ),
                          rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize:
                                  30, // QUAN TRỌNG: Phải bằng đúng reservedSize của bottomTitles bên biểu đồ thật
                              getTitlesWidget: (value, meta) => const SizedBox
                                  .shrink(), // Ẩn text nhưng vẫn giữ khoảng trống
                            ),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: const [
                              FlSpot(0, 0),
                              FlSpot(1, 0)
                            ], // Data rác để thư viện không báo lỗi
                            color: Colors.transparent, // Ẩn hoàn toàn
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. REAL CHART: Biểu đồ thật, vuốt ngang thoải mái
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final calculatedWidth = data.length * 60.0;
                        final minWidth = constraints.maxWidth;
                        final chartWidth = calculatedWidth > minWidth
                            ? calculatedWidth
                            : minWidth;

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          reverse:
                              true, // Auto cuộn về bên phải (tháng mới nhất)
                          child: SizedBox(
                            width: chartWidth,
                            child: LineChart(
                              LineChartData(
                                minY: _getMinY(),
                                maxY: _getMaxY(),
                                minX: 0,
                                maxX: (data.length - 1).toDouble(),
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
                                  // Ẩn hoàn toàn trục Y bên này vì đã có Dummy Chart lo
                                  leftTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  rightTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  topTitles: const AxisTitles(
                                    sideTitles: SideTitles(showTitles: false),
                                  ),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 30, // Khớp với Dummy Chart
                                      interval: 1,
                                      getTitlesWidget: (value, meta) {
                                        final index = value.toInt();
                                        if (index < 0 || index >= data.length) {
                                          return const Text('');
                                        }

                                        final rawLabel = data[index].monthLabel;
                                        String displayLabel = rawLabel;

                                        try {
                                          final parts = rawLabel.split('/');
                                          if (parts.length == 2) {
                                            final month =
                                                int.parse(parts[0]).toString();
                                            final year = parts[1].substring(2);

                                            if (month == '1') {
                                              displayLabel = 'T1/$year';
                                            } else {
                                              displayLabel = 'T$month';
                                            }
                                          }
                                        } catch (_) {
                                          displayLabel = rawLabel;
                                        }

                                        return Padding(
                                          padding:
                                              const EdgeInsets.only(top: 8),
                                          child: Text(
                                            displayLabel,
                                            style: TextStyle(
                                              color: Colors.grey.shade400,
                                              fontSize: 10,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                                borderData: FlBorderData(
                                  show: true,
                                  border: Border(
                                    top:
                                        BorderSide(color: Colors.grey.shade800),
                                    bottom:
                                        BorderSide(color: Colors.grey.shade800),
                                    left: BorderSide
                                        .none, // Bỏ viền trái để nó dính sát vào trục dọc của Dummy Chart
                                    right:
                                        BorderSide(color: Colors.grey.shade800),
                                  ),
                                ),
                                lineBarsData: [
                                  LineChartBarData(
                                    spots: data.asMap().entries.map((entry) {
                                      return FlSpot(
                                        entry.key.toDouble(),
                                        entry.value.profit,
                                      );
                                    }).toList(),
                                    isCurved: true,
                                    preventCurveOverShooting: true,
                                    color: _getLineColor(),
                                    barWidth: 3,
                                    isStrokeCapRound: true,
                                    dotData: FlDotData(
                                      show: true,
                                      getDotPainter:
                                          (spot, percent, barData, index) {
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
                                    fitInsideHorizontally: true,
                                    fitInsideVertically: true,
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
                        );
                      },
                    ),
                  ),
                ],
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

// ✅ ĐÃ CHUYỂN SANG STATEFUL WIDGET ĐỂ QUẢN LÝ TRẠNG THÁI TOOLTIP
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../core/utils/number_utils.dart';
import '../screens/win_history/win_history_viewmodel.dart';

class ProfitChart extends StatefulWidget {
  final List<MonthlyProfit> data;

  const ProfitChart({
    super.key,
    required this.data,
  });

  @override
  State<ProfitChart> createState() => _ProfitChartState();
}

class _ProfitChartState extends State<ProfitChart> {
  // Biến lưu trữ index của điểm đang được hiển thị tooltip
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    if (widget.data.isEmpty) {
      return const Center(
        child: Text('Chưa có dữ liệu'),
      );
    }

    // Tách riêng LineChartBarData ra một biến để có thể tái sử dụng
    // trong việc ép hiển thị Tooltip (showingTooltipIndicators)
    final lineBarData = LineChartBarData(
      spots: widget.data.asMap().entries.map((entry) {
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
        getDotPainter: (spot, percent, barData, index) {
          // UX: Phóng to chấm tròn nếu điểm đó đang được chọn
          final isSelected = _touchedIndex == index;
          return FlDotCirclePainter(
            radius: isSelected ? 6 : 4,
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
    );

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
                  SizedBox(
                    width: 62,
                    child: LineChart(
                      LineChartData(
                        minX: 0,
                        maxX: 1,
                        minY: _getMinY(),
                        maxY: _getMaxY(),
                        gridData: const FlGridData(show: false),
                        borderData: FlBorderData(
                          show: true,
                          border: Border(
                            right: BorderSide(
                                color: Colors.grey.shade800, width: 1),
                            bottom: BorderSide(
                                color: Colors.grey.shade800, width: 1),
                            top: BorderSide(
                                color: Colors.grey.shade800, width: 1),
                            left: BorderSide.none,
                          ),
                        ),
                        lineTouchData: const LineTouchData(enabled: false),
                        titlesData: FlTitlesData(
                          show: true,
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
                              reservedSize: 30,
                              getTitlesWidget: (value, meta) =>
                                  const SizedBox.shrink(),
                            ),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: const [FlSpot(0, 0), FlSpot(1, 0)],
                            color: Colors.transparent,
                            dotData: const FlDotData(show: false),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. REAL CHART: Vuốt ngang và thao tác chọn điểm
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final calculatedWidth = widget.data.length * 60.0;
                        final minWidth = constraints.maxWidth;
                        final chartWidth = calculatedWidth > minWidth
                            ? calculatedWidth
                            : minWidth;

                        return SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          reverse: true,
                          child: SizedBox(
                            width: chartWidth,
                            child: LineChart(
                              LineChartData(
                                minY: _getMinY(),
                                maxY: _getMaxY(),
                                minX: 0,
                                maxX: (widget.data.length - 1).toDouble(),
                                // ÉP HIỂN THỊ TOOLTIP: Dựa vào state _touchedIndex
                                showingTooltipIndicators: _touchedIndex == null
                                    ? []
                                    : [
                                        ShowingTooltipIndicators([
                                          LineBarSpot(
                                            lineBarData,
                                            0,
                                            lineBarData.spots[_touchedIndex!],
                                          ),
                                        ]),
                                      ],
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
                                  leftTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  rightTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  topTitles: const AxisTitles(
                                      sideTitles:
                                          SideTitles(showTitles: false)),
                                  bottomTitles: AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 30,
                                      interval: 1,
                                      getTitlesWidget: (value, meta) {
                                        final index = value.toInt();
                                        if (index < 0 ||
                                            index >= widget.data.length) {
                                          return const Text('');
                                        }

                                        final rawLabel =
                                            widget.data[index].monthLabel;
                                        String displayLabel = rawLabel;

                                        try {
                                          final parts = rawLabel.split('/');
                                          if (parts.length == 2) {
                                            final month =
                                                int.parse(parts[0]).toString();
                                            final year = parts[1].substring(2);
                                            displayLabel = (month == '1')
                                                ? 'T1/$year'
                                                : 'T$month';
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
                                              fontWeight: _touchedIndex == index
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              // Làm nổi bật nhẹ nhãn của tháng đang chọn
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
                                    left: BorderSide.none,
                                    right:
                                        BorderSide(color: Colors.grey.shade800),
                                  ),
                                ),
                                lineBarsData: [
                                  lineBarData
                                ], // Sử dụng biến lineBarData đã tạo ở trên
                                lineTouchData: LineTouchData(
                                  enabled: true,
                                  // QUAN TRỌNG: Tắt hành vi hold-to-show mặc định
                                  handleBuiltInTouches: false,
                                  touchCallback: (FlTouchEvent event,
                                      LineTouchResponse? touchResponse) {
                                    // Bắt sự kiện Tap Up (nhấc ngón tay lên sau khi chạm)
                                    if (event is FlTapUpEvent) {
                                      // Chạm ra khoảng trống hoặc không trúng điểm nào -> Tắt tooltip
                                      if (touchResponse == null ||
                                          touchResponse.lineBarSpots == null ||
                                          touchResponse.lineBarSpots!.isEmpty) {
                                        setState(() {
                                          _touchedIndex = null;
                                        });
                                        return;
                                      }

                                      // Lấy index của điểm vừa chạm
                                      final spotIndex = touchResponse
                                          .lineBarSpots!.first.spotIndex;
                                      setState(() {
                                        // Nếu chạm vào điểm đang hiển thị -> Tắt. Nếu chạm điểm khác -> Bật điểm mới.
                                        _touchedIndex =
                                            (_touchedIndex == spotIndex)
                                                ? null
                                                : spotIndex;
                                      });
                                    }
                                  },
                                  touchTooltipData: LineTouchTooltipData(
                                    fitInsideHorizontally: true,
                                    fitInsideVertically: true,
                                    tooltipBgColor: const Color(0xFF2C2C2C),
                                    tooltipRoundedRadius: 8,
                                    getTooltipItems: (touchedSpots) {
                                      return touchedSpots.map((spot) {
                                        final index = spot.x.toInt();
                                        if (index < 0 ||
                                            index >= widget.data.length)
                                          return null;

                                        final monthData = widget.data[index];
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

  // --- Các hàm tiện ích phải đổi thành widget.data ---
  double _calculateInterval() {
    if (widget.data.isEmpty) return 100000;

    final profits = widget.data.map((e) => e.profit).toList();
    final max = profits.reduce((a, b) => a > b ? a : b);
    final min = profits.reduce((a, b) => a < b ? a : b);
    final range = max - min;

    if (range < 100000) return 50000;
    if (range < 500000) return 100000;
    if (range < 1000000) return 200000;
    return 500000;
  }

  double _getMinY() {
    if (widget.data.isEmpty) return 0;
    final profits = widget.data.map((e) => e.profit).toList();
    final min = profits.reduce((a, b) => a < b ? a : b);
    return min < 0 ? min * 1.2 : 0;
  }

  double _getMaxY() {
    if (widget.data.isEmpty) return 1000000;
    final profits = widget.data.map((e) => e.profit).toList();
    final max = profits.reduce((a, b) => a > b ? a : b);
    return max * 1.2;
  }

  Color _getLineColor() {
    if (widget.data.isEmpty) return Colors.grey;
    final totalProfit = widget.data.fold<double>(0, (sum, e) => sum + e.profit);
    return totalProfit >= 0 ? const Color(0xFF00897B) : Colors.red;
  }
}

// ✅ TẠO FILE MỚI
import 'package:flutter/material.dart';
import 'package:data_table_2/data_table_2.dart';
import '../../data/models/betting_row.dart';
import '../../core/utils/number_utils.dart';

class ResponsiveDataTable extends StatelessWidget {
  final List<BettingRow> rows;
  final bool isCycleTable;

  const ResponsiveDataTable({
    Key? key,
    required this.rows,
    this.isCycleTable = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // ✅ Mobile view (< 600px)
        if (constraints.maxWidth < 600) {
          return _buildMobileView();
        }
        
        // ✅ Tablet view (600-1200px)
        if (constraints.maxWidth < 1200) {
          return _buildTabletView();
        }
        
        // ✅ Desktop view (>= 1200px)
        return _buildDesktopView();
      },
    );
  }

  // ✅ Mobile: Card-based list
  Widget _buildMobileView() {
    return ListView.builder(
      shrinkWrap: true, // ✅ FIX: Cho phép ListView nằm trong parent có constraint
      physics: const NeverScrollableScrollPhysics(), // ✅ Tắt scroll của ListView con
      itemCount: rows.length,
      padding: const EdgeInsets.all(8),
      itemBuilder: (context, index) {
        final row = rows[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ExpansionTile(
            leading: CircleAvatar(
              backgroundColor: _getMienColor(row.mien),
              child: Text(
                row.stt.toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                  color: Colors.white,
                ),
              ),
            ),
            title: Row(
              children: [
                Text(
                  row.ngay,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ],
            ),
            subtitle: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getMienColor(row.mien),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    row.mien,
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'Tổng: ${NumberUtils.formatCurrency(row.tongTien)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            trailing: SizedBox(
              width: 155,
              child: isCycleTable
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(
                                'Lời 1 số:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade400,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                NumberUtils.formatCurrency(row.loi1So),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.green.shade300,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            SizedBox(
                              width: 100,
                              child: Text(
                                'Cược/miền:',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey.shade400,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                NumberUtils.formatCurrency(row.cuocMien),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.red.shade300,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Lời ',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey.shade400,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                NumberUtils.formatCurrency(row.loi1So),
                                style: TextStyle(
                                  fontSize: 13,
                                  color: row.loi1So > 0 ? Colors.green.shade300 : Colors.red.shade300,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.right,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
            children: [
              if (isCycleTable) ...[
                _buildDetailRow('Số lô', row.soLo.toString()),
                _buildDetailRow('Cược/số', NumberUtils.formatCurrency(row.cuocSo)),
                _buildDetailRow('Cược/miền', NumberUtils.formatCurrency(row.cuocMien)),
                _buildDetailRow(
                  'Lời (1 số)',
                  NumberUtils.formatCurrency(row.loi1So),
                ),
                _buildDetailRow(
                  'Lời (2 số)',
                  NumberUtils.formatCurrency(row.loi2So ?? 0),
                ),
              ] else ...[
                _buildDetailRow('Cược', NumberUtils.formatCurrency(row.cuocMien)),
                _buildDetailRow(
                  'Lời',
                  NumberUtils.formatCurrency(row.loi1So),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  // ✅ Tablet: Compact table
  Widget _buildTabletView() {
    return Card(
      margin: const EdgeInsets.all(16),
      color: const Color(0xFF1E1E1E),
      child: SizedBox(
        height: 450, // ✅ FIX: Thêm chiều cao cố định
        child: DataTable2(
          columnSpacing: 8,
          horizontalMargin: 12,
          minWidth: 600,
          dataRowHeight: 56,
          headingTextStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
            color: Colors.white,
          ),
          dataTextStyle: const TextStyle(fontSize: 12, color: Colors.white),
          headingRowColor: MaterialStateProperty.all(const Color(0xFF2C2C2C)),
          columns: _getCompactColumns(),
          rows: rows.map((row) => _buildCompactDataRow(row)).toList(),
        ),
      ),
    );
  }

  // ✅ Desktop: Full table with hover
  Widget _buildDesktopView() {
    return Card(
      margin: const EdgeInsets.all(16),
      color: const Color(0xFF1E1E1E),
      child: SizedBox(
        height: 500, // ✅ FIX: Thêm chiều cao cố định
        child: DataTable2(
          columnSpacing: 12,
          horizontalMargin: 12,
          minWidth: 800,
          dataRowHeight: 56,
          headingRowHeight: 48,
          // ✅ Hover effect
          dataRowColor: MaterialStateProperty.resolveWith<Color?>((states) {
            if (states.contains(MaterialState.hovered)) {
              return Colors.blue.withOpacity(0.08);
            }
            if (states.contains(MaterialState.selected)) {
              return Colors.blue.withOpacity(0.15);
            }
            return null;
          }),
          headingTextStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Colors.white,
          ),
          dataTextStyle: const TextStyle(fontSize: 13, color: Colors.white),
          headingRowColor: MaterialStateProperty.all(const Color(0xFF2C2C2C)),
          columns: _getFullColumns(),
          rows: rows.asMap().entries.map((entry) {
            return _buildFullDataRow(entry.value, entry.key);
          }).toList(),
        ),
      ),
    );
  }

  // ✅ Helper methods
  Widget _buildDetailRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey.shade400),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _getMienColor(String mien) {
    switch (mien) {
      case 'Nam':
        return const Color(0xFFB45309); // ✅ Cam rất tối
      case 'Trung':
        return const Color(0xFF6B21A8); // ✅ Tím rất tối
      case 'Bắc':
        return const Color(0xFF1E40AF); // ✅ Xanh rất tối
      default:
        return const Color(0xFF4B5563);
    }
  }

  List<DataColumn2> _getCompactColumns() {
    return [
      const DataColumn2(label: Center(child: Text('STT')), size: ColumnSize.S, fixedWidth: 40),
      const DataColumn2(label: Center(child: Text('Ngày')), size: ColumnSize.S, fixedWidth: 80),
      const DataColumn2(label: Center(child: Text('Miền')), size: ColumnSize.S, fixedWidth: 60),
      const DataColumn2(label: Center(child: Text('Số')), size: ColumnSize.S, fixedWidth: 50),
      const DataColumn2(label: Align(alignment: Alignment.centerRight, child: Text('Tổng tiền')), size: ColumnSize.M),
      if (isCycleTable)
        const DataColumn2(label: Align(alignment: Alignment.centerRight, child: Text('Lời (1)')), size: ColumnSize.M),
    ];
  }

  List<DataColumn2> _getFullColumns() {
    if (isCycleTable) {
      return const [
        DataColumn2(label: Center(child: Text('STT')), size: ColumnSize.S, fixedWidth: 40),
        DataColumn2(label: Center(child: Text('Ngày')), size: ColumnSize.M, fixedWidth: 90),
        DataColumn2(label: Center(child: Text('Miền')), size: ColumnSize.S, fixedWidth: 60),
        DataColumn2(label: Center(child: Text('Số')), size: ColumnSize.S, fixedWidth: 50),
        DataColumn2(label: Center(child: Text('Cược/Số')), size: ColumnSize.S, fixedWidth: 70),
        DataColumn2(label: Align(alignment: Alignment.centerRight, child: Text('Cược/miền')), size: ColumnSize.M),
        DataColumn2(label: Align(alignment: Alignment.centerRight, child: Text('Tổng tiền')), size: ColumnSize.M),
        DataColumn2(label: Align(alignment: Alignment.centerRight, child: Text('Lời (1 số)')), size: ColumnSize.M),
        DataColumn2(label: Align(alignment: Alignment.centerRight, child: Text('Lời (2 số)')), size: ColumnSize.M),
      ];
    } else {
      return const [
        DataColumn2(label: Center(child: Text('STT')), size: ColumnSize.S, fixedWidth: 40),
        DataColumn2(label: Center(child: Text('Ngày')), size: ColumnSize.M, fixedWidth: 90),
        DataColumn2(label: Center(child: Text('Miền')), size: ColumnSize.S, fixedWidth: 60),
        DataColumn2(label: Center(child: Text('Số')), size: ColumnSize.S, fixedWidth: 50),
        DataColumn2(label: Align(alignment: Alignment.centerRight, child: Text('Cược')), size: ColumnSize.M, fixedWidth: 80),
        DataColumn2(label: Align(alignment: Alignment.centerRight, child: Text('Tổng tiền')), size: ColumnSize.M),
        DataColumn2(label: Align(alignment: Alignment.centerRight, child: Text('Lời')), size: ColumnSize.M),
      ];
    }
  }

  DataRow2 _buildCompactDataRow(BettingRow row) {
    return DataRow2(
      color: MaterialStateProperty.all(const Color(0xFF1E1E1E)),
      cells: [
        DataCell(Center(child: Text(row.stt.toString()))),
        DataCell(Center(child: Text(row.ngay.substring(0, 5)))),
        DataCell(Center(child: Text(row.mien))),
        DataCell(Center(child: Text(row.so, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)))),
        DataCell(Align(alignment: Alignment.centerRight, child: Text(NumberUtils.formatCurrency(row.tongTien)))),
        if (isCycleTable)
          DataCell(Align(
            alignment: Alignment.centerRight,
            child: Text(
              NumberUtils.formatCurrency(row.loi1So),
            ),
          )),
      ],
    );
  }

  DataRow2 _buildFullDataRow(BettingRow row, int index) {
    final isEven = index % 2 == 0;
    
    return DataRow2(
      color: MaterialStateProperty.all(
        isEven ? const Color(0xFF1E1E1E) : const Color(0xFF252525),
      ),
      cells: isCycleTable
          ? [
              DataCell(Center(child: Text(row.stt.toString()))),
              DataCell(Center(child: Text(row.ngay))),
              DataCell(Center(child: Text(row.mien))),
              DataCell(Center(child: Text(row.so, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)))),
              DataCell(Align(alignment: Alignment.centerRight, child: Text(NumberUtils.formatCurrency(row.cuocSo), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))),
              DataCell(Align(alignment: Alignment.centerRight, child: Text(NumberUtils.formatCurrency(row.cuocMien)))),
              DataCell(Align(alignment: Alignment.centerRight, child: Text(NumberUtils.formatCurrency(row.tongTien)))),
              DataCell(Align(alignment: Alignment.centerRight, child: Text(NumberUtils.formatCurrency(row.loi1So)))),
              DataCell(Align(alignment: Alignment.centerRight, child: Text(NumberUtils.formatCurrency(row.loi2So ?? 0)))),
            ]
          : [
              DataCell(Center(child: Text(row.stt.toString()))),
              DataCell(Center(child: Text(row.ngay))),
              DataCell(Center(child: Text(row.mien))),
              DataCell(Center(child: Text(row.so, style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)))),
              DataCell(Align(alignment: Alignment.centerRight, child: Text(NumberUtils.formatCurrency(row.cuocMien), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)))),
              DataCell(Align(alignment: Alignment.centerRight, child: Text(NumberUtils.formatCurrency(row.tongTien)))),
              DataCell(Align(alignment: Alignment.centerRight, child: Text(NumberUtils.formatCurrency(row.loi1So)))),
            ],
    );
  }
}
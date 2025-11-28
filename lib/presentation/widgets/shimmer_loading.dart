// ✅ TẠO FILE MỚI
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerLoading extends StatelessWidget {
  final ShimmerType type;

  const ShimmerLoading({
    super.key,
    this.type = ShimmerType.card,
  });
  
  @override
  Widget build(BuildContext context) {
    switch (type) {
      case ShimmerType.card:
        return _buildCardShimmer();
      case ShimmerType.list:
        return _buildListShimmer();
      case ShimmerType.table:
        return _buildTableShimmer();
      case ShimmerType.stats:
        return _buildStatsShimmer();
    }
  }

  Widget _buildCardShimmer() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF2C2C2C),
      highlightColor: const Color(0xFF3C3C3C),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Container(
            height: 140,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          );
        },
      ),
    );
  }

  Widget _buildListShimmer() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF2C2C2C),
      highlightColor: const Color(0xFF3C3C3C),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 8,
        itemBuilder: (context, index) {
          return Container(
            height: 72,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTableShimmer() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF2C2C2C),
      highlightColor: const Color(0xFF3C3C3C),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header
            Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(height: 8),
            // Rows
            ...List.generate(10, (index) {
              return Container(
                height: 56,
                margin: const EdgeInsets.only(bottom: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsShimmer() {
    return Shimmer.fromColors(
      baseColor: const Color(0xFF2C2C2C),
      highlightColor: const Color(0xFF3C3C3C),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Stats card
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(height: 16),
            // Grid items
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum ShimmerType {
  card,
  list,
  table,
  stats,
}
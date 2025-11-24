import 'package:flutter/material.dart';

class ContributionHeatmap extends StatelessWidget {
  final Map<DateTime, int> data;

  const ContributionHeatmap({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // 展示近2个月 (约9周)
    const int weeksToShow = 9;
    final now = DateTime.now();
    // 确保结束日期是今天所在的周日或者周六，这里简单往前推
    final startDate = now.subtract(const Duration(days: 7 * weeksToShow - 1));

    return SizedBox(
      height: 140,
      child: Center(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          reverse: true, // 最新在右边
          child: Row(
            children: List.generate(weeksToShow, (weekIndex) {
              return Column(
                children: List.generate(7, (dayIndex) {
                  final date = startDate.add(Duration(days: weekIndex * 7 + dayIndex));
                  final normalizedDate = DateTime(date.year, date.month, date.day);
                  final count = data[normalizedDate] ?? 0;
                  
                  // 黄橙红色系
                  Color color;
                  if (count == 0) {
                    color = const Color(0xFFEEEEEE); // 浅灰
                  } else if (count == 1) {
                    color = const Color(0xFFFFE0B2); // 浅橙黄
                  } else if (count == 2) {
                    color = const Color(0xFFFFB74D); // 橙色
                  } else if (count == 3) {
                    color = const Color(0xFFFF9800); // 深橙
                  } else {
                    color = const Color(0xFFE65100); // 深红橙
                  }

                  return Container(
                    width: 16,
                    height: 16,
                    margin: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              );
            }),
          ),
        ),
      ),
    );
  }
}

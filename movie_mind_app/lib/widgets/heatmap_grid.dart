import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ContributionHeatmap extends StatelessWidget {
  final Map<DateTime, int> data;

  const ContributionHeatmap({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    // 配置参数
    const int totalColumns = 53; // 显示约一年的数据 (53周)
    const double boxSize = 10.0; // 格子大小 (缩小)
    const double boxMargin = 1.5; // 格子间距 (缩小)
    const double totalBoxSize = boxSize + boxMargin * 2;
    
    final now = DateTime.now();
    final endDate = DateTime(now.year, now.month, now.day);
    
    // 计算起始日期
    // 假设每周从周日开始 (Sunday = 0)
    // DateTime.weekday: Mon=1, ..., Sun=7
    final int currentWeekDayIndex = now.weekday % 7; // Sun=0, Mon=1, ..., Sat=6
    
    // 当前周的周日 (作为这一列的起始)
    final currentWeekStart = endDate.subtract(Duration(days: currentWeekDayIndex));
    
    // 整个图表的起始日期（往前推52周，共53周）
    final gridStartDate = currentWeekStart.subtract(const Duration(days: (totalColumns - 1) * 7));

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 左侧：星期标签
        Padding(
          padding: const EdgeInsets.only(top: 16), // 为月份标签留出空间 (缩小顶部间距)
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 0=Sun, 1=Mon, ..., 6=Sat
              // 全部显示
              _buildDayLabel('Sun', true, totalBoxSize),
              _buildDayLabel('Mon', true, totalBoxSize),
              _buildDayLabel('Tue', true, totalBoxSize),
              _buildDayLabel('Wed', true, totalBoxSize),
              _buildDayLabel('Thu', true, totalBoxSize),
              _buildDayLabel('Fri', true, totalBoxSize),
              _buildDayLabel('Sat', true, totalBoxSize),
            ],
          ),
        ),
        const SizedBox(width: 4),
        // 右侧：可滚动的热度图
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            reverse: true, // 默认显示最右边（最新日期）
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 顶部：月份标签
                _buildMonthLabels(gridStartDate, totalColumns, totalBoxSize),
                const SizedBox(height: 2),
                // 热度方格
                _buildGrid(gridStartDate, totalColumns, boxSize, boxMargin),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDayLabel(String text, bool visible, double height) {
    return SizedBox(
      height: height,
      child: Center(
        child: visible
            ? Text(
                text,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 8, // 缩小字号
                  height: 1.0,
                ),
              )
            : null,
      ),
    );
  }

  Widget _buildMonthLabels(DateTime startDate, int columns, double itemWidth) {
    List<Widget> labels = [];
    DateTime currentWeek = startDate;

    for (int i = 0; i < columns; i++) {
      // 检查这一周是否包含月份的第一天
      bool isMonthStart = false;
      for(int d=0; d<7; d++) {
        final date = currentWeek.add(Duration(days: d));
        if (date.day == 1) {
          isMonthStart = true;
          break;
        }
      }

      if (isMonthStart) {
        // 找到这一周里的那个月份
        DateTime targetDate = currentWeek;
        for(int d=0; d<7; d++) {
           if (currentWeek.add(Duration(days: d)).day == 1) {
             targetDate = currentWeek.add(Duration(days: d));
             break;
           }
        }
        
        final monthName = DateFormat.MMM().format(targetDate);
        
        labels.add(
          SizedBox(
            width: itemWidth,
            child: Text(
              monthName,
              style: const TextStyle(color: Colors.grey, fontSize: 8), // 缩小字号
              overflow: TextOverflow.visible,
              softWrap: false,
            ),
          ),
        );
      } else {
        labels.add(SizedBox(width: itemWidth));
      }

      currentWeek = currentWeek.add(const Duration(days: 7));
    }

    return Row(children: labels);
  }

  Widget _buildGrid(DateTime startDate, int columns, double boxSize, double margin) {
    return Row(
      children: List.generate(columns, (colIndex) {
        final weekStart = startDate.add(Duration(days: colIndex * 7));
        return Column(
          children: List.generate(7, (rowIndex) {
            // rowIndex 0=Sun ... 6=Sat
            final date = weekStart.add(Duration(days: rowIndex));
            final normalizedDate = DateTime(date.year, date.month, date.day);
            
            final count = data[normalizedDate] ?? 0;

            return Container(
              width: boxSize,
              height: boxSize,
              margin: EdgeInsets.all(margin),
              decoration: BoxDecoration(
                color: _getColor(count),
                borderRadius: BorderRadius.circular(1.5), 
              ),
              child: Tooltip(
                message: '${DateFormat('yyyy-MM-dd').format(date)}: $count',
                child: const SizedBox(),
              ),
            );
          }),
        );
      }),
    );
  }

  Color _getColor(int count) {
    if (count == 0) return const Color(0xFFEEEEEE); // 浅灰
    if (count == 1) return const Color(0xFFFFE0B2); // 浅橙
    if (count <= 3) return const Color(0xFFFFB74D); // 中橙
    if (count <= 5) return const Color(0xFFFF9800); // 深橙
    return const Color(0xFFE65100); // 红/深红橙
  }
}

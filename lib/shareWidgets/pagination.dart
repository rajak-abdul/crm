import 'package:flutter/material.dart';

class PaginationWidget extends StatelessWidget {
  final int currentPage;
  final int totalItems;
  final int pageSize;
  final ValueChanged<int> onPageChanged;

  const PaginationWidget({
    super.key,
    required this.currentPage,
    required this.totalItems,
    required this.pageSize,
    required this.onPageChanged,
  });

  int get totalPages {
    final pages = (totalItems / pageSize).ceil();
    return pages == 0 ? 1 : pages;
  }

  @override
  Widget build(BuildContext context) {
    final start = totalItems == 0
        ? 0
        : ((currentPage - 1) * pageSize) + 1;

    final end = (currentPage * pageSize) > totalItems
        ? totalItems
        : currentPage * pageSize;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: const Border(
          top: BorderSide(color: Colors.black12),
        ),
      ),
      child: Row(
        children: [
          Text(
            "$start-$end of $totalItems",
            style: const TextStyle(fontSize: 13),
          ),

          const Spacer(),

          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: currentPage > 1
                ? () => onPageChanged(currentPage - 1)
                : null,
          ),

          Text(
            "$currentPage / $totalPages",
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),

          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: currentPage < totalPages
                ? () => onPageChanged(currentPage + 1)
                : null,
          ),
        ],
      ),
    );
  }
}
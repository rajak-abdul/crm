import 'package:flutter/material.dart';

class PaginationWidget extends StatelessWidget {
  final int currentPage;
  final int totalItems;
  final int pageSize;
  final List<int> pageSizeOptions;

  final ValueChanged<int> onPageChanged;
  final ValueChanged<int> onPageSizeChanged;

  const PaginationWidget({
    super.key,
    required this.currentPage,
    required this.totalItems,
    required this.pageSize,
    required this.pageSizeOptions,
    required this.onPageChanged,
    required this.onPageSizeChanged,
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
        horizontal: 12,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: const Border(
          top: BorderSide(
            color: Colors.black12,
          ),
        ),
      ),
      child: Row(
        children: [
          // --------------------------------------------------
          // RECORD COUNT
          // --------------------------------------------------
          Text(
            '$start-$end of $totalItems',
            style: const TextStyle(
              fontSize: 12,
            ),
          ),

          const SizedBox(width: 12),

          // --------------------------------------------------
          // PAGE SIZE DROPDOWN
          // --------------------------------------------------
          const Text(
            'Rows:',
            style: TextStyle(
              fontSize: 12,
              color: Colors.black54,
            ),
          ),

          const SizedBox(width: 4),

          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(
              horizontal: 4,
            ),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.black12,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: pageSize,
                isDense: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down,
                  size: 17,
                ),
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.black87,
                ),
                items: pageSizeOptions.map((size) {
                  return DropdownMenuItem<int>(
                    value: size,
                    child: Text('$size'),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    onPageSizeChanged(value);
                  }
                },
              ),
            ),
          ),

          const Spacer(),

          // --------------------------------------------------
          // PREVIOUS
          // --------------------------------------------------
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.chevron_left,
              size: 20,
            ),
            onPressed: currentPage > 1
                ? () {
                    onPageChanged(
                      currentPage - 1,
                    );
                  }
                : null,
          ),

          // --------------------------------------------------
          // PAGE NUMBER
          // --------------------------------------------------
          Text(
            '$currentPage / $totalPages',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),

          // --------------------------------------------------
          // NEXT
          // --------------------------------------------------
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            icon: const Icon(
              Icons.chevron_right,
              size: 20,
            ),
            onPressed: currentPage < totalPages
                ? () {
                    onPageChanged(
                      currentPage + 1,
                    );
                  }
                : null,
          ),
        ],
      ),
    );
  }
}
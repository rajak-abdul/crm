import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ExportDealsDialog extends StatefulWidget {
  final String title;
  final String description;
  final Function(DateTime? startDate, DateTime? endDate) onExport;

  const ExportDealsDialog({
    super.key,
    required this.title,
    required this.description,
    required this.onExport,
  });

  @override
  State<ExportDealsDialog> createState() => _ExportDealsDialogState();
}

class _ExportDealsDialogState extends State<ExportDealsDialog> {
  DateTime? _startDate;
  DateTime? _endDate;

  final TextEditingController _startController =
      TextEditingController();

  final TextEditingController _endController =
      TextEditingController();

  @override
  void dispose() {
    _startController.dispose();
    _endController.dispose();
    super.dispose();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _startDate = picked;
        _startController.text =
            DateFormat('dd MMM yyyy').format(picked);
      });
    }
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _endDate ?? _startDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        _endDate = picked;
        _endController.text =
            DateFormat('dd MMM yyyy').format(picked);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
      ),
      child: SizedBox(
        width: 450,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.download_rounded,
                    color: Colors.blue,
                  ),
                  const SizedBox(width: 10),
                   Expanded(
                    child: Text(
                            widget.title,
                            style: const TextStyle(
                             fontSize: 20,
                             fontWeight: FontWeight.bold,
                              ),
                             ),
                  ),
                  IconButton(
                    splashRadius: 20,
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),

              const SizedBox(height: 10),

               Text(
  widget.description,
  textAlign: TextAlign.center,
  style: const TextStyle(
    color: Colors.grey,
    height: 1.4,
  ),
),

              const SizedBox(height: 25),

              TextField(
                controller: _startController,
                readOnly: true,
                onTap: _pickStartDate,
                decoration: InputDecoration(
                  labelText: "Start Date",
                  hintText: "Select start date",
                  prefixIcon: const Icon(Icons.calendar_month),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: _pickStartDate,
                  ),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              TextField(
                controller: _endController,
                readOnly: true,
                onTap: _pickEndDate,
                decoration: InputDecoration(
                  labelText: "End Date",
                  hintText: "Select end date",
                  prefixIcon: const Icon(Icons.calendar_month),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: _pickEndDate,
                  ),
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(10),
                  ),
                ),
              ),

              const SizedBox(height: 30),

              Row(
  children: [
    Expanded(
      child: OutlinedButton(
        onPressed: () => Navigator.pop(context),
        child: const Text("Cancel"),
      ),
    ),
    const SizedBox(width: 12),
    Expanded(
      child: ElevatedButton.icon(
        icon: const Icon(Icons.download, size: 18),
        label: const Text("Export"),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: () {
          if (_startDate != null &&
              _endDate != null &&
              _startDate!.isAfter(_endDate!)) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Start date cannot be after End date"),
              ),
            );
            return;
          }
          widget.onExport(_startDate, _endDate);
          Navigator.pop(context);
        },
      ),
    ),
  ],
),
            ],
          ),
        ),
      ),
    );
  }
}
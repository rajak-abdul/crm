import 'package:crm_app/screen/deals/modal/deal_modal.dart';
import 'package:crm_app/thems/app_themes.dart';
import 'package:flutter/material.dart';

class StageDropdown extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final String allLabel;

  const StageDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.allLabel = 'All Stages',
  });

  @override
  Widget build(BuildContext context) {
    final stages = [
      allLabel,
      ...DealConstants.stages,
    ];

    final selectedValue =
        stages.contains(value) ? value : allLabel;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppColors.primary.withOpacity(0.3),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedValue,
          isDense: true,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 18,
            color: AppColors.primary,
          ),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.primary,
          ),
          items: stages.map((stage) {
            return DropdownMenuItem<String>(
              value: stage,
              child: Text(stage),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              onChanged(value);
            }
          },
        ),
      ),
    );
  }
}
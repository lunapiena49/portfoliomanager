import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../domain/analysis_preset.dart';

/// Horizontal grid of selectable preset chips. Driven by the parent stateful
/// widget through [selected] and [onSelect].
class AnalysisPresetSelector extends StatelessWidget {
  final AnalysisPreset selected;
  final ValueChanged<AnalysisPreset> onSelect;

  const AnalysisPresetSelector({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8.w,
      runSpacing: 8.h,
      children: AnalysisPresets.all.map((definition) {
        final isSelected = definition.preset == selected;
        return ChoiceChip(
          selected: isSelected,
          label: Text(definition.titleKey.tr()),
          avatar: Icon(_iconFor(definition.preset), size: 18.w),
          onSelected: (_) => onSelect(definition.preset),
        );
      }).toList(),
    );
  }

  IconData _iconFor(AnalysisPreset preset) {
    switch (preset) {
      case AnalysisPreset.fullReview:
        return Icons.auto_awesome;
      case AnalysisPreset.riskAssessment:
        return Icons.warning_amber;
      case AnalysisPreset.diversification:
        return Icons.pie_chart;
      case AnalysisPreset.performanceReview:
        return Icons.trending_up;
      case AnalysisPreset.recommendations:
        return Icons.lightbulb;
      case AnalysisPreset.geographicExposure:
        return Icons.public;
      case AnalysisPreset.concentrationCheck:
        return Icons.crop_square;
    }
  }
}

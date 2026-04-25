import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../portfolio/domain/entities/portfolio_entities.dart';
import '../../domain/analysis_preset.dart';
import '../../domain/analysis_prompt_builder.dart';

/// "What the AI will see" panel shown above the send button.
///
/// Lists the [requiredSlices] of the current preset and lets the user opt-out
/// of individual slices for privacy. The "Preview payload" button opens a
/// dialog with the exact text that will be sent to Gemini.
class AnalysisTransparencyPanel extends StatelessWidget {
  final Portfolio portfolio;
  final String language;
  final AnalysisPresetDefinition presetDefinition;
  final Set<AnalysisDataSlice> activeSlices;
  final ValueChanged<AnalysisDataSlice> onToggleSlice;

  const AnalysisTransparencyPanel({
    super.key,
    required this.portfolio,
    required this.language,
    required this.presetDefinition,
    required this.activeSlices,
    required this.onToggleSlice,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.visibility, color: theme.primaryColor),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    'analysis.transparency.title'.tr(),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            SizedBox(height: 4.h),
            Text(
              'analysis.transparency.subtitle'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
            SizedBox(height: 12.h),
            ...AnalysisDataSlice.values
                .where((slice) => _isSliceAvailable(slice))
                .map((slice) {
              final isRequired =
                  presetDefinition.requiredSlices.contains(slice);
              final isActive = activeSlices.contains(slice);
              final isAlwaysOn = slice == AnalysisDataSlice.coreSummary;
              return CheckboxListTile(
                value: isActive,
                onChanged: isAlwaysOn
                    ? null
                    : (_) => onToggleSlice(slice),
                title: Text(AnalysisPresets.dataSliceI18nKey(slice).tr()),
                subtitle: isRequired
                    ? Text(
                        'analysis.transparency.required_by_preset'.tr(),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.hintColor,
                        ),
                      )
                    : null,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              );
            }),
            SizedBox(height: 8.h),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _showPreviewDialog(context),
                icon: const Icon(Icons.code),
                label: Text('analysis.transparency.preview_button'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isSliceAvailable(AnalysisDataSlice slice) {
    switch (slice) {
      case AnalysisDataSlice.investorProfile:
        return portfolio.profile != null;
      case AnalysisDataSlice.statistics:
        return portfolio.statistics != null;
      case AnalysisDataSlice.performanceHistory:
        return portfolio.historicalPerformance != null &&
            portfolio.historicalPerformance!.isNotEmpty;
      default:
        return true;
    }
  }

  Future<void> _showPreviewDialog(BuildContext context) {
    final preview = AnalysisPromptBuilder.build(
      portfolio: portfolio,
      language: language,
      slices: activeSlices,
      presetInstruction: presetDefinition.instruction.isEmpty
          ? null
          : presetDefinition.instruction,
    );

    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        return AlertDialog(
          title: Text('analysis.transparency.preview_title'.tr()),
          content: SizedBox(
            width: double.maxFinite,
            child: Scrollbar(
              child: SingleChildScrollView(
                child: SelectableText(
                  preview,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text('common.close'.tr()),
            ),
          ],
        );
      },
    );
  }
}

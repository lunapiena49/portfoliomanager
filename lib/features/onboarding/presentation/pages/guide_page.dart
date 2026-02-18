import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';

class GuidePage extends StatelessWidget {
  const GuidePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('guide.title'.tr()),
      ),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          _buildSection(
            context,
            icon: Icons.rocket_launch,
            titleKey: 'guide.sections.getting_started.title',
            contentKey: 'guide.sections.getting_started.content',
            detailsKey: 'guide.sections.getting_started.details',
            expanded: true,
          ),
          SizedBox(height: 16.h),
          _buildSection(
            context,
            icon: Icons.upload_file,
            titleKey: 'guide.sections.importing.title',
            contentKey: 'guide.sections.importing.content',
            detailsKey: 'guide.sections.importing.details',
          ),
          SizedBox(height: 16.h),
          _buildSection(
            context,
            icon: Icons.auto_awesome,
            titleKey: 'guide.sections.analysis.title',
            contentKey: 'guide.sections.analysis.content',
            detailsKey: 'guide.sections.analysis.details',
          ),
          SizedBox(height: 16.h),
          _buildSection(
            context,
            icon: Icons.dashboard_customize,
            titleKey: 'guide.sections.charts.title',
            contentKey: 'guide.sections.charts.content',
            detailsKey: 'guide.sections.charts.details',
          ),
          SizedBox(height: 16.h),
          _buildSection(
            context,
            icon: Icons.flag,
            titleKey: 'guide.sections.goals.title',
            contentKey: 'guide.sections.goals.content',
            detailsKey: 'guide.sections.goals.details',
          ),
          SizedBox(height: 16.h),
          _buildSection(
            context,
            icon: Icons.balance,
            titleKey: 'guide.sections.rebalancing.title',
            contentKey: 'guide.sections.rebalancing.content',
            detailsKey: 'guide.sections.rebalancing.details',
          ),
          SizedBox(height: 16.h),
          _buildSection(
            context,
            icon: Icons.show_chart,
            titleKey: 'guide.sections.market_data.title',
            contentKey: 'guide.sections.market_data.content',
            detailsKey: 'guide.sections.market_data.details',
          ),
          SizedBox(height: 16.h),
          _buildSection(
            context,
            icon: Icons.book,
            titleKey: 'guide.sections.glossary.title',
            contentKey: 'guide.sections.glossary.content',
            detailsKey: 'guide.sections.glossary.details',
          ),
          SizedBox(height: 32.h),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required IconData icon,
    required String titleKey,
    required String contentKey,
    required String detailsKey,
    bool expanded = false,
  }) {
    return Card(
      child: ExpansionTile(
        initiallyExpanded: expanded,
        leading: Icon(icon, color: Theme.of(context).primaryColor),
        title: Text(
          titleKey.tr(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        subtitle: Text(
          contentKey.tr(),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Text.rich(
              _buildMarkdownTextSpan(
                detailsKey.tr(),
                Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ),
        ],
      ),
    );
  }

  TextSpan _buildMarkdownTextSpan(String text, TextStyle? baseStyle) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*');
    int currentIndex = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > currentIndex) {
        spans.add(
          TextSpan(
            text: text.substring(currentIndex, match.start),
            style: baseStyle,
          ),
        );
      }

      final boldText = match.group(1) ?? '';
      spans.add(
        TextSpan(
          text: boldText,
          style: baseStyle?.copyWith(fontWeight: FontWeight.bold),
        ),
      );

      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      spans.add(
        TextSpan(
          text: text.substring(currentIndex),
          style: baseStyle,
        ),
      );
    }

    return TextSpan(children: spans, style: baseStyle);
  }
}

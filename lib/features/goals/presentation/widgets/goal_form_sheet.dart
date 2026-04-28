import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';

import '../../../../core/constants/app_constants.dart';
import '../bloc/goals_bloc.dart';
import '../../domain/entities/goals_entities.dart';

/// Bottom sheet for creating or editing an [InvestmentGoal].
///
/// Pass `existing == null` to create a new goal; pass an [InvestmentGoal]
/// instance to edit it. The sheet dispatches [AddGoalEvent] /
/// [UpdateGoalEvent] on save and pops itself when the bloc emits the next
/// loaded state.
class GoalFormSheet extends StatefulWidget {
  final InvestmentGoal? existing;
  final String defaultCurrency;

  const GoalFormSheet({
    super.key,
    this.existing,
    this.defaultCurrency = 'EUR',
  });

  @override
  State<GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends State<GoalFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descriptionCtrl;
  late final TextEditingController _targetAmountCtrl;
  late final TextEditingController _currentAmountCtrl;
  late final TextEditingController _monthlyCtrl;

  late GoalType _type;
  late String _currency;
  DateTime? _targetDate;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameCtrl = TextEditingController(text: existing?.name ?? '');
    _descriptionCtrl =
        TextEditingController(text: existing?.description ?? '');
    _targetAmountCtrl = TextEditingController(
      text: existing != null ? existing.targetAmount.toStringAsFixed(2) : '',
    );
    _currentAmountCtrl = TextEditingController(
      text: existing != null ? existing.currentAmount.toStringAsFixed(2) : '0',
    );
    _monthlyCtrl = TextEditingController(
      text: existing?.monthlyContribution != null
          ? existing!.monthlyContribution!.toStringAsFixed(2)
          : '',
    );
    _type = existing?.type ?? GoalType.savings;
    _currency = existing?.currency ?? widget.defaultCurrency;
    _targetDate = existing?.targetDate;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descriptionCtrl.dispose();
    _targetAmountCtrl.dispose();
    _currentAmountCtrl.dispose();
    _monthlyCtrl.dispose();
    super.dispose();
  }

  void _handleTypeChanged(GoalType type) {
    setState(() {
      _type = type;
      // Pre-fill an example target date based on the suggested horizon when
      // the user has not chosen one yet. This is a hint, not a constraint.
      final horizon = type.suggestedHorizonMonths;
      if (_targetDate == null && horizon != null) {
        _targetDate = DateTime.now().add(Duration(days: 30 * horizon));
      }
    });
  }

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final initial = _targetDate ?? now.add(const Duration(days: 365));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 50)),
    );
    if (picked != null) {
      setState(() => _targetDate = picked);
    }
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final name = _nameCtrl.text.trim();
    final description = _descriptionCtrl.text.trim();
    final targetAmount = double.parse(_targetAmountCtrl.text.replaceAll(',', '.'));
    final currentAmount = _currentAmountCtrl.text.trim().isEmpty
        ? 0.0
        : double.parse(_currentAmountCtrl.text.replaceAll(',', '.'));
    final monthly = _monthlyCtrl.text.trim().isEmpty
        ? null
        : double.parse(_monthlyCtrl.text.replaceAll(',', '.'));

    final bloc = context.read<GoalsBloc>();
    if (_isEdit) {
      final updated = widget.existing!.copyWith(
        name: name,
        description: description.isEmpty ? null : description,
        type: _type,
        targetAmount: targetAmount,
        currentAmount: currentAmount,
        currency: _currency,
        targetDate: _targetDate,
        monthlyContribution: monthly,
      );
      bloc.add(UpdateGoalEvent(goal: updated));
    } else {
      bloc.add(AddGoalEvent(
        name: name,
        description: description.isEmpty ? null : description,
        type: _type,
        targetAmount: targetAmount,
        currency: _currency,
        targetDate: _targetDate,
        monthlyContribution: monthly,
      ));
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.6,
      maxChildSize: 0.98,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              // Header
              Padding(
                padding: EdgeInsets.fromLTRB(16.w, 16.h, 8.w, 8.h),
                child: Row(
                  children: [
                    Icon(
                      _isEdit ? Icons.edit : Icons.flag,
                      color: theme.primaryColor,
                    ),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        _isEdit
                            ? 'goals.form.title_edit'.tr()
                            : 'goals.form.title_new'.tr(),
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    controller: scrollController,
                    padding: EdgeInsets.all(16.w),
                    children: [
                      _buildTypePicker(context),
                      SizedBox(height: 24.h),
                      _buildSectionTitle(
                        context,
                        'goals.form.section_basics'.tr(),
                      ),
                      SizedBox(height: 12.h),
                      TextFormField(
                        controller: _nameCtrl,
                        decoration: InputDecoration(
                          labelText: 'goals.form.name'.tr(),
                          hintText: 'goals.form.name_hint'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                        textInputAction: TextInputAction.next,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'goals.form.name_required'.tr();
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 12.h),
                      TextFormField(
                        controller: _descriptionCtrl,
                        decoration: InputDecoration(
                          labelText: 'goals.form.description'.tr(),
                          hintText: 'goals.form.description_hint'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                        maxLines: 2,
                      ),
                      SizedBox(height: 24.h),
                      _buildSectionTitle(
                        context,
                        'goals.form.section_amount'.tr(),
                      ),
                      SizedBox(height: 12.h),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _targetAmountCtrl,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9.,]'),
                                ),
                              ],
                              decoration: InputDecoration(
                                labelText: 'goals.form.target_amount'.tr(),
                                border: const OutlineInputBorder(),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'goals.form.amount_required'.tr();
                                }
                                final parsed =
                                    double.tryParse(v.replaceAll(',', '.'));
                                if (parsed == null || parsed <= 0) {
                                  return 'goals.form.amount_invalid'.tr();
                                }
                                return null;
                              },
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _currency,
                              decoration: InputDecoration(
                                labelText: 'goals.form.currency'.tr(),
                                border: const OutlineInputBorder(),
                              ),
                              items: AppConstants.supportedCurrencies
                                  .map((c) => DropdownMenuItem(
                                        value: c,
                                        child: Text(c),
                                      ))
                                  .toList(),
                              onChanged: (v) =>
                                  setState(() => _currency = v ?? 'EUR'),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      TextFormField(
                        controller: _currentAmountCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.,]'),
                          ),
                        ],
                        decoration: InputDecoration(
                          labelText: 'goals.form.current_amount'.tr(),
                          helperText: 'goals.form.current_amount_help'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 24.h),
                      _buildSectionTitle(
                        context,
                        'goals.form.section_plan'.tr(),
                      ),
                      SizedBox(height: 12.h),
                      InkWell(
                        onTap: () => _pickDate(context),
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'goals.form.target_date'.tr(),
                            helperText:
                                'goals.form.target_date_help'.tr(),
                            border: const OutlineInputBorder(),
                            suffixIcon: const Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            _targetDate != null
                                ? DateFormat.yMMMd(context.locale.toString())
                                    .format(_targetDate!)
                                : 'goals.form.target_date_none'.tr(),
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      TextFormField(
                        controller: _monthlyCtrl,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9.,]'),
                          ),
                        ],
                        decoration: InputDecoration(
                          labelText: 'goals.form.monthly'.tr(),
                          helperText: 'goals.form.monthly_help'.tr(),
                          border: const OutlineInputBorder(),
                        ),
                      ),
                      SizedBox(height: 24.h),
                      _buildPrivacyHint(context),
                      SizedBox(height: 80.h),
                    ],
                  ),
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('common.cancel'.tr()),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton.icon(
                          onPressed: _save,
                          icon: Icon(_isEdit ? Icons.save : Icons.add),
                          label: Text(_isEdit
                              ? 'common.save'.tr()
                              : 'goals.form.create'.tr()),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }

  Widget _buildTypePicker(BuildContext context) {
    final theme = Theme.of(context);
    final tiers = <GoalTier>[
      GoalTier.entry,
      GoalTier.intermediate,
      GoalTier.expert,
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'goals.form.section_type'.tr()),
        SizedBox(height: 4.h),
        Text(
          'goals.form.section_type_help'.tr(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        SizedBox(height: 12.h),
        for (final tier in tiers) ...[
          _buildTierHeader(context, tier),
          SizedBox(height: 8.h),
          Wrap(
            spacing: 8.w,
            runSpacing: 8.h,
            children: GoalType.values
                .where((t) => t.tier == tier)
                .map((t) => _buildTypeChip(context, t))
                .toList(),
          ),
          SizedBox(height: 16.h),
        ],
      ],
    );
  }

  Widget _buildTierHeader(BuildContext context, GoalTier tier) {
    String label;
    Color color;
    IconData icon;
    switch (tier) {
      case GoalTier.entry:
        label = 'goals.tiers.entry'.tr();
        color = Colors.green;
        icon = Icons.eco_outlined;
        break;
      case GoalTier.intermediate:
        label = 'goals.tiers.intermediate'.tr();
        color = Colors.blue;
        icon = Icons.bolt_outlined;
        break;
      case GoalTier.expert:
        label = 'goals.tiers.expert'.tr();
        color = Colors.purple;
        icon = Icons.workspace_premium_outlined;
        break;
    }
    return Row(
      children: [
        Icon(icon, size: 16.w, color: color),
        SizedBox(width: 6.w),
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }

  Widget _buildTypeChip(BuildContext context, GoalType type) {
    final theme = Theme.of(context);
    final selected = _type == type;
    final color = _typeColor(type);
    final label = 'goals.types.${type.name}'.tr();
    return ChoiceChip(
      avatar: Icon(
        _typeIcon(type),
        size: 16.w,
        color: selected ? Colors.white : color,
      ),
      label: Text(label),
      selected: selected,
      selectedColor: color,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      labelStyle: TextStyle(
        color: selected ? Colors.white : theme.colorScheme.onSurface,
        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
      ),
      onSelected: (_) => _handleTypeChanged(type),
    );
  }

  Widget _buildPrivacyHint(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(
          color: theme.colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_outline,
            size: 18.w,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              'goals.form.privacy_hint'.tr(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _typeColor(GoalType type) {
    switch (type) {
      case GoalType.retirement:
        return Colors.purple;
      case GoalType.emergency:
        return Colors.red;
      case GoalType.house:
        return Colors.blue;
      case GoalType.education:
        return Colors.green;
      case GoalType.travel:
        return Colors.orange;
      case GoalType.custom:
        return Colors.grey;
      case GoalType.savings:
        return Colors.teal;
      case GoalType.debtRepayment:
        return Colors.deepOrange;
      case GoalType.bigPurchase:
        return Colors.amber;
      case GoalType.wedding:
        return Colors.pink;
      case GoalType.family:
        return Colors.lightGreen;
      case GoalType.carPurchase:
        return Colors.indigo;
      case GoalType.passiveIncome:
        return Colors.cyan;
      case GoalType.portfolioGrowth:
        return Colors.deepPurple;
      case GoalType.earlyRetirement:
        return Colors.purpleAccent;
      case GoalType.dividendIncome:
        return Colors.lime;
      case GoalType.diversification:
        return Colors.brown;
      case GoalType.riskManagement:
        return Colors.redAccent;
      case GoalType.taxOptimization:
        return Colors.blueGrey;
      case GoalType.estatePlanning:
        return Colors.deepOrangeAccent;
    }
  }

  IconData _typeIcon(GoalType type) {
    switch (type) {
      case GoalType.retirement:
        return Icons.beach_access;
      case GoalType.emergency:
        return Icons.health_and_safety;
      case GoalType.house:
        return Icons.home;
      case GoalType.education:
        return Icons.school;
      case GoalType.travel:
        return Icons.flight;
      case GoalType.custom:
        return Icons.star;
      case GoalType.savings:
        return Icons.savings;
      case GoalType.debtRepayment:
        return Icons.credit_card_off;
      case GoalType.bigPurchase:
        return Icons.shopping_cart_checkout;
      case GoalType.wedding:
        return Icons.favorite;
      case GoalType.family:
        return Icons.family_restroom;
      case GoalType.carPurchase:
        return Icons.directions_car;
      case GoalType.passiveIncome:
        return Icons.payments;
      case GoalType.portfolioGrowth:
        return Icons.trending_up;
      case GoalType.earlyRetirement:
        return Icons.self_improvement;
      case GoalType.dividendIncome:
        return Icons.account_balance;
      case GoalType.diversification:
        return Icons.donut_large;
      case GoalType.riskManagement:
        return Icons.shield;
      case GoalType.taxOptimization:
        return Icons.receipt_long;
      case GoalType.estatePlanning:
        return Icons.gavel;
    }
  }
}

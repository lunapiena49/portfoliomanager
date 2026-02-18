import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/portfolio_entities.dart';
import '../../domain/utils/portfolio_region_mapper.dart';
import '../bloc/portfolio_bloc.dart';

class EditPositionPage extends StatefulWidget {
  final String positionId;

  const EditPositionPage({super.key, required this.positionId});

  @override
  State<EditPositionPage> createState() => _EditPositionPageState();
}

class _EditPositionPageState extends State<EditPositionPage> {
  final _formKey = GlobalKey<FormState>();

  Position? _position;
  bool _positionNotFound = false;

  // Controllers
  final _symbolController = TextEditingController();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController();
  final _priceController = TextEditingController();
  final _costBasisController = TextEditingController();
  final _isinController = TextEditingController();
  final _exchangeController = TextEditingController();

  // Dropdown values
  String _selectedAssetType = 'Stocks';
  String _selectedSector = 'Other';
  String _selectedCurrency = 'EUR';
  String _selectedRegion = PortfolioRegionMapper.auto;

  final List<String> _assetTypes = [
    'Stocks',
    'ETFs',
    'Bonds',
    'Crypto',
    'Funds',
    'Options',
    'Futures',
    'Cash',
    'CFDs',
    'Commodities',
    'Real Estate',
    'Other',
  ];

  final List<String> _sectors = [
    'Technology',
    'Financials',
    'Healthcare',
    'Consumer Cyclicals',
    'Consumer Non-Cyclicals',
    'Industrials',
    'Basic Materials',
    'Energy',
    'Utilities',
    'Real Estate',
    'Communications',
    'Broad',
    'Other',
  ];

  final List<String> _currencies = [
    'EUR',
    'USD',
    'GBP',
    'CHF',
    'JPY',
    'CAD',
    'AUD',
  ];

  final List<String> _regionOptions = PortfolioRegionMapper.selectableCodes;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _hydrateFromState(context.read<PortfolioBloc>().state);
  }

  @override
  void dispose() {
    _symbolController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    _priceController.dispose();
    _costBasisController.dispose();
    _isinController.dispose();
    _exchangeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PortfolioBloc, PortfolioState>(
      listener: (context, state) {
        if (state is PortfolioLoaded) {
          if (_position == null && !_positionNotFound) {
            _hydrateFromState(state);
          }

          if (_isSaving) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('edit_position.success'.tr()),
                backgroundColor: AppTheme.successColor,
              ),
            );
            context.pop();
          }
        } else if (state is PortfolioError && _isSaving) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message.tr()),
              backgroundColor: AppTheme.errorColor,
            ),
          );
          setState(() => _isSaving = false);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('edit_position.title'.tr()),
        ),
        body: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_positionNotFound) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                color: AppTheme.errorColor,
                size: 48.w,
              ),
              SizedBox(height: 16.h),
              Text(
                'edit_position.not_found'.tr(),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16.h),
              TextButton(
                onPressed: () => context.pop(),
                child: Text('common.back'.tr()),
              ),
            ],
          ),
        ),
      );
    }

    if (_position == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            SizedBox(height: 24.h),

            _buildSectionHeader('add_position.required_fields'.tr()),
            SizedBox(height: 12.h),

            _buildTextField(
              controller: _symbolController,
              label: 'portfolio.position.symbol'.tr(),
              hint: 'e.g., AAPL, MSFT, VWCE',
              required: true,
              textCapitalization: TextCapitalization.characters,
            ),
            SizedBox(height: 12.h),

            _buildTextField(
              controller: _nameController,
              label: 'portfolio.position.name'.tr(),
              hint: 'e.g., Apple Inc.',
              required: true,
            ),
            SizedBox(height: 12.h),

            _buildTextField(
              controller: _quantityController,
              label: 'portfolio.position.quantity'.tr(),
              hint: 'e.g., 10.5',
              required: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: _validateNumber,
            ),
            SizedBox(height: 12.h),

            _buildTextField(
              controller: _priceController,
              label: 'portfolio.position.price'.tr(),
              hint: 'e.g., 175.50',
              required: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: _validateNumber,
            ),
            SizedBox(height: 24.h),

            _buildSectionHeader('add_position.optional_fields'.tr()),
            SizedBox(height: 12.h),

            _buildTextField(
              controller: _costBasisController,
              label: 'portfolio.position.cost_basis'.tr(),
              hint: 'add_position.cost_basis_hint'.tr(),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: _validateOptionalNumber,
            ),
            SizedBox(height: 12.h),

            _buildTextField(
              controller: _isinController,
              label: 'ISIN',
              hint: 'e.g., US0378331005',
              textCapitalization: TextCapitalization.characters,
            ),
            SizedBox(height: 12.h),

            _buildTextField(
              controller: _exchangeController,
              label: 'edit_position.exchange_label'.tr(),
              hint: 'edit_position.exchange_hint'.tr(),
              textCapitalization: TextCapitalization.characters,
            ),
            SizedBox(height: 16.h),

            _buildDropdown(
              label: 'portfolio.position.asset_type'.tr(),
              value: _selectedAssetType,
              items: _assetTypes,
              itemLabel: (item) => _getAssetTypeLabel(context, item),
              onChanged: (value) => setState(() => _selectedAssetType = value!),
            ),
            SizedBox(height: 12.h),

            _buildDropdown(
              label: 'portfolio.position.sector'.tr(),
              value: _selectedSector,
              items: _sectors,
              itemLabel: (item) => _getSectorLabel(context, item),
              onChanged: (value) => setState(() => _selectedSector = value!),
            ),
            SizedBox(height: 12.h),

            _buildDropdown(
              label: 'portfolio.position.currency'.tr(),
              value: _selectedCurrency,
              items: _currencies,
              onChanged: (value) => setState(() => _selectedCurrency = value!),
            ),
            SizedBox(height: 12.h),

            _buildDropdown(
              label: 'portfolio.position.region'.tr(),
              value: _selectedRegion,
              items: _regionOptions,
              helperText: 'portfolio.position.region_hint'.tr(),
              itemLabel: (code) => _getRegionLabel(context, code),
              onChanged: (value) => setState(() {
                _selectedRegion = value ?? PortfolioRegionMapper.auto;
              }),
            ),
            SizedBox(height: 32.h),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _submitPosition,
                child: _isSaving
                    ? SizedBox(
                        width: 20.w,
                        height: 20.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text('edit_position.save_button'.tr()),
              ),
            ),
            SizedBox(height: 16.h),
          ],
        ),
      ),
    );
  }

  void _hydrateFromState(PortfolioState state) {
    if (state is! PortfolioLoaded) return;

    final position = _findPosition(state.portfolio.positions);
    if (position == null) {
      setState(() => _positionNotFound = true);
      return;
    }

    setState(() {
      _position = position;
      _symbolController.text = position.symbol;
      _nameController.text = position.name;
      _quantityController.text = position.quantity.toString();
      _priceController.text = position.closePrice.toString();
      _costBasisController.text = position.costBasis.toString();
      _isinController.text = position.isin ?? '';
      _exchangeController.text = position.exchange ?? '';

      _selectedAssetType = _resolveDropdownValue(
        _assetTypes,
        position.assetType,
        fallback: 'Other',
      );
      _selectedSector = _resolveDropdownValue(
        _sectors,
        position.sector,
        fallback: 'Other',
      );
      _selectedCurrency = _resolveDropdownValue(
        _currencies,
        position.currency,
        fallback: _currencies.first,
      );

      final regionOverride = position.regionOverride;
      _selectedRegion = _regionOptions.contains(regionOverride)
          ? regionOverride ?? PortfolioRegionMapper.auto
          : PortfolioRegionMapper.auto;
    });
  }

  Position? _findPosition(List<Position> positions) {
    for (final position in positions) {
      if (position.id == widget.positionId) {
        return position;
      }
    }
    return null;
  }

  String _resolveDropdownValue(
    List<String> options,
    String value, {
    required String fallback,
  }) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return fallback;
    if (!options.contains(value)) {
      options.add(value);
    }
    return value;
  }

  Widget _buildInfoCard() {
    return Card(
      color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          children: [
            Icon(
              Icons.edit_outlined,
              color: Theme.of(context).primaryColor,
              size: 24.w,
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Text(
                'edit_position.info'.tr(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    bool required = false,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      decoration: InputDecoration(
        labelText: required ? '$label *' : label,
        hintText: hint,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
        ),
      ),
      validator: required
          ? (value) {
              if (value == null || value.trim().isEmpty) {
                return 'add_position.field_required'.tr();
              }
              return validator?.call(value);
            }
          : validator,
    );
  }

  Widget _buildDropdown({
    required String label,
    required String value,
    required List<String> items,
    required void Function(String?) onChanged,
    String Function(String)? itemLabel,
    String? helperText,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
        ),
      ),
      items: items.map((item) {
        return DropdownMenuItem<String>(
          value: item,
          child: Text(itemLabel?.call(item) ?? item),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  String _getAssetTypeLabel(BuildContext context, String assetType) {
    switch (assetType.trim().toLowerCase()) {
      case 'stocks':
        return 'portfolio.asset_types.stocks'.tr();
      case 'etfs':
        return 'portfolio.asset_types.etfs'.tr();
      case 'bonds':
        return 'portfolio.asset_types.bonds'.tr();
      case 'crypto':
        return 'portfolio.asset_types.crypto'.tr();
      case 'funds':
        return 'portfolio.asset_types.funds'.tr();
      case 'options':
        return 'portfolio.asset_types.options'.tr();
      case 'futures':
        return 'portfolio.asset_types.futures'.tr();
      case 'cash':
        return 'portfolio.asset_types.cash'.tr();
      case 'cfds':
        return 'portfolio.asset_types.cfds'.tr();
      case 'commodities':
        return 'portfolio.asset_types.commodities'.tr();
      case 'real estate':
        return 'portfolio.asset_types.real_estate'.tr();
      case 'other':
        return 'portfolio.asset_types.other'.tr();
      default:
        return assetType;
    }
  }

  String _getSectorLabel(BuildContext context, String sector) {
    switch (sector.trim().toLowerCase()) {
      case 'technology':
        return 'portfolio.sectors.technology'.tr();
      case 'financials':
        return 'portfolio.sectors.financials'.tr();
      case 'healthcare':
        return 'portfolio.sectors.healthcare'.tr();
      case 'consumer cyclicals':
        return 'portfolio.sectors.consumer_cyclicals'.tr();
      case 'consumer non-cyclicals':
        return 'portfolio.sectors.consumer_non_cyclicals'.tr();
      case 'industrials':
        return 'portfolio.sectors.industrials'.tr();
      case 'basic materials':
        return 'portfolio.sectors.basic_materials'.tr();
      case 'energy':
        return 'portfolio.sectors.energy'.tr();
      case 'utilities':
        return 'portfolio.sectors.utilities'.tr();
      case 'real estate':
        return 'portfolio.sectors.real_estate'.tr();
      case 'communications':
        return 'portfolio.sectors.communications'.tr();
      case 'broad':
        return 'portfolio.sectors.broad'.tr();
      case 'other':
        return 'portfolio.sectors.other'.tr();
      default:
        return sector;
    }
  }

  String _getRegionLabel(BuildContext context, String code) {
    switch (code) {
      case PortfolioRegionMapper.auto:
        return 'portfolio.position.region_auto'.tr();
      case PortfolioRegionMapper.unitedStates:
        return 'portfolio.charts.regions.us'.tr();
      case PortfolioRegionMapper.europe:
        return 'portfolio.charts.regions.europe'.tr();
      case PortfolioRegionMapper.asia:
        return 'portfolio.charts.regions.asia'.tr();
      case PortfolioRegionMapper.restOfWorld:
        return 'portfolio.charts.regions.rest_world'.tr();
      case PortfolioRegionMapper.liquidity:
        return 'portfolio.charts.regions.liquidity'.tr();
      case PortfolioRegionMapper.commodities:
        return 'portfolio.charts.regions.commodities'.tr();
      case PortfolioRegionMapper.unassigned:
      default:
        return 'portfolio.charts.regions.unassigned'.tr();
    }
  }

  String? _validateNumber(String? value) {
    if (value == null || value.isEmpty) return null;
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null) {
      return 'add_position.invalid_number'.tr();
    }
    if (parsed <= 0) {
      return 'add_position.must_be_positive'.tr();
    }
    return null;
  }

  String? _validateOptionalNumber(String? value) {
    if (value == null || value.isEmpty) return null;
    final parsed = double.tryParse(value.replaceAll(',', '.'));
    if (parsed == null) {
      return 'add_position.invalid_number'.tr();
    }
    return null;
  }

  void _submitPosition() {
    if (!_formKey.currentState!.validate()) return;
    if (_position == null) return;

    setState(() => _isSaving = true);

    final quantity = double.parse(_quantityController.text.replaceAll(',', '.'));
    final price = double.parse(_priceController.text.replaceAll(',', '.'));
    final value = quantity * price;

    double costBasis = value;
    if (_costBasisController.text.isNotEmpty) {
      costBasis =
          double.parse(_costBasisController.text.replaceAll(',', '.'));
    }

    final updated = _position!.copyWith(
      symbol: _symbolController.text.trim().toUpperCase(),
      name: _nameController.text.trim(),
      assetType: _selectedAssetType,
      sector: _selectedSector,
      currency: _selectedCurrency,
      regionOverride: _selectedRegion == PortfolioRegionMapper.auto
          ? null
          : _selectedRegion,
      quantity: quantity,
      closePrice: price,
      value: value,
      costBasis: costBasis,
      unrealizedPnL: value - costBasis,
      isin: _isinController.text.trim().isNotEmpty
          ? _isinController.text.trim().toUpperCase()
          : null,
      exchange: _exchangeController.text.trim().isNotEmpty
          ? _exchangeController.text.trim()
          : null,
      lastUpdated: DateTime.now(),
    );

    context.read<PortfolioBloc>().add(UpdatePositionEvent(updated));
  }
}

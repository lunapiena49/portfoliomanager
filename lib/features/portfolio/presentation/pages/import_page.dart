import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:file_picker/file_picker.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/entities/portfolio_entities.dart';
import '../bloc/portfolio_bloc.dart';
import '../../../../services/parsers/base_parser.dart';
import '../../../../services/parsers/parser_factory.dart';
import '../../../../services/parsers/pdf_import_parser.dart';

// [UPDATED] Import target selection
enum ImportTarget { createNew, addToExisting }

class ImportPage extends StatefulWidget {
  final bool embedded;
  final bool allowExistingTarget;

  const ImportPage({
    super.key,
    this.embedded = false,
    this.allowExistingTarget = true,
  });

  @override
  State<ImportPage> createState() => _ImportPageState();
}

class _ImportPageState extends State<ImportPage> {
  String? _selectedBroker;
  List<ImportFileData> _selectedFiles = [];
  bool _isLoading = false;
  final TextEditingController _portfolioNameController = TextEditingController();
  ImportTarget _importTarget = ImportTarget.createNew;
  String? _selectedPortfolioId;

  final List<BrokerInfo> _brokers = [
    BrokerInfo(id: 'ibkr', name: 'Interactive Brokers', icon: Icons.account_balance, color: Colors.red, region: 'Global'),
    BrokerInfo(id: 'td_ameritrade', name: 'TD Ameritrade', icon: Icons.account_balance, color: Colors.green, region: 'USA'),
    BrokerInfo(id: 'fidelity', name: 'Fidelity', icon: Icons.account_balance, color: Colors.teal, region: 'USA'),
    BrokerInfo(id: 'charles_schwab', name: 'Charles Schwab', icon: Icons.account_balance, color: Colors.blue, region: 'USA'),
    BrokerInfo(id: 'etrade', name: 'E*TRADE', icon: Icons.account_balance, color: Colors.purple, region: 'USA'),
    BrokerInfo(id: 'robinhood', name: 'Robinhood', icon: Icons.account_balance, color: Colors.green, region: 'USA'),
    BrokerInfo(id: 'vanguard', name: 'Vanguard', icon: Icons.account_balance, color: Colors.brown, region: 'USA'),
    BrokerInfo(id: 'degiro', name: 'DEGIRO', icon: Icons.account_balance, color: Colors.blue, region: 'Europe'),
    BrokerInfo(id: 'trading212', name: 'Trading 212', icon: Icons.account_balance, color: Colors.cyan, region: 'Europe'),
    BrokerInfo(id: 'xtb', name: 'XTB', icon: Icons.account_balance, color: Colors.lime, region: 'Europe'),
    BrokerInfo(id: 'revolut', name: 'Revolut', icon: Icons.account_balance, color: Colors.indigo, region: 'Global'),
    BrokerInfo(id: 'other', name: 'Other (Generic)', icon: Icons.description, color: Colors.grey, region: 'Any'),
  ];

  @override
  void initState() {
    super.initState();
    if (!widget.allowExistingTarget) {
      _importTarget = ImportTarget.createNew;
      _selectedPortfolioId = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final form = BlocListener<PortfolioBloc, PortfolioState>(
      listener: (context, state) {
        if (state is PortfolioImportSuccess) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('import.success'.tr()),
              backgroundColor: AppTheme.successColor,
            ),
          );
          context.pop();
        } else if (state is PortfolioError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message.tr()),
              backgroundColor: AppTheme.errorColor,
            ),
          );
          setState(() => _isLoading = false);
        } else if (state is PortfolioImporting) {
          setState(() => _isLoading = true);
        }
      },
      child: BlocBuilder<PortfolioBloc, PortfolioState>(
        builder: (context, state) {
          final portfolios = state is PortfolioLoaded
              ? state.allPortfolios
              : const <Portfolio>[];
          return _buildForm(portfolios);
        },
      ),
    );

    if (widget.embedded) {
      return form;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('import.title'.tr()),
      ),
      body: form,
    );
  }

  Widget _buildForm(List<Portfolio> portfolios) {
    final effectiveTarget = widget.allowExistingTarget
        ? _importTarget
        : ImportTarget.createNew;

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.allowExistingTarget) ...[
            // [UPDATED] Import target
            _buildSectionHeader(context, 'import.import_target'.tr()),
            SizedBox(height: 12.h),
            _buildTargetSelector(),
            SizedBox(height: 24.h),
          ],

          if (effectiveTarget == ImportTarget.addToExisting) ...[
            _buildSectionHeader(
              context,
              'import.select_existing_portfolio'.tr(),
            ),
            SizedBox(height: 12.h),
            _buildExistingPortfolioSelector(portfolios),
            SizedBox(height: 24.h),
          ],

          if (effectiveTarget == ImportTarget.createNew) ...[
            _buildSectionHeader(context, 'import.portfolio_name'.tr()),
            SizedBox(height: 12.h),
            TextFormField(
              controller: _portfolioNameController,
              decoration: InputDecoration(
                labelText: 'import.portfolio_name_label'.tr(),
                hintText: 'import.portfolio_name_hint'.tr(),
                prefixIcon: const Icon(Icons.badge_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                filled: true,
              ),
            ),
            SizedBox(height: 24.h),
          ],

          // Step 1: Select Broker
          _buildSectionHeader(context, '1. ${'import.select_broker'.tr()}'),
          SizedBox(height: 12.h),
          _buildBrokerSelector(),
          SizedBox(height: 24.h),

          // Step 2: Upload File
          _buildSectionHeader(context, '2. ${'import.upload_file'.tr()}'),
          SizedBox(height: 12.h),
          _buildFileUploader(),
          SizedBox(height: 24.h),

          // Help section
          if (_selectedBroker != null) ...[
            _buildHelpSection(),
            SizedBox(height: 24.h),
          ],

          // Import button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _canImport(portfolios)
                  ? () => _importPortfolio(portfolios)
                  : null,
              child: _isLoading
                  ? SizedBox(
                      width: 20.w,
                      height: 20.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text('import.import_button'.tr()),
            ),
          ),
        ],
      ),
    );
  }

  // [UPDATED] Import target selection UI
  Widget _buildTargetSelector() {
    return Column(
      children: [
        RadioListTile<ImportTarget>(
          value: ImportTarget.createNew,
          groupValue: _importTarget,
          onChanged: (value) {
            if (value == null) return;
            setState(() {
              _importTarget = value;
              _selectedPortfolioId = null;
            });
          },
          title: Text('import.import_target_create'.tr()),
        ),
        RadioListTile<ImportTarget>(
          value: ImportTarget.addToExisting,
          groupValue: _importTarget,
          onChanged: (value) {
            if (value == null) return;
            setState(() => _importTarget = value);
          },
          title: Text('import.import_target_existing'.tr()),
        ),
      ],
    );
  }

  // [UPDATED] Existing portfolio dropdown
  Widget _buildExistingPortfolioSelector(List<Portfolio> portfolios) {
    if (portfolios.isEmpty) {
      return Text(
        'import.no_portfolios'.tr(),
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return DropdownButtonFormField<String>(
      value: _selectedPortfolioId,
      decoration: InputDecoration(
        hintText: 'import.select_existing_portfolio_hint'.tr(),
        prefixIcon: const Icon(Icons.folder_open),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        filled: true,
      ),
      isExpanded: true,
      items: portfolios.map((portfolio) {
        final displayName = portfolio.accountName.isNotEmpty
            ? portfolio.accountName
            : portfolio.accountId;
        return DropdownMenuItem<String>(
          value: portfolio.id,
          child: Text(displayName),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedPortfolioId = value),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
    );
  }

  Widget _buildBrokerSelector() {
    return DropdownButtonFormField<String>(
      value: _selectedBroker,
      decoration: InputDecoration(
        hintText: 'import.choose_broker'.tr(),
        prefixIcon: const Icon(Icons.account_balance),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        filled: true,
      ),
      isExpanded: true,
      itemHeight: null,
      selectedItemBuilder: (context) {
        return _brokers.map((broker) {
          return Row(
            children: [
              Icon(broker.icon, color: broker.color, size: 20.w),
              SizedBox(width: 12.w),
              Expanded(
                child: Text(
                  '${broker.name} • ${broker.region}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          );
        }).toList();
      },
      items: _brokers.map((broker) {
        return DropdownMenuItem<String>(
          value: broker.id,
          child: Row(
            children: [
              Icon(broker.icon, color: broker.color, size: 20.w),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      broker.name,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    Text(
                      broker.region,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).textTheme.bodySmall?.color?.withValues(alpha: 0.6),
                            fontSize: 11.sp,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedBroker = value),
    );
  }

  Widget _buildFileUploader() {
    return InkWell(
      onTap: _pickFile,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(32.w),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border.all(
            color: _selectedFiles.isNotEmpty
                ? AppTheme.successColor
                : Theme.of(context).dividerColor,
            width: 2,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Column(
          children: [
            Icon(
              _selectedFiles.isNotEmpty ? Icons.check_circle : Icons.upload_file,
              size: 48.w,
              color: _selectedFiles.isNotEmpty
                  ? AppTheme.successColor
                  : Theme.of(context).primaryColor,
            ),
            SizedBox(height: 16.h),
            Text(
              _fileSelectionLabel(),
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (_selectedFiles.length > 1) ...[
              SizedBox(height: 8.h),
              ..._selectedFiles.map((file) => Text(
                    file.name,
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  )),
            ],
            SizedBox(height: 8.h),
            Text(
              'import.or'.tr(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            SizedBox(height: 8.h),
            OutlinedButton(
              onPressed: _pickFile,
              child: Text('import.browse_files'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHelpSection() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.help_outline,
                  size: 20.w,
                  color: Theme.of(context).primaryColor,
                ),
                SizedBox(width: 8.w),
                Text(
                  'import.help.title'.tr(),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Text(
              _getHelpText(),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  String _getHelpText() {
    switch (_selectedBroker) {
      case 'ibkr':
        return 'import.help.ibkr'.tr();
      case 'fidelity':
        return 'import.help.fidelity'.tr();
      case 'charles_schwab':
        return 'import.help.schwab'.tr();
      case 'td_ameritrade':
        return 'import.help.td_ameritrade'.tr();
      case 'etrade':
        return 'import.help.etrade'.tr();
      case 'robinhood':
        return 'import.help.robinhood'.tr();
      case 'vanguard':
        return 'import.help.vanguard'.tr();
      case 'degiro':
        return 'import.help.degiro'.tr();
      case 'trading212':
        return 'import.help.trading212'.tr();
      case 'xtb':
        return 'import.help.xtb'.tr();
      case 'revolut':
        return 'import.help.revolut'.tr();
      default:
        return 'import.help.generic'.tr();
    }
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'pdf'],
        allowMultiple: true,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final selectedFiles = <ImportFileData>[];

        for (final file in result.files) {
          final bytes = file.bytes ??
              (file.path != null ? await File(file.path!).readAsBytes() : null);
          if (bytes == null) continue;

          final extension = (file.extension ?? _extensionFromName(file.name))
              .toLowerCase();
          selectedFiles.add(ImportFileData(
            name: file.name,
            extension: extension,
            bytes: bytes,
          ));
        }

        if (selectedFiles.isNotEmpty) {
          setState(() => _selectedFiles = selectedFiles);
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('errors.file_invalid'.tr()),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  bool _canImport(List<Portfolio> portfolios) {
    if (_isLoading || _selectedBroker == null || _selectedFiles.isEmpty) {
      return false;
    }

    if (_importTarget == ImportTarget.createNew) {
      return _portfolioNameController.text.trim().isNotEmpty;
    }

    return portfolios.isNotEmpty && _selectedPortfolioId != null;
  }

  Future<void> _importPortfolio(List<Portfolio> portfolios) async {
    if (_selectedBroker == null || _selectedFiles.isEmpty) return;

    if (_importTarget == ImportTarget.createNew) {
      if (_portfolioNameController.text.trim().isEmpty) return;
      context.read<PortfolioBloc>().add(
            CreatePortfolioFromImportEvent(
              files: _selectedFiles,
              broker: _selectedBroker!,
              portfolioName: _portfolioNameController.text.trim(),
            ),
          );
      return;
    }

    if (_selectedPortfolioId == null) return;
    final targetPortfolio = portfolios.firstWhere(
      (portfolio) => portfolio.id == _selectedPortfolioId,
      orElse: () => Portfolio.empty(),
    );

    if (targetPortfolio.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('errors.storage_error'.tr()),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    PositionMergeStrategy mergeStrategy = PositionMergeStrategy.add;

    try {
      final incomingPositions = await _parseIncomingPositions();
      final normalizedExisting = BaseBrokerParser.normalizeAndDeduplicatePositions(
        targetPortfolio.positions,
      );
      final duplicateCount = _countDuplicatePositions(
        normalizedExisting,
        incomingPositions,
      );

      if (duplicateCount > 0) {
        final selectedStrategy = await _showMergeStrategyDialog(duplicateCount);
        if (selectedStrategy == null) return;
        mergeStrategy = selectedStrategy;
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('import.error'.tr()),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    context.read<PortfolioBloc>().add(
          AddPositionsFromImportEvent(
            files: _selectedFiles,
            broker: _selectedBroker!,
            portfolioId: targetPortfolio.id,
            mergeStrategy: mergeStrategy,
          ),
        );
  }

  String _fileSelectionLabel() {
    if (_selectedFiles.isEmpty) {
      return 'import.drag_drop'.tr();
    }

    if (_selectedFiles.length == 1) {
      return _selectedFiles.first.name;
    }

    return 'import.files_selected'.tr(
      namedArgs: {'count': _selectedFiles.length.toString()},
    );
  }

  String _extensionFromName(String name) {
    final parts = name.split('.');
    if (parts.length < 2) return '';
    return parts.last;
  }

  Future<List<Position>> _parseIncomingPositions() async {
    final positions = <Position>[];
    for (final file in _selectedFiles) {
      final portfolio = await _parseImportFile(file);
      positions.addAll(portfolio.positions);
    }

    return BaseBrokerParser.normalizeAndDeduplicatePositions(positions);
  }

  Future<Portfolio> _parseImportFile(ImportFileData file) async {
    final brokerId = _selectedBroker ?? '';
    if (file.extension.toLowerCase() == 'pdf') {
      return PdfImportParser.parse(file.bytes, brokerId: brokerId);
    }

    final content = utf8.decode(file.bytes, allowMalformed: true);
    try {
      return BrokerParserFactory.parseWithBroker(content, brokerId);
    } catch (_) {
      return BrokerParserFactory.autoParseCSV(content);
    }
  }

  int _countDuplicatePositions(
    List<Position> existing,
    List<Position> incoming,
  ) {
    final existingKeys = existing
        .map(_buildPositionKey)
        .where((key) => key.isNotEmpty)
        .toSet();

    var duplicates = 0;
    for (final position in incoming) {
      final key = _buildPositionKey(position);
      if (key.isNotEmpty && existingKeys.contains(key)) {
        duplicates++;
      }
    }

    return duplicates;
  }

  String _buildPositionKey(Position position) {
    final isin = position.isin?.trim().toUpperCase();
    if (isin != null && isin.isNotEmpty) {
      return 'ISIN:$isin';
    }

    final symbol = BaseBrokerParser.normalizeSymbol(position.symbol);
    if (symbol.isEmpty) {
      final name = position.name.trim().toUpperCase();
      return name.isEmpty
          ? ''
          : 'NAME:$name:${position.currency.toUpperCase()}';
    }

    return 'SYM:$symbol:${position.currency.toUpperCase()}';
  }

  Future<PositionMergeStrategy?> _showMergeStrategyDialog(int duplicateCount) {
    return showDialog<PositionMergeStrategy>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('import.merge_conflict_title'.tr()),
          content: Text(
            'import.merge_conflict_message'.tr(
              namedArgs: {'count': duplicateCount.toString()},
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context)
                  .pop(PositionMergeStrategy.ignore),
              child: Text('import.merge_ignore'.tr()),
            ),
            TextButton(
              onPressed: () => Navigator.of(context)
                  .pop(PositionMergeStrategy.replace),
              child: Text('import.merge_replace'.tr()),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context)
                  .pop(PositionMergeStrategy.add),
              child: Text('import.merge_add'.tr()),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _portfolioNameController.dispose();
    super.dispose();
  }
}

class BrokerInfo {
  final String id;
  final String name;
  final IconData icon;
  final Color color;
  final String region;

  BrokerInfo({
    required this.id,
    required this.name,
    required this.icon,
    required this.color,
    required this.region,
  });
}
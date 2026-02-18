import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_theme.dart';
import '../bloc/portfolio_bloc.dart';
import 'import_page.dart';

class CreatePortfolioPage extends StatefulWidget {
  const CreatePortfolioPage({super.key});

  @override
  State<CreatePortfolioPage> createState() => _CreatePortfolioPageState();
}

class _CreatePortfolioPageState extends State<CreatePortfolioPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<PortfolioBloc, PortfolioState>(
      listener: (context, state) {
        if (state is PortfolioLoaded && _isLoading) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('portfolio.create_success'.tr()),
              backgroundColor: AppTheme.successColor,
            ),
          );
          setState(() => _isLoading = false);
          context.pop();
        } else if (state is PortfolioError && _isLoading) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message.tr()),
              backgroundColor: AppTheme.errorColor,
            ),
          );
          setState(() => _isLoading = false);
        }
      },
      // [UPDATED] Tabbed create/import flow
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: Text('portfolio.create_portfolio'.tr()),
            bottom: TabBar(
              tabs: [
                Tab(text: 'portfolio.create_empty_tab'.tr()),
                Tab(text: 'portfolio.create_import_tab'.tr()),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _buildManualForm(),
              const ImportPage(
                embedded: true,
                allowExistingTarget: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildManualForm() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).primaryColor,
                      size: 24.w,
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        'portfolio.create_portfolio_info'.tr(),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'portfolio.portfolio_name'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            SizedBox(height: 12.h),
            TextFormField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'portfolio.portfolio_name'.tr(),
                hintText: 'portfolio.portfolio_name_hint'.tr(),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                ),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'portfolio.portfolio_name_required'.tr();
                }
                return null;
              },
            ),
            SizedBox(height: 24.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: _isLoading
                    ? SizedBox(
                        width: 20.w,
                        height: 20.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text('portfolio.create_portfolio'.tr()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    context.read<PortfolioBloc>().add(
          CreatePortfolioEvent(_nameController.text.trim()),
        );
  }
}

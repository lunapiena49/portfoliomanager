import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../portfolio/presentation/bloc/portfolio_bloc.dart';
import '../../../settings/presentation/bloc/settings_bloc.dart';
import '../bloc/ai_chat_bloc.dart';

class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final chatBloc = context.read<AIChatBloc>();
      chatBloc.add(InitializeChatEvent('analysis.ask_ai'.tr()));
      _syncApiKey();
    });
  }

  void _syncApiKey() {
    final settingsState = context.read<SettingsBloc>().state;
    if (settingsState is SettingsLoaded) {
      context
          .read<AIChatBloc>()
          .add(UpdateChatApiKeyEvent(settingsState.settings.geminiApiKey));
    }
  }

  void _sendMessage() {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    final portfolioState = context.read<PortfolioBloc>().state;
    final settingsState = context.read<SettingsBloc>().state;

    if (portfolioState is! PortfolioLoaded) {
      _showError('analysis.no_portfolio_loaded'.tr());
      return;
    }

    if (settingsState is! SettingsLoaded) {
      _showError('analysis.api_key_required'.tr());
      return;
    }

    context
        .read<AIChatBloc>()
        .add(UpdateChatApiKeyEvent(settingsState.settings.geminiApiKey));
    context.read<AIChatBloc>().add(SendChatMessageEvent(
          message: message,
          portfolio: portfolioState.portfolio,
          language: settingsState.settings.languageCode,
        ));

    _messageController.clear();
    _scrollToBottom();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppTheme.errorColor,
      ),
    );
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _resolveErrorMessage(String raw) {
    if (raw.startsWith('analysis.')) {
      return raw.tr();
    }
    return raw;
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AIChatBloc, AIChatState>(
      listenWhen: (previous, current) {
        if (current is! AIChatReady) return false;
        if (previous is! AIChatReady) return current.errorMessage != null;
        return previous.errorMessage != current.errorMessage &&
            current.errorMessage != null;
      },
      listener: (context, state) {
        if (state is AIChatReady && state.errorMessage != null) {
          _showError(_resolveErrorMessage(state.errorMessage!));
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('analysis.chat_title'.tr()),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                context
                    .read<AIChatBloc>()
                    .add(ClearChatEvent('analysis.ask_ai'.tr()));
              },
            ),
            IconButton(
              icon: const Icon(Icons.help_outline),
              tooltip: 'common.help'.tr(),
              onPressed: () => context.push(RouteNames.guide),
            ),
          ],
        ),
        body: BlocConsumer<AIChatBloc, AIChatState>(
          listenWhen: (previous, current) =>
              current is AIChatReady &&
              previous is AIChatReady &&
              previous.messages.length != current.messages.length,
          listener: (context, state) => _scrollToBottom(),
          builder: (context, state) {
            final messages =
                state is AIChatReady ? state.messages : const <ChatMessage>[];
            final isLoading = state is AIChatReady && state.isSending;
            return Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.all(16.w),
                    itemCount: messages.length + (isLoading ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == messages.length && isLoading) {
                        return _buildLoadingIndicator();
                      }
                      return _buildMessageBubble(messages[index]);
                    },
                  ),
                ),
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    boxShadow: [
                      BoxShadow(
                        color:
                            Theme.of(context).shadowColor.withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            decoration: InputDecoration(
                              hintText: 'analysis.ask_ai'.tr(),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(24.r),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 16.w,
                                vertical: 12.h,
                              ),
                            ),
                            maxLines: null,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _sendMessage(),
                          ),
                        ),
                        SizedBox(width: 12.w),
                        CircleAvatar(
                          radius: 24.r,
                          backgroundColor: Theme.of(context).primaryColor,
                          child: IconButton(
                            icon: Icon(Icons.send,
                                color:
                                    Theme.of(context).colorScheme.onPrimary),
                            onPressed: isLoading ? null : _sendMessage,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage message) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              radius: 16.r,
              backgroundColor: Theme.of(context).primaryColor,
              child: Icon(Icons.auto_awesome,
                  size: 16.w, color: Theme.of(context).colorScheme.onPrimary),
            ),
            SizedBox(width: 8.w),
          ],
          Flexible(
            child: Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: message.isUser
                    ? Theme.of(context).primaryColor
                    : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(16.r).copyWith(
                  bottomRight:
                      message.isUser ? Radius.zero : Radius.circular(16.r),
                  bottomLeft:
                      message.isUser ? Radius.circular(16.r) : Radius.zero,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SelectableText(
                message.content,
                style: TextStyle(
                  color: message.isUser
                      ? Theme.of(context).colorScheme.onPrimary
                      : null,
                ),
              ),
            ),
          ),
          if (message.isUser) ...[
            SizedBox(width: 8.w),
            CircleAvatar(
              radius: 16.r,
              backgroundColor: AppTheme.accentColor,
              child: Icon(Icons.person, size: 16.w, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16.r,
            backgroundColor: Theme.of(context).primaryColor,
            child: Icon(Icons.auto_awesome,
                size: 16.w, color: Theme.of(context).colorScheme.onPrimary),
          ),
          SizedBox(width: 8.w),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16.r).copyWith(
                bottomLeft: Radius.zero,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 16.w,
                  height: 16.w,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
                SizedBox(width: 12.w),
                Text(
                  'analysis.thinking'.tr(),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

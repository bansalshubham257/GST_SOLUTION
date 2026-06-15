// lib/features/chat_flow/presentation/pages/chat_flow_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../providers/chat_flow_provider.dart';

class ChatFlowPage extends ConsumerWidget {
  const ChatFlowPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatState = ref.watch(chatFlowProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primarySurface,
              child: Icon(Icons.smart_toy_outlined, color: AppColors.primary, size: 14),
            ),
            SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Assistant', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                Text('Chat Flow', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            tooltip: 'Start over',
            onPressed: () {
              ref.read(chatFlowProvider.notifier).reset();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Chat(
              messages: chatState.messages,
              onSendPressed: (p) =>
                  ref.read(chatFlowProvider.notifier).handleInput(p.text),
              user: const types.User(id: 'chatflow-user', firstName: 'You'),
              showUserAvatars: true,
              showUserNames: false,
              theme: DefaultChatTheme(
                primaryColor: AppColors.primary,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                inputBackgroundColor: Colors.white,
                inputTextColor: const Color(0xFF1A1A2E),
                inputTextCursorColor: AppColors.primary,
                inputTextDecoration: const InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Color(0xFF94A3B8)),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.all(Radius.circular(24)),
                    borderSide: BorderSide(color: Color(0xFFCBD5E1)),
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                inputBorderRadius: BorderRadius.circular(24),
                messageBorderRadius: 12,
                receivedMessageBodyTextStyle:
                    const TextStyle(color: Colors.black87, fontSize: 14),
                sentMessageBodyTextStyle:
                    const TextStyle(color: Colors.white, fontSize: 14),
              ),
              typingIndicatorOptions: TypingIndicatorOptions(
                typingUsers:
                    chatState.isBotTyping
                        ? [const types.User(id: 'chatflow-bot', firstName: '')]
                        : [],
              ),
            ),
          ),
          if (chatState.quickReplyOptions.isNotEmpty)
            _buildQuickReplies(chatState, ref),
        ],
      ),
    );
  }

  Widget _buildQuickReplies(ChatFlowState state, WidgetRef ref) {
    final options = state.quickReplyOptions;
    if (options.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 48,
      color: AppColors.surfaceVariantLight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () =>
              ref.read(chatFlowProvider.notifier).handleInput(options[i]),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Text(
              options[i],
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

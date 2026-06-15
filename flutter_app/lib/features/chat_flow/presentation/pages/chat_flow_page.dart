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
    final items = chatState.activeEntity != null &&
            (chatState.activeEntity == FlowEntity.sale ||
                chatState.activeEntity == FlowEntity.purchase)
        ? (chatState.draft['items'] as List<Map<String, dynamic>>? ?? [])
        : <Map<String, dynamic>>[];

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
          if (items.isNotEmpty) _buildCart(items, ref, context),
          if (chatState.quickReplyOptions.isNotEmpty)
            _buildQuickReplies(chatState, ref),
        ],
      ),
    );
  }

  Widget _buildCart(List<Map<String, dynamic>> items, WidgetRef ref, BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 160),
      color: Colors.white,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: AppColors.primarySurface,
            child: Row(
              children: [
                const Icon(Icons.shopping_cart, size: 16, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  '${items.length} item${items.length != 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primary),
                ),
              ],
            ),
          ),
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              itemCount: items.length,
              itemBuilder: (_, i) {
                final item = items[i];
                return _CartItemTile(
                  index: i,
                  item: item,
                  onEdit: () => _showEditSheet(context, ref, i, item),
                  onDelete: () => ref.read(chatFlowProvider.notifier).removeItem(i),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context, WidgetRef ref, int index, Map<String, dynamic> item) {
    final qtyCtrl = TextEditingController(text: (item['qty'] as num).toString());
    final priceCtrl = TextEditingController(text: (item['price'] as num).toStringAsFixed(2));
    final gstCtrl = TextEditingController(text: (item['gstRate'] as num).toStringAsFixed(0));
    final notifier = ref.read(chatFlowProvider.notifier);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 20, right: 20, top: 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(
                color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2),
              )),
            ),
            const SizedBox(height: 12),
            Text('Edit ${item['name']}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextField(
              controller: qtyCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Quantity', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Unit Price', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: gstCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'GST Rate (%)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () {
                  notifier.updateItem(
                    index,
                    qty: double.tryParse(qtyCtrl.text),
                    price: double.tryParse(priceCtrl.text),
                    gstRate: double.tryParse(gstCtrl.text),
                  );
                  Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
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

// ─── Cart Item Tile ──────────────────────────────────────────────────────────

class _CartItemTile extends StatelessWidget {
  final int index;
  final Map<String, dynamic> item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CartItemTile({
    required this.index,
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final qty = (item['qty'] as num?)?.toDouble() ?? 0;
    final price = (item['price'] as num?)?.toDouble() ?? 0;
    final gst = (item['gstRate'] as num?)?.toDouble() ?? 0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          leading: CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primarySurface,
            child: Text('${index + 1}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
          ),
          title: Text(item['name'] ?? '',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
          subtitle: Text(
            'Qty: $qty × ₹$price | GST: ${gst.toStringAsFixed(0)}%',
            style: const TextStyle(fontSize: 11),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit, size: 18),
                color: AppColors.primary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: onEdit,
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                color: Colors.red.shade400,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

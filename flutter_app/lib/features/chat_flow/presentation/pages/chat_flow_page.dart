// lib/features/chat_flow/presentation/pages/chat_flow_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/storage/local_storage.dart';
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
          if (chatState.step != ChatFlowStep.mainMenu ||
              chatState.quickReplyOptions.isNotEmpty)
            _buildQuickReplies(chatState, ref, context),
          Expanded(
            child: Chat(
              messages: chatState.messages,
              onSendPressed: (p) =>
                  _onTextSend(p.text, ref, context),
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
        ],
      ),
    );
  }

  void _onTextSend(String text, WidgetRef ref, BuildContext context) {
    final state = ref.read(chatFlowProvider);
    if (state.step == ChatFlowStep.saleStaffSelect &&
        (text.contains('Select') || text.contains('👤'))) {
      _showStaffPicker(context, ref);
    } else {
      ref.read(chatFlowProvider.notifier).handleInput(text);
    }
  }

  void _onChipTap(String text, WidgetRef ref, BuildContext context) {
    final state = ref.read(chatFlowProvider);
    if (state.step == ChatFlowStep.saleStaffSelect &&
        (text.contains('Select') || text.contains('👤'))) {
      _showStaffPicker(context, ref);
    } else {
      ref.read(chatFlowProvider.notifier).handleInput(text);
    }
  }

  void _showStaffPicker(BuildContext context, WidgetRef ref) {
    final staff = LocalStorage.staffBox.values.toList();
    final notifier = ref.read(chatFlowProvider.notifier);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _StaffPickerSheet(
        staff: staff,
        onSelect: (name) {
          notifier.handleInput(name);
          Navigator.pop(ctx);
        },
        onSkip: () {
          notifier.handleInput('skip');
          Navigator.pop(ctx);
        },
      ),
    );
  }

  Widget _buildQuickReplies(ChatFlowState state, WidgetRef ref, BuildContext context) {
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
          onTap: () => _onChipTap(options[i], ref, context),
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

// ─── Staff Picker Bottom Sheet ───────────────────────────────────────────────

class _StaffPickerSheet extends StatefulWidget {
  final List<Map<dynamic, dynamic>> staff;
  final ValueChanged<String> onSelect;
  final VoidCallback onSkip;

  const _StaffPickerSheet({
    required this.staff,
    required this.onSelect,
    required this.onSkip,
  });

  @override
  State<_StaffPickerSheet> createState() => _StaffPickerSheetState();
}

class _StaffPickerSheetState extends State<_StaffPickerSheet> {
  final _searchCtrl = TextEditingController();
  List<Map<dynamic, dynamic>> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = widget.staff;
    _searchCtrl.addListener(_filter);
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? widget.staff
          : widget.staff.where((s) {
              final name = (s['name'] ?? '').toString().toLowerCase();
              final phone = (s['phone'] ?? '').toString();
              return name.contains(q) || phone.contains(q);
            }).toList();
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.55,
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.symmetric(vertical: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.group, size: 20, color: AppColors.primary),
                  const SizedBox(width: 8),
                  const Text(
                    'Select Staff Member',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: widget.onSkip,
                    icon: const Icon(Icons.skip_next, size: 18),
                    label: const Text('Skip'),
                  ),
                ],
              ),
            ),
            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search by name or phone...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () => _searchCtrl.clear(),
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.shade300),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
              ),
            ),
            const Divider(height: 1),
            // Staff list
            Expanded(
              child: _filtered.isEmpty
                  ? const Center(
                      child: Text('No staff members found',
                          style: TextStyle(color: Colors.grey)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      itemCount: _filtered.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
                      itemBuilder: (_, i) {
                        final s = _filtered[i];
                        return ListTile(
                          leading: CircleAvatar(
                            radius: 18,
                            backgroundColor: AppColors.primarySurface,
                            child: Text(
                              (s['name'] ?? '?').toString()[0].toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          title: Text(
                            '${s['name']}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Text(
                            s['role'] != null ? '${s['role']}' : '',
                            style: const TextStyle(fontSize: 12),
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 20, color: Colors.grey),
                          onTap: () => widget.onSelect('${s['name']}'),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

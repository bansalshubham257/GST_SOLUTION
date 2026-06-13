// lib/features/chat_support/presentation/pages/chat_support_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_widgets.dart';

const _user = types.User(id: 'user-1', firstName: 'Me');
const _supportBot = types.User(
  id: 'bot-1',
  firstName: 'GST',
  lastName: 'Assistant',
  imageUrl: null,
);
const _humanAgent = types.User(
  id: 'agent-1',
  firstName: 'Support',
  lastName: 'Team',
);

class ChatSupportPage extends ConsumerStatefulWidget {
  const ChatSupportPage({super.key});

  @override
  ConsumerState<ChatSupportPage> createState() => _ChatSupportPageState();
}

class _ChatSupportPageState extends ConsumerState<ChatSupportPage> {
  final List<types.Message> _messages = [];
  bool _isAiResponding = false;
  bool _isEscalated = false;
  final _uuid = const Uuid();

  @override
  void initState() {
    super.initState();
    _addWelcomeMessage();
  }

  void _addWelcomeMessage() {
    final welcomeMessage = types.TextMessage(
      author: _supportBot,
      id: _uuid.v4(),
      text: '''👋 Hello! I'm your GST Assistant.

I can help you with:
• Creating and managing invoices
• GST calculation queries
• GSTIN validation
• GSTR-1 and GSTR-3B queries
• Filing assistance

Type your question or choose from quick options below!''',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    setState(() => _messages.insert(0, welcomeMessage));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isEscalated
            ? const Row(children: [
                CircleAvatar(radius: 16, backgroundColor: AppColors.successLight, child: Icon(Icons.person, color: AppColors.success, size: 14)),
                SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Support Agent', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    Text('Online', style: TextStyle(fontSize: 11, color: AppColors.success)),
                  ],
                ),
              ])
            : const Row(children: [
                CircleAvatar(radius: 16, backgroundColor: AppColors.primarySurface, child: Icon(Icons.smart_toy_outlined, color: AppColors.primary, size: 14)),
                SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GST Assistant', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    Text('AI Powered', style: TextStyle(fontSize: 11, color: AppColors.textSecondaryLight)),
                  ],
                ),
              ]),
        actions: [
          if (!_isEscalated)
            TextButton.icon(
              icon: const Icon(Icons.support_agent, size: 18),
              label: const Text('Human'),
              onPressed: _escalateToHuman,
            ),
        ],
      ),
      body: Column(
        children: [
          if (!_isEscalated) _buildQuickReplies(),
          Expanded(
            child: Chat(
              messages: _messages,
              onSendPressed: _handleSendPressed,
              user: _user,
              showUserAvatars: true,
              showUserNames: true,
              theme: DefaultChatTheme(
                primaryColor: AppColors.primary,
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                inputBackgroundColor: Colors.white,
                inputBorderRadius: BorderRadius.circular(24),
                messageBorderRadius: 12,
                receivedMessageBodyTextStyle: const TextStyle(color: Colors.black87, fontSize: 14),
                sentMessageBodyTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
              ),
              typingIndicatorOptions: TypingIndicatorOptions(
                typingUsers: _isAiResponding ? [_supportBot] : [],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickReplies() {
    final quickReplies = [
      'How to create invoice?',
      'GST calculation help',
      'GSTIN validation',
      'How to file GSTR-1?',
      'Download invoice PDF',
    ];

    return Container(
      height: 44,
      color: AppColors.surfaceVariantLight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: quickReplies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () => _sendQuickReply(quickReplies[i]),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Text(
              quickReplies[i],
              style: const TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w500),
            ),
          ),
        ),
      ),
    );
  }

  void _handleSendPressed(types.PartialText message) {
    final textMessage = types.TextMessage(
      author: _user,
      id: _uuid.v4(),
      text: message.text,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    setState(() => _messages.insert(0, textMessage));
    _getAiResponse(message.text);
  }

  void _sendQuickReply(String text) {
    _handleSendPressed(types.PartialText(text: text));
  }

  Future<void> _getAiResponse(String userMessage) async {
    if (_isEscalated) return; // Human agent takes over

    setState(() => _isAiResponding = true);
    await Future.delayed(const Duration(milliseconds: 1200));

    final response = _generateResponse(userMessage.toLowerCase());

    final botMessage = types.TextMessage(
      author: _supportBot,
      id: _uuid.v4(),
      text: response,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );

    setState(() {
      _messages.insert(0, botMessage);
      _isAiResponding = false;
    });
  }

  String _generateResponse(String input) {
    if (input.contains('invoice') && input.contains('creat')) {
      return 'To create an invoice:\n\n1. Tap the ✚ **New Invoice** button at the bottom\n2. Search or enter customer details\n3. Add items/services with HSN/SAC code\n4. GST is auto-calculated based on rates\n5. Review the total and tap **Create Invoice**\n6. Download PDF and share!\n\nNeed more help?';
    }
    if (input.contains('gst') && (input.contains('calculat') || input.contains('rate'))) {
      return 'GST calculation in the app:\n\n• **Intra-state**: CGST (50%) + SGST (50%)\n• **Inter-state**: IGST (100%)\n\nRates available: **0%, 5%, 12%, 18%, 28%**\n\nThe app auto-detects intra/inter-state by comparing your GSTIN with customer\'s GSTIN.\n\nAll calculations are automatic! 🎉';
    }
    if (input.contains('gstin') && input.contains('valid')) {
      return 'To validate a GSTIN:\n\n1. Go to **Create Invoice** or **Add Customer**\n2. Enter the GSTIN in the field\n3. Tap the ✓ verify button\n\nGSTIN format: **2 digits (state) + 10 chars (PAN) + 1 digit + Z + check digit**\n\nExample: 27AABCU9603R1ZX';
    }
    if (input.contains('gstr-1') || input.contains('gstr1') || input.contains('filing')) {
      return 'To prepare GSTR-1:\n\n1. Go to **GST tab** → GSTR-1\n2. Select the filing month\n3. Review B2B and B2C invoices\n4. Tap **Export JSON**\n5. Upload the JSON file at **gstn.gov.in**\n\n⚠️ Always verify before submitting to the GST portal.';
    }
    if (input.contains('pdf') || input.contains('download')) {
      return 'To download invoice PDF:\n\n1. Open any invoice from the **Invoices** tab\n2. Tap the **Download PDF** button at the bottom\n3. PDF is saved to your device\n4. You can also share it directly via WhatsApp, email, etc.!';
    }
    if (input.contains('hello') || input.contains('hi') || input.contains('hey')) {
      return 'Hello! 👋 How can I help you today?\n\nYou can ask me about:\n• Creating invoices\n• GST calculations\n• GSTIN validation\n• Filing GSTR-1/3B\n• Downloading PDFs';
    }
    return 'I understand your query. Let me help...\n\nFor this specific question, I recommend connecting with our support team who can provide detailed assistance.\n\nTap **Human** button above to chat with a support agent, or you can also email us at support@gstsolution.in';
  }

  void _escalateToHuman() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Connect to Support'),
        content: const Text('A human support agent will join the chat. Expected wait time: 2-5 minutes.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() => _isEscalated = true);
              _addEscalationMessage();
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  void _addEscalationMessage() {
    final systemMessage = types.SystemMessage(
      id: _uuid.v4(),
      text: 'You are now connected to a human support agent. Average response time is 2-5 minutes during business hours (9 AM - 6 PM IST).',
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    setState(() => _messages.insert(0, systemMessage));
  }
}


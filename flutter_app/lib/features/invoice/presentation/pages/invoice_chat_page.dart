// lib/features/invoice/presentation/pages/invoice_chat_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:flutter_chat_types/flutter_chat_types.dart' as types;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/services/voice_input_service.dart';
import '../../../../core/services/tts_service.dart';
import '../../../../core/widgets/voice_mic_button.dart';
import '../../../../core/widgets/language_toggle_button.dart'; // LanguageToggleButton + VoiceLanguageRow
import '../../../../core/providers/language_provider.dart';
import '../../../../core/utils/chat_strings.dart';
import '../providers/invoice_chat_provider.dart';
import '../../../customer/presentation/providers/customer_provider.dart';

class InvoiceChatPage extends ConsumerStatefulWidget {
  const InvoiceChatPage({super.key});

  @override
  ConsumerState<InvoiceChatPage> createState() => _InvoiceChatPageState();
}

class _InvoiceChatPageState extends ConsumerState<InvoiceChatPage> {
  // ─── Voice Conversation Mode state ──────────────────────────────────────────
  bool _voiceMode = false;   // is voice-conversation loop active?
  bool _ttsSpeaking = false; // is the app currently speaking?
  bool _voiceTurnBusy = false; // guards against concurrent turns

  @override
  void dispose() {
    // Always stop TTS and mic when leaving the page
    TtsService.instance.stop();
    ref.read(voiceInputProvider.notifier).reset();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final chatState = ref.watch(invoiceChatProvider);

    // NOTE: language sync is handled inside InvoiceChatNotifier via ref.listen
    // on appLanguageProvider — no need to bridge it from the widget here.

    ref.listen(invoiceChatProvider, (prev, next) {
      // Invoice just created
      if (prev != null && !prev.isInvoiceCreated && next.isInvoiceCreated) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _showInvoiceCreatedSheet();
        });
        // Stop voice mode gracefully
        if (_voiceMode) _stopVoiceMode();
        return;
      }

      // Voice conversation mode: bot just finished typing → start next turn
      if (_voiceMode &&
          prev != null &&
          prev.isBotTyping &&
          !next.isBotTyping &&
          !next.isInvoiceCreated &&
          next.step != ChatStep.done) {
        _doVoiceTurn(next);
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: _buildAppBar(chatState),
      body: Column(
        children: [
          _buildProgressBar(chatState),
          Expanded(
            child: Chat(
              key: ValueKey(chatState.sessionId),
              messages: chatState.messages,
              onSendPressed: (partial) =>
                  ref.read(invoiceChatProvider.notifier).handleUserMessage(partial.text),
              user: chatUser,
              showUserAvatars: true,
              showUserNames: true,
              typingIndicatorOptions: TypingIndicatorOptions(
                typingUsers: chatState.isBotTyping ? [chatBot] : [],
              ),
              theme: DefaultChatTheme(
                primaryColor: AppColors.primary,
                backgroundColor: const Color(0xFFF0F4FF),
                inputBackgroundColor: Colors.white,
                inputBorderRadius: BorderRadius.circular(28),
                messageBorderRadius: 16,
                inputTextColor: AppColors.textPrimaryLight,
                receivedMessageBodyTextStyle: const TextStyle(
                    color: Color(0xFF1E293B), fontSize: 14, height: 1.5),
                sentMessageBodyTextStyle:
                    const TextStyle(color: Colors.white, fontSize: 14, height: 1.5),
                inputTextStyle: const TextStyle(fontSize: 14),
                inputPadding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
                sendButtonIcon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                seenIcon: const SizedBox.shrink(),
                deliveredIcon: const SizedBox.shrink(),
                sendingIcon: const SizedBox.shrink(),
              ),
              emptyState: const Center(
                child: Text('Chat with the AI to create your invoice',
                    style: TextStyle(color: AppColors.textSecondaryLight)),
              ),
              customBottomWidget: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Voice Conversation Mode banner ──────────────────────────
                  if (_voiceMode)
                    _buildVoiceConvBanner(chatState)
                  else ...[
                    // Language row — always visible above the input
                    if (!chatState.isInvoiceCreated)
                      const Padding(
                        padding: EdgeInsets.fromLTRB(12, 6, 12, 0),
                        child: VoiceLanguageRow(),
                      ),
                    if (chatState.step == ChatStep.askCustomerName &&
                        !chatState.isInvoiceCreated)
                      _buildSelectCustomerBar(chatState),
                  ],
                  // Dynamic quick replies from provider state
                  if (chatState.dynamicQuickReplies.isNotEmpty &&
                      !chatState.isInvoiceCreated &&
                      !_voiceMode)
                    _buildQuickReplies(chatState.dynamicQuickReplies),
                  // Bottom bar
                  if (chatState.isInvoiceCreated && chatState.step == ChatStep.done)
                    _buildDoneBar(chatState)
                  else
                    _buildChatInput(chatState),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── App Bar ─────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar(InvoiceChatState chatState) {
    final isHindi = chatState.lang == AppLanguage.hindi;
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
        onPressed: () => context.pop(),
      ),
      title: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                  colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isHindi ? 'इनवॉइस सहायक' : 'Invoice Assistant',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A))),
              Text(
                chatState.isBotTyping
                    ? (isHindi ? 'टाइप हो रहा है...' : 'typing...')
                    : (isHindi ? 'AI द्वारा' : 'AI Powered'),
                style: TextStyle(
                  fontSize: 11,
                  color: chatState.isBotTyping
                      ? AppColors.primary
                      : AppColors.textSecondaryLight,
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        // Voice Conversation Mode toggle
        if (!chatState.isInvoiceCreated)
          Tooltip(
            message: isHindi
                ? (_voiceMode ? 'वॉइस मोड बंद करें' : 'वॉइस बातचीत शुरू करें')
                : (_voiceMode ? 'Stop Voice Chat' : 'Start Voice Chat'),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
              child: GestureDetector(
                onTap: () =>
                    _voiceMode ? _stopVoiceMode() : _startVoiceMode(chatState),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _voiceMode
                        ? const Color(0xFFFF3B30).withOpacity(0.12)
                        : const Color(0xFF7C3AED).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _voiceMode
                          ? const Color(0xFFFF3B30).withOpacity(0.5)
                          : const Color(0xFF7C3AED).withOpacity(0.4),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _voiceMode
                            ? Icons.stop_circle_outlined
                            : Icons.record_voice_over_rounded,
                        size: 16,
                        color: _voiceMode
                            ? const Color(0xFFFF3B30)
                            : const Color(0xFF7C3AED),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        _voiceMode
                            ? (isHindi ? 'बंद' : 'Stop')
                            : (isHindi ? 'वॉइस' : 'Voice'),
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: _voiceMode
                              ? const Color(0xFFFF3B30)
                              : const Color(0xFF7C3AED),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(width: 2),
        // Language toggle — tapping here changes lang globally (all voice features)
        const LanguageToggleButton(),
        const SizedBox(width: 4),
        if (chatState.isInvoiceCreated && chatState.step == ChatStep.done)
          IconButton(
            icon: const Icon(Icons.add_comment_rounded, size: 22,
                color: Color(0xFF7C3AED)),
            tooltip: isHindi ? 'नया इनवॉइस' : 'New Chat',
            onPressed: () =>
                ref.read(invoiceChatProvider.notifier).resetChat(),
          )
        else if (!chatState.isInvoiceCreated)
          IconButton(
            icon: const Icon(Icons.refresh_rounded, size: 22,
                color: AppColors.textSecondaryLight),
            tooltip: isHindi ? 'फिर से शुरू' : 'Start Over',
            onPressed: _confirmRestart,
          ),
        const SizedBox(width: 4),
      ],
    );
  }

  // ─── Progress Bar ────────────────────────────────────────────────────────────

  Widget _buildProgressBar(InvoiceChatState chatState) {
    const steps = [
      ChatStep.askCustomerName, ChatStep.askCustomerPhone, ChatStep.askCustomerGstin,
      ChatStep.askItemName, ChatStep.askItemQuantity, ChatStep.askItemPrice,
      ChatStep.askItemGst, ChatStep.askMoreItems, ChatStep.showSummary,
      ChatStep.askSaveCustomer, ChatStep.done,
    ];
    final idx = steps.indexOf(chatState.step);
    final progress = idx < 0 ? 0.05 : (idx + 1) / steps.length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_stepLabel(chatState.step, chatState),
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: AppColors.primary)),
              Text('${(progress * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondaryLight)),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: AppColors.borderLight,
              valueColor: AlwaysStoppedAnimation<Color>(
                  chatState.isInvoiceCreated ? AppColors.success : AppColors.primary),
              minHeight: 4,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Voice Conversation Mode ─────────────────────────────────────────────────

  /// Activate voice conversation loop. Immediately speaks the current question.
  void _startVoiceMode(InvoiceChatState chatState) {
    if (_voiceMode) return;
    setState(() {
      _voiceMode = true;
      _voiceTurnBusy = false;
    });
    _doVoiceTurn(chatState);
  }

  /// Deactivate voice conversation loop — stop TTS and mic immediately.
  void _stopVoiceMode() {
    setState(() {
      _voiceMode = false;
      _voiceTurnBusy = false;
      _ttsSpeaking = false;
    });
    TtsService.instance.stop();
    ref.read(voiceInputProvider.notifier).reset();
  }

  /// One complete voice turn: speak latest bot message → listen → send reply.
  Future<void> _doVoiceTurn(InvoiceChatState chatState) async {
    if (!_voiceMode || !mounted || _voiceTurnBusy) return;
    if (chatState.step == ChatStep.done || chatState.isInvoiceCreated) {
      _stopVoiceMode();
      return;
    }

    setState(() => _voiceTurnBusy = true);

    try {
      // ── 1. Find the latest bot message ─────────────────────────────────────
      final botMsg = chatState.messages
          .whereType<types.TextMessage>()
          .where((m) => m.author.id != chatUser.id)
          .firstOrNull;

      if (botMsg == null) {
        setState(() => _voiceTurnBusy = false);
        return;
      }

      // ── 2. Speak the message ────────────────────────────────────────────────
      if (mounted && _voiceMode) {
        setState(() => _ttsSpeaking = true);
        await TtsService.instance.speak(
          botMsg.text,
          locale: chatState.lang.locale,
        );
        if (mounted) setState(() => _ttsSpeaking = false);
      }

      if (!mounted || !_voiceMode) {
        setState(() => _voiceTurnBusy = false);
        return;
      }

      // Small breathing gap between speak and listen
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted || !_voiceMode) {
        setState(() => _voiceTurnBusy = false);
        return;
      }

      // ── 3. Listen for user reply ────────────────────────────────────────────
      setState(() => _voiceTurnBusy = false); // allow next turn after reply
      _listenForReply(chatState.lang);
    } catch (e) {
      debugPrint('_doVoiceTurn error: $e');
      if (mounted) setState(() {
        _voiceTurnBusy = false;
        _ttsSpeaking = false;
      });
    }
  }

  void _listenForReply(AppLanguage lang) {
    if (!_voiceMode || !mounted) return;
    ref.read(voiceInputProvider.notifier).startListening(
      localeId: lang.locale,
      prompt: ChatStrings(lang).voicePromptChat(),
      onFinal: (text) {
        if (!mounted || !_voiceMode) return;
        if (text.trim().isNotEmpty) {
          // Send the spoken reply — the bot will process it and the
          // ref.listen in build() will trigger the next _doVoiceTurn.
          ref
              .read(invoiceChatProvider.notifier)
              .handleUserMessage(text.trim());
        } else {
          // Nothing heard — retry listening
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && _voiceMode) _listenForReply(lang);
          });
        }
      },
    );
  }

  // ─── Voice Conversation Banner ───────────────────────────────────────────────

  Widget _buildVoiceConvBanner(InvoiceChatState chatState) {
    final isHindi = chatState.lang == AppLanguage.hindi;
    final voiceState = ref.watch(voiceInputProvider);
    final isListening = voiceState.isListening;

    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (_ttsSpeaking) {
      statusText = isHindi ? '🔊 बोल रहा हूँ...' : '🔊 Speaking...';
      statusColor = const Color(0xFF7C3AED);
      statusIcon = Icons.volume_up_rounded;
    } else if (isListening) {
      statusText = isHindi ? '🎙 सुन रहा हूँ...' : '🎙 Listening...';
      statusColor = Colors.red.shade600;
      statusIcon = Icons.mic_rounded;
    } else {
      statusText = isHindi ? '⏳ समझ रहा हूँ...' : '⏳ Processing...';
      statusColor = AppColors.primary;
      statusIcon = Icons.hourglass_top_rounded;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 6, 12, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            statusColor.withOpacity(0.08),
            statusColor.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Animated indicator dot
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.6, end: 1.0),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeInOut,
            builder: (_, v, child) => Transform.scale(scale: v, child: child),
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: statusColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              statusText,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: statusColor,
              ),
            ),
          ),
          // Stop voice mode button
          GestureDetector(
            onTap: _stopVoiceMode,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Text(
                isHindi ? 'बंद' : 'Stop',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.red,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Select Customer Bar ─────────────────────────────────────────────────────

  Widget _buildSelectCustomerBar(InvoiceChatState chatState) {
    final isHindi = chatState.lang == AppLanguage.hindi;
    final customers = ref.watch(customerListProvider).valueOrNull ?? [];
    if (customers.isEmpty) return const SizedBox.shrink();

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: GestureDetector(
        onTap: () => _showCustomerPicker(chatState),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFEEF2FF), Color(0xFFF0FDF4)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withOpacity(0.25)),
          ),
          child: Row(
            children: [
              Container(
                width: 32, height: 32,
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.people_alt_rounded,
                    color: AppColors.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isHindi ? '👤 सेव किए ग्राहक से चुनें' : '👤 Select from Saved Customers',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      isHindi
                          ? '${customers.length} ग्राहक उपलब्ध'
                          : '${customers.length} customer${customers.length == 1 ? '' : 's'} available',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondaryLight),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded,
                  size: 14, color: AppColors.primary),
            ],
          ),
        ),
      ),
    );
  }

  void _showCustomerPicker(InvoiceChatState chatState) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomerPickerSheet(
        lang: chatState.lang,
        onSelect: (customer) {
          Navigator.pop(context);
          ref.read(invoiceChatProvider.notifier).selectCustomer(customer);
        },
      ),
    );
  }

  // ─── Quick Replies ────────────────────────────────────────────────────────────

  Widget _buildQuickReplies(List<String> replies) {
    return Container(
      height: 46,
      color: Colors.white,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: replies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => GestureDetector(
          onTap: () =>
              ref.read(invoiceChatProvider.notifier).handleQuickReply(replies[i]),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Text(replies[i],
                style: const TextStyle(
                    fontSize: 13, color: AppColors.primary,
                    fontWeight: FontWeight.w500)),
          ),
        ),
      ),
    );
  }

  // ─── Chat Input ───────────────────────────────────────────────────────────────

  Widget _buildChatInput(InvoiceChatState chatState) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: _ChatInputBox(
        hint: _inputHint(chatState),
        lang: chatState.lang,
        onSend: (text) =>
            ref.read(invoiceChatProvider.notifier).handleUserMessage(text),
      ),
    );
  }

  // ─── Done Bar (after invoice created) ────────────────────────────────────────

  Widget _buildDoneBar(InvoiceChatState chatState) {
    final invoiceId = chatState.createdInvoiceId;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () {
                if (invoiceId != null) {
                  context.push('${AppRoutes.serviceHistory}/$invoiceId');
                } else {
                  context.push(AppRoutes.serviceHistory);
                }
              },
              icon: const Icon(Icons.receipt_long_rounded, size: 18),
              label: const Text('View Invoice'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            onPressed: () =>
                ref.read(invoiceChatProvider.notifier).resetChat(),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('New Invoice'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
              side: const BorderSide(color: AppColors.primary),
              foregroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Invoice Created Sheet ────────────────────────────────────────────────────

  void _showInvoiceCreatedSheet() {
    final chatState = ref.read(invoiceChatProvider);
    final draft = chatState.draft;
    final invoiceId = chatState.createdInvoiceId;
    final fmt = NumberFormat('#,##,##0.00', 'en_IN');

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48, height: 48,
              decoration: const BoxDecoration(
                  color: AppColors.successLight, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: AppColors.success, size: 28),
            ),
            const SizedBox(height: 16),
            const Text('Invoice Created! 🎉',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('For ${draft.customerName ?? 'Customer'}',
                style: const TextStyle(color: AppColors.textSecondaryLight, fontSize: 15)),
            const SizedBox(height: 4),
            Text('₹${fmt.format(draft.grandTotal)}',
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.primary)),
            const SizedBox(height: 4),
            Text('${draft.items.length} items · GST: ₹${fmt.format(draft.totalGst)}',
                style: const TextStyle(color: AppColors.textSecondaryLight)),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      if (invoiceId != null) {
                        context.push('${AppRoutes.serviceHistory}/$invoiceId');
                      }
                    },
                    icon: const Icon(Icons.receipt_long_rounded, size: 18),
                    label: const Text('View Invoice'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      ref.read(invoiceChatProvider.notifier).resetChat();
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('New Invoice'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: AppColors.primary),
                      foregroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────────

  void _confirmRestart() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Start Over?'),
        content: const Text('This will clear the current invoice draft.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(invoiceChatProvider.notifier).resetChat();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger, foregroundColor: Colors.white),
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }

  String _stepLabel(ChatStep step, InvoiceChatState chatState) {
    final s = ChatStrings(chatState.lang);
    switch (step) {
      case ChatStep.welcome:
      case ChatStep.askCustomerName: return s.stepCustomer();
      case ChatStep.askCustomerPhone:
      case ChatStep.askCustomerGstin: return s.stepCustomerDetails();
      case ChatStep.askItemName: return s.stepItemName();
      case ChatStep.askItemQuantity: return s.stepQty();
      case ChatStep.askItemPrice: return s.stepPrice();
      case ChatStep.askItemGst: return s.stepGst();
      case ChatStep.askSaveItem: return s.stepSaveItem();
      case ChatStep.askMoreItems: return s.stepMoreItems();
      case ChatStep.showSummary: return s.stepReview();
      case ChatStep.askSaveCustomer: return s.stepSaveCustomer();
      case ChatStep.done: return s.stepDone();
    }
  }

  String _inputHint(InvoiceChatState chatState) {
    final s = ChatStrings(chatState.lang);
    switch (chatState.step) {
      case ChatStep.askCustomerName: return s.hintCustomerName();
      case ChatStep.askCustomerPhone: return s.hintPhone();
      case ChatStep.askCustomerGstin: return s.hintGstin();
      case ChatStep.askItemName: return s.hintItemName();
      case ChatStep.askItemQuantity: return s.hintQty();
      case ChatStep.askItemPrice: return s.hintPrice();
      case ChatStep.askItemGst: return s.hintGst();
      case ChatStep.askMoreItems: return s.hintMoreItems();
      case ChatStep.showSummary: return s.hintSummary();
      default: return s.hintDefault();
    }
  }
}

// ─── Custom Chat Input with Voice ────────────────────────────────────────────

class _ChatInputBox extends ConsumerStatefulWidget {
  final String hint;
  final AppLanguage lang;
  final ValueChanged<String> onSend;
  const _ChatInputBox({
    required this.hint,
    required this.lang,
    required this.onSend,
  });

  @override
  ConsumerState<_ChatInputBox> createState() => _ChatInputBoxState();
}

class _ChatInputBoxState extends ConsumerState<_ChatInputBox> {
  final _controller = TextEditingController();
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      final has = _controller.text.trim().isNotEmpty;
      if (has != _hasText) setState(() => _hasText = has);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    widget.onSend(text);
  }

  void _toggleVoice() {
    final voiceState = ref.read(voiceInputProvider);
    if (voiceState.isListening) return;
    ref.read(voiceInputProvider.notifier).startListening(
      localeId: widget.lang.locale,
      prompt: ChatStrings(widget.lang).voicePromptChat(),
      onFinal: (t) {
        if (t.isNotEmpty) {
          _controller.text = t;
          _controller.selection = TextSelection.collapsed(offset: t.length);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final voiceState = ref.watch(voiceInputProvider);
    final isHindi = widget.lang == AppLanguage.hindi;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: voiceState.isListening
                  ? Colors.red.shade300
                  : AppColors.borderLight,
              width: voiceState.isListening ? 1.5 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Mic button
              Padding(
                padding: const EdgeInsets.only(left: 8, bottom: 4),
                child: VoiceMicButton(
                  isListening: voiceState.isListening,
                  isInitializing: voiceState.isInitializing,
                  size: 36,
                  idleColor: AppColors.textSecondaryLight,
                  onTap: _toggleVoice,
                ),
              ),
              // Text field
              Expanded(
                child: TextField(
                  controller: _controller,
                  onSubmitted: (_) => _send(),
                  textInputAction: TextInputAction.send,
                  style: const TextStyle(
                      fontSize: 14, color: AppColors.textPrimaryLight),
                  decoration: InputDecoration(
                    hintText: voiceState.isListening
                        ? (isHindi ? '🎙 बोलें...' : '🎙 Listening...')
                        : widget.hint,
                    hintStyle: TextStyle(
                      color: voiceState.isListening
                          ? Colors.red.shade400
                          : AppColors.textTertiaryLight,
                      fontSize: 13,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                  maxLines: 3,
                  minLines: 1,
                ),
              ),
              // Send button
              GestureDetector(
                onTap: _send,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.only(right: 6, bottom: 5),
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: _hasText
                        ? const LinearGradient(
                            colors: [AppColors.primary, AppColors.primaryDark])
                        : null,
                    color: _hasText ? null : AppColors.borderLight,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.send_rounded,
                    color: _hasText ? Colors.white : AppColors.textTertiaryLight,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Customer Picker Sheet ────────────────────────────────────────────────────

class _CustomerPickerSheet extends ConsumerStatefulWidget {
  final AppLanguage lang;
  final ValueChanged<CustomerEntity> onSelect;

  const _CustomerPickerSheet({required this.lang, required this.onSelect});

  @override
  ConsumerState<_CustomerPickerSheet> createState() =>
      _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends ConsumerState<_CustomerPickerSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = widget.lang == AppLanguage.hindi;
    final allCustomers = ref.watch(customerListProvider).valueOrNull ?? [];

    final filtered = _query.isEmpty
        ? allCustomers
        : allCustomers.where((c) {
            final q = _query.toLowerCase();
            return c.name.toLowerCase().contains(q) ||
                (c.phone ?? '').contains(q) ||
                (c.gstin ?? '').toLowerCase().contains(q);
          }).toList();

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primarySurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.people_alt_rounded,
                      color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  isHindi ? 'ग्राहक चुनें' : 'Select Customer',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryLight,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: InputDecoration(
                hintText: isHindi
                    ? 'नाम, फोन या GSTIN खोजें...'
                    : 'Search by name, phone or GSTIN...',
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textSecondaryLight, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: AppColors.surfaceVariantLight,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // List
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.48,
            ),
            child: filtered.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        const Icon(Icons.person_search_outlined,
                            size: 48, color: AppColors.textTertiaryLight),
                        const SizedBox(height: 12),
                        Text(
                          isHindi ? 'कोई ग्राहक नहीं मिला' : 'No customers found',
                          style: const TextStyle(
                              color: AppColors.textSecondaryLight),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 52),
                    itemBuilder: (_, i) => _CustomerTile(
                      customer: filtered[i],
                      onTap: () => widget.onSelect(filtered[i]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Customer Tile ────────────────────────────────────────────────────────────

class _CustomerTile extends StatelessWidget {
  final CustomerEntity customer;
  final VoidCallback onTap;

  const _CustomerTile({required this.customer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 20,
              backgroundColor: AppColors.primarySurface,
              child: Text(
                customer.name.isNotEmpty ? customer.name[0].toUpperCase() : '?',
                style: const TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customer.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  if (customer.phone != null) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.phone_outlined,
                            size: 12, color: AppColors.textTertiaryLight),
                        const SizedBox(width: 3),
                        Text(
                          customer.phone!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondaryLight),
                        ),
                      ],
                    ),
                  ],
                  if (customer.gstin != null) ...[
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        const Icon(Icons.business_outlined,
                            size: 12, color: AppColors.textTertiaryLight),
                        const SizedBox(width: 3),
                        Text(
                          customer.gstin!,
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textTertiaryLight),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Invoice count badge
            if (customer.invoiceCount > 0)
              Container(
                margin: const EdgeInsets.only(right: 6),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${customer.invoiceCount} inv',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textTertiaryLight),
          ],
        ),
      ),
    );
  }
}

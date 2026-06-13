// lib/features/dashboard/presentation/widgets/recent_invoice_tile.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/app_widgets.dart';
import '../providers/dashboard_provider.dart';

class RecentInvoiceTile extends StatelessWidget {
  final RecentInvoiceSummary invoice;

  const RecentInvoiceTile({super.key, required this.invoice});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => context.push('${AppRoutes.serviceHistory}/${invoice.id}'),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primarySurface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.receipt_long_outlined, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        invoice.customerName,
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    AmountText(amount: invoice.amount),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      invoice.invoiceNumber,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(width: 8),
                    Text('•', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('dd MMM yy').format(invoice.date),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const Spacer(),
                    _buildStatusBadge(),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    switch (invoice.status.toLowerCase()) {
      case 'paid':
        return const StatusBadge(label: 'Paid', type: StatusType.success);
      case 'sent':
        return const StatusBadge(label: 'Sent', type: StatusType.info);
      case 'overdue':
        return const StatusBadge(label: 'Overdue', type: StatusType.danger);
      case 'cancelled':
        return const StatusBadge(label: 'Cancelled', type: StatusType.neutral);
      default:
        return const StatusBadge(label: 'Draft', type: StatusType.neutral);
    }
  }
}


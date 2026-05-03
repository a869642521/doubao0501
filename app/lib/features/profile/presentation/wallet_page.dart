import 'package:flutter/material.dart';
import 'package:starpath/core/theme.dart';
import 'package:starpath/shared/widgets/frosted_card.dart';

class WalletPage extends StatelessWidget {
  const WalletPage({super.key});

  @override
  Widget build(BuildContext context) {
    final sampleTransactions = [
      _TransactionItem(reason: '新用户奖励', amount: 50, isEarn: true, time: '刚刚'),
    ];

    return Scaffold(
      backgroundColor: StarpathColors.background,
      appBar: AppBar(title: const Text('我的钱包')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Balance card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: StarpathColors.brandGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: StarpathColors.brandPurple.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '灵感币余额',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text(
                        '50',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6, left: 8),
                        child: Icon(
                          Icons.auto_awesome,
                          color: Colors.white.withValues(alpha: 0.8),
                          size: 22,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _buildBalanceStat('累计获得', '50'),
                      const SizedBox(width: 32),
                      _buildBalanceStat('累计消耗', '0'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // How to earn
            Text('如何赚取灵感币',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            _buildEarnRule(Icons.edit_note, '发布内容', '+10'),
            _buildEarnRule(Icons.favorite, '获得点赞', '+1'),
            _buildEarnRule(Icons.comment, '获得评论', '+2'),
            _buildEarnRule(Icons.calendar_today, '每日签到', '+5'),
            const SizedBox(height: 24),

            // Transaction history
            Text('收支明细', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 12),
            ...sampleTransactions.map((t) => _buildTransactionTile(t)),
          ],
        ),
      ),
    );
  }

  Widget _buildBalanceStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildEarnRule(IconData icon, String title, String reward) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FrostedCard(
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: StarpathColors.brandPurple.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: StarpathColors.brandPurple, size: 18),
            ),
            const SizedBox(width: 12),
            Text(title,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const Spacer(),
            ShaderMask(
              shaderCallback: (bounds) =>
                  StarpathColors.currencyGradient.createShader(bounds),
              child: Text(
                reward,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTile(_TransactionItem transaction) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: FrostedCard(
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: (transaction.isEarn
                        ? StarpathColors.success
                        : StarpathColors.error)
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                transaction.isEarn
                    ? Icons.arrow_downward
                    : Icons.arrow_upward,
                color: transaction.isEarn
                    ? StarpathColors.success
                    : StarpathColors.error,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(transaction.reason,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
                  Text(transaction.time,
                      style: TextStyle(
                          fontSize: 12, color: StarpathColors.textTertiary)),
                ],
              ),
            ),
            Text(
              '${transaction.isEarn ? '+' : '-'}${transaction.amount}',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: transaction.isEarn
                    ? StarpathColors.success
                    : StarpathColors.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionItem {
  final String reason;
  final int amount;
  final bool isEarn;
  final String time;

  const _TransactionItem({
    required this.reason,
    required this.amount,
    required this.isEarn,
    required this.time,
  });
}

import 'package:flutter/material.dart';

/// 动态作业类型步进器：+/- 按钮调整某作业类型的数量。
class JobQuantityStepper extends StatelessWidget {
  final String jobType;
  final int quantity;
  final double unitPrice;
  final ValueChanged<int> onChanged; // delta

  const JobQuantityStepper({
    super.key,
    required this.jobType,
    required this.quantity,
    required this.unitPrice,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(jobType, style: Theme.of(context).textTheme.titleMedium),
                  Text(
                    '单价 ¥${unitPrice.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              onPressed: quantity > 0 ? () => onChanged(-1) : null,
            ),
            SizedBox(
              width: 32,
              child: Text(
                '$quantity',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => onChanged(1),
            ),
          ],
        ),
      ),
    );
  }
}

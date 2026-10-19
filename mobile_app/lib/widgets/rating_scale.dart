
import 'package:flutter/material.dart';

class RatingScale extends StatelessWidget {
  final String title;
  final String? description;
  final String leftLabel;
  final String rightLabel;
  final double? value;
  final ValueChanged<double> onChanged;

  const RatingScale({
    super.key,
    required this.title,
    this.description,
    required this.leftLabel,
    required this.rightLabel,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description!,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
            const SizedBox(height: 22),

            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;

                void updateValue(Offset position) {
                  final percentage =
                      (position.dx / width).clamp(0.0, 1.0);
                  onChanged(percentage * 100);
                }

                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (details) =>
                      updateValue(details.localPosition),
                  onHorizontalDragStart: (details) =>
                      updateValue(details.localPosition),
                  onHorizontalDragUpdate: (details) =>
                      updateValue(details.localPosition),
                  child: SizedBox(
                    width: width,
                    height: 60,
                    child: CustomPaint(
                      painter: _P804ScalePainter(
                        value: value,
                        color: Theme.of(context).brightness ==
                                Brightness.dark
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                  ),
                );
              },
            ),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    leftLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    rightLabel,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _P804ScalePainter extends CustomPainter {
  final double? value;
  final Color color;

  const _P804ScalePainter({
    required this.value,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const lineY = 20.0;

    final scalePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.square;

    // Main horizontal line.
    canvas.drawLine(
      const Offset(0, lineY),
      Offset(size.width, lineY),
      scalePaint,
    );

    // Five equally spaced major vertical lines.
    // No small tick marks between them.
    const majorIntervals = 4;

    for (var i = 0; i <= majorIntervals; i++) {
      final x = size.width * i / majorIntervals;

      canvas.drawLine(
        Offset(x, lineY),
        Offset(x, lineY + 23.0),
        scalePaint,
      );
    }

    // Two short extensions at the ends.
    const extensionLength = 9.0;

    canvas.drawLine(
      const Offset(0, lineY),
      const Offset(0, lineY - extensionLength),
      scalePaint,
    );

    canvas.drawLine(
      Offset(size.width, lineY),
      Offset(size.width, lineY - extensionLength),
      scalePaint,
    );

    // Selected red X, positioned on the horizontal line.
    if (value != null) {
      final fraction = (value! / 100).clamp(0.0, 1.0);
      final x = size.width * fraction;

      final xPaint = Paint()
        ..color = Colors.red.shade700
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;

      const halfSize = 9.0;

      canvas.drawLine(
        Offset(x - halfSize, lineY - halfSize),
        Offset(x + halfSize, lineY + halfSize),
        xPaint,
      );

      canvas.drawLine(
        Offset(x - halfSize, lineY + halfSize),
        Offset(x + halfSize, lineY - halfSize),
        xPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _P804ScalePainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.color != color;
  }
}

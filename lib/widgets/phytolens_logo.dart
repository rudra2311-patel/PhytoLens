import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

/// PhytoLens Logo Widget
/// Displays the app logo with leaf magnifying glass design
class PhytoLensLogo extends StatelessWidget {
  final double size;
  final bool showText;

  const PhytoLensLogo({super.key, this.size = 100, this.showText = true});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Logo
        CustomPaint(size: Size(size, size), painter: PhytoLensLogoPainter()),

        if (showText) ...[
          const SizedBox(height: 16),
          // App Name
          Text(
            'PhytoLens',
            style: TextStyle(
              fontSize: size * 0.25,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          // Tagline
          Text(
            'AI-Powered Crop Disease Detection',
            style: TextStyle(
              fontSize: size * 0.12,
              color: AppColors.primaryDark.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// Custom Painter for PhytoLens Logo
class PhytoLensLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.45;

    // Lens Ring (Emerald-600)
    final lensPaint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.08;

    canvas.drawCircle(center, radius, lensPaint);

    // Glass Reflection (Emerald-400)
    final reflectionPaint = Paint()
      ..color = AppColors.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.04
      ..strokeCap = StrokeCap.round;

    final reflectionPath = Path()
      ..moveTo(center.dx + radius * 0.4, center.dy - radius * 0.5)
      ..arcToPoint(
        Offset(center.dx, center.dy - radius * 0.64),
        radius: Radius.circular(radius * 0.5),
        clockwise: false,
      );

    canvas.drawPath(reflectionPath, reflectionPaint);

    // Leaf Shape (Emerald-500)
    final leafPaint = Paint()
      ..color = AppColors.secondary
      ..style = PaintingStyle.fill;

    final leafPath = Path()
      ..moveTo(center.dx, center.dy + radius * 0.6)
      ..quadraticBezierTo(
        center.dx - radius * 0.5,
        center.dy + radius * 0.2,
        center.dx - radius * 0.5,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx - radius * 0.5,
        center.dy - radius * 0.4,
        center.dx,
        center.dy - radius * 0.6,
      )
      ..quadraticBezierTo(
        center.dx + radius * 0.5,
        center.dy - radius * 0.4,
        center.dx + radius * 0.5,
        center.dy,
      )
      ..quadraticBezierTo(
        center.dx + radius * 0.5,
        center.dy + radius * 0.2,
        center.dx,
        center.dy + radius * 0.6,
      );

    canvas.drawPath(leafPath, leafPaint);

    // Leaf Vein (Emerald-800)
    final veinPaint = Paint()
      ..color = AppColors.primaryDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.03
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(center.dx, center.dy + radius * 0.6),
      Offset(center.dx, center.dy - radius * 0.45),
      veinPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

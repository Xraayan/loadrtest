import 'package:flutter/material.dart';

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFECECEC),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class MapScreenSkeleton extends StatelessWidget {
  const MapScreenSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFEDEBE7),
      body: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(color: Color(0xFFEDEBE7)),
              child: CustomPaint(painter: _MapGridPainter()),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: Color(0x14000000), blurRadius: 18),
                  ],
                ),
                child: const Row(
                  children: [
                    Icon(Icons.arrow_back, color: Colors.black26),
                    SizedBox(width: 14),
                    Expanded(child: SkeletonBox(height: 18)),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            right: 16,
            top: MediaQuery.paddingOf(context).top + 88,
            child: Container(
              width: 56,
              height: 104,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(color: Color(0x22000000), blurRadius: 24),
                ],
              ),
              child: const SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                        child: SkeletonBox(width: 48, height: 4, radius: 99)),
                    SizedBox(height: 24),
                    SkeletonBox(width: 190, height: 28),
                    SizedBox(height: 18),
                    SkeletonBox(height: 92, radius: 18),
                    SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        SkeletonBox(width: 92, height: 30, radius: 99),
                        SkeletonBox(width: 128, height: 30, radius: 99),
                        SkeletonBox(width: 116, height: 30, radius: 99),
                      ],
                    ),
                    SizedBox(height: 18),
                    SkeletonBox(height: 54, radius: 16),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CardListSkeleton extends StatelessWidget {
  final int itemCount;

  const CardListSkeleton({super.key, this.itemCount = 3});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(
        itemCount,
        (index) => const Padding(
          padding: EdgeInsets.only(bottom: 14),
          child: SkeletonBox(height: 148, radius: 14),
        ),
      ),
    );
  }
}

class GridSkeleton extends StatelessWidget {
  final int itemCount;

  const GridSkeleton({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: itemCount,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 1.4,
      ),
      itemBuilder: (context, index) => const SkeletonBox(height: 100),
    );
  }
}

class _MapGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD8D5CF)
      ..strokeWidth = 2;
    for (var y = 80.0; y < size.height; y += 90) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    for (var x = 0.0; x < size.width; x += 100) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

import 'package:flutter/material.dart';

class SkeletonBox extends StatelessWidget {
  final double? width;
  final double height;
  final double radius;
  final Color? color;

  const SkeletonBox({
    super.key,
    this.width,
    required this.height,
    this.radius = 12,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = color ?? const Color(0xFFE9E7E4);
    return _Shimmer(
      baseColor: baseColor,
      highlightColor: Color.lerp(baseColor, Colors.white, 0.58)!,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class SkeletonButtonLabel extends StatelessWidget {
  final double width;
  final double height;
  final Color color;

  const SkeletonButtonLabel({
    super.key,
    this.width = 72,
    this.height = 16,
    this.color = const Color(0x66FFFFFF),
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: height,
        height: height,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      );
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

class _Shimmer extends StatefulWidget {
  final Widget child;
  final Color baseColor;
  final Color highlightColor;

  const _Shimmer({
    required this.child,
    required this.baseColor,
    required this.highlightColor,
  });

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1250),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            final width = bounds.width == 0 ? 1.0 : bounds.width;
            final slide = _controller.value * 2 - 1;
            return LinearGradient(
              begin: Alignment(-1 + slide, -0.35),
              end: Alignment(1 + slide, 0.35),
              colors: [
                widget.baseColor,
                widget.highlightColor,
                widget.baseColor,
              ],
              stops: const [0.22, 0.5, 0.78],
            ).createShader(Rect.fromLTWH(0, 0, width, bounds.height));
          },
          child: child!,
        );
      },
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
          child: _TripCardSkeleton(),
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
      itemBuilder: (context, index) => const _VehicleGridTileSkeleton(),
    );
  }
}

class _TripCardSkeleton extends StatelessWidget {
  const _TripCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEAEAEA)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 14,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SkeletonBox(width: 44, height: 44, radius: 8),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBox(height: 16, radius: 5),
                    SizedBox(height: 8),
                    SkeletonBox(width: 140, height: 12, radius: 4),
                  ],
                ),
              ),
              SkeletonBox(width: 66, height: 24, radius: 99),
            ],
          ),
          SizedBox(height: 18),
          SkeletonBox(height: 13, radius: 4),
          SizedBox(height: 10),
          SkeletonBox(width: 220, height: 13, radius: 4),
          SizedBox(height: 16),
          SkeletonBox(width: 120, height: 14, radius: 4),
        ],
      ),
    );
  }
}

class _VehicleGridTileSkeleton extends StatelessWidget {
  const _VehicleGridTileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEAEAEA)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SkeletonBox(width: 38, height: 38, radius: 8),
          Spacer(),
          SkeletonBox(height: 14, radius: 4),
          SizedBox(height: 8),
          SkeletonBox(width: 88, height: 12, radius: 4),
        ],
      ),
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

import 'package:flutter/material.dart';
import 'package:loadr/models/menu_card_data.dart';
import 'package:loadr/widgets/menu_card.dart';

class ScrollableScreen extends StatefulWidget {
  final double headerHeight;

  final Size size;
  const ScrollableScreen(
      {required this.headerHeight, required this.size, super.key});

  @override
  State<ScrollableScreen> createState() => _ScrollableScreenState();
}

class _ScrollableScreenState extends State<ScrollableScreen> {
  final List<MenuCardData> _menuItems = [
    MenuCardData(
      title: 'New Trip',
      description:
          'Start your Trip Today In publishing and graphic design. Lorem ipsum is a placeholder text commonly.',
      icon: Icons.local_shipping_rounded,
      iconColor: const Color(0xFFFF6B4A),
      bgColor: const Color(0xFFFFECE8),
      route: '/new-trips',
    ),
    MenuCardData(
        title: 'All Trips',
        description:
            'Start your Trip Today In publishing and graphic design. Lorem ipsum is a placeholder text commonly.',
        icon: Icons.swap_vert_circle_rounded,
        iconColor: const Color(0xFFD44ED0),
        bgColor: const Color(0xFFF9E8FF),
        route: '/all-trips'),
    MenuCardData(
      title: 'Expenses',
      description:
          'Start your Trip Today In publishing and graphic design. Lorem ipsum is a placeholder text commonly.',
      icon: Icons.payments_rounded,
      iconColor: const Color(0xFF4CAF50),
      bgColor: const Color(0xFFE8F5E9),
    ),
    MenuCardData(
      title: 'Support',
      description:
          'Start your Trip Today In publishing and graphic design. Lorem ipsum is a placeholder text commonly.',
      icon: Icons.support_agent_rounded,
      iconColor: const Color(0xFFE91E63),
      bgColor: const Color(0xFFFFE8F0),
    ),
    MenuCardData(
      title: 'Jobs',
      description:
          'Start your Trip Today In publishing and graphic design. Lorem ipsum is a placeholder text commonly.',
      icon: Icons.add_road_rounded,
      iconColor: const Color(0xFFFF9800),
      bgColor: const Color(0xFFFFF3E0),
    ),
    MenuCardData(
        title: 'Ledger',
        description:
            'Start your Trip Today In publishing and graphic design. Lorem ipsum is a placeholder text commonly.',
        icon: Icons.book_rounded,
        iconColor: const Color(0xFFE91E63),
        bgColor: const Color(0xFFFFE8F0),
        route: '/ledger'),
  ];
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 1 - (widget.headerHeight / widget.size.height) + 0.04,
      minChildSize: 0.40,
      maxChildSize: 1.0,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Color(0x18000000),
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag handle
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Grid
              Expanded(
                child: GridView.builder(
                  controller: scrollController,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  physics: const BouncingScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 14,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.9,
                  ),
                  itemCount: _menuItems.length,
                  itemBuilder: (context, index) =>
                      MenuCard(data: _menuItems[index]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

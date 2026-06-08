import 'package:flutter/material.dart';
import 'package:loadr/widgets/nav_item.dart';

class BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onTap;

  const BottomNav({required this.selectedIndex, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFFE53935);
    const inactiveColor = Color(0xFFAAAAAA);

    final items = [
      NavItem(icon: Icons.home_rounded, label: 'Home'),
      NavItem(icon: Icons.wallet_rounded, label: 'Wallet'),
      NavItem(icon: Icons.chat_bubble_outline_rounded, label: 'Messages'),
      NavItem(icon: Icons.person_outline_rounded, label: 'Profile'),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFF5F5),
        boxShadow: [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final selected = i == selectedIndex;
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        items[i].icon,
                        color: selected ? activeColor : inactiveColor,
                        size: 26,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        items[i].label,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w400,
                          color: selected ? activeColor : inactiveColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        height: 3,
                        width: selected ? 28 : 0,
                        decoration: BoxDecoration(
                          color: activeColor,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

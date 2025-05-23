import 'package:flutter/material.dart';

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Divider(
            color: Colors.yellow,
            thickness: 1,
            endIndent: 10,
          ),
        ),
        Text(
          'veya',
          style: TextStyle(
            color: Colors.yellow.shade700,
            fontWeight: FontWeight.bold,
          ),
        ),
        const Expanded(
          child: Divider(
            color: Colors.yellow,
            thickness: 1,
            indent: 10,
          ),
        ),
      ],
    );
  }
}

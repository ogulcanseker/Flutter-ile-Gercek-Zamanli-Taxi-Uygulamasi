import 'package:flutter/material.dart';

class RegisterText extends StatelessWidget {
  final VoidCallback onTap;
  const RegisterText({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: const Text(
          'Hesabınız yok mu? Kayıt olun',
          style: TextStyle(
            color: Colors.yellow,
            fontSize: 16,
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

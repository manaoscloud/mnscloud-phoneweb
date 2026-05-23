import 'package:flutter/material.dart';

void main() {
  runApp(const PhoneWebApp());
}

class PhoneWebApp extends StatelessWidget {
  const PhoneWebApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      title: 'MNSCloud PhoneWeb',
      home: Scaffold(
        body: Center(
          child: Text('MNSCloud PhoneWeb'),
        ),
      ),
    );
  }
}


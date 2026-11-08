import 'package:flutter/material.dart';

void main() {
  runApp(
    const MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.green,
        body: Center(
          child: Text(
            'halo',
            style: TextStyle(fontSize: 48, color: Colors.white),
          ),
        ),
      ),
    ),
  );
}
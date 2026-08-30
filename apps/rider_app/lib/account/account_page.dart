import 'package:flutter/material.dart';

/// A placeholder screen for the Account feature/tab.
class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account'),
      ),
      body: Center(
        child: Text(
          'Account Screen Placeholder',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}

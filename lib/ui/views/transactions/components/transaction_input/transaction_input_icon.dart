/// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class TransactionInputIcon extends ConsumerWidget {
  const TransactionInputIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const FaIcon(
      FontAwesomeIcons.arrowTurnDown,
      size: 12,
      color: Colors.green,
    );
  }
}

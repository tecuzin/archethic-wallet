// Flutter imports:
import 'package:aeuniverse/ui/views/intro/set_yubikey.dart';
import 'package:flutter/material.dart';

// Package imports:
import 'package:core/localization.dart';

class IntroYubikey extends StatefulWidget {
  const IntroYubikey({Key? key}) : super(key: key);
  @override
  _IntroYubikeyState createState() => _IntroYubikeyState();
}

class _IntroYubikeyState extends State<IntroYubikey> {
  @override
  Widget build(BuildContext context) {
    return SetYubikey(
        header: AppLocalization.of(context)!.seYubicloudHeader,
        description: AppLocalization.of(context)!.seYubicloudDescription);
  }
}

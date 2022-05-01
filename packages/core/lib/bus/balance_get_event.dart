/// SPDX-License-Identifier: AGPL-3.0-or-later

// Package imports:
import 'package:core/model/balance_wallet.dart';
import 'package:core/model/data/hive_db.dart';
import 'package:event_taxi/event_taxi.dart';

class BalanceGetEvent implements Event {
  BalanceGetEvent({this.response, this.account});

  final Account? account;
  final BalanceWallet? response;
}

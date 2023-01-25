import 'dart:async';
import 'dart:developer';

import 'package:aewallet/application/settings/settings.dart';
import 'package:aewallet/application/wallet/wallet.dart';
import 'package:aewallet/domain/models/core/failures.dart';
import 'package:aewallet/domain/models/core/result.dart';
import 'package:aewallet/domain/models/transaction_event.dart';
import 'package:aewallet/domain/service/command_dispatcher.dart';
import 'package:aewallet/domain/service/commands/sign_transaction.dart';
import 'package:aewallet/util/confirmations/transaction_sender.dart';
import 'package:aewallet/util/get_it_instance.dart';
import 'package:aewallet/util/keychain_util.dart';
import 'package:archethic_lib_dart/archethic_lib_dart.dart' as archethic;
import 'package:archethic_lib_dart/archethic_lib_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NftCreationCommandHandler extends ConsumerWidget {
  NftCreationCommandHandler({
    super.key,
    required this.child,
  });

  static const logName = 'SignTransactionHandler';
  final Widget child;

  final commandDispatcher = sl
      .get<CommandDispatcher<SignTransactionCommand, SignTransactionResult>>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    commandDispatcher.handler = (p0) async {
      log('>>>> Handle ');

      final operationCompleter =
          Completer<Result<TransactionConfirmation, TransactionError>>();

      final networkSettings = ref.watch(
        SettingsProviders.settings.select((settings) => settings.network),
      );
      final transactionSender = ArchethicTransactionSender(
        phoenixHttpEndpoint: networkSettings.getPhoenixHttpLink(),
        websocketEndpoint: networkSettings.getWebsocketUri(),
      );

      final transaction = await p0.toArchethicTransaction(
        ref,
        sl.get<archethic.ApiService>(),
      );

      // ignore: cascade_invocations
      transactionSender.send(
        transaction: transaction,
        onConfirmation: (confirmation) async {
          if (confirmation.isFullyConfirmed) {
            log('Final confirmation received : $confirmation', name: logName);
            operationCompleter.complete(
              Result.success(confirmation),
            );
            return;
          }
          log('Confirmation received : $confirmation', name: logName);
        },
        onError: (error) async {
          log('Transaction error received', name: logName, error: error);
          operationCompleter.complete(
            Result.failure(error),
          );
        },
      );

      return operationCompleter.future;
    };
    return child;
  }
}

extension SignTransactionCommandConversion on SignTransactionCommand {
  Future<archethic.Transaction> toArchethicTransaction(
    WidgetRef ref,
    archethic.ApiService apiService,
  ) async {
// TODO(Chralu)
// Uri.encodeFull(
//       serviceName,
//     )

    final wallet = ref.read(SessionProviders.session).loggedIn!.wallet;
    final keychain = wallet.keychainSecuredInfos.toKeychain();
    final account = wallet.appKeychain.accounts.firstWhere(
      (account) => account.name == accountName,
      orElse: () {
        throw const Failure.other();
        // throw Failure.unknownService();
      },
    );
    // final seed = archethic.uint8ListToHex(account..seed!);
    final serviceName = 'archethic-wallet-${Uri.encodeFull(accountName)}';

    final indexMap = await apiService.getTransactionIndex(
      [account.genesisAddress],
    );
    final accountIndex = indexMap[account.genesisAddress] ?? 0;
    final originPrivateKey = apiService.getOriginKey();
    final transaction = Transaction(type: type, data: data);

    final builtTransaction = keychain.buildTransaction(
      transaction,
      serviceName,
      accountIndex,
    );

    final signedTransaction = builtTransaction.originSign(originPrivateKey);
    return signedTransaction;
  }
}

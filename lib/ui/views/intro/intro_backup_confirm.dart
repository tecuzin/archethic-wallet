/// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

// Project imports:
import 'package:aewallet/application/theme.dart';
import 'package:aewallet/appstate_container.dart';
import 'package:aewallet/bus/authenticated_event.dart';
import 'package:aewallet/bus/transaction_send_event.dart';
import 'package:aewallet/localization.dart';
import 'package:aewallet/model/authentication_method.dart';
import 'package:aewallet/model/data/app_wallet.dart';
import 'package:aewallet/model/data/appdb.dart';
import 'package:aewallet/ui/util/dimens.dart';
import 'package:aewallet/ui/util/styles.dart';
import 'package:aewallet/ui/util/ui_util.dart';
import 'package:aewallet/ui/views/intro/intro_configure_security.dart';
import 'package:aewallet/ui/widgets/components/buttons.dart';
import 'package:aewallet/ui/widgets/components/dialog.dart';
import 'package:aewallet/ui/widgets/components/picker_item.dart';
import 'package:aewallet/util/biometrics_util.dart';
import 'package:aewallet/util/confirmations/confirmations_util.dart';
import 'package:aewallet/util/confirmations/subscription_channel.dart';
import 'package:aewallet/util/get_it_instance.dart';
import 'package:aewallet/util/keychain_util.dart';
import 'package:aewallet/util/mnemonics.dart';
import 'package:aewallet/util/preferences.dart';
import 'package:aewallet/util/vault.dart';
// Package imports:
import 'package:archethic_lib_dart/archethic_lib_dart.dart';
import 'package:auto_size_text/auto_size_text.dart';
import 'package:event_taxi/event_taxi.dart';
// Flutter imports:
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IntroBackupConfirm extends ConsumerStatefulWidget {
  const IntroBackupConfirm({required this.name, required this.seed, super.key});
  final String? name;
  final String? seed;

  @override
  ConsumerState<IntroBackupConfirm> createState() => _IntroBackupConfirmState();
}

class _IntroBackupConfirmState extends ConsumerState<IntroBackupConfirm> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<String> wordListSelected = List<String>.empty(growable: true);
  List<String> wordListToSelect = List<String>.empty(growable: true);
  List<String> originalWordsList = List<String>.empty(growable: true);

  StreamSubscription<AuthenticatedEvent>? _authSub;
  StreamSubscription<TransactionSendEvent>? _sendTxSub;
  SubscriptionChannel subscriptionChannel = SubscriptionChannel();
  SubscriptionChannel subscriptionChannel2 = SubscriptionChannel();

  void _registerBus() {
    _authSub = EventTaxiImpl.singleton()
        .registerTo<AuthenticatedEvent>()
        .listen((AuthenticatedEvent event) async {
      await createKeychain();
    });

    _sendTxSub = EventTaxiImpl.singleton()
        .registerTo<TransactionSendEvent>()
        .listen((TransactionSendEvent event) async {
      final localizations = AppLocalization.of(context)!;
      final theme = ref.watch(ThemeProviders.selectedTheme);
      if (event.response != 'ok' && event.nbConfirmations == 0) {
        UIUtil.showSnackbar(
          '${localizations.sendError} (${event.response!})',
          context,
          ref,
          theme.text!,
          theme.snackBarShadow!,
        );
        Navigator.of(context).pop(false);
      } else {
        if (event.response == 'ok' &&
            ConfirmationsUtil.isEnoughConfirmations(
              event.nbConfirmations!,
              event.maxConfirmations!,
            )) {
          switch (event.transactionType!) {
            case TransactionSendEventType.keychain:
              UIUtil.showSnackbar(
                event.nbConfirmations == 1
                    ? localizations.keychainCreationTransactionConfirmed1
                        .replaceAll('%1', event.nbConfirmations.toString())
                        .replaceAll('%2', event.maxConfirmations.toString())
                    : localizations.keychainCreationTransactionConfirmed
                        .replaceAll('%1', event.nbConfirmations.toString())
                        .replaceAll('%2', event.maxConfirmations.toString()),
                context,
                ref,
                theme.text!,
                theme.snackBarShadow!,
                duration: const Duration(milliseconds: 5000),
              );

              final preferences = await Preferences.getInstance();
              await subscriptionChannel2.connect(
                await preferences.getNetwork().getPhoenixHttpLink(),
                await preferences.getNetwork().getWebsocketUri(),
              );

              await KeychainUtil().createKeyChainAccess(
                widget.seed,
                widget.name,
                event.params!['keychainAddress']! as String,
                event.params!['originPrivateKey']! as String,
                event.params!['keychain']! as Keychain,
                subscriptionChannel2,
              );
              break;
            case TransactionSendEventType.keychainAccess:
              UIUtil.showSnackbar(
                event.nbConfirmations == 1
                    ? localizations.keychainAccessCreationTransactionConfirmed1
                        .replaceAll('%1', event.nbConfirmations.toString())
                        .replaceAll('%2', event.maxConfirmations.toString())
                    : localizations.keychainAccessCreationTransactionConfirmed
                        .replaceAll('%1', event.nbConfirmations.toString())
                        .replaceAll('%2', event.maxConfirmations.toString()),
                context,
                ref,
                theme.text!,
                theme.snackBarShadow!,
                duration: const Duration(milliseconds: 5000),
              );

              var error = false;
              try {
                StateContainer.of(context).appWallet =
                    await AppWallet().createNewAppWallet(
                  event.params!['keychainAddress']! as String,
                  event.params!['keychain']! as Keychain,
                  widget.name,
                );
              } catch (e) {
                error = true;
                UIUtil.showSnackbar(
                  '${localizations.sendError} ($e)',
                  context,
                  ref,
                  theme.text!,
                  theme.snackBarShadow!,
                );
              }
              if (error == false) {
                await StateContainer.of(context).requestUpdate();

                StateContainer.of(context).checkTransactionInputs(
                  localizations.transactionInputNotification,
                );
                final preferences = await Preferences.getInstance();
                StateContainer.of(context).bottomBarCurrentPage =
                    preferences.getMainScreenCurrentPage();
                StateContainer.of(context).bottomBarPageController =
                    PageController(
                  initialPage: StateContainer.of(context).bottomBarCurrentPage,
                );
                Navigator.of(context).pushNamedAndRemoveUntil(
                  '/home',
                  (Route<dynamic> route) => false,
                );
              } else {
                Navigator.of(context).pop();
              }
              break;
            case TransactionSendEventType.transfer:
              break;
            case TransactionSendEventType.token:
              break;
          }
        } else {
          UIUtil.showSnackbar(
            localizations.notEnoughConfirmations,
            context,
            ref,
            theme.text!,
            theme.snackBarShadow!,
          );
          Navigator.of(context).pop();
        }
      }
    });
  }

  void _destroyBus() {
    _authSub?.cancel();
    _sendTxSub?.cancel();
  }

  @override
  void dispose() {
    _destroyBus();
    subscriptionChannel.close();
    subscriptionChannel2.close();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _registerBus();
    Preferences.getInstance().then((Preferences preferences) {
      setState(() {
        wordListToSelect = AppMnemomics.seedToMnemonic(
          widget.seed!,
          languageCode: preferences.getLanguageSeed(),
        );
        wordListToSelect.shuffle();
        originalWordsList = AppMnemomics.seedToMnemonic(
          widget.seed!,
          languageCode: preferences.getLanguageSeed(),
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalization.of(context)!;
    final theme = ref.watch(ThemeProviders.selectedTheme);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      key: _scaffoldKey,
      body: DecoratedBox(
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage(
              theme.background3Small!,
            ),
            fit: BoxFit.fitHeight,
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[theme.backgroundDark!, theme.background!],
          ),
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) =>
              SafeArea(
            minimum: EdgeInsets.only(
              bottom: MediaQuery.of(context).size.height * 0.035,
              top: MediaQuery.of(context).size.height * 0.075,
            ),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Container(
                      margin: const EdgeInsetsDirectional.only(start: 15),
                      height: 50,
                      width: 50,
                      child: BackButton(
                        key: const Key('back'),
                        color: theme.text,
                        onPressed: () {
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsetsDirectional.only(
                            start: 20,
                            end: 20,
                            top: 10,
                          ),
                          alignment: AlignmentDirectional.centerStart,
                          child: AutoSizeText(
                            localizations.confirmSecretPhrase,
                            style: theme.textStyleSize20W700Warning,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsetsDirectional.only(
                            start: 20,
                            end: 20,
                            top: 15,
                          ),
                          child: AutoSizeText(
                            localizations.confirmSecretPhraseExplanation,
                            style: theme.textStyleSize16W600Primary,
                            textAlign: TextAlign.justify,
                            maxLines: 6,
                            stepGranularity: 0.5,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsetsDirectional.only(
                            start: 20,
                            end: 20,
                            top: 15,
                          ),
                          child: Wrap(
                            spacing: 10,
                            children: wordListSelected
                                .asMap()
                                .entries
                                .map((MapEntry entry) {
                              return SizedBox(
                                height: 35,
                                child: Chip(
                                  avatar: CircleAvatar(
                                    backgroundColor: Colors.grey.shade800,
                                    child: Text(
                                      (entry.key + 1).toString(),
                                      style: theme.textStyleSize12W100Primary60,
                                    ),
                                  ),
                                  label: Text(
                                    entry.value,
                                    style: theme.textStyleSize12W400Primary,
                                  ),
                                  onDeleted: () {
                                    setState(() {
                                      wordListToSelect.add(entry.value);
                                      wordListSelected.removeAt(entry.key);
                                    });
                                  },
                                  deleteIconColor: Colors.white,
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        Divider(
                          height: 15,
                          color: theme.text60,
                        ),
                        Container(
                          margin: const EdgeInsetsDirectional.only(
                            start: 20,
                            end: 20,
                            top: 15,
                          ),
                          child: Wrap(
                            spacing: 10,
                            children: wordListToSelect
                                .asMap()
                                .entries
                                .map((MapEntry entry) {
                              return SizedBox(
                                height: 35,
                                child: GestureDetector(
                                  onTap: () {
                                    wordListSelected.add(entry.value);
                                    wordListToSelect.removeAt(entry.key);
                                    setState(() {});
                                  },
                                  child: Chip(
                                    label: Text(
                                      entry.value,
                                      style: theme.textStyleSize12W400Primary,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Column(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        if (wordListSelected.length != 24)
                          AppButton.buildAppButton(
                            const Key('confirm'),
                            context,
                            ref,
                            AppButtonType.primaryOutline,
                            localizations.confirm,
                            Dimens.buttonTopDimens,
                            onPressed: () {},
                          )
                        else
                          AppButton.buildAppButton(
                            const Key('confirm'),
                            context,
                            ref,
                            AppButtonType.primary,
                            localizations.confirm,
                            Dimens.buttonTopDimens,
                            onPressed: () async {
                              var orderOk = true;

                              for (var i = 0;
                                  i < originalWordsList.length;
                                  i++) {
                                if (originalWordsList[i] !=
                                    wordListSelected[i]) {
                                  orderOk = false;
                                }
                              }
                              if (orderOk == false) {
                                setState(() {
                                  UIUtil.showSnackbar(
                                    localizations.confirmSecretPhraseKo,
                                    context,
                                    ref,
                                    theme.text!,
                                    theme.snackBarShadow!,
                                  );
                                });
                              } else {
                                await _launchSecurityConfiguration(
                                  widget.name!,
                                  widget.seed!,
                                );
                              }
                            },
                          ),
                      ],
                    ),
                    Row(
                      children: <Widget>[
                        AppButton.buildAppButton(
                          const Key('pass'),
                          context,
                          ref,
                          AppButtonType.primary,
                          localizations.pass,
                          Dimens.buttonBottomDimens,
                          onPressed: () {
                            AppDialogs.showConfirmDialog(
                              context,
                              ref,
                              localizations.passBackupConfirmationDisclaimer,
                              localizations.passBackupConfirmationMessage,
                              localizations.yes,
                              () async {
                                await _launchSecurityConfiguration(
                                  widget.name!,
                                  widget.seed!,
                                );
                              },
                            );
                          },
                        )
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _launchSecurityConfiguration(String name, String seed) async {
    final theme = ref.watch(ThemeProviders.selectedTheme);
    final biometricsAvalaible = await sl.get<BiometricUtil>().hasBiometrics();
    final accessModes = <PickerItem>[];
    accessModes.add(
      PickerItem(
        const AuthenticationMethod(AuthMethod.pin).getDisplayName(context),
        const AuthenticationMethod(AuthMethod.pin).getDescription(context),
        AuthenticationMethod.getIcon(AuthMethod.pin),
        theme.pickerItemIconEnabled,
        AuthMethod.pin,
        true,
      ),
    );
    accessModes.add(
      PickerItem(
        const AuthenticationMethod(AuthMethod.password).getDisplayName(context),
        const AuthenticationMethod(AuthMethod.password).getDescription(context),
        AuthenticationMethod.getIcon(AuthMethod.password),
        theme.pickerItemIconEnabled,
        AuthMethod.password,
        true,
      ),
    );
    if (biometricsAvalaible) {
      accessModes.add(
        PickerItem(
          const AuthenticationMethod(AuthMethod.biometrics)
              .getDisplayName(context),
          const AuthenticationMethod(AuthMethod.biometrics)
              .getDescription(context),
          AuthenticationMethod.getIcon(AuthMethod.biometrics),
          theme.pickerItemIconEnabled,
          AuthMethod.biometrics,
          true,
        ),
      );
    }
    accessModes.add(
      PickerItem(
        const AuthenticationMethod(AuthMethod.biometricsUniris)
            .getDisplayName(context),
        const AuthenticationMethod(AuthMethod.biometricsUniris)
            .getDescription(context),
        AuthenticationMethod.getIcon(AuthMethod.biometricsUniris),
        theme.pickerItemIconEnabled,
        AuthMethod.biometricsUniris,
        false,
      ),
    );
    accessModes.add(
      PickerItem(
        const AuthenticationMethod(AuthMethod.yubikeyWithYubicloud)
            .getDisplayName(context),
        const AuthenticationMethod(AuthMethod.yubikeyWithYubicloud)
            .getDescription(context),
        AuthenticationMethod.getIcon(AuthMethod.yubikeyWithYubicloud),
        theme.pickerItemIconEnabled,
        AuthMethod.yubikeyWithYubicloud,
        true,
      ),
    );

    final bool securityConfiguration = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (BuildContext context) {
          return IntroConfigureSecurity(
            accessModes: accessModes,
            name: name,
            seed: seed,
          );
        },
      ),
    );

    return securityConfiguration;
  }

  void _showSendingAnimation(BuildContext context) {
    final localizations = AppLocalization.of(context)!;
    final theme = ref.watch(ThemeProviders.selectedTheme);
    Navigator.of(context).push(
      AnimationLoadingOverlay(
        AnimationType.send,
        theme.animationOverlayStrong!,
        theme.animationOverlayMedium!,
        title: localizations.appWalletInitInProgress,
      ),
    );
  }

  Future<void> createKeychain() async {
    _showSendingAnimation(context);

    var error = false;

    try {
      await sl.get<DBHelper>().clearAppWallet();
      final vault = await Vault.getInstance();
      await vault.setSeed(widget.seed!);

      final originPrivateKey = sl.get<ApiService>().getOriginKey();

      final preferences = await Preferences.getInstance();

      await subscriptionChannel.connect(
        await preferences.getNetwork().getPhoenixHttpLink(),
        await preferences.getNetwork().getWebsocketUri(),
      );

      await KeychainUtil().createKeyChain(
        widget.seed,
        widget.name,
        originPrivateKey,
        preferences,
        subscriptionChannel,
      );
    } catch (e) {
      error = true;
      final localizations = AppLocalization.of(context)!;
      final theme = ref.watch(ThemeProviders.selectedTheme);
      UIUtil.showSnackbar(
        '${localizations.sendError} ($e)',
        context,
        ref,
        theme.text!,
        theme.snackBarShadow!,
      );
    }

    if (error == false) {
    } else {
      Navigator.of(context).pop();
    }
  }
}

/// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:aewallet/domain/models/core/failures.dart';
import 'package:aewallet/domain/models/core/result.dart';
import 'package:aewallet/domain/models/market_price.dart';
import 'package:aewallet/domain/repositories/market/market.dart';
import 'package:aewallet/domain/usecases/read_usecases.dart';
import 'package:aewallet/model/available_currency.dart';

class GetUCOMarketPriceUsecases
    with ReadStrategy<AvailableCurrencyEnum, MarketPrice> {
  GetUCOMarketPriceUsecases({
    required this.localRepository,
    required this.remoteRepositories,
  });

  final List<MarketRepositoryInterface> remoteRepositories;
  final MarketLocalRepositoryInterface localRepository;

  MarketRepositoryInterface _findRepo(AvailableCurrencyEnum currency) {
    try {
      return remoteRepositories.firstWhere(
        (repository) => repository.canHandleCurrency(currency),
      );
    } catch (_) {
      throw const Failure.invalidValue();
    }
  }

  @override
  Future<MarketPrice?> getLocal(AvailableCurrencyEnum command) =>
      localRepository.getPrice(currency: command).valueOrThrow;

  @override
  Future<MarketPrice?> getRemote(AvailableCurrencyEnum command) =>
      _findRepo(command).getUCOMarketPrice(command).valueOrThrow;

  @override
  Future<void> saveLocal(AvailableCurrencyEnum command, MarketPrice value) =>
      localRepository.setPrice(
        currency: command,
        price: value,
      );
}

import 'package:aewallet/application/settings/theme.dart';
import 'package:aewallet/ui/util/styles.dart';
import 'package:aewallet/ui/views/nft/layouts/components/thumbnail/nft_thumbnail_error.dart';
import 'package:aewallet/ui/widgets/components/image_network_widgeted.dart';
import 'package:aewallet/util/token_util.dart';
import 'package:aewallet/util/url_util.dart';
import 'package:archethic_lib_dart/archethic_lib_dart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class NFTThumbnailIPFS extends ConsumerWidget with UrlUtil {
  const NFTThumbnailIPFS({
    super.key,
    required this.token,
    this.roundBorder = false,
    this.withContentInfo = false,
  });

  final Token token;
  final bool roundBorder;
  final bool withContentInfo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final localizations = AppLocalizations.of(context)!;
    final theme = ref.watch(ThemeProviders.selectedTheme);
    final raw = TokenUtil.getIPFSUrlFromToken(
      token,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (raw == null)
          NFTThumbnailError(
            message: localizations.previewNotAvailable,
          )
        else
          roundBorder == true
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: ImageNetworkWidgeted(
                    url: UrlUtil.convertUrlIPFSForWeb(raw),
                    errorMessage: localizations.nftAEWebEmpty,
                  ),
                )
              : ImageNetworkWidgeted(
                  url: UrlUtil.convertUrlIPFSForWeb(raw),
                  errorMessage: localizations.nftAEWebEmpty,
                ),
        if (withContentInfo)
          Padding(
            padding: const EdgeInsets.all(10),
            child: SelectableText(
              '${localizations.nftIPFSFrom}\n${raw!}',
              style: theme.textStyleSize12W100Primary,
            ),
          ),
      ],
    );
  }
}

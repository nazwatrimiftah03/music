
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/data_saver_provider.dart';

class CoverImage extends StatelessWidget {
  final String? url;
  final double size;
  final double radius;

  const CoverImage({
    super.key,
    this.url,
    this.size = 56,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final saver = context.watch<DataSaverProvider>().enabled;

    final imageUrl = url?.trim() ?? '';

    final placeholder = Container(
      width: size,
      height: size,
      color: cs.primaryContainer,
      alignment: Alignment.center,
      child: Icon(
        Icons.music_note_rounded,
        color: cs.primary,
        size: size * 0.45,
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: saver || imageUrl.isEmpty
          ? placeholder
          : CachedNetworkImage(
        imageUrl: imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth: (size *
            MediaQuery.devicePixelRatioOf(context))
            .round(),
        memCacheHeight: (size *
            MediaQuery.devicePixelRatioOf(context))
            .round(),
        fadeInDuration: const Duration(milliseconds: 250),
        fadeOutDuration: const Duration(milliseconds: 100),
        placeholder: (_, _) => placeholder,
        errorWidget: (_, _, _) => placeholder,
      ),
    );
  }
}

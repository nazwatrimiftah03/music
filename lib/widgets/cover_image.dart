import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/data_saver_provider.dart';

class CoverImage extends StatelessWidget {
  final String? url;
  final double size;
  final double radius;
  const CoverImage({super.key, this.url, this.size = 56, this.radius = 12});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    // Mode hemat data: jangan unduh gambar, pakai ikon saja.
    final saver = context.watch<DataSaverProvider>().enabled;
    final placeholder = Container(
      width: size,
      height: size,
      color: cs.primaryContainer,
      child: Icon(Icons.music_note_rounded,
          color: cs.primary, size: size * 0.45),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: (saver || url == null || url!.isEmpty)
          ? placeholder
          : CachedNetworkImage(
        imageUrl: url!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        placeholder: (_, _) => placeholder,
        errorWidget: (_, _, _) => placeholder,
      ),
    );
  }
}
// SPDX-License-Identifier: GPL-3.0-or-later
import 'dart:io';

import 'package:flutter/material.dart';

import '../theme.dart';
import 'press_scale.dart';
import 'stroke_icon.dart';

const _back = ['M15 5l-7 7 7 7'];
final _film = [svgRect(4, 5, 16, 14, 2.5), 'M10 9.5v5l4.5-2.5z'];

String prettySize(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1 << 20) return '${(bytes / 1024).round()} KB';
  final mb = bytes / (1 << 20);
  return '${mb.toStringAsFixed(mb < 100 ? 1 : 0)} MB';
}

class ToolBar extends StatelessWidget {
  final String title;
  final String? sub;
  final Widget? leading;
  const ToolBar({super.key, required this.title, this.sub, this.leading});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: HaloColors.line, width: 0.5)),
      ),
      child: Row(
        children: [
          PressScale(
            label: 'Back',
            onTap: () => Navigator.of(context).maybePop(),
            child: SizedBox(
              width: 44,
              height: 44,
              child: Center(
                child: StrokeIcon(_back, size: 22, color: HaloColors.warm),
              ),
            ),
          ),
          const SizedBox(width: 4),
          if (leading != null) ...[leading!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: HaloType.sans(
                    size: 15,
                    weight: FontWeight.w500,
                    color: HaloColors.text,
                  ),
                ),
                if (sub != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: HaloType.mono(size: 10.5, color: HaloColors.warm),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ToolThumb extends StatelessWidget {
  final String path;
  final bool video;
  final double size;
  const ToolThumb({
    super.key,
    required this.path,
    required this.video,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: HaloColors.surface3,
      child: Center(
        child: StrokeIcon(_film, size: size * 0.5, color: HaloColors.warm),
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.24),
      child: SizedBox(
        width: size,
        height: size,
        child: video
            ? fallback
            : Image.file(
                File(path),
                fit: BoxFit.cover,
                cacheWidth: (size * 3).round(),
                gaplessPlayback: true,
                errorBuilder: (_, _, _) => fallback,
              ),
      ),
    );
  }
}

class ToolWideButton extends StatelessWidget {
  final List<String>? icon;
  final String label;
  final bool filled;
  final VoidCallback? onTap;
  const ToolWideButton({
    super.key,
    this.icon,
    required this.label,
    required this.filled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ink = filled ? HaloColors.onAmber : HaloColors.text;
    return Opacity(
      opacity: onTap == null ? 0.55 : 1,
      child: PressScale(
        label: label,
        onTap: onTap,
        scale: 0.96,
        child: Container(
          height: filled ? 54 : 50,
          decoration: BoxDecoration(
            color: filled ? HaloColors.amber : null,
            borderRadius: BorderRadius.circular(14),
            border: filled ? null : Border.all(color: HaloColors.line2),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                StrokeIcon(icon!, size: 19, color: ink),
                const SizedBox(width: 9),
              ],
              ExcludeSemantics(
                child: Text(
                  label,
                  style: HaloType.sans(
                    size: filled ? 15 : 14,
                    weight: filled ? FontWeight.w600 : FontWeight.w500,
                    color: ink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

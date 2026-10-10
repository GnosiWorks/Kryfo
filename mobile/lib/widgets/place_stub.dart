// SPDX-License-Identifier: GPL-3.0-or-later
// the card under a bubble that holds a geo: link: a pin, the place's name
// when the link carries one, and its coordinates. no map, no tiles: the
// reader's phone asks the network for nothing until a maps app takes it.
import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../open_outside.dart';
import '../place_link.dart';
import '../theme.dart';
import 'press_scale.dart';

class PlaceStub extends StatelessWidget {
  final Place place;
  final bool isOut;
  const PlaceStub({super.key, required this.place, required this.isOut});

  @override
  Widget build(BuildContext context) {
    final fg = isOut ? HaloColors.onAmber : HaloColors.text;
    final soft = isOut ? HaloColors.onAmber : HaloColors.text2;
    final pin = isOut ? HaloColors.onAmber : HaloColors.amber;
    final name = place.label ?? l10n.placeStubLocation;
    return PressScale(
      scale: 0.97,
      label: '$name, ${place.coords}',
      onTap: () async {
        final ok = await openOutside(place.uri);
        if (!ok && context.mounted) showHaloToast(context, l10n.linkNoAppOpens);
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 10, 8),
        decoration: BoxDecoration(
          color: (isOut ? HaloColors.onAmber : HaloColors.text).withValues(
            alpha: 0.07,
          ),
          borderRadius: BorderRadius.circular(9),
        ),
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: pin.withValues(alpha: isOut ? 0.12 : 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.location_on_rounded, size: 17, color: pin),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textDirection: place.label == null
                        ? null
                        : writtenDir(name),
                    style: HaloType.sans(
                      size: 13,
                      weight: FontWeight.w600,
                      color: fg,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // digits and minus signs read left to right in any language
                  Text(
                    place.coords,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textDirection: TextDirection.ltr,
                    style: HaloType.mono(size: 10.5, color: soft, letter: 0.02),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

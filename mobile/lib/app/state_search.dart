// SPDX-License-Identifier: GPL-3.0-or-later
// AppState: the search index fill

part of '../main.dart';

extension AppStateSearch on AppState {
  Future<void> _fillSearch([HaloDb? vault]) async {
    final d = vault ?? live;
    try {
      while (!haloWiping && (vault == null || identical(_openVault, vault))) {
        final p = await d.fillSearchIndex();
        if (vault == null) {
          _liveFill = p;
        } else if (identical(_openVault, vault)) {
          _vaultFill = p;
        }
        _showFill();
        if (p.at >= p.to) break;
        await Future.delayed(const Duration(milliseconds: 60));
      }
    } catch (e) {
      if (vault == null || identical(_openVault, vault)) {
        dlog('search fill stopped: $e');
      }
    }
  }

  // the search screen's line: the vault's part only while it is open
  void _showFill() {
    final v = _openVault == null ? (at: 0, to: 0) : _vaultFill;
    searchFill.value = (at: _liveFill.at + v.at, to: _liveFill.to + v.to);
  }
}

import 'package:flutter_test/flutter_test.dart';
import 'package:kryfo/delivery_mode.dart';

void main() {
  const min = 60 * 1000;
  const hour = 60 * min;

  test('an unknown or missing mode is always on', () {
    expect(deliveryModeOf(null), DeliveryMode.always);
    expect(deliveryModeOf('ntfy'), DeliveryMode.always);
    expect(deliveryModeOf('fcm'), DeliveryMode.always);
    expect(deliveryModeOf('checkins'), DeliveryMode.checkins);
    expect(deliveryModeOf('helper'), DeliveryMode.helper);
  });

  test('formats time ago', () {
    const now = 100 * hour;
    expect(agoLine(0, now), 'not yet');
    expect(agoLine(now + 5, now), 'not yet');
    expect(agoLine(now - 20 * 1000, now), 'just now');
    expect(agoLine(now - 4 * min, now), '4 min ago');
    expect(agoLine(now - 61 * min, now), '1 hour ago');
    expect(agoLine(now - 5 * hour, now), '5 hours ago');
    expect(agoLine(now - 30 * hour, now), 'yesterday');
    expect(agoLine(now - 72 * hour, now), '3 days ago');
  });

  group('the status line says what happened', () {
    DeliveryStatus line(
      DeliveryMode m, {
      bool connected = false,
      bool connecting = false,
      bool checking = false,
      int check = 0,
      int wake = 0,
      String? helper,
    }) => deliveryStatus(
      mode: m,
      connected: connected,
      connecting: connecting,
      checking: checking,
      lastCheckMs: check,
      lastWakeMs: wake,
      nowMs: 50 * hour,
      helperName: helper,
    );

    test('always on shows the connection', () {
      expect(line(DeliveryMode.always, connected: true).text, 'Connected');
      expect(line(DeliveryMode.always, connected: true).live, true);
      expect(line(DeliveryMode.always, connecting: true).text, 'Connecting');
      expect(line(DeliveryMode.always).text, 'Not connected');
    });
    test('check-ins show the last check-in', () {
      expect(line(DeliveryMode.checkins).text, 'No check-in yet');
      expect(
        line(DeliveryMode.checkins, check: 50 * hour - 4 * min).text,
        'Last checked 4 min ago',
      );
      expect(
        line(DeliveryMode.checkins, check: 50 * hour - 3 * hour).text,
        'Last checked 3 hours ago',
      );
      expect(line(DeliveryMode.checkins, checking: true).text, 'Checking now');
      // this screen is only ever read with kryfo open, so the last check-in
      // has to be on the line there too or it is never seen
      expect(
        line(
          DeliveryMode.checkins,
          connected: true,
          check: 50 * hour - 8 * min,
        ).text,
        'Connected now \u00B7 last check-in 8 min ago',
      );
      expect(
        line(DeliveryMode.checkins, connected: true).text,
        'Connected now \u00B7 no check-in yet',
      );
      expect(
        line(DeliveryMode.checkins, connecting: true).text,
        'Connecting \u00B7 no check-in yet',
      );
    });
    test('helper shows the last wake-up', () {
      expect(
        line(
          DeliveryMode.helper,
          helper: 'ntfy',
          wake: 50 * hour - 2 * min,
        ).text,
        'Woken by ntfy · last wake-up 2 min ago',
      );
      expect(
        line(DeliveryMode.helper).text,
        'Woken by a helper app · no wake-up yet',
      );
    });
  });

  group('the nudge', () {
    const now = 1000 * hour;
    RestartVerdict judge({
      int beat = now - 2 * hour,
      int booted = now - 50 * hour,
      List<int> kills = const [],
      bool shown = false,
      DeliveryMode mode = DeliveryMode.always,
    }) => judgeRestart(
      nowMs: now,
      lastBeatMs: beat,
      bootedAtMs: booted,
      kills: kills,
      nudgeShown: shown,
      mode: mode,
    );

    test('a long silence without reboot is a kill', () {
      final v = judge();
      expect(v.wasKill, true);
      expect(v.kills, [now]);
      expect(v.showNudge, false);
    });
    test('a short gap is a normal restart', () {
      expect(judge(beat: now - 10 * min).wasKill, false);
    });
    test('a reboot in between is not a kill', () {
      expect(judge(booted: now - 5 * min).wasKill, false);
    });
    test('first run is not a kill', () {
      expect(judge(beat: 0).wasKill, false);
    });
    test('only always-on is expected to stay alive', () {
      expect(judge(mode: DeliveryMode.checkins).wasKill, false);
      expect(judge(mode: DeliveryMode.helper).wasKill, false);
    });
    test('three in a day shows the card', () {
      final v = judge(kills: [now - 20 * hour, now - 3 * hour]);
      expect(v.kills.length, 3);
      expect(v.showNudge, true);
    });
    test('old kills fall out of the day', () {
      final v = judge(kills: [now - 30 * hour, now - 3 * hour]);
      expect(v.kills.length, 2);
      expect(v.showNudge, false);
    });
    test('shows the card only once', () {
      final v = judge(kills: [now - 20 * hour, now - 3 * hour], shown: true);
      expect(v.showNudge, false);
    });
    test('a clock set back drops future kills', () {
      final v = judge(kills: [now + hour, now + 2 * hour]);
      expect(v.kills, [now]);
    });
  });
}

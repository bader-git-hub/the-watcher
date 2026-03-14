import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'dart:math';
import 'dart:js' as js;

void main() {
  runApp(
    GameWidget(
      game: TheWatcherGame(),
      overlayBuilderMap: {
        'Title': (context, game) => TitleOverlay(game: game as TheWatcherGame),
        'HUD': (context, game) => HudOverlay(game: game as TheWatcherGame),
        'Profile': (context, game) =>
            ProfileOverlay(game: game as TheWatcherGame),
        'Juice': (context, game) => JuiceOverlay(game: game as TheWatcherGame),
        'RoundIntro': (context, game) =>
            RoundIntroOverlay(game: game as TheWatcherGame),
        'GameOver': (context, game) =>
            GameOverOverlay(game: game as TheWatcherGame),
        'Victory': (context, game) =>
            VictoryOverlay(game: game as TheWatcherGame),
        'Event': (context, game) => EventOverlay(game: game as TheWatcherGame),
      },
    ),
  );
}

// ─── SOUND ENGINE ─────────────────────────────────────────────────────────────

class SoundEngine {
  static js.JsObject? _ctx;
  static double vol = 0.55;
  static double musicVol = 0.4;
  static js.JsObject? _musicMaster;
  static List<js.JsObject> _musicNodes = [];
  static bool _musicPlaying = false;

  static void applyMusicVol() {
    if (_musicMaster != null) {
      try {
        (_musicMaster!['gain'] as js.JsObject)['value'] = musicVol;
      } catch (_) {}
    }
  }

  static void resumeAndPlayMenuMusic() {
    try {
      final c = ctx;
      c.callMethod('resume');
      if (!_musicPlaying) playMenuMusic();
    } catch (_) {}
  }

  static js.JsObject get ctx {
    _ctx ??= js.JsObject(
      js.context['AudioContext'] ?? js.context['webkitAudioContext'],
    );
    final state = _ctx!['state'] as String;
    if (state == 'suspended') _ctx!.callMethod('resume');
    return _ctx!;
  }

  static js.JsObject _gain(double v, [js.JsObject? dest]) {
    final g = ctx.callMethod('createGain') as js.JsObject;
    (g['gain'] as js.JsObject)['value'] = v * vol;
    g.callMethod('connect', [dest ?? ctx['destination']]);
    return g;
  }

  static void _osc(
    double freq,
    String type,
    double dur, {
    double freqEnd = 0,
    double v = 0.3,
    double attack = 0.005,
    double rel = 0.05,
    double startOff = 0,
    js.JsObject? dest,
  }) {
    try {
      final c = ctx;
      final now = (c['currentTime'] as num).toDouble() + startOff;
      final o = c.callMethod('createOscillator') as js.JsObject;
      final g = _gain(v, dest);
      o['type'] = type;
      (o['frequency'] as js.JsObject)['value'] = freq;
      if (freqEnd > 0)
        (o['frequency'] as js.JsObject).callMethod(
          'exponentialRampToValueAtTime',
          [freqEnd, now + dur],
        );
      (g['gain'] as js.JsObject).callMethod('setValueAtTime', [0.001, now]);
      (g['gain'] as js.JsObject).callMethod('linearRampToValueAtTime', [
        v * vol,
        now + attack,
      ]);
      (g['gain'] as js.JsObject).callMethod('exponentialRampToValueAtTime', [
        0.001,
        now + dur - rel,
      ]);
      o.callMethod('connect', [g]);
      o.callMethod('start', [now]);
      o.callMethod('stop', [now + dur]);
    } catch (_) {}
  }

  static void _noise(
    double dur,
    double v, {
    double hipass = 400,
    double startOff = 0,
    js.JsObject? dest,
  }) {
    try {
      final c = ctx;
      final now = (c['currentTime'] as num).toDouble() + startOff;
      final rate = (c['sampleRate'] as num).toInt();
      final frames = (rate * dur).toInt();
      final buf =
          c.callMethod('createBuffer', [1, frames, rate]) as js.JsObject;
      final data = buf.callMethod('getChannelData', [0]) as js.JsObject;
      final rng = Random();
      for (int i = 0; i < frames; i++) data[i] = rng.nextDouble() * 2 - 1;
      final src = c.callMethod('createBufferSource') as js.JsObject;
      src['buffer'] = buf;
      final f = c.callMethod('createBiquadFilter') as js.JsObject;
      f['type'] = 'highpass';
      (f['frequency'] as js.JsObject)['value'] = hipass;
      final g = _gain(v, dest);
      (g['gain'] as js.JsObject).callMethod('setValueAtTime', [v * vol, now]);
      (g['gain'] as js.JsObject).callMethod('exponentialRampToValueAtTime', [
        0.001,
        now + dur,
      ]);
      src.callMethod('connect', [f]);
      f.callMethod('connect', [g]);
      src.callMethod('start', [now]);
      src.callMethod('stop', [now + dur]);
    } catch (_) {}
  }

  // ── SFX ──

  static void flag() {
    _osc(120, 'sine', 0.25, freqEnd: 40, v: 0.7, attack: 0.001, rel: 0.15);
    _noise(0.04, 0.4, hipass: 3000);
    _osc(1800, 'square', 0.04, freqEnd: 800, v: 0.2, attack: 0.001, rel: 0.02);
  }

  static void clear() {
    _osc(660, 'sine', 0.12, freqEnd: 880, v: 0.3, attack: 0.005, rel: 0.04);
    _osc(
      880,
      'sine',
      0.18,
      freqEnd: 1100,
      v: 0.25,
      attack: 0.005,
      rel: 0.05,
      startOff: 0.1,
    );
    _osc(1320, 'sine', 0.14, v: 0.15, attack: 0.005, rel: 0.06, startOff: 0.22);
  }

  static void wrong() {
    _osc(200, 'sawtooth', 0.15, freqEnd: 80, v: 0.5, attack: 0.001, rel: 0.1);
    _osc(
      180,
      'square',
      0.15,
      freqEnd: 60,
      v: 0.4,
      attack: 0.001,
      rel: 0.1,
      startOff: 0.12,
    );
    _osc(
      160,
      'sawtooth',
      0.2,
      freqEnd: 50,
      v: 0.35,
      attack: 0.001,
      rel: 0.15,
      startOff: 0.22,
    );
    _noise(0.12, 0.25, hipass: 200);
  }

  static void cameraSwitch() {
    _noise(0.06, 0.35, hipass: 1500);
    _noise(0.04, 0.2, hipass: 800, startOff: 0.05);
    _osc(2000, 'square', 0.03, freqEnd: 100, v: 0.1, attack: 0.001, rel: 0.02);
  }

  static void signalLoss() {
    for (int layer = 0; layer < 3; layer++) {
      _noise(
        0.8,
        0.35 - layer * 0.08,
        hipass: (800 + layer * 600).toDouble(),
        startOff: layer * 0.05,
      );
    }
    _osc(60, 'sine', 0.6, freqEnd: 40, v: 0.3, attack: 0.02, rel: 0.3);
    _osc(
      3200,
      'square',
      0.03,
      freqEnd: 800,
      v: 0.15,
      attack: 0.001,
      rel: 0.02,
      startOff: 0.1,
    );
    _osc(
      1600,
      'square',
      0.03,
      freqEnd: 400,
      v: 0.1,
      attack: 0.001,
      rel: 0.02,
      startOff: 0.18,
    );
  }

  static void spawn() {
    for (int i = 0; i < 4; i++) {
      _osc(
        400 + i * 120,
        'sine',
        0.06,
        freqEnd: 600 + i * 150.0,
        v: 0.12,
        attack: 0.001,
        rel: 0.03,
        startOff: i * 0.04,
      );
    }
  }

  static void timerTick() {
    _osc(880, 'sine', 0.04, freqEnd: 660, v: 0.22, attack: 0.001, rel: 0.02);
    _noise(0.02, 0.08, hipass: 4000);
  }

  static void flee() {
    for (int i = 0; i < 3; i++) {
      _osc(
        880,
        'square',
        0.08,
        freqEnd: 1200,
        v: 0.3,
        attack: 0.001,
        rel: 0.04,
        startOff: i * 0.14,
      );
      _osc(
        660,
        'square',
        0.08,
        freqEnd: 440,
        v: 0.2,
        attack: 0.001,
        rel: 0.04,
        startOff: i * 0.14 + 0.04,
      );
    }
  }

  static void streak() {
    for (int i = 0; i < 4; i++) {
      final f = [523.0, 659.0, 784.0, 1047.0][i];
      _osc(
        f,
        'sine',
        0.15,
        v: 0.28,
        attack: 0.005,
        rel: 0.05,
        startOff: i * 0.07,
      );
    }
  }

  static void victory() {
    final notes = [523.0, 659.0, 784.0, 1047.0, 1319.0, 1568.0];
    for (int i = 0; i < notes.length; i++) {
      _osc(
        notes[i],
        'sine',
        0.35,
        v: 0.3,
        attack: 0.01,
        rel: 0.1,
        startOff: i * 0.1,
      );
      if (i % 2 == 0)
        _osc(
          notes[i] / 2,
          'sine',
          0.4,
          v: 0.15,
          attack: 0.01,
          rel: 0.15,
          startOff: i * 0.1,
        );
    }
    _noise(0.08, 0.1, hipass: 3000, startOff: 0.05);
  }

  static void gameOver() {
    final notes = [220.0, 185.0, 155.0, 130.0, 110.0];
    for (int i = 0; i < notes.length; i++) {
      _osc(
        notes[i],
        'sawtooth',
        0.55,
        freqEnd: notes[i] * 0.8,
        v: 0.4,
        attack: 0.01,
        rel: 0.3,
        startOff: i * 0.22,
      );
      _osc(
        notes[i] * 1.5,
        'square',
        0.15,
        freqEnd: notes[i] * 0.5,
        v: 0.1,
        attack: 0.001,
        rel: 0.1,
        startOff: i * 0.22,
      );
    }
    _noise(0.3, 0.15, hipass: 80, startOff: 0.4);
  }

  // ── MUSIC ──

  static void stopMusic() {
    _musicPlaying = false;
    _musicMaster = null;
    for (final n in _musicNodes) {
      try {
        n.callMethod('stop');
      } catch (_) {}
    }
    _musicNodes = [];
  }

  static void playMenuMusic() {
    stopMusic();
    _musicPlaying = true;
    try {
      final c = ctx;
      final master = c.callMethod('createGain') as js.JsObject;
      (master['gain'] as js.JsObject)['value'] = musicVol;
      master.callMethod('connect', [c['destination']]);
      _musicMaster = master;

      // Drone layers
      void drone(double freq, double v) {
        final o = c.callMethod('createOscillator') as js.JsObject;
        o['type'] = 'sine';
        (o['frequency'] as js.JsObject)['value'] = freq;
        final g = c.callMethod('createGain') as js.JsObject;
        (g['gain'] as js.JsObject)['value'] = v;
        o.callMethod('connect', [g]);
        g.callMethod('connect', [master]);
        o.callMethod('start');
        _musicNodes.add(o);
      }

      drone(55, 0.55);
      drone(110, 0.2);
      drone(82.4, 0.15);

      // LFO tremolo
      final lfo = c.callMethod('createOscillator') as js.JsObject;
      lfo['type'] = 'sine';
      (lfo['frequency'] as js.JsObject)['value'] = 0.12;
      final lfoG = c.callMethod('createGain') as js.JsObject;
      (lfoG['gain'] as js.JsObject)['value'] = 0.18;
      lfo.callMethod('connect', [lfoG]);
      // connect LFO to first drone gain — approximated
      lfo.callMethod('start');
      _musicNodes.add(lfo);

      // Arp — fully pre-scheduled
      final arpNotes = [110.0, 130.8, 110.0, 98.0, 110.0, 123.5, 110.0, 146.8];
      final stepLen = 0.95;
      final totalSteps = 64;
      final startTime = (c['currentTime'] as num).toDouble() + 0.1;
      for (int i = 0; i < totalSteps; i++) {
        final t = startTime + i * stepLen;
        final freq = arpNotes[i % arpNotes.length];
        final o = c.callMethod('createOscillator') as js.JsObject;
        o['type'] = 'triangle';
        (o['frequency'] as js.JsObject)['value'] = freq;
        final g = c.callMethod('createGain') as js.JsObject;
        (g['gain'] as js.JsObject).callMethod('setValueAtTime', [0.001, t]);
        (g['gain'] as js.JsObject).callMethod('linearRampToValueAtTime', [
          0.28,
          t + 0.04,
        ]);
        (g['gain'] as js.JsObject).callMethod('setValueAtTime', [
          0.28,
          t + stepLen * 0.6,
        ]);
        (g['gain'] as js.JsObject).callMethod('exponentialRampToValueAtTime', [
          0.001,
          t + stepLen * 0.92,
        ]);
        o.callMethod('connect', [g]);
        g.callMethod('connect', [master]);
        o.callMethod('start', [t]);
        o.callMethod('stop', [t + stepLen]);
        _musicNodes.add(o);
      }
      // Eerie pings
      final pingNotes = [440.0, 523.0, 392.0, 349.0];
      for (int i = 0; i < 16; i++) {
        final t = startTime + i * 3.8 + 1.5;
        final o = c.callMethod('createOscillator') as js.JsObject;
        o['type'] = 'sine';
        (o['frequency'] as js.JsObject)['value'] = pingNotes[i % 4];
        final g = c.callMethod('createGain') as js.JsObject;
        (g['gain'] as js.JsObject).callMethod('setValueAtTime', [0.001, t]);
        (g['gain'] as js.JsObject).callMethod('linearRampToValueAtTime', [
          0.12,
          t + 0.02,
        ]);
        (g['gain'] as js.JsObject).callMethod('exponentialRampToValueAtTime', [
          0.001,
          t + 2.5,
        ]);
        o.callMethod('connect', [g]);
        g.callMethod('connect', [master]);
        o.callMethod('start', [t]);
        o.callMethod('stop', [t + 2.6]);
        _musicNodes.add(o);
      }
    } catch (_) {}
  }

  static void playGameMusic() {
    stopMusic();
    _musicPlaying = true;
    try {
      final c = ctx;
      final master = c.callMethod('createGain') as js.JsObject;
      (master['gain'] as js.JsObject)['value'] = musicVol;
      master.callMethod('connect', [c['destination']]);
      _musicMaster = master;

      // Bass drone
      final bass = c.callMethod('createOscillator') as js.JsObject;
      bass['type'] = 'sawtooth';
      (bass['frequency'] as js.JsObject)['value'] = 55;
      final bassF = c.callMethod('createBiquadFilter') as js.JsObject;
      bassF['type'] = 'lowpass';
      (bassF['frequency'] as js.JsObject)['value'] = 180;
      final bassG = c.callMethod('createGain') as js.JsObject;
      (bassG['gain'] as js.JsObject)['value'] = 0.5;
      bass.callMethod('connect', [bassF]);
      bassF.callMethod('connect', [bassG]);
      bassG.callMethod('connect', [master]);
      bass.callMethod('start');
      _musicNodes.add(bass);

      final stepLen = 0.22;
      final steps = 128;
      final start = (c['currentTime'] as num).toDouble() + 0.05;

      // Kick — every 4 steps
      for (int i = 0; i < steps; i += 4) {
        final t = start + i * stepLen;
        final o = c.callMethod('createOscillator') as js.JsObject;
        o['type'] = 'sine';
        (o['frequency'] as js.JsObject)['value'] = 80;
        (o['frequency'] as js.JsObject).callMethod(
          'exponentialRampToValueAtTime',
          [35, t + 0.12],
        );
        final g = c.callMethod('createGain') as js.JsObject;
        (g['gain'] as js.JsObject).callMethod('setValueAtTime', [0.001, t]);
        (g['gain'] as js.JsObject).callMethod('linearRampToValueAtTime', [
          0.7,
          t + 0.005,
        ]);
        (g['gain'] as js.JsObject).callMethod('exponentialRampToValueAtTime', [
          0.001,
          t + 0.18,
        ]);
        o.callMethod('connect', [g]);
        g.callMethod('connect', [master]);
        o.callMethod('start', [t]);
        o.callMethod('stop', [t + 0.2]);
        _musicNodes.add(o);
      }

      // Melodic stabs
      final stabNotes = [110.0, 116.5, 110.0, 98.0, 110.0, 103.8, 110.0, 92.5];
      final stabPattern = [1, 0, 0, 1, 0, 1, 0, 0];
      for (int i = 0; i < steps; i++) {
        if (stabPattern[i % 8] == 0) continue;
        final t = start + i * stepLen;
        final freq = stabNotes[i % stabNotes.length];
        final o = c.callMethod('createOscillator') as js.JsObject;
        o['type'] = 'square';
        (o['frequency'] as js.JsObject)['value'] = freq;
        final lp = c.callMethod('createBiquadFilter') as js.JsObject;
        lp['type'] = 'lowpass';
        (lp['frequency'] as js.JsObject)['value'] = 600;
        final g = c.callMethod('createGain') as js.JsObject;
        (g['gain'] as js.JsObject).callMethod('setValueAtTime', [0.001, t]);
        (g['gain'] as js.JsObject).callMethod('linearRampToValueAtTime', [
          0.18,
          t + 0.01,
        ]);
        (g['gain'] as js.JsObject).callMethod('exponentialRampToValueAtTime', [
          0.001,
          t + 0.15,
        ]);
        o.callMethod('connect', [lp]);
        lp.callMethod('connect', [g]);
        g.callMethod('connect', [master]);
        o.callMethod('start', [t]);
        o.callMethod('stop', [t + 0.18]);
        _musicNodes.add(o);
      }

      // Eerie high strings
      final highNotes = [440.0, 415.3, 392.0, 369.9];
      for (int i = 0; i < 16; i++) {
        final t = start + i * 3.52;
        final o = c.callMethod('createOscillator') as js.JsObject;
        o['type'] = 'sawtooth';
        (o['frequency'] as js.JsObject)['value'] = highNotes[i % 4];
        final lp = c.callMethod('createBiquadFilter') as js.JsObject;
        lp['type'] = 'lowpass';
        (lp['frequency'] as js.JsObject)['value'] = 900;
        final g = c.callMethod('createGain') as js.JsObject;
        (g['gain'] as js.JsObject).callMethod('setValueAtTime', [0.001, t]);
        (g['gain'] as js.JsObject).callMethod('linearRampToValueAtTime', [
          0.09,
          t + 0.3,
        ]);
        (g['gain'] as js.JsObject).callMethod('setValueAtTime', [
          0.09,
          t + 2.8,
        ]);
        (g['gain'] as js.JsObject).callMethod('exponentialRampToValueAtTime', [
          0.001,
          t + 3.4,
        ]);
        o.callMethod('connect', [lp]);
        lp.callMethod('connect', [g]);
        g.callMethod('connect', [master]);
        o.callMethod('start', [t]);
        o.callMethod('stop', [t + 3.5]);
        _musicNodes.add(o);
      }
    } catch (_) {}
  }

  static void dossierOpen() {
    _osc(1200, 'sine', 0.04, freqEnd: 800, v: 0.18, attack: 0.001, rel: 0.02);
    _osc(600, 'sine', 0.08, v: 0.12, attack: 0.005, rel: 0.05, startOff: 0.03);
    _noise(0.03, 0.08, hipass: 2000);
  }

  static void ambientTick() {
    _osc(55, 'sine', 1.5, v: 0.03, attack: 0.4, rel: 0.6);
  }
}

// ─── MAP PIXEL ────────────────────────────────────────────────────────────────

class MapPixel {
  final double x, y, w, h;
  final Color color;
  double alpha = 0.0;
  final double delay;
  MapPixel({
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.color,
    required this.delay,
  });
}

// ─── MAP DEFINITIONS (TOP-DOWN) ───────────────────────────────────────────────

MapPixel _r(double x, double y, double w, double h, Color c, double d) =>
    MapPixel(x: x, y: y, w: w, h: h, color: c, delay: d);

List<MapPixel> buildMarketMap(double sw, double sh) {
  final p = <MapPixel>[];
  final rng = Random(42);
  // Ground tiles warm sandstone
  for (double x = 0; x < sw; x += 32) {
    for (double y = 100; y < sh; y += 32) {
      p.add(_r(x, y, 31, 31, const Color(0xFF1c1810), rng.nextDouble() * 0.25));
    }
  }
  for (double y = 100; y < sh; y += 32) {
    p.add(_r(0, y, sw, 2, const Color(0xFF0e0c08), 0.04));
  }
  for (double x = 0; x < sw; x += 32) {
    p.add(_r(x, 100, 2, sh - 100, const Color(0xFF0e0c08), 0.04));
  }
  // Road through middle
  for (double x = 0; x < sw; x += 20) {
    p.add(_r(x, sh * 0.47, 20, sh * 0.13, const Color(0xFF141210), 0.08));
  }
  for (double x = 0; x < sw; x += 44) {
    p.add(_r(x + 8, sh * 0.525, 26, 4, const Color(0xFF1c1a10), 0.12));
  }
  // Market stalls top-down rooftops
  final stalls = [
    [sw * 0.06, sh * 0.16],
    [sw * 0.36, sh * 0.16],
    [sw * 0.66, sh * 0.16],
    [sw * 0.06, sh * 0.66],
    [sw * 0.36, sh * 0.66],
    [sw * 0.66, sh * 0.66],
  ];
  final awC = [
    const Color(0xFF3a1a08),
    const Color(0xFF0a2a10),
    const Color(0xFF1a0838),
    const Color(0xFF2a1a00),
    const Color(0xFF081a2a),
    const Color(0xFF1a0818),
  ];
  for (int i = 0; i < stalls.length; i++) {
    final sx = stalls[i][0];
    final sy = stalls[i][1];
    final d = 0.2 + i * 0.07;
    p.add(_r(sx + 5, sy + 5, 90, 60, Colors.black.withOpacity(0.35), d));
    p.add(_r(sx, sy, 90, 60, awC[i], d + 0.02));
    for (double ax = sx; ax < sx + 90; ax += 13) {
      p.add(_r(ax, sy, 6, 60, Colors.black.withOpacity(0.15), d + 0.03));
    }
    p.add(_r(sx, sy, 90, 3, Colors.black.withOpacity(0.4), d + 0.04));
    p.add(_r(sx, sy, 3, 60, Colors.black.withOpacity(0.4), d + 0.04));
    p.add(_r(sx + 87, sy, 3, 60, Colors.black.withOpacity(0.4), d + 0.04));
    p.add(_r(sx, sy + 57, 90, 3, Colors.black.withOpacity(0.4), d + 0.04));
    final pC = [
      const Color(0xFF3a1808),
      const Color(0xFF1a3008),
      const Color(0xFF381808),
      const Color(0xFF182a08),
      const Color(0xFF2a2808),
    ];
    for (int j = 0; j < 6; j++) {
      p.add(
        _r(sx + 6 + j * 13.0, sy + 12, 9, 9, pC[j % 5], d + 0.09 + j * 0.01),
      );
    }
    for (int j = 0; j < 5; j++) {
      p.add(
        _r(
          sx + 12 + j * 14.0,
          sy + 28,
          9,
          9,
          pC[(j + 2) % 5],
          d + 0.11 + j * 0.01,
        ),
      );
    }
    p.add(_r(sx + 8, sy + 44, 16, 10, const Color(0xFF221808), d + 0.08));
    p.add(_r(sx + 28, sy + 44, 16, 10, const Color(0xFF1e1408), d + 0.08));
  }
  // Street lamps top-down cross
  for (final lp in [
    [sw * 0.24, sh * 0.42],
    [sw * 0.54, sh * 0.42],
    [sw * 0.84, sh * 0.42],
    [sw * 0.24, sh * 0.62],
    [sw * 0.54, sh * 0.62],
    [sw * 0.84, sh * 0.62],
  ]) {
    p.add(_r(lp[0] - 1, lp[1] - 7, 4, 14, const Color(0xFF282820), 0.65));
    p.add(_r(lp[0] - 7, lp[1] - 1, 14, 4, const Color(0xFF282820), 0.65));
    p.add(_r(lp[0] - 2, lp[1] - 2, 6, 6, const Color(0xFF343428), 0.67));
  }
  // Trees top-down blobs
  for (final tp in [
    [sw * 0.01, sh * 0.12],
    [sw * 0.30, sh * 0.12],
    [sw * 0.60, sh * 0.12],
    [sw * 0.90, sh * 0.12],
    [sw * 0.01, sh * 0.70],
    [sw * 0.90, sh * 0.70],
  ]) {
    final tx = tp[0];
    final ty = tp[1];
    final d = 0.55 + rng.nextDouble() * 0.15;
    p.add(_r(tx, ty, 26, 26, Colors.black.withOpacity(0.25), d));
    p.add(_r(tx - 1, ty - 1, 26, 26, const Color(0xFF060e04), d + 0.01));
    p.add(_r(tx + 2, ty + 2, 20, 20, const Color(0xFF081206), d + 0.03));
    p.add(_r(tx + 5, ty + 5, 14, 14, const Color(0xFF0c1608), d + 0.05));
    p.add(_r(tx + 8, ty + 8, 8, 8, const Color(0xFF101c0a), d + 0.07));
  }
  return p;
}

List<MapPixel> buildResidentialMap(double sw, double sh) {
  final p = <MapPixel>[];
  final rng = Random(99);
  // Ground pavement tiles
  for (double x = 0; x < sw; x += 28) {
    for (double y = 100; y < sh; y += 28) {
      p.add(_r(x, y, 27, 27, const Color(0xFF0e1018), rng.nextDouble() * 0.18));
    }
  }
  for (double y = 100; y < sh; y += 28) {
    p.add(_r(0, y, sw, 1, const Color(0xFF0a0c14), 0.04));
  }
  for (double x = 0; x < sw; x += 28) {
    p.add(_r(x, 100, 1, sh - 100, const Color(0xFF0a0c14), 0.04));
  }
  // Main road vertical
  for (double y = 100; y < sh; y += 18) {
    p.add(_r(sw * 0.44, y, sw * 0.12, 18, const Color(0xFF0c0c10), 0.07));
  }
  for (double y = 108; y < sh; y += 38) {
    p.add(_r(sw * 0.495, y, sw * 0.01, 20, const Color(0xFF161614), 0.10));
  }
  // Houses top-down rooftops
  final houses = [
    [sw * 0.04, sh * 0.13, sw * 0.17, sh * 0.20],
    [sw * 0.22, sh * 0.13, sw * 0.17, sh * 0.18],
    [sw * 0.04, sh * 0.44, sw * 0.19, sh * 0.20],
    [sw * 0.22, sh * 0.44, sw * 0.15, sh * 0.18],
    [sw * 0.60, sh * 0.13, sw * 0.17, sh * 0.20],
    [sw * 0.78, sh * 0.13, sw * 0.15, sh * 0.18],
    [sw * 0.60, sh * 0.44, sw * 0.19, sh * 0.20],
    [sw * 0.78, sh * 0.44, sw * 0.15, sh * 0.18],
  ];
  final rC = [
    const Color(0xFF1a1020),
    const Color(0xFF201018),
    const Color(0xFF101820),
    const Color(0xFF181018),
    const Color(0xFF0e1420),
    const Color(0xFF1a1814),
    const Color(0xFF14101a),
    const Color(0xFF181414),
  ];
  for (int i = 0; i < houses.length; i++) {
    final hx = houses[i][0];
    final hy = houses[i][1];
    final hw = houses[i][2];
    final hh = houses[i][3];
    final d = 0.18 + i * 0.06;
    p.add(_r(hx + 5, hy + 5, hw, hh, Colors.black.withOpacity(0.3), d));
    p.add(_r(hx, hy, hw, hh, rC[i], d + 0.02));
    p.add(
      _r(
        hx + hw * 0.1,
        hy + hh * 0.08,
        hw * 0.8,
        hh * 0.05,
        Colors.black.withOpacity(0.25),
        d + 0.04,
      ),
    );
    p.add(
      _r(
        hx + hw * 0.1,
        hy + hh * 0.5,
        hw * 0.8,
        hh * 0.05,
        Colors.black.withOpacity(0.18),
        d + 0.04,
      ),
    );
    p.add(
      _r(
        hx + hw * 0.12,
        hy + hh * 0.18,
        hw * 0.2,
        hh * 0.17,
        const Color(0xFF0a1420),
        d + 0.07,
      ),
    );
    p.add(
      _r(
        hx + hw * 0.62,
        hy + hh * 0.18,
        hw * 0.2,
        hh * 0.17,
        const Color(0xFF0a1420),
        d + 0.07,
      ),
    );
    p.add(
      _r(
        hx + hw * 0.12,
        hy + hh * 0.60,
        hw * 0.2,
        hh * 0.17,
        const Color(0xFF0a1420),
        d + 0.07,
      ),
    );
    p.add(
      _r(
        hx + hw * 0.62,
        hy + hh * 0.60,
        hw * 0.2,
        hh * 0.17,
        const Color(0xFF0a1420),
        d + 0.07,
      ),
    );
    p.add(
      _r(
        hx + hw * 0.38,
        hy + hh * 0.76,
        hw * 0.24,
        hh * 0.22,
        const Color(0xFF080810),
        d + 0.09,
      ),
    );
  }
  // Gardens
  for (final gp in [
    [sw * 0.04, sh * 0.36],
    [sw * 0.22, sh * 0.36],
    [sw * 0.60, sh * 0.36],
    [sw * 0.78, sh * 0.36],
  ]) {
    p.add(
      _r(
        gp[0],
        gp[1],
        sw * 0.16,
        sh * 0.06,
        const Color(0xFF080e04),
        0.48 + rng.nextDouble() * 0.08,
      ),
    );
    p.add(
      _r(
        gp[0] + 3,
        gp[1] + 3,
        sw * 0.12,
        sh * 0.03,
        const Color(0xFF0a1206),
        0.50,
      ),
    );
  }
  // Cars top-down
  for (final cp in [
    [sw * 0.04, sh * 0.68],
    [sw * 0.60, sh * 0.68],
    [sw * 0.78, sh * 0.35],
  ]) {
    final cx = cp[0];
    final cy = cp[1];
    final d = 0.72 + rng.nextDouble() * 0.08;
    p.add(_r(cx + 2, cy + 2, 44, 20, Colors.black.withOpacity(0.3), d));
    p.add(_r(cx, cy, 44, 20, const Color(0xFF0c0e18), d + 0.02));
    p.add(_r(cx + 4, cy + 3, 36, 14, const Color(0xFF0e1020), d + 0.04));
    p.add(_r(cx, cy, 7, 5, const Color(0xFF080810), d + 0.05));
    p.add(_r(cx + 37, cy, 7, 5, const Color(0xFF080810), d + 0.05));
    p.add(_r(cx, cy + 15, 7, 5, const Color(0xFF080810), d + 0.05));
    p.add(_r(cx + 37, cy + 15, 7, 5, const Color(0xFF080810), d + 0.05));
  }
  // Trees
  for (final tp in [
    [sw * 0.01, sh * 0.10],
    [sw * 0.95, sh * 0.10],
    [sw * 0.01, sh * 0.67],
    [sw * 0.95, sh * 0.67],
    [sw * 0.42, sh * 0.86],
  ]) {
    final tx = tp[0];
    final ty = tp[1];
    final d = 0.68 + rng.nextDouble() * 0.12;
    p.add(_r(tx, ty, 24, 24, Colors.black.withOpacity(0.22), d));
    p.add(_r(tx - 1, ty - 1, 24, 24, const Color(0xFF060e04), d + 0.01));
    p.add(_r(tx + 2, ty + 2, 18, 18, const Color(0xFF081008), d + 0.03));
    p.add(_r(tx + 5, ty + 5, 12, 12, const Color(0xFF0c160a), d + 0.05));
  }
  return p;
}

List<MapPixel> buildTransitMap(double sw, double sh) {
  final p = <MapPixel>[];
  final rng = Random(7);
  // Platform concrete
  for (double x = 0; x < sw; x += 24) {
    for (double y = 100; y < sh; y += 24) {
      p.add(_r(x, y, 23, 23, const Color(0xFF110c0a), rng.nextDouble() * 0.18));
    }
  }
  for (double y = 100; y < sh; y += 24) {
    p.add(_r(0, y, sw, 1, const Color(0xFF0c0808), 0.04));
  }
  for (double x = 0; x < sw; x += 24) {
    p.add(_r(x, 100, 1, sh - 100, const Color(0xFF0c0808), 0.04));
  }
  // Train tracks top-down
  for (final tx in [sw * 0.20, sw * 0.60]) {
    p.add(_r(tx - 18, 100, 44, sh - 100, const Color(0xFF0e0a08), 0.08));
    p.add(_r(tx - 14, 100, 6, sh - 100, const Color(0xFF1a1410), 0.10));
    p.add(_r(tx + 16, 100, 6, sh - 100, const Color(0xFF1a1410), 0.10));
    for (double sy = 108; sy < sh; sy += 20) {
      p.add(
        _r(
          tx - 16,
          sy,
          36,
          7,
          const Color(0xFF120e0c),
          0.12 + rng.nextDouble() * 0.04,
        ),
      );
    }
  }
  // Platform island
  for (double y = 100; y < sh; y += 18) {
    p.add(_r(sw * 0.26, y, sw * 0.28, 18, const Color(0xFF130e0c), 0.07));
  }
  for (double y = 108; y < sh; y += 22) {
    p.add(_r(sw * 0.26, y, sw * 0.28, 7, const Color(0xFF1e1208), 0.13));
    p.add(_r(sw * 0.26, y, sw * 0.28, 3, const Color(0xFF281808), 0.14));
  }
  // Station building
  p.add(
    _r(sw * 0.30, 108, sw * 0.40, sh * 0.13, const Color(0xFF100c0a), 0.28),
  );
  p.add(
    _r(sw * 0.32, 112, sw * 0.36, sh * 0.11, const Color(0xFF140e0c), 0.30),
  );
  for (int i = 0; i < 4; i++) {
    p.add(
      _r(
        sw * 0.34 + i * sw * 0.07,
        118,
        sw * 0.05,
        sh * 0.04,
        const Color(0xFF0c0808),
        0.33 + i * 0.02,
      ),
    );
  }
  p.add(
    _r(
      sw * 0.46,
      108 + sh * 0.11,
      sw * 0.08,
      sh * 0.02,
      const Color(0xFF080606),
      0.36,
    ),
  );
  // Platform benches
  for (final by in [sh * 0.38, sh * 0.55, sh * 0.72]) {
    p.add(
      _r(
        sw * 0.29,
        by,
        sw * 0.09,
        sh * 0.025,
        const Color(0xFF1a1208),
        0.48 + rng.nextDouble() * 0.08,
      ),
    );
    p.add(
      _r(
        sw * 0.44,
        by,
        sw * 0.09,
        sh * 0.025,
        const Color(0xFF1a1208),
        0.48 + rng.nextDouble() * 0.08,
      ),
    );
    p.add(
      _r(
        sw * 0.29 + 2,
        by - sh * 0.012,
        sw * 0.08,
        sh * 0.008,
        const Color(0xFF160e06),
        0.50,
      ),
    );
    p.add(
      _r(
        sw * 0.44 + 2,
        by - sh * 0.012,
        sw * 0.08,
        sh * 0.008,
        const Color(0xFF160e06),
        0.50,
      ),
    );
  }
  // Ticket machines
  for (final tx in [sw * 0.29, sw * 0.44]) {
    p.add(
      _r(tx, sh * 0.28, sw * 0.04, sh * 0.05, const Color(0xFF140e0c), 0.58),
    );
    p.add(
      _r(
        tx + 2,
        sh * 0.285,
        sw * 0.03,
        sh * 0.03,
        const Color(0xFF100a08),
        0.60,
      ),
    );
  }
  // Signs
  for (final sx in [sw * 0.29, sw * 0.47]) {
    p.add(
      _r(sx, sh * 0.21, sw * 0.09, sh * 0.028, const Color(0xFF1a0c08), 0.62),
    );
    for (int j = 0; j < 3; j++) {
      p.add(
        _r(
          sx + 4 + j * sw * 0.025,
          sh * 0.215,
          sw * 0.018,
          sh * 0.014,
          const Color(0xFF0e0806),
          0.64 + j * 0.01,
        ),
      );
    }
  }
  return p;
}

List<MapPixel> buildParkMap(double sw, double sh) {
  final p = <MapPixel>[];
  final rng = Random(13);
  // Grass base varied greens
  for (double x = 0; x < sw; x += 18) {
    for (double y = 100; y < sh; y += 18) {
      final v = (rng.nextDouble() * 5).toInt();
      p.add(
        _r(
          x,
          y,
          18,
          18,
          Color.fromARGB(255, 6 + v, 11 + v, 4 + v),
          rng.nextDouble() * 0.22,
        ),
      );
    }
  }
  // Paths
  for (double x = 0; x < sw; x += 14) {
    p.add(_r(x, sh * 0.50, 14, sw * 0.045, const Color(0xFF181610), 0.04));
  }
  for (double y = 100; y < sh; y += 14) {
    p.add(_r(sw * 0.47, y, sw * 0.06, 14, const Color(0xFF181610), 0.04));
  }
  p.add(_r(0, sh * 0.50, sw, 2, const Color(0xFF100e0a), 0.06));
  p.add(_r(0, sh * 0.50 + sw * 0.045, sw, 2, const Color(0xFF100e0a), 0.06));
  // Pond
  p.add(
    _r(
      sw * 0.62,
      sh * 0.16,
      sw * 0.20,
      sh * 0.15,
      const Color(0xFF060c14),
      0.18,
    ),
  );
  p.add(
    _r(
      sw * 0.64,
      sh * 0.18,
      sw * 0.16,
      sh * 0.11,
      const Color(0xFF08101a),
      0.20,
    ),
  );
  p.add(
    _r(
      sw * 0.66,
      sh * 0.20,
      sw * 0.12,
      sh * 0.07,
      const Color(0xFF0a1420),
      0.22,
    ),
  );
  p.add(
    _r(
      sw * 0.68,
      sh * 0.23,
      sw * 0.06,
      sh * 0.025,
      const Color(0xFF0c1824),
      0.24,
    ),
  );
  p.add(_r(sw * 0.62, sh * 0.16, sw * 0.20, 2, const Color(0xFF0a1006), 0.19));
  p.add(_r(sw * 0.62, sh * 0.16, 2, sh * 0.15, const Color(0xFF0a1006), 0.19));
  // Trees top-down circles
  final trees = [
    [sw * 0.04, sh * 0.11, 28.0],
    [sw * 0.16, sh * 0.19, 22.0],
    [sw * 0.09, sh * 0.30, 30.0],
    [sw * 0.84, sh * 0.11, 26.0],
    [sw * 0.91, sh * 0.26, 22.0],
    [sw * 0.79, sh * 0.34, 18.0],
    [sw * 0.04, sh * 0.67, 26.0],
    [sw * 0.14, sh * 0.79, 20.0],
    [sw * 0.87, sh * 0.71, 24.0],
    [sw * 0.91, sh * 0.84, 18.0],
    [sw * 0.33, sh * 0.11, 22.0],
    [sw * 0.54, sh * 0.79, 26.0],
  ];
  for (int i = 0; i < trees.length; i++) {
    final tx = trees[i][0];
    final ty = trees[i][1];
    final ts = trees[i][2];
    final d = 0.30 + i * 0.035;
    p.add(_r(tx + 4, ty + 4, ts, ts, Colors.black.withOpacity(0.28), d));
    p.add(_r(tx, ty, ts, ts, const Color(0xFF060e04), d + 0.02));
    p.add(
      _r(
        tx + ts * 0.15,
        ty + ts * 0.15,
        ts * 0.70,
        ts * 0.70,
        const Color(0xFF081408),
        d + 0.04,
      ),
    );
    p.add(
      _r(
        tx + ts * 0.30,
        ty + ts * 0.20,
        ts * 0.35,
        ts * 0.35,
        const Color(0xFF0c1a0a),
        d + 0.06,
      ),
    );
    p.add(
      _r(
        tx + ts * 0.40,
        ty + ts * 0.40,
        ts * 0.18,
        ts * 0.18,
        const Color(0xFF100c06),
        d + 0.08,
      ),
    );
  }
  // Benches
  for (final bp in [
    [sw * 0.21, sh * 0.45],
    [sw * 0.67, sh * 0.45],
    [sw * 0.21, sh * 0.56],
    [sw * 0.67, sh * 0.56],
  ]) {
    final bx = bp[0];
    final by = bp[1];
    final d = 0.68 + rng.nextDouble() * 0.08;
    p.add(_r(bx + 2, by + 2, 34, 11, Colors.black.withOpacity(0.28), d));
    p.add(_r(bx, by, 34, 11, const Color(0xFF181408), d + 0.02));
    p.add(_r(bx + 2, by + 2, 30, 7, const Color(0xFF1c1810), d + 0.04));
    for (int j = 0; j < 4; j++) {
      p.add(
        _r(
          bx + 2 + j * 7.5,
          by + 2,
          5,
          7,
          const Color(0xFF201c10),
          d + 0.05 + j * 0.01,
        ),
      );
    }
  }
  // Flower beds
  final fC = [
    const Color(0xFF2a1010),
    const Color(0xFF102010),
    const Color(0xFF10102a),
    const Color(0xFF2a1a08),
  ];
  for (final fp in [
    [sw * 0.39, sh * 0.17],
    [sw * 0.39, sh * 0.71],
    [sw * 0.07, sh * 0.50],
  ]) {
    p.add(
      _r(fp[0], fp[1], sw * 0.08, sh * 0.055, const Color(0xFF0a1206), 0.58),
    );
    for (int j = 0; j < 6; j++) {
      p.add(
        _r(
          fp[0] + 4 + j * sw * 0.011,
          fp[1] + 4,
          sw * 0.008,
          sh * 0.018,
          fC[j % 4],
          0.60 + j * 0.01,
        ),
      );
    }
  }
  // Lamp posts
  for (final lp in [
    [sw * 0.47, sh * 0.42],
    [sw * 0.47, sh * 0.57],
    [sw * 0.19, sh * 0.50],
    [sw * 0.75, sh * 0.50],
  ]) {
    p.add(_r(lp[0] - 1, lp[1] - 5, 4, 10, const Color(0xFF1e1e18), 0.72));
    p.add(_r(lp[0] - 5, lp[1] - 1, 10, 4, const Color(0xFF1e1e18), 0.72));
    p.add(_r(lp[0] - 2, lp[1] - 2, 6, 6, const Color(0xFF2a2820), 0.74));
  }
  return p;
}

// ─── MAP COMPONENT ────────────────────────────────────────────────────────────

class MapBackground extends Component with HasGameRef<TheWatcherGame> {
  final List<MapPixel> pixels;
  double _elapsed = 0;
  bool built = false;

  MapBackground({required this.pixels});

  @override
  void update(double dt) {
    _elapsed += dt;
    bool allDone = true;
    for (final p in pixels) {
      if (_elapsed - p.delay > 0) {
        p.alpha = ((_elapsed - p.delay) * 2.8).clamp(0.0, 1.0);
        if (p.alpha < 1.0) allDone = false;
      } else {
        allDone = false;
      }
    }
    if (allDone) built = true;
  }

  @override
  void render(Canvas canvas) {
    for (final p in pixels) {
      if (p.alpha <= 0) continue;
      canvas.drawRect(
        Rect.fromLTWH(p.x, p.y, p.w, p.h),
        Paint()..color = p.color.withOpacity(p.alpha),
      );
    }
  }
}

// ─── DISSIDENT TYPES ──────────────────────────────────────────────────────────

enum DissidentType { obvious, master, decoy, panicked, disguised }

enum BehaviorType { nervous, normal, suspicious, secretive }

// ─── APPEARANCE ENUMS ─────────────────────────────────────────────────────────

enum HatStyle { cap, hood, beanie, none }

enum BodyShape { regular, slim }

enum AccessoryType { none, bag, backpack, briefcase }

// ─── CITIZEN DATA ─────────────────────────────────────────────────────────────

class CitizenData {
  final String name;
  final int age;
  final String job;
  final List<String> inventory;
  final bool isTrulySuspicious;
  final String systemHint, trueReason, falseHint;
  final BehaviorType behavior;
  final List<String> clues;
  final Color skinColor, torsoColor, legsColor;
  final int trackingId;
  final DissidentType? dissidentType;
  final HatStyle hatStyle;
  final BodyShape bodyShape;
  final AccessoryType accessory;

  CitizenData({
    required this.name,
    required this.age,
    required this.job,
    required this.inventory,
    required this.isTrulySuspicious,
    required this.systemHint,
    required this.trueReason,
    required this.falseHint,
    required this.behavior,
    required this.clues,
    required this.skinColor,
    required this.torsoColor,
    required this.legsColor,
    required this.trackingId,
    this.dissidentType,
    this.hatStyle = HatStyle.cap,
    this.bodyShape = BodyShape.regular,
    this.accessory = AccessoryType.none,
  });
}

// ─── DIFFICULTY ───────────────────────────────────────────────────────────────

class DifficultyConfig {
  final int citizenCount;
  final double roundDuration, citizenSpeed, clueRevealInterval, spawnDelay;
  final int scoreMultiplier, questCount;
  final String threatLevel;
  final Color threatColor;
  const DifficultyConfig({
    required this.citizenCount,
    required this.roundDuration,
    required this.citizenSpeed,
    required this.clueRevealInterval,
    required this.spawnDelay,
    required this.scoreMultiplier,
    required this.threatLevel,
    required this.threatColor,
    this.questCount = 3,
  });
}

DifficultyConfig getDifficulty(int round) {
  if (round <= 2)
    return const DifficultyConfig(
      citizenCount: 2,
      roundDuration: 40,
      citizenSpeed: 32,
      clueRevealInterval: 2.5,
      spawnDelay: 0.7,
      scoreMultiplier: 1,
      threatLevel: 'LOW',
      threatColor: Color(0xFF39ff6a),
      questCount: 3,
    );
  if (round <= 4)
    return const DifficultyConfig(
      citizenCount: 3,
      roundDuration: 35,
      citizenSpeed: 38,
      clueRevealInterval: 3.0,
      spawnDelay: 0.6,
      scoreMultiplier: 2,
      threatLevel: 'MODERATE',
      threatColor: Color(0xFFffb347),
      questCount: 5,
    );
  if (round <= 7)
    return const DifficultyConfig(
      citizenCount: 4,
      roundDuration: 30,
      citizenSpeed: 44,
      clueRevealInterval: 3.5,
      spawnDelay: 0.5,
      scoreMultiplier: 3,
      threatLevel: 'ELEVATED',
      threatColor: Color(0xFFff8800),
      questCount: 7,
    );
  if (round <= 10)
    return const DifficultyConfig(
      citizenCount: 4,
      roundDuration: 25,
      citizenSpeed: 50,
      clueRevealInterval: 4.0,
      spawnDelay: 0.4,
      scoreMultiplier: 4,
      threatLevel: 'HIGH',
      threatColor: Color(0xFFff4400),
      questCount: 7,
    );
  return const DifficultyConfig(
    citizenCount: 5,
    roundDuration: 20,
    citizenSpeed: 58,
    clueRevealInterval: 5.0,
    spawnDelay: 0.3,
    scoreMultiplier: 5,
    threatLevel: 'CRITICAL',
    threatColor: Color(0xFFff0000),
    questCount: 7,
  );
}

List<DifficultyConfig> generateRoundConfigs(String preset) {
  switch (preset) {
    case 'easy':
      return [
        const DifficultyConfig(
          citizenCount: 2,
          roundDuration: 120,
          citizenSpeed: 26,
          clueRevealInterval: 2.0,
          spawnDelay: 0.8,
          scoreMultiplier: 1,
          threatLevel: 'LOW',
          threatColor: Color(0xFF39ff6a),
          questCount: 3,
        ),
        const DifficultyConfig(
          citizenCount: 2,
          roundDuration: 100,
          citizenSpeed: 28,
          clueRevealInterval: 2.2,
          spawnDelay: 0.75,
          scoreMultiplier: 1,
          threatLevel: 'LOW',
          threatColor: Color(0xFF39ff6a),
          questCount: 3,
        ),
        const DifficultyConfig(
          citizenCount: 3,
          roundDuration: 80,
          citizenSpeed: 32,
          clueRevealInterval: 2.6,
          spawnDelay: 0.65,
          scoreMultiplier: 1,
          threatLevel: 'LOW',
          threatColor: Color(0xFF39ff6a),
          questCount: 3,
        ),
        const DifficultyConfig(
          citizenCount: 3,
          roundDuration: 65,
          citizenSpeed: 36,
          clueRevealInterval: 3.0,
          spawnDelay: 0.6,
          scoreMultiplier: 1,
          threatLevel: 'LOW',
          threatColor: Color(0xFF39ff6a),
          questCount: 3,
        ),
      ];
    case 'normal':
      return [
        const DifficultyConfig(
          citizenCount: 3,
          roundDuration: 60,
          citizenSpeed: 36,
          clueRevealInterval: 2.8,
          spawnDelay: 0.6,
          scoreMultiplier: 2,
          threatLevel: 'MODERATE',
          threatColor: Color(0xFFffb347),
          questCount: 5,
        ),
        const DifficultyConfig(
          citizenCount: 3,
          roundDuration: 50,
          citizenSpeed: 40,
          clueRevealInterval: 3.2,
          spawnDelay: 0.55,
          scoreMultiplier: 2,
          threatLevel: 'MODERATE',
          threatColor: Color(0xFFffb347),
          questCount: 5,
        ),
        const DifficultyConfig(
          citizenCount: 4,
          roundDuration: 42,
          citizenSpeed: 44,
          clueRevealInterval: 3.6,
          spawnDelay: 0.5,
          scoreMultiplier: 2,
          threatLevel: 'MODERATE',
          threatColor: Color(0xFFffb347),
          questCount: 5,
        ),
        const DifficultyConfig(
          citizenCount: 5,
          roundDuration: 35,
          citizenSpeed: 50,
          clueRevealInterval: 4.0,
          spawnDelay: 0.4,
          scoreMultiplier: 2,
          threatLevel: 'MODERATE',
          threatColor: Color(0xFFffb347),
          questCount: 5,
        ),
      ];
    case 'hard':
      return [
        const DifficultyConfig(
          citizenCount: 4,
          roundDuration: 40,
          citizenSpeed: 48,
          clueRevealInterval: 3.5,
          spawnDelay: 0.4,
          scoreMultiplier: 3,
          threatLevel: 'ELEVATED',
          threatColor: Color(0xFFff8800),
          questCount: 7,
        ),
        const DifficultyConfig(
          citizenCount: 4,
          roundDuration: 32,
          citizenSpeed: 54,
          clueRevealInterval: 4.0,
          spawnDelay: 0.35,
          scoreMultiplier: 3,
          threatLevel: 'ELEVATED',
          threatColor: Color(0xFFff8800),
          questCount: 7,
        ),
        const DifficultyConfig(
          citizenCount: 5,
          roundDuration: 26,
          citizenSpeed: 60,
          clueRevealInterval: 4.5,
          spawnDelay: 0.3,
          scoreMultiplier: 3,
          threatLevel: 'ELEVATED',
          threatColor: Color(0xFFff8800),
          questCount: 7,
        ),
        const DifficultyConfig(
          citizenCount: 6,
          roundDuration: 20,
          citizenSpeed: 66,
          clueRevealInterval: 5.0,
          spawnDelay: 0.25,
          scoreMultiplier: 3,
          threatLevel: 'ELEVATED',
          threatColor: Color(0xFFff8800),
          questCount: 7,
        ),
      ];
    default:
      return [
        // expert
        const DifficultyConfig(
          citizenCount: 5,
          roundDuration: 30,
          citizenSpeed: 58,
          clueRevealInterval: 4.5,
          spawnDelay: 0.25,
          scoreMultiplier: 5,
          threatLevel: 'CRITICAL',
          threatColor: Color(0xFFff0000),
          questCount: 7,
        ),
        const DifficultyConfig(
          citizenCount: 5,
          roundDuration: 24,
          citizenSpeed: 64,
          clueRevealInterval: 5.0,
          spawnDelay: 0.2,
          scoreMultiplier: 5,
          threatLevel: 'CRITICAL',
          threatColor: Color(0xFFff0000),
          questCount: 7,
        ),
        const DifficultyConfig(
          citizenCount: 6,
          roundDuration: 18,
          citizenSpeed: 70,
          clueRevealInterval: 5.5,
          spawnDelay: 0.18,
          scoreMultiplier: 5,
          threatLevel: 'CRITICAL',
          threatColor: Color(0xFFff0000),
          questCount: 7,
        ),
        const DifficultyConfig(
          citizenCount: 7,
          roundDuration: 14,
          citizenSpeed: 76,
          clueRevealInterval: 6.0,
          spawnDelay: 0.15,
          scoreMultiplier: 5,
          threatLevel: 'CRITICAL',
          threatColor: Color(0xFFff0000),
          questCount: 7,
        ),
      ];
  }
}

const _firstNames = [
  'Mara',
  'Deon',
  'Ines',
  'Tomas',
  'Viktor',
  'Vera',
  'Otto',
  'Lena',
  'Riku',
  'Amara',
  'Cai',
  'Nadia',
  'Felix',
  'Sione',
  'Priya',
  'Ezra',
  'Yuki',
  'Kofi',
  'Ilse',
  'Tariq',
  'Brigid',
  'Hana',
  'Matteo',
  'Zara',
  'Sven',
  'Leila',
  'Rohan',
  'Astrid',
  'Kwame',
  'Petra',
  'Dani',
  'Malik',
  'Sigrid',
  'Emre',
  'Chiara',
  'Olu',
  'Freya',
  'Jae',
  'Miriam',
  'Bram',
];
const _lastNames = [
  'Voss',
  'Park',
  'Sorel',
  'Reyes',
  'Hess',
  'Kline',
  'Braun',
  'Cross',
  'Tanaka',
  'Mensah',
  'Chen',
  'Ivanova',
  'Weber',
  'Faleolo',
  'Sharma',
  'Klein',
  'Nakamura',
  'Asante',
  'Bauer',
  'Hassan',
  'Murphy',
  'Sato',
  'Romano',
  'Ahmed',
  'Lindqvist',
  'Nazari',
  'Patel',
  'Berg',
  'Owusu',
  'Novak',
  'Kim',
  'Diallo',
  'Eriksson',
  'Yilmaz',
  'Russo',
  'Adeyemi',
  'Larsson',
  'Moon',
  'Cohen',
  'Visser',
];

class _JP {
  final String title;
  final List<String> inv, clues;
  final String sh, fh, tr;
  const _JP({
    required this.title,
    required this.inv,
    required this.clues,
    required this.sh,
    required this.fh,
    required this.tr,
  });
}

const List<_JP> _jobs = [
  _JP(
    title: 'Schoolteacher',
    inv: ['Chalk', 'Lesson plan', 'Red marker', 'Worksheets'],
    clues: [
      'Stops to help a child tie their shoes.',
      'Waves at a colleague outside the gates.',
      'Reviews lesson plans at a bench.',
    ],
    sh: 'Carrying unmarked printed materials. Route deviation flagged.',
    fh: 'Subject observed distributing documents to minors.',
    tr: 'Walking to school. Completely innocent.',
  ),
  _JP(
    title: 'Delivery Driver',
    inv: ['Parcels', 'Scanner', 'Route printout', 'Water bottle'],
    clues: [
      'Scans a barcode at a doorstep.',
      'Checks phone — delivery app visible.',
      'Recipient signs for a package.',
    ],
    sh: 'Repeated stops at multiple addresses. Possible dead drop pattern.',
    fh: 'Packages have no visible labeling. Contents unverified.',
    tr: 'On their delivery route. Innocent.',
  ),
  _JP(
    title: 'Florist',
    inv: ['Flowers', 'Wire cutters', 'Apron', 'Price tags'],
    clues: [
      'Arranges flowers outside a shop.',
      'Greets a returning customer by name.',
      'Clips stems — standard prep work.',
    ],
    sh: 'Carrying sharp tools. Frequents high-footfall public spaces.',
    fh: 'No registered business permit found under this name.',
    tr: 'Opening their flower shop. Innocent.',
  ),
  _JP(
    title: 'Student',
    inv: ['Textbooks', 'Headphones', 'Campus ID', 'Coffee'],
    clues: [
      'Checks phone — bus tracker app open.',
      'Reads a textbook while waiting.',
      'Boards the correct bus without hesitation.',
    ],
    sh: 'Loitering near transit hub. Behavioral anomaly detected.',
    fh: 'Subject appears agitated and checks surroundings repeatedly.',
    tr: 'Waiting for a bus to campus. Innocent.',
  ),
  _JP(
    title: 'Nurse',
    inv: ['Medical bag', 'Hospital ID', 'Medication', 'Gloves'],
    clues: [
      'Shows ID badge at apartment entrance.',
      'Elderly resident opens door — expected.',
      'Administers insulin. Routine home visit.',
    ],
    sh: 'Transporting controlled substances. Route deviation logged.',
    fh: 'Substances not listed in pharmacy dispatch records today.',
    tr: 'Home care visit to elderly patient. Innocent.',
  ),
  _JP(
    title: 'Retired',
    inv: ['Newspaper', 'Reading glasses', 'Bread', 'Walking stick'],
    clues: [
      'Buys bread at the corner bakery.',
      'Sits on usual bench reading newspaper.',
      'Feeds pigeons. Vendor knows him by name.',
    ],
    sh: 'Extended stationary behavior near public space. Possible lookout.',
    fh: 'Subject photographed near a restricted zone last month.',
    tr: 'Morning walk to the bakery. Innocent.',
  ),
  _JP(
    title: 'Chef',
    inv: ['Knife roll', 'Recipe notebook', 'Apron', 'Market bag'],
    clues: [
      'Inspects vegetables at a market stall.',
      'Compares produce to recipe notebook.',
      'Vendor recognizes them — regular customer.',
    ],
    sh: 'Carrying professional bladed tools in public. Risk flag.',
    fh: 'Blades exceed permitted carry length under municipal code.',
    tr: 'Shopping for tonight\'s service. Innocent.',
  ),
  _JP(
    title: 'Journalist',
    inv: ['Press badge', 'Voice recorder', 'Notepad', 'Camera'],
    clues: [
      'Shows press badge to an officer.',
      'Takes notes interviewing a bystander.',
      'Photographs a public building — standard press work.',
    ],
    sh: 'Recording public officials. Unauthorized photography detected.',
    fh: 'Press credentials appear unverified in the national registry.',
    tr: 'Covering a local story. Innocent.',
  ),
  _JP(
    title: 'Street Vendor',
    inv: ['Cash box', 'Produce crates', 'Scale', 'Plastic bags'],
    clues: [
      'Sets up market stall — familiar routine.',
      'Weighs fruit, hands over change.',
      'Neighboring vendors greet them warmly.',
    ],
    sh: 'Handling large volumes of unregistered cash transactions.',
    fh: 'Vendor permit could not be located in city records today.',
    tr: 'Running their daily market stall. Innocent.',
  ),
  _JP(
    title: 'Electrician',
    inv: ['Tool belt', 'Wiring diagrams', 'Work order', 'Hard hat'],
    clues: [
      'Checks work order before entering.',
      'Building manager lets them in.',
      'Inspects electrical panel — routine maintenance.',
    ],
    sh: 'Entering restricted utility areas. No prior clearance on file.',
    fh: 'Work order number does not match municipal schedule.',
    tr: 'Performing a scheduled inspection. Innocent.',
  ),
  _JP(
    title: 'Librarian',
    inv: ['Stack of books', 'Card scanner', 'Reading list', 'Glasses'],
    clues: [
      'Unlocks the library entrance on schedule.',
      'Stamps returned books correctly.',
      'Helps an elderly patron find a section.',
    ],
    sh: 'Distributing printed materials at high frequency. Pattern flagged.',
    fh: 'Some distributed texts contain flagged political content.',
    tr: 'Opening the library for the day. Innocent.',
  ),
  _JP(
    title: 'Dog Walker',
    inv: ['Multiple leashes', 'Treat bag', 'Waste bags', 'Client schedule'],
    clues: [
      'Collects dogs from separate apartments.',
      'Follows established route through the park.',
      'Owners wave from windows — known and trusted.',
    ],
    sh: 'Subject takes irregular routes. Frequently enters private properties.',
    fh: 'Multiple property entries logged without prior authorization.',
    tr: 'Walking client dogs on their usual route. Innocent.',
  ),
];

class _DP {
  final String job, sh, fh, tr;
  final List<String> inv, clues;
  final BehaviorType beh;
  final DissidentType type;
  final String typeLabel;
  const _DP({
    required this.job,
    required this.inv,
    required this.clues,
    required this.sh,
    required this.fh,
    required this.tr,
    required this.beh,
    required this.type,
    required this.typeLabel,
  });
}

const List<_DP> _obviousD = [
  _DP(
    job: 'Unknown',
    type: DissidentType.obvious,
    typeLabel: 'OBVIOUS SUSPECT',
    inv: ['Encrypted phone', 'Unmarked envelope', 'Burner radio'],
    clues: [
      'Drops an envelope at a bench. Walks away fast.',
      'Second person picks it up immediately. No eye contact.',
      'Uses burner radio — encrypted channel active.',
    ],
    sh: '⚠ HIGH RISK — No registered employment. Multiple anomalous signals.',
    fh: 'Could be an undercover officer. Credentials cannot be verified.',
    tr: 'Coordinating illegal distribution network.',
    beh: BehaviorType.suspicious,
  ),
  _DP(
    job: 'Trader',
    type: DissidentType.obvious,
    typeLabel: 'OBVIOUS SUSPECT',
    inv: ['Duffel bag', 'Vacuum-sealed packages', 'Burner phone', 'Cash roll'],
    clues: [
      'Transfers heavy duffel bag between two vehicles.',
      'Both drivers keep engines running — 30s exchange.',
      'Large cash payment visible. No paperwork.',
    ],
    sh: '⚠ HIGH RISK — Unregistered transfer. Unusual package volume.',
    fh: 'Informal goods trading is common in this district.',
    tr: 'Moving contraband between distribution points.',
    beh: BehaviorType.suspicious,
  ),
];
const List<_DP> _masterD = [
  _DP(
    job: 'Consultant',
    type: DissidentType.master,
    typeLabel: 'MASTER OF DISGUISE',
    inv: ['Briefcase', 'Coded notebook', 'Second phone'],
    clues: ['Passes a folded note in a handshake. Blink and you\'ll miss it.'],
    sh: 'Subject profile — low risk. Minor behavioral flag.',
    fh: 'Known corporate consultant. Briefcase contents are routine.',
    tr: 'Courier for an organized crime network.',
    beh: BehaviorType.normal,
  ),
  _DP(
    job: 'Accountant',
    type: DissidentType.master,
    typeLabel: 'MASTER OF DISGUISE',
    inv: ['Laptop bag', 'Coffee', 'Work documents'],
    clues: [
      'Laptop briefly shows encrypted financial data — not accounting software.',
    ],
    sh: 'Subject appears routine. Low confidence flag.',
    fh: 'Works for a registered firm. Documents appear legitimate.',
    tr: 'Laundering funds through shell companies.',
    beh: BehaviorType.normal,
  ),
];
const List<_DP> _decoyD = [
  _DP(
    job: 'Activist',
    type: DissidentType.decoy,
    typeLabel: '⚠ DECOY — INNOCENT',
    inv: ['Protest sign', 'Pamphlets', 'Megaphone'],
    clues: [
      'Distributing pamphlets about an environmental cause.',
      'Recognized by a city council member.',
      'Has a permit for the demonstration. Fully legal.',
    ],
    sh: '🚨 CRITICAL — Unauthorized assembly. Distributing subversive materials.',
    fh: 'Subject has prior record of civil disruption.',
    tr: 'Peaceful protest. Legally permitted. Completely innocent.',
    beh: BehaviorType.nervous,
  ),
  _DP(
    job: 'Street Performer',
    type: DissidentType.decoy,
    typeLabel: '⚠ DECOY — INNOCENT',
    inv: ['Costume', 'Props box', 'Donation hat'],
    clues: [
      'Performs for a crowd — children watching and laughing.',
      'A police officer stops to watch and applauds.',
      'Collecting donations openly. Permit visible on jacket.',
    ],
    sh: '🚨 CRITICAL — Gathering a crowd. Unusual props. Behavior flagged.',
    fh: 'Subject drawing large public attention. Potential agitator.',
    tr: 'Licensed street performer. Innocent.',
    beh: BehaviorType.normal,
  ),
];
const List<_DP> _panickedD = [
  _DP(
    job: 'Smuggler',
    type: DissidentType.panicked,
    typeLabel: 'PANICKED — WILL FLEE',
    inv: ['Hidden package', 'Fake passport', 'Burner phone'],
    clues: [
      'Keeps glancing over shoulder — watching for surveillance.',
      'Drops package when startled by a nearby sound.',
      'Attempts to leave the area when approached.',
    ],
    sh: 'Subject exhibiting high-stress behavioral pattern. Evasion likely.',
    fh: 'May have anxiety disorder. Behavior not necessarily criminal.',
    tr: 'Carrying smuggled goods. Will flee if watched.',
    beh: BehaviorType.nervous,
  ),
  _DP(
    job: 'Courier',
    type: DissidentType.panicked,
    typeLabel: 'PANICKED — WILL FLEE',
    inv: ['Sealed envelope', 'Motorcycle keys', 'Disguise kit'],
    clues: [
      'Checks phone repeatedly — waiting for a signal.',
      'Paces nervously. Avoids eye contact with everyone.',
      'Starts moving fast toward the edge of camera range.',
    ],
    sh: 'Erratic movement pattern. Subject appears to be stalling.',
    fh: 'Could be running late for a legitimate appointment.',
    tr: 'Illegal courier. Panics under observation.',
    beh: BehaviorType.nervous,
  ),
];
const List<_DP> _disguisedD = [
  _DP(
    job: 'Jogger',
    type: DissidentType.disguised,
    typeLabel: 'DISGUISED OPERATIVE',
    inv: ['Running shoes', 'Water bottle', 'Earbuds', 'Hidden radio'],
    clues: [
      'Pauses run to make a brief coded hand signal to someone.',
      'Earbuds connected to a radio, not a phone.',
      'Route passes every camera blind spot in sequence.',
    ],
    sh: 'Jogger on unusual route. Minor flag — low confidence.',
    fh: 'Exercise routes often vary. Common behavior.',
    tr: 'Operative doing surveillance sweep disguised as a jogger.',
    beh: BehaviorType.normal,
  ),
  _DP(
    job: 'Tourist',
    type: DissidentType.disguised,
    typeLabel: 'DISGUISED OPERATIVE',
    inv: ['Camera', 'Tourist map', 'Backpack', 'Hidden documents'],
    clues: [
      'Photos only target security infrastructure — no sightseeing.',
      'Map has handwritten notes marking camera positions.',
      'Backpack contains forged entry documents.',
    ],
    sh: 'Tourist with unusual photography pattern. Low confidence flag.',
    fh: 'Tourists commonly photograph public infrastructure.',
    tr: 'Intelligence operative mapping security systems.',
    beh: BehaviorType.normal,
  ),
  _DP(
    job: 'Street Vendor',
    type: DissidentType.disguised,
    typeLabel: 'DISGUISED OPERATIVE',
    inv: ['Produce stall', 'Hidden compartment', 'Coded price tags'],
    clues: [
      'Certain customers receive items without paying — coded exchange.',
      'Price tags contain numbers that don\'t match any currency.',
      'Stall always positioned at a surveillance blind spot.',
    ],
    sh: 'Vendor with inconsistent transaction patterns. Minor flag.',
    fh: 'Local vendors sometimes give food to regulars for free.',
    tr: 'Using vendor stall as front for illegal exchange network.',
    beh: BehaviorType.secretive,
  ),
];

const _skinTones = [
  Color(0xFFffe0bd),
  Color(0xFFe8c9a0),
  Color(0xFFd4a574),
  Color(0xFFc68642),
  Color(0xFF8d5524),
  Color(0xFF4a2912),
];
const _torsoColors = [
  Color(0xFF2a3344),
  Color(0xFF3a2020),
  Color(0xFF203020),
  Color(0xFF2a2040),
  Color(0xFF402020),
  Color(0xFF1a2a1a),
  Color(0xFF303030),
  Color(0xFF1a1a2a),
  Color(0xFF2a1a30),
  Color(0xFF1e2d1e),
  Color(0xFF2d1e1e),
  Color(0xFF1e1e2d),
];
const _legsColors = [
  Color(0xFF1a2233),
  Color(0xFF111111),
  Color(0xFF2a1a00),
  Color(0xFF1a2a1a),
  Color(0xFF252525),
  Color(0xFF1a1a35),
];
int _tidCounter = 1000;

CitizenData generateCitizen(
  Random rng, {
  bool forceSuspicious = false,
  int round = 1,
}) {
  final name =
      '${_firstNames[rng.nextInt(_firstNames.length)]} ${_lastNames[rng.nextInt(_lastNames.length)]}';
  final age = 18 + rng.nextInt(55);
  final skin = _skinTones[rng.nextInt(_skinTones.length)];
  final tid = _tidCounter++;
  if (forceSuspicious || rng.nextDouble() < 0.30)
    return _genDissident(rng, name, age, skin, tid, round);
  return _genInnocent(rng, name, age, skin, tid);
}

CitizenData _genInnocent(
  Random rng,
  String name,
  int age,
  Color skin,
  int tid,
) {
  final p = _jobs[rng.nextInt(_jobs.length)];
  final torso = _torsoColors[rng.nextInt(_torsoColors.length)];
  final legs = _legsColors[rng.nextInt(_legsColors.length)];
  final inv = List<String>.from(p.inv)..shuffle(rng);
  // 50% no hat, 50% random hat style
  final hat = rng.nextDouble() < 0.5
      ? HatStyle.none
      : HatStyle.values[rng.nextInt(3)]; // values 0-2 = cap/beanie/hood
  final body = BodyShape.values[rng.nextInt(BodyShape.values.length)];
  final acc = AccessoryType.values[rng.nextInt(AccessoryType.values.length)];
  return CitizenData(
    name: name,
    age: age,
    job: p.title,
    inventory: inv.take(2 + rng.nextInt(3)).toList(),
    isTrulySuspicious: false,
    systemHint: p.sh,
    trueReason: p.tr,
    falseHint: p.fh,
    behavior: BehaviorType.normal,
    clues: p.clues,
    skinColor: skin,
    torsoColor: torso,
    legsColor: legs,
    trackingId: tid,
    dissidentType: null,
    hatStyle: hat,
    bodyShape: body,
    accessory: acc,
  );
}

CitizenData _genDissident(
  Random rng,
  String name,
  int age,
  Color skin,
  int tid,
  int round,
) {
  final List<DissidentType> pool = [];
  pool.addAll(List.filled(round <= 3 ? 4 : 1, DissidentType.obvious));
  pool.addAll(List.filled(round >= 3 ? 3 : 1, DissidentType.master));
  pool.addAll(List.filled(2, DissidentType.decoy));
  pool.addAll(List.filled(round >= 4 ? 3 : 1, DissidentType.panicked));
  pool.addAll(List.filled(round >= 5 ? 4 : 1, DissidentType.disguised));
  pool.shuffle(rng);
  final type = pool.first;
  _DP p;
  switch (type) {
    case DissidentType.obvious:
      p = _obviousD[rng.nextInt(_obviousD.length)];
      break;
    case DissidentType.master:
      p = _masterD[rng.nextInt(_masterD.length)];
      break;
    case DissidentType.decoy:
      p = _decoyD[rng.nextInt(_decoyD.length)];
      break;
    case DissidentType.panicked:
      p = _panickedD[rng.nextInt(_panickedD.length)];
      break;
    case DissidentType.disguised:
      p = _disguisedD[rng.nextInt(_disguisedD.length)];
      break;
  }
  final isSusp = type != DissidentType.decoy;
  Color torso, legs;
  switch (type) {
    case DissidentType.obvious:
      torso = const Color(0xFF3a1515);
      legs = const Color(0xFF1a0a0a);
      break;
    case DissidentType.master:
      torso = const Color(0xFF2a3344);
      legs = const Color(0xFF1a2233);
      break;
    case DissidentType.decoy:
      torso = const Color(0xFF1a2a3a);
      legs = const Color(0xFF0a1a2a);
      break;
    case DissidentType.panicked:
      torso = const Color(0xFF2a2a15);
      legs = const Color(0xFF1a1a0a);
      break;
    case DissidentType.disguised:
      torso = _torsoColors[rng.nextInt(_torsoColors.length)];
      legs = _legsColors[rng.nextInt(_legsColors.length)];
      break;
  }
  // Dissidents get appearance based on type — subtle visual cues
  HatStyle hat;
  BodyShape body;
  AccessoryType acc;
  switch (type) {
    case DissidentType.obvious:
      hat = HatStyle.none;
      body = BodyShape.regular;
      acc = AccessoryType.bag;
      break;
    case DissidentType.master:
      hat = HatStyle.cap;
      body = BodyShape.slim;
      acc = AccessoryType.briefcase;
      break;
    case DissidentType.decoy:
      hat = HatStyle.values[rng.nextInt(HatStyle.values.length)];
      body = BodyShape.values[rng.nextInt(2)];
      acc = AccessoryType.none;
      break;
    case DissidentType.panicked:
      hat = HatStyle.hood;
      body = BodyShape.slim;
      acc = AccessoryType.backpack;
      break;
    case DissidentType.disguised:
      hat = HatStyle.values[rng.nextInt(HatStyle.values.length)];
      body = BodyShape.values[rng.nextInt(2)];
      acc = AccessoryType.values[rng.nextInt(AccessoryType.values.length)];
      break;
  }
  return CitizenData(
    name: name,
    age: age,
    job: p.job,
    inventory: p.inv,
    isTrulySuspicious: isSusp,
    systemHint: p.sh,
    trueReason: p.tr,
    falseHint: p.fh,
    behavior: p.beh,
    clues: p.clues,
    skinColor: skin,
    torsoColor: torso,
    legsColor: legs,
    trackingId: tid,
    dissidentType: type,
    hatStyle: hat,
    bodyShape: body,
    accessory: acc,
  );
}

// ─── JUICE ────────────────────────────────────────────────────────────────────

class JuiceState {
  double shakeAmount = 0, shakeDuration = 0;
  Offset shakeOffset = Offset.zero;
  Color flashColor = Colors.transparent;
  double flashOpacity = 0, flashDuration = 0;
  String stampText = '';
  Color stampColor = Colors.red;
  double stampOpacity = 0, stampDuration = 0, stampScale = 1.0;
  double flickerOpacity = 0.03,
      flickerTimer = 0,
      vignettePulse = 0,
      warningPulse = 0;
  double glitchTimer = 0;
  bool showGlitch = false;
  double glitchY = 0;
  double motionDetectedTimer = 0;
  bool signalLoss = false;
  double signalLossTimer = 0;
  double chromAberration = 0;
  double streakPulse = 0;
  final Random _rng = Random();
  void triggerFlag() {
    flashColor = const Color(0xFFff3355);
    flashOpacity = 0.25;
    flashDuration = 0.4;
    stampText = 'FLAGGED';
    stampColor = const Color(0xFFff3355);
    stampOpacity = 1.0;
    stampDuration = 1.2;
    stampScale = 1.5;
    vignettePulse = 1.0;
  }

  void triggerWrongFlag() {
    shakeAmount = 16.0;
    shakeDuration = 0.8;
    flashColor = const Color(0xFFff0000);
    flashOpacity = 0.55;
    flashDuration = 0.8;
    stampText = 'ERROR';
    stampColor = const Color(0xFFff0000);
    stampOpacity = 1.0;
    stampDuration = 1.8;
    stampScale = 2.2;
    vignettePulse = 1.0;
    chromAberration = 1.0;
  }

  void triggerCorrectClear() {
    flashColor = const Color(0xFF39ff6a);
    flashOpacity = 0.14;
    flashDuration = 0.3;
    stampText = 'CLEARED';
    stampColor = const Color(0xFF39ff6a);
    stampOpacity = 1.0;
    stampDuration = 0.9;
    stampScale = 1.2;
    streakPulse = 0.5;
  }

  void triggerCorrectFlag() {
    flashColor = const Color(0xFFffb347);
    flashOpacity = 0.18;
    flashDuration = 0.35;
    stampText = 'CONFIRMED';
    stampColor = const Color(0xFFffb347);
    stampOpacity = 1.0;
    stampDuration = 1.1;
    stampScale = 1.4;
    vignettePulse = 0.4;
  }

  void triggerCameraSwitch() {
    flashColor = Colors.white;
    flashOpacity = 0.15;
    flashDuration = 0.06;
    shakeAmount = 2.0;
    shakeDuration = 0.12;
    _staticBurst = true;
    _staticTimer = 0.1;
  }

  bool _staticBurst = false;
  double _staticTimer = 0;
  void triggerMotionDetected() {
    motionDetectedTimer = 2.0;
  }

  void triggerMultiplierUp() {
    flashColor = const Color(0xFFffff00);
    flashOpacity = 0.1;
    flashDuration = 0.3;
    stampText = 'MULTIPLIER UP!';
    stampColor = const Color(0xFFffff00);
    stampOpacity = 1.0;
    stampDuration = 1.4;
    stampScale = 1.4;
  }

  void triggerFleeWarning() {
    flashColor = const Color(0xFFff8800);
    flashOpacity = 0.2;
    flashDuration = 0.3;
    stampText = 'SUBJECT FLEEING!';
    stampColor = const Color(0xFFff8800);
    stampOpacity = 1.0;
    stampDuration = 1.0;
    stampScale = 1.3;
  }

  void update(double dt, double roundTimer) {
    if (shakeDuration > 0) {
      shakeDuration -= dt;
      final s = shakeAmount * (shakeDuration / 0.6).clamp(0.0, 1.0);
      shakeOffset = Offset(
        (_rng.nextDouble() - 0.5) * s,
        (_rng.nextDouble() - 0.5) * s,
      );
    } else {
      shakeOffset = Offset.zero;
      shakeAmount = 0;
    }
    if (flashDuration > 0) {
      flashDuration -= dt;
      flashOpacity = (flashOpacity - dt * 3.0).clamp(0.0, 0.5);
    }
    if (stampDuration > 0) {
      stampDuration -= dt;
      stampOpacity = (stampDuration / 1.5).clamp(0.0, 1.0);
      stampScale = (stampScale - dt * 0.6).clamp(1.0, 2.5);
    }
    flickerTimer -= dt;
    if (flickerTimer <= 0) {
      flickerTimer = 0.08 + _rng.nextDouble() * 0.35;
      flickerOpacity = 0.02 + _rng.nextDouble() * 0.05;
    }
    if (vignettePulse > 0)
      vignettePulse = (vignettePulse - dt * 2.0).clamp(0.0, 1.0);
    if (chromAberration > 0)
      chromAberration = (chromAberration - dt * 3.0).clamp(0.0, 1.0);
    if (streakPulse > 0) streakPulse = (streakPulse - dt * 2.5).clamp(0.0, 1.0);
    warningPulse = roundTimer < 10
        ? (sin(roundTimer * 5) * 0.5 + 0.5) * 0.9
        : 0;
    glitchTimer -= dt;
    if (glitchTimer <= 0) {
      glitchTimer = 0.8 + _rng.nextDouble() * 3;
      showGlitch = true;
      glitchY = _rng.nextDouble();
    }
    signalLossTimer -= dt;
    if (signalLossTimer <= 0) {
      signalLossTimer = 8 + _rng.nextDouble() * 15;
      signalLoss = true;
      Future.delayed(
        const Duration(milliseconds: 180),
        () => signalLoss = false,
      );
    }
    if (_staticBurst) {
      _staticTimer -= dt;
      if (_staticTimer <= 0) _staticBurst = false;
    }
    if (motionDetectedTimer > 0) motionDetectedTimer -= dt;
  }

  bool get showStaticBurst => _staticBurst;
}

// ─── QUEST SYSTEM ─────────────────────────────────────────────────────────────

enum QuestType {
  flagDissidents,
  clearInnocents,
  catchMaster,
  catchVIP,
  noMistakesRound,
  streakOf3,
}

class Quest {
  final QuestType type;
  final String title, description;
  final int target;
  int progress = 0;
  bool get completed => progress >= target;
  Quest({
    required this.type,
    required this.title,
    required this.description,
    required this.target,
  });
}

List<Quest> generateQuests(int round, int count) {
  final rng = Random(round * 13 + count);
  final hard = round >= 5;
  final all = [
    Quest(
      type: QuestType.flagDissidents,
      title: 'NEUTRALIZE THREATS',
      description: 'Correctly flag ${hard ? 4 : 2} dissidents',
      target: hard ? 4 : 2,
    ),
    Quest(
      type: QuestType.clearInnocents,
      title: 'PROTECT THE INNOCENT',
      description: 'Correctly clear ${hard ? 5 : 3} innocents',
      target: hard ? 5 : 3,
    ),
    Quest(
      type: QuestType.noMistakesRound,
      title: 'CLEAN OPERATION',
      description: 'Complete a full round with zero mistakes',
      target: 1,
    ),
    Quest(
      type: QuestType.streakOf3,
      title: 'TRIPLE LOCK',
      description: 'Make 3 correct decisions in a row',
      target: 3,
    ),
    Quest(
      type: QuestType.catchMaster,
      title: 'UNMASK THE GHOST',
      description: 'Identify a Master operative',
      target: 1,
    ),
    Quest(
      type: QuestType.catchVIP,
      title: 'HIGH VALUE TARGET',
      description: 'Flag the VIP target when they appear',
      target: 1,
    ),
    Quest(
      type: QuestType.flagDissidents,
      title: 'SWEEP THE SECTOR',
      description: 'Flag ${hard ? 6 : 3} total dissidents',
      target: hard ? 6 : 3,
    ),
  ];
  all.shuffle(rng);
  return all.take(count.clamp(1, 7)).toList();
}

// ─── EVENTS ───────────────────────────────────────────────────────────────────

enum EventType { tipOff, blackout, rewind, vipAlert }

class GameEvent {
  final EventType type;
  final String title, description;
  double timer = 0;
  bool active = false;
  String? targetId; // for tipOff — tracking ID of dissident
  GameEvent({
    required this.type,
    required this.title,
    required this.description,
  });
}

// ─── GAME ─────────────────────────────────────────────────────────────────────

class TheWatcherGame extends FlameGame {
  final List<String> cameraNames = [
    'CAM 01 — Market District',
    'CAM 02 — Residential Block',
    'CAM 03 — Transit Hub',
    'CAM 04 — Park & Commons',
  ];
  final List<Color> camColors = [
    const Color(0xFF061209),
    const Color(0xFF060a10),
    const Color(0xFF100606),
    const Color(0xFF0a0a04),
  ];
  final List<String> camIds = ['MKT-01', 'RES-02', 'TRN-03', 'PRK-04'];
  final List<Color> camTints = [
    const Color(0xFF00ff88),
    const Color(0xFF0088ff),
    const Color(0xFFff4422),
    const Color(0xFFdddd00),
  ];
  final _rng = Random();
  final juice = JuiceState();
  int currentCamera = 0,
      wrongFlags = 0,
      correctFlags = 0,
      totalDecisions = 0,
      round = 1,
      score = 0,
      streak = 0;
  bool isGameOver = false,
      isRoundIntro = false,
      isTitle = true,
      isPaused = false;
  int _prevMultiplier = 1;
  String gameOverReason = 'replaced'; // 'replaced' or 'timeout'

  // Quests
  List<Quest> quests = [];
  bool get allQuestsComplete =>
      quests.isNotEmpty && quests.every((q) => q.completed);
  int _roundMistakes = 0; // mistakes this round for CLEAN OPERATION quest

  // Events
  GameEvent? activeEvent;
  double _eventTimer = 0;
  bool _blackoutActive = false;
  bool _vipSpawned = false;
  CitizenData? vipTarget;
  bool get blackoutActive => _blackoutActive;
  String? tipOffTargetId; // tracking ID highlighted by tip-off

  // Round configs — 3 rounds per run, progressively harder
  List<DifficultyConfig> roundConfigs = [];
  Set<int> completedRounds = {}; // rounds that have been cleared
  DifficultyConfig get difficulty =>
      roundConfigs.isNotEmpty && round <= roundConfigs.length
      ? roundConfigs[round - 1]
      : getDifficulty(round);
  int get totalRounds => roundConfigs.isNotEmpty ? roundConfigs.length : 3;
  bool get isLastRound => round >= totalRounds;
  // Custom difficulty override for custom mode
  DifficultyConfig? customDifficulty;
  String currentPreset = 'normal';
  String get nextPreset {
    const order = ['easy', 'normal', 'hard', 'expert'];
    final i = order.indexOf(currentPreset);
    return i >= 0 && i < order.length - 1 ? order[i + 1] : currentPreset;
  }

  bool get isMaxPreset =>
      currentPreset == 'expert' || currentPreset == 'custom';
  double get roundDuration => difficulty.roundDuration;
  double roundTimer = 40.0;
  bool roundActive = false;
  List<CitizenComponent> citizens = [];
  CitizenData? selectedCitizen;
  CitizenComponent? selectedComponent;
  double get accuracy => totalDecisions == 0
      ? 100.0
      : ((totalDecisions - wrongFlags) / totalDecisions * 100);
  int get scoreMultiplier => difficulty.scoreMultiplier;

  // Map state
  final List<MapBackground?> _maps = [null, null, null, null];

  @override
  Color backgroundColor() => const Color(0xFF060608);

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    SoundEngine.stopMusic();
    overlays.add('Title');
  }

  @override
  void update(double dt) {
    super.update(dt);
    juice.update(dt, roundTimer);
    if (!roundActive || isGameOver || isRoundIntro || isPaused) return;
    roundTimer -= dt;
    if (roundTimer <= 0) _nextRound();
    // timer warning tick under 10s
    if (roundTimer < 10 && roundTimer > 0) {
      final prev = roundTimer + dt;
      if (prev.floor() != roundTimer.floor()) SoundEngine.timerTick();
    }
    // Event scheduling — trigger a random event once per round between 30-60% of round time
    if (activeEvent == null && roundActive) {
      _eventTimer += dt;
      final triggerAt = roundDuration * 0.35;
      if (_eventTimer >= triggerAt && round >= 2) {
        _eventTimer = 0;
        _triggerRandomEvent();
      }
    }
    // Blackout countdown
    if (_blackoutActive) {
      _eventTimer += dt;
      if (_eventTimer >= 3.0) {
        _blackoutActive = false;
        _eventTimer = 0;
        overlays.remove('Event');
      }
    }
  }

  void _ensureMap(int camIndex) {
    if (_maps[camIndex] != null) return;
    final sw = size.x;
    final sh = size.y;
    List<MapPixel> pixels;
    switch (camIndex) {
      case 0:
        pixels = buildMarketMap(sw, sh);
        break;
      case 1:
        pixels = buildResidentialMap(sw, sh);
        break;
      case 2:
        pixels = buildTransitMap(sw, sh);
        break;
      default:
        pixels = buildParkMap(sw, sh);
        break;
    }
    final map = MapBackground(pixels: pixels);
    map.priority = -10;
    _maps[camIndex] = map;
  }

  void _mountCurrentMap() {
    _ensureMap(currentCamera);
    final map = _maps[currentCamera]!;
    if (!map.isMounted) add(map);
  }

  void _showRoundIntro() {
    isRoundIntro = true;
    overlays.remove('HUD');
    overlays.remove('Juice');
    overlays.add('RoundIntro');
    Future.delayed(const Duration(milliseconds: 2400), _startRound);
  }

  void _startRound() {
    isRoundIntro = false;
    overlays.remove('RoundIntro');
    overlays.add('HUD');
    overlays.add('Juice');
    roundTimer = difficulty.roundDuration;
    roundActive = true;
    _roundMistakes = 0;
    _eventTimer = 0;
    activeEvent = null;
    _vipSpawned = false;
    tipOffTargetId = null;
    if (round == 1) quests = generateQuests(round, difficulty.questCount);
    _mountCurrentMap();
    _spawnCitizens();
    if (round == 1) SoundEngine.playGameMusic();
    if (difficulty.scoreMultiplier > _prevMultiplier) {
      juice.triggerMultiplierUp();
      _prevMultiplier = difficulty.scoreMultiplier;
    }
  }

  void _spawnCitizens() {
    for (final c in citizens) c.removeFromParent();
    citizens.clear();
    final count = difficulty.citizenCount + _rng.nextInt(2);
    final List<CitizenData> generated = [];
    bool addedSuspicious = false;
    for (int i = 0; i < count; i++) {
      final force = round > 1 && !addedSuspicious && i == count - 1;
      final data = generateCitizen(_rng, forceSuspicious: force, round: round);
      if (data.isTrulySuspicious) addedSuspicious = true;
      generated.add(data);
    }
    generated.shuffle(_rng);
    for (int i = 0; i < generated.length; i++) {
      final spawnW = (size.x - 240).clamp(100.0, size.x - 100);
      final spawnH = (size.y - 280).clamp(80.0, size.y - 160);
      final c = CitizenComponent(
        data: generated[i],
        startPos: Vector2(
          120 + _rng.nextDouble() * spawnW,
          160 + _rng.nextDouble() * spawnH,
        ),
        game: this,
        spawnDelay: i * difficulty.spawnDelay,
        speedOverride: difficulty.citizenSpeed,
      );
      add(c);
      citizens.add(c);
    }
    juice.triggerMotionDetected();
    SoundEngine.spawn();
  }

  void switchCamera(int index) {
    if (index == currentCamera) return;
    if (_maps[currentCamera] != null && _maps[currentCamera]!.isMounted) {
      _maps[currentCamera]!.removeFromParent();
    }
    juice.triggerCameraSwitch();
    SoundEngine.cameraSwitch();
    currentCamera = index;
    selectedCitizen = null;
    selectedComponent = null;
    overlays.remove('Profile');
    _mountCurrentMap();
    // snap any out-of-bounds citizens back into the visible area
    for (final c in citizens) c.snapIntoBounds();
  }

  // Manual camera switch from HUD buttons — respawns citizens for that camera
  void manualSwitchCamera(int index) {
    if (index == currentCamera) return;
    if (completedRounds.contains(index)) return;
    for (final c in citizens) c.removeFromParent();
    citizens.clear();
    switchCamera(index);
    // reset timer and event state for the new camera
    roundTimer = difficulty.roundDuration;
    _eventTimer = 0;
    activeEvent = null;
    if (overlays.isActive('Event')) overlays.remove('Event');
    _spawnCitizens();
  }

  void selectCitizen(CitizenData data, CitizenComponent comp) {
    selectedComponent?.deselect();
    selectedCitizen = data;
    selectedComponent = comp;
    SoundEngine.dossierOpen();
    overlays.remove('Profile');
    overlays.add('Profile');
  }

  void closeProfile() {
    selectedCitizen = null;
    selectedComponent?.deselect();
    selectedComponent = null;
    overlays.remove('Profile');
  }

  void onCitizenFled(CitizenComponent comp) {
    juice.triggerFleeWarning();
    citizens.remove(comp);
    comp.removeFromParent();
    if (selectedComponent == comp) closeProfile();
  }

  void makeDecision(CitizenData data, bool flagAsSuspicious) {
    totalDecisions++;
    final isVip = data == vipTarget;
    final mult = isVip ? 3 : scoreMultiplier;
    if (flagAsSuspicious) {
      if (data.isTrulySuspicious) {
        correctFlags++;
        streak++;
        score += 100 * mult + (streak > 2 ? (streak - 2) * 25 : 0);
        juice.triggerCorrectFlag();
        SoundEngine.flag();
        _updateQuests(
          flagged: true,
          correct: true,
          dtype: data.dissidentType,
          isVip: isVip,
        );
      } else {
        wrongFlags++;
        streak = 0;
        _roundMistakes++;
        score -= 50;
        juice.triggerWrongFlag();
        SoundEngine.wrong();
        _updateQuests(flagged: true, correct: false, mistake: true);
      }
    } else {
      if (data.isTrulySuspicious) {
        wrongFlags++;
        streak = 0;
        _roundMistakes++;
        score -= 30;
        juice.triggerWrongFlag();
        SoundEngine.wrong();
        _updateQuests(cleared: false, correct: false, mistake: true);
      } else {
        streak++;
        score += 20 * scoreMultiplier;
        juice.triggerCorrectClear();
        SoundEngine.clear();
        _updateQuests(cleared: true, correct: true);
      }
    }
    if (isVip) vipTarget = null;
    closeProfile();
    if (wrongFlags >= maxWrongFlags) {
      _triggerGameOver();
      return;
    }
    // trigger death animation — keep in citizens list until anim done
    final comp = citizens.firstWhere(
      (c) => c.data == data,
      orElse: () => throw StateError('missing'),
    );
    comp.triggerDeath(flagged: flagAsSuspicious);
    Future.delayed(const Duration(milliseconds: 700), () {
      if (comp.isMounted) comp.removeFromParent();
      citizens.remove(comp);
      if (!isGameOver) checkRoundComplete();
    });
  }

  void _triggerRandomEvent() {
    if (_blackoutActive) return;
    final types = [
      EventType.tipOff,
      EventType.blackout,
      EventType.rewind,
      EventType.vipAlert,
    ];
    final type = types[_rng.nextInt(types.length)];
    switch (type) {
      case EventType.tipOff:
        // Find a real dissident on screen
        final dissidents = citizens
            .where((c) => c.data.isTrulySuspicious)
            .toList();
        if (dissidents.isEmpty) return;
        final target = dissidents[_rng.nextInt(dissidents.length)];
        tipOffTargetId = '${target.data.trackingId}';
        activeEvent = GameEvent(
          type: EventType.tipOff,
          title: 'INCOMING TIP-OFF',
          description:
              'Intelligence has flagged one subject. Tracking ID highlighted for 4 seconds.',
        );
        overlays.add('Event');
        Future.delayed(const Duration(seconds: 4), () {
          tipOffTargetId = null;
          activeEvent = null;
          if (overlays.isActive('Event')) overlays.remove('Event');
        });
        break;
      case EventType.blackout:
        SoundEngine.signalLoss();
        _blackoutActive = true;
        _eventTimer = 0;
        activeEvent = GameEvent(
          type: EventType.blackout,
          title: 'SIGNAL LOST',
          description: 'Camera feed interrupted. Restoring in 3 seconds.',
        );
        overlays.add('Event');
        break;
      case EventType.rewind:
        // Reset all revealed clues by rebuilding citizens (keep same data, reset watch time in profile)
        activeEvent = GameEvent(
          type: EventType.rewind,
          title: 'SYSTEM REWIND',
          description:
              'Intelligence database purged. All behavioral data lost.',
        );
        overlays.add('Event');
        Future.delayed(const Duration(seconds: 2), () {
          activeEvent = null;
          if (overlays.isActive('Event')) overlays.remove('Event');
        });
        break;
      case EventType.vipAlert:
        if (_vipSpawned) return;
        _vipSpawned = true;
        final vipData = _generateVIP();
        vipTarget = vipData;
        final c = CitizenComponent(
          data: vipData,
          startPos: Vector2(
            120 + _rng.nextDouble() * (size.x - 240),
            160 + _rng.nextDouble() * (size.y - 280),
          ),
          game: this,
          spawnDelay: 0,
          speedOverride: difficulty.citizenSpeed * 0.7,
        );
        add(c);
        citizens.add(c);
        activeEvent = GameEvent(
          type: EventType.vipAlert,
          title: 'VIP TARGET ACQUIRED',
          description:
              'High-value target has entered the area. Flag for 3× bonus points.',
        );
        overlays.add('Event');
        Future.delayed(const Duration(seconds: 3), () {
          activeEvent = null;
          if (overlays.isActive('Event')) overlays.remove('Event');
        });
        break;
    }
  }

  CitizenData _generateVIP() {
    final name =
        '${_firstNames[_rng.nextInt(_firstNames.length)]} ${_lastNames[_rng.nextInt(_lastNames.length)]}';
    final skin = _skinTones[_rng.nextInt(_skinTones.length)];
    return CitizenData(
      name: name,
      age: 35 + _rng.nextInt(20),
      job: 'Unknown — High Value',
      inventory: [
        'Encrypted device',
        'Classified documents',
        'Fake credentials',
      ],
      isTrulySuspicious: true,
      systemHint:
          '⭐ VIP TARGET — High-value operative. Flag for triple score bonus.',
      trueReason: 'Senior operative. Extremely high value target.',
      falseHint:
          'Subject may have diplomatic immunity. Verify before flagging.',
      behavior: BehaviorType.normal,
      clues: [
        'Moves with unusual confidence — no nervousness.',
        'Makes brief eye contact with multiple strangers.',
        'Checks encrypted device — one-time pad visible.',
      ],
      skinColor: skin,
      torsoColor: const Color(0xFF1a1030),
      legsColor: const Color(0xFF0a0820),
      trackingId: _tidCounter++,
      dissidentType: DissidentType.master,
    );
  }

  void _updateQuests({
    bool flagged = false,
    bool cleared = false,
    bool correct = false,
    bool mistake = false,
    DissidentType? dtype,
    bool isVip = false,
  }) {
    for (final q in quests) {
      if (q.completed) continue;
      switch (q.type) {
        case QuestType.flagDissidents:
          if (flagged && correct) q.progress++;
          break;
        case QuestType.clearInnocents:
          if (cleared && correct) q.progress++;
          break;
        case QuestType.noMistakesRound:
          break; // handled in _nextRound
        case QuestType.streakOf3:
          q.progress = streak >= 3 ? 3 : streak;
          break;
        case QuestType.catchMaster:
          if (flagged && correct && dtype == DissidentType.master) q.progress++;
          break;
        case QuestType.catchVIP:
          if (flagged && correct && isVip) q.progress++;
          break;
      }
    }
    if (allQuestsComplete) {
      // let checkRoundComplete handle victory — don't trigger here mid-decision
    }
  }

  void _nextRound() {
    // Time ran out — TIMEOUT game over
    juice.triggerWrongFlag();
    Future.delayed(const Duration(milliseconds: 400), _triggerTimeoutGameOver);
  }

  void _triggerTimeoutGameOver() {
    isGameOver = true;
    roundActive = false;
    gameOverReason = 'timeout';
    overlays.remove('HUD');
    overlays.remove('Profile');
    overlays.remove('Juice');
    overlays.remove('RoundIntro');
    overlays.remove('Event');
    overlays.add('GameOver');
  }

  void checkRoundComplete() {
    if (!roundActive || isGameOver) return;
    // citizens are only removed from the list AFTER their death animation completes
    // so if citizens list is non-empty, some are still animating — wait for them
    if (citizens.isNotEmpty) return;
    completedRounds.add(currentCamera);
    for (final q in quests) {
      if (q.type == QuestType.noMistakesRound &&
          !q.completed &&
          _roundMistakes == 0)
        q.progress = 1;
    }
    if (completedRounds.length >= cameraNames.length) {
      _triggerVictory();
      return;
    }
    if (allQuestsComplete) {
      _triggerVictory();
      return;
    }
    round++;
    roundActive = false;
    int nextCam = (currentCamera + 1) % cameraNames.length;
    while (completedRounds.contains(nextCam))
      nextCam = (nextCam + 1) % cameraNames.length;
    Future.delayed(const Duration(milliseconds: 600), () {
      switchCamera(nextCam);
      _showRoundIntro();
    });
  }

  void _triggerVictory() {
    score += 500;
    roundActive = false;
    SoundEngine.victory();
    SoundEngine.stopMusic();
    overlays.remove('HUD');
    overlays.remove('Profile');
    overlays.remove('Juice');
    overlays.remove('RoundIntro');
    overlays.remove('Event');
    overlays.add('Victory');
  }

  void _triggerGameOver() {
    isGameOver = true;
    roundActive = false;
    gameOverReason = 'replaced';
    SoundEngine.gameOver();
    SoundEngine.stopMusic();
    overlays.remove('HUD');
    overlays.remove('Profile');
    overlays.remove('Juice');
    overlays.remove('RoundIntro');
    overlays.add('GameOver');
  }

  void startGame(
    DifficultyConfig? custom, {
    String preset = 'normal',
    List<DifficultyConfig>? configs,
  }) {
    roundConfigs =
        configs ??
        (custom != null
            ? List.filled(4, custom)
            : generateRoundConfigs(preset));
    customDifficulty = custom;
    currentPreset = preset;
    isTitle = false;
    wrongFlags = 0;
    correctFlags = 0;
    totalDecisions = 0;
    round = 1;
    score = 0;
    streak = 0;
    isGameOver = false;
    roundActive = false;
    isRoundIntro = false;
    _prevMultiplier = 1;
    quests = [];
    _roundMistakes = 0;
    activeEvent = null;
    _vipSpawned = false;
    tipOffTargetId = null;
    vipTarget = null;
    completedRounds = {};
    gameOverReason = 'replaced';
    currentCamera = 0;
    selectedCitizen = null;
    selectedComponent = null;
    for (final c in citizens) c.removeFromParent();
    citizens.clear();
    for (int i = 0; i < _maps.length; i++) {
      if (_maps[i] != null && _maps[i]!.isMounted) _maps[i]!.removeFromParent();
      _maps[i] = null;
    }
    overlays.remove('Victory');
    overlays.remove('GameOver');
    overlays.remove('Title');
    overlays.remove('HUD');
    overlays.remove('Juice');
    overlays.remove('Profile');
    overlays.remove('RoundIntro');
    overlays.remove('Event');
    roundTimer = difficulty.roundDuration;
    _showRoundIntro();
  }

  void restart() {
    if (currentPreset != 'custom')
      roundConfigs = generateRoundConfigs(currentPreset);
    wrongFlags = 0;
    correctFlags = 0;
    totalDecisions = 0;
    round = 1;
    score = 0;
    streak = 0;
    isGameOver = false;
    roundActive = false;
    isRoundIntro = false;
    _prevMultiplier = 1;
    quests = [];
    _roundMistakes = 0;
    activeEvent = null;
    _vipSpawned = false;
    tipOffTargetId = null;
    vipTarget = null;
    completedRounds = {};
    gameOverReason = 'replaced';
    currentCamera = 0;
    selectedCitizen = null;
    selectedComponent = null;
    for (final c in citizens) c.removeFromParent();
    citizens.clear();
    for (int i = 0; i < _maps.length; i++) {
      if (_maps[i] != null && _maps[i]!.isMounted) _maps[i]!.removeFromParent();
      _maps[i] = null;
    }
    overlays.remove('GameOver');
    overlays.remove('Victory');
    SoundEngine.stopMusic();
    _showRoundIntro();
  }

  void returnToTitle() {
    isTitle = true;
    isGameOver = false;
    roundActive = false;
    gameOverReason = 'replaced';
    quests = [];
    _roundMistakes = 0;
    activeEvent = null;
    _vipSpawned = false;
    tipOffTargetId = null;
    vipTarget = null;
    for (final c in citizens) c.removeFromParent();
    citizens.clear();
    for (int i = 0; i < _maps.length; i++) {
      if (_maps[i] != null && _maps[i]!.isMounted) _maps[i]!.removeFromParent();
      _maps[i] = null;
    }
    overlays.remove('GameOver');
    overlays.remove('Victory');
    overlays.remove('HUD');
    overlays.remove('Juice');
    overlays.remove('Profile');
    overlays.remove('RoundIntro');
    overlays.remove('Event');
    SoundEngine.stopMusic();
    overlays.add('Title');
  }

  static const int maxWrongFlags = 3;
}

// ─── CITIZEN COMPONENT ────────────────────────────────────────────────────────

class CitizenComponent extends PositionComponent
    with TapCallbacks, HasGameRef<TheWatcherGame> {
  final CitizenData data;
  final TheWatcherGame game;
  final double spawnDelay, speedOverride;
  Vector2 velocity = Vector2.zero();
  double _dirTimer = 0, _behaviorTimer = 0, _behaviorDuration = 0;
  bool _selected = false,
      _spawned = false,
      _doingBehavior = false,
      _fleeing = false,
      _fleeTriggered = false;
  double _spawnProgress = 0,
      _elapsed = 0,
      _reticleScale = 1.0,
      _fleeTimer = 0,
      _obviousTimer = 0;
  // Death animation
  bool _dying = false;
  double _deathTimer = 0;
  Color _deathColor = Colors.red;
  bool _deathFlag = false;
  String _currentAction = '';
  final List<_Pixel> _pixels = [];
  static final Random _rng = Random();
  static const double _fleeThreshold = 7.0;

  CitizenComponent({
    required this.data,
    required Vector2 startPos,
    required this.game,
    this.spawnDelay = 0,
    this.speedOverride = 38,
  }) : super(position: startPos, size: Vector2(32, 56), anchor: Anchor.center);

  void triggerDeath({required bool flagged}) {
    _dying = true;
    _deathTimer = 0.7;
    _deathFlag = flagged;
    _deathColor = flagged ? const Color(0xFFff3355) : const Color(0xFF39ff6a);
    velocity = Vector2.zero();
  }

  @override
  Future<void> onLoad() async {
    _generatePixels();
    _pickDirection();
  }

  void _generatePixels() {
    final hatColor = Color.lerp(data.torsoColor, Colors.black, 0.4)!;
    final skin = data.skinColor;
    final torso = data.torsoColor;
    final legs = data.legsColor;
    final shoe = Color.lerp(legs, Colors.black, 0.5)!;
    // Dissidents: slightly darker/redder torso tint as subtle cue
    final bodyColor =
        data.isTrulySuspicious && data.dissidentType != DissidentType.decoy
        ? Color.lerp(torso, const Color(0xFF220000), 0.18)!
        : torso;
    final slim = data.bodyShape == BodyShape.slim;

    void px(int c, int r, Color col) {
      _pixels.add(
        _Pixel(col: c, row: r, color: col, delay: _rng.nextDouble() * 0.85),
      );
    }

    // ── HAT ──────────────────────────────────────────────────────────────────
    switch (data.hatStyle) {
      case HatStyle.cap:
        // baseball cap — brim sticks out front
        for (int c = 3; c <= 6; c++) {
          px(c, 0, hatColor);
          px(c, 1, hatColor);
        }
        px(2, 1, hatColor);
        px(7, 1, hatColor);
        px(2, 2, hatColor); // brim
        break;
      case HatStyle.beanie:
        // tight beanie — rounder, sits high
        for (int c = 3; c <= 6; c++) px(c, 0, hatColor);
        for (int c = 2; c <= 7; c++) px(c, 1, hatColor);
        break;
      case HatStyle.hood:
        // hood — wraps around head sides
        for (int c = 3; c <= 6; c++) {
          px(c, 0, hatColor);
          px(c, 1, hatColor);
        }
        px(2, 1, hatColor);
        px(7, 1, hatColor);
        px(2, 2, hatColor);
        px(7, 2, hatColor); // hood sides extend down
        px(2, 3, hatColor);
        px(7, 3, hatColor);
        break;
      case HatStyle.none:
        // visible hair — pick from natural hair colors
        final hairColors = [
          const Color(0xFF1a0e00),
          const Color(0xFF3d2b1f),
          const Color(0xFF6b4c11),
          const Color(0xFFc8a050),
          const Color(0xFF888888),
          const Color(0xFF111111),
        ];
        final hair = hairColors[_rng.nextInt(hairColors.length)];
        for (int c = 3; c <= 6; c++) {
          px(c, 0, hair);
          px(c, 1, hair);
        }
        px(2, 1, hair);
        px(7, 1, hair); // wider hair sides
        break;
    }

    // ── HEAD ─────────────────────────────────────────────────────────────────
    for (int c = 3; c <= 6; c++) for (int r = 2; r <= 4; r++) px(c, r, skin);
    px(3, 3, const Color(0xFF111122)); // left eye
    px(6, 3, const Color(0xFF111122)); // right eye
    px(4, 4, Color.lerp(skin, Colors.black, 0.28)!); // mouth

    // ── NECK ─────────────────────────────────────────────────────────────────
    px(4, 5, skin);
    px(5, 5, skin);

    // ── TORSO ────────────────────────────────────────────────────────────────
    final torsoW = slim ? [3, 4, 5, 6] : [2, 3, 4, 5, 6, 7];
    for (final c in torsoW) for (int r = 6; r <= 9; r++) px(c, r, bodyColor);
    // belt
    for (final c in torsoW)
      px(c, 10, Color.lerp(bodyColor, Colors.black, 0.35)!);

    // ── ARMS ─────────────────────────────────────────────────────────────────
    for (int r = 6; r <= 10; r++) {
      px(1, r, bodyColor);
      px(8, r, bodyColor);
    }
    px(1, 11, skin);
    px(8, 11, skin); // hands

    // ── LEGS ─────────────────────────────────────────────────────────────────
    for (int r = 11; r <= 15; r++) {
      px(3, r, legs);
      px(4, r, Color.lerp(legs, Colors.black, 0.25)!); // left leg shading
      px(5, r, Color.lerp(legs, Colors.black, 0.25)!);
      px(6, r, legs); // right leg shading
    }

    // ── SHOES ────────────────────────────────────────────────────────────────
    for (int c = 2; c <= 4; c++) px(c, 16, shoe);
    for (int c = 5; c <= 7; c++) px(c, 16, shoe);
    px(2, 17, shoe);
    px(3, 17, shoe);
    px(5, 17, shoe);
    px(6, 17, shoe);
    px(7, 17, shoe);

    // ── ACCESSORY ────────────────────────────────────────────────────────────
    final accColor = Color.lerp(legs, Colors.black, 0.2)!;
    switch (data.accessory) {
      case AccessoryType.bag:
        // shoulder bag — hangs on left arm side
        for (int r = 8; r <= 11; r++) px(0, r, accColor);
        px(0, 7, accColor);
        px(0, 12, accColor);
        break;
      case AccessoryType.backpack:
        // backpack — on the back (rendered behind torso, slightly sticking out right)
        for (int r = 7; r <= 11; r++)
          px(9, r, Color.lerp(accColor, const Color(0xFF223344), 0.5)!);
        px(9, 6, Color.lerp(accColor, const Color(0xFF223344), 0.5)!);
        break;
      case AccessoryType.briefcase:
        // briefcase — held in right hand
        for (int r = 12; r <= 14; r++)
          px(9, r, Color.lerp(accColor, const Color(0xFF1a1000), 0.3)!);
        px(9, 11, Color.lerp(accColor, const Color(0xFF1a1000), 0.3)!);
        break;
      case AccessoryType.none:
        break;
    }

    _pixels.shuffle(_rng);
  }

  Color _pc(int r) {
    if (r <= 2) return data.skinColor;
    if (r >= 9) return data.legsColor;
    return data.torsoColor;
  }

  void _pickDirection() {
    if (_fleeing) {
      final b = game.size;
      final edges = [
        Vector2(0, position.y),
        Vector2(b.x, position.y),
        Vector2(position.x, 0),
        Vector2(position.x, b.y),
      ];
      edges.sort(
        (a, z) => (a - position).length.compareTo((z - position).length),
      );
      velocity = (edges.first - position).normalized() * (speedOverride * 2.2);
      return;
    }
    final a = _rng.nextDouble() * 2 * pi;
    velocity = Vector2(cos(a), sin(a)) * speedOverride;
    if (data.behavior == BehaviorType.secretive ||
        data.behavior == BehaviorType.suspicious)
      velocity *= 0.55;
    _dirTimer = 1.5 + _rng.nextDouble() * 2.5;
  }

  void _triggerBehavior() {
    if (_doingBehavior) return;
    _doingBehavior = true;
    _behaviorDuration = 1.5 + _rng.nextDouble() * 2.0;
    velocity = Vector2.zero();
    switch (data.behavior) {
      case BehaviorType.nervous:
        _currentAction = '👀';
        break;
      case BehaviorType.suspicious:
        _currentAction = '📦';
        break;
      case BehaviorType.secretive:
        _currentAction = '📻';
        break;
      default:
        _currentAction = '';
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    _elapsed += dt;
    if (_elapsed < spawnDelay) return;
    if (!_spawned) {
      _spawnProgress += dt * 1.6;
      if (_spawnProgress >= 1.0) {
        _spawnProgress = 1.0;
        _spawned = true;
      }
      return;
    }
    // death animation
    if (_dying) {
      _deathTimer -= dt;
      if (_deathTimer <= 0) removeFromParent();
      return;
    }
    if (_selected) _reticleScale = 1.0 + sin(_elapsed * 4) * 0.08;
    if (data.dissidentType == DissidentType.panicked && _selected) {
      _fleeTimer += dt;
      if (_fleeTimer >= _fleeThreshold && !_fleeTriggered) {
        _fleeTriggered = true;
        _fleeing = true;
        _pickDirection();
        SoundEngine.flee();
      }
    }
    if (_fleeing) {
      position += velocity * dt;
      final b = game.size;
      if (position.x < -60 ||
          position.x > b.x + 60 ||
          position.y < -60 ||
          position.y > b.y + 60) {
        game.onCitizenFled(this);
        return;
      }
      return;
    }
    if (data.dissidentType == DissidentType.obvious) {
      _obviousTimer -= dt;
      if (_obviousTimer <= 0) {
        _obviousTimer = 1.5 + _rng.nextDouble() * 1.5;
        _triggerBehavior();
      }
    } else {
      _behaviorTimer -= dt;
      if (_behaviorTimer <= 0) {
        _behaviorTimer = 2.5 + _rng.nextDouble() * 3.5;
        if (data.behavior != BehaviorType.normal) _triggerBehavior();
      }
    }
    if (_doingBehavior) {
      _behaviorDuration -= dt;
      if (_behaviorDuration <= 0) {
        _doingBehavior = false;
        _currentAction = '';
        _pickDirection();
      }
      return;
    }
    _dirTimer -= dt;
    if (_dirTimer <= 0) _pickDirection();
    position += velocity * dt;
    final b = game.size;
    // strict bounds — keep citizens in the visible camera area only
    const double xMin = 50, xMax_pad = 50, yMin = 140.0, yMax_pad = 80.0;
    if (position.x < xMin || position.x > b.x - xMax_pad) {
      velocity.x *= -1;
      position.x = position.x.clamp(xMin, b.x - xMax_pad);
    }
    if (position.y < yMin || position.y > b.y - yMax_pad) {
      velocity.y *= -1;
      position.y = position.y.clamp(yMin, b.y - yMax_pad);
    }
  }

  void snapIntoBounds() {
    final b = game.size;
    position.x = position.x.clamp(80.0, b.x - 80.0);
    position.y = position.y.clamp(150.0, b.y - 90.0);
    _pickDirection();
  }

  @override
  void render(Canvas canvas) {
    if (_elapsed < spawnDelay) return;
    const pw = 3.0, ph = 3.0;

    // idle bob — gentle vertical offset
    final bob = _spawned && !_dying && !_fleeing
        ? sin(_elapsed * 2.2 + (data.trackingId * 0.7)) * 1.2
        : 0.0;

    // death: dissolve + color tint
    final deathFrac = _dying ? (1.0 - _deathTimer / 0.7).clamp(0.0, 1.0) : 0.0;
    final deathAlpha = _dying ? (1.0 - deathFrac * 1.1).clamp(0.0, 1.0) : 1.0;

    // shadow — ellipse on the ground below citizen
    if (_spawned && !_dying) {
      final shadowAlpha = 0.18 * (1.0 - deathFrac);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(size.x / 2, size.y + 2),
          width: size.x * 0.9,
          height: 6,
        ),
        Paint()..color = Colors.black.withOpacity(shadowAlpha),
      );
    }

    canvas.save();
    canvas.translate(0, bob);

    for (final px in _pixels) {
      final t = ((_spawnProgress - px.delay) / 0.25).clamp(0.0, 1.0);
      if (t <= 0) continue;
      Color col = px.color;
      if (_dying) col = Color.lerp(col, _deathColor, deathFrac * 0.7)!;
      final a = t * (_selected ? 1.0 : 0.85) * deathAlpha;
      // scatter pixels on death
      double dx = 0, dy = 0;
      if (_dying && deathFrac > 0.3) {
        final seed = (px.col * 31 + px.row * 17) % 100;
        dx = sin(seed.toDouble() + _elapsed * 8) * deathFrac * 6;
        dy =
            cos(seed.toDouble() + _elapsed * 6) * deathFrac * 5 - deathFrac * 4;
      }
      canvas.drawRect(
        Rect.fromLTWH(px.col * pw + dx, px.row * ph + dy, pw - 0.3, ph - 0.3),
        Paint()..color = col.withOpacity(a),
      );
    }

    // death stamp — X or ✓ drawn over citizen
    if (_dying && deathFrac > 0.1) {
      final stampPaint = Paint()
        ..color = _deathColor.withOpacity(
          (1.0 - deathFrac).clamp(0.0, 1.0) * 0.9,
        )
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      final cx = size.x / 2, cy = size.y / 2 - bob;
      if (_deathFlag) {
        // red X
        canvas.drawLine(
          Offset(cx - 10, cy - 10),
          Offset(cx + 10, cy + 10),
          stampPaint,
        );
        canvas.drawLine(
          Offset(cx + 10, cy - 10),
          Offset(cx - 10, cy + 10),
          stampPaint,
        );
      } else {
        // green checkmark
        canvas.drawLine(
          Offset(cx - 10, cy),
          Offset(cx - 3, cy + 8),
          stampPaint,
        );
        canvas.drawLine(
          Offset(cx - 3, cy + 8),
          Offset(cx + 10, cy - 8),
          stampPaint,
        );
      }
    }

    canvas.restore();

    if (_selected && _spawned && !_dying) {
      final cx = size.x / 2, cy = size.y / 2;
      final r = (size.x * 0.9) * _reticleScale;
      Color rc = const Color(0xFFff4d00);
      if (data.dissidentType == DissidentType.master)
        rc = const Color(0xFF6688ff);
      if (data.dissidentType == DissidentType.decoy)
        rc = const Color(0xFFffff00);
      if (data.dissidentType == DissidentType.panicked)
        rc = const Color(0xFFff8800);
      if (data.dissidentType == DissidentType.disguised)
        rc = const Color(0xFF88ff88);
      final paint = Paint()
        ..color = rc.withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      final corners = [
        Offset(cx - r, cy - r),
        Offset(cx + r, cy - r),
        Offset(cx + r, cy + r),
        Offset(cx - r, cy + r),
      ];
      for (int i = 0; i < 4; i++) {
        final ox = corners[i].dx, oy = corners[i].dy;
        final xs = (i == 0 || i == 3) ? 1.0 : -1.0;
        final ys = i < 2 ? 1.0 : -1.0;
        canvas.drawLine(Offset(ox, oy), Offset(ox + xs * 7, oy), paint);
        canvas.drawLine(Offset(ox, oy), Offset(ox, oy + ys * 7), paint);
      }
      canvas.drawCircle(
        Offset(cx, cy),
        2,
        Paint()..color = rc.withOpacity(0.7),
      );
      if (data.dissidentType == DissidentType.panicked && !_fleeTriggered) {
        final frac = (_fleeTimer / _fleeThreshold).clamp(0.0, 1.0);
        canvas.drawRect(
          Rect.fromLTWH(0, size.y + 6, size.x, 4),
          Paint()..color = Colors.black.withOpacity(0.5),
        );
        canvas.drawRect(
          Rect.fromLTWH(0, size.y + 6, size.x * frac, 4),
          Paint()..color = const Color(0xFFff8800).withOpacity(0.8),
        );
      }
    }
    if (_spawned && !_dying) {
      final isTipOff = game.tipOffTargetId == '${data.trackingId}';
      final isVip = game.vipTarget == data;
      final idColor = isTipOff
          ? const Color(0xFFffdd00)
          : isVip
          ? const Color(0xFFff88ff)
          : const Color(0xFF39ff6a);
      if (isTipOff) {
        canvas.drawRect(
          Rect.fromLTWH(-4, -24, size.x + 8, size.y + 28),
          Paint()
            ..color = const Color(
              0xFFffdd00,
            ).withOpacity(0.12 + 0.08 * sin(_elapsed * 6))
            ..style = PaintingStyle.fill,
        );
      }
      if (isVip) {
        canvas.drawRect(
          Rect.fromLTWH(-4, -24, size.x + 8, size.y + 28),
          Paint()
            ..color = const Color(
              0xFFff88ff,
            ).withOpacity(0.12 + 0.08 * sin(_elapsed * 4))
            ..style = PaintingStyle.fill,
        );
      }
      final tp = TextPainter(
        text: TextSpan(
          text: isTipOff
              ? '⚡#${data.trackingId}'
              : isVip
              ? '⭐#${data.trackingId}'
              : '#${data.trackingId}',
          style: TextStyle(
            color: idColor.withOpacity(0.9),
            fontSize: 8,
            letterSpacing: 1,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.x / 2 - tp.width / 2, -16));
    }
    if (_currentAction.isNotEmpty && _spawned && !_dying) {
      final tp = TextPainter(
        text: TextSpan(
          text: _currentAction,
          style: const TextStyle(fontSize: 14),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(size.x / 2 - 8, -28));
    }
    if (_spawned && !_selected && !_dying) {
      canvas.drawCircle(
        Offset(size.x / 2, -8),
        3,
        Paint()
          ..color = const Color(
            0xFFff4d00,
          ).withOpacity(0.4 + 0.4 * sin(_elapsed * 3)),
      );
    }
  }

  @override
  void onTapDown(TapDownEvent event) {
    if (!_spawned) return;
    _selected = true;
    game.selectCitizen(data, this);
  }

  void deselect() {
    _selected = false;
    _fleeTimer = 0;
  }
}

class _Pixel {
  final int col, row;
  final double delay;
  final Color color;
  _Pixel({
    required this.col,
    required this.row,
    required this.delay,
    required this.color,
  });
}

// ─── TITLE SCREEN ─────────────────────────────────────────────────────────────

class _DotGridPainter extends CustomPainter {
  final double t;
  _DotGridPainter(this.t);
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = const Color(0xFF0a1a0a);
    const spacing = 28.0;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        final wave = sin(x * 0.03 + y * 0.02 + t) * 0.5 + 0.5;
        final r = 1.2 + wave * 0.8;
        p.color = Color.lerp(
          const Color(0xFF060e06),
          const Color(0xFF0d280d),
          wave,
        )!;
        canvas.drawCircle(Offset(x, y), r, p);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter o) => o.t != t;
}

class _PixelEyePainter extends CustomPainter {
  final double blink; // 0=open, 1=closed
  final double glow;
  _PixelEyePainter({required this.blink, required this.glow});
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2, cy = size.height / 2;
    const px = 6.0;
    final iris = const Color(0xFFff4d00);
    final pupil = Colors.black;
    final white = const Color(0xFF1a1a2a);
    final lid = Colors.black;
    // glow
    canvas.drawCircle(
      Offset(cx, cy),
      38 + glow * 8,
      Paint()
        ..color = iris.withOpacity(0.06 + glow * 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
    // white of eye - 9x5 pixel grid centered
    final eyePixels = [
      [0, 0, 1, 1, 1, 1, 1, 0, 0],
      [0, 1, 1, 1, 1, 1, 1, 1, 0],
      [1, 1, 1, 1, 1, 1, 1, 1, 1],
      [0, 1, 1, 1, 1, 1, 1, 1, 0],
      [0, 0, 1, 1, 1, 1, 1, 0, 0],
    ];
    final startX = cx - 4.5 * px, startY = cy - 2.5 * px;
    for (int row = 0; row < eyePixels.length; row++) {
      final lidFrac = blink;
      final visibleRows = (eyePixels.length * (1 - lidFrac)).ceil();
      if (row >= visibleRows) {
        canvas.drawRect(
          Rect.fromLTWH(startX + 1 * px, startY + row * px, 7 * px, px),
          Paint()..color = lid,
        );
        continue;
      }
      for (int col = 0; col < eyePixels[row].length; col++) {
        if (eyePixels[row][col] == 0) continue;
        canvas.drawRect(
          Rect.fromLTWH(
            startX + col * px,
            startY + row * px,
            px - 0.5,
            px - 0.5,
          ),
          Paint()..color = white,
        );
      }
    }
    if (blink < 0.7) {
      // iris 3x3
      for (int r = 1; r <= 3; r++)
        for (int c = 3; c <= 5; c++) {
          canvas.drawRect(
            Rect.fromLTWH(startX + c * px, startY + r * px, px - 0.5, px - 0.5),
            Paint()..color = iris.withOpacity(0.9 + glow * 0.1),
          );
        }
      // pupil 1x1
      canvas.drawRect(
        Rect.fromLTWH(startX + 4 * px, startY + 2 * px, px - 0.5, px - 0.5),
        Paint()..color = pupil,
      );
      // scan line across eye
      canvas.drawLine(
        Offset(startX, cy),
        Offset(startX + 9 * px, cy),
        Paint()
          ..color = iris.withOpacity(0.15)
          ..strokeWidth = 0.5,
      );
    }
  }

  @override
  bool shouldRepaint(_PixelEyePainter o) => o.blink != blink || o.glow != glow;
}

class TitleOverlay extends StatefulWidget {
  final TheWatcherGame game;
  const TitleOverlay({super.key, required this.game});
  @override
  State<TitleOverlay> createState() => _TitleState();
}

class _TitleState extends State<TitleOverlay> with TickerProviderStateMixin {
  late AnimationController _glitch, _fade, _grid, _blink, _boot, _sweep, _pulse;
  bool _showCustom = false;
  bool _showSettings = false;
  bool _showContent = false;
  int _customCitizens = 3, _customTime = 30, _customSuspicion = 30;
  int _bootLine = 0;
  final _bootLines = [
    'SURVEILLANCE DIVISION SYSTEM v4.7.1',
    'LOADING OPERATOR PROFILE...',
    'CAMERA NETWORK: 4 FEEDS ONLINE',
    'THREAT DETECTION MODULE: ACTIVE',
    'AWAITING OPERATOR CLEARANCE...',
  ];

  @override
  void initState() {
    super.initState();
    _glitch = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    )..repeat(reverse: true);
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..forward();
    _grid = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _boot = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    )..forward();
    // horizontal sweep line — slow dramatic pass top→bottom
    _sweep = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..forward();
    // pulsing prompt after content loads
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    // content reveals after sweep
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _showContent = true);
    });
    // Try to start music — works if audio already unlocked (e.g. returning from game)
    // If locked, GestureDetector on the screen will start it on first tap
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) SoundEngine.resumeAndPlayMenuMusic();
    });
    for (int i = 0; i < _bootLines.length; i++) {
      Future.delayed(Duration(milliseconds: 600 + i * 420), () {
        if (mounted) setState(() => _bootLine = i + 1);
      });
    }
    _scheduleBlink();
  }

  void _scheduleBlink() {
    Future.delayed(Duration(milliseconds: 2000 + Random().nextInt(4000)), () {
      if (!mounted) return;
      _blink.forward().then(
        (_) => _blink.reverse().then((_) {
          if (mounted) _scheduleBlink();
        }),
      );
    });
  }

  @override
  void dispose() {
    _glitch.dispose();
    _fade.dispose();
    _grid.dispose();
    _blink.dispose();
    _boot.dispose();
    _sweep.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _startWithPreset(String preset) =>
      widget.game.startGame(null, preset: preset);
  void _startCustom() {
    // Generate 4 scaling rounds based on custom settings
    final configs = List.generate(4, (i) {
      final scale = 1.0 + i * 0.25; // each camera gets slightly harder
      return DifficultyConfig(
        citizenCount: (_customCitizens + i).clamp(1, 10),
        roundDuration: (_customTime / scale).clamp(10.0, 300.0),
        citizenSpeed: 30.0 + i * 6,
        clueRevealInterval: (4.0 - i * 0.5).clamp(1.5, 6.0),
        spawnDelay: 0.5,
        scoreMultiplier: 2,
        threatLevel: 'CUSTOM',
        threatColor: const Color(0xFF88aaff),
      );
    });
    widget.game.startGame(null, preset: 'custom', configs: configs);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: SoundEngine.resumeAndPlayMenuMusic,
      child: Material(
        color: Colors.transparent,
        child: FadeTransition(
          opacity: _fade,
          child: Container(
            color: Colors.black,
            child: Stack(
              children: [
                // Animated dot grid background
                AnimatedBuilder(
                  animation: _grid,
                  builder: (_, __) => Positioned.fill(
                    child: CustomPaint(
                      painter: _DotGridPainter(_grid.value * 2 * pi),
                    ),
                  ),
                ),

                Positioned.fill(
                  child: CustomPaint(painter: ScanlinePainter(opacity: 0.05)),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: VignettePainter(
                      baseOpacity: 0.82,
                      pulseOpacity: 0,
                    ),
                  ),
                ),

                // Glitch lines
                AnimatedBuilder(
                  animation: _glitch,
                  builder: (_, __) {
                    final h = MediaQuery.of(context).size.height;
                    return Stack(
                      children: [
                        Positioned(
                          top: h * 0.28 + _glitch.value * 4,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 1,
                            color: const Color(0xFFff4d00).withOpacity(0.18),
                          ),
                        ),
                        Positioned(
                          top: h * 0.72 - _glitch.value * 3,
                          left: 0,
                          right: 0,
                          child: Container(
                            height: 1,
                            color: const Color(0xFF0088ff).withOpacity(0.12),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                // Dramatic sweep line — scans top to bottom on load
                AnimatedBuilder(
                  animation: _sweep,
                  builder: (_, __) {
                    final h = MediaQuery.of(context).size.height;
                    final y = _sweep.value * h;
                    final fade = (1.0 - _sweep.value).clamp(0.0, 1.0);
                    if (_sweep.isCompleted) return const SizedBox.shrink();
                    return Stack(
                      children: [
                        // glow above line
                        Positioned(
                          top: y - 40,
                          left: 0,
                          right: 0,
                          height: 40,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.transparent,
                                  const Color(
                                    0xFF00ff44,
                                  ).withOpacity(0.04 * fade),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // bright line
                        Positioned(
                          top: y,
                          left: 0,
                          right: 0,
                          height: 2,
                          child: Container(
                            color: const Color(
                              0xFF00ff44,
                            ).withOpacity(0.55 * fade),
                          ),
                        ),
                      ],
                    );
                  },
                ),

                // CRT corners
                Positioned.fill(
                  child: CustomPaint(
                    painter: CRTCornerPainter(color: const Color(0xFFff4d00)),
                  ),
                ),

                // Boot log — bottom left
                Positioned(
                  left: 20,
                  bottom: 20,
                  child: AnimatedBuilder(
                    animation: _boot,
                    builder: (_, __) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (
                          int i = 0;
                          i < _bootLine && i < _bootLines.length;
                          i++
                        )
                          _BootLine(text: _bootLines[i], delay: i * 380),
                      ],
                    ),
                  ),
                ),

                // Content — delayed until sweep passes center
                AnimatedOpacity(
                  opacity: _showContent ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 600),
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(height: 32),

                          // Classification stamp
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFFff4d00).withOpacity(0.3),
                              ),
                            ),
                            child: const Text(
                              'SURVEILLANCE DIVISION — SECTOR 7 — CLASSIFIED',
                              style: TextStyle(
                                color: Color(0xFF2a2a38),
                                fontSize: 8,
                                letterSpacing: 3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Pixel eye
                          AnimatedBuilder(
                            animation: Listenable.merge([_blink, _grid]),
                            builder: (_, __) => SizedBox(
                              width: 80,
                              height: 60,
                              child: CustomPaint(
                                painter: _PixelEyePainter(
                                  blink: _blink.value,
                                  glow:
                                      (sin(_grid.value * 2 * pi) * 0.5 + 0.5) *
                                      0.4,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Glitchy title
                          AnimatedBuilder(
                            animation: _glitch,
                            builder: (_, __) {
                              final off = _glitch.value * 5;
                              return Stack(
                                alignment: Alignment.center,
                                children: [
                                  Transform.translate(
                                    offset: Offset(off, 0),
                                    child: const Text(
                                      'THE WATCHER',
                                      style: TextStyle(
                                        color: Color(0x33ff4d00),
                                        fontSize: 56,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 10,
                                      ),
                                    ),
                                  ),
                                  Transform.translate(
                                    offset: Offset(-off, 0),
                                    child: const Text(
                                      'THE WATCHER',
                                      style: TextStyle(
                                        color: Color(0x220088ff),
                                        fontSize: 56,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 10,
                                      ),
                                    ),
                                  ),
                                  const Text(
                                    'THE WATCHER',
                                    style: TextStyle(
                                      color: Color(0xFFdddde8),
                                      fontSize: 56,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 10,
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Y O U   A R E   T H E   S Y S T E M',
                            style: TextStyle(
                              color: Color(0xFFff4d00),
                              fontSize: 11,
                              letterSpacing: 5,
                            ),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: 420,
                            child: const Text(
                              'Civilians move through your camera network. Read their dossiers.\nFlag the guilty. Clear the innocent. Three mistakes and you are replaced.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF3a3a50),
                                fontSize: 11,
                                height: 1.7,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),

                          if (!_showCustom && !_showSettings) ...[
                            // Pulsing "ENTER CLEARANCE" prompt
                            AnimatedBuilder(
                              animation: _pulse,
                              builder: (_, __) => Text(
                                '— SELECT THREAT LEVEL —',
                                style: TextStyle(
                                  color: Color.lerp(
                                    const Color(0xFF2a2a38),
                                    const Color(0xFFff4d00),
                                    _pulse.value * 0.5,
                                  )!,
                                  fontSize: 9,
                                  letterSpacing: 4,
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              alignment: WrapAlignment.center,
                              children: [
                                _DiffBtn(
                                  label: 'EASY',
                                  sub:
                                      '2–3 subjects · 4 cameras\n120s → 65s per round\nFor new recruits',
                                  color: const Color(0xFF39ff6a),
                                  onTap: () => _startWithPreset('easy'),
                                ),
                                _DiffBtn(
                                  label: 'NORMAL',
                                  sub:
                                      '3–5 subjects · 4 cameras\n60s → 35s per round\nRecommended',
                                  color: const Color(0xFFffb347),
                                  onTap: () => _startWithPreset('normal'),
                                ),
                                _DiffBtn(
                                  label: 'HARD',
                                  sub:
                                      '4–6 subjects · 4 cameras\n40s → 20s per round\nFor veterans',
                                  color: const Color(0xFFff8800),
                                  onTap: () => _startWithPreset('hard'),
                                ),
                                _DiffBtn(
                                  label: 'EXPERT',
                                  sub:
                                      '5–7 subjects · 4 cameras\n30s → 14s per round\nGood luck',
                                  color: const Color(0xFFff3355),
                                  onTap: () => _startWithPreset('expert'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            GestureDetector(
                              onTap: () => setState(() => _showCustom = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(
                                      0xFF88aaff,
                                    ).withOpacity(0.35),
                                  ),
                                  color: const Color(
                                    0xFF88aaff,
                                  ).withOpacity(0.04),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.tune,
                                      color: Color(0xFF88aaff),
                                      size: 14,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'CUSTOM OPERATION',
                                      style: TextStyle(
                                        color: Color(0xFF88aaff),
                                        fontSize: 11,
                                        letterSpacing: 3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: () => setState(() => _showSettings = true),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 28,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(
                                      0xFF445566,
                                    ).withOpacity(0.35),
                                  ),
                                  color: const Color(
                                    0xFF445566,
                                  ).withOpacity(0.04),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.settings,
                                      color: Color(0xFF6688aa),
                                      size: 14,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'SYSTEM SETTINGS',
                                      style: TextStyle(
                                        color: Color(0xFF6688aa),
                                        fontSize: 11,
                                        letterSpacing: 3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ] else if (_showSettings) ...[
                            Container(
                              width: 380,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(
                                    0xFF445566,
                                  ).withOpacity(0.3),
                                ),
                                color: const Color(0xFF06060e),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'SYSTEM SETTINGS',
                                    style: TextStyle(
                                      color: Color(0xFF6688aa),
                                      fontSize: 9,
                                      letterSpacing: 4,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: 340,
                                    height: 1,
                                    color: const Color(
                                      0xFF445566,
                                    ).withOpacity(0.2),
                                  ),
                                  const SizedBox(height: 28),
                                  _RawSlider(
                                    label: 'SFX VOLUME',
                                    value: SoundEngine.vol,
                                    color: const Color(0xFF39ff6a),
                                    onChanged: (v) =>
                                        setState(() => SoundEngine.vol = v),
                                  ),
                                  const SizedBox(height: 24),
                                  _RawSlider(
                                    label: 'MUSIC VOLUME',
                                    value: SoundEngine.musicVol,
                                    color: const Color(0xFF6688aa),
                                    onChanged: (v) {
                                      setState(() => SoundEngine.musicVol = v);
                                      SoundEngine.applyMusicVol();
                                    },
                                  ),
                                  const SizedBox(height: 32),
                                  GestureDetector(
                                    onTap: () =>
                                        setState(() => _showSettings = false),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 32,
                                        vertical: 10,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: const Color(0xFF2a2a38),
                                        ),
                                      ),
                                      child: const Text(
                                        'CLOSE',
                                        style: TextStyle(
                                          color: Color(0xFF444455),
                                          fontSize: 10,
                                          letterSpacing: 4,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            Container(
                              width: 380,
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(
                                    0xFF88aaff,
                                  ).withOpacity(0.25),
                                ),
                                color: const Color(0xFF06060e),
                              ),
                              child: Column(
                                children: [
                                  const Text(
                                    'CUSTOM OPERATION PARAMETERS',
                                    style: TextStyle(
                                      color: Color(0xFF88aaff),
                                      fontSize: 9,
                                      letterSpacing: 3,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: 340,
                                    height: 1,
                                    color: const Color(
                                      0xFF88aaff,
                                    ).withOpacity(0.15),
                                  ),
                                  const SizedBox(height: 24),
                                  _CustomRow(
                                    label: 'SUBJECTS PER CAMERA',
                                    value: _customCitizens,
                                    min: 1,
                                    max: 999,
                                    hint:
                                        'how many people walk each camera feed',
                                    onChanged: (v) =>
                                        setState(() => _customCitizens = v),
                                  ),
                                  const SizedBox(height: 20),
                                  _CustomRow(
                                    label: 'ROUND DURATION',
                                    value: _customTime,
                                    min: 10,
                                    max: 9999,
                                    suffix: 's',
                                    hint: 'time before timeout game over',
                                    onChanged: (v) =>
                                        setState(() => _customTime = v),
                                  ),
                                  const SizedBox(height: 20),
                                  _CustomRow(
                                    label: 'SUSPICION RATE',
                                    value: _customSuspicion,
                                    min: 10,
                                    max: 100,
                                    suffix: '%',
                                    hint:
                                        'chance any given subject is a dissident',
                                    onChanged: (v) =>
                                        setState(() => _customSuspicion = v),
                                  ),
                                  const SizedBox(height: 28),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      GestureDetector(
                                        onTap: () =>
                                            setState(() => _showCustom = false),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 20,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: const Color(0xFF2a2a38),
                                            ),
                                          ),
                                          child: const Text(
                                            'BACK',
                                            style: TextStyle(
                                              color: Color(0xFF444455),
                                              fontSize: 10,
                                              letterSpacing: 3,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      GestureDetector(
                                        onTap: _startCustom,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 32,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: const Color(0xFF88aaff),
                                              width: 1.5,
                                            ),
                                            color: const Color(
                                              0xFF88aaff,
                                            ).withOpacity(0.08),
                                          ),
                                          child: const Text(
                                            'DEPLOY',
                                            style: TextStyle(
                                              color: Color(0xFF88aaff),
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 4,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 36),
                          const Text(
                            'SURVEILLANCE DIVISION · CLASSIFIED · SECTOR 7',
                            style: TextStyle(
                              color: Color(0xFF181820),
                              fontSize: 8,
                              letterSpacing: 3,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'FLAME GAME JAM 2026',
                            style: TextStyle(
                              color: Color(0xFF181820),
                              fontSize: 8,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ), // end AnimatedOpacity > Center > SingleChildScrollView > Column
              ],
            ),
          ),
        ),
      ),
    ); // end GestureDetector > Material > FadeTransition > Container > Stack
  }
}

// Raw slider — no Material ancestor needed
class _RawSlider extends StatefulWidget {
  final String label;
  final double value;
  final Color color;
  final ValueChanged<double> onChanged;
  const _RawSlider({
    required this.label,
    required this.value,
    required this.color,
    required this.onChanged,
  });
  @override
  State<_RawSlider> createState() => _RawSliderState();
}

class _RawSliderState extends State<_RawSlider> {
  late double _val;
  @override
  void initState() {
    super.initState();
    _val = widget.value;
  }

  void _handle(Offset local, double width) {
    final v = (local.dx / width).clamp(0.0, 1.0);
    setState(() => _val = v);
    widget.onChanged(v);
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.label,
            style: const TextStyle(
              color: Color(0xFF445566),
              fontSize: 9,
              letterSpacing: 3,
            ),
          ),
          Text(
            '${(_val * 100).round()}%',
            style: TextStyle(
              color: widget.color,
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      LayoutBuilder(
        builder: (ctx, c) {
          final w = c.maxWidth;
          return GestureDetector(
            onHorizontalDragUpdate: (d) => _handle(d.localPosition, w),
            onTapDown: (d) => _handle(d.localPosition, w),
            child: SizedBox(
              height: 24,
              width: w,
              child: CustomPaint(painter: _SliderPainter(_val, widget.color)),
            ),
          );
        },
      ),
    ],
  );
}

class _SliderPainter extends CustomPainter {
  final double val;
  final Color color;
  const _SliderPainter(this.val, this.color);
  @override
  void paint(Canvas c, Size s) {
    final y = s.height / 2;
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, y - 2, s.width, 4),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFF1a1a28),
    );
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(0, y - 2, s.width * val, 4),
        const Radius.circular(2),
      ),
      Paint()..color = color.withOpacity(0.8),
    );
    c.drawCircle(Offset(s.width * val, y), 7, Paint()..color = color);
    c.drawCircle(
      Offset(s.width * val, y),
      7,
      Paint()
        ..color = Colors.white.withOpacity(0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(_SliderPainter o) => o.val != val || o.color != color;
}

class _BootLine extends StatefulWidget {
  final String text;
  final int delay;
  const _BootLine({required this.text, required this.delay});
  @override
  State<_BootLine> createState() => _BootLineState();
}

class _BootLineState extends State<_BootLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: (widget.text.length * 22).clamp(200, 500),
      ),
    )..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) {
      final chars = (widget.text.length * _c.value).ceil().clamp(
        0,
        widget.text.length,
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '> ',
              style: const TextStyle(
                color: Color(0xFF39ff6a),
                fontSize: 9,
                fontFamily: 'monospace',
              ),
            ),
            Text(
              widget.text.substring(0, chars),
              style: const TextStyle(
                color: Color(0xFF1a3a1a),
                fontSize: 9,
                letterSpacing: 1,
                fontFamily: 'monospace',
              ),
            ),
            if (_c.value < 1.0)
              Container(
                width: 5,
                height: 10,
                color: const Color(0xFF39ff6a).withOpacity(0.6),
              ),
          ],
        ),
      );
    },
  );
}

class _DiffBtn extends StatelessWidget {
  final String label, sub;
  final Color color;
  final VoidCallback onTap;
  const _DiffBtn({
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 155,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.35), width: 1.5),
        color: color.withOpacity(0.05),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            sub,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: color.withOpacity(0.4),
              fontSize: 9,
              height: 1.6,
            ),
          ),
        ],
      ),
    ),
  );
}

class _CustomRow extends StatefulWidget {
  final String label, suffix;
  final int value, min, max;
  final String? hint;
  final ValueChanged<int> onChanged;
  const _CustomRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.hint,
    this.suffix = '',
  });
  @override
  State<_CustomRow> createState() => _CustomRowState();
}

class _CustomRowState extends State<_CustomRow> {
  late TextEditingController _ctrl;
  final FocusNode _focusNode = FocusNode();
  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.value}');
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus) _submit(_ctrl.text);
    });
  }

  @override
  void didUpdateWidget(_CustomRow old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _ctrl.text = '${widget.value}';
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _submit(String val) {
    final n = int.tryParse(val);
    if (n != null) {
      widget.onChanged(n.clamp(widget.min, widget.max));
    } else {
      _ctrl.text = '${widget.value}';
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        widget.label,
        style: const TextStyle(
          color: Color(0xFF444455),
          fontSize: 8,
          letterSpacing: 3,
        ),
      ),
      if (widget.hint != null) ...[
        const SizedBox(height: 2),
        Text(
          widget.hint!,
          style: const TextStyle(color: Color(0xFF2a2a38), fontSize: 8),
        ),
      ],
      const SizedBox(height: 10),
      Row(
        children: [
          _TapBtn(
            icon: Icons.remove,
            onTap: widget.value > widget.min
                ? () => widget.onChanged(widget.value - 1)
                : null,
          ),
          const SizedBox(width: 12),
          // Typed input
          GestureDetector(
            onTap: () => _focusNode.requestFocus(),
            child: Container(
              width: 90,
              height: 40,
              decoration: BoxDecoration(
                border: Border.all(
                  color: const Color(0xFF88aaff).withOpacity(0.35),
                ),
                color: const Color(0xFF88aaff).withOpacity(0.06),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: EditableText(
                      controller: _ctrl,
                      focusNode: _focusNode,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Color(0xFF88aaff),
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      cursorColor: const Color(0xFF88aaff),
                      backgroundCursorColor: Colors.transparent,
                      onSubmitted: _submit,
                    ),
                  ),
                  if (widget.suffix.isNotEmpty)
                    Text(
                      widget.suffix,
                      style: const TextStyle(
                        color: Color(0xFF88aaff),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          _TapBtn(
            icon: Icons.add,
            onTap: widget.value < widget.max
                ? () => widget.onChanged(widget.value + 1)
                : null,
          ),
          const SizedBox(width: 12),
          Text(
            '${widget.min}–${widget.max}',
            style: const TextStyle(color: Color(0xFF2a2a38), fontSize: 8),
          ),
        ],
      ),
    ],
  );
}

class _TapBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _TapBtn({required this.icon, this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        border: Border.all(
          color: onTap != null
              ? const Color(0xFF88aaff).withOpacity(0.4)
              : const Color(0xFF1a1a24),
        ),
        color: onTap != null
            ? const Color(0xFF88aaff).withOpacity(0.07)
            : Colors.transparent,
      ),
      child: Icon(
        icon,
        color: onTap != null
            ? const Color(0xFF88aaff)
            : const Color(0xFF252530),
        size: 16,
      ),
    ),
  );
}

// ─── ROUND INTRO ──────────────────────────────────────────────────────────────

class RoundIntroOverlay extends StatefulWidget {
  final TheWatcherGame game;
  const RoundIntroOverlay({super.key, required this.game});
  @override
  State<RoundIntroOverlay> createState() => _RoundIntroState();
}

class _RoundIntroState extends State<RoundIntroOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  int _phase = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    )..forward();
    // phase 0: deployment bar sweeps (0–400ms)
    // phase 1: boot lines appear
    Future.delayed(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _phase = 1);
    });
    Future.delayed(const Duration(milliseconds: 520), () {
      if (mounted) setState(() => _phase = 2);
    });
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _phase = 3);
    });
    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) setState(() => _phase = 4);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final diff = game.difficulty;
    final cam = game.cameraNames[game.currentCamera];
    final camId = game.camIds[game.currentCamera];
    final tint = game.camTints[game.currentCamera];
    final isFirstRound = game.round == 1 && game.completedRounds.isEmpty;
    final W = MediaQuery.of(context).size.width;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value;
        final fadeOut = t > 0.82
            ? (1.0 - (t - 0.82) * 5.5).clamp(0.0, 1.0)
            : 1.0;
        // deployment bar: 0→1 in first 0.22 of animation
        final barFrac = (t / 0.22).clamp(0.0, 1.0);

        return Opacity(
          opacity: fadeOut,
          child: Container(
            color: Colors.black.withOpacity(0.96),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: ScanlinePainter(opacity: 0.05)),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: VignettePainter(
                      baseOpacity: 0.55,
                      pulseOpacity: 0,
                    ),
                  ),
                ),

                // Tint accent bars
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(height: 2, color: tint.withOpacity(0.8)),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(height: 1, color: tint.withOpacity(0.4)),
                ),

                // ── DEPLOYMENT BAR — sweeps left to right ──
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(height: 2),
                      // label
                      if (barFrac > 0.05)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              Text(
                                'DEPLOYING TO ${cam.toUpperCase()}',
                                style: const TextStyle(
                                  color: Color(0xFFff3355),
                                  fontSize: 9,
                                  letterSpacing: 4,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                '${(barFrac * 100).toInt()}%',
                                style: const TextStyle(
                                  color: Color(0xFFff3355),
                                  fontSize: 9,
                                  letterSpacing: 2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      // bar track
                      Container(height: 3, color: const Color(0xFF1a0008)),
                      // fill
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: W * barFrac,
                          height: 3,
                          decoration: BoxDecoration(
                            color: const Color(0xFFff3355),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFff3355).withOpacity(0.6),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Boot terminal lines — left side
                Positioned(
                  left: 32,
                  top: 80,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_phase >= 1)
                        _IntroLine(
                          text: 'INITIALIZING CAMERA FEED...',
                          color: const Color(0xFF1a3a1a),
                          fontSize: 9,
                          letterSpacing: 1,
                        ),
                      if (_phase >= 1) const SizedBox(height: 4),
                      if (_phase >= 2)
                        _IntroLine(
                          text: 'DECRYPTING VIDEO STREAM... OK',
                          color: const Color(0xFF1a3a1a),
                          fontSize: 9,
                          letterSpacing: 1,
                        ),
                      if (_phase >= 2) const SizedBox(height: 4),
                      if (_phase >= 3)
                        _IntroLine(
                          text: 'LOADING BEHAVIORAL DATABASE... OK',
                          color: const Color(0xFF1a3a1a),
                          fontSize: 9,
                          letterSpacing: 1,
                        ),
                    ],
                  ),
                ),

                Center(
                  child: SizedBox(
                    width: 460,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Camera ID + round badge
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              color: tint.withOpacity(0.15),
                              child: Text(
                                camId,
                                style: TextStyle(
                                  color: tint,
                                  fontSize: 10,
                                  letterSpacing: 4,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFF252530),
                                ),
                              ),
                              child: Text(
                                'SECTOR ${game.round} / ${game.cameraNames.length}',
                                style: const TextStyle(
                                  color: Color(0xFF444455),
                                  fontSize: 9,
                                  letterSpacing: 3,
                                ),
                              ),
                            ),
                            if (isFirstRound) ...[
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                color: const Color(0xFF39ff6a).withOpacity(0.1),
                                child: const Text(
                                  'FIRST DEPLOYMENT',
                                  style: TextStyle(
                                    color: Color(0xFF39ff6a),
                                    fontSize: 8,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 22),

                        // Camera name — big typewriter, hard cut in at phase 2
                        if (_phase >= 2)
                          _IntroLine(
                            text: cam.toUpperCase(),
                            color: const Color(0xFFdddde8),
                            fontSize: 28,
                            bold: true,
                            letterSpacing: 2,
                          ),
                        const SizedBox(height: 14),

                        if (_phase >= 3)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            width: 300,
                            height: 1,
                            color: tint.withOpacity(0.4),
                          ),
                        const SizedBox(height: 14),

                        if (_phase >= 3)
                          _IntroLine(
                            text:
                                '${diff.citizenCount}–${diff.citizenCount + 1} SUBJECTS  ·  ${diff.roundDuration.toInt()}s TIME WINDOW',
                            color: const Color(0xFF555566),
                            fontSize: 10,
                            letterSpacing: 2,
                          ),
                        const SizedBox(height: 6),
                        if (_phase >= 3)
                          Row(
                            children: [
                              _IntroLine(
                                text: 'THREAT LEVEL: ',
                                color: const Color(0xFF444455),
                                fontSize: 10,
                                letterSpacing: 2,
                              ),
                              _IntroLine(
                                text: diff.threatLevel,
                                color: diff.threatColor,
                                fontSize: 10,
                                letterSpacing: 3,
                              ),
                            ],
                          ),
                        const SizedBox(height: 20),

                        if (_phase >= 4)
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF39ff6a),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'SURVEILLANCE ACTIVE',
                                style: TextStyle(
                                  color: Color(0xFF39ff6a),
                                  fontSize: 9,
                                  letterSpacing: 5,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _IntroLine extends StatefulWidget {
  final String text;
  final Color color;
  final double fontSize;
  final bool bold;
  final double letterSpacing;
  const _IntroLine({
    required this.text,
    required this.color,
    this.fontSize = 11,
    this.bold = false,
    this.letterSpacing = 1,
  });
  @override
  State<_IntroLine> createState() => _IntroLineState();
}

class _IntroLineState extends State<_IntroLine>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: (widget.text.length * 28).clamp(200, 600),
      ),
    )..forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (ctx, _) {
      final chars = (widget.text.length * _c.value).ceil().clamp(
        0,
        widget.text.length,
      );
      return Text(
        widget.text.substring(0, chars),
        style: TextStyle(
          color: widget.color,
          fontSize: widget.fontSize,
          fontWeight: widget.bold ? FontWeight.bold : FontWeight.normal,
          letterSpacing: widget.letterSpacing,
          fontFamily: 'monospace',
        ),
      );
    },
  );
}

// ─── JUICE OVERLAY ────────────────────────────────────────────────────────────

class JuiceOverlay extends StatefulWidget {
  final TheWatcherGame game;
  const JuiceOverlay({super.key, required this.game});
  @override
  State<JuiceOverlay> createState() => _JuiceState();
}

class _JuiceState extends State<JuiceOverlay> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(milliseconds: 50), (i) => i),
      builder: (context, _) {
        final j = widget.game.juice;
        final size = MediaQuery.of(context).size;
        final tint = widget.game.camTints[widget.game.currentCamera];
        return IgnorePointer(
          child: Stack(
            children: [
              // Camera colour tint — stronger moodier feel
              Positioned.fill(child: Container(color: tint.withOpacity(0.07))),
              // Coloured edge glow per camera
              Positioned.fill(
                child: CustomPaint(painter: _CamVignettePainter(tint)),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: ScanlinePainter(opacity: j.flickerOpacity),
                ),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: VignettePainter(
                    baseOpacity: 0.65,
                    pulseOpacity: j.vignettePulse * 0.4,
                  ),
                ),
              ),
              // Streak pulse — green flash border
              if (j.streakPulse > 0)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(
                          0xFF39ff6a,
                        ).withOpacity(j.streakPulse * 0.7),
                        width: 4,
                      ),
                    ),
                  ),
                ),
              if (j.warningPulse > 0)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: const Color(
                          0xFFff3355,
                        ).withOpacity(j.warningPulse),
                        width: 7,
                      ),
                    ),
                  ),
                ),
              if (j.showGlitch)
                Positioned(
                  top: size.height * j.glitchY,
                  left: 0,
                  right: 0,
                  child: Container(height: 2, color: tint.withOpacity(0.45)),
                ),
              if (j.showGlitch)
                Positioned(
                  top: size.height * j.glitchY + 4,
                  left: size.width * 0.2,
                  right: 0,
                  child: Container(height: 1, color: tint.withOpacity(0.2)),
                ),
              if (j.signalLoss)
                Positioned.fill(
                  child: Container(color: Colors.white.withOpacity(0.06)),
                ),
              if (j.flashOpacity > 0)
                Positioned.fill(
                  child: Container(
                    color: j.flashColor.withOpacity(j.flashOpacity),
                  ),
                ),
              // Chromatic aberration on wrong flag
              if (j.chromAberration > 0)
                Positioned.fill(
                  child: CustomPaint(
                    painter: _ChromAberrationPainter(j.chromAberration),
                  ),
                ),
              if (j.showStaticBurst)
                Positioned.fill(child: CustomPaint(painter: _StaticPainter())),
              if (j.stampDuration > 0 && j.stampText.isNotEmpty)
                Center(
                  child: Transform.scale(
                    scale: j.stampScale,
                    child: Opacity(
                      opacity: j.stampOpacity,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: j.stampColor, width: 2),
                          color: j.stampColor.withOpacity(0.08),
                        ),
                        child: Text(
                          j.stampText,
                          style: TextStyle(
                            color: j.stampColor,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 8,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              if (j.motionDetectedTimer > 0)
                Positioned(
                  top: 90,
                  left: 16,
                  child: Opacity(
                    opacity: (j.motionDetectedTimer / 2.0).clamp(0.0, 1.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        border: Border.all(color: tint.withOpacity(0.6)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: tint.withOpacity(0.8),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'MOTION DETECTED',
                            style: TextStyle(
                              color: tint.withOpacity(0.9),
                              fontSize: 9,
                              letterSpacing: 3,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              Positioned.fill(
                child: CustomPaint(painter: CRTCornerPainter(color: tint)),
              ),
              Positioned(
                bottom: 40,
                left: 16,
                child: Text(
                  widget.game.camIds[widget.game.currentCamera],
                  style: TextStyle(
                    color: tint.withOpacity(0.5),
                    fontSize: 9,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class ScanlinePainter extends CustomPainter {
  final double opacity;
  ScanlinePainter({required this.opacity});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.black.withOpacity(opacity)
      ..strokeWidth = 1.0;
    for (double y = 0; y < size.height; y += 3)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
  }

  @override
  bool shouldRepaint(ScanlinePainter o) => o.opacity != opacity;
}

class VignettePainter extends CustomPainter {
  final double baseOpacity, pulseOpacity;
  VignettePainter({required this.baseOpacity, required this.pulseOpacity});
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.transparent,
            Colors.black.withOpacity(baseOpacity + pulseOpacity),
          ],
          stops: const [0.4, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_) => true;
}

class CRTCornerPainter extends CustomPainter {
  final Color color;
  const CRTCornerPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withOpacity(0.25)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    const s = 24.0;
    canvas.drawLine(const Offset(10, 10), const Offset(10 + s, 10), p);
    canvas.drawLine(const Offset(10, 10), const Offset(10, 10 + s), p);
    canvas.drawLine(
      Offset(size.width - 10, 10),
      Offset(size.width - 10 - s, 10),
      p,
    );
    canvas.drawLine(
      Offset(size.width - 10, 10),
      Offset(size.width - 10, 10 + s),
      p,
    );
    canvas.drawLine(
      Offset(10, size.height - 10),
      Offset(10 + s, size.height - 10),
      p,
    );
    canvas.drawLine(
      Offset(10, size.height - 10),
      Offset(10, size.height - 10 - s),
      p,
    );
    canvas.drawLine(
      Offset(size.width - 10, size.height - 10),
      Offset(size.width - 10 - s, size.height - 10),
      p,
    );
    canvas.drawLine(
      Offset(size.width - 10, size.height - 10),
      Offset(size.width - 10, size.height - 10 - s),
      p,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

class _StaticPainter extends CustomPainter {
  static final Random _r = Random();
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint();
    for (int i = 0; i < 800; i++) {
      final x = _r.nextDouble() * size.width;
      final y = _r.nextDouble() * size.height;
      final w = 1.0 + _r.nextDouble() * 4;
      final h = 1.0 + _r.nextDouble() * 2;
      p.color = Colors.white.withOpacity(0.05 + _r.nextDouble() * 0.12);
      canvas.drawRect(Rect.fromLTWH(x, y, w, h), p);
    }
  }

  @override
  bool shouldRepaint(_) => true;
}

class _CamVignettePainter extends CustomPainter {
  final Color tint;
  const _CamVignettePainter(this.tint);
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    // Subtle coloured edge glow — makes each camera feel distinct
    canvas.drawRect(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.transparent, tint.withOpacity(0.08)],
          stops: const [0.5, 1.0],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_CamVignettePainter o) => o.tint != tint;
}

class _ChromAberrationPainter extends CustomPainter {
  final double amount;
  const _ChromAberrationPainter(this.amount);
  @override
  void paint(Canvas canvas, Size size) {
    final shift = amount * 8;
    // Red channel shifted left, blue shifted right
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..color = const Color(0xFFff0000).withOpacity(amount * 0.06)
        ..blendMode = BlendMode.screen,
    );
    canvas.save();
    canvas.translate(-shift, 0);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..color = const Color(0xFFff0000).withOpacity(amount * 0.04)
        ..blendMode = BlendMode.screen,
    );
    canvas.restore();
    canvas.save();
    canvas.translate(shift, 0);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..color = const Color(0xFF0000ff).withOpacity(amount * 0.04)
        ..blendMode = BlendMode.screen,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ChromAberrationPainter o) => o.amount != amount;
}

// ─── HUD ──────────────────────────────────────────────────────────────────────

class HudOverlay extends StatefulWidget {
  final TheWatcherGame game;
  const HudOverlay({super.key, required this.game});
  @override
  State<HudOverlay> createState() => _HudState();
}

class _HudState extends State<HudOverlay> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(milliseconds: 150), (i) => i),
      builder: (context, _) {
        final game = widget.game;
        final frac = (game.roundTimer / game.roundDuration).clamp(0.0, 1.0);
        final isUrgent = game.roundTimer < 10;
        final tc = frac > 0.5
            ? const Color(0xFF39ff6a)
            : frac > 0.25
            ? const Color(0xFFffb347)
            : const Color(0xFFff3355);
        final diff = game.difficulty;
        final ct = game.camTints[game.currentCamera];
        return SafeArea(
          child: Column(
            children: [
              Container(
                color: Colors.black.withOpacity(0.92),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    Text(
                      '● ',
                      style: TextStyle(
                        color: ct.withOpacity(0.8),
                        fontSize: 10,
                      ),
                    ),
                    const Text(
                      'THE WATCHER',
                      style: TextStyle(
                        color: Color(0xFFff4d00),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 4,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      game.cameraNames[game.currentCamera],
                      style: const TextStyle(
                        color: Color(0xFF444455),
                        fontSize: 10,
                        letterSpacing: 2,
                      ),
                    ),
                    const Spacer(),
                    if (game.streak >= 2)
                      Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFffff00).withOpacity(0.1),
                          border: Border.all(
                            color: const Color(0xFFffff00).withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          '${game.streak}× STREAK',
                          style: const TextStyle(
                            color: Color(0xFFffff00),
                            fontSize: 8,
                            letterSpacing: 2,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Container(
                      margin: const EdgeInsets.only(right: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: diff.threatColor.withOpacity(0.1),
                        border: Border.all(
                          color: diff.threatColor.withOpacity(0.4),
                        ),
                      ),
                      child: Text(
                        '${diff.scoreMultiplier}×',
                        style: TextStyle(
                          color: diff.threatColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    _C(
                      label: 'SCORE',
                      value: '${game.score}',
                      color: const Color(0xFFffb347),
                    ),
                    const SizedBox(width: 12),
                    _C(
                      label: 'ACCURACY',
                      value: '${game.accuracy.toStringAsFixed(0)}%',
                      color: game.accuracy > 60
                          ? const Color(0xFF39ff6a)
                          : const Color(0xFFff3355),
                    ),
                    const SizedBox(width: 12),
                    Row(
                      children: List.generate(
                        TheWatcherGame.maxWrongFlags,
                        (i) => Padding(
                          padding: const EdgeInsets.only(left: 4),
                          child: Icon(
                            Icons.warning_rounded,
                            size: 15,
                            color: i < game.wrongFlags
                                ? const Color(0xFFff3355)
                                : const Color(0xFF252530),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () =>
                          setState(() => game.isPaused = !game.isPaused),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: game.isPaused
                                ? const Color(0xFFffb347).withOpacity(0.7)
                                : const Color(0xFF252530),
                          ),
                          color: game.isPaused
                              ? const Color(0xFFffb347).withOpacity(0.08)
                              : Colors.transparent,
                        ),
                        child: Text(
                          game.isPaused ? '▶ RESUME' : '⏸ PAUSE',
                          style: TextStyle(
                            color: game.isPaused
                                ? const Color(0xFFffb347)
                                : const Color(0xFF444455),
                            fontSize: 9,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                color: Colors.black.withOpacity(0.78),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 5,
                ),
                child: Row(
                  children: [
                    ...List.generate(game.cameraNames.length, (i) {
                      final isActive = game.currentCamera == i;
                      final isDone = game.completedRounds.contains(i);
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: GestureDetector(
                          onTap: isDone
                              ? null
                              : () =>
                                    setState(() => game.manualSwitchCamera(i)),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDone
                                  ? const Color(0xFF39ff6a).withOpacity(0.08)
                                  : isActive
                                  ? ct.withOpacity(0.12)
                                  : Colors.transparent,
                              border: Border.all(
                                color: isDone
                                    ? const Color(0xFF39ff6a).withOpacity(0.6)
                                    : isActive
                                    ? ct
                                    : const Color(0xFF252530),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isDone)
                                  const Text(
                                    '✓ ',
                                    style: TextStyle(
                                      color: Color(0xFF39ff6a),
                                      fontSize: 9,
                                    ),
                                  ),
                                Text(
                                  isDone
                                      ? 'CLEARED'
                                      : 'CAM ${(i + 1).toString().padLeft(2, '0')}',
                                  style: TextStyle(
                                    color: isDone
                                        ? const Color(0xFF39ff6a)
                                        : isActive
                                        ? ct
                                        : const Color(0xFF3a3a4a),
                                    fontSize: 9,
                                    letterSpacing: 2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    const Spacer(),
                    Text(
                      diff.threatLevel,
                      style: TextStyle(
                        color: diff.threatColor.withOpacity(0.7),
                        fontSize: 8,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'R${game.round}/${game.totalRounds}  ',
                      style: const TextStyle(
                        color: Color(0xFF444455),
                        fontSize: 9,
                        letterSpacing: 2,
                      ),
                    ),
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 100),
                      style: TextStyle(
                        color: tc,
                        fontSize: isUrgent ? 16 : 14,
                        fontWeight: FontWeight.bold,
                      ),
                      child: Text('${game.roundTimer.toInt()}s'),
                    ),
                  ],
                ),
              ),
              LinearProgressIndicator(
                value: frac,
                backgroundColor: const Color(0xFF0d0d14),
                valueColor: AlwaysStoppedAnimation(tc),
                minHeight: 2,
              ),
              if (game.isPaused)
                Expanded(
                  child: _PauseScreen(
                    onResume: () => setState(() => game.isPaused = false),
                    onMenu: () {
                      game.isPaused = false;
                      game.returnToTitle();
                    },
                  ),
                )
              else
                const Spacer(),
              Container(
                color: Colors.black.withOpacity(0.6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: const BoxDecoration(
                        color: Color(0xFFff3355),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'REC',
                      style: TextStyle(
                        color: Color(0xFFff3355),
                        fontSize: 8,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _ts(),
                      style: TextStyle(
                        color: ct.withOpacity(0.4),
                        fontSize: 8,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      game.camIds[game.currentCamera],
                      style: TextStyle(
                        color: ct.withOpacity(0.5),
                        fontSize: 8,
                        letterSpacing: 2,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'CLICK TO INSPECT · WAIT FOR CLUES',
                      style: TextStyle(
                        color: Color(0xFF2a2a38),
                        fontSize: 8,
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _ts() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}  ${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}:${n.second.toString().padLeft(2, '0')}';
  }
}

class _PauseScreen extends StatefulWidget {
  final VoidCallback onResume, onMenu;
  const _PauseScreen({required this.onResume, required this.onMenu});
  @override
  State<_PauseScreen> createState() => _PauseScreenState();
}

class _PauseScreenState extends State<_PauseScreen>
    with TickerProviderStateMixin {
  late AnimationController _glitch, _blink, _scan;
  @override
  void initState() {
    super.initState();
    _glitch = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    )..repeat(reverse: true);
    _blink = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _scan = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _glitch.dispose();
    _blink.dispose();
    _scan.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final W = MediaQuery.of(context).size.width;
    final H = MediaQuery.of(context).size.height;
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: Listenable.merge([_glitch, _blink, _scan]),
        builder: (ctx, _) {
          final g = _glitch.value;
          final b = _blink.value;
          return Stack(
            children: [
              // Dark base
              Container(color: Colors.black.withOpacity(0.88)),

              // Horizontal glitch slices — random displacement
              ...List.generate(6, (i) {
                final y = H * (0.12 + i * 0.14) + (g * 8 * (i.isEven ? 1 : -1));
                final sliceH = 2.0 + g * 3;
                return Positioned(
                  top: y,
                  left: g * (i.isEven ? 12.0 : -8.0),
                  right: 0,
                  child: Container(
                    height: sliceH,
                    color:
                        (i.isEven
                                ? const Color(0xFFff3355)
                                : const Color(0xFF0088ff))
                            .withOpacity(0.06 + g * 0.08),
                  ),
                );
              }),

              // Slow scan line sweeping down
              Positioned(
                top: _scan.value * H,
                left: 0,
                right: 0,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        const Color(0xFF00ff44).withOpacity(0.25),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              // CRT corners
              Positioned.fill(
                child: CustomPaint(
                  painter: CRTCornerPainter(
                    color: const Color(0xFFff4d00).withOpacity(0.5),
                  ),
                ),
              ),

              // CENTER CONTENT
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // WARNING header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFFff3355).withOpacity(0.5),
                        ),
                        color: const Color(0xFFff3355).withOpacity(0.06),
                      ),
                      child: Text(
                        '⚠  FEED INTERRUPTED',
                        style: TextStyle(
                          color: const Color(
                            0xFFff3355,
                          ).withOpacity(0.5 + b * 0.5),
                          fontSize: 9,
                          letterSpacing: 5,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Big glitchy PAUSED text with chromatic aberration
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Transform.translate(
                          offset: Offset(g * 6, 0),
                          child: const Text(
                            'SYSTEM PAUSED',
                            style: TextStyle(
                              color: Color(0x22ff3355),
                              fontSize: 38,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 8,
                            ),
                          ),
                        ),
                        Transform.translate(
                          offset: Offset(-g * 4, 0),
                          child: const Text(
                            'SYSTEM PAUSED',
                            style: TextStyle(
                              color: Color(0x220088ff),
                              fontSize: 38,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 8,
                            ),
                          ),
                        ),
                        const Text(
                          'SYSTEM PAUSED',
                          style: TextStyle(
                            color: Color(0xFFdddde8),
                            fontSize: 38,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 8,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    // Status lines
                    Text(
                      'SURVEILLANCE SUSPENDED · ALL FEEDS FROZEN',
                      style: TextStyle(
                        color: const Color(
                          0xFF444455,
                        ).withOpacity(0.6 + b * 0.4),
                        fontSize: 9,
                        letterSpacing: 3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'OPERATOR ABSENT FROM POST',
                      style: TextStyle(
                        color: const Color(
                          0xFFff3355,
                        ).withOpacity(0.3 + b * 0.3),
                        fontSize: 8,
                        letterSpacing: 4,
                      ),
                    ),

                    const SizedBox(height: 36),

                    // Volume controls
                    Container(
                      width: 280,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: const Color(0xFF222233).withOpacity(0.6),
                        ),
                        color: Colors.black.withOpacity(0.3),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'AUDIO SETTINGS',
                            style: TextStyle(
                              color: Color(0xFF333344),
                              fontSize: 8,
                              letterSpacing: 4,
                            ),
                          ),
                          const SizedBox(height: 14),
                          _RawSlider(
                            label: 'SFX VOLUME',
                            value: SoundEngine.vol,
                            color: const Color(0xFF39ff6a),
                            onChanged: (v) =>
                                setState(() => SoundEngine.vol = v),
                          ),
                          const SizedBox(height: 12),
                          _RawSlider(
                            label: 'MUSIC VOLUME',
                            value: SoundEngine.musicVol,
                            color: const Color(0xFF6688aa),
                            onChanged: (v) {
                              setState(() => SoundEngine.musicVol = v);
                              SoundEngine.applyMusicVol();
                            },
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Resume button — pulsing border
                    GestureDetector(
                      onTap: widget.onResume,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 36,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(
                              0xFF39ff6a,
                            ).withOpacity(0.3 + b * 0.5),
                            width: 1.5,
                          ),
                          color: const Color(
                            0xFF39ff6a,
                          ).withOpacity(0.03 + b * 0.04),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF39ff6a,
                                ).withOpacity(0.4 + b * 0.6),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              'RESUME SURVEILLANCE',
                              style: TextStyle(
                                color: const Color(
                                  0xFF39ff6a,
                                ).withOpacity(0.6 + b * 0.4),
                                fontSize: 11,
                                letterSpacing: 4,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Return to menu button
                    GestureDetector(
                      onTap: widget.onMenu,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 36,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF444455).withOpacity(0.4),
                          ),
                          color: Colors.transparent,
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '↩  ABORT MISSION',
                              style: TextStyle(
                                color: Color(0xFF555566),
                                fontSize: 11,
                                letterSpacing: 4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                    // Bottom classified
                    Text(
                      'SURVEILLANCE DIV. · SECTOR 7 · CLASSIFIED',
                      style: TextStyle(
                        color: const Color(
                          0xFF1a1a24,
                        ).withOpacity(0.8 + b * 0.2),
                        fontSize: 8,
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _C extends StatelessWidget {
  final String label, value;
  final Color color;
  const _C({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.end,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        label,
        style: const TextStyle(
          color: Color(0xFF2a2a38),
          fontSize: 8,
          letterSpacing: 2,
        ),
      ),
      Text(
        value,
        style: TextStyle(
          color: color,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
      ),
    ],
  );
}

// ─── PROFILE ──────────────────────────────────────────────────────────────────

class ProfileOverlay extends StatefulWidget {
  final TheWatcherGame game;
  const ProfileOverlay({super.key, required this.game});
  @override
  State<ProfileOverlay> createState() => _ProfileState();
}

class _ProfileState extends State<ProfileOverlay> {
  double _watchTime = 0;
  int _revealedClues = 0;
  @override
  void initState() {
    super.initState();
    _watchTime = 0;
    _revealedClues = 0;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(milliseconds: 200), (i) => i),
      builder: (context, _) {
        _watchTime += 0.2;
        final game = widget.game;
        final interval = game.difficulty.clueRevealInterval;
        final maxClues =
            game.selectedCitizen?.dissidentType == DissidentType.master
            ? 1
            : 99;
        final sr = (_watchTime / interval).floor().clamp(0, maxClues);
        if (sr > _revealedClues) _revealedClues = sr;
        final citizen = game.selectedCitizen;
        if (citizen == null) return const SizedBox();
        final ca = _revealedClues.clamp(0, citizen.clues.length);
        final showFalse = _watchTime > 5;
        final nextIn = (interval - (_watchTime % interval)).toInt() + 1;
        final isPanicked = citizen.dissidentType == DissidentType.panicked;
        final fleeComp = game.selectedComponent;
        final fleeP = isPanicked && fleeComp != null
            ? (fleeComp._fleeTimer / 7.0).clamp(0.0, 1.0)
            : 0.0;
        final isVip = game.vipTarget == citizen;
        final suspicionFrac = (ca / citizen.clues.length.clamp(1, 99)).clamp(
          0.0,
          1.0,
        );
        final accentColor = isVip
            ? const Color(0xFFff88ff)
            : const Color(0xFFff4d00);

        // Get citizen screen position and clamp dossier so it stays on screen
        final comp = game.selectedComponent;
        final sw = MediaQuery.of(context).size.width;
        final sh = MediaQuery.of(context).size.height;
        const dossierW = 300.0;
        const dossierMaxH = 420.0;
        double dx = 0, dy = 0;
        if (comp != null) {
          // citizen position in game coords = screen coords (1:1 on web)
          final cx = comp.position.x;
          final cy = comp.position.y;
          // place dossier to the right of citizen, flip left if too close to right edge
          dx = cx + 36 + dossierW > sw ? cx - dossierW - 36 : cx + 36;
          // vertically center on citizen, clamp to screen
          dy = (cy - dossierMaxH / 2).clamp(48.0, sh - dossierMaxH - 8);
        } else {
          dx = (sw - dossierW) / 2;
          dy = (sh - dossierMaxH) / 2;
        }

        return Stack(
          children: [
            // Backdrop — tap to dismiss
            Positioned.fill(
              child: GestureDetector(
                onTap: game.closeProfile,
                child: Container(color: Colors.black.withOpacity(0.45)),
              ),
            ),
            // Dossier — follows citizen
            Positioned(
              left: dx,
              top: dy,
              width: dossierW,
              child: Container(
                constraints: const BoxConstraints(maxHeight: dossierMaxH),
                decoration: BoxDecoration(
                  color: const Color(0xFF07070b).withOpacity(0.98),
                  border: Border.all(
                    color: accentColor.withOpacity(0.6),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withOpacity(0.15),
                      blurRadius: 20,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Color(0xFF111118)),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              'ID #${citizen.trackingId}',
                              style: TextStyle(
                                color: isVip
                                    ? const Color(0xFFff88ff)
                                    : const Color(0xFF39ff6a),
                                fontSize: 9,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              isVip ? '⭐ VIP DOSSIER' : 'CITIZEN DOSSIER',
                              style: TextStyle(
                                color: accentColor,
                                fontSize: 9,
                                letterSpacing: 3,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: game.closeProfile,
                              child: const Icon(
                                Icons.close,
                                color: Color(0xFF444455),
                                size: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Pixel portrait + basic info side by side
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Big pixel portrait with surveillance frame
                            Stack(
                              children: [
                                Container(
                                  width: 90,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: accentColor.withOpacity(0.5),
                                      width: 1.5,
                                    ),
                                    color: Colors.black,
                                    boxShadow: [
                                      BoxShadow(
                                        color: accentColor.withOpacity(0.15),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ],
                                  ),
                                  child: CustomPaint(
                                    size: const Size(90, 120),
                                    painter: _PortraitPainter(citizen: citizen),
                                  ),
                                ),
                                // Corner brackets
                                Positioned(
                                  top: 3,
                                  left: 3,
                                  child: CustomPaint(
                                    size: const Size(12, 12),
                                    painter: _CornerBracket(
                                      color: accentColor,
                                      tl: true,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 3,
                                  right: 3,
                                  child: CustomPaint(
                                    size: const Size(12, 12),
                                    painter: _CornerBracket(
                                      color: accentColor,
                                      tr: true,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 3,
                                  left: 3,
                                  child: CustomPaint(
                                    size: const Size(12, 12),
                                    painter: _CornerBracket(
                                      color: accentColor,
                                      bl: true,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  bottom: 3,
                                  right: 3,
                                  child: CustomPaint(
                                    size: const Size(12, 12),
                                    painter: _CornerBracket(
                                      color: accentColor,
                                      br: true,
                                    ),
                                  ),
                                ),
                                // Tracking ID at bottom of portrait
                                Positioned(
                                  bottom: 6,
                                  left: 0,
                                  right: 0,
                                  child: Center(
                                    child: Text(
                                      '#${citizen.trackingId.toString().padLeft(4, '0')}',
                                      style: TextStyle(
                                        color: accentColor.withOpacity(0.8),
                                        fontSize: 8,
                                        letterSpacing: 2,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                ),
                                // REC dot
                                Positioned(
                                  top: 6,
                                  left: 8,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 5,
                                        height: 5,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFff3355),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 3),
                                      const Text(
                                        'REC',
                                        style: TextStyle(
                                          color: Color(0xFFff3355),
                                          fontSize: 6,
                                          letterSpacing: 1,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Name with classification bar
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 3,
                                      horizontal: 6,
                                    ),
                                    color: accentColor.withOpacity(0.08),
                                    child: Text(
                                      citizen.name.toUpperCase(),
                                      style: const TextStyle(
                                        color: Color(0xFFdddde8),
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  _InfoRow(
                                    'AGE',
                                    '${citizen.age}',
                                    accentColor,
                                  ),
                                  const SizedBox(height: 4),
                                  _InfoRow(
                                    'ROLE',
                                    citizen.job.toUpperCase(),
                                    const Color(0xFF556677),
                                  ),
                                  const SizedBox(height: 4),
                                  _InfoRow(
                                    'STATUS',
                                    citizen.isTrulySuspicious &&
                                            citizen.dissidentType !=
                                                DissidentType.decoy
                                        ? 'FLAGGED FOR REVIEW'
                                        : 'UNDER OBSERVATION',
                                    citizen.isTrulySuspicious &&
                                            citizen.dissidentType !=
                                                DissidentType.decoy
                                        ? const Color(0xFFff3355)
                                        : const Color(0xFF39ff6a),
                                  ),
                                  if (isVip) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: const Color(
                                            0xFFff88ff,
                                          ).withOpacity(0.4),
                                        ),
                                        color: const Color(
                                          0xFFff88ff,
                                        ).withOpacity(0.08),
                                      ),
                                      child: const Text(
                                        '⭐ VIP — 3× SCORE BONUS',
                                        style: TextStyle(
                                          color: Color(0xFFff88ff),
                                          fontSize: 8,
                                          letterSpacing: 1,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Suspicion meter
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'SUSPICION LEVEL',
                                  style: TextStyle(
                                    color: Color(0xFF2a2a38),
                                    fontSize: 8,
                                    letterSpacing: 3,
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  '${(suspicionFrac * 100).toInt()}%',
                                  style: TextStyle(
                                    color: _suspColor(suspicionFrac),
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(1),
                              child: LinearProgressIndicator(
                                value: suspicionFrac,
                                backgroundColor: const Color(0xFF0d0d14),
                                valueColor: AlwaysStoppedAnimation(
                                  _suspColor(suspicionFrac),
                                ),
                                minHeight: 6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Flee warning
                      if (isPanicked && fleeP > 0)
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          color: const Color(0xFFff8800).withOpacity(0.08),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    '⚠ SUBJECT MAY FLEE',
                                    style: TextStyle(
                                      color: Color(0xFFff8800),
                                      fontSize: 9,
                                      letterSpacing: 2,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${((1 - fleeP) * 7).toInt()}s',
                                    style: const TextStyle(
                                      color: Color(0xFFff8800),
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              LinearProgressIndicator(
                                value: fleeP,
                                backgroundColor: const Color(0xFF1a1000),
                                valueColor: const AlwaysStoppedAnimation(
                                  Color(0xFFff8800),
                                ),
                                minHeight: 3,
                              ),
                            ],
                          ),
                        ),
                      // Inventory + clues
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _Lbl('INVENTORY'), const SizedBox(height: 5),
                            ...citizen.inventory.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 3),
                                child: Row(
                                  children: [
                                    const Text(
                                      '▸ ',
                                      style: TextStyle(
                                        color: Color(0xFFff4d00),
                                        fontSize: 10,
                                      ),
                                    ),
                                    Text(
                                      item,
                                      style: const TextStyle(
                                        color: Color(0xFF8899bb),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            _Lbl('SYSTEM ALERT'),
                            const SizedBox(height: 5),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFFff4d00,
                                ).withOpacity(0.05),
                                border: Border.all(
                                  color: const Color(
                                    0xFFff4d00,
                                  ).withOpacity(0.18),
                                ),
                              ),
                              child: Text(
                                citizen.systemHint,
                                style: const TextStyle(
                                  color: Color(0xFFff7755),
                                  fontSize: 11,
                                  height: 1.5,
                                ),
                              ),
                            ),
                            if (ca > 0) ...[
                              const SizedBox(height: 12),
                              _Lbl('OBSERVED BEHAVIOR'),
                              const SizedBox(height: 5),
                              ...citizen.clues
                                  .take(ca)
                                  .map(
                                    (c) => Container(
                                      margin: const EdgeInsets.only(bottom: 4),
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF0d1520),
                                        border: Border.all(
                                          color: const Color(0xFF1a2a3a),
                                        ),
                                      ),
                                      child: Text(
                                        c,
                                        style: const TextStyle(
                                          color: Color(0xFF6688aa),
                                          fontSize: 10,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ),
                            ],
                            if (showFalse) ...[
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFFffb347,
                                  ).withOpacity(0.04),
                                  border: Border.all(
                                    color: const Color(
                                      0xFFffb347,
                                    ).withOpacity(0.18),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      '⚠ ',
                                      style: TextStyle(
                                        color: Color(0xFFffb347),
                                        fontSize: 10,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        citizen.falseHint,
                                        style: const TextStyle(
                                          color: Color(0xFF887744),
                                          fontSize: 10,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            if (ca < citizen.clues.length &&
                                citizen.dissidentType !=
                                    DissidentType.master) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Observing... next clue in ${nextIn}s',
                                style: const TextStyle(
                                  color: Color(0xFF2a2a38),
                                  fontSize: 9,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                            const SizedBox(height: 14),
                            // FLAG / CLEAR buttons — bigger and clearer
                            Row(
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () =>
                                        game.makeDecision(citizen, true),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFff3355,
                                        ).withOpacity(0.1),
                                        border: Border.all(
                                          color: const Color(
                                            0xFFff3355,
                                          ).withOpacity(0.6),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          const Text(
                                            '⚑ FLAG',
                                            style: TextStyle(
                                              color: Color(0xFFff3355),
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 2,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          const Text(
                                            'SUSPICIOUS',
                                            style: TextStyle(
                                              color: Color(0xFF884455),
                                              fontSize: 8,
                                              letterSpacing: 2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () =>
                                        game.makeDecision(citizen, false),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 14,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF39ff6a,
                                        ).withOpacity(0.08),
                                        border: Border.all(
                                          color: const Color(
                                            0xFF39ff6a,
                                          ).withOpacity(0.5),
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Column(
                                        children: [
                                          const Text(
                                            '✓ CLEAR',
                                            style: TextStyle(
                                              color: Color(0xFF39ff6a),
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 2,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          const Text(
                                            'INNOCENT',
                                            style: TextStyle(
                                              color: Color(0xFF336644),
                                              fontSize: 8,
                                              letterSpacing: 2,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                      // Quest panel at bottom of profile
                      if (game.quests.isNotEmpty)
                        _QuestPanel(quests: game.quests),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Color _suspColor(double f) => f < 0.33
      ? const Color(0xFF39ff6a)
      : f < 0.66
      ? const Color(0xFFffb347)
      : const Color(0xFFff3355);
}

class _InfoRow extends StatelessWidget {
  final String label, value;
  final Color valueColor;
  const _InfoRow(this.label, this.value, this.valueColor);
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        '$label  ',
        style: const TextStyle(
          color: Color(0xFF333344),
          fontSize: 8,
          letterSpacing: 2,
        ),
      ),
      Flexible(
        child: Text(
          value,
          style: TextStyle(
            color: valueColor,
            fontSize: 9,
            letterSpacing: 1,
            fontWeight: FontWeight.bold,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ],
  );
}

class _CornerBracket extends CustomPainter {
  final Color color;
  final bool tl, tr, bl, br;
  const _CornerBracket({
    required this.color,
    this.tl = false,
    this.tr = false,
    this.bl = false,
    this.br = false,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withOpacity(0.7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    const s = 8.0;
    if (tl) {
      canvas.drawLine(Offset.zero, Offset(s, 0), p);
      canvas.drawLine(Offset.zero, Offset(0, s), p);
    }
    if (tr) {
      canvas.drawLine(Offset(size.width, 0), Offset(size.width - s, 0), p);
      canvas.drawLine(Offset(size.width, 0), Offset(size.width, s), p);
    }
    if (bl) {
      canvas.drawLine(Offset(0, size.height), Offset(s, size.height), p);
      canvas.drawLine(Offset(0, size.height), Offset(0, size.height - s), p);
    }
    if (br) {
      canvas.drawLine(
        Offset(size.width, size.height),
        Offset(size.width - s, size.height),
        p,
      );
      canvas.drawLine(
        Offset(size.width, size.height),
        Offset(size.width, size.height - s),
        p,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _PortraitPainter extends CustomPainter {
  final CitizenData citizen;
  _PortraitPainter({required this.citizen});
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;
    final cols = 10, rows = 18;
    final pw = size.width / cols, ph = size.height / rows;

    // Background gradient — dark top, slightly lighter bottom
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      p..color = const Color(0xFF06060e),
    );
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.6, size.width, size.height * 0.4),
      p..color = const Color(0xFF08080f),
    );

    void px(int c, int r, Color col, {double alpha = 1.0}) {
      canvas.drawRect(
        Rect.fromLTWH(c * pw + 0.5, r * ph + 0.5, pw - 1.0, ph - 1.0),
        p..color = col.withOpacity(alpha),
      );
    }

    final skin = citizen.skinColor;
    final torso = citizen.torsoColor;
    final legs = citizen.legsColor;
    final shoe = Color.lerp(legs, Colors.black, 0.5)!;
    final hatC = Color.lerp(torso, Colors.black, 0.4)!;
    final bodyC =
        citizen.isTrulySuspicious &&
            citizen.dissidentType != DissidentType.decoy
        ? Color.lerp(torso, const Color(0xFF220000), 0.18)!
        : torso;
    final slim = citizen.bodyShape == BodyShape.slim;

    // ── HAT ──
    switch (citizen.hatStyle) {
      case HatStyle.cap:
        for (int c = 3; c <= 6; c++) {
          px(c, 0, hatC);
          px(c, 1, hatC);
        }
        px(2, 1, hatC);
        px(7, 1, hatC);
        px(2, 2, hatC);
        break;
      case HatStyle.beanie:
        for (int c = 3; c <= 6; c++) px(c, 0, hatC);
        for (int c = 2; c <= 7; c++) px(c, 1, hatC);
        break;
      case HatStyle.hood:
        for (int c = 3; c <= 6; c++) {
          px(c, 0, hatC);
          px(c, 1, hatC);
        }
        px(2, 1, hatC);
        px(7, 1, hatC);
        px(2, 2, hatC);
        px(7, 2, hatC);
        px(2, 3, hatC);
        px(7, 3, hatC);
        break;
      case HatStyle.none:
        final hairColors = [
          const Color(0xFF1a0e00),
          const Color(0xFF3d2b1f),
          const Color(0xFF6b4c11),
          const Color(0xFFc8a050),
          const Color(0xFF888888),
          const Color(0xFF111111),
        ];
        final hair = hairColors[citizen.trackingId % hairColors.length];
        for (int c = 3; c <= 6; c++) {
          px(c, 0, hair);
          px(c, 1, hair);
        }
        px(2, 1, hair);
        px(7, 1, hair);
        break;
    }

    // ── HEAD ──
    for (int c = 3; c <= 6; c++) for (int r = 2; r <= 4; r++) px(c, r, skin);
    // eyes with slight highlight
    px(3, 3, const Color(0xFF111122));
    px(6, 3, const Color(0xFF111122));
    px(3, 3, const Color(0xFF334455), alpha: 0.3);
    px(6, 3, const Color(0xFF334455), alpha: 0.3);
    // mouth
    px(4, 4, Color.lerp(skin, Colors.black, 0.3)!);

    // ── NECK ──
    px(4, 5, skin);
    px(5, 5, skin);

    // ── TORSO ──
    final torsoW = slim ? [3, 4, 5, 6] : [2, 3, 4, 5, 6, 7];
    for (final c in torsoW) for (int r = 6; r <= 9; r++) px(c, r, bodyC);
    // highlight top of torso
    for (final c in torsoW) px(c, 6, Color.lerp(bodyC, Colors.white, 0.12)!);
    // belt
    for (final c in torsoW) px(c, 10, Color.lerp(bodyC, Colors.black, 0.35)!);

    // ── ARMS ──
    for (int r = 6; r <= 10; r++) {
      px(1, r, bodyC);
      px(8, r, bodyC);
    }
    px(1, 11, skin);
    px(8, 11, skin);

    // ── LEGS ──
    for (int r = 11; r <= 15; r++) {
      px(3, r, legs);
      px(4, r, Color.lerp(legs, Colors.black, 0.25)!);
      px(5, r, Color.lerp(legs, Colors.black, 0.25)!);
      px(6, r, legs);
    }

    // ── SHOES ──
    for (int c = 2; c <= 4; c++) px(c, 16, shoe);
    for (int c = 5; c <= 7; c++) px(c, 16, shoe);
    px(2, 17, shoe);
    px(3, 17, shoe);
    px(5, 17, shoe);
    px(6, 17, shoe);
    px(7, 17, shoe);

    // ── ACCESSORY ──
    final accC = Color.lerp(legs, Colors.black, 0.2)!;
    switch (citizen.accessory) {
      case AccessoryType.bag:
        for (int r = 8; r <= 11; r++) px(0, r, accC);
        px(0, 7, accC);
        px(0, 12, accC);
        break;
      case AccessoryType.backpack:
        for (int r = 7; r <= 11; r++)
          px(9, r, Color.lerp(accC, const Color(0xFF223344), 0.5)!);
        px(9, 6, Color.lerp(accC, const Color(0xFF223344), 0.5)!);
        break;
      case AccessoryType.briefcase:
        for (int r = 12; r <= 14; r++)
          px(9, r, Color.lerp(accC, const Color(0xFF1a1000), 0.3)!);
        px(9, 11, Color.lerp(accC, const Color(0xFF1a1000), 0.3)!);
        break;
      case AccessoryType.none:
        break;
    }

    // ── SCANLINES ──
    for (double y = 0; y < size.height; y += 2)
      canvas.drawRect(
        Rect.fromLTWH(0, y, size.width, 0.8),
        Paint()..color = Colors.black.withOpacity(0.14),
      );

    // ── GREEN TINT OVERLAY (surveillance feel) ──
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF00ff44).withOpacity(0.04),
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

class _QuestPanel extends StatelessWidget {
  final List<Quest> quests;
  const _QuestPanel({required this.quests});
  @override
  Widget build(BuildContext context) {
    final done = quests.every((q) => q.completed);
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: done ? const Color(0xFF39ff6a) : const Color(0xFF111118),
          ),
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                done ? '✓ ALL OBJECTIVES COMPLETE' : 'OBJECTIVES',
                style: TextStyle(
                  color: done
                      ? const Color(0xFF39ff6a)
                      : const Color(0xFF2a2a38),
                  fontSize: 8,
                  letterSpacing: 3,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (done) ...[
                const Spacer(),
                const Text(
                  'VICTORY PENDING',
                  style: TextStyle(
                    color: Color(0xFF39ff6a),
                    fontSize: 8,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          ...quests.map((q) {
            final frac = (q.progress / q.target).clamp(0.0, 1.0);
            final qcolor = q.completed
                ? const Color(0xFF39ff6a)
                : const Color(0xFF555577);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        q.completed ? '✓ ' : '○ ',
                        style: TextStyle(color: qcolor, fontSize: 10),
                      ),
                      Expanded(
                        child: Text(
                          q.title,
                          style: TextStyle(
                            color: qcolor,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      Text(
                        '${q.progress}/${q.target}',
                        style: TextStyle(
                          color: qcolor.withOpacity(0.7),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    q.description,
                    style: const TextStyle(
                      color: Color(0xFF333344),
                      fontSize: 8,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  LinearProgressIndicator(
                    value: frac,
                    backgroundColor: const Color(0xFF0d0d14),
                    valueColor: AlwaysStoppedAnimation(qcolor.withOpacity(0.7)),
                    minHeight: 2,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _Lbl extends StatelessWidget {
  final String t;
  const _Lbl(this.t);
  @override
  Widget build(BuildContext context) => Text(
    t,
    style: const TextStyle(
      color: Color(0xFF2a2a38),
      fontSize: 8,
      letterSpacing: 3,
    ),
  );
}

class _Btn extends StatelessWidget {
  final String label, sub;
  final Color color;
  final VoidCallback onTap;
  const _Btn({
    required this.label,
    required this.sub,
    required this.color,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
          Text(
            sub,
            style: TextStyle(
              color: color.withOpacity(0.45),
              fontSize: 8,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    ),
  );
}

// ─── GAME OVER ────────────────────────────────────────────────────────────────

class GameOverOverlay extends StatefulWidget {
  final TheWatcherGame game;
  const GameOverOverlay({super.key, required this.game});
  @override
  State<GameOverOverlay> createState() => _GameOverState();
}

class _GameOverState extends State<GameOverOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleIn;
  int _phase = 0;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..forward();
    _scaleIn = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.1, 0.4, curve: Curves.elasticOut),
    );
    Future.delayed(
      const Duration(milliseconds: 400),
      () => setState(() => _phase = 1),
    );
    Future.delayed(
      const Duration(milliseconds: 1200),
      () => setState(() => _phase = 2),
    );
    Future.delayed(
      const Duration(milliseconds: 2200),
      () => setState(() => _phase = 3),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Container(
          color: Colors.black.withOpacity(0.96),
          child: Stack(
            children: [
              Positioned.fill(
                child: CustomPaint(painter: ScanlinePainter(opacity: 0.04)),
              ),
              Positioned.fill(
                child: CustomPaint(
                  painter: VignettePainter(baseOpacity: 0.7, pulseOpacity: 0),
                ),
              ),
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_phase >= 0)
                      AnimatedOpacity(
                        opacity: _phase >= 1 ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 400),
                        child: Column(
                          children: [
                            Container(
                              width: 300,
                              height: 2,
                              color: const Color(0xFFff3355).withOpacity(0.8),
                              margin: const EdgeInsets.only(bottom: 16),
                            ),
                            Text(
                              game.gameOverReason == 'timeout'
                                  ? '▓▒░ TIME EXPIRED ░▒▓'
                                  : '▓▒░ SYSTEM OFFLINE ░▒▓',
                              style: const TextStyle(
                                color: Color(0xFFff3355),
                                fontSize: 10,
                                letterSpacing: 4,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    if (_phase >= 1)
                      Transform.scale(
                        scale: _scaleIn.value,
                        child: Column(
                          children: [
                            Text(
                              game.gameOverReason == 'timeout'
                                  ? 'TIME\nEXPIRED'
                                  : ' YOU HAVE\nBEEN\nREPLACED',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFFddddee),
                                fontSize: 44,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 6,
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              width: 200,
                              height: 1,
                              color: const Color(0xFFff3355).withOpacity(0.4),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              game.gameOverReason == 'timeout'
                                  ? '\u201cThe surveillance window closed.\nSubjects dispersed before\ndecisions could be made.\u201d'
                                  : '\u201c${game.wrongFlags} innocent ${game.wrongFlags == 1 ? "citizen" : "citizens"} flagged.\nThe system has recalibrated.\nA new operator has been assigned.\u201d',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Color(0xFF555566),
                                fontSize: 11,
                                height: 1.6,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 28),
                    if (_phase >= 2)
                      AnimatedOpacity(
                        opacity: 1.0,
                        duration: const Duration(milliseconds: 600),
                        child: Container(
                          width: 300,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF2a2a38)),
                            color: const Color(0xFF0a0a0e),
                          ),
                          child: Column(
                            children: [
                              const Text(
                                'INCIDENT REPORT',
                                style: TextStyle(
                                  color: Color(0xFF444455),
                                  fontSize: 8,
                                  letterSpacing: 4,
                                ),
                              ),
                              const SizedBox(height: 12),
                              _R(
                                'Final Score',
                                '${game.score}',
                                color: const Color(0xFFffb347),
                              ),
                              _R(
                                'Rounds survived',
                                '${game.round}',
                                color: const Color(0xFF6688aa),
                              ),
                              _R(
                                'Correct flags',
                                '${game.correctFlags}',
                                color: const Color(0xFF39ff6a),
                              ),
                              _R(
                                'Wrong flags',
                                '${game.wrongFlags}',
                                color: const Color(0xFFff3355),
                              ),
                              _R(
                                'Accuracy',
                                '${game.accuracy.toStringAsFixed(1)}%',
                                color: game.accuracy > 60
                                    ? const Color(0xFF39ff6a)
                                    : const Color(0xFFff3355),
                              ),
                              _R(
                                'Best streak',
                                '${game.streak}',
                                color: const Color(0xFFffff00),
                              ),
                            ],
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    if (_phase >= 3)
                      AnimatedOpacity(
                        opacity: 1.0,
                        duration: const Duration(milliseconds: 400),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            GestureDetector(
                              onTap: game.restart,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFFff4d00),
                                    width: 1.5,
                                  ),
                                  color: const Color(
                                    0xFFff4d00,
                                  ).withOpacity(0.08),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.refresh,
                                      color: Color(0xFFff4d00),
                                      size: 14,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'REINITIALIZE SYSTEM',
                                      style: TextStyle(
                                        color: Color(0xFFff4d00),
                                        fontSize: 11,
                                        letterSpacing: 3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            GestureDetector(
                              onTap: game.returnToTitle,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFF444455),
                                  ),
                                  color: Colors.transparent,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.arrow_back,
                                      color: Color(0xFF444455),
                                      size: 12,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'RETURN TO TITLE',
                                      style: TextStyle(
                                        color: Color(0xFF444455),
                                        fontSize: 10,
                                        letterSpacing: 3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),
                    if (_phase >= 3)
                      const Text(
                        'SURVEILLANCE DIVISION · CLASSIFIED',
                        style: TextStyle(
                          color: Color(0xFF222230),
                          fontSize: 8,
                          letterSpacing: 4,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _R extends StatelessWidget {
  final String l, v;
  final Color color;
  const _R(this.l, this.v, {required this.color});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Flexible(
          child: Text(
            l.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFF333344),
              fontSize: 9,
              letterSpacing: 2,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          v,
          style: TextStyle(
            color: color,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

// ─── VICTORY ──────────────────────────────────────────────────────────────────

class VictoryOverlay extends StatefulWidget {
  final TheWatcherGame game;
  const VictoryOverlay({super.key, required this.game});
  @override
  State<VictoryOverlay> createState() => _VictoryState();
}

class _VictoryState extends State<VictoryOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  int _phase = 0;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..forward();
    _scale = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.05, 0.35, curve: Curves.elasticOut),
    );
    Future.delayed(
      const Duration(milliseconds: 300),
      () => setState(() => _phase = 1),
    );
    Future.delayed(
      const Duration(milliseconds: 1000),
      () => setState(() => _phase = 2),
    );
    Future.delayed(
      const Duration(milliseconds: 2200),
      () => setState(() => _phase = 3),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (ctx, _) {
        return Material(
          color: Colors.transparent,
          child: Container(
            color: Colors.black.withOpacity(0.97),
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(painter: ScanlinePainter(opacity: 0.035)),
                ),
                Positioned.fill(
                  child: CustomPaint(
                    painter: VignettePainter(baseOpacity: 0.6, pulseOpacity: 0),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_phase >= 0)
                        AnimatedOpacity(
                          opacity: _phase >= 1 ? 1.0 : 0.0,
                          duration: const Duration(milliseconds: 500),
                          child: Column(
                            children: [
                              Container(
                                width: 320,
                                height: 2,
                                color: const Color(0xFF39ff6a).withOpacity(0.8),
                                margin: const EdgeInsets.only(bottom: 16),
                              ),
                              const Text(
                                '▓▒░ ALL OBJECTIVES COMPLETE ░▒▓',
                                style: TextStyle(
                                  color: Color(0xFF39ff6a),
                                  fontSize: 9,
                                  letterSpacing: 4,
                                ),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      if (_phase >= 1)
                        Transform.scale(
                          scale: _scale.value,
                          child: Column(
                            children: [
                              const Text(
                                'MISSION\nCOMPLETE',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFFddffd8),
                                  fontSize: 52,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 6,
                                  height: 0.95,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                width: 240,
                                height: 1,
                                color: const Color(0xFF39ff6a).withOpacity(0.4),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                '"Sector cleared.\nAll targets neutralized.\nYou are the system."',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Color(0xFF445544),
                                  fontSize: 11,
                                  height: 1.7,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 28),
                      if (_phase >= 2)
                        AnimatedOpacity(
                          opacity: 1.0,
                          duration: const Duration(milliseconds: 600),
                          child: Container(
                            width: 320,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: const Color(0xFF39ff6a).withOpacity(0.2),
                              ),
                              color: const Color(0xFF020e04),
                            ),
                            child: Column(
                              children: [
                                const Text(
                                  'OPERATION REPORT',
                                  style: TextStyle(
                                    color: Color(0xFF39ff6a),
                                    fontSize: 8,
                                    letterSpacing: 4,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _R(
                                  'Final Score',
                                  '${game.score}',
                                  color: const Color(0xFFffb347),
                                ),
                                _R(
                                  'Rounds completed',
                                  '${game.round}',
                                  color: const Color(0xFF6688aa),
                                ),
                                _R(
                                  'Correct flags',
                                  '${game.correctFlags}',
                                  color: const Color(0xFF39ff6a),
                                ),
                                _R(
                                  'Wrong flags',
                                  '${game.wrongFlags}',
                                  color: game.wrongFlags == 0
                                      ? const Color(0xFF39ff6a)
                                      : const Color(0xFFff3355),
                                ),
                                _R(
                                  'Accuracy',
                                  '${game.accuracy.toStringAsFixed(1)}%',
                                  color: game.accuracy > 80
                                      ? const Color(0xFF39ff6a)
                                      : const Color(0xFFffb347),
                                ),
                                _R(
                                  'Best streak',
                                  '${game.streak}',
                                  color: const Color(0xFFffff00),
                                ),
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  color: const Color(
                                    0xFF39ff6a,
                                  ).withOpacity(0.05),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(
                                        Icons.star,
                                        color: Color(0xFFffff00),
                                        size: 12,
                                      ),
                                      const SizedBox(width: 8),
                                      const Flexible(
                                        child: Text(
                                          '+500 BONUS — ALL SECTORS CLEARED',
                                          style: TextStyle(
                                            color: Color(0xFFffff00),
                                            fontSize: 9,
                                            letterSpacing: 1,
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 24),
                      if (_phase >= 3)
                        AnimatedOpacity(
                          opacity: 1.0,
                          duration: const Duration(milliseconds: 400),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  if (game.isMaxPreset)
                                    game.restart();
                                  else
                                    game.startGame(
                                      null,
                                      preset: game.nextPreset,
                                    );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(0xFF39ff6a),
                                      width: 1.5,
                                    ),
                                    color: const Color(
                                      0xFF39ff6a,
                                    ).withOpacity(0.08),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.arrow_upward,
                                        color: Color(0xFF39ff6a),
                                        size: 14,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        game.isMaxPreset
                                            ? 'NEW OPERATION'
                                            : 'ESCALATE — ${game.nextPreset.toUpperCase()}',
                                        style: const TextStyle(
                                          color: Color(0xFF39ff6a),
                                          fontSize: 11,
                                          letterSpacing: 3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              GestureDetector(
                                onTap: game.returnToTitle,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(0xFF444455),
                                    ),
                                    color: Colors.transparent,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.arrow_back,
                                        color: Color(0xFF444455),
                                        size: 12,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'RETURN TO TITLE',
                                        style: TextStyle(
                                          color: Color(0xFF444455),
                                          fontSize: 10,
                                          letterSpacing: 3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 8),
                      if (_phase >= 3)
                        const Text(
                          'SURVEILLANCE DIVISION · MISSION ACCOMPLISHED',
                          style: TextStyle(
                            color: Color(0xFF1a2a1a),
                            fontSize: 8,
                            letterSpacing: 4,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─── EVENT OVERLAY ────────────────────────────────────────────────────────────

class EventOverlay extends StatefulWidget {
  final TheWatcherGame game;
  const EventOverlay({super.key, required this.game});
  @override
  State<EventOverlay> createState() => _EventState();
}

class _EventState extends State<EventOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final ev = game.activeEvent;
    if (ev == null) return const SizedBox();
    final isBlackout = game.blackoutActive;
    // Blackout — full black screen
    if (isBlackout) {
      return Material(
        color: Colors.transparent,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (ctx, _) {
            return Container(
              color: Colors.black.withOpacity(_ctrl.value * 0.97),
              child: Center(
                child: Opacity(
                  opacity: _ctrl.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '▓▒░ SIGNAL LOST ░▒▓',
                        style: TextStyle(
                          color: Color(0xFF333344),
                          fontSize: 10,
                          letterSpacing: 4,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'CAMERA FEED INTERRUPTED',
                        style: TextStyle(
                          color: Color(0xFF222233),
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'RESTORING IN 3 SECONDS...',
                        style: TextStyle(
                          color: Color(0xFF1a1a28),
                          fontSize: 9,
                          letterSpacing: 4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      );
    }
    // Event banner — slides in from top
    Color evColor;
    IconData evIcon;
    switch (ev.type) {
      case EventType.tipOff:
        evColor = const Color(0xFF39ff6a);
        evIcon = Icons.wifi_tethering;
        break;
      case EventType.vipAlert:
        evColor = const Color(0xFFff88ff);
        evIcon = Icons.person;
        break;
      case EventType.rewind:
        evColor = const Color(0xFFffb347);
        evIcon = Icons.replay;
        break;
      default:
        evColor = const Color(0xFF6688aa);
        evIcon = Icons.info_outline;
    }
    return Material(
      color: Colors.transparent,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (ctx, _) {
          final slide = Curves.easeOutCubic.transform(_ctrl.value);
          return Align(
            alignment: Alignment.topCenter,
            child: Transform.translate(
              offset: Offset(0, -80 * (1 - slide)),
              child: Opacity(
                opacity: _ctrl.value,
                child: Container(
                  margin: const EdgeInsets.only(top: 100, left: 40, right: 40),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF07070b).withOpacity(0.97),
                    border: Border.all(
                      color: evColor.withOpacity(0.5),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: evColor.withOpacity(0.15),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(evIcon, color: evColor, size: 18),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            ev.title,
                            style: TextStyle(
                              color: evColor,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            ev.description,
                            style: TextStyle(
                              color: evColor.withOpacity(0.5),
                              fontSize: 9,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

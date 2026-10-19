
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import '../../models/experiment_config.dart';

class AudioImpairmentService {
  final Random _random = Random();

  DegradationCondition _condition =
      const DegradationCondition();

  final List<Timer> _pendingTimers = [];

  // Previous samples for the echo effect.
  Int16List _echoHistory = Int16List(0);
  int _echoPosition = 0;

  int packetsProcessed = 0;
  int packetsDropped = 0;
  int packetsSent = 0;

  bool _active = false;

  void configure(DegradationCondition condition) {
    stop();

    if (condition.packetLossPercent < 0 ||
        condition.packetLossPercent > 100 ||
        condition.delayMs < 0 ||
        condition.echoDelayMs < 1 ||
        condition.echoGain < 0 ||
        condition.echoGain > 1) {
      throw ArgumentError(
  'Invalid degradation settings: '
  'packetLoss=${condition.packetLossPercent}, '
  'delay=${condition.delayMs}, '
  'echoEnabled=${condition.echoEnabled}, '
  'echoDelay=${condition.echoDelayMs}, '
  'echoGain=${condition.echoGain}',
);
    }

    _condition = condition;

    final echoSamples =
        (48000 * condition.echoDelayMs / 1000).round();

    _echoHistory = Int16List(echoSamples);
    _echoPosition = 0;

    packetsProcessed = 0;
    packetsDropped = 0;
    packetsSent = 0;

    _active = true;
  }

  void process(
    Uint8List pcm,
    void Function(Uint8List) sendPacket,
  ) {
    if (!_active) return;

    packetsProcessed++;

    // 1. Random packet loss.
    if (_random.nextDouble() * 100 <
        _condition.packetLossPercent) {
      packetsDropped++;
      return;
    }

    // 2. Echo processing.
    final output = _condition.echoEnabled
        ? _addEcho(pcm)
        : Uint8List.fromList(pcm);

    // 3. Additional transmission delay.
    if (_condition.delayMs == 0) {
      if (_active) {
        sendPacket(output);
        packetsSent++;
      }
      return;
    }

    late Timer timer;

    timer = Timer(
      Duration(milliseconds: _condition.delayMs),
      () {
        _pendingTimers.remove(timer);

        if (!_active) return;

        sendPacket(output);
        packetsSent++;
      },
    );

    _pendingTimers.add(timer);
  }

  Uint8List _addEcho(Uint8List input) {
    final output = Uint8List(input.length);
    final source = ByteData.sublistView(input);
    final destination = ByteData.sublistView(output);

    final sampleCount = input.length ~/ 2;

    for (var i = 0; i < sampleCount; i++) {
      final current = source.getInt16(
        i * 2,
        Endian.little,
      );

      final delayed = _echoHistory[_echoPosition];

      final mixed = (
        current + delayed * _condition.echoGain
      ).round().clamp(-32768, 32767).toInt();

      destination.setInt16(
        i * 2,
        mixed,
        Endian.little,
      );

      _echoHistory[_echoPosition] = current;

      _echoPosition++;

      if (_echoPosition >= _echoHistory.length) {
        _echoPosition = 0;
      }
    }

    return output;
  }

  void stop() {
    _active = false;

    for (final timer in _pendingTimers) {
      timer.cancel();
    }

    _pendingTimers.clear();
  }

  void dispose() {
    stop();
  }
}

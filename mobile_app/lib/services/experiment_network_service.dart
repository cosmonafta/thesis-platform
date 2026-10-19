
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';

import '../models/discovered_experiment.dart';
import '../models/experiment_config.dart';

class ExperimentNetworkService {
  static const _channel =
      MethodChannel('sct/experiment_discovery');

  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _subscription;

  final _messages =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get messages =>
      _messages.stream;

  Completer<bool>? _joinCompleter;
  String? _pendingToken;
  String? _pendingHost;
  int? _pendingPort;

  String? connectedHost;
  int? connectedPort;

  bool get isConnected => connectedHost != null;

  Future<void> startHosting(String name) async {
    await _closeSocket();
    connectedHost = null;
    connectedPort = null;

    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      5001,
    );

    _listen(isHost: true);

    try {
      await _channel.invokeMethod('startHosting', {
        'name': name,
        'port': 5001,
      });
    } catch (_) {
      await _closeSocket();
      rethrow;
    }
  }

  Future<void> startDiscovery() =>
      _channel.invokeMethod('startDiscovery');

  Future<void> stopDiscovery() =>
      _channel.invokeMethod('stopDiscovery');

  Future<List<DiscoveredExperiment>>
      getExperiments() async {
    final result =
        await _channel.invokeMethod<List<dynamic>>(
      'getExperiments',
    );

    return (result ?? [])
        .map((item) =>
            DiscoveredExperiment.fromMap(item as Map))
        .toList();
  }

  Future<bool> join(
    DiscoveredExperiment experiment,
  ) async {
    await _closeSocket();
    connectedHost = null;
    connectedPort = null;

    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      0,
    );

    _listen(isHost: false);

    final host = experiment.host;
    final port = experiment.port;
    final token =
        '${DateTime.now().microsecondsSinceEpoch}'
        '-${Random().nextInt(1000000)}';

    _pendingToken = token;
    _pendingHost = host;
    _pendingPort = port;

    final completer = Completer<bool>();
    _joinCompleter = completer;

    for (var attempt = 0; attempt < 4; attempt++) {
      if (completer.isCompleted) break;

      _sendTo(host, port, {
        'type': 'join',
        'token': token,
      });

      await Future.any<Object?>([
        completer.future,
        Future<void>.delayed(
          const Duration(seconds: 1),
        ),
      ]);
    }

    final accepted =
        completer.isCompleted ? await completer.future : false;

    _joinCompleter = null;
    _pendingToken = null;
    _pendingHost = null;
    _pendingPort = null;

    if (!accepted) {
      await _closeSocket();
    }

    return accepted;
  }

  void send(Map<String, dynamic> message) {
    final host = connectedHost;
    final port = connectedPort;

    if (host == null || port == null) {
      throw StateError('No participant connected');
    }

    _sendTo(host, port, message);
  }

  void _sendTo(
    String host,
    int port,
    Map<String, dynamic> message,
  ) {
    _socket?.send(
      utf8.encode(jsonEncode(message)),
      InternetAddress(host),
      port,
    );
  }

  void _listen({required bool isHost}) {
    _subscription = _socket!.listen((event) {
      if (event != RawSocketEvent.read) return;

      Datagram? packet;

      while ((packet = _socket?.receive()) != null) {
        final datagram = packet!;

        try {
          final data = jsonDecode(
            utf8.decode(datagram.data),
          ) as Map<String, dynamic>;

          final sender = datagram.address.address;

          if (isHost && data['type'] == 'join') {
            final token = data['token'];
            if (token is! String) continue;

            final sameParticipant =
                connectedHost == sender &&
                connectedPort == datagram.port;

            if (connectedHost != null &&
                !sameParticipant) {
              continue;
            }

            final firstJoin = connectedHost == null;

            connectedHost = sender;
            connectedPort = datagram.port;

            _sendTo(sender, datagram.port, {
              'type': 'accepted',
              'token': token,
            });

            if (firstJoin && !_messages.isClosed) {
              _messages.add({'type': 'participant_joined'});
            }

            continue;
          }

          if (!isHost &&
              data['type'] == 'accepted' &&
              data['token'] == _pendingToken &&
              sender == _pendingHost &&
              datagram.port == _pendingPort) {
            connectedHost = sender;
            connectedPort = datagram.port;

            final completer = _joinCompleter;
            if (completer != null &&
                !completer.isCompleted) {
              completer.complete(true);
            }

            continue;
          }

          if (connectedHost != sender ||
              connectedPort != datagram.port) {
            continue;
          }

          if (!_messages.isClosed) {
            _messages.add(data);
          }
        } catch (_) {
          // Ignore unrelated or malformed UDP packets.
        }
      }
    });
  }

  Future<void> _closeSocket() async {
    final completer = _joinCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(false);
    }

    await _subscription?.cancel();
    _subscription = null;

    _socket?.close();
    _socket = null;
  }

  Future<void> dispose() async {
    try {
      await stopDiscovery();
    } catch (_) {}

    try {
      await _channel.invokeMethod('stopHosting');
    } catch (_) {}

    await _closeSocket();
    connectedHost = null;
    connectedPort = null;

    await _messages.close();
  }
}

// Convert the generated experiment into JSON-compatible data.
Map<String, dynamic> experimentToMap(
  ExperimentConfig experiment,
) {
  return {
    'id': experiment.id,
    'name': experiment.name,
    'tests': experiment.tests.map((test) {
      return {
        'testNumber': test.testNumber,
        'scenarioId': test.scenarioId,
        'condition': {
          'packetLossPercent':
              test.condition.packetLossPercent,
          'delayMs': test.condition.delayMs,
          'echoEnabled': test.condition.echoEnabled,
          'echoDelayMs': test.condition.echoDelayMs,
          'echoGain': test.condition.echoGain,
        },
      };
    }).toList(),
  };
}

// Rebuild the same experiment on the second phone.
ExperimentConfig experimentFromMap(
  Map<String, dynamic> map,
) {
  final tests = (map['tests'] as List).map((item) {
    final test = item as Map<String, dynamic>;
    final condition =
        test['condition'] as Map<String, dynamic>;

    return ExperimentTest(
      testNumber: (test['testNumber'] as num).toInt(),
      scenarioId: (test['scenarioId'] as num).toInt(),
      condition: DegradationCondition(
        packetLossPercent:
            (condition['packetLossPercent'] as num)
                .toDouble(),
        delayMs: (condition['delayMs'] as num).toInt(),
        echoEnabled: condition['echoEnabled'] as bool,
        echoDelayMs:
            (condition['echoDelayMs'] as num).toInt(),
        echoGain:
            (condition['echoGain'] as num).toDouble(),
      ),
    );
  }).toList();

  return ExperimentConfig(
    id: map['id'] as String,
    name: map['name'] as String,
    tests: tests,
  );
}

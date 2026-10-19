import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

class AudioTransportService {
  RawDatagramSocket? _socket;

  Function(Uint8List)? onAudioReceived;

  // ============================================================
  // PING VARIABLES
  // ============================================================

  int _pingCounter = 0;
  final Map<int, Stopwatch> _pendingPings = {};

  // ============================================================
  // AUDIO SEQUENCE VARIABLES
  // ============================================================

  int _audioSequenceNumber = 0;

  int? _lastReceivedSequence;

  int _receivedAudioPackets = 0;
  int _lostAudioPackets = 0;
  int _outOfOrderPackets = 0;

  // ============================================================
  // PACKET ARRIVAL TIMING
  // ============================================================

  int? _lastAudioArrivalMicros;

  int _timingSamples = 0;

  double _totalArrivalIntervalMs = 0;

  double _minArrivalIntervalMs = double.infinity;

  double _maxArrivalIntervalMs = 0;

  int _latePackets = 0;

  // ============================================================
  // START UDP
  // ============================================================

  Future<void> start({
    int port = 5000,
  }) async {
    if (_socket != null) {
      print('UDP socket is already running');
      return;
    }

    // Start every test with clean statistics
    // and a fresh sequence number.
    resetAudioStatistics();

    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      port,
    );

    print('UDP listening on port $port');

    _socket!.listen((RawSocketEvent event) {
      if (event != RawSocketEvent.read) {
        return;
      }

      final datagram = _socket!.receive();

      if (datagram == null) {
        return;
      }

      _handleDatagram(datagram);
    });
  }

  // ============================================================
  // HANDLE RECEIVED UDP PACKET
  // ============================================================

  void _handleDatagram(Datagram datagram) {
    final data = datagram.data;

    // ==========================================================
    // CONTROL PACKETS: PING / PONG / UDP TEST
    // ==========================================================

    if (data.length < 100) {
      final message = utf8.decode(
        data,
        allowMalformed: true,
      );

      // --------------------------------------------------------
      // PING
      // --------------------------------------------------------

      if (message.startsWith('PING:')) {
        final pingId = message.substring(5);

        print(
          'PING $pingId received from '
          '${datagram.address.address}:${datagram.port}',
        );

        final pong = 'PONG:$pingId';

        _socket?.send(
          utf8.encode(pong),
          datagram.address,
          datagram.port,
        );

        print('PONG $pingId sent');

        return;
      }

      // --------------------------------------------------------
      // PONG
      // --------------------------------------------------------

      if (message.startsWith('PONG:')) {
        final pingId = int.tryParse(
          message.substring(5),
        );

        if (pingId == null) {
          return;
        }

        final stopwatch = _pendingPings.remove(
          pingId,
        );

        if (stopwatch == null) {
          return;
        }

        stopwatch.stop();

        final rttMilliseconds =
            stopwatch.elapsedMicroseconds / 1000.0;

        final estimatedOneWay =
            rttMilliseconds / 2.0;

        print('');
        print('========================================');
        print('PING $pingId RESULT');
        print(
          'UDP RTT: '
          '${rttMilliseconds.toStringAsFixed(2)} ms',
        );
        print(
          'Estimated one-way UDP delay: '
          '${estimatedOneWay.toStringAsFixed(2)} ms',
        );
        print('========================================');
        print('');

        return;
      }

      // --------------------------------------------------------
      // SIMPLE UDP TEST
      // --------------------------------------------------------

      if (message == 'UDP TEST') {
        print(
          'UDP TEST received from '
          '${datagram.address.address}:${datagram.port}',
        );

        return;
      }
    }

    // ==========================================================
    // AUDIO PACKET
    // ==========================================================
    //
    // Packet structure:
    //
    // bytes 0-3   = sequence number
    // bytes 4-... = PCM audio
    //
    // Normal packet:
    //
    // 4-byte sequence number
    // +
    // 960-byte PCM payload
    // =
    // 964 bytes total
    // ==========================================================

    if (data.length < 5) {
      print('Invalid audio packet');
      return;
    }

    final byteData = ByteData.sublistView(
      data,
    );

    final sequenceNumber = byteData.getUint32(
      0,
      Endian.big,
    );

    final audioData = Uint8List.sublistView(
      data,
      4,
    );

    _receivedAudioPackets++;

    // ==========================================================
    // MEASURE PACKET ARRIVAL TIMING
    // ==========================================================
    //
    // Each audio packet contains approximately
    // 10 ms of PCM audio.
    //
    // Ideally packets should therefore arrive
    // roughly every 10 ms.
    //
    // We measure the time between consecutive
    // UDP audio packets.
    // ==========================================================

    final arrivalMicros =
        DateTime.now().microsecondsSinceEpoch;

    if (_lastAudioArrivalMicros != null) {
      final intervalMs =
          (arrivalMicros - _lastAudioArrivalMicros!) /
              1000.0;

      _timingSamples++;

      _totalArrivalIntervalMs += intervalMs;

      if (intervalMs < _minArrivalIntervalMs) {
        _minArrivalIntervalMs = intervalMs;
      }

      if (intervalMs > _maxArrivalIntervalMs) {
        _maxArrivalIntervalMs = intervalMs;
      }

      // We currently define an arrival as "late"
      // when more than 20 ms passed since the
      // previous packet.
      //
      // This is only a diagnostic threshold.
      if (intervalMs > 20.0) {
        _latePackets++;
      }
    }

    _lastAudioArrivalMicros = arrivalMicros;

    // ==========================================================
    // SEQUENCE NUMBER CHECK
    // ==========================================================

    if (_lastReceivedSequence != null) {
      final expectedSequence =
          _lastReceivedSequence! + 1;

      // --------------------------------------------------------
      // PACKET LOSS
      // --------------------------------------------------------

      if (sequenceNumber > expectedSequence) {
        final missingPackets =
            sequenceNumber - expectedSequence;

        _lostAudioPackets += missingPackets;

        print('');
        print('!!!!!!!! PACKET LOSS !!!!!!!!');
        print('Expected: $expectedSequence');
        print('Received: $sequenceNumber');
        print('Missing packets: $missingPackets');
        print('Total missing: $_lostAudioPackets');
        print('!!!!!!!!!!!!!!!!!!!!!!!!!!!!!');
        print('');
      }

      // --------------------------------------------------------
      // OUT OF ORDER
      // --------------------------------------------------------

      else if (sequenceNumber < expectedSequence) {
        _outOfOrderPackets++;

        print('');
        print('<<<< OUT OF ORDER PACKET >>>>');
        print('Expected: $expectedSequence');
        print('Received: $sequenceNumber');
        print(
          'Total out of order: '
          '$_outOfOrderPackets',
        );
        print('<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<');
        print('');
      }
    }

    _lastReceivedSequence = sequenceNumber;

    // ==========================================================
    // PRINT STATISTICS EVERY 100 PACKETS
    // ==========================================================

    if (_receivedAudioPackets % 100 == 0) {
      print('');
      print('-------- AUDIO STATS --------');

      print(
        'Last sequence: $sequenceNumber',
      );

      print(
        'Received packets: '
        '$_receivedAudioPackets',
      );

      print(
        'Missing packets: '
        '$_lostAudioPackets',
      );

      print(
        'Out-of-order packets: '
        '$_outOfOrderPackets',
      );

      // --------------------------------------------------------
      // TIMING STATISTICS
      // --------------------------------------------------------

      if (_timingSamples > 0) {
        final averageInterval =
            _totalArrivalIntervalMs /
                _timingSamples;

        print(
          'Average arrival interval: '
          '${averageInterval.toStringAsFixed(2)} ms',
        );

        print(
          'Minimum arrival interval: '
          '${_minArrivalIntervalMs.toStringAsFixed(2)} ms',
        );

        print(
          'Maximum arrival interval: '
          '${_maxArrivalIntervalMs.toStringAsFixed(2)} ms',
        );

        print(
          'Late arrivals (>20 ms): '
          '$_latePackets',
        );
      }

      print('-----------------------------');
      print('');
    }

    // ==========================================================
    // SEND PCM TO PLAYBACK
    // ==========================================================

    onAudioReceived?.call(
      audioData,
    );
  }

  // ============================================================
  // SEND AUDIO
  // ============================================================

  void sendAudio(
    Uint8List audioData,
    String targetIp,
    int targetPort,
  ) {
    if (_socket == null) {
      print(
        'UDP socket has not been started',
      );

      return;
    }

    // PCM16 mono 48 kHz
    //
    // 48,000 samples/sec
    // × 0.010 sec
    // × 2 bytes/sample
    //
    // = 960 bytes
    //
    // Therefore each packet represents
    // approximately 10 ms of audio.

    const audioPayloadSize = 960;

    for (
      int offset = 0;
      offset < audioData.length;
      offset += audioPayloadSize
    ) {
      final end =
          (offset + audioPayloadSize <
                  audioData.length)
              ? offset + audioPayloadSize
              : audioData.length;

      final audioChunk =
          Uint8List.sublistView(
        audioData,
        offset,
        end,
      );

      // 4 bytes for sequence number
      // + PCM audio data
      final packet = Uint8List(
        4 + audioChunk.length,
      );

      final byteData =
          ByteData.sublistView(
        packet,
      );

      // Store sequence number
      // in first 4 bytes.
      byteData.setUint32(
        0,
        _audioSequenceNumber,
        Endian.big,
      );

      // Store PCM audio after header.
      packet.setRange(
        4,
        packet.length,
        audioChunk,
      );

      _socket!.send(
        packet,
        InternetAddress(
          targetIp,
        ),
        targetPort,
      );

      _audioSequenceNumber++;
    }
  }

  // ============================================================
  // SEND PING
  // ============================================================

  void sendPing(
    String targetIp,
    int targetPort,
  ) {
    if (_socket == null) {
      print(
        'UDP socket has not been started',
      );

      return;
    }

    _pingCounter++;

    final pingId = _pingCounter;

    final stopwatch =
        Stopwatch()..start();

    _pendingPings[pingId] =
        stopwatch;

    final message =
        'PING:$pingId';

    _socket!.send(
      utf8.encode(message),
      InternetAddress(
        targetIp,
      ),
      targetPort,
    );

    print(
      'PING $pingId sent to '
      '$targetIp:$targetPort',
    );
  }

  // ============================================================
  // SEND SIMPLE UDP TEST
  // ============================================================

  void sendTest(
    String targetIp,
    int targetPort,
  ) {
    if (_socket == null) {
      print(
        'UDP socket has not been started',
      );

      return;
    }

    final message =
        utf8.encode(
      'UDP TEST',
    );

    _socket!.send(
      message,
      InternetAddress(
        targetIp,
      ),
      targetPort,
    );

    print(
      'UDP test sent to '
      '$targetIp:$targetPort',
    );
  }

  // ============================================================
  // PRINT AUDIO STATISTICS
  // ============================================================

  void printAudioStatistics() {
    print('');
    print('========================================');
    print('AUDIO PACKET STATISTICS');
    print('========================================');

    print(
      'Received packets: '
      '$_receivedAudioPackets',
    );

    print(
      'Missing packets: '
      '$_lostAudioPackets',
    );

    print(
      'Out-of-order packets: '
      '$_outOfOrderPackets',
    );

    final expectedPackets =
        _receivedAudioPackets +
            _lostAudioPackets;

    if (expectedPackets > 0) {
      final lossPercentage =
          (_lostAudioPackets /
                  expectedPackets) *
              100;

      print(
        'Estimated packet loss: '
        '${lossPercentage.toStringAsFixed(3)} %',
      );
    }

    // ==========================================================
    // TIMING STATISTICS
    // ==========================================================

    if (_timingSamples > 0) {
      final averageInterval =
          _totalArrivalIntervalMs /
              _timingSamples;

      print('');
      print('PACKET ARRIVAL TIMING');

      print(
        'Average arrival interval: '
        '${averageInterval.toStringAsFixed(2)} ms',
      );

      print(
        'Minimum arrival interval: '
        '${_minArrivalIntervalMs.toStringAsFixed(2)} ms',
      );

      print(
        'Maximum arrival interval: '
        '${_maxArrivalIntervalMs.toStringAsFixed(2)} ms',
      );

      print(
        'Late arrivals (>20 ms): '
        '$_latePackets',
      );
    }

    print('========================================');
    print('');
  }

  // ============================================================
  // RESET AUDIO STATISTICS
  // ============================================================

  void resetAudioStatistics() {
    // Reset sender sequence number.
    _audioSequenceNumber = 0;

    // Reset receiver sequence state.
    _lastReceivedSequence = null;

    _receivedAudioPackets = 0;
    _lostAudioPackets = 0;
    _outOfOrderPackets = 0;

    // Reset timing statistics.
    _lastAudioArrivalMicros = null;

    _timingSamples = 0;

    _totalArrivalIntervalMs = 0;

    _minArrivalIntervalMs =
        double.infinity;

    _maxArrivalIntervalMs = 0;

    _latePackets = 0;

    print('');
    print('========================================');
    print('AUDIO STATISTICS RESET');
    print('Sequence number reset to 0');
    print('Timing statistics reset');
    print('========================================');
    print('');
  }

  // ============================================================
  // STOP UDP
  // ============================================================

  void stop() {
    for (
      final stopwatch
          in _pendingPings.values
    ) {
      stopwatch.stop();
    }

    _pendingPings.clear();

    _socket?.close();
    _socket = null;

    print('UDP stopped');
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  void dispose() {
    stop();
  }
}
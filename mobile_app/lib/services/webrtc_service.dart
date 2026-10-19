import 'package:flutter_webrtc/flutter_webrtc.dart';

class WebRTCService {
  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;

  Function(RTCIceCandidate)? onIceCandidate;
  Function(RTCPeerConnectionState)? onConnectionStateChanged;
  Function(String)? onRemoteTrackReceived;

  Future<void> initialize() async {
    final configuration = {
      "iceServers": [
        {"urls": "stun:stun.l.google.com:19302"},
      ],
    };

    peerConnection = await createPeerConnection(configuration);

    peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
      onIceCandidate?.call(candidate);
    };

    peerConnection!.onConnectionState =
        (RTCPeerConnectionState state) {
      onConnectionStateChanged?.call(state);
    };

    peerConnection!.onTrack = (RTCTrackEvent event) {
      if (event.streams.isNotEmpty) {
        remoteStream = event.streams[0];
      }

onRemoteTrackReceived?.call(event.track.kind ?? "unknown");    };

    localStream = await navigator.mediaDevices.getUserMedia({
      "audio": true,
      "video": false,
    });

    for (final track in localStream!.getTracks()) {
      await peerConnection!.addTrack(track, localStream!);
    }
  }

  Future<RTCSessionDescription?> createOffer() async {
    if (peerConnection == null) return null;

    final offer = await peerConnection!.createOffer();
    await peerConnection!.setLocalDescription(offer);

    return offer;
  }

  Future<RTCSessionDescription?> handleOffer(dynamic offer) async {
    if (peerConnection == null) return null;

    await peerConnection!.setRemoteDescription(
      RTCSessionDescription(
        offer["sdp"],
        offer["type"],
      ),
    );

    final answer = await peerConnection!.createAnswer();
    await peerConnection!.setLocalDescription(answer);

    return answer;
  }

  Future<void> handleAnswer(dynamic answer) async {
    if (peerConnection == null) return;

    await peerConnection!.setRemoteDescription(
      RTCSessionDescription(
        answer["sdp"],
        answer["type"],
      ),
    );
  }

  Future<void> addIceCandidate(dynamic candidate) async {
    if (peerConnection == null || candidate == null) return;

    await peerConnection!.addCandidate(
      RTCIceCandidate(
        candidate["candidate"],
        candidate["sdpMid"],
        candidate["sdpMLineIndex"],
      ),
    );
  }

  void dispose() {
    localStream?.dispose();
    remoteStream?.dispose();
    peerConnection?.close();
  }
}
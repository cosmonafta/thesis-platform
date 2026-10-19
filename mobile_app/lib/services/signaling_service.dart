import 'package:socket_io_client/socket_io_client.dart' as IO;

class SignalingService {
  late IO.Socket socket;

  Function()? onConnected;
  Function()? onDisconnected;

  Function(dynamic)? onRoomUsers;
  Function(dynamic)? onUserJoined;
  Function(dynamic)? onOffer;
  Function(dynamic)? onAnswer;
  Function(dynamic)? onIceCandidate;

  void connect() {
    socket = IO.io(
      'http://192.168.1.8:3000',
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    socket.connect();

    socket.onConnect((_) {
      onConnected?.call();
    });

    socket.onDisconnect((_) {
      onDisconnected?.call();
    });

    socket.on("room-users", (data) {
      onRoomUsers?.call(data);
    });

    socket.on("user-joined", (data) {
      onUserJoined?.call(data);
    });

    socket.on("offer", (data) {
      onOffer?.call(data);
    });

    socket.on("answer", (data) {
      onAnswer?.call(data);
    });

    socket.on("ice-candidate", (data) {
      onIceCandidate?.call(data);
    });
  }

  void joinRoom(String roomId) {
    socket.emit("join-room", roomId);
  }

  void sendOffer(String roomId, dynamic offer) {
    socket.emit("offer", {
      "roomId": roomId,
      "offer": offer,
    });
  }

  void sendAnswer(String roomId, dynamic answer) {
    socket.emit("answer", {
      "roomId": roomId,
      "answer": answer,
    });
  }

  void sendIceCandidate(String roomId, dynamic candidate) {
    socket.emit("ice-candidate", {
      "roomId": roomId,
      "candidate": candidate,
    });
  }

  void dispose() {
    socket.dispose();
  }
}
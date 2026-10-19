const express = require("express");
const http = require("http");
const { Server } = require("socket.io");
const cors = require("cors");

const app = express();
app.use(cors());

const server = http.createServer(app);

const io = new Server(server, {
  cors: { origin: "*" },
});

app.get("/", (req, res) => {
  res.send("Signaling server is running");
});

io.on("connection", (socket) => {
  console.log("User connected:", socket.id);

  socket.on("join-room", (roomId) => {
    socket.join(roomId);

    const room = io.sockets.adapter.rooms.get(roomId);
    const userCount = room ? room.size : 0;

    console.log(`${socket.id} joined room ${roomId}. Users: ${userCount}`);

    io.to(roomId).emit("room-users", {
      roomId,
      userCount,
    });

    socket.to(roomId).emit("user-joined", {
      socketId: socket.id,
    });
  });

  socket.on("offer", ({ roomId, offer }) => {
    console.log("Offer received");
    socket.to(roomId).emit("offer", {
      offer,
      sender: socket.id,
    });
  });

  socket.on("answer", ({ roomId, answer }) => {
    console.log("Answer received");
    socket.to(roomId).emit("answer", {
      answer,
      sender: socket.id,
    });
  });

  socket.on("ice-candidate", ({ roomId, candidate }) => {
    socket.to(roomId).emit("ice-candidate", {
      candidate,
      sender: socket.id,
    });
  });

  socket.on("disconnect", () => {
    console.log("User disconnected:", socket.id);
  });
});

server.listen(3000, () => {
  console.log("Server running on http://localhost:3000");
});
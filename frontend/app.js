const websocket_url = "ws://42c5ff47.execute-api.localhost:4566/local";

const ws = new WebSocket(websocket_url);
console.log(ws);
ws.addEventListener("open", (event) => {
  console.log(event);
});

ws.addEventListener("close", (event) => {
  console.log(event);
});

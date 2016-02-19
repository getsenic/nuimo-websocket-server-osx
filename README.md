# Nuimo WebSocket Server for OS X

Any application that supports WebSockets can now communicate with Nuimo.

<img src="https://raw.githubusercontent.com/getsenic/nuimo-websocket-server-osx/master/screenshot.png" alt="Nuimo WebSocket Server for OS X">

## How to use

1. Start Nuimo WebSocket Server
2. Enable your Mac's Bluetooth and power on Nuimo. Nuimo WebSocket Server automatically connects to your Nuimo.
3. Open a WebSocket to port 8080 (or the port number you've chosen)
4. Receive all Nuimo events by reading from the WebSocket
5. Write to the WebSocket to modify Nuimo's LED Matrix

JavaScript example:

```javascript
var ws = new WebSocket('ws://localhost:8080/');

ws.onopen = function() {
  ws.send(
    '    *    ' +
    '   ***   ' +
    '  *****  ' +
    ' ******* ' +
    '*********' +
    ' ******* ' +
    '  *****  ' +
    '   ***   ' +
    '    *    ')
}

ws.onmessage = function(event) {
  console.log('Received Nuimo event: ' + event.data);
};
```

## Support

Visit https://www.senic.com/developers

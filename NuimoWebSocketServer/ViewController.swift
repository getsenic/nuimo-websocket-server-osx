//
//  ViewController.swift
//  NuimoWebSocketServer
//
//  Created by Lars Blumberg on 2/18/16.
//  Copyright © 2016 senic. All rights reserved.
//

import Cocoa
import PocketSocket
import NuimoSwift

class ViewController: NSViewController {

    @IBOutlet var arrayController: NSArrayController!
    @IBOutlet weak var nuimoStatusTextField: NSTextField!
    @IBOutlet weak var portTextField: NSTextField!
    @IBOutlet weak var startStopButton: NSButton!
    @IBOutlet var logTextView: NSTextView!

    var discoveringNuimo = false
    var nuimoController: NuimoController?
    var server: PSWebSocketServer?
    var sockets = [PSWebSocket]()
    var firmwareVersion: String?
    var batteryLevel: Int?

    override func viewDidLoad() {
        super.viewDidLoad()
        NuimoDiscoveryManager.sharedManager.delegate = self
        NuimoDiscoveryManager.sharedManager.startDiscovery()
        showNuimoStatus("Discovering...")
    }

    func showNuimoStatus(status: String) {
        nuimoStatusTextField.stringValue = status
    }

    @IBAction func startStopServer(sender: AnyObject) {
        nuimoController?.disconnect()
        nuimoController = nil

        if let _ = server {
            stopServer()
        }
        else {
            guard let nuimoController = arrayController.selectedObjects.first as? NuimoController else { return }
            self.nuimoController = nuimoController
            nuimoController.delegate = self
            nuimoController.connect()
        }
    }

    func startServer() {
        guard let port = UInt(portTextField.stringValue) else { return }
        server = PSWebSocketServer(host: nil, port: port)
        server?.delegate = self
        server?.start()
        startStopButton.title = "Stop"
    }

    func stopServer() {
        server?.stop()
        server = nil
        startStopButton.title = "Start"
    }

    func log(message: String) {
        logTextView.textStorage?.appendAttributedString(NSAttributedString(string: "\(message)\n"))
    }

    func sendFirmwareVersion(sockets: [PSWebSocket]) {
        guard let firmwareVersion = firmwareVersion else { return }
        sockets.forEach{ $0.send("V\(firmwareVersion)") }
    }

    func sendBatteryLevel(sockets: [PSWebSocket]) {
        guard let batteryLevel = batteryLevel else { return }
        sockets.forEach{ $0.send("%\(batteryLevel)") }
    }
}

extension ViewController: PSWebSocketServerDelegate {

    func serverDidStart(server: PSWebSocketServer!) {
        log("Server started")
    }

    func server(server: PSWebSocketServer!, didFailWithError error: NSError!) {
        log("Server failed: \(error.localizedDescription), \(error.localizedFailureReason ?? "")")
        sockets = []
    }

    func serverDidStop(server: PSWebSocketServer!) {
        log("Server stopped")
        sockets = []
    }

    func server(server: PSWebSocketServer!, acceptWebSocketWithRequest request: NSURLRequest!) -> Bool {
        return true
    }

    func server(server: PSWebSocketServer!, webSocketDidOpen webSocket: PSWebSocket!) {
        log("WebSocket opened")
        sockets.append(webSocket)
        sendFirmwareVersion([webSocket])
        sendBatteryLevel([webSocket])
    }

    func server(server: PSWebSocketServer!, webSocket: PSWebSocket!, didReceiveMessage message: AnyObject!) {
        log("WebSocket received: '\(message)'")
        nuimoController?.writeMatrix(NuimoLEDMatrix(string: "\(message)"))
    }

    func server(server: PSWebSocketServer!, webSocket: PSWebSocket!, didCloseWithCode code: Int, reason: String!, wasClean: Bool) {
        log("WebSocket closed")
        sockets = sockets.filter{ $0 != webSocket }
    }

    func server(server: PSWebSocketServer!, webSocket: PSWebSocket!, didFailWithError error: NSError!) {
        log("WebSocket failed: \(error.localizedDescription), \(error.localizedFailureReason ?? "")")
    }
}

extension ViewController: NuimoDiscoveryDelegate {

    func nuimoDiscoveryManager(discovery: NuimoDiscoveryManager, didDiscoverNuimoController controller: NuimoController) {
        arrayController.addObject(controller)
    }
}

extension ViewController: NuimoControllerDelegate {

    func nuimoController(controller: NuimoController, didChangeConnectionState state: NuimoConnectionState, withError error: NSError?) {
        switch state {
        case .Connecting:
            showNuimoStatus("Connecting...")
        case .Connected:
            showNuimoStatus("Connected")
            startServer()
        case .Disconnecting:
            showNuimoStatus("Disconnecting...")
        case .Disconnected:
            showNuimoStatus("Discovering...")
            stopServer()
        case .Invalidated:
            showNuimoStatus("Discovering...")
            stopServer()
            arrayController.removeObject(controller)
        }
        if let error = error {
            log("Nuimo connection failed: \(error.localizedDescription) \(error.localizedFailureReason ?? "")")
        }
    }

    func nuimoController(controller: NuimoController, didReceiveGestureEvent event: NuimoGestureEvent) {
        guard let event: String? = { switch (event.gesture) {
            case .ButtonPress:   return "B,1"
            case .ButtonRelease: return "B,0"
            case .Rotate:        return "R,\(event.value ?? 0)"
            case .SwipeLeft:     return "S,L"
            case .SwipeRight:    return "S,R"
            case .SwipeUp:       return "S,U"
            case .SwipeDown:     return "S,D"
            case .TouchLeft:     return "T,L"
            case .TouchRight:    return "T,R"
            case .TouchTop:      return "T,T"
            case .TouchBottom:   return "T,B"
            case .FlyLeft:       return "F,L"
            case .FlyRight:      return "F,R"
            case .FlyBackwards:  return "F,B"
            case .FlyTowards:    return "F,T"
            default:             return nil
        }}() else { return }
        sockets.forEach{
            $0.send(event)
        }
    }

    func nuimoController(controller: NuimoController, didReadFirmwareVersion firmwareVersion: String) {
        self.firmwareVersion = firmwareVersion
        sendFirmwareVersion(sockets)
    }

    func nuimoController(controller: NuimoController, didUpdateBatteryLevel batteryLevel: Int) {
        self.batteryLevel = batteryLevel
        sendBatteryLevel(sockets)
    }
}

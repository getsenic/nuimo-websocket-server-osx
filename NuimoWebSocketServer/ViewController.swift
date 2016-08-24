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

class ViewController: NSViewController, PSWebSocketServerDelegate, NuimoDiscoveryDelegate, NuimoControllerDelegate {

    @IBOutlet var arrayController: NSArrayController!
    @IBOutlet weak var nuimoStatusTextField: NSTextField!
    @IBOutlet weak var portTextField: NSTextField!
    @IBOutlet weak var startStopButton: NSButton!
    @IBOutlet var logTextView: NSTextView!

    var discoveringNuimo = false
    var nuimoController: NuimoController?
    var server: PSWebSocketServer?
    var sockets = [PSWebSocket]()

    override func viewDidLoad() {
        super.viewDidLoad()
        discoverNuimo()
    }

    func discoverNuimo(reason: String = "") {
        guard !discoveringNuimo else { return }
        nuimoStatusTextField.stringValue = "\(reason) Discovering..."
        NuimoDiscoveryManager.sharedManager.delegate = self
        NuimoDiscoveryManager.sharedManager.startDiscovery()
    }

    @IBAction func startStopServer(sender: AnyObject) {
        nuimoController?.disconnect()
        nuimoController = nil

        if let _ = server {
            stopServer()
        }
        else {
            guard let nuimoController = arrayController.selectedObjects.first as? NuimoController else { return }
            nuimoController.delegate = self
            nuimoController.connect()
            self.nuimoController = nuimoController
            nuimoStatusTextField.stringValue = "Connecting..."
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

    //MARK: PSWebSocketServerDelegate

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
    }

    func server(server: PSWebSocketServer!, webSocket: PSWebSocket!, didReceiveMessage message: AnyObject!) {
        log("WebSocket received: '\(message)'")
        nuimoController?.writeMatrix(NuimoLEDMatrix(string: "\(message)"))
    }

    func server(server: PSWebSocketServer!, webSocket: PSWebSocket!, didCloseWithCode code: Int, reason: String!, wasClean: Bool) {
        log("WebSocket closed")
        sockets = sockets.filter{ $0 == webSocket }
    }

    func server(server: PSWebSocketServer!, webSocket: PSWebSocket!, didFailWithError error: NSError!) {
        log("WebSocket failed: \(error.localizedDescription), \(error.localizedFailureReason ?? "")")
    }

    //MARK: NuimoDiscoveryDelegate

    func nuimoDiscoveryManager(discovery: NuimoDiscoveryManager, didDiscoverNuimoController controller: NuimoController) {
        arrayController.addObject(controller)
    }

    //MARK: NuimoControllerDelegate

    func nuimoControllerDidConnect(controller: NuimoController) {
        startServer()
        nuimoStatusTextField.stringValue = "Connected"
    }

    func nuimoController(controller: NuimoController, didFailToConnect error: NSError?) {
        discoverNuimo("Failed to connect.")
    }

    func nuimoController(controller: NuimoController, didDisconnect error: NSError?) {
        discoverNuimo("Disconnected.")
    }

    func nuimoControllerDidInvalidate(controller: NuimoController) {
        discoverNuimo("Disappeared.")
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
}

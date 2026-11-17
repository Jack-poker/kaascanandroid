import Flutter
import UIKit
import UserNotifications

public class NtfyPlugin: NSObject, FlutterPlugin, FlutterStreamHandler, URLSessionDataDelegate {
    private var eventSink: FlutterEventSink?
    private var urlSession: URLSession?
    private var dataTask: URLSessionDataTask?
    private var buffer = Data()
    
    private var currentUrl: String?
    private var currentTopic: String?
    private var currentAuth: String?
    private var isSubscribed = false
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "ntfy", binaryMessenger: registrar.messenger())
        let eventChannel = FlutterEventChannel(name: "ntfy_events", binaryMessenger: registrar.messenger())
        let instance = NtfyPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "subscribe" {
            guard let args = call.arguments as? [String: Any],
                  let url = args["url"] as? String,
                  let topic = args["topic"] as? String else {
                result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid arguments", details: nil))
                return
            }
            let auth = args["auth"] as? String
            
            // Request notification permissions
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
            
            subscribe(url: url, topic: topic, auth: auth)
            result(nil)
        } else if call.method == "unsubscribe" {
            unsubscribe()
            result(nil)
        } else {
            result(FlutterMethodNotImplemented)
        }
    }

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        self.eventSink = nil
        return nil
    }

    private func subscribe(url: String, topic: String, auth: String?) {
        isSubscribed = true
        currentUrl = url
        currentTopic = topic
        currentAuth = auth
        
        connect()
    }
    
    private func connect() {
        dataTask?.cancel()
        dataTask = nil
        
        guard let url = currentUrl, let topic = currentTopic else { return }
        let topicUrl = "\(url)/\(topic)/json"
        guard let urlObj = URL(string: topicUrl) else { return }

        var request = URLRequest(url: urlObj)
        if let auth = currentAuth {
            request.setValue(auth, forHTTPHeaderField: "Authorization")
        }

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = TimeInterval(Int.max)
        config.timeoutIntervalForResource = TimeInterval(Int.max)
        
        if urlSession == nil {
            urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        }
        
        dataTask = urlSession?.dataTask(with: request)
        dataTask?.resume()
    }

    private func unsubscribe() {
        isSubscribed = false
        dataTask?.cancel()
        dataTask = nil
        urlSession?.invalidateAndCancel()
        urlSession = nil
        buffer.removeAll()
    }

    public func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.buffer.append(data)
            
            while let newlineRange = self.buffer.range(of: Data("\n".utf8)) {
                let lineData = self.buffer.subdata(in: 0..<newlineRange.lowerBound)
                self.buffer.removeSubrange(0..<newlineRange.upperBound)
                
                if let jsonString = String(data: lineData, encoding: .utf8), !jsonString.isEmpty {
                    self.handleMessage(jsonString: jsonString)
                }
            }
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if self.isSubscribed {
                // Reconnect after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    if self.isSubscribed {
                        self.connect()
                    }
                }
            }
        }
    }

    private func handleMessage(jsonString: String) {
        guard let data = jsonString.data(using: .utf8) else { return }
        do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let event = json["event"] as? String, event == "message" {
                
                let title = json["title"] as? String ?? "New Notification"
                let message = json["message"] as? String ?? ""
                let id = json["id"] as? String ?? UUID().uuidString
                
                showNotification(title: title, message: message, id: id)
                
                self.eventSink?(jsonString)
            }
        } catch {
            print("Error parsing ntfy json: \(error)")
        }
    }

    private func showNotification(title: String, message: String, id: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("Error showing notification: \(error)")
            }
        }
    }
}

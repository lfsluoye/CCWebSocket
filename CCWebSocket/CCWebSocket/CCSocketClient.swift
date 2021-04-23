//
//  CCSocketClient.swift
//  CCWebSocket
//
//  Created by Caffrey on 2021/4/23.
//

import Foundation
import SocketRocket

/// Websocket连接收到新消息的通知
public let CCSocketDidReceiveMessageNotification = NSNotification.Name.init("CCSocketDidReceiveMessageNotification")

public class CCSocketClient: NSObject {
    /// 生成随机字符串
    ///
    /// - Parameter length: 字符串长度
    /// - Returns: 生成的随机字符串
    private let randomCharacters = "0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
    private var webSocket: SRWebSocket?

    private var socketOption: CCSocketOption

    /// 心跳队列
    private let heartBeatQueue = DispatchQueue(label: "com.socket.heart.queue")

    /// 发送心跳, 同时用作ACK超时计算
    private var sendHeartBeatTimer: DispatchSourceTimer?

    /// 记录发送 ping 的间隔
    private var pingInterval: TimeInterval = 0

    /// 记录发送 ping 到收到 pong 的时间间隔
    private var pingTimeout: TimeInterval = 0

    /// 重连次数
    private var reconnectCount: Int = 0

    /// 正在重连
    private var lockReconnect = false

    /// 用户关闭
    private var userClose = false

    /// 重发消息
    private var overtimeMessages = [CCMessage]()

    /// 是否在断开连接后自动重连
    public var autoReconnect = true

    public init(options: CCSocketOption) {
        socketOption = options
        super.init()
        initSocket()
    }

    /// 打开socket
    public func openSocket() {
        guard let socket = webSocket else {
            print("socket 不存在")
            return
        }
        userClose = false
        socket.open()
    }
    /// 关闭socket
    public func closeSocket() {
        guard let socket = webSocket else {
            print("socket 不存在")
            return
        }
        userClose = true
        socket.close()
    }

    // MARK: - 私有方法
    /// 初始化socket
    private func initSocket() {
        guard let url = URL(string: socketOption.host) else {
            print("[CCWebSocket] 初始化 url 失败")
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = socketOption.pingTimeout
        webSocket = SRWebSocket(urlRequest: request, protocols: [], allowsUntrustedSSLCertificates: socketOption.trustAllSSL)
        webSocket?.delegate = self
        webSocket?.setDelegateDispatchQueue(heartBeatQueue)
        openSocket()
    }

    /// 初始化心跳
    private func initHeart() {
        print("socket 开启心跳")

        reconnectCount = 0

        sendHeartBeatTimer = DispatchSource.makeTimerSource(flags: [], queue: heartBeatQueue)
        sendHeartBeatTimer?.schedule(deadline: .now(), repeating: .seconds(1), leeway: DispatchTimeInterval.milliseconds(100))
        sendHeartBeatTimer?.setEventHandler {[weak self] in
            guard let self = self else {
                return
            }
            self.heartBeatTimerHandler()
        }
        sendHeartBeatTimer?.resume()
    }

    /// 处理心跳
    private func heartBeatTimerHandler() {
        pingInterval += 1
        pingTimeout += 1

        if pingTimeout >= socketOption.pingTimeout {

            print("[CCWebSocket] pong timeout")

            pingTimeout = 0
            startReconnect()
            return
        }

        if pingInterval >= socketOption.pingInterval {
            pingInterval = 0

            guard webSocket?.readyState == SRReadyState.OPEN else {
                print("error readyState \(String(describing: webSocket?.readyState))")
                return
            }

            webSocket?.sendPing(nil)

            print("[CCWebSocket] send ping")
        }


        guard webSocket?.readyState == SRReadyState.OPEN, var message = overtimeMessages.first else {
            return
        }
        if Date().timeIntervalSince1970 > message.time {//超时重传

            self.sendJSON(message.json)

            print("resendMessage \(message)")

            if message.count >= socketOption.ackRetryCount {
                overtimeMessages.removeFirst()
            }
            message.count += 1
        }
    }

    /// 开始重连
    private func startReconnect() {

        if !autoReconnect{
            return
        }

        if lockReconnect {
            return
        }
        lockReconnect = true

        guard reconnectCount < socketOption.maxReconnectionTimes else {
            print("[T3WebSocket] 超过最大重试次数")
            return
        }

        let seconds = DispatchTime.now().uptimeNanoseconds + UInt64(reconnectCount) * NSEC_PER_SEC
        let time = DispatchTime.init(uptimeNanoseconds: seconds)
        DispatchQueue.main.asyncAfter(deadline: time) {
            self.destorySocket()
            self.initSocket()
            self.lockReconnect = false
        }

        if reconnectCount == 0 {
            reconnectCount = 1
        }
        reconnectCount *= 2
    }

    /// 销毁 socket
    private func destorySocket() {
        closeSocket()
        webSocket?.delegate = nil
        webSocket = nil
    }

    /// 销毁定时器
    private func destoryTimer(){
        sendHeartBeatTimer?.cancel()
        sendHeartBeatTimer = nil
    }

    /// 重置数据
    private func resetCount() {
        pingInterval = 0
        pingTimeout = 0
        reconnectCount = 0
    }
}

// MARK: - 发消息
extension CCSocketClient {

    /// 发送消息
    /// - Parameters:
    ///   - message: 消息内容
    ///   - messageId: 消息id
    ///   - mesageType: 消息类型 分为 push, ack
    /// - Returns: 返回消息id
    @discardableResult
    public func sendMessage(_ message: String, messageId: String? = nil, mesageType: CCMessageType = .push) -> String? {
        let msgID = messageId ?? randomString(length: 24)
        let json = [CCMessageConfig.messageID: msgID,
                    CCMessageConfig.data: message,
                    CCMessageConfig.messageType: mesageType.rawValue]

        let error = self.sendJSON(json)
        if error == nil {
            let time = Date(timeIntervalSinceNow: self.socketOption.ackTimeout).timeIntervalSince1970
            let message = CCMessage(time: time, messageID: msgID, json: json)
            overtimeMessages.append(message)
            return msgID
        } else {
            return nil
        }
    }

    @discardableResult
    private func sendJSON(_ json: [String: Any]) -> NSError? {
        let jsonData = try? JSONSerialization.data(withJSONObject: json, options: JSONSerialization.WritingOptions.prettyPrinted)
        return sendData(jsonData)
    }

    @discardableResult
    private func sendData(_ data: Data?) -> NSError? {

        guard webSocket?.readyState == SRReadyState.OPEN else{
            return NSError.init(domain: "CCWebsocket", code: SRStatusCodeGoingAway.rawValue, userInfo: nil)
        }
        webSocket?.send(data)
        return nil
    }



    /// 随机一个消息id
    /// - Parameter length: 消息id长度
    /// - Returns: 返回一个消息id
    func randomString(length: Int) -> String {
        var ranStr = ""
        for _ in 0 ..< length {
            if let character = randomCharacters.randomElement() {
                ranStr.append(character)
            } else {
                ranStr.append("")
            }
        }
        return ranStr
    }
}

extension CCSocketClient: SRWebSocketDelegate {
    /// 收到信息
    public func webSocket(_ webSocket: SRWebSocket!, didReceiveMessage message: Any!) {
        print("socket didReceiveMessage")

        guard let data = (message as? String)?.data(using: .utf8) else {
            print("[CCWebsocket] 接受消息解析失败")
            return
        }
        guard let msgJSON = try? JSONSerialization.jsonObject(with: data, options: .mutableContainers) as?  [String: Any] else {
            return
        }
        if let messageID = msgJSON[CCMessageConfig.messageID] as? String,  overtimeMessages.count > 0 {
            if let index = findMessage(messageID) {
                overtimeMessages.remove(at: index)
            }
        }
        print(msgJSON)
        NotificationCenter.default.post(name: CCSocketDidReceiveMessageNotification, object: self, userInfo: ["message":msgJSON])
    }

    /// 查message
    private func findMessage(_ messageID: String) -> Int? {
        var index = 0
        for message in overtimeMessages {
            if message.messageID == messageID {
                return index
            }
            index += 1
        }
        return nil
    }

    /// socket didopen
    public func webSocketDidOpen(_ webSocket: SRWebSocket!) {
        print("socket did open")
        initHeart()
    }

    /// socket error
    public func webSocket(_ webSocket: SRWebSocket!, didFailWithError error: Error!) {
        print("socket didFailWithError")
        startReconnect()
    }

    /// socket receivepong
    public func webSocket(_ webSocket: SRWebSocket!, didReceivePong pongPayload: Data!) {
        print("socket didReceivePong")
        pingTimeout = 0
    }

    public func webSocket(_ webSocket: SRWebSocket!, didCloseWithCode code: Int, reason: String!, wasClean: Bool) {
        print("socket didCloseWithCode")
        if !userClose {
            startReconnect()
        }
    }
}

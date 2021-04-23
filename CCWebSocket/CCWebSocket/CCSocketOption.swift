//
//  CCSocketOption.swift
//  CCWebSocket
//
//  Created by Caffrey on 2021/4/23.
//

import Foundation

public struct CCSocketOption {
    /// 心跳间隔时长
    var pingInterval: TimeInterval = 5

    /// 心跳超时时长
    var pingTimeout: TimeInterval = 12

    /// 是否支持https
    var trustAllSSL: Bool = false

    /// 最大重连次数
    var maxReconnectionTimes = Int.max

    /// 默认的服务器消息ACK超时时间
    var ackTimeout: TimeInterval = 7

    /// 发送失败重试次数
    var ackRetryCount: Int = 3

    /// 连接地址
    var host: String = ""

    /// 连接的配置参数
    ///
    /// - Parameters:
    ///   - host:  主机地址
    ///   - pingInterval: 心跳间隔时长
    ///   - pingTimeout: 心跳超时时长
    ///   - trustAllSSL: 是否支持https
    ///   - ackTimeout: ack 超时时间
    ///   - retryTimes: 重试次数
    public init(host: String = "",
                pingInterval: TimeInterval = 5,
                pingTimeout: TimeInterval = 12,
                trustAllSSL: Bool = true,
                maxReconnectionTimes: Int = .max,
                ackTimeout: TimeInterval = 7,
                ackRetryCount: Int = 3
                ) {
        self.host = host
        self.pingInterval = pingInterval
        self.pingTimeout = pingTimeout
        self.trustAllSSL = trustAllSSL
        self.maxReconnectionTimes = maxReconnectionTimes
        self.ackTimeout = ackTimeout
        self.ackRetryCount = ackRetryCount
    }
}

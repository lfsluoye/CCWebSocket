//
//  CCMessageConfig.swift
//  CCWebSocket
//
//  Created by Caffrey on 2021/4/23.
//

public struct CCMessageConfig {
    static var data = "data"
    static var messageID = "messageId"
    static var messageType = "messageType"
}

public enum CCMessageType: String {
    // receive push from server
    case push = "PUSH"

    // send reponse to server for push
    case ack = "ACK"
}

//
//  CCMessage.swift
//  CCWebSocket
//
//  Created by Caffrey on 2021/4/23.
//

class CCMessage {
    /// 时间戳
    var time: TimeInterval = 0
    /// 消息id
    var messageID: String = ""
    /// 消息内容
    var json = [String: Any]()
    /// 消息个数
    var count = 0

    init(time: TimeInterval, messageID: String, json: [String: Any]) {
        self.time = time
        self.messageID = messageID
        self.json = json
    }
}

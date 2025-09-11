//
//  WSTopic.swift
//  ONTest
//
//  Created by bomi on 2025/9/2.
//

import Foundation

protocol WSTopicSpec {
    associatedtype Output: Sendable

    static var destination: String { get }
    
    static func parse<S: Sequence>(_ fields: S) -> Output? where S.Element == Substring
}

enum WSTopic {
    case odds
}

extension WSTopic {
    struct Odds: WSTopicSpec {
        typealias Output = OddsUpdate

        static var destination: String { "/odds" }

        static func parse<S: Sequence>(_ fields: S) -> OddsUpdate? where S.Element == Substring {
            var id: Int?
            var a: Double?
            var b: Double?
            for f in fields {
                let pair = f.split(separator: "=")
                if pair.count != 2 { continue }
                let key = pair[0], val = pair[1]
                switch key {
                case "matchID": id = Int(val)
                case "teamAOdds": a = Double(val)
                case "teamBOdds": b = Double(val)
                default: break
                }
            }
            guard let id, let a, let b else { return nil }
            return OddsUpdate(matchID: id, teamAOdds: a, teamBOdds: b)
        }
    }
}

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
    
    //mock
    static var mockEnabled: Bool { get }
    static var mockUpdatePerSecondRange: ClosedRange<Int> { get }
    static var mockFailureInterval: TimeInterval { get }
    static func mockUpdate() -> Output?
}

extension WSTopicSpec {
    static var mockEnabled: Bool { false }
    static var mockUpdatePerSecondRange: ClosedRange<Int> { 1...10 }
    static var mockFailureInterval: TimeInterval { 10 }
    static func mockUpdate() -> Output? { nil }
}

// topics namespace
enum WSTopic {
    case odds
}

// topics implement
extension WSTopic {
    struct Odds: WSTopicSpec {
        
        typealias Output = OddsUpdate
        
        static var destination: String { "/odds" }
        
        static var mockEnabled: Bool { true }
        
        static func mockUpdate() -> OddsUpdate? {
            let id = Array(1001...1100).randomElement() ?? 1001
            return .init(
                matchID: id,
                teamAOdds: Double.random(in: 1.5...3.0),
                teamBOdds: Double.random(in: 1.5...3.0)
            )
        }
    }
}

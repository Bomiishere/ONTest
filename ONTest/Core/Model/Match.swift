//
//  Match.swift
//  ONTest
//
//  Created by bomi on 2025/8/29.
//

import Foundation

struct Match: Identifiable, Hashable, Codable {
    let id: Int
    let teamA: String
    let teamB: String
    let startTime: String
    
    enum CodingKeys: String, CodingKey {
        case id = "matchID"
        case teamA, teamB, startTime
    }
}

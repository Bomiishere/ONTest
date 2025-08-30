//
//  Odds.swift
//  ONTest
//
//  Created by bomi on 2025/8/29.
//

import Foundation

struct Odds: Hashable, Codable {
    let matchID: Int
    let teamAOdds: Double
    let teamBOdds: Double
}

struct OddsUpdate: Hashable, Codable {
    let matchID: Int
    let teamAOdds: Double
    let teamBOdds: Double
}

//
//  OddsRepository.swift
//  ONTest
//
//  Created by bomi on 2025/8/29.
//

import Foundation

private final class OddsBox {
    let odds: Odds

    init(_ odds: Odds) {
        self.odds = odds
    }
}

actor OddsRepository {
    
    private let cache = NSCache<NSNumber, OddsBox>()
    
    init(countLimit: Int = 500) {
        cache.countLimit = countLimit
    }
    
    // MARK: - Write
    func seed(_ odds: [Odds]) {
        for odd in odds { put(odd) }
    }
    
    func apply(_ update: OddsUpdate) {
        let odds = Odds(matchID: update.matchID, teamAOdds: update.teamAOdds, teamBOdds: update.teamBOdds)
        put(odds)
    }
    
    // MARK: - Read
    func getOdds(_ matchID: Int) -> Odds? {
        let key = NSNumber(value: matchID)
        return cache.object(forKey: key)?.odds
    }
}

extension OddsRepository {
    
    private func put(_ odds: Odds) {
        let key = NSNumber(value: odds.matchID)
        let box = OddsBox(odds)
        cache.setObject(box, forKey: key)
    }
}

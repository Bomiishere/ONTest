//
//  MatchRepository.swift
//  ONTest
//
//  Created by bomi on 2025/8/30.
//

import Foundation

private final class MatchBox {
    let match: Match
    init(_ match: Match) {
        self.match = match
    }
}

actor MatchRepository {
    private let cache = NSCache<NSNumber, MatchBox>()
    private var index = Set<Int>()
    
    //match 約 100 筆
    init(countLimit: Int = 200) {
        cache.countLimit = countLimit
    }
    
    // MARK: - Write
    func seed(_ matches: [Match]) {
        for m in matches { put(m) }
    }
    
    // MARK: - Read
    func snapshot() -> [Match] {
        index.compactMap { getMatch($0) }
    }
    
    func getMatch(_ id: Int) -> Match? {
        let key = NSNumber(value: id)
        return cache.object(forKey: key)?.match
    }
}

private extension MatchRepository {
    
    func put(_ match: Match) {
        let key = NSNumber(value: match.id)
        cache.setObject(MatchBox(match), forKey: key)
        index.insert(match.id)
    }
}

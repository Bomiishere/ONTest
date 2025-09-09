//
//  MatchListRepository.swift
//  ONTest
//
//  Created by bomi on 2025/9/6.
//

import ComposableArchitecture
import Foundation

actor MatchListRepository {
    
    typealias DataType = [MatchListFeature.State.Row]
    
    private let cache = NSCache<NSString, MatchListBox>()
    private let cacheKey: NSString = "MatchListRepo"
    private var index = Set<Int>()
    
    // matches 約 100 筆
    init(cacheCount: Int = 200) {
        cache.countLimit = cacheCount
    }
    
    //MARK: - API
    func fetchAPI() async throws -> DataType {
        let matchService = APIService()
        async let matchesJob = matchService.fetch(APIEndPoint.matches, [Match].self)
        
        let oddsService = APIService()
        async let oddsListJob = oddsService.fetch(APIEndPoint.oddsList, [Odds].self)
        
        //並發
        let (matches, oddsList) = try await (matchesJob, oddsListJob)
        
        //prevent unique key crash
        let oddsMap = oddsList.reduce(into: [Int: Odds]()) { dict, odds in
            dict[odds.matchID] = odds
        }
        let sorted = matches.sorted { $0.startTime > $1.startTime }
        
        let rows: DataType = sorted.map { match in
            let odds = oddsMap[match.id]
            return .init(
                id: match.id,
                teamA: match.teamA,
                teamB: match.teamB,
                time: match.startTime,
                teamAOdds: (odds?.teamAOdds ?? .nan).oddsDisplay,
                teamBOdds: (odds?.teamBOdds ?? .nan).oddsDisplay
            )
        }
        
        Task {
            await seed(rows)
        }
        
        return rows
    }
    
    // MARK: - Read
    func snapshot() -> DataType {
        return cache.object(forKey: cacheKey)?.data ?? []
    }
    
    // MARK: - Write
    private func seed(_ data: DataType) async {
        cache.setObject(MatchListBox(data), forKey: cacheKey)
    }
    
    deinit { print("MatchListRepository deinit") }
}

private final class MatchListBox {
    let data: MatchListRepository.DataType
    init(_ data: MatchListRepository.DataType) {
        self.data = data
    }
}

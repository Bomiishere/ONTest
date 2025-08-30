//
//  MatchListMock.swift
//  ONTest
//
//  Created by bomi on 2025/8/29.
//

import Foundation

actor MockMatchService {
    func fetchMatches() async throws -> [Match] {
        let now = Date()
        let matches = (0..<100).map { i in
            let startDate = Calendar.current.date(byAdding: .minute, value: i * 5, to: now)!
            return Match(
                id: 1000 + i,
                teamA: "Team \(Int.random(in: 1...10))",
                teamB: "Team \(Int.random(in: 11...20))",
                startTime: DateFormatter.match.string(from: startDate)
            )
        }
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        return matches
    }
}

actor MockOddsService {
    func fetchOddsList() async throws -> [Odds] {
        // 與 matchID 1000...1099 對應
        return (1000..<1100).map { id in
            Odds(matchID: id,
                 teamAOdds: Double.random(in: 1.8...2.8).rounded(to: 2),
                 teamBOdds: Double.random(in: 1.8...2.8).rounded(to: 2))
        }
    }
}

actor MockOddsStream {
    private let matchIDRange: ClosedRange<Int>
    private let countPerSecond: Int
    private let minOdd: Double = 1.8
    private let maxOdd: Double = 2.8
    
    init(matchIDRange: ClosedRange<Int> = 1088...1099, countPerSecond: Int = 10) {
        self.matchIDRange = matchIDRange
        self.countPerSecond = countPerSecond
    }
    
    func updates() -> AsyncStream<OddsUpdate> {
        AsyncStream { continuation in
            let task = Task {
                while !Task.isCancelled {
                    
                    let count = Int.random(in: 0...countPerSecond)
                    for _ in 0..<count {
                        let id = Int.random(in: matchIDRange)
                        let a = Double.random(in: minOdd...maxOdd).rounded(to: 2)
                        let b = Double.random(in: minOdd...maxOdd).rounded(to: 2)
                        
                        //pretend json
                        let payload: [String: Any] = [
                            "matchID": id,
                            "teamAOdds": a,
                            "teamBOdds": b
                        ]
                        
                        if let data = try? JSONSerialization.data(withJSONObject: payload) {
                            if let update = try? JSONDecoder().decode(OddsUpdate.self, from: data) {
                                continuation.yield(update)
                            }
                        }
                        
                        try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s 一筆 < 1s
                    }
                    try? await Task.sleep(nanoseconds: 1_000_000_000) // 1s 更新一次
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

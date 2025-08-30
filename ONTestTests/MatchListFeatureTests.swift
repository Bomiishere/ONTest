//
//  MatchListFeatureTests.swift
//  ONTest
//
//  Created by bomi on 2025/9/1.
//

import XCTest
import ComposableArchitecture
import CombineSchedulers

@testable import ONTest

@MainActor
final class MatchListFeatureTests: XCTestCase {
    
    // MARK: - TestStore factory with sensible defaults
    private func makeStore(
        initialState: MatchListFeature.State = .init(),
        matches: [Match]? = nil,
        oddsList: [Odds]? = nil,
        stream: AsyncStream<OddsUpdate>? = nil,
        override: (inout DependencyValues) -> Void = { _ in }
    ) -> TestStoreOf<MatchListFeature> {
        return TestStore(
            initialState: initialState,
            reducer: { MatchListFeature() }
        ) { deps in
            deps.mainQueue = .immediate
            if let matches { deps.matchService.fetchMatches = { matches } }
            if let oddsList { deps.oddsService.fetchOddsList = { oddsList } }
            if let stream {
                deps.oddsStream.updates = { stream }
            }
            else {
                // Default: a finished stream so long‑lived effects don't hang tests
                deps.oddsStream.updates = {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                }
            }
            deps.matchRepo.seed = { _ in }
            deps.matchRepo.snapshot = { [] }
            deps.matchRepo.getMatch = { _ in nil }
            deps.oddsRepo.seed = { _ in }
            deps.oddsRepo.apply = { _ in }
            deps.oddsRepo.getOdds = { _ in nil }
            override(&deps)
        }
    }
    
    func test_task_emptyData() async {
        
        let store = makeStore(matches: [], oddsList: [])

        await store.send(.task) { state in
            state.isLoading = true
            state.errorMessage = nil
        }
        
        // _fetchCache
        await store.receive { action in
            if case ._fetchCache = action { return true }
            return false
        }
        
        // _fetchAPI
        await store.receive({ action in
            if case ._fetchAPI = action { return true }
            return false
        })
        
        // _startOddsStream
        await store.receive { action in
            if case ._startOddsStream = action { return true }
            return false
        }
        
        // _apply
        await store.receive({ action in
            if case ._apply = action { return true }
            return false
        }) { state in
            state.rows = []
            state.isLoading = false
        }
        
        await store.finish()
    }
    
    @MainActor
    func test_fetchCache_timeOrder() async {
        // id = 2(較早), id = 1(較新) -> 期望排序 [1,2]
        let cached: [Match] = [
            .init(id: 2, teamA: "B", teamB: "C", startTime: "2025-07-05T12:00:00Z"),
            .init(id: 1, teamA: "A", teamB: "D", startTime: "2025-07-06T12:00:00Z"),
        ]
        let oddsMap: [Int: Odds] = [
            1: .init(matchID: 1, teamAOdds: 1.9, teamBOdds: 2.04),
            2: .init(matchID: 2, teamAOdds: 1.8, teamBOdds: 2.20),
        ]

        let store = makeStore { deps in
            deps.matchRepo.snapshot = { cached }
            deps.oddsRepo.getOdds = { oddsMap[$0] }
        }

        await store.send(._fetchCache)
        await store.receive({ action in
            if case let ._apply(rows) = action {
                XCTAssertEqual(rows.map(\.id), [1,2]) // 新 -> 舊
                return true
            }
            return false
        }) { status in
            status.rows = [
                .init(id: 1, teamA: "A", teamB: "D", time: "2025-07-06T12:00:00Z", teamAOdds: "1.90", teamBOdds: "2.04"),
                .init(id: 2, teamA: "B", teamB: "C", time: "2025-07-05T12:00:00Z", teamAOdds: "1.80", teamBOdds: "2.20"),
            ]
            status.isLoading = false
        }
        await store.finish()
    }
    
    func test_fetchAPI_applyRows() async {
        // id = 2(較早), id = 1(較新) -> 期望排序 [1,2]
        let matches: [Match] = [
            .init(id: 2, teamA: "B", teamB: "C", startTime: "2025-07-05T12:00:00Z"),
            .init(id: 1, teamA: "A", teamB: "D", startTime: "2025-07-06T12:00:00Z"),
        ]
        let odds: [Odds] = [
            .init(matchID: 1, teamAOdds: 1.91, teamBOdds: 2.04),
            .init(matchID: 2, teamAOdds: 1.88, teamBOdds: 2.20),
        ]

        let store = makeStore(matches: matches, oddsList: odds)

        await store.send(.task) { status in
            status.isLoading = true
            status.errorMessage = nil
        }
        await store.receive { if case ._fetchCache = $0 { true } else { false } }
        await store.receive { if case ._fetchAPI = $0 { true } else { false } }
        await store.receive { if case ._startOddsStream = $0 { true } else { false } }
        await store.receive({ action in
            if case ._apply = action {
                return true
            }
            else {
                return false
            }
        }) { status in
            status.rows = [
                .init(id: 1, teamA: "A", teamB: "D", time: "2025-07-06T12:00:00Z", teamAOdds: "1.91", teamBOdds: "2.04"),
                .init(id: 2, teamA: "B", teamB: "C", time: "2025-07-05T12:00:00Z", teamAOdds: "1.88", teamBOdds: "2.20"),
            ]
            status.isLoading = false
        }
        
        await store.finish()
    }
    
    func test_fetchAPI_failure() async {
        enum TestAPIErr: Error { case sth }
        let store = makeStore { deps in
            deps.matchService.fetchMatches = { throw TestAPIErr.sth }
            deps.oddsService.fetchOddsList = { [] }
        }

        await store.send(._fetchAPI)
        await store.receive({ action in
            if case let ._failed(msg) = action {
                XCTAssertTrue(msg.contains("sth"))
                return true
            }
            return false
        }) { s in
            s.isLoading = false
            s.errorMessage = String(describing: TestAPIErr.sth)
        }
        await store.finish()
    }
    
    func test_startStream_stop() async {
        let terminated = expectation(description: "stream terminated")
        let stream = AsyncStream<OddsUpdate> { continuation in
            continuation.onTermination = { _ in
                terminated.fulfill() //thread safe
            }
        }
        
        let store = makeStore(stream: stream)
        await store.send(._startOddsStream)
        await store.send(.stop)
        await fulfillment(of: [terminated], timeout: 1.0)
        
        await store.finish()
    }
    
    func test_throttleStreamUpdate_takeLatestOddsUpdateInOneSecond() async {
        let scheduler = DispatchQueue.test
        let store = makeStore { deps in
            deps.mainQueue = scheduler.eraseToAnyScheduler()
        }
        // 先放兩列
        await store.send(._apply([
            .init(id: 1, teamA: "A", teamB: "B", time: "2025-07-06T12:00:00Z", teamAOdds: "-", teamBOdds: "-"),
            .init(id: 2, teamA: "C", teamB: "D", time: "2025-07-05T12:00:00Z", teamAOdds: "-", teamBOdds: "-"),
        ])) { status in
            status.rows = [
                .init(id: 1, teamA: "A", teamB: "B", time: "2025-07-06T12:00:00Z", teamAOdds: "-", teamBOdds: "-"),
                .init(id: 2, teamA: "C", teamB: "D", time: "2025-07-05T12:00:00Z", teamAOdds: "-", teamBOdds: "-"),
            ]
            status.isLoading = false
        }

        // 同一 matchID 快速送三筆
        await store.send(._throttleStreamUpdate(.init(matchID: 1, teamAOdds: 1.80, teamBOdds: 2.10)))
        await store.send(._throttleStreamUpdate(.init(matchID: 1, teamAOdds: 1.85, teamBOdds: 2.05)))
        await store.send(._throttleStreamUpdate(.init(matchID: 1, teamAOdds: 1.90, teamBOdds: 2.00)))

        // 推進 1 秒，只會看到一次 _updateOdds/_updateOddsRepo，且值為最後一筆
        await scheduler.advance(by: .seconds(1))

        // verify last OddsUpdate
        await store.receive({ action in
            if case let ._updateOdds(update) = action {
                XCTAssertEqual(update.matchID, 1)
                XCTAssertEqual(update.teamAOdds, 1.90, accuracy: 0.0001)
                XCTAssertEqual(update.teamBOdds, 2.00, accuracy: 0.0001)
                return true
            }
            return false
        }) { state in
            if let idx = state.rows.firstIndex(where: { $0.id == 1 }) {
                state.rows[idx].teamAOdds = "1.90"
                state.rows[idx].teamBOdds = "2.00"
            }
        }
        await store.receive { action in
            if case ._updateOddsRepo = action { return true }
            return false
        }
        await store.finish()
    }
}

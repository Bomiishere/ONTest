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
    
    enum TestErr: Error { case sth }
    
    func testTask() async {
        
        let store = TestStore(
            initialState: MatchListFeature.State.init(),
            reducer: { MatchListFeature()
            })
        
        await store.send(.task) { state in
            state.isLoading = true
            state.errorMessage = nil
        }
        await store.receive { action in
            if case ._fetchMatchList = action { return true }
            return false
        }
        await store.receive { action in
            if case ._startOddsStream = action { return true }
            return false
        }
        
        await store.send(.onDisappear)
        await store.finish()
    }
    
    func testReload() async {
        let store = TestStore(
            initialState: MatchListFeature.State.init(),
            reducer: { MatchListFeature()
            })
        
        await store.send(.reload) { state in
            state.isLoading = true
            state.errorMessage = nil
        }
        await store.receive { action in
            if case ._fetchMatchList = action { return true }
            return false
        }
        await store.receive { action in
            if case ._startOddsStream = action { return true }
            return false
        }
        
        await store.send(.onDisappear)
        await store.finish()
    }
    
    func testFetchMatchList_rows() async {
        let exp_rows: [MatchListFeature.State.Row] = [
            .init(id: 1, teamA: "A", teamB: "D", time: "2025-07-06T12:00:00Z", teamAOdds: "1.90", teamBOdds: "2.04"),
            .init(id: 2, teamA: "B", teamB: "C", time: "2025-07-05T12:00:00Z", teamAOdds: "1.80", teamBOdds: "2.20"),
        ]
        
        let store = TestStore(
            initialState: MatchListFeature.State.init(isLoading: true),
            reducer: { MatchListFeature() }
        ) { deps in
            deps.matchListRepo.fetchUpdates = {
                AsyncThrowingStream<MatchListRepository.DataType, Error> { continuation in
                    continuation.yield(exp_rows)
                    continuation.finish()
                }
            }
        }

        await store.send(._fetchMatchList)
        await store.receive({ action in
            if case ._apply = action { return true }
            return false
        })
        await store.receive({ action in
            if case ._applyDonePatch = action { return true }
            return false
        }) { state in
            state.rows = .init(uniqueElements: exp_rows)
            state.isLoading = false
        }
        await store.finish()
    }
    
    func testFetchMatchList_rows_empty() async {
        let exp_rows: [MatchListFeature.State.Row] = []
        let store = TestStore(
            initialState: MatchListFeature.State.init(isLoading: true),
            reducer: { MatchListFeature() }
        ) { deps in
            deps.matchListRepo.fetchUpdates = {
                AsyncThrowingStream<MatchListRepository.DataType, Error> { continuation in
                    continuation.yield(exp_rows)
                    continuation.finish()
                }
            }
        }

        await store.send(._fetchMatchList)
        await store.receive({ action in
            if case ._apply = action { return true }
            return false
        })
        await store.receive({ action in
            if case ._applyDonePatch = action { return true }
            return false
        }) { state in
            state.rows = .init(uniqueElements: exp_rows)
            state.isLoading = false
        }
        await store.finish()
    }

    func testFetchMatchList_failure() async {
        
        let store = TestStore(
            initialState: MatchListFeature.State.init(),
            reducer: { MatchListFeature()}
        )  { deps in
            deps.matchListRepo.fetchUpdates = {
                AsyncThrowingStream<MatchListRepository.DataType, Error> { continuation in
                    continuation.finish(throwing: TestErr.sth)
                }
            }
        }
        
        await store.send(._fetchMatchList)
        await store.receive({ action in
            if case let ._failed(msg) = action {
                XCTAssertTrue(msg.contains("sth"))
                return true
            }
            return false
        }) { state in
            state.isLoading = false
            state.errorMessage = String(describing: TestErr.sth)
        }
        await store.finish()
    }
    
    func testApplyDeletions_result_budget_bounds() throws {
        var state = MatchListFeature.State()
        state.rows = .init(uniqueElements: (0..<8).map { id in
            MatchListFeature.State.Row(id: id, teamA: "A\(id)", teamB: "B\(id)", time: "2025-01-01T00:00:00Z", teamAOdds: "1.90", teamBOdds: "2.10")
        })
        let remaining = state.applyDeletions([2, 10, 4], opsLeft: 2)
        
        XCTAssertEqual(state.rows.map(\.id), [0, 1, 3, 5, 6, 7])
        XCTAssertEqual(remaining, 0, "Budget should be fully consumed")
    }
    
    func testApplyInsertions_result_budget_bounds() throws {
        var state = MatchListFeature.State()
        state.rows = .init(uniqueElements: (0..<3).map { id in
            MatchListFeature.State.Row(id: id, teamA: "A\(id)", teamB: "B\(id)", time: "2025-01-01T00:00:00Z", teamAOdds: "1.90", teamBOdds: "2.10")
        })
        /**
         Conditions:
         1. Insert at first
         2. Middle
         3. Out of range -> append
         4. Same ID
         */
        let insertions: [(Int, MatchListFeature.State.Row)] = [
            (0, MatchListFeature.State.Row(id: 997, teamA: "", teamB: "", time: "", teamAOdds: "", teamBOdds: "")),
            (2, MatchListFeature.State.Row(id: 998, teamA: "", teamB: "", time: "", teamAOdds: "", teamBOdds: "")),
            (999, MatchListFeature.State.Row(id: 999, teamA: "", teamB: "", time: "", teamAOdds: "", teamBOdds: "")),
            //test same id 998
            (999, MatchListFeature.State.Row(id: 998, teamA: "", teamB: "", time: "", teamAOdds: "", teamBOdds: "")),
        ]
        
        let remaining = state.applyInsertions(insertions, opsLeft: 4)
        
        XCTAssertEqual(state.rows.map(\.id), [997, 0, 998, 1, 2, 999], "Rows id should be fullfill")
        XCTAssertEqual(remaining, 0, "Budget should be fully consumed")
    }
    
    func testApplyRowContentUpdates_result_buget_bounds() throws {
        var state = MatchListFeature.State()
        state.rows = .init(uniqueElements: (0..<3).map { id in
            MatchListFeature.State.Row(id: id, teamA: "A\(id)", teamB: "B\(id)", time: "2025-01-01T00:00:00Z", teamAOdds: "1.90", teamBOdds: "2.10")
        })
        
        let updates: IdentifiedArrayOf<MatchListFeature.State.Row> = .init(uniqueElements: [
            MatchListFeature.State.Row(id: 2, teamA: "", teamB: "", time: "", teamAOdds: "2", teamBOdds: ""),
            MatchListFeature.State.Row(id: 3, teamA: "", teamB: "", time: "", teamAOdds: "3", teamBOdds: ""),
            MatchListFeature.State.Row(id: 4, teamA: "", teamB: "", time: "", teamAOdds: "4", teamBOdds: ""),
        ])
        
        let remaining = state.applyRowContentUpdates(toward: updates, opsLeft: 2)
        
        // Only id 2 will update
        XCTAssertEqual(state.rows[id: 2]?.teamAOdds, "2")
        XCTAssertEqual(state.rows[id: 3], nil)
        XCTAssertNil(state.rows[id: 3], "Row with id 3 should not exist")
        XCTAssertEqual(remaining, 1)
    }

    func testOddsStream_start_takeLatestOddsUpdateInOneSecond() async {
        
        let clock = TestClock()
        let exp_updates: [OddsUpdate] = [
            .init(matchID: 1, teamAOdds: 1.80, teamBOdds: 2.10),
            .init(matchID: 1, teamAOdds: 1.85, teamBOdds: 2.05),
            .init(matchID: 1, teamAOdds: 1.90, teamBOdds: 2.00),
        ]
        
        let store = TestStore(
            initialState: MatchListFeature.State.init(),
            reducer: { MatchListFeature()}
        )  { deps in
            deps.continuousClock = clock
            deps.ws.oddsUpdate = {
                AsyncStream { continuation in
                    for update in exp_updates {
                        continuation.yield(update)
                    }
                    continuation.finish()
                }
            }
        }
        
        // apply rows
        let exp_rows: [MatchListFeature.State.Row] = [
            .init(id: 1, teamA: "A", teamB: "B", time: "2025-07-06T12:00:00Z", teamAOdds: "-", teamBOdds: "-"),
            .init(id: 2, teamA: "C", teamB: "D", time: "2025-07-05T12:00:00Z", teamAOdds: "-", teamBOdds: "-"),
        ]
        await store.send(._apply(.init(uniqueElements: exp_rows)))
        await store.receive({ action in
            if case ._applyDonePatch = action { return true }
            return false
        }) { state in
            state.rows = .init(uniqueElements: exp_rows)
            state.isLoading = false
        }

        // 同一 matchID 送三筆
        await store.send(._startOddsStream)

        // 推進 1 秒，只會看到一次 _updateOdds/_updateOddsRepo，且值為最後一筆
        await clock.advance(by: .seconds(1))
        
        // update 3 筆
        for _ in 0..<3 {
            await store.receive({ action in
                if case ._throttleOddsUpdate = action { return true }
                return false
            })
        }
        // verify last OddsUpdate in one sec
        await store.receive({ action in
            if case ._updateOdds = action, let last_update = exp_updates.last {
                XCTAssertEqual(last_update.matchID, 1)
                XCTAssertEqual(last_update.teamAOdds, 1.90, accuracy: 0.0001)
                XCTAssertEqual(last_update.teamBOdds, 2.00, accuracy: 0.0001)
                return true
            }
            return false
        }) { state in
            if let idx = state.rows.firstIndex(where: { $0.id == 1 }) {
                state.rows[idx].teamAOdds = "1.90"
                state.rows[idx].teamBOdds = "2.00"
            }
        }
        await store.finish()
    }
    
    func testOddsStream_fail() async {
        let scheduler = DispatchQueue.test
        
        let store = TestStore(
            initialState: MatchListFeature.State.init(),
            reducer: { MatchListFeature()}
        )  { deps in
            deps.mainQueue = scheduler.eraseToAnyScheduler()
            deps.ws.oddsUpdate = { throw TestErr.sth }
        }
        
        await store.send(._startOddsStream)
        await store.receive({ action in
            if case let ._failed(msg) = action {
                XCTAssertTrue(msg.contains("sth"))
                return true
            }
            return false
        }) { state in
            state.errorMessage = String(describing: TestErr.sth)
        }
        await store.finish()
    }
    
    
    func testOddsStream_stop() async {
        let terminated = expectation(description: "stream terminated")
        let stream = AsyncStream<OddsUpdate> { continuation in
            continuation.onTermination = { _ in
                terminated.fulfill()
            }
        }
        
        let store = TestStore(
            initialState: MatchListFeature.State.init(),
            reducer: { MatchListFeature()}
        )  { deps in
            deps.ws.oddsUpdate = { stream }
        }
        await store.send(._startOddsStream)
        await store.send(.onDisappear)
        await fulfillment(of: [terminated], timeout: 1.0)
        
        await store.finish()
    }
}

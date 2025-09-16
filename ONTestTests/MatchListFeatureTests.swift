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
        let exp_rows: [MatchListFeature.State.Row] = [
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

    func testOddsStream_start_takeLatestOddsUpdateInOneSecond() async {
        
        let scheduler = DispatchQueue.test
        let exp_updates: [OddsUpdate] = [
            .init(matchID: 1, teamAOdds: 1.80, teamBOdds: 2.10),
            .init(matchID: 1, teamAOdds: 1.85, teamBOdds: 2.05),
            .init(matchID: 1, teamAOdds: 1.90, teamBOdds: 2.00),
        ]
        
        let store = TestStore(
            initialState: MatchListFeature.State.init(),
            reducer: { MatchListFeature()}
        )  { deps in
            deps.mainQueue = scheduler.eraseToAnyScheduler()
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
        await scheduler.advance(by: .seconds(1))
        
        // update 3 筆
        for _ in 0..<3 {
            await store.receive({ action in
                if case ._throttleOddsUpdate = action { return true }
                return false
            })
        }
        // verify last OddsUpdate in one sec
        await store.receive({ action in
            if case let ._updateOdds(update) = action, let last_update = exp_updates.last {
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

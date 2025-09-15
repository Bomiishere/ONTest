//
//  MatchListFeature.swift
//  ONTest
//
//  Created by bomi on 2025/8/29.
//

import Foundation
import ComposableArchitecture
import Dependencies

@Reducer
struct MatchListFeature {
    
    enum CancelID {
        case stream
    }
    
    enum ThrottleID: Hashable {
        case match(Int)
    }
    
    @ObservableState
    struct State: Equatable {
        var id: UUID = .init()
        var rows: IdentifiedArrayOf<Row> = []
        var isLoading = false
        var errorMessage: String?
        
        struct Row: Equatable, Identifiable {
            let id: Int
            let teamA: String
            let teamB: String
            let time: String
            var teamAOdds: String
            var teamBOdds: String
        }
    }
    
    enum Action: Equatable {
        case task
        
        // match list
        case _fetchCache
        case _fetchAPI
        case _apply(_ newRows: IdentifiedArrayOf<State.Row>)
        case _applyDonePatch(_ patch: MatchListPatch, _ newRows: IdentifiedArrayOf<State.Row>)
        
        //odds stream
        case _startOddsStream
        case _throttleStreamUpdate(OddsUpdate)
        case _updateOdds(OddsUpdate)
        ///may using in other action
        case _updateOddsRepo(OddsUpdate)
        
        case _failed(String)
        case stop
        
    }
    
    // MARK: Dependencies
    @Dependency(\.matchListRepo.fetchCache) var fetchCache
    @Dependency(\.matchListRepo.fetchAPI) var fetchAPI
    @Dependency(\.ws.oddsUpdate) var oddsUpdate
    @Dependency(\.oddsRepo) var oddsRepo
    @Dependency(\.mainQueue) var mainQueue
    @Dependency(\.matchListDiffer.patch) var differPatch
    
    // MARK: Reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state.isLoading = true
                state.errorMessage = nil
                return .run { send in
                    await send(._fetchCache)
                    await send(._fetchAPI)
                    await send(._startOddsStream)
                }
                
            case ._fetchCache:
                return .run { [fetchCache] send in
                    let rows = await fetchCache()
                    if rows.count > 0 { await send(._apply(IdentifiedArray(uniqueElements: rows))) }
                }
                
            case ._fetchAPI:
                return .run { [fetchAPI] send in
                    do {
                        let rows = try await fetchAPI()
                        await send(._apply(IdentifiedArray(uniqueElements: rows)))
                    } catch {
                        await send(._failed(String(describing: error)))
                    }
                }
                
            case let ._apply(newRows):
                let existing = state.rows
                return .run(priority: .utility) { [differPatch, existing] send in
                    let patch = await differPatch(Array(existing), Array(newRows))
                    await send(._applyDonePatch(patch, newRows))
                }
                
            case let ._applyDonePatch(patch, newRows):
                let done = state.applyPatch(patch, toward: newRows)
                state.isLoading = false
                return done ? .none : .send(._apply(newRows))
                
            case ._startOddsStream:
                return .run { [oddsUpdate] send in
                    do {
                        let updates = try await oddsUpdate()
                        for await update in updates {
                            await send(._throttleStreamUpdate(update))
                        }
                    } catch {
                        await send(._failed(String(describing: error)))
                    }
                }
                .cancellable(id: CancelID.stream, cancelInFlight: true)
                
            case let ._throttleStreamUpdate(update):
                //merge throttles
                return .merge(
                    .send(._updateOdds(update)),
                    .send(._updateOddsRepo(update))
                )
                .throttle(
                    id: ThrottleID.match(update.matchID),
                    for: .seconds(1),
                    scheduler: mainQueue,
                    latest: true
                )
                
            case let ._updateOdds(update):
                if var row = state.rows[id: update.matchID] {
                    row.teamAOdds = update.teamAOdds.oddsDisplay
                    row.teamBOdds = update.teamBOdds.oddsDisplay
                    state.rows[id: update.matchID] = row
                }
                return .none
                
            case let ._updateOddsRepo(update):
                return .run { [oddsRepo] _ in
                    await oddsRepo.apply(update)
                }
                
            case let ._failed(message):
                state.isLoading = false
                state.errorMessage = message
                return .none
                
            case .stop:
                return .cancel(id: CancelID.stream)
            }
        }
    }
}

extension MatchListFeature.State {
    
    mutating func applyPatch(
        _ patch: MatchListPatch,
        toward target: IdentifiedArrayOf<Row>,
        maximumOperations: Int = 20
    ) -> Bool {
        var operationsLeft = maximumOperations
        operationsLeft = applyDeletions(patch.removals, opsLeft: operationsLeft)
        operationsLeft = applyInsertions(patch.insertions, opsLeft: operationsLeft)
        _ = applyContentUpdates(toward: target, opsLeft: operationsLeft)
        return rows == target
    }
    
    mutating func applyDeletions(_ removals: [Int], opsLeft: Int) -> Int {
        guard opsLeft > 0, !removals.isEmpty else { return opsLeft }
        var budget = opsLeft
        for idx in removals.sorted(by: >).prefix(budget) {
            if idx >= 0 && idx < rows.count {
                rows.remove(at: idx)
                budget -= 1
                if budget == 0 { break }
            }
        }
        return budget
    }
    
    mutating func applyInsertions(_ insertions: [(Int, Row)], opsLeft: Int) -> Int {
        guard opsLeft > 0, !insertions.isEmpty else { return opsLeft }
        var budget = opsLeft
        for (index, row) in insertions.sorted(by: { $0.0 < $1.0 }).prefix(budget) {
            if index <= rows.count {
                rows.insert(row, at: index)
            } else {
                rows.append(row)
            }
            budget -= 1
            if budget == 0 { break }
        }
        return budget
    }
    
    mutating func applyContentUpdates(toward target: IdentifiedArrayOf<Row>, opsLeft: Int) -> Int {
        guard opsLeft > 0 else { return 0 }
        var budget = opsLeft
        let limit = min(rows.count, target.count)
        var i = 0
        while i < limit && budget > 0 {
            if rows[i].id == target[i].id, rows[i] != target[i] {
                rows[i] = target[i]
                budget -= 1
            }
            i += 1
        }
        return budget
    }
}

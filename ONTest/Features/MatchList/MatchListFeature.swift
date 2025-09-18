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
        case matchListUpdates, oddsUpdates, applyPatch
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
        case reload
        
        // match list
        case _fetchMatchList
        case _apply(_ newRows: IdentifiedArrayOf<State.Row>)
        case _applyDonePatch(_ patch: MatchListPatch, _ newRows: IdentifiedArrayOf<State.Row>)
        
        // odds stream
        case _startOddsStream
        case _throttleOddsUpdate(OddsUpdate)
        case _updateOdds(OddsUpdate)
        
        // fail
        case _failed(String)
        
        case onDisappear
        
    }
    
    // MARK: Dependencies
    @Dependency(\.matchListRepo.fetchUpdates) var matchListFetchUpdates
    @Dependency(\.matchListDiffer.patch) var differPatch
    @Dependency(\.ws.oddsUpdate) var wsOddsUpdate
    @Dependency(\.continuousClock) var clock
    
    // MARK: Reducer
    var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .task:
                state.startLoading()
                return .merge(
                    .send(._fetchMatchList),
                    .send(._startOddsStream)
                )
                
            case .reload:
                state.startLoading()
                return .concatenate(
                    .merge(
                        .cancel(id: CancelID.matchListUpdates),
                        .cancel(id: CancelID.oddsUpdates),
                        .cancel(id: CancelID.applyPatch)
                    ),
                    .send(._fetchMatchList),
                    .send(._startOddsStream)
                )
                
            case ._fetchMatchList:
                return .run { [matchListFetchUpdates] send in
                    do {
                        let stream = await matchListFetchUpdates()
                        for try await rows in stream {
                            let identifiedRows = IdentifiedArray(uniqueElements: rows)
                            await send(._apply(identifiedRows))
                        }
                    } catch {
                        await send(._failed(String(describing: error)))
                    }
                }
                .cancellable(id: CancelID.matchListUpdates, cancelInFlight: true)
                
            case let ._apply(newRows):
                let existing = state.rows
                return .run { [differPatch, existing] send in
                    let patch = await differPatch(Array(existing), Array(newRows))
                    await send(._applyDonePatch(patch, newRows))
                }
                .cancellable(id: CancelID.applyPatch, cancelInFlight: true)
                
            case let ._applyDonePatch(patch, newRows):
                let done = state.applyPatch(patch, toward: newRows)
                state.stopLoading()
                return done ? .none : .send(._apply(newRows))
                
            case ._startOddsStream:
                return .run { [wsOddsUpdate] send in
                    do {
                        let updates = try await wsOddsUpdate()
                        for await update in updates {
                            await send(._throttleOddsUpdate(update))
                        }
                    } catch {
                        await send(._failed(String(describing: error)))
                    }
                }
                .cancellable(id: CancelID.oddsUpdates, cancelInFlight: true)
                
            case let ._throttleOddsUpdate(update):
                return .concatenate(
                    .run { send in try? await clock.sleep(for: .seconds(1))},
                    .send(._updateOdds(update))
                )
                .cancellable(id: ThrottleID.match(update.matchID), cancelInFlight: true)
                
            case let ._updateOdds(update):
                if var row = state.rows[id: update.matchID] {
                    row.teamAOdds = update.teamAOdds.oddsDisplay
                    row.teamBOdds = update.teamBOdds.oddsDisplay
                    state.rows[id: update.matchID] = row
                }
                return .none
                
            case let ._failed(message):
                state.stopLoading(message: message)
                return .none
                
            case .onDisappear:
                return .merge(
                    .cancel(id: CancelID.matchListUpdates),
                    .cancel(id: CancelID.oddsUpdates),
                    .cancel(id: CancelID.applyPatch)
                )
            }
        }
    }
}

// MARK: Patch
extension MatchListFeature.State {
    
    mutating func applyPatch(
        _ patch: MatchListPatch,
        toward target: IdentifiedArrayOf<Row>,
        maximumOperations: Int = 20
    ) -> Bool {
        var operationsLeft = maximumOperations
        operationsLeft = applyDeletions(patch.removals, opsLeft: operationsLeft)
        operationsLeft = applyInsertions(patch.insertions, opsLeft: operationsLeft)
        _ = applyRowContentUpdates(toward: target, opsLeft: operationsLeft)
        return rows == target
    }
    
    mutating func applyDeletions(_ removals: [Int], opsLeft: Int) -> Int {
        guard opsLeft > 0, !removals.isEmpty else { return opsLeft }
        var budget = opsLeft
        
        //remove from larger id
        for idx in removals.sorted(by: >) {
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
        
        //insert from smaller id
        for (index, row) in insertions.sorted(by: { $0.0 < $1.0 }) {
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
    
    mutating func applyRowContentUpdates(toward target: IdentifiedArrayOf<Row>, opsLeft: Int) -> Int {
        guard opsLeft > 0 else { return 0 }
        var budget = opsLeft
        
        // only update exist match & row content
        for t in target {
            if let i = rows.index(id: t.id), rows[i] != t {
                rows[i] = t
                budget -= 1
                if budget == 0 { break }
            }
        }
        return budget
    }
}

// MARK: State Change
private extension MatchListFeature.State {
    mutating func startLoading() {
        if !isLoading { isLoading = true }
        errorMessage = nil
    }
    
    mutating func stopLoading(message: String? = nil) {
        if isLoading { isLoading = false }
        errorMessage = message
    }
}

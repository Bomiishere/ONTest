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
        case _apply([State.Row])
        
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
                    if rows.count > 0 { await send(._apply(rows)) }
                }
                
            case ._fetchAPI:
                return .run { [fetchAPI] send in
                    do {
                        let rows = try await fetchAPI()
                        await send(._apply(rows))
                    } catch {
                        await send(._failed(String(describing: error)))
                    }
                }
                
            case let ._apply(rows):
                state.rows = .init(uniqueElements: rows)
                state.isLoading = false
                return .none
                
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

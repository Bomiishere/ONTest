//
//  MatchListFeature.swift
//  ONTest
//
//  Created by bomi on 2025/8/29.
//

import Foundation
import ComposableArchitecture

@Reducer
struct MatchListFeature {
    
    enum CancelID { case stream }
    enum ThrottleID: Hashable { case match(Int) }
    
    @ObservableState
    struct State: Equatable {
        var id: UUID = .init()
        var rows: [Row] = []
        var isLoading = false
        var errorMessage: String?
        
        @ObservableState
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
        //TODO: send fetch behavior cache into repo
        case _fetchCache
        case _fetchAPI
        case _apply([State.Row])
        case _failed(String)
        case _startOddsStream
        case _throttleStreamUpdate(OddsUpdate)
        case _updateOdds(OddsUpdate)
        case _updateOddsRepo(OddsUpdate)
        case stop
    }
    
    // MARK: Dependencies
    @Dependency(\.matchService) var matchService
    @Dependency(\.oddsService) var oddsService
    @Dependency(\.oddsStream) var oddsStream
    @Dependency(\.oddsRepo) var oddsRepo
    @Dependency(\.matchRepo) var matchRepo
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
                return .run { [matchRepo, oddsRepo] send in
                    let cachedMatches = await matchRepo.snapshot()
                    guard !cachedMatches.isEmpty else { return }

                    let sorted = cachedMatches.sorted { $0.startTime > $1.startTime }
                    var rows: [State.Row] = []
                    rows.reserveCapacity(sorted.count)

                    for match in sorted {
                        let odd = await oddsRepo.getOdds(match.id)
                        rows.append(.init(
                            id: match.id,
                            teamA: match.teamA,
                            teamB: match.teamB,
                            time: match.startTime,
                            teamAOdds: (odd?.teamAOdds ?? .nan).oddsDisplay,
                            teamBOdds: (odd?.teamBOdds ?? .nan).oddsDisplay
                        ))
                    }

                    await send(._apply(rows))
                }
                
            case ._fetchAPI:
                return .run { [matchService, oddsService, matchRepo, oddsRepo] send in
                    do {
                        async let matchesJob = matchService.fetchMatches()
                        async let oddsListJob = oddsService.fetchOddsList()
                        let (matches, oddsList) = try await (matchesJob, oddsListJob)
                        await matchRepo.seed(matches)
                        await oddsRepo.seed(oddsList)
                        
                        //prevent unique key crash
                        let oddsMap = oddsList.reduce(into: [Int: Odds]()) { dict, odds in
                            dict[odds.matchID] = odds
                        }
                        let sorted = matches.sorted { $0.startTime > $1.startTime }
                        let rows: [State.Row] = sorted.map { match in
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
                        await send(._apply(rows))
                        
                    } catch {
                        await send(._failed(String(describing: error)))
                    }
                }
                
            case let ._apply(rows):
                state.rows = rows
                state.isLoading = false
                return .none
                
            case ._startOddsStream:
                return .run { [stream = oddsStream] send in
                    do {
                        let updates = try await stream.updates()
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
                if let idx = state.rows.firstIndex(where: { $0.id == update.matchID }) {
                    let row = state.rows[idx]
                    let newRow: State.Row = .init(
                        id: row.id,
                        teamA: row.teamA,
                        teamB: row.teamB,
                        time: row.time,
                        teamAOdds: update.teamAOdds.oddsDisplay,
                        teamBOdds: update.teamBOdds.oddsDisplay
                    )
                    state.rows[idx] = newRow
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

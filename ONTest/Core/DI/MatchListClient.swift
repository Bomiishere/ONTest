//
//  MatchListClient.swift
//  ONTest
//
//  Created by bomi on 2025/8/29.
//

import ComposableArchitecture
import Foundation
import Dependencies

// MARK: MatchListRepoClient
struct MatchListRepoClient {
    var fetchCache: @Sendable () async -> MatchListRepository.DataType
    var fetchAPI:   @Sendable () async throws -> MatchListRepository.DataType
}

extension MatchListRepoClient: DependencyKey {
    
    static var liveValue: MatchListRepoClient = .init(
        fetchCache: {
            let repo = MatchListRepository()
            return await repo.snapshot()
        },
        fetchAPI: {
            let repo = MatchListRepository()
            return try await repo.fetchAPI()
        }
    )

    static var previewValue: MatchListRepoClient = .init(
        fetchCache: {
            let repo = MatchListRepository()
            return await repo.snapshot()
        },
        fetchAPI: {
            let repo = MatchListRepository()
            return try await repo.fetchAPI()
        }
    )
    
    static var testValue: MatchListRepoClient = .init(
        fetchCache: { [] },
        fetchAPI: { [] }
    )
}

extension DependencyValues {
    var matchListRepo: MatchListRepoClient {
        get { self[MatchListRepoClient.self] }
        set { self[MatchListRepoClient.self] = newValue }
    }
}

//MARK: OddsRepoClient
struct OddsRepoClient {
    var seed: @Sendable ([Odds]) async -> Void
    var apply: @Sendable (OddsUpdate) async -> Void
    var getOdds: @Sendable (Int) async -> Odds?
}

extension OddsRepoClient: DependencyKey {
    static let liveValue: OddsRepoClient = {
        let repo = OddsRepository()
        return .init(
            seed: { await repo.seed($0) },
            apply: { await repo.apply($0) },
            getOdds: { await repo.getOdds($0) }
        )
    }()
    
    static let testValue: OddsRepoClient = {
        let repo = OddsRepository()
        return .init(
            seed: { await repo.seed($0) },
            apply: { await repo.apply($0) },
            getOdds: { await repo.getOdds($0) }
        )
    }()
}

extension DependencyValues {
    var oddsRepo: OddsRepoClient {
        get { self[OddsRepoClient.self] }
        set { self[OddsRepoClient.self] = newValue }
    }
}

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


//MARK: OddsStreamClient
struct OddsStreamClient {
    var updates: @Sendable () async throws -> AsyncStream<OddsUpdate>
}

extension OddsStreamClient: DependencyKey {
    static var liveValue: OddsStreamClient = .init(
        updates: {
            let stream = WSStream<WSTopic.Odds>()
            return await stream.updates()
        }
    )
    
    static var previewValue: OddsStreamClient = .init(
        updates: {
             let oddsStream = MockOddsStream()
             return await oddsStream.updates()
        }
    )
    
    static var testValue: OddsStreamClient = .init(
        updates: {
            AsyncStream { continuation in
                continuation.finish()
            }
        }
    )
}

extension DependencyValues {
    var oddsStream: OddsStreamClient {
        get { self[OddsStreamClient.self] }
        set { self[OddsStreamClient.self] = newValue }
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

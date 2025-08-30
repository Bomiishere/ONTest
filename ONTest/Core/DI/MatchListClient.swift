//
//  MatchListClient.swift
//  ONTest
//
//  Created by bomi on 2025/8/29.
//

import ComposableArchitecture
import Foundation

//MARK: MatchServiceClient
@DependencyClient
struct MatchServiceClient {
    var fetchMatches: @Sendable () async throws -> [Match]
}
extension MatchServiceClient: DependencyKey {
    static var liveValue: MatchServiceClient = .init(
        fetchMatches: {
            let service = APIService()
            return try await service.fetch(APIEndPoint.matches, [Match].self)
        }
    )
    
    static let previewValue: MatchServiceClient = .init(
        fetchMatches: {
            let service = MockMatchService()
            return try await service.fetchMatches()
        }
    )
    
    static let testValue: MatchServiceClient = .init(
        fetchMatches: {
            let service = MockMatchService()
            return try await service.fetchMatches()
        }
    )
}
extension DependencyValues {
    var matchService: MatchServiceClient {
        get { self[MatchServiceClient.self] }
        set { self[MatchServiceClient.self] = newValue }
    }
}

//MARK: OddsServiceClient
@DependencyClient
struct OddsServiceClient {
    var fetchOddsList: @Sendable () async throws -> [Odds]
}
extension OddsServiceClient: DependencyKey {
    static var liveValue: OddsServiceClient = .init(
        fetchOddsList: {
            let service = APIService()
            return try await service.fetch(APIEndPoint.oddsList, [Odds].self)
        }
    )
    
    static let previewValue: OddsServiceClient = .init(
        fetchOddsList: {
            let service = MockOddsService()
            return try await service.fetchOddsList()
        }
    )
    
    static let testValue: OddsServiceClient = .init(
        fetchOddsList: {
            let service = MockOddsService()
            return try await service.fetchOddsList()
        }
    )
}
extension DependencyValues {
    var oddsService: OddsServiceClient {
        get { self[OddsServiceClient.self] }
        set { self[OddsServiceClient.self] = newValue }
    }
}

//MARK: OddsStreamClient
@DependencyClient
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
            let stream = MockOddsStream()
            return await stream.updates()
        }
    )
}
extension DependencyValues {
    var oddsStream: OddsStreamClient {
        get { self[OddsStreamClient.self] }
        set { self[OddsStreamClient.self] = newValue }
    }
}

//MARK: MatchRepoClient
@DependencyClient
struct MatchRepoClient {
    var seed: @Sendable ([Match]) async -> Void
    var snapshot: @Sendable () async -> [Match] = { [] }
    var getMatch: @Sendable (Int) async -> Match?
}
extension MatchRepoClient: DependencyKey {
    static let liveValue: MatchRepoClient = {
        let repo = MatchRepository()
        return .init(
            seed: { await repo.seed($0) },
            snapshot: { await repo.snapshot() },
            getMatch: { await repo.getMatch($0) }
        )
    }()
}
extension DependencyValues {
    var matchRepo: MatchRepoClient {
        get { self[MatchRepoClient.self] }
        set { self[MatchRepoClient.self] = newValue }
    }
}

//MARK: OddsRepoClient
@DependencyClient
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
}
extension DependencyValues {
    var oddsRepo: OddsRepoClient {
        get { self[OddsRepoClient.self] }
        set { self[OddsRepoClient.self] = newValue }
    }
}

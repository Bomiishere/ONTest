//
//  WSClient.swift
//  ONTest
//
//  Created by bomi on 2025/9/10.
//

import ComposableArchitecture

struct WSClient {
    var launch: @Sendable () async -> Void
    var oddsUpdate:   @Sendable () async throws -> AsyncStream<OddsUpdate>
}

extension WSClient: DependencyKey {
    static let liveValue: WSClient = {
        let ws = WSStream()
        return .init(
            launch: { await ws.launch() },
            oddsUpdate:   { try await ws.subscribe(WSTopic.Odds.self) }
        )
    }()
    
    static let previewValue: WSClient = {
        let ws = WSStream()
        return .init(
            launch: { await ws.launch() },
            oddsUpdate:   { try await ws.subscribe(WSTopic.Odds.self) }
        )
    }()
    
    static let testValue: WSClient = .init(
        launch: {},
        oddsUpdate:   { AsyncStream { _ in } }
    )
}

extension DependencyValues {
    var ws: WSClient {
        get { self[WSClient.self] }
        set { self[WSClient.self] = newValue }
    }
}

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
    var fetchUpdates: @Sendable () async -> AsyncThrowingStream<MatchListRepository.DataType, Error>
}

extension MatchListRepoClient: DependencyKey {

    static var liveValue: MatchListRepoClient = .init(
        fetchUpdates: {
            let repo = MatchListRepository()
            return AsyncThrowingStream<MatchListRepository.DataType, Error> { continuation in
                let task = Task {
                    let cacheRows = await repo.snapshot()
                    if !cacheRows.isEmpty {
                        continuation.yield(cacheRows)
                    }

                    do {
                        let apiRows = try await repo.fetchAPI()
                        continuation.yield(apiRows)
                        continuation.finish()
                    } catch is CancellationError {
                        continuation.finish()
                    } catch {
                        continuation.finish(throwing: error)
                    }
                }
                continuation.onTermination = { _ in task.cancel() }
            }
        }
    )

    static var previewValue: MatchListRepoClient = .liveValue

    static var testValue: MatchListRepoClient = .init(
        fetchUpdates: {
            AsyncThrowingStream<MatchListRepository.DataType, Error> { continuation in
                continuation.finish()
            }
        }
    )
}

extension DependencyValues {
    var matchListRepo: MatchListRepoClient {
        get { self[MatchListRepoClient.self] }
        set { self[MatchListRepoClient.self] = newValue }
    }
}

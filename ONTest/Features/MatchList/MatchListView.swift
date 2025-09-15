//
//  MatchListView.swift
//  ONTest
//
//  Created by bomi on 2025/8/29.
//

import SwiftUI
import ComposableArchitecture

struct MatchListView: View {
    let store: StoreOf<MatchListFeature>
    
    var body: some View {
        NavigationStack {
            List(store.rows) { row in
                MatchRowView(row: row)
                .listRowSeparator(.hidden)
                .listRowInsets(.init(top: 12, leading: 16, bottom: 12, trailing: 16))
            }
            .listStyle(.plain)
            .overlay {
                if store.isLoading {
                    loadingView
                } else if let err = store.errorMessage {
                    errorView(Text(err))
                }
            }
            .navigationTitle("Matches & Odds")
            .task { await store.send(.task).finish() }
            .onDisappear { store.send(.stop) }
        }
    }
    
    @MainActor
    private var loadingView: some View {
        ProgressView("Loading…")
    }
    
    @MainActor
    private func errorView(_ text: Text) -> some View {
        ContentUnavailableView("Error", systemImage: "exclamationmark.triangle", description: text)
    }
}

#Preview("DEV") {
    withDependencies {
        $0.matchListRepo = .liveValue
        $0.ws = .liveValue
    } operation: {
        MatchListView(
            store: Store(initialState: MatchListFeature.State()) {
                MatchListFeature()
            }
        )
    }
}

#Preview("Mock") {
    withDependencies {
        $0.matchListRepo = .previewValue
        $0.ws = .previewValue
    } operation: {
        MatchListView(
            store: Store(initialState: MatchListFeature.State()) {
                MatchListFeature()
            }
        )
    }
}

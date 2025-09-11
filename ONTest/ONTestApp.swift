//
//  ONTestApp.swift
//  ONTest
//
//  Created by bomi on 2025/8/29.
//

import SwiftUI
import IssueReporting
import ComposableArchitecture

@main
struct ONTestApp: App {
    
    var body: some Scene {
        WindowGroup {
            if !isTesting {
                AppRootView()
            }
        }
    }
}

struct AppRootView: View {
    let store = Store(
        initialState: .init(),
        reducer: { AppFeature()
        })
    var body: some View {
        ZStack {
            TabView {
                MatchListView(
                    store: store.scope(state: \.matchList, action: \.matchList)
                )
                .tabItem {
                    Label("Matches", systemImage: "sportscourt")
                }
                
                SecondTabView()
                .tabItem {
                    Label("Second Page", systemImage: "gear")
                }
            }
            
            VStack {
                FPSBadge()
                Spacer()
            }
        }
        .task { await store.send(.task).finish() }
    }
}

#Preview("DEV") {
    withDependencies {
        $0.ws = .liveValue
    } operation: {
        AppRootView()
    }
}


//
//  ONTestApp.swift
//  ONTest
//
//  Created by bomi on 2025/8/29.
//

import SwiftUI
import IssueReporting

@main
struct ONTestApp: App {
    
    var body: some Scene {
        WindowGroup {
            if !isTesting {
                
                ZStack {
                    TabView {
                        MatchListView(
                            store: .init(initialState: .init(), reducer: { MatchListFeature() })
                        )
                        .tabItem { Label("Matches", systemImage: "sportscourt") }
                        
                        SecondTabView()
                            .tabItem { Label("Second Page", systemImage: "gear") }
                    }
                    
                    VStack {
                        FPSBadge()
                        Spacer()
                    }
                }
            }
        }
    }
}

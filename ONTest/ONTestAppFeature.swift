//
//  Untitled.swift
//  ONTest
//
//  Created by bomi on 2025/9/11.
//

//import SwiftUI
import ComposableArchitecture

@Reducer
struct AppFeature {
    
    struct State: Equatable {
        var matchList = MatchListFeature.State()
    }
    
    enum Action: Equatable {
        case task
        case matchList(MatchListFeature.Action)
    }
    
    @Dependency(\.ws) var ws
    
    var body: some Reducer<State, Action> {
        
        Scope(state: \.matchList, action: \.matchList) {
            MatchListFeature()
        }
        
        Reduce { state, action in
            switch action {
            case .task:
                return .run { [ws] _ in
                    await ws.launch()
                }
            case .matchList:
                return .none
            }
        }
    }
}

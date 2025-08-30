//
//  MatchRowView.swift
//  ONTest
//
//  Created by bomi on 2025/8/29.
//

import SwiftUI

struct MatchRowView: View {
    let teamA: String
    let teamB: String
    let time: String
    let teamAOdds: String
    let teamBOdds: String
    
    var body: some View {
        VStack() {
            VStack(spacing: 12) {
                HStack {
                    Text(teamA)
                    Spacer()
                    Text("主隊")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(teamAOdds)
                        .bold()
                }
                HStack {
                    Text(teamB)
                        .foregroundColor(.blue)
                    Spacer()
                    Text("客隊")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(teamBOdds)
                        .bold()
                }
                Text(time)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            Divider()
                .padding(.top, 4)
        }
        .font(.subheadline.monospacedDigit())
        .padding(.top, 8)
    }
}

//
//  MatchRowView.swift
//  ONTest
//
//  Created by bomi on 2025/8/29.
//

import SwiftUI

struct MatchRowView: View {
    
    let row: MatchListFeature.State.Row
    
    var body: some View {
        VStack() {
            VStack(spacing: 12) {
                HStack {
                    Text(row.teamA)
                    Spacer()
                    Text("主隊")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(row.teamAOdds)
                        .bold()
                }
                HStack {
                    Text(row.teamB)
                        .foregroundColor(.blue)
                    Spacer()
                    Text("客隊")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(row.teamBOdds)
                        .bold()
                }
                Text(row.time)
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

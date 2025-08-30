//
//  FPSBadge.swift
//  ONTest
//
//  Created by bomi on 2025/9/2.
//

import SwiftUI
import QuartzCore

final class FPSCounter: ObservableObject {
    @Published var fps: Int = 0
    private var lastTimestamp: CFTimeInterval = 0
    private var frames = 0
    private var link: CADisplayLink?

    func start() {
        link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link?.add(to: .main, forMode: .common)
    }
    func stop() { link?.invalidate(); link = nil }

    @objc private func tick(_ link: CADisplayLink) {
        if lastTimestamp == 0 { lastTimestamp = link.timestamp; return }
        frames += 1
        let delta = link.timestamp - lastTimestamp
        if delta >= 1 {
            fps = frames
            frames = 0
            lastTimestamp = link.timestamp
        }
    }
}

struct FPSBadge: View {
    @StateObject private var counter = FPSCounter()
    var body: some View {
        Text("FPS \(counter.fps)")
            .font(.system(size: 12, weight: .semibold, design: .monospaced))
            .padding(6)
            .background(.black.opacity(0.6))
            .foregroundStyle(.green)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .onAppear { counter.start() }
            .onDisappear { counter.stop() }
    }
}

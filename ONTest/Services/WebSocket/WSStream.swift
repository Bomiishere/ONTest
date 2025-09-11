//
//  WSStream.swift
//  ONTest
//
//  Created by bomi on 2025/08/31.
//

import Foundation
import Combine

actor WSStream {
    
    enum State { case idle, connecting, connected, disconnected }
    
    private var state: State = .idle

    // MARK: Subscribe
    private var subscribed: [String: SubscribeEntry] = [:]  // destination -> entry
    private struct SubscribeEntry {
        var continuations: [UUID: (Any) -> Void] = [:]  // type-erased yield
        let parser: ([Substring]) -> Any?
    }

    // MARK: - Reconnect
    private var reconnectAttempts: Int = 0
    private var totalReconnectTime: TimeInterval = 0
    private let maxReconnectTime: TimeInterval = 24 * 60 * 60

    // MARK: - Mock
    private var mockOddsMessageTimer: AnyCancellable?
    private var mockFailureTimer: AnyCancellable?

    // MARK: - Public
    func launch() async {
        await startSession()
    }

    func subscribe<Topic: WSTopicSpec>(_ type: Topic.Type) async throws -> AsyncStream<Topic.Output> {
        
        await startSession()

        let destination = Topic.destination

        // ensure entry send SUBSCRIBE once per destination
        if subscribed[destination] == nil {
            subscribed[destination] = SubscribeEntry(
                continuations: [:],
                parser: { fields in
                    if let v = Topic.parse(fields) { return v as Any } else { return nil }
                }
            )
            sendSubscribeMessage(destination)
        }

        return AsyncStream { continuation in
            let id = UUID()
            let sink: (Any) -> Void = { any in
                if let value = any as? Topic.Output {
                    continuation.yield(value)
                }
            }
            subscribed[destination]?.continuations[id] = sink

            continuation.onTermination = { [weak self] _ in
                Task { await self?.removeContinuation(id, destination: destination) }
            }
        }
    }

    deinit { print("WSStream deinit") }
}

// MARK: - Private
private extension WSStream {
    func removeContinuation(_ id: UUID, destination: String) {
        guard var entry = subscribed[destination] else { return }
        entry.continuations[id] = nil
        subscribed[destination] = entry
        if entry.continuations.isEmpty {
            subscribed.removeValue(forKey: destination)
            sendUnsubscribeMessage(destination)
        }
    }

    func startSession() async {
        guard state == .idle || state == .disconnected else { return }
        state = .connecting
        await sendConnect()
        startReceiveMessages()
    }
    
    func startReceiveMessages() {
        clearMockDataTimer()
        
        // 0) Mock Connected
        mockConnect()
        
        // 1) Mock MESSAGE for /odds
        mockOddsMessageTimer = Timer
            .publish(every: 1.0, on: .main, in: .default)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.mockOddsMessage() }
            }

        // 2) Mock FAIL for 10s per failure
        mockFailureTimer = Just(())
            .delay(for: .seconds(10), scheduler: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.mockWSFailure() }
            }
    }
    
    // MARK: - Parser & dispatcher
     /**
      Protocols
      
      CONNECTED
      
      MESSAGE (destination) (kv pairs)
      */
    func parseMessage(_ text: String) {
        // Split once into pieces: [EVENT, destination, kv pairs...]
        let parts = text.split(separator: " ")
        guard let eventRaw = parts.first, let event = WSEvent(rawValue: String(eventRaw)) else { return }

        switch event {
        case .connected:
            handleConnected()

        case .message:
            guard parts.count >= 2 else { return }
            
            let destination = String(parts[1])
            let payloadFields = Array(parts.dropFirst(2))

            // grab subscribed entry for how to parse this destination
            guard let entry = subscribed[destination], let value = entry.parser(payloadFields) else { return }

            // Broadcast to subscribers of that destination
            for sink in entry.continuations.values { sink(value) }
        }
    }
    
    func sendConnect() async {
        print("[WS] Send Connect")
    }

    func sendSubscribeMessage(_ destination: String) {
        print("[WS] Subscribe: \(destination)")
    }
    
    func sendUnsubscribeMessage(_ destination: String) {
        print("[WS] Unsubscribe: \(destination)")
    }
    
    func handleConnected() {
        print("[WS] Connected")
        state = .connected
    }
    
    func handleFailure() {
        print("[WS] Fail")
        disconnect()
        Task {
            // for more obviously failure, wait three secs then reconnect
            try? await Task.sleep(nanoseconds: 3 * 1_000_000_000)
            await reconnect()
        }
    }
    
    func disconnect() {
        print("[WS] Disconnect")
        state = .disconnected
        reconnectAttempts = 0
        totalReconnectTime = 0
        clearMockDataTimer()
    }
    
    // MARK: - Reconnect loop
    func reconnect() async {
        if case .connected = state {
            reconnectAttempts = 0
            totalReconnectTime = 0
            return
        }
        print("[WS] Try to Reconnect...")
        if totalReconnectTime >= maxReconnectTime { return }

        let delay = pow(2.0, Double(reconnectAttempts))  // 1, 2, 4, 8...
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        totalReconnectTime += delay

        await startSession()
        if case .connected = state {
            reconnectAttempts = 0
            totalReconnectTime = 0
        } else {
            reconnectAttempts += 1
            await reconnect()
        }
    }
}

//MARK: Mock Data
private extension WSStream {
    
    func mockConnect() {
        parseMessage(WSEvent.connected.rawValue)
    }
    
    func mockOddsMessage() {
        guard case .connected = state else { return }
        (0..<100).forEach { i in
            let id = Int.random(in: 1001...1100)
            let a  = Double.random(in: 1.5...3.0)
            let b  = Double.random(in: 1.5...3.0)
            let text = "MESSAGE /odds matchID=\(id) teamAOdds=\(String(format: "%.2f", a)) teamBOdds=\(String(format: "%.2f", b))"
            parseMessage(text)
        }
    }

    func mockWSFailure() async {
        handleFailure()
    }

    func clearMockDataTimer() {
        mockOddsMessageTimer?.cancel()
        mockOddsMessageTimer = nil
        mockFailureTimer?.cancel()
        mockFailureTimer = nil
    }
}

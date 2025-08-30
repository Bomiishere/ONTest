//
//  WSStream.swift
//  ONTest
//
//  Created by bomi on 2025/8/31.
//

import Foundation
import Combine

actor WSStream<Topic: WSTopicSpec> {
    public enum State { case idle, connecting, connected, disconnected }

    private var state: State = .idle
    
    private let subject = PassthroughSubject<Topic.Output, Never>()
    
    private var reconnectAttempts: Int = 0
    private var totalReconnectTime: TimeInterval = 0
    private let maxReconnectTime: TimeInterval = 24 * 60 * 60
    
    //for test
    private var mockMessageTimer: AnyCancellable?
    private var failConnectionTimer: AnyCancellable?

    func updates() async -> AsyncStream<Topic.Output> {
        await startSession()

        return AsyncStream { continuation in
            let cancellable = subject.sink { value in
                continuation.yield(value)
            }
            continuation.onTermination = { @Sendable _ in
                cancellable.cancel()
                Task { await self.disconnect() }
            }
        }
    }

    /// 主動中斷連線與清理狀態。
    public func disconnect() {
        state = .disconnected
        reconnectAttempts = 0
        totalReconnectTime = 0
        
        //for test
        mockMessageTimer?.cancel()
        failConnectionTimer?.cancel()
        mockMessageTimer = nil
        failConnectionTimer = nil
    }

    deinit { print("WSStream<\(Topic.self)> deinit") }
}

private extension WSStream {
    func startSession() async {
        guard mockMessageTimer == nil else { return }
        state = .connecting
        
        // send connect, start receiving message
        await sendConnect()
        
        // send subscribe message
        sendSubscribeMessage(Topic.destination)
        
        // simulate start receving WS messages in timer
        if Topic.mockEnabled {
            mockMessageTimer = Timer
                .publish(every: 1.0, on: .main, in: .default)
                .autoconnect()
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    guard let self else { return }
                    Task { await self.mockTopicMessages() }
                }
        }

        // simulate fail connection from WS
        failConnectionTimer = Just(())
            .delay(for: .seconds(Topic.mockFailureInterval), scheduler: DispatchQueue.main)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self else { return }
                Task { await self.pretendWSFailConnection() }
            }
    }
    
    func sendConnect() async {
        print("[WS] Send Connect")
        //start receiving message
        
        //pretend received connected message
        state = .connected
    }
    
    func sendSubscribeMessage(_ destination: String) {
        print("[WS] Subscribe: \(destination)")
    }

    func mockTopicMessages() {
        guard case .connected = state, let _ = Topic.mockUpdate() else { return }
        let count = Int.random(in: Topic.mockUpdatePerSecondRange)
        for _ in 0..<count {
            guard let update = Topic.mockUpdate() else { break }
            subject.send(update)
        }
    }

    func pretendWSFailConnection() async {
        print("[WS] Fail")
        disconnect()
        
        // 3 秒後嘗試重連
        try? await Task.sleep(nanoseconds: UInt64(3 * 1_000_000_000))
        await reconnect()
    }

    func reconnect() async {
        if case .connected = state {
            reconnectAttempts = 0
            totalReconnectTime = 0
            return
        }
        
        print("[WS] Try to Reconnect...")
        
        // 超過 24 小時停止
        if totalReconnectTime >= maxReconnectTime { return }

        // 指數嘗試重新連線（1, 2, 4, 8...秒）
        let delay: TimeInterval = 1 * pow(2.0, Double(reconnectAttempts))
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        totalReconnectTime += delay

        await startSession()

        if case .connected = state {
            reconnectAttempts = 0
            totalReconnectTime = 0
            return
        } else {
            reconnectAttempts += 1
            await reconnect()
        }
    }
}

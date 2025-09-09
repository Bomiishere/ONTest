//
//  APIService.swift
//  ONTest
//
//  Created by bomi on 2025/8/30.
//

import ComposableArchitecture
import Foundation

actor APIService {
    private let config: APIConfig
    private let session: URLSession
    
    init(config: APIConfig = .default, session: URLSession = URLSession(configuration: .default)) {
        self.config = config
        self.session = session
    }
    
    func send(_ endpoint: APIEndPoint) async throws -> Data {
        var request = try endpoint.asURLRequest(baseURL: config.baseURL)
        
        // headers
        for (k, v) in config.defaultHeaders { request.setValue(v, forHTTPHeaderField: k) }
        if let extraHeaders = endpoint.headers {
            for (k, v) in extraHeaders { request.setValue(v, forHTTPHeaderField: k) }
        }
        
        // timeout
        request.timeoutInterval = endpoint.timeout ?? config.timeout
        
        do {
            let (data, resp) = try await session.data(for: request)
            guard let http = resp as? HTTPURLResponse else { throw APIError.unknown }
            guard (200..<300).contains(http.statusCode) else {
                throw APIError.serverError(status: http.statusCode, data: data)
            }
            return data
        } catch let urlErr as URLError {
            throw APIError.requestFailed(urlErr)
        } catch {
            throw error
        }
    }
    
//    deinit { print("APIService deinit") }
}

extension APIService {
    func fetch<T: Decodable>(_ endpoint: APIEndPoint, _ responseType: T.Type = T.self) async throws -> T {
        switch endpoint {
        case .matches:
            let service = MockMatchService()
            return try await service.fetchMatches() as! T
        case .oddsList:
            let service = MockOddsService()
            return try await service.fetchOddsList() as! T
        default:
            break
        }
        let data = try await send(endpoint)
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decodingFailed(error)
        }
    }
}

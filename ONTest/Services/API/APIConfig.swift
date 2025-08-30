//
//  APIConfig.swift
//  ONTest
//
//  Created by bomi on 2025/8/30.
//

import Foundation

struct APIConfig: Sendable, Equatable {
    var baseURL: URL
    var defaultHeaders: [String: String] = ["Accept": "application/json"]
    var timeout: TimeInterval = 15
}

extension APIConfig {
    static var `default`: APIConfig {
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
              let url = URL(string: urlString) else {
            fatalError("API_BASE_URL not found or invalid in Info.plist")
        }
        return APIConfig(baseURL: url)
    }
}

enum APIError: Error, LocalizedError {
    case invalidURL
    case requestFailed(URLError)
    case serverError(status: Int, data: Data?)
    case decodingFailed(Error)
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case let .requestFailed(u): return "Request failed: \(u)"
        case let .serverError(code, _): return "HTTP \(code)"
        case let .decodingFailed(e): return "Decoding failed: \(e)"
        case .unknown: return "Unknown error"
        }
    }
}

extension APIError: Equatable {
    static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL):
            return true
        case let (.requestFailed(l), .requestFailed(r)):
            return l.code == r.code
        case let (.serverError(lc, _), .serverError(rc, _)):
            return lc == rc
        case (.decodingFailed, .decodingFailed):
            return true
        case (.unknown, .unknown):
            return true
        default:
            return false
        }
    }
}

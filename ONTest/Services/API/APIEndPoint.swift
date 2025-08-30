//
//  APIEndPoint.swift
//  ONTest
//
//  Created by bomi on 2025/8/30.
//

import Foundation

enum APIEndPoint {
    case matches
    case oddsList
    case sendFeedback(message: String, email: String?)
}

enum HTTPMethod: String {
    case GET, POST
}

enum HTTPBody {
    case none
    case json([String: Any?])
}

extension APIEndPoint {
    var path: String {
        switch self {
        case .matches: return "/api/matches"
        case .oddsList:    return "/api/odds"
        case .sendFeedback: return "/feedback"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        case .matches, .oddsList: return .GET
        case .sendFeedback:   return .POST
        }
    }
    
    var queries: [String: Any]? {
        switch self {
        default:
            return nil
        }
    }
    
    var body: HTTPBody {
        switch self {
        case let .sendFeedback(message, email):
            return .json([
                "message": message,
                "email": email
            ])
        default:
            return .none
        }
    }
    
    var headers: [String: String]? {
        switch self {
        default:
            return nil
        }
    }
    
    var timeout: TimeInterval? {
        switch self {
        default:
            return nil
        }
    }
    
    func asURLRequest(baseURL: URL) throws -> URLRequest {
        
        guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw URLError(.badURL)
        }
        components.path = path
        if let queries = queries {
            components.queryItems = queries.map { URLQueryItem(name: $0.key, value: "\($0.value)") }
        }
        
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        switch body {
        case .none:
            break
        case .json(let dict):
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let cleaned = dict.compactMapValues { $0 }
            request.httpBody = try JSONSerialization.data(withJSONObject: cleaned, options: [])
        }
        
        return request
    }
}

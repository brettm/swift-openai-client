//
//  OpenAIClient.swift
//  OpenAIClient
//
//  Created by Brett on 12/01/2023.
//
// Reference: https://beta.openai.com/docs/api-reference/completions/create

import Foundation

protocol Model: Encodable {}

public struct CompletionsModel: Model {
    var model: String
    var prompt: [String]?
    var maxTokens: Int?
    var temperature: Float?

    enum CodingKeys: String, CodingKey {
        case model
        case prompt
        case maxTokens = "max_tokens"
        case temperature
    }
}

protocol Response: Decodable {}

public struct Usage: Decodable {
    var promptTokens: Int
    var completionTokens: Int
    var totalTokens: Int

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

public struct Choice: Decodable {
    var text: String
    var index: Int
    var logprobs: Int?
    var finishReason: String

    enum CodingKeys: String, CodingKey {
        case text
        case index
        case logprobs
        case finishReason = "finish_reason"
    }
}

public struct CompletionsResponse: Response {
    var id: String
    var object: String
    var model: String
    var choices: [Choice]
    var usage: Usage
}

public enum OpenAIService {
    case completions(CompletionsModel)

    var path: String {
        switch self {
        case .completions:
            return "completions"
        }
    }

    var httpMethod: String {
        switch self {
        case .completions:
            return "POST"
        }
    }

    var model: Model {
        switch self {
        case .completions(let model): return model
        }
    }

    func url(host: URL) -> URL! {
        return host.appending(path: self.path)
    }

    func request(client: OpenAIClient) async throws -> Response? {
        guard let data = try await client.fetch(self) else {
            return nil
        }
        return try self.response(from: data)
    }

    func response(from data: Data) throws -> Response {
        switch self {
        case .completions(_): return try JSONDecoder().decode(CompletionsResponse.self, from: data)
        }
    }
}

public class OpenAIClient {
    let version: String
    let hostURL: URL
    var baseURL: URL {
        hostURL.appending(path: version)
    }
    let session: URLSession
    let apiKey: String
    let orgId: String

    public init(
        apiKey: String,
        orgId: String = "org-LHn8F46kcMZ3IzDnuySzyYZm",
        version: String = "v1",
        hostURL: URL = URL(string: "https://api.openai.com/")!,
        session: URLSession = URLSession.shared
    ) {
        self.apiKey = apiKey
        self.orgId = orgId
        self.version = version
        self.hostURL = hostURL
        self.session = session
    }

    private func createRequest(for service: OpenAIService) -> URLRequest {
        var request = URLRequest(url: service.url(host: self.baseURL))
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    func fetch(_ service: OpenAIService) async throws -> Data? {
        var request = self.createRequest(for: service)
        request.httpMethod = service.httpMethod
        if request.httpMethod == "POST" {
            request.httpBody = try JSONEncoder().encode(service.model)
            let (data, response) = try await URLSession.shared.data(for: request)
            print(response)
            print(String(decoding: data, as: UTF8.self))
            return data
        }
        return nil
    }
}


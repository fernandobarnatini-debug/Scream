import Foundation

/// Minimal client for the local Ollama HTTP API. Every call is best-effort:
/// callers treat any failure as "insert the raw transcript".
struct OllamaClient: Sendable {
    var baseURL = URL(string: "http://localhost:11434")!
    /// Hard cap on cleanup latency — insertion must never feel blocked.
    var timeout: TimeInterval = 4.0

    func chat(model: String, system: String, user: String) async throws -> String {
        struct Message: Codable {
            let role: String
            let content: String
        }
        struct Request: Encodable {
            let model: String
            let messages: [Message]
            let stream: Bool
            let keep_alive: String
            let options: [String: Double]
        }
        struct Response: Decodable {
            let message: Message
        }

        var request = URLRequest(url: baseURL.appending(path: "api/chat"), timeoutInterval: timeout)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(Request(
            model: model,
            messages: [
                Message(role: "system", content: system),
                Message(role: "user", content: user),
            ],
            stream: false,
            keep_alive: "10m",
            options: ["temperature": 0]
        ))

        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(Response.self, from: data).message.content
    }

    func listModels() async throws -> [String] {
        struct Response: Decodable {
            struct Model: Decodable {
                let name: String
            }
            let models: [Model]
        }
        var request = URLRequest(url: baseURL.appending(path: "api/tags"), timeoutInterval: 2.0)
        request.httpMethod = "GET"
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(Response.self, from: data).models.map(\.name)
    }

    /// Kicks model load so it overlaps with the user speaking.
    func warmUp(model: String) async {
        struct Request: Encodable {
            let model: String
            let prompt: String
            let keep_alive: String
        }
        var request = URLRequest(url: baseURL.appending(path: "api/generate"), timeoutInterval: 10)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(Request(model: model, prompt: "", keep_alive: "10m"))
        _ = try? await URLSession.shared.data(for: request)
    }
}

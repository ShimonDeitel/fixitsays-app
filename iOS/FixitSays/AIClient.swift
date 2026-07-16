import Foundation

// MARK: - Configuration

/// FixitSays talks to its own Cloudflare Worker (fixitsays-api), which fronts Cloudflare
/// Workers AI and speaks the same OpenAI-compatible chat-completions wire shape. There is NO
/// API key in the app: any string compiled into a shipped binary is trivially extractable, so
/// the backend uses Workers AI via a server-side binding (no provider key anywhere) and bounds
/// abuse per-IP. Only the user's typed symptom description and appliance category are ever sent.
enum AIConfig {
    static let endpoint = URL(string: "https://fixitsays-api.s0533495227.workers.dev")!
    /// Model hint sent only for wire-shape parity; the Worker selects the actual Workers AI model.
    static let model = "openai/gpt-4o-mini"
    static let maxTokens = 900
    static let temperature = 0.2
    static let timeout: TimeInterval = 30
    /// Free tier: diagnoses per day.
    static let freeDailyLimit = 3
}

// MARK: - Errors

enum AIError: Error, LocalizedError {
    case badResponse
    case http(Int)
    case decoding
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .badResponse: return "No response from the service. Check your connection."
        case .http(let code): return "Service returned \(code). Try again in a moment."
        case .decoding: return "Couldn't read the result. Try again."
        case .rateLimited: return "You've used today's free diagnoses. Go Pro for unlimited, or come back tomorrow."
        }
    }
}

// MARK: - Daily rate limit (free tier only)

enum AIRateLimiter {
    private static let countKey = "fixitsays.ai.daily.count"
    private static let dayKey = "fixitsays.ai.daily.day"

    private static var today: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    private static func rollIfNeeded(_ d: UserDefaults) {
        if d.string(forKey: dayKey) != today {
            d.set(today, forKey: dayKey)
            d.set(0, forKey: countKey)
        }
    }

    static func usedToday(_ d: UserDefaults = .standard) -> Int {
        rollIfNeeded(d)
        return d.integer(forKey: countKey)
    }

    static func canCall(isPro: Bool, _ d: UserDefaults = .standard) -> Bool {
        isPro || usedToday(d) < AIConfig.freeDailyLimit
    }

    static func remaining(_ d: UserDefaults = .standard) -> Int {
        max(0, AIConfig.freeDailyLimit - usedToday(d))
    }

    static func recordCall(_ d: UserDefaults = .standard) {
        rollIfNeeded(d)
        d.set(d.integer(forKey: countKey) + 1, forKey: countKey)
    }
}

// MARK: - Wire types

private struct ChatMessage: Encodable { let role: String; let content: String }

private struct ChatRequest: Encodable {
    struct ResponseFormat: Encodable { let type: String }
    let model: String
    let messages: [ChatMessage]
    let response_format: ResponseFormat
    let max_tokens: Int
    let temperature: Double
}

private struct ChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable { let content: String? }
        let message: Message?
    }
    let choices: [Choice]
}

/// One likely cause. Tolerant of loose model output.
struct WireCause: Codable, Identifiable, Equatable {
    var id: String { label }
    var label: String = ""
    var likelihood: String = "medium"
    var explanation: String = ""

    enum CodingKeys: String, CodingKey { case label, likelihood, explanation }

    init(label: String = "", likelihood: String = "medium", explanation: String = "") {
        self.label = label
        self.likelihood = likelihood
        self.explanation = explanation
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        label = (try? c.decode(String.self, forKey: .label)) ?? ""
        likelihood = ((try? c.decode(String.self, forKey: .likelihood)) ?? "medium").lowercased()
        explanation = (try? c.decode(String.self, forKey: .explanation)) ?? ""
    }

    var likelihoodLabel: String {
        switch likelihood {
        case "high": return "Most likely"
        case "low": return "Less likely"
        default: return "Possible"
        }
    }
}

/// The full diagnosis off the wire.
struct WireDiagnosis: Decodable, Equatable {
    var causes: [WireCause] = []
    var verdict: String = "call_a_pro"
    var steps: [String] = []

    enum CodingKeys: String, CodingKey { case causes, verdict, steps }
    init() {}
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        causes = (try? c.decode([WireCause].self, forKey: .causes)) ?? []
        verdict = ((try? c.decode(String.self, forKey: .verdict)) ?? "call_a_pro").lowercased()
        steps = (try? c.decode([String].self, forKey: .steps)) ?? []
    }

    var isUsable: Bool { !causes.isEmpty }
    var verdictEnum: Verdict { Verdict(rawValue: verdict) ?? .callAPro }
}

// MARK: - Client

final class AIClient {
    static let shared = AIClient()

    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let cfg = URLSessionConfiguration.default
            cfg.timeoutIntervalForRequest = AIConfig.timeout
            cfg.timeoutIntervalForResource = AIConfig.timeout
            self.session = URLSession(configuration: cfg)
        }
    }

    func diagnose(category: ApplianceCategory, symptom: String) async throws -> WireDiagnosis {
        let user = "APPLIANCE / SYSTEM: \(category.rawValue)\nSYMPTOM (user's own words):\n\(symptom)"
        let content = try await chat(system: Self.systemPrompt, user: user)
        let wire: WireDiagnosis = try Self.decodeContent(content)
        guard wire.isUsable else { throw AIError.decoding }
        return wire
    }

    static let systemPrompt = """
    You are a practical, safety-conscious home-appliance and home-systems diagnostician. The user describes a symptom in plain English; you give the most likely causes and a clear do-it-yourself-or-call-a-pro verdict.

    Return ONLY a single JSON object - no markdown, no prose, no code fences - with EXACTLY this shape:
    {
      "causes": [
        { "label": string, "likelihood": "high" | "medium" | "low", "explanation": string }
      ],
      "verdict": "diy_safe" | "diy_with_caution" | "call_a_pro",
      "steps": [string]
    }

    Rules:
    - 2-3 causes, ranked most likely first. Plain English, no jargon; one short sentence each in "explanation".
    - SAFETY FIRST: any gas smell, electrical sparking/burning smell, breaker issues beyond a simple reset, or anything involving opening sealed refrigerant systems is ALWAYS "call_a_pro" with an empty or evacuation-focused steps list.
    - "steps" only when the verdict is diy_safe or diy_with_caution: 3-6 short numbered-style instructions a non-handy person can follow (no step numbers in the text; the app numbers them).
    - When verdict is call_a_pro, "steps" may contain 1-2 preparation notes (e.g. what to tell the technician).
    - No emojis. Output valid JSON only.
    """

    // MARK: Transport

    private func chat(system: String, user: String) async throws -> String {
        var req = URLRequest(url: AIConfig.endpoint)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // No Authorization header by design: the Worker holds no client-extractable secret, so
        // nothing sensitive ships in the binary. Abuse is bounded per-IP server-side instead.

        let body = ChatRequest(
            model: AIConfig.model,
            messages: [ChatMessage(role: "system", content: system),
                       ChatMessage(role: "user", content: user)],
            response_format: .init(type: "json_object"),
            max_tokens: AIConfig.maxTokens,
            temperature: AIConfig.temperature)
        req.httpBody = try JSONEncoder().encode(body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: req)
        } catch {
            throw AIError.badResponse
        }
        guard let http = response as? HTTPURLResponse else { throw AIError.badResponse }
        guard (200..<300).contains(http.statusCode) else { throw AIError.http(http.statusCode) }

        guard let envelope = try? JSONDecoder().decode(ChatResponse.self, from: data),
              let content = envelope.choices.first?.message?.content,
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIError.badResponse
        }
        return content
    }

    static func decodeContent<R: Decodable>(_ content: String) throws -> R {
        for candidate in jsonCandidates(from: content) {
            if let data = candidate.data(using: .utf8),
               let decoded = try? JSONDecoder().decode(R.self, from: data) {
                return decoded
            }
        }
        throw AIError.decoding
    }

    static func jsonCandidates(from content: String) -> [String] {
        var out: [String] = []
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        out.append(trimmed)
        if trimmed.hasPrefix("```") {
            var s = trimmed
            if let firstNewline = s.firstIndex(of: "\n") { s = String(s[s.index(after: firstNewline)...]) }
            if let fence = s.range(of: "```", options: .backwards) { s = String(s[..<fence.lowerBound]) }
            out.append(s.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        if let open = trimmed.firstIndex(of: "{"), let close = trimmed.lastIndex(of: "}"), open < close {
            out.append(String(trimmed[open...close]))
        }
        return out
    }
}

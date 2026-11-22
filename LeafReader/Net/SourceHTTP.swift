import Foundation

/// Legado 的「URL,选项 JSON」写法，例如：
/// `https://a.com/api,{"method":"POST","headers":{"X":"1"},"body":"k=1"}`
struct SourceRequest {
    var url: URL
    var method: String
    var headers: [String: String]
    var body: Data?

    init?(raw: String, base: String? = nil) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        var urlText = trimmed
        var options: [String: Any] = [:]

        if let range = trimmed.range(of: ",{") {
            let jsonPart = String(trimmed[range.lowerBound...]).dropFirst()
            if let data = String(jsonPart).data(using: .utf8),
               let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                options = object
                urlText = String(trimmed[..<range.lowerBound])
            }
        }

        guard let resolved = SourceRequest.resolveURL(urlText, base: base) else { return nil }
        url = resolved
        method = ((options["method"] as? String) ?? "GET").uppercased()

        if let rawHeaders = options["headers"] as? [String: Any] {
            var headers: [String: String] = [:]
            for (key, value) in rawHeaders {
                headers[key] = "\(value)"
            }
            self.headers = headers
        } else {
            self.headers = [:]
        }

        if let body = options["body"] as? String {
            self.body = body.data(using: .utf8)
        } else if let body = options["body"] as? [String: Any] {
            self.body = try? JSONSerialization.data(withJSONObject: body)
        } else {
            self.body = nil
        }
    }

    static func resolveURL(_ text: String, base: String?) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        if trimmed.lowercased().hasPrefix("http://") || trimmed.lowercased().hasPrefix("https://") {
            return URL(string: trimmed)
        }
        guard let base = base, let baseURL = URL(string: base) else { return nil }
        return URL(string: trimmed, relativeTo: baseURL)?.absoluteURL
    }
}

enum SourceHTTP {
    static let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

    /// 书源 header 字段是 JSON 字符串，合并到每个请求上。
    static func sourceHeaders(_ source: BookSource?) -> [String: String] {
        guard let raw = source?.header, !raw.isEmpty,
              let data = raw.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }
        var result: [String: String] = [:]
        for (key, value) in object {
            result[key] = "\(value)"
        }
        return result
    }

    static func urlRequest(for request: SourceRequest, source: BookSource?) -> URLRequest {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method
        urlRequest.timeoutInterval = 25
        urlRequest.httpBody = request.body

        var headers: [String: String] = ["User-Agent": userAgent, "Accept-Language": "zh-CN,zh;q=0.9"]
        for (key, value) in sourceHeaders(source) { headers[key] = value }
        for (key, value) in request.headers { headers[key] = value }
        for (key, value) in headers { urlRequest.setValue(value, forHTTPHeaderField: key) }

        if request.body != nil, urlRequest.value(forHTTPHeaderField: "Content-Type") == nil {
            urlRequest.setValue("application/x-www-form-urlencoded; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        }
        return urlRequest
    }

    static func fetch(_ request: SourceRequest, source: BookSource?, timeout: TimeInterval = 25) async throws -> String {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout
        configuration.httpCookieAcceptPolicy = .always
        configuration.httpShouldSetCookies = true
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }

        let (data, _) = try await session.data(for: urlRequest(for: request, source: source))
        if let text = String(data: data, encoding: .utf8), !text.isEmpty {
            return text
        }
        return TextDecoder.decode(data)
    }

    /// 供 JavaScriptCore 的 java.ajax 使用：在后台线程阻塞等待。
    static func fetchSync(_ raw: String, source: BookSource?, timeout: TimeInterval = 25) -> String {
        guard let request = SourceRequest(raw: raw, base: source?.bookSourceUrl) else { return "" }
        let semaphore = DispatchSemaphore(value: 0)
        var result = ""
        let session = URLSession(configuration: .default)
        let task = session.dataTask(with: urlRequest(for: request, source: source)) { data, _, _ in
            if let data = data {
                if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                    result = text
                } else {
                    result = TextDecoder.decode(data)
                }
            }
            semaphore.signal()
        }
        task.resume()
        _ = semaphore.wait(timeout: .now() + timeout)
        return result
    }

    static func fetchData(_ url: URL, source: BookSource?, timeout: TimeInterval = 20) async -> Data? {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = timeout
        let session = URLSession(configuration: configuration)
        defer { session.finishTasksAndInvalidate() }
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        for (key, value) in sourceHeaders(source) { request.setValue(value, forHTTPHeaderField: key) }
        guard let (data, _) = try? await session.data(for: request) else { return nil }
        return data
    }
}
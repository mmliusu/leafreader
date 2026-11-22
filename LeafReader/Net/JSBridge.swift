import Foundation
import JavaScriptCore
import CryptoKit

/// 在 JavaScriptCore 里跑书源的 @js: 规则与 jsLib，提供 Legado 的 java.* 子集。
final class JSBridge {
    static let shared = JSBridge()

    private let queue = DispatchQueue(label: "leafreader.js.bridge", qos: .userInitiated)
    private var contexts: [String: JSContext] = [:]

    private init() {}

    func evaluate(
        script: String,
        result: String,
        baseUrl: String,
        source: BookSource?,
        vars: [String: String]
    ) -> String {
        guard let source = source, !script.isEmpty else { return "" }
        var output = ""
        queue.sync {
            let context = self.context(for: source)
            self.prepare(context, result: result, baseUrl: baseUrl, vars: vars)
            let value = context.evaluateScript(script)
            if let exception = context.exception {
                NSLog("[LeafReader][JS] %@", exception.toString() ?? "")
                context.exception = nil
                output = ""
                return
            }
            output = self.stringify(value, context: context)
        }
        return output
    }

    // MARK: - 上下文

    private func context(for source: BookSource) -> JSContext {
        if let cached = contexts[source.bookSourceUrl] {
            return cached
        }
        let context: JSContext = JSContext()
        inject(context: context, source: source)
        if let lib = source.jsLib, !lib.isEmpty {
            context.evaluateScript(lib)
            if let exception = context.exception {
                NSLog("[LeafReader][jsLib] %@", exception.toString() ?? "")
                context.exception = nil
            }
        }
        contexts[source.bookSourceUrl] = context
        return context
    }

    private func prepare(_ context: JSContext, result: String, baseUrl: String, vars: [String: String]) {
        context.setObject(result, forKeyedSubscript: "result" as NSString)
        context.setObject(baseUrl, forKeyedSubscript: "baseUrl" as NSString)
        context.setObject(baseUrl, forKeyedSubscript: "url" as NSString)
        let key = vars["key"] ?? ""
        let page = Int(vars["page"] ?? "1") ?? 1
        context.setObject(key, forKeyedSubscript: "key" as NSString)
        context.setObject(page, forKeyedSubscript: "page" as NSString)
        context.setObject(key, forKeyedSubscript: "searchKey" as NSString)
        context.setObject(page, forKeyedSubscript: "searchPage" as NSString)
        context.evaluateScript("var title = ''; var book = null; var chapter = null;")
    }

    private func inject(context: JSContext, source: BookSource) {
        guard let java = JSValue(newObjectIn: context) else { return }

        let ajax: @convention(block) (AnyObject) -> String = { argument in
            let raw: String
            if let text = argument as? String {
                raw = text
            } else if let dict = argument as? [String: Any], let url = dict["url"] as? String {
                raw = url
            } else {
                raw = ""
            }
            return SourceHTTP.fetchSync(raw, source: source)
        }
        java.setObject(ajax, forKeyedSubscript: "ajax" as NSString)

        let base64Encode: @convention(block) (String) -> String = { text in
            Data(text.utf8).base64EncodedString()
        }
        java.setObject(base64Encode, forKeyedSubscript: "base64Encode" as NSString)

        let base64Decode: @convention(block) (String) -> String = { text in
            guard let data = Data(base64Encoded: text) else { return "" }
            return String(data: data, encoding: .utf8) ?? ""
        }
        java.setObject(base64Decode, forKeyedSubscript: "base64DecodeToString" as NSString)
        java.setObject(base64Decode, forKeyedSubscript: "base64Decode" as NSString)

        let md5: @convention(block) (String) -> String = { text in
            InsecureHash.md5(text)
        }
        java.setObject(md5, forKeyedSubscript: "md5Encode" as NSString)
        java.setObject(md5, forKeyedSubscript: "md5Encode16" as NSString)

        let log: @convention(block) (AnyObject) -> Void = { value in
            NSLog("[LeafReader][source] %@", "\(value)")
        }
        java.setObject(log, forKeyedSubscript: "log" as NSString)
        java.setObject(log, forKeyedSubscript: "toast" as NSString)
        java.setObject(log, forKeyedSubscript: "longToast" as NSString)

        let empty: @convention(block) () -> String = { "" }
        for name in ["getString", "startBrowser", "startBrowserAwait", "getDeviceId", "getAndroidId", "getImei", "getSerial"] {
            java.setObject(empty, forKeyedSubscript: name as NSString)
        }

        let deviceModel: @convention(block) () -> String = { "iPhone" }
        java.setObject(deviceModel, forKeyedSubscript: "getDeviceModel" as NSString)

        let timeFormat: @convention(block) (Double) -> String = { timestamp in
            let date = Date(timeIntervalSince1970: timestamp > 100000000000 ? timestamp / 1000 : timestamp)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy/MM/dd HH:mm"
            return formatter.string(from: date)
        }
        java.setObject(timeFormat, forKeyedSubscript: "timeFormat" as NSString)

        let getSource: @convention(block) () -> AnyObject = {
            guard let object = JSValue(newObjectIn: context) else { return NSNull() }
            object.setObject(source.bookSourceUrl, forKeyedSubscript: "bookSourceUrl" as NSString)
            object.setObject(source.bookSourceName, forKeyedSubscript: "bookSourceName" as NSString)
            object.setObject(source.header ?? "", forKeyedSubscript: "header" as NSString)
            let getKey: @convention(block) () -> String = { "" }
            object.setObject(getKey, forKeyedSubscript: "getKey" as NSString)
            return object
        }
        java.setObject(getSource, forKeyedSubscript: "getSource" as NSString)

        if let util = JSValue(newObjectIn: context) {
            java.setObject(util, forKeyedSubscript: "util" as NSString)
        }
        context.setObject(java, forKeyedSubscript: "java" as NSString)

        let cookie = JSValue(newObjectIn: context)
        let emptyCookie: @convention(block) (String) -> String = { _ in "" }
        cookie?.setObject(emptyCookie, forKeyedSubscript: "getCookie" as NSString)
        let noopCookie: @convention(block) (String, String) -> Void = { _, _ in }
        cookie?.setObject(noopCookie, forKeyedSubscript: "setCookie" as NSString)
        context.setObject(cookie, forKeyedSubscript: "cookie" as NSString)

        if let sourceValue = getSource() as? JSValue {
            context.setObject(sourceValue, forKeyedSubscript: "source" as NSString)
        }

        context.evaluateScript(
            "var Packages = { java: { security: { MessageDigest: function(){} }, util: {} } };"
        )
    }

    // MARK: - 结果转换

    private func stringify(_ value: JSValue?, context: JSContext) -> String {
        guard let value = value, !value.isUndefined, !value.isNull else { return "" }
        if value.isString {
            return value.toString() ?? ""
        }
        if value.isArray {
            let items = value.toArray() ?? []
            return items.map { "\($0)" }.joined(separator: "\n")
        }
        if value.isObject {
            if let json = context.evaluateScript("(function(v){ return JSON.stringify(v); })")?.call(withArguments: [value]),
               json.isString {
                let text = json.toString() ?? ""
                return text == "{}" ? "" : text
            }
        }
        return value.toString() ?? ""
    }
}

enum InsecureHash {
    static func md5(_ text: String) -> String {
        let digest = Insecure.MD5.hash(data: Data(text.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
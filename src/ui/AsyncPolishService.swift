import Foundation

final class AsyncPolishService {
    static let shared = AsyncPolishService()

    private let callbackQueue = DispatchQueue(label: "whisperpuma.asyncpolish.callback")

    private init() {}

    func polish(_ text: String, timeoutMs: Int = 250, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: "http://127.0.0.1:11434/api/generate") else {
            completion(nil)
            return
        }

        let prompt = """
        Clean up punctuation and readability only.
        Preserve wording, names, and list structure.
        Return only the final text with no commentary.

        Text:
        \(text)
        """
        let payload: [String: Any] = [
            "model": "qwen2.5:3b-instruct",
            "prompt": prompt,
            "stream": false,
            "options": ["temperature": 0]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = max(0.1, Double(timeoutMs) / 1000.0)
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        var hasCompleted = false
        func completeOnce(_ value: String?) {
            callbackQueue.async {
                guard !hasCompleted else { return }
                hasCompleted = true
                completion(value)
            }
        }

        let task = URLSession.shared.dataTask(with: request) { data, _, _ in
            guard
                let data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let out = json["response"] as? String
            else {
                completeOnce(nil)
                return
            }
            completeOnce(out.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        task.resume()

        DispatchQueue.global().asyncAfter(deadline: .now() + .milliseconds(timeoutMs)) {
            if task.state == .running {
                task.cancel()
            }
            completeOnce(nil)
        }
    }
}

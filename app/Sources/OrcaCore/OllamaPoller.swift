import Foundation

/// Polls the local ollama server for running models, since ollama has no hook
/// mechanism. Emits the list of model names (empty when down) off the main thread.
public final class OllamaPoller {
    private let url: URL
    private let interval: TimeInterval
    private let onModels: ([String]) -> Void
    private var timer: Timer?

    public init(
        url: URL = URL(string: "http://127.0.0.1:11434/api/ps")!,
        interval: TimeInterval = 5,
        onModels: @escaping ([String]) -> Void
    ) {
        self.url = url
        self.interval = interval
        self.onModels = onModels
    }

    public func start() {
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in self?.poll() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        poll()
    }

    private func poll() {
        var request = URLRequest(url: url)
        request.timeoutInterval = 3
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let self = self else { return }
            guard
                let data = data,
                let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                let models = json["models"] as? [[String: Any]]
            else {
                self.onModels([])
                return
            }
            self.onModels(models.compactMap { $0["name"] as? String })
        }.resume()
    }
}

// Copyright (c) 2026 silentrosehill
// SPDX-License-Identifier: GPL-3.0-or-later
import Foundation

final class AvatarDownload: NSObject, URLSessionDataDelegate {
    static let limit = 1_000_000
    private var body = Data()
    private var rejected = false
    private let completion: (Data?) -> Void
    init(completion: @escaping (Data?) -> Void) { self.completion = completion }
    func start(_ url: URL) {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8; config.timeoutIntervalForResource = 12
        config.httpShouldSetCookies = false
        let session = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        session.dataTask(with: url).resume()
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(avatarAddress(request.url?.absoluteString) == nil ? nil : request)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        let allowed = (response as? HTTPURLResponse)?.statusCode == 200 && avatarAddress(response.url?.absoluteString) != nil
            && ["image/png", "image/jpeg", "image/gif", "image/webp"].contains(response.mimeType ?? "")
            && response.expectedContentLength <= Self.limit
        rejected = !allowed; completionHandler(allowed ? .allow : .cancel)
    }
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        guard data.count <= Self.limit - body.count else { rejected = true; body.removeAll(); dataTask.cancel(); return }
        body.append(data)
    }
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        completion(error == nil && !rejected ? body : nil)
        session.finishTasksAndInvalidate()
    }
}

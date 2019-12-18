//
//  RIBsTreeViewer.swift
//  RIBsTreeViewerClient
//
//  Created by yuki tamazawa on 2019/01/16.
//  Copyright © 2019 minipro. All rights reserved.
//

import Foundation
import RxSwift
import RIBs

protocol RIBsTreeViewer {
    func start()
}

public enum RIBsTreeViewerOptions: String {
    case webSocketURL
}

@available(iOS 13.0, *)
public class RIBsTreeViewerImpl {

    private let router: Routing
    private let webSocket: WebSocketClient
    private let disposeBag = DisposeBag()

    public init(router: Routing, option: [RIBsTreeViewerOptions: String]? = nil) {
        let url = option?[.webSocketURL]
        self.router = router

        if let url = url {
            self.webSocket = WebSocketClient.init(url: URL(string: url)!)
        } else {
            self.webSocket = WebSocketClient.init(url: URL(string: "ws://0.0.0.0:8080")!)
        }
        self.webSocket.delegate = self
        self.webSocket.connect()
    }

    public func start() {
        Observable<Int>.interval(RxTimeInterval.microseconds(200), scheduler: MainScheduler.instance)
            .map { [unowned self] _ in
                self.tree(router: self.router)
        }
        .distinctUntilChanged { a, b in
            NSDictionary(dictionary: a).isEqual(to: b)
        }
        .subscribe(onNext: { [weak self] in
            do {
                let jsonData = try JSONSerialization.data(withJSONObject: $0)
                let jsonString = String(bytes: jsonData, encoding: .utf8)!
                self?.webSocket.send(text: jsonString)
            } catch {
                // print(error)
            }
        })
            .disposed(by: disposeBag)
    }

    private func tree(router: Routing, appendImage: Bool = false) -> [String: Any] {
        var currentRouter = String(describing: type(of: router))
        if router is ViewableRouting {
            currentRouter += " (View) "
        }
        if router.children.isEmpty {
            return ["name": currentRouter, "children": []]
        } else {
            return ["name": currentRouter, "children": router.children.map { tree(router: $0, appendImage: appendImage) }]
        }
    }

    private func findRouter(target: String, router: Routing) -> Routing? {
        let currentRouter = String(describing: type(of: router))
        if target == currentRouter {
            return router
        } else if !router.children.isEmpty {
            return router.children.compactMap { findRouter(target: target, router: $0) }.first
        } else {
            return nil
        }
    }
}

@available(iOS 13.0, *)
extension RIBsTreeViewerImpl {
    private func captureView(from targetRouter: String) -> Data? {
        guard let router = findRouter(target: targetRouter, router: router) as? ViewableRouting,
            let view = router.viewControllable.uiviewController.view,
            let captureImage = image(with: view) else {
                return nil
        }
        return captureImage.pngData()
    }

    private func image(with view: UIView) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, view.isOpaque, 0.0)
        defer { UIGraphicsEndImageContext() }
        if let context = UIGraphicsGetCurrentContext() {
            view.layer.render(in: context)
            let image = UIGraphicsGetImageFromCurrentImageContext()
            return image
        }
        return nil
    }
}

@available(iOS 13.0, *)
extension RIBsTreeViewerImpl: WebSocketClientDelegate {
    func onConnected(client: WebSocketClient) {
    }

    func onDisconnedted(client: WebSocketClient) {
    }

    func onMessage(client: WebSocketClient, text: String) {
        // text == routerName
        DispatchQueue.main.async {
            if let data = self.captureView(from: text) {
                self.webSocket.send(data: data)
            }
        }
    }

    func onMessage(client: WebSocketClient, data: Data) {
    }

    func onError(client: WebSocketClient, error: Error) {
    }
}

protocol WebSocketClientDelegate: class {
    @available(iOS 13.0, *)
    func onConnected(client: WebSocketClient)
    @available(iOS 13.0, *)
    func onDisconnedted(client: WebSocketClient)
    @available(iOS 13.0, *)
    func onMessage(client: WebSocketClient, text: String)
    @available(iOS 13.0, *)
    func onMessage(client: WebSocketClient, data: Data)
    @available(iOS 13.0, *)
    func onError(client: WebSocketClient, error: Error)
}

@available(iOS 13.0, *)
class WebSocketClient: NSObject {

    weak var delegate: WebSocketClientDelegate?
    var webSocketTask: URLSessionWebSocketTask!
    var urlSession: URLSession!
    let delegateQueue = OperationQueue()

    init(url: URL) {
        super.init()
        urlSession = URLSession(configuration: .default, delegate: self, delegateQueue: delegateQueue)
        webSocketTask = urlSession.webSocketTask(with: url)
    }

    func connect() {
        webSocketTask.resume()
        listen()
    }

    func disconnect() {
        webSocketTask.cancel()
    }

    func send(data: Data) {
        webSocketTask.send(.data(data)) { error in
            guard let error = error else {
                return
            }
            self.delegate?.onError(client: self, error: error)
        }
    }

    func send(text: String) {
        webSocketTask.send(.string(text)) { error in
            guard let error = error else {
                return
            }
            self.delegate?.onError(client: self, error: error)
        }
    }

    private func listen() {
        webSocketTask.receive { result in
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    self.delegate?.onMessage(client: self, data: data)
                case .string(let text):
                    self.delegate?.onMessage(client: self, text: text)
                @unknown default:
                    fatalError()
                }
            case .failure(let error):
                self.delegate?.onError(client: self, error: error)
            }
            self.listen()
        }
    }

}

@available(iOS 13.0, *)
extension WebSocketClient: URLSessionWebSocketDelegate {
    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        self.delegate?.onConnected(client: self)
    }

    func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        self.delegate?.onDisconnedted(client: self)
    }
}

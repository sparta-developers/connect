import Foundation
import Combine
import AppKit

public enum State: Equatable {
    case login
    case busy(value: Progress)
    case complete
    func onlyProgress() -> Progress? {
        if case let .busy(value: progress) = self {
            return progress
        } else {
            return nil
        }
    }
}

public protocol Installation {
    var statePublisher: AnyPublisher<State, Never> {get}
    func beginInstallation(login: Login)
    func cancelInstallation()
    func uninstall()
}

enum BackEnd: String {
    case localhost
    case staging
    case production
    func baseUrl() -> URL {
        let environment: [BackEnd: String] = [
            .localhost: "http://localhost:4000",
            .staging: "https://staging.spartascience.com",
            .production: "https://home.spartascience.com",
        ]
        return URL(string: environment[self]!)!
    }
}

public struct Organization: Codable {
    let id: Int
    let logoUrl: String?
    let name: String
    let touchIconUrl: String?
}

public struct ResponseSuccess: Codable {
    public let message: HTTPLoginMessage
    public let vernalFallsConfig: [String: String]
    public let org: Organization
}

public struct ResponseFailure: Codable {
    public let error: String
}

public enum HTTPLoginResponse: Codable {
    public init(from decoder: Decoder) throws {
        if let decoded = try? Self.success(ResponseSuccess(from: decoder)) {
            self = decoded
        } else {
            self = try Self.failure(ResponseFailure(from: decoder))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        switch self {
        case .success(value: let success):
            try success.encode(to: encoder)
        case .failure(value: let failure):
            try failure.encode(to: encoder)
        }
    }
    
    case success(_:ResponseSuccess)
    case failure(_:ResponseFailure)
}

public struct HTTPLoginMessage: Codable {
    let downloadUrl: URL
    let vernalFallsVersion: String
}

public class Installer: NSObject {
    public static let shared = Installer()
    @Published public var state: State = .login
    @objc func downloadStep() {
        if case let .busy(value: value) = state {
            if value.isFinished {
                state = .complete
            } else {
                value.completedUnitCount += 1
                state = .busy(value: value)
                perform(#selector(downloadStep), with: nil, afterDelay: 0.1)
            }
        }
    }
    @objc func downloadStart() {
        let progress = Progress()
        progress.isCancellable = true
        progress.totalUnitCount = 20
        progress.completedUnitCount = 1
        self.state = .busy(value: progress)
        perform(#selector(downloadStep), with: nil, afterDelay: 1)
    }
    var cancellables = Set<AnyCancellable>()
    
    enum ApiError: LocalizedError {
        case server(message: String)
        var errorDescription: String? {
            switch self {
            case let .server(message):
                return message
            }
        }
    }
    
    func loginRequest(_ login: Login) -> URLRequest {
        let backend = BackEnd(rawValue: login.environment)!
        let loginUrl = backend.baseUrl().appendingPathComponent("api/app-setup")
        var components = URLComponents(url: loginUrl, resolvingAgainstBaseURL: true)!
        components.queryItems = [.init(name: "email", value: login.username),
                                 .init(name: "password", value: login.password),
                                 .init(name: "client-id", value: "delete-me-please-test")]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        return request
    }
    
    func process(_ org: Organization) {
        print("org:", org)
    }

    public func installationURL() -> URL {
        applicationSupportURL().appendingPathComponent(Bundle.main.bundleIdentifier!)
    }
    public func applicationSupportURL() -> URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .last!
    }

    func process(_ vernalFallsConfig: [String: String]) {
        print("vernalFallsConfig: ", vernalFallsConfig)
    }

    public func beginInstallation(login: Login) {
        assert(state == .login)
        let progress = Progress()
        progress.kind = .file
        progress.fileOperationKind = .receiving
        progress.isCancellable = true
        state = .busy(value: progress)
        
        let remoteDataPublisher = URLSession.shared
            .dataTaskPublisher(for: loginRequest(login))
        .map { $0.data }
        .decode(type: HTTPLoginResponse.self, decoder: JSONDecoder())
        .tryMap { response -> HTTPLoginMessage in
            try FileManager.default.createDirectory(at: self.installationURL(),
                                                    withIntermediateDirectories: true)
            switch response {
            case .failure(value: let serverError):
                throw ApiError.server(message: serverError.error)
            case .success(value: let success):
                self.process(success.org)
                self.process(success.vernalFallsConfig)
                return success.message
            }
        }
        .map { (message: HTTPLoginMessage)->URL in
            message.downloadUrl
        }.tryMap { (url: URL)->Data in
            try Data(contentsOf: url)
        }.tryMap { (data: Data)->Int in
            try data.write(to: self.installationURL().appendingPathComponent("vernal_falls.tar.gz"))
            return data.count
        }
        .eraseToAnyPublisher()
        
        remoteDataPublisher.sink(receiveCompletion: { complete in
            switch complete {
            case .finished:
                print("Finished")
            case .failure(let error):
                DispatchQueue.main.async {
                    self.cancelInstallation()
                    NSAlert(error: error).runModal()
                }
                print("failure error: ", error)
            }
        }) { response in
            print("final response: ", response)
        }.store(in: &cancellables)
        
        perform(#selector(downloadStart), with: nil, afterDelay: 1)
    }
    public func cancelInstallation() {
        cancellables.forEach {
            $0.cancel()
        }
        cancellables.removeAll()
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        let progress = Progress()
        progress.isCancellable = false
        state = .busy(value: progress)
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(1)) {
            self.state = .login
        }
    }
    public func uninstall() {
        NSObject.cancelPreviousPerformRequests(withTarget: self)
        let progress = Progress()
        progress.isCancellable = false
        state = .busy(value: progress)
        DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
            self.state = .login
        }
    }
}

extension Installer: Installation {
    public var statePublisher: AnyPublisher<State, Never> {
        $state.eraseToAnyPublisher()
    }
}

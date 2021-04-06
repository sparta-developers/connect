import EdgeScience
import Foundation
import Swifter
import Testable

extension MskWrapper {
    func convert(predictions: [Decimal?], ids: [String]) -> ScienceOutputs {
        let features = predictions.map { mskHealth -> Features in
            if let mskHealth = mskHealth {
                return Features(mskHealth: mskHealth, approved: true)
            }
            return Features(mskHealth: 0, approved: false)
        }
        let instances = zip(ids, features).map { Instance(id: $0, features: $1) }
        return ScienceOutputs(instances: instances)
    }
    func predict(inputs: ScienceInputs) -> ScienceOutputs {
        convert(predictions: predictMskHealth(inputs),
                ids: inputs.input.map { $0.id })
    }
}

public class LocalServer: NSObject {
    @Inject var science: MskWrapper

    @Inject var server: HttpServer
    let decoder = Init(JSONDecoder()) {
        $0.keyDecodingStrategy = .convertFromSnakeCase
    }
    let encoder = Init(JSONEncoder()) {
        $0.keyEncodingStrategy = .convertToSnakeCase
    }
    func handleMskHealthRequest(data: Data) -> HttpResponseBody {
        do {
            let inputs = try decoder.decode(ScienceInputs.self, from: data)
            let encoded = try encoder.encode(science.predict(inputs: inputs))
            return .data(encoded)
        } catch {
            return .json([
                "localizedDescription": error.localizedDescription,
                "errorMessage": String(describing: error),
                "errorType": String(describing: type(of: error)),
                "stackTrace": Thread.callStackSymbols
            ])
        }
    }
    func startServer() {
        server["/msk-health"] = { request in
            .ok(self.handleMskHealthRequest(data: Data(request.body)))
        }
        server["/health-check"] = { _ in
            .ok(.html("ok"))
        }
        // swiftlint:disable:next force_try
        try! server.start(4_080)
    }
    override public func awakeFromNib() {
        super.awakeFromNib()
        startServer()
    }
}

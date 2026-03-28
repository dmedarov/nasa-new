import Foundation

protocol APODService {
    func data(from url: URL) async throws -> (Data, URLResponse)
}

struct URLSessionAPODService: APODService {
    let session: URLSession

    func data(from url: URL) async throws -> (Data, URLResponse) {
        try await session.data(from: url)
    }
}

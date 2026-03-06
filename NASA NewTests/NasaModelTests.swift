import Foundation
import Testing

struct NasaModelTests {
    @Test
    func decodesValidAPODPayload() throws {
        let json = """
        {
            "date": "2025-01-15",
            "explanation": "A great APOD entry.",
            "media_type": "image",
            "service_version": "v1",
            "title": "Galaxy",
            "url": "https://example.com/image.jpg",
            "hdurl": "https://example.com/image_hd.jpg",
            "copyright": "NASA"
        }
        """.data(using: .utf8)!

        let model = try JSONDecoder().decode(NASA.self, from: json)

        #expect(model.date == "2025-01-15")
        #expect(model.mediaType == .image)
        #expect(model.url?.absoluteString == "https://example.com/image.jpg")
        #expect(model.hdurl?.absoluteString == "https://example.com/image_hd.jpg")
        #expect(model.title == "Galaxy")
        #expect(model.id == "date:2025-01-15|url:https://example.com/image.jpg")
    }

    @Test
    func mapsUnknownMediaTypeToOther() throws {
        let json = """
        {
            "date": "2025-01-15",
            "explanation": "Unknown media test.",
            "media_type": "audio",
            "title": "Unknown",
            "url": "https://example.com/asset"
        }
        """.data(using: .utf8)!

        let model = try JSONDecoder().decode(NASA.self, from: json)

        #expect(model.mediaType == .other)
    }

    @Test
    func sanitizesInvalidDateAndURLsInsteadOfFailingDecode() throws {
        let json = """
        {
            "date": "15-01-2025",
            "explanation": "Invalid values should be sanitized.",
            "media_type": "image",
            "title": "Sanitize",
            "url": "ftp://example.com/file",
            "hdurl": "not-a-url"
        }
        """.data(using: .utf8)!

        let model = try JSONDecoder().decode(NASA.self, from: json)

        #expect(model.date == nil)
        #expect(model.url == nil)
        #expect(model.hdurl == nil)
        #expect(model.mediaType == .image)
    }

    @Test
    func usesStableFallbackIdentityWhenDateAndURLMissing() throws {
        let json = """
        {
            "explanation": "Fallback identity entry.",
            "media_type": "image",
            "title": "Fallback Title"
        }
        """.data(using: .utf8)!

        let model = try JSONDecoder().decode(NASA.self, from: json)
        #expect(model.id == "explanation:Fallback identity entry.")
    }
}

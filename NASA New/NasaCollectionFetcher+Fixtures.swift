import Foundation

enum FixtureScenario: String {
    case `default`
    case unsupportedVideo = "unsupported_video"
    case directVideo = "direct_video"
    case diagnosticsCycle = "diagnostics_cycle"
    case dateNavigation = "date_navigation"
    case longExplanation = "long_explanation"
    case offlineCached = "offline_cached"
    case rateLimited = "rate_limited"
    case noMedia = "no_media"
    case loadFailure = "load_failure"
}

extension NasaCollectionFetcher {
    func configureFixtureModeIfNeeded() {
        guard ProcessInfo.processInfo.environment["UITEST_USE_FIXTURE"] == "1" else { return }

        let mode = ProcessInfo.processInfo.environment["UITEST_FIXTURE_MODE"] ?? "default"
        let scenario = FixtureScenario(rawValue: mode) ?? .default
        applyFixtureScenario(scenario)
    }

    func applyFixtureScenario(_ scenario: FixtureScenario) {
        isUsingFixtureData = true
        isUsingCachedData = false
        isOfflineMode = false
        error = nil
        rateLimitRetryDate = nil
        fixtureFetchCycle = 0
        lastStatusCode = nil
        lastTransportError = nil
        requestDiagnostics = []
        fixtureScenario = scenario

        if scenario == .dateNavigation {
            let fixtures = [
                NASA(
                    copyright: "NASA",
                    date: "2025-01-13",
                    explanation: "Date navigation fixture for January 13.",
                    hdurl: URL(string: "https://example.com/apod-2025-01-13-hd.jpg"),
                    mediaType: .image,
                    serviceVersion: "v1",
                    title: "Fixture APOD 2025-01-13",
                    url: URL(string: "https://example.com/apod-2025-01-13.jpg")
                ),
                NASA(
                    copyright: "NASA",
                    date: "2025-01-14",
                    explanation: "Date navigation fixture for January 14.",
                    hdurl: URL(string: "https://example.com/apod-2025-01-14-hd.jpg"),
                    mediaType: .image,
                    serviceVersion: "v1",
                    title: "Fixture APOD 2025-01-14",
                    url: URL(string: "https://example.com/apod-2025-01-14.jpg")
                ),
                NASA(
                    copyright: "NASA",
                    date: "2025-01-15",
                    explanation: "Date navigation fixture for January 15.",
                    hdurl: URL(string: "https://example.com/apod-2025-01-15-hd.jpg"),
                    mediaType: .image,
                    serviceVersion: "v1",
                    title: "Fixture APOD 2025-01-15",
                    url: URL(string: "https://example.com/apod-2025-01-15.jpg")
                )
            ]

            apodData = fixtures
            currentNasa = fixtures.last ?? .default
            cachedItemCount = apodData.count
            return
        }

        let fixture: NASA
        switch scenario {
        case .dateNavigation:
            fixture = NASA.default
        case .unsupportedVideo:
            fixture = NASA(
                copyright: "NASA",
                date: "2025-01-15",
                explanation: "Unsupported video fixture.",
                hdurl: nil,
                mediaType: .video,
                serviceVersion: "v1",
                title: "Fixture Unsupported Video",
                url: URL(string: "https://vimeo.com/76979871")
            )
        case .directVideo:
            fixture = NASA(
                copyright: "NASA",
                date: "2025-01-15",
                explanation: "Direct video fixture.",
                hdurl: nil,
                mediaType: .video,
                serviceVersion: "v1",
                title: "Fixture Direct Video",
                url: URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")
            )
        case .diagnosticsCycle:
            fixture = NASA(
                copyright: "NASA",
                date: "2025-01-15",
                explanation: "Diagnostics cycle fixture.",
                hdurl: URL(string: "https://example.com/apod_hd.jpg"),
                mediaType: .image,
                serviceVersion: "v1",
                title: "Fixture APOD",
                url: URL(string: "https://example.com/apod.jpg")
            )
            lastStatusCode = nil
            lastTransportError = nil
        case .longExplanation:
            fixture = NASA(
                copyright: "European Southern Observatory / M. Kormendy",
                date: "2025-01-15",
                explanation: Array(repeating: "This extended fixture explanation is intentionally long so we can verify large dynamic type, VoiceOver reading order, and deep scroll behavior across the APOD detail view without losing access to the source and share controls.", count: 8).joined(separator: " "),
                hdurl: URL(string: "https://example.com/long-story-apod-hd.jpg"),
                mediaType: .image,
                serviceVersion: "v1",
                title: "Fixture APOD with Extended Editorial Storytelling for Accessibility Validation",
                url: URL(string: "https://example.com/long-story-apod.jpg")
            )
        case .offlineCached:
            fixture = NASA(
                copyright: "NASA",
                date: "2025-01-15",
                explanation: "Offline cache fixture.",
                hdurl: URL(string: "https://example.com/offline-apod-hd.jpg"),
                mediaType: .image,
                serviceVersion: "v1",
                title: "Fixture APOD Available Offline",
                url: URL(string: "https://example.com/offline-apod.jpg")
            )
        case .rateLimited:
            fixture = NASA(
                copyright: "NASA",
                date: "2025-01-15",
                explanation: "Rate limit fixture.",
                hdurl: URL(string: "https://example.com/rate-limit-apod-hd.jpg"),
                mediaType: .image,
                serviceVersion: "v1",
                title: "Fixture APOD During Rate Limit",
                url: URL(string: "https://example.com/rate-limit-apod.jpg")
            )
        case .noMedia:
            fixture = NASA(
                copyright: "NASA",
                date: "2025-01-15",
                explanation: "No media fixture.",
                hdurl: nil,
                mediaType: .image,
                serviceVersion: "v1",
                title: "Fixture APOD Without Media Source",
                url: nil
            )
        case .loadFailure:
            fixture = NASA.default
        case .default:
            fixture = NASA(
                copyright: "NASA",
                date: "2025-01-15",
                explanation: "This is deterministic fixture content used for UI testing.",
                hdurl: URL(string: "https://example.com/apod_hd.jpg"),
                mediaType: .image,
                serviceVersion: "v1",
                title: "Fixture APOD",
                url: URL(string: "https://example.com/apod.jpg")
            )
        }

        apodData = scenario == .loadFailure ? [] : [fixture]
        currentNasa = scenario == .loadFailure ? .default : fixture
        cachedItemCount = apodData.count

        switch scenario {
        case .offlineCached:
            isOfflineMode = true
            isUsingCachedData = true
            lastTransportError = URLError(.notConnectedToInternet).localizedDescription
        case .rateLimited:
            lastStatusCode = 429
            error = .httpStatus(429)
            rateLimitRetryDate = nowProvider().addingTimeInterval(20 * 60)
            appendDiagnostic(
                endpoint: "fixture://rate-limited",
                statusCode: 429,
                result: "failure",
                transportError: nil,
                usedCache: false
            )
        case .loadFailure:
            error = .network(URLError(.notConnectedToInternet))
            lastTransportError = URLError(.notConnectedToInternet).localizedDescription
        default:
            break
        }
    }

    func handleFixtureFetchIfNeeded(for date: Date?) -> Bool {
        guard isUsingFixtureData else { return false }
        if fixtureScenario == .dateNavigation {
            if let date,
               let requestedDate = self.dateFormatter.date(from: self.dateFormatter.string(from: normalizedDate(date))),
               let matchingItem = apodData.first(where: {
                   guard let itemDate = self.date(from: $0.date) else { return false }
                   return calendar.isDate(itemDate, inSameDayAs: requestedDate)
               }) {
                currentNasa = matchingItem
            }
            return true
        }
        guard fixtureScenario == .diagnosticsCycle else { return true }

        fixtureFetchCycle += 1
        lastRequestDate = nowProvider()
        if fixtureFetchCycle % 2 == 1 {
            lastStatusCode = 429
            lastTransportError = nil
            error = .httpStatus(429)
            appendDiagnostic(
                endpoint: "fixture://diagnostics-cycle",
                statusCode: 429,
                result: "failure",
                transportError: nil,
                usedCache: false
            )
        } else {
            lastStatusCode = 200
            lastTransportError = nil
            error = nil
            appendDiagnostic(
                endpoint: "fixture://diagnostics-cycle",
                statusCode: 200,
                result: "success",
                transportError: nil,
                usedCache: false
            )
        }
        return true
    }
}

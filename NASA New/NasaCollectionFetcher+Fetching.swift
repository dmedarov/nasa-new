import Foundation

extension NasaCollectionFetcher {
    func buildURL(for date: Date? = nil) -> URL? {
        var components = URLComponents(string: "https://api.nasa.gov/planetary/apod")
        var queryItems = [URLQueryItem(name: "api_key", value: apiKey)]

        if let date {
            queryItems.append(URLQueryItem(name: "date", value: dateFormatter.string(from: normalizedDate(date))))
        } else {
            let now = normalizedDate(nowProvider())
            let endDate = dateFormatter.string(from: now)
            let startDate = normalizedDate(calendar.date(byAdding: .day, value: -90, to: now) ?? now)
            let startDateString = dateFormatter.string(from: startDate)
            queryItems.append(URLQueryItem(name: "start_date", value: startDateString))
            queryItems.append(URLQueryItem(name: "end_date", value: endDate))
        }

        components?.queryItems = queryItems
        return components?.url
    }

    func buildArchiveRangeURL(startDate: Date, endDate: Date) -> URL? {
        var components = URLComponents(string: "https://api.nasa.gov/planetary/apod")
        components?.queryItems = [
            URLQueryItem(name: "api_key", value: apiKey),
            URLQueryItem(name: "start_date", value: dateFormatter.string(from: normalizedDate(startDate))),
            URLQueryItem(name: "end_date", value: dateFormatter.string(from: normalizedDate(endDate)))
        ]
        return components?.url
    }

    @available(iOS 15.0, *)
    func fetchData() async {
        await fetchData(for: nil)
    }

    @available(iOS 15.0, *)
    func startLatestFetch(for date: Date? = nil) {
        latestFetchTask?.cancel()
        latestFetchTask = Task { [weak self] in
            await self?.fetchData(for: date)
        }
    }

    func loadOlderArchiveBatch() {
        Task { [weak self] in
            await self?.fetchOlderArchiveBatch()
        }
    }

    func cancelLatestFetch() {
        latestFetchTask?.cancel()
        latestFetchTask = nil
    }

    @available(iOS 15.0, *)
    func fetchData(for date: Date?) async {
        if handleFixtureFetchIfNeeded(for: date) { return }
        let requestID = UUID()
        activeRequestID = requestID
        isFetching = true
        error = nil
        isOfflineMode = false
        lastRequestDate = nowProvider()
        lastTransportError = nil
        rateLimitRetryDate = nil
        defer {
            if requestID == activeRequestID {
                isFetching = false
            }
        }

        guard let url = buildURL(for: date) else {
            if requestID == activeRequestID {
                error = .badRequest
            }
            return
        }

        do {
            let (data, response) = try await service.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw FetchError.invalidResponse
            }
            if requestID == activeRequestID {
                lastStatusCode = httpResponse.statusCode
            }
            guard (200...299).contains(httpResponse.statusCode) else {
                if requestID == activeRequestID, httpResponse.statusCode == 429 {
                    rateLimitRetryDate = retryAfterDate(from: httpResponse, referenceDate: nowProvider())
                }
                throw FetchError.httpStatus(httpResponse.statusCode)
            }

            let decoder = JSONDecoder()

            if date != nil {
                let item = try decoder.decode(NASA.self, from: data)
                guard requestID == activeRequestID else { return }
                currentNasa = item
                mergeAPODItems([item])
                refreshFavoriteIfNeeded(with: item)
                isUsingCachedData = false
                appendDiagnostic(
                    endpoint: sanitizedEndpoint(from: url),
                    statusCode: httpResponse.statusCode,
                    result: "success",
                    transportError: nil,
                    usedCache: false
                )
            } else {
                let decoded = try decoder.decode([NASA].self, from: data)
                    .sorted { ($0.date ?? "") < ($1.date ?? "") }
                guard !decoded.isEmpty else {
                    throw FetchError.emptyResponse
                }
                guard requestID == activeRequestID else { return }
                mergeAPODItems(decoded)
                currentNasa = apodData.last ?? .default
                isUsingCachedData = false
                appendDiagnostic(
                    endpoint: sanitizedEndpoint(from: url),
                    statusCode: httpResponse.statusCode,
                    result: "success",
                    transportError: nil,
                    usedCache: false
                )
            }
        } catch is CancellationError {
            return
        } catch let fetchError as FetchError {
            if requestID == activeRequestID {
                error = fetchError
                appendDiagnostic(
                    endpoint: sanitizedEndpoint(from: url),
                    statusCode: lastStatusCode,
                    result: "failure",
                    transportError: fetchError.localizedDescription,
                    usedCache: isUsingCachedData
                )
            }
        } catch let urlError as URLError {
            if requestID == activeRequestID, urlError.code != .cancelled {
                error = .network(urlError)
                lastTransportError = urlError.localizedDescription
                isOfflineMode = !apodData.isEmpty
                appendDiagnostic(
                    endpoint: sanitizedEndpoint(from: url),
                    statusCode: nil,
                    result: "failure",
                    transportError: urlError.localizedDescription,
                    usedCache: !apodData.isEmpty
                )
            }
        } catch let decodeError as DecodingError {
            if requestID == activeRequestID {
                error = .decoding(decodeError)
                lastTransportError = L10n.text(
                    "api.payload.decode_failed",
                    default: "Failed to decode NASA API payload."
                )
                appendDiagnostic(
                    endpoint: sanitizedEndpoint(from: url),
                    statusCode: lastStatusCode,
                    result: "failure",
                    transportError: L10n.text(
                        "api.payload.decode_failed",
                        default: "Failed to decode NASA API payload."
                    ),
                    usedCache: isUsingCachedData
                )
            }
        } catch {
            if requestID == activeRequestID {
                self.error = .unknown(error.localizedDescription)
                lastTransportError = error.localizedDescription
                appendDiagnostic(
                    endpoint: sanitizedEndpoint(from: url),
                    statusCode: lastStatusCode,
                    result: "failure",
                    transportError: error.localizedDescription,
                    usedCache: isUsingCachedData
                )
            }
        }
    }

    @available(iOS 15.0, *)
    func fetchOlderArchiveBatch() async {
        guard !isUsingFixtureData else { return }
        guard !isFetchingArchive else { return }
        guard let oldestArchivedDate = archiveItems.last.flatMap({ date(from: $0.date) }) else { return }

        let previousDay = calendar.date(byAdding: .day, value: -1, to: normalizedDate(oldestArchivedDate)) ?? oldestArchivedDate
        let endDate = normalizedDate(previousDay)
        guard endDate >= minimumSelectableDate else { return }

        let proposedStartDate = calendar.date(
            byAdding: .day,
            value: -(Constants.archiveBatchDayCount - 1),
            to: endDate
        ) ?? endDate
        let startDate = max(normalizedDate(proposedStartDate), minimumSelectableDate)

        guard let url = buildArchiveRangeURL(startDate: startDate, endDate: endDate) else {
            archiveError = .badRequest
            return
        }

        isFetchingArchive = true
        archiveError = nil
        lastRequestDate = nowProvider()
        defer { isFetchingArchive = false }

        do {
            let (data, response) = try await service.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse else {
                throw FetchError.invalidResponse
            }
            lastStatusCode = httpResponse.statusCode

            guard (200...299).contains(httpResponse.statusCode) else {
                if httpResponse.statusCode == 429 {
                    rateLimitRetryDate = retryAfterDate(from: httpResponse, referenceDate: nowProvider())
                }
                throw FetchError.httpStatus(httpResponse.statusCode)
            }

            let decoded = try JSONDecoder().decode([NASA].self, from: data)
                .sorted { ($0.date ?? "") < ($1.date ?? "") }
            guard !decoded.isEmpty else {
                throw FetchError.emptyResponse
            }

            mergeAPODItems(decoded)
            isUsingCachedData = false
            appendDiagnostic(
                endpoint: sanitizedEndpoint(from: url),
                statusCode: httpResponse.statusCode,
                result: "success",
                transportError: nil,
                usedCache: false
            )
        } catch let fetchError as FetchError {
            archiveError = fetchError
            appendDiagnostic(
                endpoint: sanitizedEndpoint(from: url),
                statusCode: lastStatusCode,
                result: "failure",
                transportError: fetchError.localizedDescription,
                usedCache: !apodData.isEmpty
            )
        } catch let urlError as URLError {
            if urlError.code == .cancelled { return }
            archiveError = .network(urlError)
            lastTransportError = urlError.localizedDescription
            appendDiagnostic(
                endpoint: sanitizedEndpoint(from: url),
                statusCode: nil,
                result: "failure",
                transportError: urlError.localizedDescription,
                usedCache: !apodData.isEmpty
            )
        } catch let decodeError as DecodingError {
            archiveError = .decoding(decodeError)
            lastTransportError = L10n.text(
                "api.payload.decode_failed",
                default: "Failed to decode NASA API payload."
            )
            appendDiagnostic(
                endpoint: sanitizedEndpoint(from: url),
                statusCode: lastStatusCode,
                result: "failure",
                transportError: L10n.text(
                    "api.payload.decode_failed",
                    default: "Failed to decode NASA API payload."
                ),
                usedCache: !apodData.isEmpty
            )
        } catch {
            archiveError = .unknown(error.localizedDescription)
            lastTransportError = error.localizedDescription
            appendDiagnostic(
                endpoint: sanitizedEndpoint(from: url),
                statusCode: lastStatusCode,
                result: "failure",
                transportError: error.localizedDescription,
                usedCache: !apodData.isEmpty
            )
        }
    }

    func date(from value: String?) -> Date? {
        guard let value else { return nil }
        return dateFormatter.date(from: value)
    }

    func applyCacheItemLimit(_ limit: Int) {
        cacheItemLimit = max(1, limit)
        trimCacheIfNeeded()
        cacheStorage.saveCachedAPODItems(apodData)
        cachedItemCount = apodData.count
    }

    func shouldRefreshOnForeground() -> Bool {
        guard !isUsingFixtureData else { return false }
        guard !isFetching else { return false }
        guard !apodData.isEmpty else { return true }
        guard let lastRequestDate else { return true }
        return nowProvider().timeIntervalSince(lastRequestDate) >= Constants.foregroundRefreshInterval
    }

    var canLoadMoreArchiveHistory: Bool {
        guard !isUsingFixtureData else { return false }
        guard let oldestArchivedDate = archiveItems.last.flatMap({ date(from: $0.date) }) else { return false }
        return normalizedDate(oldestArchivedDate) > minimumSelectableDate
    }

    func mergeAPODItems(_ items: [NASA]) {
        guard !items.isEmpty else { return }

        var mergedItems = Dictionary(uniqueKeysWithValues: apodData.map { ($0.id, $0) })
        for item in items {
            mergedItems[item.id] = item
        }

        apodData = mergedItems.values.sorted { ($0.date ?? "") < ($1.date ?? "") }
        refreshFavoritesFromData(items)
        trimCacheIfNeeded()
        cacheStorage.saveCachedAPODItems(apodData)
        cachedItemCount = apodData.count
    }
}

import AppKit
import Foundation
import Photos

/// Storage for temporary photo files
actor PhotoStorage {
  static let shared = PhotoStorage()

  private var photos: [String: URL] = [:]
  private let tempDirectory: URL

  private init() {
    self.tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("gardenbridge-photos")
    try? FileManager.default.createDirectory(at: self.tempDirectory, withIntermediateDirectories: true)
  }

  func store(data: Data, format: String) -> String {
    let id = UUID().uuidString
    let ext = format == "jpeg" || format == "jpg" ? "jpg" : format
    let fileURL = self.tempDirectory.appendingPathComponent("\(id).\(ext)")

    do {
      try data.write(to: fileURL)
      self.photos[id] = fileURL
      Task {
        try? await Task.sleep(for: .seconds(600))
        await self.remove(id: id)
      }
      return id
    } catch {
      return ""
    }
  }

  func get(id: String) -> URL? {
    self.photos[id]
  }

  func remove(id: String) {
    if let url = self.photos.removeValue(forKey: id) {
      try? FileManager.default.removeItem(at: url)
    }
  }
}

/// Handles Photos framework commands
actor PhotosCommands: CommandExecutor {
  private let serverPort: UInt16 = 28790

  func execute(command: String, params: [String: AnyCodable]) async throws -> AnyCodable? {
    switch command {
    case "photos.list":
      return try await self.listPhotos(params: params)
    case "photos.get":
      return try await self.getPhoto(params: params)
    case "photos.search":
      return try await self.searchPhotos(params: params)
    case "photos.getAlbums":
      return try await self.getAlbums(params: params)
    default:
      throw CommandError(code: "UNKNOWN_COMMAND", message: "Unknown photos command: \(command)")
    }
  }

  // MARK: - Authorization

  private func ensureAuthorization() async throws {
    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    switch status {
    case .authorized, .limited:
      return
    case .notDetermined:
      let granted = await withCheckedContinuation { continuation in
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { newStatus in
          continuation.resume(returning: newStatus == .authorized || newStatus == .limited)
        }
      }
      if !granted {
        throw CommandError.permissionDenied
      }
    default:
      throw CommandError.permissionDenied
    }
  }

  // MARK: - List Photos

  private func listPhotos(params: [String: AnyCodable]) async throws -> AnyCodable {
    try await self.ensureAuthorization()

    let startDate = self.parseDate(params["startDate"]?.stringValue)
    let endDate = self.parseDate(params["endDate"]?.stringValue)
    let albumName = params["album"]?.stringValue
    let limit = params["limit"]?.intValue ?? 50

    let assets = self.fetchAssets(albumName: albumName, startDate: startDate, endDate: endDate)
    let results = self.assetsToList(assets: assets, limit: limit)

    return AnyCodable([
      "count": results.count,
      "photos": results,
    ])
  }

  // MARK: - Get Photo

  private func getPhoto(params: [String: AnyCodable]) async throws -> AnyCodable {
    try await self.ensureAuthorization()

    guard let id = params["id"]?.stringValue else {
      throw CommandError.invalidParam("id")
    }

    let format = (params["format"]?.stringValue ?? "jpeg").lowercased()
    let targetSize = self.parseSize(params["size"])

    guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject else {
      throw CommandError.notFound
    }

    let (data, width, height, mimeType) = try await self.renderAsset(asset, targetSize: targetSize, format: format)

    let photoId = await PhotoStorage.shared.store(data: data, format: format)
    guard !photoId.isEmpty else {
      throw CommandError(code: "STORAGE_FAILED", message: "Failed to store photo")
    }

    let photoUrl = "http://localhost:\(self.serverPort)/photo/\(photoId)"
    return AnyCodable([
      "photoId": photoId,
      "photoUrl": photoUrl,
      "format": format,
      "mimeType": mimeType,
      "width": width,
      "height": height,
    ])
  }

  // MARK: - Search Photos

  private func searchPhotos(params: [String: AnyCodable]) async throws -> AnyCodable {
    try await self.ensureAuthorization()

    let startDate = self.parseDate(params["startDate"]?.stringValue)
    let endDate = self.parseDate(params["endDate"]?.stringValue)
    let latitude = params["latitude"]?.doubleValue
    let longitude = params["longitude"]?.doubleValue
    let radius = params["radius"]?.doubleValue ?? 1000
    let limit = params["limit"]?.intValue ?? 50

    let assets = self.fetchAssets(albumName: nil, startDate: startDate, endDate: endDate)
    let results = self.assetsToList(
      assets: assets,
      limit: limit,
      latitude: latitude,
      longitude: longitude,
      radius: radius)

    return AnyCodable([
      "count": results.count,
      "photos": results,
    ])
  }

  // MARK: - Albums

  private func getAlbums(params: [String: AnyCodable]) async throws -> AnyCodable {
    try await self.ensureAuthorization()

    let type = params["type"]?.stringValue?.lowercased() ?? "all"
    var collections: [PHAssetCollection] = []

    if type == "all" || type == "user" {
      let userCollections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
      userCollections.enumerateObjects { collection, _, _ in
        collections.append(collection)
      }
    }

    if type == "all" || type == "smart" {
      let smartCollections = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)
      smartCollections.enumerateObjects { collection, _, _ in
        collections.append(collection)
      }
    }

    let albums = collections.map { collection -> [String: Any] in
      var info: [String: Any] = [
        "id": collection.localIdentifier,
        "title": collection.localizedTitle ?? "",
        "type": collection.assetCollectionType == .smartAlbum ? "smart" : "user",
      ]

      if collection.estimatedAssetCount != NSNotFound {
        info["count"] = collection.estimatedAssetCount
      }

      return info
    }

    return AnyCodable([
      "count": albums.count,
      "albums": albums,
    ])
  }

  // MARK: - Helpers

  private func fetchAssets(
    albumName: String?,
    startDate: Date?,
    endDate: Date?
  ) -> PHFetchResult<PHAsset> {
    let options = PHFetchOptions()
    var predicates: [NSPredicate] = [NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)]

    if let startDate {
      predicates.append(NSPredicate(format: "creationDate >= %@", startDate as NSDate))
    }

    if let endDate {
      predicates.append(NSPredicate(format: "creationDate <= %@", endDate as NSDate))
    }

    options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

    if let albumName, let collection = self.findAlbum(named: albumName) {
      return PHAsset.fetchAssets(in: collection, options: options)
    }

    return PHAsset.fetchAssets(with: options)
  }

  private func findAlbum(named name: String) -> PHAssetCollection? {
    let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
    var match: PHAssetCollection?
    collections.enumerateObjects { collection, _, stop in
      if collection.localizedTitle?.caseInsensitiveCompare(name) == .orderedSame {
        match = collection
        stop.pointee = true
      }
    }

    if match != nil {
      return match
    }

    let smartCollections = PHAssetCollection.fetchAssetCollections(with: .smartAlbum, subtype: .any, options: nil)
    smartCollections.enumerateObjects { collection, _, stop in
      if collection.localizedTitle?.caseInsensitiveCompare(name) == .orderedSame {
        match = collection
        stop.pointee = true
      }
    }

    return match
  }

  private func assetsToList(
    assets: PHFetchResult<PHAsset>,
    limit: Int,
    latitude: Double? = nil,
    longitude: Double? = nil,
    radius: Double? = nil
  ) -> [[String: Any]] {
    let formatter = ISO8601DateFormatter()
    var items: [[String: Any]] = []
    let maxCount = max(0, limit)

    let hasLocationFilter = latitude != nil && longitude != nil
    let targetLocation: CLLocation? = hasLocationFilter
      ? CLLocation(latitude: latitude!, longitude: longitude!)
      : nil
    let radiusValue = radius ?? 1000

    var index = 0
    while index < assets.count, items.count < maxCount {
      let asset = assets.object(at: index)
      index += 1

      if let targetLocation, let location = asset.location {
        let distance = location.distance(from: targetLocation)
        if distance > radiusValue {
          continue
        }
      } else if hasLocationFilter {
        continue
      }

      var item: [String: Any] = [
        "id": asset.localIdentifier,
        "width": asset.pixelWidth,
        "height": asset.pixelHeight,
      ]

      if let creationDate = asset.creationDate {
        item["createdAt"] = formatter.string(from: creationDate)
      }

      if let filename = asset.value(forKey: "filename") as? String {
        item["filename"] = filename
      }

      if let targetLocation, let location = asset.location {
        item["distanceMeters"] = location.distance(from: targetLocation)
      }

      items.append(item)
    }

    return items
  }

  private func renderAsset(
    _ asset: PHAsset,
    targetSize: CGSize?,
    format: String
  ) async throws -> (Data, Int, Int, String) {
    if let targetSize {
      let image = try await self.requestImage(asset, targetSize: targetSize)
      return try self.encodeImage(image: image, format: format)
    }

    let data = try await self.requestImageData(asset)
    if let image = NSImage(data: data) {
      return try self.encodeImage(image: image, format: format)
    }

    return (data, asset.pixelWidth, asset.pixelHeight, self.mimeType(for: format))
  }

  private func requestImage(_ asset: PHAsset, targetSize: CGSize) async throws -> NSImage {
    try await withCheckedThrowingContinuation { continuation in
      let options = PHImageRequestOptions()
      options.isSynchronous = false
      options.deliveryMode = .highQualityFormat
      options.resizeMode = .fast

      PHImageManager.default().requestImage(
        for: asset,
        targetSize: targetSize,
        contentMode: .aspectFit,
        options: options
      ) { image, _ in
        if let image {
          continuation.resume(returning: image)
        } else {
          continuation.resume(throwing: CommandError.notFound)
        }
      }
    }
  }

  private func requestImageData(_ asset: PHAsset) async throws -> Data {
    try await withCheckedThrowingContinuation { continuation in
      let options = PHImageRequestOptions()
      options.isSynchronous = false
      options.deliveryMode = .highQualityFormat

      PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
        if let data {
          continuation.resume(returning: data)
        } else {
          continuation.resume(throwing: CommandError.notFound)
        }
      }
    }
  }

  private func encodeImage(image: NSImage, format: String) throws -> (Data, Int, Int, String) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData)
    else {
      throw CommandError(code: "ENCODING_FAILED", message: "Failed to encode image")
    }

    let data: Data?
    let mimeType = self.mimeType(for: format)
    switch format {
    case "png":
      data = bitmap.representation(using: .png, properties: [:])
    case "tiff":
      data = bitmap.representation(using: .tiff, properties: [:])
    default:
      data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
    }

    guard let finalData = data else {
      throw CommandError(code: "ENCODING_FAILED", message: "Failed to encode image")
    }

    return (finalData, Int(image.size.width), Int(image.size.height), mimeType)
  }

  private func mimeType(for format: String) -> String {
    switch format {
    case "png": "image/png"
    case "tiff": "image/tiff"
    default: "image/jpeg"
    }
  }

  private func parseDate(_ value: String?) -> Date? {
    guard let value, !value.isEmpty else { return nil }
    let formatter = ISO8601DateFormatter()
    return formatter.date(from: value)
  }

  private func parseSize(_ value: AnyCodable?) -> CGSize? {
    if let intValue = value?.intValue {
      return CGSize(width: intValue, height: intValue)
    }
    if let doubleValue = value?.doubleValue {
      return CGSize(width: doubleValue, height: doubleValue)
    }
    return nil
  }
}

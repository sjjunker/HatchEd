//
//  PhotosPickerImageLoading.swift
//  HatchEd
//
//  Resilient loading from PhotosPickerItem when Transferable / JPEG export fails (common with iCloud Photos).
//

import Foundation
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Transferable fast paths (iOS 16+)

private struct GenericImageDataTransfer: Transferable {
    let data: Data
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { Self(data: $0) }
    }
}

private struct JPEGImageDataTransfer: Transferable {
    let data: Data
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .jpeg) { Self(data: $0) }
    }
}

private struct PNGImageDataTransfer: Transferable {
    let data: Data
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .png) { Self(data: $0) }
    }
}

private struct HEICImageDataTransfer: Transferable {
    let data: Data
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .heic) { Self(data: $0) }
    }
}

private struct GIFImageDataTransfer: Transferable {
    let data: Data
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .gif) { Self(data: $0) }
    }
}

/// Loads image bytes: tries several `Transferable` types, then PhotoKit with network access for iCloud (iOS 17+).
func loadImageDataFromPhotosPickerItem(_ item: PhotosPickerItem) async throws -> (data: Data, mimeType: String, fileNameSuffix: String) {
    if let t = try? await item.loadTransferable(type: GenericImageDataTransfer.self), !t.data.isEmpty {
        let sniffed = sniffImageFormat(t.data)
        return (t.data, sniffed.mime, sniffed.suffix)
    }
    if let t = try? await item.loadTransferable(type: JPEGImageDataTransfer.self), !t.data.isEmpty {
        let sniffed = sniffImageFormat(t.data)
        return (t.data, sniffed.mime, sniffed.suffix)
    }
    if let t = try? await item.loadTransferable(type: PNGImageDataTransfer.self), !t.data.isEmpty {
        let sniffed = sniffImageFormat(t.data)
        return (t.data, sniffed.mime, sniffed.suffix)
    }
    if let t = try? await item.loadTransferable(type: HEICImageDataTransfer.self), !t.data.isEmpty {
        let sniffed = sniffImageFormat(t.data)
        return (t.data, sniffed.mime, sniffed.suffix)
    }
    if let t = try? await item.loadTransferable(type: GIFImageDataTransfer.self), !t.data.isEmpty {
        let sniffed = sniffImageFormat(t.data)
        return (t.data, sniffed.mime, sniffed.suffix)
    }

    if #available(iOS 17.0, *) {
        if let loaded = try await loadImageDataUsingPhotoKit(item) {
            return loaded
        }
    }

    throw NSError(
        domain: "PhotosPickerImageLoading",
        code: -2,
        userInfo: [NSLocalizedDescriptionKey: "Could not load this photo. If it’s stored in iCloud only, open it in the Photos app once to download it, then try again."]
    )
}

/// Uses `PhotosPickerItem.itemIdentifier` + PhotoKit so iCloud assets can be downloaded (`isNetworkAccessAllowed`).
@available(iOS 17.0, *)
private func loadImageDataUsingPhotoKit(_ item: PhotosPickerItem) async throws -> (data: Data, mimeType: String, fileNameSuffix: String)? {
    guard let localId = item.itemIdentifier else { return nil }
    let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [localId], options: nil)
    guard let asset = fetch.firstObject else { return nil }

    return try await withCheckedThrowingContinuation { continuation in
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .none

        PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, utiString, _, info in
            if let data = data, !data.isEmpty {
                let sniffed = sniffImageFormat(data)
                let mime = utiString.flatMap { UTType($0)?.preferredMIMEType } ?? sniffed.mime
                continuation.resume(returning: (data, mime, sniffed.suffix))
                return
            }
            let err = info?[PHImageErrorKey] as? NSError
            continuation.resume(throwing: err ?? NSError(
                domain: "PhotosPickerImageLoading",
                code: -5,
                userInfo: [NSLocalizedDescriptionKey: "Could not read image data from Photos."]
            ))
        }
    }
}

private func sniffImageFormat(_ data: Data) -> (mime: String, suffix: String) {
    guard data.count >= 3 else { return ("image/jpeg", "jpg") }
    if data.count >= 4, data[0] == 0x89, data[1] == 0x50, data[2] == 0x4E, data[3] == 0x47 {
        return ("image/png", "png")
    }
    if data[0] == 0xFF, data[1] == 0xD8 {
        return ("image/jpeg", "jpg")
    }
    if data.count >= 12, data[0] == 0x00, data[1] == 0x00, data[2] == 0x00, data[3] == 0x20, data[4] == 0x66, data[5] == 0x74, data[6] == 0x79, data[7] == 0x70 {
        return ("image/heic", "heic")
    }
    return ("image/jpeg", "jpg")
}

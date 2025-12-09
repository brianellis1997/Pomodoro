import Foundation
import UIKit

class SpotifyService: ObservableObject {
    static let shared = SpotifyService()

    private init() {}

    var isSpotifyInstalled: Bool {
        guard let url = URL(string: "spotify:") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    func openPlaylist(_ playlistUri: String) {
        let cleanUri = cleanPlaylistUri(playlistUri)
        guard let url = URL(string: cleanUri) else { return }
        UIApplication.shared.open(url)
    }

    func openSpotify() {
        guard let url = URL(string: "spotify:") else { return }
        UIApplication.shared.open(url)
    }

    private func cleanPlaylistUri(_ input: String) -> String {
        if input.hasPrefix("spotify:") {
            return input
        }

        if input.contains("open.spotify.com/playlist/") {
            if let playlistId = extractPlaylistId(from: input) {
                return "spotify:playlist:\(playlistId)"
            }
        }

        if input.contains("open.spotify.com/album/") {
            if let albumId = extractAlbumId(from: input) {
                return "spotify:album:\(albumId)"
            }
        }

        return "spotify:playlist:\(input)"
    }

    private func extractPlaylistId(from url: String) -> String? {
        guard let range = url.range(of: "playlist/") else { return nil }
        var playlistId = String(url[range.upperBound...])
        if let queryIndex = playlistId.firstIndex(of: "?") {
            playlistId = String(playlistId[..<queryIndex])
        }
        return playlistId.isEmpty ? nil : playlistId
    }

    private func extractAlbumId(from url: String) -> String? {
        guard let range = url.range(of: "album/") else { return nil }
        var albumId = String(url[range.upperBound...])
        if let queryIndex = albumId.firstIndex(of: "?") {
            albumId = String(albumId[..<queryIndex])
        }
        return albumId.isEmpty ? nil : albumId
    }
}

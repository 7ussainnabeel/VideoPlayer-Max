import Flutter
import UIKit
import CarPlay

class SceneDelegate: FlutterSceneDelegate {

}

@available(iOS 14.0, *)
class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
    var interfaceController: CPInterfaceController?
    var carplayChannel: FlutterMethodChannel?
    
    // CarPlay Tab templates
    var playlistsTemplate: CPListTemplate?
    var videosTemplate: CPListTemplate?
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didConnect interfaceController: CPInterfaceController) {
        self.interfaceController = interfaceController
        
        // Retrieve binary messenger from Flutter engine
        if let appDelegate = AppDelegate.shared,
           let controller = appDelegate.window?.rootViewController as? FlutterViewController {
            let channel = FlutterMethodChannel(name: "com.videoplayermax.media/carplay", binaryMessenger: controller.binaryMessenger)
            self.carplayChannel = channel
            
            channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
                if call.method == "reloadCarPlay" {
                    self?.reloadCarPlayData()
                    result(true)
                } else {
                    result(FlutterMethodNotImplemented)
                }
            }
        }
        
        setupCarPlayUI()
    }
    
    func templateApplicationScene(_ templateApplicationScene: CPTemplateApplicationScene, didDisconnect interfaceController: CPInterfaceController) {
        self.interfaceController = nil
        self.carplayChannel = nil
    }
    
    private func setupCarPlayUI() {
        let playlistsTab = CPListTemplate(title: "Playlists", sections: [])
        playlistsTab.tabImage = UIImage(systemName: "music.note.list")
        self.playlistsTemplate = playlistsTab
        
        let videosTab = CPListTemplate(title: "Videos", sections: [])
        videosTab.tabImage = UIImage(systemName: "video.fill")
        self.videosTemplate = videosTab
        
        let tabBar = CPTabBarTemplate(templates: [playlistsTab, videosTab])
        interfaceController?.setRootTemplate(tabBar, animated: true, completion: nil)
        
        loadPlaylists()
        loadVideos()
    }
    
    private func reloadCarPlayData() {
        loadPlaylists()
        loadVideos()
    }
    
    private func loadPlaylists() {
        carplayChannel?.invokeMethod("getPlaylists", arguments: nil) { [weak self] (result) in
            guard let self = self else { return }
            if let list = result as? [[String: Any]] {
                var items = [CPListItem]()
                for dict in list {
                    let id = dict["id"] as? String ?? ""
                    let name = dict["name"] as? String ?? "Untitled Playlist"
                    let count = dict["itemCount"] as? Int ?? 0
                    
                    let item = CPListItem(text: name, detailText: "\(count) videos")
                    item.setImage(UIImage(systemName: "music.note.list"))
                    item.handler = { [weak self] (item, completion) in
                        self?.openPlaylist(playlistId: id, title: name)
                        completion()
                    }
                    items.append(item)
                }
                
                let section = CPListSection(items: items)
                self.playlistsTemplate?.updateSections([section])
            }
        }
    }
    
    private func openPlaylist(playlistId: String, title: String) {
        // Push a detail list template representing the playlist
        let playlistDetailTemplate = CPListTemplate(title: title, sections: [])
        self.interfaceController?.pushTemplate(playlistDetailTemplate, animated: true, completion: nil)
        
        carplayChannel?.invokeMethod("getPlaylistItems", arguments: ["playlistId": playlistId]) { [weak self] (result) in
            guard let self = self else { return }
            if let list = result as? [[String: Any]] {
                var items = [CPListItem]()
                for dict in list {
                    let id = dict["id"] as? String ?? ""
                    let itemTitle = dict["title"] as? String ?? "Untitled Video"
                    let durationMs = dict["durationMs"] as? Int ?? 0
                    let durationStr = self.formatDuration(ms: durationMs)
                    
                    let item = CPListItem(text: itemTitle, detailText: durationStr)
                    item.setImage(UIImage(systemName: "video"))
                    item.handler = { [weak self] (item, completion) in
                        self?.playMediaItem(itemId: id, playlistId: playlistId)
                        completion()
                    }
                    items.append(item)
                }
                let section = CPListSection(items: items)
                playlistDetailTemplate.updateSections([section])
            }
        }
    }
    
    private func loadVideos() {
        carplayChannel?.invokeMethod("getVideos", arguments: nil) { [weak self] (result) in
            guard let self = self else { return }
            if let list = result as? [[String: Any]] {
                var items = [CPListItem]()
                for dict in list {
                    let id = dict["id"] as? String ?? ""
                    let itemTitle = dict["title"] as? String ?? "Untitled Video"
                    let durationMs = dict["durationMs"] as? Int ?? 0
                    let durationStr = self.formatDuration(ms: durationMs)
                    
                    let item = CPListItem(text: itemTitle, detailText: durationStr)
                    item.setImage(UIImage(systemName: "video"))
                    item.handler = { [weak self] (item, completion) in
                        self?.playMediaItem(itemId: id, playlistId: nil)
                        completion()
                    }
                    items.append(item)
                }
                let section = CPListSection(items: items)
                self.videosTemplate?.updateSections([section])
            }
        }
    }
    
    private func playMediaItem(itemId: String, playlistId: String?) {
        var args: [String: Any] = ["itemId": itemId]
        if let playlistId = playlistId {
            args["playlistId"] = playlistId
        }
        carplayChannel?.invokeMethod("playItem", arguments: args) { [weak self] (result) in
            if let self = self {
                // Instantly open the CarPlay Now Playing template
                self.interfaceController?.pushTemplate(CPNowPlayingTemplate.shared, animated: true, completion: nil)
            }
        }
    }
    
    private func formatDuration(ms: Int) -> String {
        let totalSeconds = ms / 1000
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

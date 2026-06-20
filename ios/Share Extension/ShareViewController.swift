import Social
import UIKit

private let schemePrefix = "ShareMedia"
private let userDefaultsKey = "ShareKey"
private let userDefaultsMessageKey = "ShareMessageKey"
private let appGroupIdKey = "AppGroupId"

final class ShareViewController: SLComposeServiceViewController {
  private var hostAppBundleIdentifier = ""
  private var appGroupId = ""
  private var sharedMedia: [SharedMediaFile] = []

  override func isContentValid() -> Bool {
    true
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    loadIds()
  }

  override func presentationAnimationDidFinish() {
    super.presentationAnimationDidFinish()
    navigationController?.navigationBar.topItem?.rightBarButtonItem?.title = "发送"
  }

  override func didSelectPost() {
    loadSharedItems()
  }

  override func configurationItems() -> [Any]! {
    []
  }

  private func loadIds() {
    let extensionBundleIdentifier = Bundle.main.bundleIdentifier ?? ""
    if let lastDot = extensionBundleIdentifier.lastIndex(of: ".") {
      hostAppBundleIdentifier = String(extensionBundleIdentifier[..<lastDot])
    }
    let defaultAppGroupId = "group.\(hostAppBundleIdentifier)"
    appGroupId = Bundle.main.object(forInfoDictionaryKey: appGroupIdKey) as? String ?? defaultAppGroupId
  }

  private func loadSharedItems() {
    guard
      let extensionContext,
      let content = extensionContext.inputItems.first as? NSExtensionItem,
      let attachments = content.attachments
    else {
      saveAndRedirect(message: contentText)
      return
    }
    if attachments.isEmpty {
      saveAndRedirect(message: contentText)
      return
    }

    let group = DispatchGroup()
    let urlType = "public.url"
    let textType = "public.text"
    for attachment in attachments {
      if attachment.hasItemConformingToTypeIdentifier(urlType) {
        group.enter()
        attachment.loadItem(forTypeIdentifier: urlType) { [weak self] data, _ in
          defer { group.leave() }
          if let url = data as? URL {
            self?.sharedMedia.append(SharedMediaFile(path: url.absoluteString, mimeType: nil, type: .url))
          } else if let text = data as? String {
            self?.sharedMedia.append(SharedMediaFile(path: text, mimeType: nil, type: .url))
          }
        }
      } else if attachment.hasItemConformingToTypeIdentifier(textType) {
        group.enter()
        attachment.loadItem(forTypeIdentifier: textType) { [weak self] data, _ in
          defer { group.leave() }
          if let text = data as? String {
            self?.sharedMedia.append(SharedMediaFile(path: text, mimeType: "text/plain", type: .text))
          }
        }
      }
    }
    group.notify(queue: .main) { [weak self] in
      self?.saveAndRedirect(message: self?.contentText)
    }
  }

  private func saveAndRedirect(message: String? = nil) {
    let defaults = UserDefaults(suiteName: appGroupId)
    defaults?.set(encoded(sharedMedia), forKey: userDefaultsKey)
    defaults?.set(message, forKey: userDefaultsMessageKey)
    defaults?.synchronize()
    redirectToHostApp()
  }

  private func redirectToHostApp() {
    loadIds()
    guard let url = URL(string: "\(schemePrefix)-\(hostAppBundleIdentifier):share") else {
      extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
      return
    }
    let selector = sel_registerName("openURL:")
    var responder = self as UIResponder?
    while responder != nil {
      if responder?.responds(to: selector) == true {
        _ = responder?.perform(selector, with: url)
        break
      }
      responder = responder?.next
    }
    extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
  }

  private func encoded(_ files: [SharedMediaFile]) -> String {
    guard let data = try? JSONEncoder().encode(files) else {
      return "[]"
    }
    return String(data: data, encoding: .utf8) ?? "[]"
  }
}

private struct SharedMediaFile: Codable {
  let path: String
  let mimeType: String?
  let thumbnail: String? = nil
  let duration: Double? = nil
  let message: String? = nil
  let type: SharedMediaType
}

private enum SharedMediaType: String, Codable {
  case text
  case url
}

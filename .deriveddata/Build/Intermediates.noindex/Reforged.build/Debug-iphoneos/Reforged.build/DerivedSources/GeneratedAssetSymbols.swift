import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 11.0, macOS 10.13, tvOS 11.0, *)
extension ColorResource {

    /// The "AccentColor" asset catalog color resource.
    static let accent = ColorResource(name: "AccentColor", bundle: resourceBundle)

    /// The "LaunchScreenBackground" asset catalog color resource.
    static let launchScreenBackground = ColorResource(name: "LaunchScreenBackground", bundle: resourceBundle)

}

// MARK: - Image Symbols -

@available(iOS 11.0, macOS 10.7, tvOS 11.0, *)
extension ImageResource {

    /// The "AppIconImage" asset catalog image resource.
    static let appIcon = ImageResource(name: "AppIconImage", bundle: resourceBundle)

    /// The "sticky-note" asset catalog image resource.
    static let stickyNote = ImageResource(name: "sticky-note", bundle: resourceBundle)

    /// The "verse-bg-field" asset catalog image resource.
    static let verseBgField = ImageResource(name: "verse-bg-field", bundle: resourceBundle)

    /// The "verse-bg-forest" asset catalog image resource.
    static let verseBgForest = ImageResource(name: "verse-bg-forest", bundle: resourceBundle)

    /// The "verse-bg-mountains" asset catalog image resource.
    static let verseBgMountains = ImageResource(name: "verse-bg-mountains", bundle: resourceBundle)

    /// The "verse-bg-ocean" asset catalog image resource.
    static let verseBgOcean = ImageResource(name: "verse-bg-ocean", bundle: resourceBundle)

    /// The "verse-bg-sky" asset catalog image resource.
    static let verseBgSky = ImageResource(name: "verse-bg-sky", bundle: resourceBundle)

    /// The "verse-bg-sunset" asset catalog image resource.
    static let verseBgSunset = ImageResource(name: "verse-bg-sunset", bundle: resourceBundle)

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
@available(macOS 10.13, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    /// The "AccentColor" asset catalog color.
    static var accent: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .accent)
#else
        .init()
#endif
    }

    /// The "LaunchScreenBackground" asset catalog color.
    static var launchScreenBackground: AppKit.NSColor {
#if !targetEnvironment(macCatalyst)
        .init(resource: .launchScreenBackground)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 11.0, tvOS 11.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    /// The "AccentColor" asset catalog color.
    static var accent: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .accent)
#else
        .init()
#endif
    }

    /// The "LaunchScreenBackground" asset catalog color.
    static var launchScreenBackground: UIKit.UIColor {
#if !os(watchOS)
        .init(resource: .launchScreenBackground)
#else
        .init()
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension SwiftUI.Color {

    /// The "AccentColor" asset catalog color.
    static var accent: SwiftUI.Color { .init(.accent) }

    /// The "LaunchScreenBackground" asset catalog color.
    static var launchScreenBackground: SwiftUI.Color { .init(.launchScreenBackground) }

}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    /// The "AccentColor" asset catalog color.
    static var accent: SwiftUI.Color { .init(.accent) }

    /// The "LaunchScreenBackground" asset catalog color.
    static var launchScreenBackground: SwiftUI.Color { .init(.launchScreenBackground) }

}
#endif

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
@available(macOS 10.7, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    /// The "AppIconImage" asset catalog image.
    static var appIcon: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .appIcon)
#else
        .init()
#endif
    }

    /// The "sticky-note" asset catalog image.
    static var stickyNote: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .stickyNote)
#else
        .init()
#endif
    }

    /// The "verse-bg-field" asset catalog image.
    static var verseBgField: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .verseBgField)
#else
        .init()
#endif
    }

    /// The "verse-bg-forest" asset catalog image.
    static var verseBgForest: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .verseBgForest)
#else
        .init()
#endif
    }

    /// The "verse-bg-mountains" asset catalog image.
    static var verseBgMountains: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .verseBgMountains)
#else
        .init()
#endif
    }

    /// The "verse-bg-ocean" asset catalog image.
    static var verseBgOcean: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .verseBgOcean)
#else
        .init()
#endif
    }

    /// The "verse-bg-sky" asset catalog image.
    static var verseBgSky: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .verseBgSky)
#else
        .init()
#endif
    }

    /// The "verse-bg-sunset" asset catalog image.
    static var verseBgSunset: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .verseBgSunset)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 11.0, tvOS 11.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    /// The "AppIconImage" asset catalog image.
    static var appIcon: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .appIcon)
#else
        .init()
#endif
    }

    /// The "sticky-note" asset catalog image.
    static var stickyNote: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .stickyNote)
#else
        .init()
#endif
    }

    /// The "verse-bg-field" asset catalog image.
    static var verseBgField: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .verseBgField)
#else
        .init()
#endif
    }

    /// The "verse-bg-forest" asset catalog image.
    static var verseBgForest: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .verseBgForest)
#else
        .init()
#endif
    }

    /// The "verse-bg-mountains" asset catalog image.
    static var verseBgMountains: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .verseBgMountains)
#else
        .init()
#endif
    }

    /// The "verse-bg-ocean" asset catalog image.
    static var verseBgOcean: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .verseBgOcean)
#else
        .init()
#endif
    }

    /// The "verse-bg-sky" asset catalog image.
    static var verseBgSky: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .verseBgSky)
#else
        .init()
#endif
    }

    /// The "verse-bg-sunset" asset catalog image.
    static var verseBgSunset: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .verseBgSunset)
#else
        .init()
#endif
    }

}
#endif

// MARK: - Thinnable Asset Support -

@available(iOS 11.0, macOS 10.13, tvOS 11.0, *)
@available(watchOS, unavailable)
extension ColorResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if AppKit.NSColor(named: NSColor.Name(thinnableName), bundle: bundle) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIColor(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 10.13, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    private convenience init?(thinnableResource: ColorResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 11.0, tvOS 11.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    private convenience init?(thinnableResource: ColorResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension SwiftUI.Color {

    private init?(thinnableResource: ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    private init?(thinnableResource: ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}
#endif

@available(iOS 11.0, macOS 10.7, tvOS 11.0, *)
@available(watchOS, unavailable)
extension ImageResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if bundle.image(forResource: NSImage.Name(thinnableName)) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIImage(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 10.7, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    private convenience init?(thinnableResource: ImageResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 11.0, tvOS 11.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    private convenience init?(thinnableResource: ImageResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

// MARK: - Backwards Deployment Support -

/// A color resource.
struct ColorResource: Swift.Hashable, Swift.Sendable {

    /// An asset catalog color resource name.
    fileprivate let name: Swift.String

    /// An asset catalog color resource bundle.
    fileprivate let bundle: Foundation.Bundle

    /// Initialize a `ColorResource` with `name` and `bundle`.
    init(name: Swift.String, bundle: Foundation.Bundle) {
        self.name = name
        self.bundle = bundle
    }

}

/// An image resource.
struct ImageResource: Swift.Hashable, Swift.Sendable {

    /// An asset catalog image resource name.
    fileprivate let name: Swift.String

    /// An asset catalog image resource bundle.
    fileprivate let bundle: Foundation.Bundle

    /// Initialize an `ImageResource` with `name` and `bundle`.
    init(name: Swift.String, bundle: Foundation.Bundle) {
        self.name = name
        self.bundle = bundle
    }

}

#if canImport(AppKit)
@available(macOS 10.13, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

    /// Initialize a `NSColor` with a color resource.
    convenience init(resource: ColorResource) {
        self.init(named: NSColor.Name(resource.name), bundle: resource.bundle)!
    }

}

protocol _ACResourceInitProtocol {}
extension AppKit.NSImage: _ACResourceInitProtocol {}

@available(macOS 10.7, *)
@available(macCatalyst, unavailable)
extension _ACResourceInitProtocol {

    /// Initialize a `NSImage` with an image resource.
    init(resource: ImageResource) {
        self = resource.bundle.image(forResource: NSImage.Name(resource.name))! as! Self
    }

}
#endif

#if canImport(UIKit)
@available(iOS 11.0, tvOS 11.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    /// Initialize a `UIColor` with a color resource.
    convenience init(resource: ColorResource) {
#if !os(watchOS)
        self.init(named: resource.name, in: resource.bundle, compatibleWith: nil)!
#else
        self.init()
#endif
    }

}

@available(iOS 11.0, tvOS 11.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    /// Initialize a `UIImage` with an image resource.
    convenience init(resource: ImageResource) {
#if !os(watchOS)
        self.init(named: resource.name, in: resource.bundle, compatibleWith: nil)!
#else
        self.init()
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension SwiftUI.Color {

    /// Initialize a `Color` with a color resource.
    init(_ resource: ColorResource) {
        self.init(resource.name, bundle: resource.bundle)
    }

}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
extension SwiftUI.Image {

    /// Initialize an `Image` with an image resource.
    init(_ resource: ImageResource) {
        self.init(resource.name, bundle: resource.bundle)
    }

}
#endif
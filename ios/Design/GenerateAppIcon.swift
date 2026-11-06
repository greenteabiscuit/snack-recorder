// Reuses the shapes and colors from Android's app/src/main/res/drawable/ic_snack.xml.
// Run from the repository root: swift ios/Design/GenerateAppIcon.swift
import CoreGraphics
import ImageIO
import Foundation

let size = 1024
let context = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8,
                        bytesPerRow: size * 4, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
context.translateBy(x: 0, y: CGFloat(size))
context.scaleBy(x: CGFloat(size) / 48, y: -CGFloat(size) / 48)
func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> CGColor { CGColor(red: r/255, green: g/255, blue: b/255, alpha: 1) }
context.setFillColor(color(255, 247, 237))
context.fill(CGRect(x: 0, y: 0, width: 48, height: 48))
context.setFillColor(color(249, 115, 22))
let top = CGMutablePath()
top.move(to: CGPoint(x: 15, y: 16))
top.addCurve(to: CGPoint(x: 20.5, y: 10.5), control1: CGPoint(x: 15, y: 13), control2: CGPoint(x: 17.5, y: 10.5))
top.addLine(to: CGPoint(x: 27.5, y: 10.5))
top.addCurve(to: CGPoint(x: 33, y: 16), control1: CGPoint(x: 30.5, y: 10.5), control2: CGPoint(x: 33, y: 13))
top.addLine(to: CGPoint(x: 33, y: 20)); top.addLine(to: CGPoint(x: 15, y: 20)); top.closeSubpath()
context.addPath(top); context.fillPath()
context.setFillColor(color(253, 186, 116))
let bottom = CGMutablePath()
bottom.move(to: CGPoint(x: 12, y: 20)); bottom.addLine(to: CGPoint(x: 36, y: 20)); bottom.addLine(to: CGPoint(x: 33.6, y: 34.5))
bottom.addCurve(to: CGPoint(x: 28.8, y: 38.5), control1: CGPoint(x: 33.2, y: 36.8), control2: CGPoint(x: 31.2, y: 38.5))
bottom.addLine(to: CGPoint(x: 19.2, y: 38.5))
bottom.addCurve(to: CGPoint(x: 14.4, y: 34.5), control1: CGPoint(x: 16.8, y: 38.5), control2: CGPoint(x: 14.8, y: 36.8))
bottom.closeSubpath(); context.addPath(bottom); context.fillPath()
context.setFillColor(color(124, 45, 18))
for rect in [CGRect(x: 18, y: 24, width: 3, height: 3), CGRect(x: 27, y: 24, width: 3, height: 3), CGRect(x: 21, y: 31, width: 6, height: 2)] { context.fill(rect) }
let image = context.makeImage()!
let url = URL(fileURLWithPath: "ios/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, nil)
guard CGImageDestinationFinalize(destination) else { fatalError("Could not write app icon") }

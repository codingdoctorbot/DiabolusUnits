// Clears a ring texture's interior (e.g. baked glass) inside a radius, with a
// short feather, keeping the metal band. Writes the same 32-bit TGA layout as media/.
//   swiftc -O tools/clear_ring_interior.swift -o /tmp/clear_ring
//   /tmp/clear_ring in.tga out.tga innerRadiusPixels [featherPixels]
import CoreGraphics
import Foundation
import ImageIO

let args = CommandLine.arguments
guard args.count >= 4, let radius = Double(args[3]) else {
	print("usage: clear_ring in.tga out.tga innerRadiusPixels [featherPixels]"); exit(1)
}
let feather = args.count > 4 ? Double(args[4]) ?? 2 : 2
let img = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(URL(fileURLWithPath: args[1]) as CFURL, nil)!, 0, nil)!
let w = img.width, h = img.height
var px = [UInt8](repeating: 0, count: w * h * 4)
let ctx = CGContext(data: &px, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
	space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
let cx = Double(w) / 2, cy = Double(h) / 2
for y in 0..<h { for x in 0..<w {
	let d = ((Double(x) + 0.5 - cx) * (Double(x) + 0.5 - cx) + (Double(y) + 0.5 - cy) * (Double(y) + 0.5 - cy)).squareRoot()
	let keep = min(1, max(0, (d - (radius - feather)) / feather))
	for c in 0..<4 { px[(y * w + x) * 4 + c] = UInt8((Double(px[(y * w + x) * 4 + c]) * keep).rounded()) }
} }
var data = Data([0, 0, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, UInt8(w & 255), UInt8(w >> 8), UInt8(h & 255), UInt8(h >> 8), 32, 8])
for y in stride(from: h - 1, through: 0, by: -1) { for x in 0..<w {
	let i = (y * w + x) * 4, a = Int(px[i + 3])
	func un(_ v: UInt8) -> UInt8 { a == 0 ? 0 : UInt8(min(255, (Int(v) * 255 + a / 2) / a)) }
	data.append(contentsOf: [un(px[i + 2]), un(px[i + 1]), un(px[i]), UInt8(a)])
} }
try! data.write(to: URL(fileURLWithPath: args[2]))

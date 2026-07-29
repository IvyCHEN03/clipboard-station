#!/usr/bin/env swift

import AVFoundation
import CoreGraphics
import Foundation

guard CommandLine.arguments.count >= 3 else {
    fatalError("Usage: upscale-video.swift INPUT.mp4 OUTPUT.mp4")
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let asset = AVURLAsset(url: inputURL)
let duration = try await asset.load(.duration)

guard let sourceVideo = try await asset.loadTracks(withMediaType: .video).first else {
    fatalError("Input has no video track")
}

let composition = AVMutableComposition()
guard let videoTrack = composition.addMutableTrack(
    withMediaType: .video,
    preferredTrackID: kCMPersistentTrackID_Invalid
) else {
    fatalError("Could not create video track")
}

try videoTrack.insertTimeRange(
    CMTimeRange(start: .zero, duration: duration),
    of: sourceVideo,
    at: .zero
)

if let sourceAudio = try await asset.loadTracks(withMediaType: .audio).first,
   let audioTrack = composition.addMutableTrack(
       withMediaType: .audio,
       preferredTrackID: kCMPersistentTrackID_Invalid
   ) {
    try audioTrack.insertTimeRange(
        CMTimeRange(start: .zero, duration: duration),
        of: sourceAudio,
        at: .zero
    )
}

let outputSize = CGSize(width: 2560, height: 1440)
let instruction = AVMutableVideoCompositionInstruction()
instruction.timeRange = CMTimeRange(start: .zero, duration: duration)

let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videoTrack)
layerInstruction.setTransform(CGAffineTransform(scaleX: 4.0 / 3.0, y: 4.0 / 3.0), at: .zero)
instruction.layerInstructions = [layerInstruction]

let videoComposition = AVMutableVideoComposition()
videoComposition.renderSize = outputSize
videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
videoComposition.instructions = [instruction]

try? FileManager.default.removeItem(at: outputURL)
guard let exporter = AVAssetExportSession(
    asset: composition,
    presetName: AVAssetExportPresetHighestQuality
) else {
    fatalError("Could not create exporter")
}
exporter.videoComposition = videoComposition
try await exporter.export(to: outputURL, as: .mp4)
print(outputURL.path)

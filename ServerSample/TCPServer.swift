//
//  TCPServer.swift
//  ServerSample
//
//  Created by macbook air on 30/12/2018.
//  Copyright © 2018 a.lapatin@icloud.com. All rights reserved.
//



import Foundation
import AVFoundation

class TCPServer: NSObject {
    
    let domain = "local"
    let netServiceType = "_babywatcher._tcp."
    let netServiceName = "Baby Monitor"
    
    var service: NetService!
    var serviceRunning = false
    var registeredName: String?
    
    var inputStream: InputStream?
    var outputStream: OutputStream?
    var openedStreams = 0
    
    var dataReceivedCallback: ((String) -> Void)?
    
    
    
    var videoPreviewView: AVSampleBufferDisplayLayer?
    
    static let shared = TCPServer()
    
    private override init() {
        super.init()
        
        self.service = NetService(domain: domain, type: netServiceType, name: netServiceName, port: 0)
        self.service.includesPeerToPeer = true
        self.service.delegate = self
        self.service.publish(options: .listenForConnections)
        
        self.serviceRunning = true
    }
    
    func openStreams() {
        guard self.openedStreams == 0 else {
            return
        }
        
        self.inputStream?.delegate = self
        self.inputStream?.schedule(in: .current, forMode: .default)
        self.inputStream?.open()
        
        self.outputStream?.delegate = self
        self.outputStream?.schedule(in: .current, forMode: .default)
        self.outputStream?.open()
    }
    
    func closeStreams() {
        self.inputStream?.remove(from: .current, forMode: .default)
        self.inputStream?.close()
        self.inputStream = nil
        
        self.outputStream?.remove(from: .current, forMode: .default)
        self.outputStream?.close()
        self.outputStream = nil
        
        self.openedStreams = 0
    }
}

extension TCPServer: NetServiceDelegate {
    
    func netServiceDidPublish(_ sender: NetService) {
        self.registeredName = sender.name
        print("Service name: \(sender.port)")
    }
    
    func netService(_ sender: NetService, didAcceptConnectionWith inputStream: InputStream, outputStream: OutputStream) {
        OperationQueue.main.addOperation { [weak self] in
            if self?.inputStream != nil {
                inputStream.open()
                inputStream.close()
                outputStream.open()
                outputStream.close()
                return print("connection already open.")
            }
            self?.service?.stop()
            self?.serviceRunning = false
            self?.registeredName = nil
            self?.inputStream = inputStream
            self?.outputStream = outputStream
            self?.openStreams()
            
            print("connection accepted: streams opened.")
        }
    }
}

extension TCPServer: StreamDelegate {
    
    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        
        if eventCode.contains(.openCompleted) {
            self.openedStreams += 1
            print("Opend stream: \(openedStreams)")
            
            if self.openedStreams == 2 {
                self.service?.stop()
                self.serviceRunning = false
                self.registeredName = nil
            }
        }
        
        if eventCode.contains(.hasBytesAvailable) {
            guard let inputStream = self.inputStream else {
                return print("no input stream")
            }
            
            let bufferSize     = 3136320
            var buffer         = Array<UInt8>(repeating: 0, count: bufferSize)
            var message        = ""
            
            print("frame")
            
            while inputStream.hasBytesAvailable {
                
                
                let len = inputStream.read(&buffer, maxLength: bufferSize)
                var pixelBuffer: CVPixelBuffer?
//                var data = Data(buffer) as NSData
                
                
                
                let pixelBufferError = CVPixelBufferCreateWithBytes(nil,
                                                                    1920,
                                                                    1080,
                                                                    OSType(875704438),
                                                                    &buffer,
                                                                    2904,
                                                                    nil,
                                                                    nil,
                                                                    nil,
                                                                    &pixelBuffer)
//                print(pixelBufferError)
                switch pixelBufferError {
                case kCVReturnInvalidPixelBufferAttributes:
                    print("1")
                case kCVReturnInvalidPixelFormat:
                    print("2")
                case kCVReturnInvalidSize:
                    print("3")
                case kCVReturnPixelBufferNotMetalCompatible:
                    print("4")
                case kCVReturnPixelBufferNotOpenGLCompatible:
                    print("5")
                default:
                    break
                }
                
                var timingInfo: CMSampleTimingInfo = .invalid
                var videoInfo: CMVideoFormatDescription?
                
                
                if pixelBuffer != nil {
                CMVideoFormatDescriptionCreateForImageBuffer(allocator: nil,
                                                             imageBuffer: pixelBuffer!,
                                                             formatDescriptionOut: &videoInfo)
                
                
                var sampleBuffer: CMSampleBuffer?
                var sampleBufferError = CMSampleBufferCreateForImageBuffer(allocator: nil,
                                                                        imageBuffer: pixelBuffer!,
                                                                        dataReady: true,
                                                                        makeDataReadyCallback: nil,
                                                                        refcon: nil,
                                                                        formatDescription: videoInfo!,
                                                                        sampleTiming: &timingInfo,
                                                                        sampleBufferOut: &sampleBuffer)
                    
                    
                    if sampleBuffer != nil && videoPreviewView != nil {
                    print("sampleBuffer")
                        if (videoPreviewView?.isReadyForMoreMediaData)!{
                            videoPreviewView?.enqueue(sampleBuffer!)
                        }
                    }
                }
//                print(buffer)
                
                
                
//                print("bytes")
//
//
//                if len < 0 {
//                    print("error reading stream...")
//                    return self.closeStreams()
//                }
//                if len > 0 {
//                    message += String(bytes: buffer, encoding: .utf8)!
//                }
//                if len == 0 {
//                    print("no more bytes available...")
//                    break
//                }
            }
            self.dataReceivedCallback?(message)
        }
    }
}

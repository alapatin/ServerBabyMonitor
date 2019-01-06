//
//  TCPServer.swift
//  ServerSample
//
//  Created by macbook air on 30/12/2018.
//  Copyright © 2018 a.lapatin@icloud.com. All rights reserved.
//



import Foundation
import AVFoundation
import VideoToolbox


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
    
    var dataReceivedCallback: ((CMSampleBuffer) -> Void)?
    var labelPrint: (() -> ())?
    
    var pixelBuffer: CVPixelBuffer?
    
    var formatDesc: CMVideoFormatDescription?
    
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
        print("Service name: \(sender.name)")
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
            
            let bufferSize     = 60000
            var buffer         = Array<UInt8>(repeating: 0, count: bufferSize)
            
            while inputStream.hasBytesAvailable {
                let readStatus = inputStream.read(&buffer, maxLength: bufferSize)
                //???
                //                let bytes = inputStream.getBuffer(&buffer, length: &bufferSize)
                self.labelPrint!()
                
                
                // Decompression session
                
                let decompressionSession: VTDecompressionSession?
                let videoLayer: AVSampleBufferDisplayLayer?
                var spsSize: Int!
                var ppsSize: Int!
                
                
                let data: UInt8?
                let pps: UnsafeMutableRawPointer?
                let sps: UnsafeMutableRawPointer?
                let startCodeIndex = 0
                var secondCodeIndex = 0
                var thirdCodeIndex = 0
                
                let blockLength = 0
                
                let sampleBuffer: CMSampleBuffer?
                let blockBuffer: CMBlockBuffer?
                
                var NaluType = (buffer[startCodeIndex + 4] & 0x1F)
                
                // ??? format description
                if NaluType != 7 && formatDesc == nil {
                    print("Error: Frame is not an I Frame")
                }
                
                // NALU type 7 is the SPS parameter
                if NaluType == 7 {
                    print("NALU type: 7")
                    for index in (startCodeIndex + 4)..<(startCodeIndex + 40) {
                        if buffer[index] == 0x00 && buffer[index + 1] == 0x00 && buffer[index + 2] == 0x00 && buffer[index + 3] == 0x01 {
                            secondCodeIndex = index
                            spsSize = secondCodeIndex
                        }
                    }
                }
                
                // find what the second NALU type is
                NaluType = (buffer[secondCodeIndex + 4] & 0x1F);
                
                // NALU type 8 is the PPS parameter
                
                if NaluType == 8 {
                    //???
                    for index in (spsSize + 12)..<(spsSize + 50){
                        if buffer[index] == 0x00 && buffer[index + 1] == 0x00 && buffer[index + 2] == 0x00 && buffer[index + 3] == 0x01 {
                            thirdCodeIndex = index
                            ppsSize = thirdCodeIndex - spsSize
                        }
                    }
                }
                
                sps = malloc(spsSize - 4);
                pps = malloc(ppsSize - 4);
                
                // copy in the actual sps and pps values, again ignoring the 4 byte header
                memcpy (sps, &buffer[4], spsSize - 4);
                memcpy (pps, &buffer[spsSize + 4], ppsSize - 4);
                
                // now we set our H264 parameters
                let spsPointer = UnsafePointer(sps!.bindMemory(to: UInt8.self, capacity: spsSize - 4))
                let ppsPointer = UnsafePointer(pps!.bindMemory(to: UInt8.self, capacity: ppsSize - 4))
                
                // make pointers array
                let dataParamArray = [spsPointer, ppsPointer]
                let parameterSetPointers = UnsafePointer<UnsafePointer<UInt8>>(dataParamArray)
                
                // make parameter sizes array
                let sizeParamArray = [spsSize!, ppsSize!]
                let parameterSetSizes = UnsafePointer<Int>(sizeParamArray)
                
                let statusFormatDescription =
                    CMVideoFormatDescriptionCreateFromH264ParameterSets(allocator: nil,
                                                                        parameterSetCount: 2,
                                                                        parameterSetPointers: parameterSetPointers,
                                                                        parameterSetSizes: parameterSetSizes,
                                                                        nalUnitHeaderLength: 4,
                                                                        formatDescriptionOut: &formatDesc)
                
                
                
                //                    CMVideoFormatDescriptionCreateFromH264ParameterSets(nil, 2,
                //                                                                             (const uint8_t *const*)parameterSetPointers,
                //                                                                             parameterSetSizes, 4,
                //                                                                             &formatDesc);
                //
            }
        }
    }
}

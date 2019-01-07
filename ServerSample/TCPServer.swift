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
    
    
    var bufferPoint: UnsafeMutablePointer<UInt8>?
    var bufferLengthPoint: UnsafeMutablePointer<Int>?

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
            
            let bufferSize     = 300000
            var buffer         = Array<UInt8>(repeating: 0, count: bufferSize)
            
            while inputStream.hasBytesAvailable {
                let bytesFromStream = inputStream.read(&buffer, maxLength: bufferSize)
                if bytesFromStream < 0 {
                    print("Error: read buffer")
                    return
                }
                self.labelPrint!()
                print("bytesFromStream: \(bytesFromStream)")
                
// Decompression session
                
                var spsSize: Int!
                var ppsSize: Int!
                //                let data: UInt8?
                var pps: UnsafeMutableRawPointer?
                var sps: UnsafeMutableRawPointer?
                let startCodeIndex = 0
                var secondCodeIndex = 0
                var thirdCodeIndex = 0
                
                var blockLength = 0
                var blockBuffer: CMBlockBuffer?
                var sampleBuffer: CMSampleBuffer?
                
                var NaluType = (buffer[startCodeIndex + 4] & 0x1F)
                print(NaluType)
                if NaluType != 7 && formatDesc == nil {
                    print("Error: Frame is not an I Frame")
                    return
                }
                
                // NALU type 7 is the SPS parameter
                if NaluType == 7 {
                    print("NALU type: 7")
                    for index in (startCodeIndex + 4)..<(startCodeIndex + 40) {
                        if buffer[index] == 0x00 && buffer[index + 1] == 0x00 && buffer[index + 2] == 0x00 && buffer[index + 3] == 0x01 {
                            secondCodeIndex = index
                            spsSize = secondCodeIndex
                            break
                            
                        }
                    }
                // find what the second NALU type is
                NaluType = (buffer[secondCodeIndex + 4] & 0x1F)
                    print("2nd NALU type: \(NaluType)")
                }
                
                // NALU type 8 is the PPS parameter
                
                if NaluType == 8 {
                    //???
                    
                    if spsSize == nil {
                        return
                    }
                    
                    for index in (spsSize + 8)..<(spsSize + 50){
                        if buffer[index] == 0x00 && buffer[index + 1] == 0x00 && buffer[index + 2] == 0x00 && buffer[index + 3] == 0x01 {
                            thirdCodeIndex = index
                            ppsSize = thirdCodeIndex - spsSize
                            break
                        }
                    }
                
                    
                
                sps = malloc(spsSize - 4);
                pps = malloc(ppsSize - 4);

                // copy in the actual sps and pps values, again ignoring the 4 byte header
//                sps = memcpy (sps!, &buffer[4], spsSize - 4);
//                pps = memcpy (pps!, &buffer[spsSize + 4], ppsSize - 4);

                    
                    for i in 0...(spsSize - 5) {
                        memcpy(sps! + i, &buffer[4 + i], 1)
                    }
                    
                    for i in 0...(ppsSize - 5) {
                        memcpy(pps! + i, &buffer[spsSize + 4 + i], 1)
                    }
                    
                    
//                // now we set our H264 parameters
                let spsPointer = UnsafePointer(sps!.bindMemory(to: UInt8.self, capacity: spsSize - 4))
                let ppsPointer = UnsafePointer(pps!.bindMemory(to: UInt8.self, capacity: ppsSize - 4))
//
//                // make pointers array
                let dataParamArray = [spsPointer, ppsPointer]
                let parameterSetPointers = UnsafePointer<UnsafePointer<UInt8>>(dataParamArray)
//
//                // make parameter sizes array
                let sizeParamArray = [spsSize!, ppsSize!]
                let parameterSetSizes = UnsafePointer<Int>(sizeParamArray)

                let statusFormatDescription =
                    CMVideoFormatDescriptionCreateFromH264ParameterSets(allocator: nil,
                                                                        parameterSetCount: 2,
                                                                        parameterSetPointers: parameterSetPointers,
                                                                        parameterSetSizes: parameterSetSizes,
                                                                        nalUnitHeaderLength: 4,
                                                                        formatDescriptionOut: &formatDesc)
                    if statusFormatDescription != noErr {
                        print("Error: Can't create description")
                    }

                    while NaluType != 5 {
                        for index in (spsSize + ppsSize + 8)..<(ppsSize + ppsSize + 150){
                        if buffer[index] == 0x00 && buffer[index + 1] == 0x00 && buffer[index + 2] == 0x00 && buffer[index + 3] == 0x01 {
                            thirdCodeIndex = index
                            NaluType = (buffer[thirdCodeIndex + 4] & 0x1F)
                            break
                        }
                    }
                    }
                
                    print("3d nalu type: \(NaluType)")
                }
                
                // CREATE DECOMPRESSION SESSON IF NEED
                
                // NALU type 5 is an IDR frame
                if NaluType == 5 {
                    
                    // find the offset, or where the SPS and PPS NALUs end and the IDR frame NALU begins
                    let offset = thirdCodeIndex
                    blockLength = bytesFromStream - offset

                    let dataFrame = malloc(blockLength)

                    for i in 0...(blockLength - 1) {
                        memcpy(dataFrame! + i, &buffer[offset + i], 1)
                    }
                    
                    // replace the start code header on this NALU with its size.
                    // AVCC format requires that you do this.
                    // htonl converts the unsigned int from host to network byte order
                    
                    var dataLength32 = CFSwapInt32HostToBig(UInt32(blockLength - 4))

                    memcpy(dataFrame, &dataLength32, 4)

                    // create a block buffer from the IDR NALU
                    
                    let statusBlockBuffer = CMBlockBufferCreateWithMemoryBlock(allocator: nil,
                                                                               memoryBlock: dataFrame,
                                                                               blockLength: blockLength,
                                                                               blockAllocator: kCFAllocatorNull,
                                                                               customBlockSource: nil,
                                                                               offsetToData: 0,
                                                                               dataLength: blockLength,
                                                                               flags: 0,
                                                                               blockBufferOut: &blockBuffer)
                    
                    if statusBlockBuffer == kCMBlockBufferNoErr {
                        print("Create block buffer IDR frame")
                    }
                }
                
                // NALU type 1 is non-IDR
                if NaluType == 1 {
                    
                    blockLength = bytesFromStream;
                    let dataFrame = malloc(blockLength);

                    for i in 0...(blockLength - 1) {
                        memcpy(dataFrame! + i, &buffer[i], 1)
                    }
                    
        
                    // again, replace the start header with the size of the NALU
                    var dataLength32 = CFSwapInt32HostToBig(UInt32(blockLength - 4))
        
                    memcpy (dataFrame, &dataLength32, 4);
          
                    let statusBB = CMBlockBufferCreateWithMemoryBlock(allocator: nil,
                                                                      memoryBlock: dataFrame,
                                                                      blockLength: blockLength,
                                                                      blockAllocator: kCFAllocatorNull,
                                                                      customBlockSource: nil,
                                                                      offsetToData: 0,
                                                                      dataLength: blockLength,
                                                                      flags: 0,
                                                                      blockBufferOut: &blockBuffer)
                    if statusBB == kCMBlockBufferNoErr {
                        print("Create block buffer NON-IDR frame")
                    }
                }
 
                // now create our sample buffer from the block buffer,
                
                var sampleSize: size_t = blockLength
                
                let statusSB = CMSampleBufferCreate(allocator: kCFAllocatorDefault,
                                                    dataBuffer: blockBuffer,
                                                    dataReady: true,
                                                    makeDataReadyCallback: nil,
                                                    refcon: nil,
                                                    formatDescription: formatDesc,
                                                    sampleCount: 1,
                                                    sampleTimingEntryCount: 0,
                                                    sampleTimingArray: nil,
                                                    sampleSizeEntryCount: 1,
                                                    sampleSizeArray: &sampleSize,
                                                    sampleBufferOut: &sampleBuffer)
                if statusSB == noErr {
                    print("Create sample buffer")
                    
                }
                
                if let bufferAtt = sampleBuffer {
                    let attachments: CFArray! = CMSampleBufferGetSampleAttachmentsArray(bufferAtt,
                                                                                        createIfNecessary: true)
                    let dictionary = unsafeBitCast(CFArrayGetValueAtIndex(attachments, 0),
                                                   to: CFMutableDictionary.self)
                    let key = Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque()
                    let value = Unmanaged.passUnretained(kCFBooleanTrue).toOpaque()
                    CFDictionarySetValue(dictionary, key, value)
                }
                
                self.dataReceivedCallback!(sampleBuffer!)
                
            }
        }
    }
}

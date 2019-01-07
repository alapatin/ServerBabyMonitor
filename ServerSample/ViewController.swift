//
//  ViewController.swift
//  ServerSample
//
//  Created by macbook air on 30/12/2018.
//  Copyright © 2018 a.lapatin@icloud.com. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    var videoPreviewView: AVSampleBufferDisplayLayer?
    var controlTimebase: CMTimebase?
    
    @IBOutlet weak var previewLayer: UIView!
    @IBOutlet weak var label: UILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        videoPreviewView = AVSampleBufferDisplayLayer()
        videoPreviewView?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewView?.frame = view.layer.bounds
        
        
//        CMTimebaseCreateWithMasterClock(allocator: CFAllocatorGetDefault() as! CFAllocator,
//                                        masterClock: CMClockGetHostTimeClock(),
//                                        timebaseOut: &controlTimebase);
//        
//        CMTimebaseSetTime(self.videoPreviewView!.controlTimebase!, time: CMTime.zero);
//        CMTimebaseSetRate(self.videoPreviewView!.controlTimebase!, rate: 1.0);
        
        previewLayer.layer.addSublayer(videoPreviewView!)
        print("Livevideo")
        
//        TCPServer.shared.imagePrint = { image in
//            self.imageView.image = image
//        }
        
        TCPServer.shared.labelPrint = {
            self.label.text = "Hello, World"
        }
        
        //diaplay with AVSampleBufferDisplayLayer
        TCPServer.shared.dataReceivedCallback = { buffer in
            
            if (self.videoPreviewView?.isReadyForMoreMediaData)!{
                self.videoPreviewView?.enqueue(buffer)
                DispatchQueue.main.async(execute: {
                    self.videoPreviewView?.setNeedsDisplay()
                })
                
            }
        }
    }
}


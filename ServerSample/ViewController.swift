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
    
    
    @IBOutlet weak var previewLayer: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        videoPreviewView = AVSampleBufferDisplayLayer()
        videoPreviewView?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewView?.frame = view.layer.bounds
        previewLayer.layer.addSublayer(videoPreviewView!)
        print("Livevideo")
        
        TCPServer.shared.dataReceivedCallback = { buffer in
            
            if (self.videoPreviewView?.isReadyForMoreMediaData)!{
                self.videoPreviewView?.enqueue(buffer)
            }
        }
    }
}


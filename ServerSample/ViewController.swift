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
        
        TCPServer.shared.dataReceivedCallback = { data in
            print(data)
        }

//        while TCPServer.shared.sampleBuffer == nil {}
        
        
        
        
        videoPreviewView = AVSampleBufferDisplayLayer()
        videoPreviewView?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        videoPreviewView?.frame = view.layer.bounds
        previewLayer.layer.addSublayer(videoPreviewView!)
        print("Livevideo")
        
        TCPServer.shared.videoPreviewView = videoPreviewView
    }
}


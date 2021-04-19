//
//  test.swift
//  virtualBG
//
//  Created by yisin on 2021/3/29.
//

import Foundation
import UIKit
import AVFoundation

class DepthVideoViewController: UIViewController {
  @IBOutlet weak var previewView: UIImageView!
  
  let session = AVCaptureSession()
  let depthOutput = AVCaptureDepthDataOutput()
  let videoOutput = AVCaptureVideoDataOutput()
    
  var dataOutputSynchronizer: AVCaptureDataOutputSynchronizer!
  let dataOutputQueue = DispatchQueue(label: "video data queue",
                                      qos: .userInitiated,
                                      attributes: [],
                                      autoreleaseFrequency: .workItem)
  
  var depthMap: CIImage?
  var mask: CIImage?

  override func viewDidLoad() {
    super.viewDidLoad()

    configureCaptureSession()

    session.startRunning()
  }
}

extension DepthVideoViewController {
  func configureCaptureSession() {
    guard let camera = AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front) else {
      fatalError("No depth video camera available")
    }

    session.sessionPreset = .photo

    do {
      let cameraInput = try AVCaptureDeviceInput(device: camera)
      session.addInput(cameraInput)
    } catch {
      fatalError(error.localizedDescription)
    }

    
    videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]

    if session.canAddOutput(videoOutput) {
        session.addOutput(videoOutput)
    }
    else{
        print("cannot add video output")
    }

    let videoConnection = videoOutput.connection(with: .video)
    videoConnection?.videoOrientation = .portrait

    depthOutput.isFilteringEnabled = true
    session.addOutput(depthOutput)

    let depthConnection = depthOutput.connection(with: .depthData)
    depthConnection?.videoOrientation = .portrait

    
    let depthFormats = camera.activeFormat.supportedDepthDataFormats
    let filtered = depthFormats.filter({
        CMFormatDescriptionGetMediaSubType($0.formatDescription) == kCVPixelFormatType_DepthFloat16
    })
    let selectedFormat = filtered.max(by: {
        first, second in CMVideoFormatDescriptionGetDimensions(first.formatDescription).width < CMVideoFormatDescriptionGetDimensions(second.formatDescription).width
    })

    do {
        try camera.lockForConfiguration()
        camera.activeDepthDataFormat = selectedFormat
        camera.unlockForConfiguration()
    } catch {
        print("Could not lock device for configuration: \(error)")
        session.commitConfiguration()
        return
    }
    
    dataOutputSynchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [videoOutput, depthOutput])
    dataOutputSynchronizer.setDelegate(self, queue: dataOutputQueue)

  }
}

extension DepthVideoViewController: AVCaptureDataOutputSynchronizerDelegate{
    func dataOutputSynchronizer(_ synchronizer: AVCaptureDataOutputSynchronizer, didOutput synchronizedDataCollection: AVCaptureSynchronizedDataCollection) {
        
        guard let syncedDepthData: AVCaptureSynchronizedDepthData = synchronizedDataCollection.synchronizedData(for: depthOutput) as? AVCaptureSynchronizedDepthData, let syncedVideoData: AVCaptureSynchronizedSampleBufferData = synchronizedDataCollection.synchronizedData(for: videoOutput) as? AVCaptureSynchronizedSampleBufferData else {
                    print("Could not get data from synchronizedDataCollection")
                    return
                }

        let depthData = syncedDepthData.depthData

        var convertedDepth: AVDepthData

        let depthDataType = kCVPixelFormatType_DisparityFloat32
        if depthData.depthDataType != depthDataType {
          convertedDepth = depthData.converting(toDepthDataType: depthDataType)
        } else {
          convertedDepth = depthData
        }
        let pixelBuffer = convertedDepth.depthDataMap

        let depthMap = CIImage(cvPixelBuffer: pixelBuffer)

        //print(depthData,depthData.depthDataMap)

        let previewImage: CIImage
        previewImage = depthMap
        let displayImage = UIImage(ciImage: previewImage)
        
        DispatchQueue.main.async { [weak self] in
            
            self?.previewView.image = displayImage
        }
        
    }
    
}
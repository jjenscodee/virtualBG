//
//  test.swift
//  virtualBG
//
//  Created by yisin on 2021/3/29.
//

import Foundation
import UIKit
import AVFoundation
import Accelerate

class DepthVideoViewController: UIViewController {
  @IBOutlet weak var previewView: UIImageView!
  @IBOutlet weak var sliderVal: UISlider!
  var sliderValue: CGFloat = 0.0
  @IBAction func slider(_ sender: UISlider) {
        sliderValue = CGFloat(sliderVal.value)
    }
  var automatic_flag = false
  @IBOutlet var mySwitch: UISwitch!
    @IBAction func switchDidChange(_ sender: UISwitch){
        if sender.isOn{
            automatic_flag = true
        }
        else{
            automatic_flag = false
        }
    }
  let session = AVCaptureSession()
  let depthOutput = AVCaptureDepthDataOutput()
  let videoOutput = AVCaptureVideoDataOutput()
    
  var dataOutputSynchronizer: AVCaptureDataOutputSynchronizer!
  let dataOutputQueue = DispatchQueue(label: "video data queue",
                                      qos: .userInitiated,
                                      attributes: [],
                                      autoreleaseFrequency: .workItem)
  
  var depthMap: CIImage?
  var depthFilters = DepthFilters()
  var update_adjust: Timer?
  var automatic_adjust = CGFloat(0)
    
  override func viewDidLoad() {
    super.viewDidLoad()
    update_adjust = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(runTimedCode), userInfo: nil, repeats: true)
    configureCaptureSession()

    session.startRunning()
  }
}

extension DepthVideoViewController {
    @objc func runTimedCode() {
        automatic_adjust = getHistogram(depthMap!)
    }
    
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

    // Search for highest resolution with half-point depth values
    let depthFormats = camera.activeFormat.supportedDepthDataFormats
    let filtered = depthFormats.filter({
        CMFormatDescriptionGetMediaSubType($0.formatDescription) == kCVPixelFormatType_DisparityFloat16
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
    
    //session.commitConfiguration()

  }
}

extension DepthVideoViewController: AVCaptureDataOutputSynchronizerDelegate{
    func convertCIImageToCGImage(inputImage: CIImage) -> CGImage? {
        let context = CIContext(options: nil)
        if let cgImage = context.createCGImage(inputImage, from: inputImage.extent) {
            return cgImage
        }
        return nil
    }
    

    func getHistogram(_ image: CIImage)->  CGFloat  {
        //[Int: Int]
            guard
                let cgImage = convertCIImageToCGImage(inputImage: image),
                var imageBuffer = try? vImage_Buffer(cgImage: cgImage)
            else {
                //print("nonononon")
                return -1
            }
            defer {
                imageBuffer.free()
            }
            //print("hihihihihihihihih")
            var redArray: [vImagePixelCount] = Array(repeating: 0, count: 256)
            var greenArray: [vImagePixelCount] = Array(repeating: 0, count: 256)
            var blueArray: [vImagePixelCount] = Array(repeating: 0, count: 256)
            var alphaArray: [vImagePixelCount] = Array(repeating: 0, count: 256)
            var error: vImage_Error = kvImageNoError

            redArray.withUnsafeMutableBufferPointer { rPointer in
                greenArray.withUnsafeMutableBufferPointer { gPointer in
                    blueArray.withUnsafeMutableBufferPointer { bPointer in
                        alphaArray.withUnsafeMutableBufferPointer { aPointer in

                var histogram = [ rPointer.baseAddress, gPointer.baseAddress, bPointer.baseAddress, aPointer.baseAddress ]
                histogram.withUnsafeMutableBufferPointer { hPointer in
                  
                  if let hBaseAddress = hPointer.baseAddress {
                    
                    error = vImageHistogramCalculation_ARGB8888(&imageBuffer, hBaseAddress, UInt32(kvImageNoFlags))
                                }
                            }
                        }
                    }
                }
            }
          
        var max1 = -1
        var maxval1 = -1
        var max2 = -1
        var maxval2 = -1
        
        
        for i in 1..<255{
            //print("hi")
            if (redArray[i-1] < redArray[i] && redArray[i] > redArray[i+1]){
                if(maxval1 >= maxval2){
                    if(redArray[i] > maxval2){
                        max2 = i
                        maxval2 = Int(Double(redArray[i]))
                    }
                }
                else{
                    if(redArray[i] > maxval1){
                        max1 = i
                        maxval1 = Int(Double(redArray[i]))
                    }
                }
            }
        }
        
        if(redArray[255] > redArray[254]){
            
            if(maxval1 >= maxval2){
                if(redArray[255] > maxval2){
                    max2 = 255
                    maxval2 = Int(Double(redArray[255]))
                }
            }
            else{
                if(redArray[255] > maxval1){
                    max1 = 255
                    maxval1 = Int(Double(redArray[255]))
                }
            }
        }
        
        
        
        return CGFloat(abs(max1 + max2))/2
        
        }

    
    func dataOutputSynchronizer(_ synchronizer: AVCaptureDataOutputSynchronizer, didOutput synchronizedDataCollection: AVCaptureSynchronizedDataCollection) {
        
        guard let syncedDepthData: AVCaptureSynchronizedDepthData = synchronizedDataCollection.synchronizedData(for: depthOutput) as? AVCaptureSynchronizedDepthData,
        let syncedVideoData: AVCaptureSynchronizedSampleBufferData = synchronizedDataCollection.synchronizedData(for: videoOutput) as? AVCaptureSynchronizedSampleBufferData else {
                    print("Could not get data from synchronizedDataCollection")
                    return
                }
        
        if syncedDepthData.depthDataWasDropped || syncedVideoData.sampleBufferWasDropped {
            return
        }
        
        
        // depth map
        let depthData = syncedDepthData.depthData
        var convertedDepth: AVDepthData
        // get disparity
        let depthDataType = kCVPixelFormatType_DisparityFloat32
        if depthData.depthDataType != depthDataType {
          convertedDepth = depthData.converting(toDepthDataType: depthDataType)
        } else {
          convertedDepth = depthData
        }
        let pixelBuffer = convertedDepth.depthDataMap
        depthMap = CIImage(cvPixelBuffer: pixelBuffer)
        //print(depthMap)
        //print()

        // video to image
        let sampleBuffer = syncedVideoData.sampleBuffer
        guard let videoPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                return
        }
        let image = CIImage(cvPixelBuffer: videoPixelBuffer)
        
        // get background
        let background: CIImage! = CIImage(image: BG.background!)
        
        // automanic
        print( getHistogram(depthMap!))
        //automatic_adjust = getHistogram(depthMap!)
        // create mask
        //print(automatic_flag)
        let masks = depthFilters.createMask(for: depthMap!, slope: sliderValue, adjust: automatic_adjust, flag: automatic_flag)
        
        // get filtered image
        let previewImage: CIImage
        previewImage = depthFilters.virtualBG(image: image,
                                                background: background,
                                                mask: masks)
        
        let displayImage = UIImage(ciImage: previewImage)
        //let displayImage = UIImage(ciImage: masks)
        //let displayImage = UIImage(ciImage: depthMap!)
        //let displayImage = UIImage(ciImage: image)
        
        DispatchQueue.main.async { [weak self] in
            
            self?.previewView.image = displayImage
        }
        
    }
    
}

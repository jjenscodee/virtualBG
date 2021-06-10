//
//  DepthFilter.swift
//  virtualBG
//
//  Created by yisin on 2021/4/19.
//

import Foundation
import CoreImage
import UIKit
import AVFoundation
import Accelerate

class DepthFilters {
    func createMask(for depthImage: CIImage, slope: CGFloat, adjust: CGFloat, flag: Bool) -> CIImage {
        
    let focus = 0.99 //0.99
    // the larger scale, the steeper slope
        let scale = 3.75
    
    var automatic_adjust = adjust
    var filterwidth =  0.1 + CGFloat(2 / scale)
    
    // moves the line left or right //plus to move right
    var b = -CGFloat(scale) * (CGFloat(focus) - filterwidth / CGFloat(2))
        
    if(flag == false){
        filterwidth =  0.1 + CGFloat(2 / slope)
        //b = -CGFloat(slope) * (CGFloat(focus) - filterwidth / CGFloat(2))
        b = slope
        //print(b)
    }
        
    if(flag == true){
        if(automatic_adjust != -1){
            //b = -CGFloat(scale) * (CGFloat(focus) - filterwidth / CGFloat(2)) - (1/automatic_adjust*1000)
            b = -automatic_adjust
            
        }
    }
    //b = 0
    
    
    
    let mask = depthImage
      .applyingFilter("CIColorMatrix", parameters: [
        "inputRVector": CIVector(x: 255, y: 0, z: 0, w: 0),
        "inputGVector": CIVector(x: 0, y: 255, z: 0, w: 0),
        "inputBVector": CIVector(x: 0, y: 0, z: 255, w: 0),
        "inputBiasVector": CIVector(x: b, y: b, z: b, w: 0)
      ])
        .applyingFilter("CIColorClamp")   //set value between 0 to 1
      .applyingFilter("CILanczosScaleTransform", parameters: [
        "inputScale": 3.75
      ]) //bicubic scale transform filter
    
   // print(mask)
    return mask
        
        
  }

  
    
  func virtualBG(image: CIImage,
                 background: CIImage,
                 mask: CIImage) -> CIImage {
    
    let crop = CIVector(x: 0,
                      y: 0,
                      z: image.extent.size.width,
                      w: image.extent.size.height)

    let croppedBG = background.applyingFilter("CICrop", parameters: [
    "inputRectangle": crop ])

    return image.applyingFilter("CIBlendWithMask", parameters: [
    "inputBackgroundImage": croppedBG,
    "inputMaskImage": mask ])
  }

}

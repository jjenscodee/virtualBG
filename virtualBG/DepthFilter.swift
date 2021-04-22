//
//  DepthFilter.swift
//  virtualBG
//
//  Created by yisin on 2021/4/19.
//

import Foundation
import CoreImage


class DepthFilters {
  func createMask(for depthImage: CIImage,
                          isSharp: Bool = false) -> CIImage {
    let focus = 0.99
    let scale = 3.75
    let filterWidth =  2 / 4 + 0.1
    let b = -4 * (CGFloat(focus) - CGFloat(filterWidth) / 2)

    let mask = depthImage
      .applyingFilter("CIColorMatrix", parameters: [
        "inputRVector": CIVector(x: 4, y: 0, z: 0, w: 0),
        "inputGVector": CIVector(x: 0, y: 4, z: 0, w: 0),
        "inputBVector": CIVector(x: 0, y: 0, z: 4, w: 0),
        "inputBiasVector": CIVector(x: b-1, y: b-1, z: b-1, w: 0)
      ])
      .applyingFilter("CIColorClamp")   //set value between 0 to 1
      .applyingFilter("CIBicubicScaleTransform", parameters: [
        "inputScale": scale
      ]) //bicubic scale transform filter

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

//
//  ViewController.swift
//  virtualBG
//
//  Created by yisin on 2021/3/25.
//

import UIKit

class ViewController: UIViewController, UIImagePickerControllerDelegate,
    UINavigationControllerDelegate {

    @IBOutlet var imageView: UIImageView!

    let pickerController = UIImagePickerController()


    @IBAction func buttonTest(_ sender: UIButton) {
        pickerController.allowsEditing = false
        pickerController.sourceType = .photoLibrary

        present(pickerController, animated: true, completion: nil)
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        pickerController.delegate = self
    }

    func imagePickerController(_ picker: UIImagePickerController,
        didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {

        if let pickedImage = info[UIImagePickerController.InfoKey.originalImage] as? UIImage {
            imageView.contentMode = .scaleAspectFit
            imageView.image = pickedImage
        }

        dismiss(animated: true, completion: nil)
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        dismiss(animated: true, completion: nil)
    }
}

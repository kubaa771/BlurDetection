//
//  ViewController.swift
//  BlurDetection
//
//  Created by Jakub Iwaszek on 07/06/2021.
//

import UIKit
import Metal
import MetalKit
import MetalPerformanceShaders

class ViewController: UIViewController {
    
    @IBOutlet weak var pictureImageView: UIImageView!
    var imagePicker: UIImagePickerController!
    var presentedImage: UIImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        configureImagePicker()
    }
    
    func configureImagePicker() {
        imagePicker = UIImagePickerController()
        imagePicker.delegate = self
    }
    
    @IBAction func cameraButtonTapped(_ sender: UIButton) {
        imagePicker.sourceType = .camera
        present(imagePicker, animated: true, completion: nil)
    }
    
    @IBAction func picturesButtonTapped(_ sender: UIButton) {
        imagePicker.sourceType = .photoLibrary
        present(imagePicker, animated: true, completion: nil)
    }
    
    @IBAction func detectBlurButtonTapped(_ sender: UIButton) {
        guard let presentedImage = presentedImage else {
            self.showAlert(title: "Error", message: "Choose an image first")
            return
        }
        renderImage(presentedImage.cgImage!)
        
    }
    
    func renderImage(_ image: CGImage) {
        guard let mtlDevice = MTLCreateSystemDefaultDevice() else { return }
        let mtlCommandQueue = mtlDevice.makeCommandQueue()
        
        let commandBuffer = mtlCommandQueue?.makeCommandBuffer()!
        
        let laplacian = MPSImageLaplacian(device: mtlDevice)
        let meanAndVariance = MPSImageStatisticsMeanAndVariance(device: mtlDevice)
        
        let textureLoader = MTKTextureLoader(device: mtlDevice)
        let srcTexture = try! textureLoader.newTexture(cgImage: image, options: nil)
        
        let lapDesc = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: srcTexture.pixelFormat, width: srcTexture.width, height: srcTexture.height, mipmapped: false)
        lapDesc.usage = [.shaderRead, .shaderWrite]
        let lapTex = mtlDevice.makeTexture(descriptor: lapDesc)!
        
        laplacian.encode(commandBuffer: commandBuffer!, sourceTexture: srcTexture, destinationTexture: lapTex)
        
        let varianceTextureDescriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: srcTexture.pixelFormat, width: 2, height: 1, mipmapped: false)
        varianceTextureDescriptor.usage = [.shaderWrite, .shaderRead]
        let varianceTexture = mtlDevice.makeTexture(descriptor: varianceTextureDescriptor)
        
        meanAndVariance.encode(commandBuffer: commandBuffer!, sourceTexture: lapTex, destinationTexture: varianceTexture!)
        
        commandBuffer?.commit()
        commandBuffer?.waitUntilCompleted()
        
        var result = [Int8](repeatElement(0, count: 2))
        let region = MTLRegionMake2D(0, 0, 2, 1)
        varianceTexture?.getBytes(&result, bytesPerRow: 1*2*4, from: region, mipmapLevel: 0)
        
        let variance = result.last!
        print(result)
        print(region)
        print(variance)
        
        if variance < 3 {
            self.showAlert(title: "Alert", message: "Poziom rozmycia zbyt wysoki")
        } else {
            self.showAlert(title: "Alert", message: "Poziom rozmycia jest niski")
        }
        
    }
    
    
    
}

extension ViewController: UINavigationControllerDelegate, UIImagePickerControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        imagePicker.dismiss(animated: true, completion: nil)
        guard let image = info[.originalImage] as? UIImage else {
            self.showAlert(title: "Error", message: "Image not found.")
            return
        }
        presentedImage = image
        pictureImageView.image = image
    }
}

extension UIViewController {
    func showAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let okAlertAction = UIAlertAction(title: "OK", style: .default, handler: nil)
        alert.addAction(okAlertAction)
        self.present(alert, animated: true, completion: nil)
    }
}


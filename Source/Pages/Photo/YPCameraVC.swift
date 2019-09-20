//
//  YPCameraVC.swift
//  YPImgePicker
//
//  Created by Sacha Durand Saint Omer on 25/10/16.
//  Copyright © 2016 Yummypets. All rights reserved.
//

import UIKit
import AVFoundation
import Photos

public class YPCameraVC: UIViewController, UIGestureRecognizerDelegate, YPPermissionCheckable {
    
    public var didCapturePhoto: ((UIImage) -> Void)?
    let photoCapture = newPhotoCapture()
    let v: YPCameraView!
    var isInited = false
    override public func loadView()
    {
		if (UIDevice.current.userInterfaceIdiom == .pad)
		{
	    	super.loadView()
			v.translatesAutoresizingMaskIntoConstraints = false
			view.addSubview(v)
			v.top(0).bottom(0).width(540)
			v.centerHorizontally()
		}
		else
		{
	        view = v
		}
    }

    public required init() {
        self.v = YPCameraView(overlayView: YPConfig.overlayView)
        super.init(nibName: nil, bundle: nil)
        title = YPConfig.wordings.cameraTitle
    }
    
    public required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override public func viewDidLoad() {
        super.viewDidLoad()
        v.flashButton.isHidden = true
        v.flashButton.addTarget(self, action: #selector(flashButtonTapped), for: .touchUpInside)
        v.shotButton.addTarget(self, action: #selector(shotButtonTapped), for: .touchUpInside)
        v.flipButton.addTarget(self, action: #selector(flipButtonTapped), for: .touchUpInside)
		v.shotButton.isEnabled = false
       
        // Focus
        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(self.focusTapped(_:)))
        tapRecognizer.delegate = self
        v.previewViewContainer.addGestureRecognizer(tapRecognizer)
    }
    
    func start() {
        doAfterPermissionCheck { [weak self] in
            guard let strongSelf = self else {
                return
            }
            self?.photoCapture.start(with: strongSelf.v.previewViewContainer, completion: {
                DispatchQueue.main.async
                {
                    self?.isInited = true
                    self?.refreshFlashButton()
        			self?.v.shotButton.isEnabled = true
					strongSelf.photoCapture.videoLayer?.connection?.videoOrientation = strongSelf.transformOrientation(orientation: UIInterfaceOrientation(rawValue: UIApplication.shared.statusBarOrientation.rawValue)!)
                }
            })
        }
    }

    @objc
    func focusTapped(_ recognizer: UITapGestureRecognizer) {
        guard isInited else {
            return
        }
        
        doAfterPermissionCheck { [weak self] in
            self?.focus(recognizer: recognizer)
        }
    }
    
    func focus(recognizer: UITapGestureRecognizer) {

        let point = recognizer.location(in: v.previewViewContainer)
        
        // Focus the capture
        let viewsize = v.previewViewContainer.bounds.size
        let newPoint = CGPoint(x: point.x/viewsize.width, y: point.y/viewsize.height)
        photoCapture.focus(on: newPoint)
        
        // Animate focus view
        v.focusView.center = point
        YPHelper.configureFocusView(v.focusView)
        v.addSubview(v.focusView)
        YPHelper.animateFocusView(v.focusView)
    }
        
    func stopCamera() {
        photoCapture.stopCamera()
    }
    
    @objc
    func flipButtonTapped() {
        doAfterPermissionCheck { [weak self] in
            self?.photoCapture.flipCamera {
                self?.refreshFlashButton()
            }
        }
    }
    
    @objc
    func shotButtonTapped() {
        doAfterPermissionCheck { [weak self] in
            self?.shoot()
        }
    }
    
    func shoot() {
        // Prevent from tapping multiple times in a row
        // causing a crash
        v.shotButton.isEnabled = false
        
        photoCapture.shoot
        { imageData in
            
	        self.v.shotButton.isEnabled = true
            if let imageData = imageData
            {
	            
	            guard let shotImage = UIImage(data: imageData) else {
	                return
	            }
	            
	            self.photoCapture.stopCamera()
	            
	            var image = shotImage
	            // Crop the image if the output needs to be square.
	            if YPConfig.onlySquareImagesFromCamera {
	                image = self.cropImageToSquare(image)
	            }

	            // Flip image if taken form the front camera.
	            if let device = self.photoCapture.device, device.position == .front {
	                image = self.flipImage(image: image)
	            }
	            
	            DispatchQueue.main.async {
	                let noOrietationImage = image.resetOrientation()
	                self.didCapturePhoto?(noOrietationImage.resizedImageIfNeeded())
	            }
	    	}
        }
    }
    
    func cropImageToSquare(_ image: UIImage) -> UIImage {
        let orientation: UIDeviceOrientation = UIDevice.current.orientation
        var imageWidth = image.size.width
        var imageHeight = image.size.height
        switch orientation {
        case .landscapeLeft, .landscapeRight:
            // Swap width and height if orientation is landscape
            imageWidth = image.size.height
            imageHeight = image.size.width
        default:
            break
        }
        
        // The center coordinate along Y axis
        let rcy = imageHeight * 0.5
        let rect = CGRect(x: rcy - imageWidth * 0.5, y: 0, width: imageWidth, height: imageWidth)
        let imageRef = image.cgImage?.cropping(to: rect)
        return UIImage(cgImage: imageRef!, scale: 1.0, orientation: image.imageOrientation)
    }
    
    // Used when image is taken from the front camera.
    func flipImage(image: UIImage!) -> UIImage! {
//		return UIImage(cgImage: image.cgImage!, scale: 1.0, orientation: .downMirrored)
        return image
    }
    
    @objc
    func flashButtonTapped() {
        photoCapture.tryToggleFlash()
        refreshFlashButton()
    }
    
    func refreshFlashButton() {
        let flashImage = photoCapture.currentFlashMode.flashImage()
        v.flashButton.setImage(flashImage, for: .normal)
        v.flashButton.isHidden = !photoCapture.hasFlash
    }

    func transformOrientation(orientation: UIInterfaceOrientation) -> AVCaptureVideoOrientation
    {
        switch orientation
        {
		case .landscapeLeft:
			return .landscapeLeft
		case .landscapeRight:
			return .landscapeRight
		case .portraitUpsideDown:
			return .portraitUpsideDown
        default:
			return .portrait
        }
    }
    
	override public func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator)
	{
		coordinator.animate(alongsideTransition:
		{ (_) in
			self.photoCapture.videoLayer?.connection?.videoOrientation = self.transformOrientation(orientation: UIInterfaceOrientation(rawValue: UIApplication.shared.statusBarOrientation.rawValue)!)
        },
        completion:
		{ _ in
        })
        super.viewWillTransition(to: size, with: coordinator)
    }

}

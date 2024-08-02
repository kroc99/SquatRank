import UIKit
import AVFoundation
import CoreGraphics

class ObjectDetectionVC: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, PoseNetDelegate {
    @IBOutlet weak var cameraView: UIView!
    var session: AVCaptureSession?
    var device: AVCaptureDevice?
    var input: AVCaptureDeviceInput?
    var output: AVCaptureVideoDataOutput?
    var prevLayer: AVCaptureVideoPreviewLayer?
    let sampleBufferQueue = DispatchQueue.global(qos: .background)
    var processing = false
    let cv = CV() // Assuming CV is your object detection class
    let detectionsCanvas = DetectionsCanvas()
    var poseNet: PoseNet?
    var currentFrame: CGImage?

    override func viewDidLoad() {
        super.viewDidLoad()
        detectionsCanvas.isOpaque = false
        view.addSubview(detectionsCanvas)
        detectionsCanvas.labelmap = loadLabels()
        verifyCameraPermissions()
        do {
            poseNet = try PoseNet()
            poseNet?.delegate = self
        } catch {
            fatalError("Failed to load PoseNet model. Error: \(error.localizedDescription)")
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        prevLayer?.frame.size = cameraView.frame.size
        detectionsCanvas.frame = cameraView.frame
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return [.portrait]
    }
    
    func verifyCameraPermissions() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized: // The user has previously granted access to the camera.
                self.createSession()
            
            case .notDetermined: // The user has not yet been asked for camera access.
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    if granted {
                        DispatchQueue.main.sync {
                            self.createSession()
                        }
                    }
                }
            
            case .denied: // The user has previously denied access.
                return

            case .restricted: // The user can't grant access due to restrictions.
                return

        @unknown default:
            return
        }

    }
    
    func createSession() {
        session = AVCaptureSession()
        session?.sessionPreset = AVCaptureSession.Preset.photo
        device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        
        do {
            input = try AVCaptureDeviceInput(device: device!)
            guard input != nil else { return }
            session?.addInput(input!)
            
            prevLayer = AVCaptureVideoPreviewLayer(session: session!)
            prevLayer?.backgroundColor = UIColor.black.cgColor
            prevLayer?.frame.size = cameraView.frame.size
            prevLayer?.videoGravity = AVLayerVideoGravity.resizeAspect
            
            cameraView.layer.addSublayer(prevLayer!)

            let output = AVCaptureVideoDataOutput()
            let bufferPixelFormatKey = (kCVPixelBufferPixelFormatTypeKey as NSString) as String
            
            output.videoSettings = [bufferPixelFormatKey: NSNumber(value: kCVPixelFormatType_32BGRA)]
            output.alwaysDiscardsLateVideoFrames = true
            output.setSampleBufferDelegate(self, queue: sampleBufferQueue)
            session?.addOutput(output)
            output.connection(with: AVMediaType.video)?.videoOrientation = .portrait // MUST be after session.addOutput
            
            session?.startRunning()

        } catch {
            print(error)
        }
    }
    func createCGImage(from pixelBuffer: CVPixelBuffer) -> CGImage? {
       let ciContext = CIContext()
       let ciImage = CIImage(cvImageBuffer: pixelBuffer)
       return ciContext.createCGImage(ciImage, from: ciImage.extent)
    }
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
            guard !processing else { return }
            processing = true

            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                processing = false
                return
            }

            CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
            if let cgImage = createCGImage(from: pixelBuffer) {
                currentFrame = cgImage
                detectionsCanvas.actualCameraFrameWidth = CGFloat(CVPixelBufferGetWidth(pixelBuffer))
                    detectionsCanvas.actualCameraFrameHeight = CGFloat(CVPixelBufferGetHeight(pixelBuffer))
                poseNet?.predict(cgImage)
                // Additional object detection logic
            }
            CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly)


        // CV detection (optional, depends on your use case)
        let start = DispatchTime.now().uptimeNanoseconds
        
        let res = cv.detect(sampleBuffer)
 
        
        let span = DispatchTime.now().uptimeNanoseconds - start
        print("Detection time: \(span / 1000000) msec")

        // Convert results to Float and set it for drawing on the canvas
        detectionsCanvas.detections = res.compactMap {($0 as! Float)}
        

        DispatchQueue.main.async { [weak self] in
            self?.detectionsCanvas.setNeedsDisplay()
            self?.processing = false
        }
    }

    func loadLabels() -> [String] {
        var res = [String]()
        if let filepath = Bundle.main.path(forResource: "labels", ofType: "txt") {
            do {
                let contents = try String(contentsOfFile: filepath)
                res = contents.split { $0.isNewline }.map(String.init)
            } catch {
                print("Error loading labelmap.txt file")
            }
        }
        
        return res
    }
    func poseNet(_ poseNet: PoseNet, didPredict predictions: PoseNetOutput) {
            guard let currentFrame = currentFrame else { return }
            let poseBuilder = PoseBuilder(output: predictions, configuration: PoseBuilderConfiguration(), inputImage: currentFrame)
            let poses = [poseBuilder.pose] // Adapt based on your needs

            DispatchQueue.main.async {
                self.detectionsCanvas.poses = poses
                self.detectionsCanvas.setNeedsDisplay()
            }
        }
    
}

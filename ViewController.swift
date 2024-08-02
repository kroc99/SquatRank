import UIKit
import AVFoundation
import WebKit




class ViewController: UIViewController {

    var player: AVPlayer?
    var playerLayer: AVPlayerLayer?

    // IBOutlet for the button
        @IBOutlet weak var myButton: UIButton!
        @IBOutlet var webView: WKWebView!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        

                // Your HTML content with CSS embedded
        loadHTMLContentIntoWebView()
        playVideo()
        
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { // Adjust time as needed
                    self.webView.isHidden = true
                }
        
    }

    func loadHTMLContentIntoWebView() {
            // Your HTML content with CSS embedded
            let htmlContent = """
                <html>
                <head>
                <style>
                .loader {
                  position: relative;
                  width: 120px;
                  height: 90px;
                  margin: 0 auto;
                }
                .loader:before {
                  content: "";
                  position: absolute;
                  bottom: 30px;
                  left: 50px;
                  height: 30px;
                  width: 30px;
                  border-radius: 50%;
                  background: #2a9d8f;
                  animation: loading-bounce 0.5s ease-in-out infinite alternate;
                }
                .loader:after {
                  content: "";
                  position: absolute;
                  right: 0;
                  top: 0;
                  height: 7px;
                  width: 45px;
                  border-radius: 4px;
                  box-shadow: 0 5px 0 #f2f2f2, -35px 50px 0 #f2f2f2, -70px 95px 0 #f2f2f2;
                  animation: loading-step 1s ease-in-out infinite;
                }
                @keyframes loading-bounce {
                  0% {
                    transform: scale(1, 0.7);
                  }
                  40% {
                    transform: scale(0.8, 1.2);
                  }
                  60% {
                    transform: scale(1, 1);
                  }
                  100% {
                    bottom: 140px;
                  }
                }
                @keyframes loading-step {
                  0% {
                    box-shadow: 0 10px 0 rgba(0, 0, 0, 0),
                            0 10px 0 #f2f2f2,
                            -35px 50px 0 #f2f2f2,
                            -70px 90px 0 #f2f2f2;
                  }
                  100% {
                    box-shadow: 0 10px 0 #f2f2f2,
                            -35px 50px 0 #f2f2f2,
                            -70px 90px 0 #f2f2f2,
                            -70px 90px 0 rgba(0, 0, 0, 0);
                  }
                }
                </style>
                </head>
                <body>
                <div class="loader"></div>
                </body>
                </html>
                """
            webView.loadHTMLString(htmlContent, baseURL: nil)
        }
    
    
    func playVideo() {
        guard let videoURL = Bundle.main.url(forResource: "Untitled", withExtension: "mp4") else {
            print("Video file not found")
            return
        }

        player = AVPlayer(url: videoURL)
        playerLayer = AVPlayerLayer(player: player)
        
        // Adjusting the frame to cover the entire screen, including the notch
        playerLayer?.frame = UIScreen.main.bounds
        playerLayer?.videoGravity = .resizeAspectFill // Fill the screen while maintaining aspect ratio
        self.view.layer.insertSublayer(playerLayer!, at: 0) // Insert at 0 to avoid covering other UI elements

        player?.play()

        NotificationCenter.default.addObserver(self,
                                               selector: #selector(videoDidEnd),
                                               name: .AVPlayerItemDidPlayToEndTime,
                                               object: player?.currentItem)
    }

    @objc func videoDidEnd(notification: NSNotification) {
        playerLayer?.removeFromSuperlayer()
        player = nil
        NotificationCenter.default.removeObserver(self)

        // Transition using AppDelegate's method
        if let appDelegate = UIApplication.shared.delegate as? AppDelegate {
            appDelegate.transitionToMainStoryboard()
        }
        
        // Animation for the button to smoothly appear
            myButton.isHidden = false
            myButton.alpha = 0
            UIView.animate(withDuration: 0.5, animations: {
                self.myButton.alpha = 1
    }
                           )}

            }

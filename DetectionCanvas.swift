import Foundation
import UIKit


class DetectionsCanvas: UIView {
    var labelmap = [String]()
    var detections = [Float]() // Raw results from detector
    var circledetections = [Float]()
    
    // The size of the image we run detection on
    var actualCameraFrameWidth: CGFloat = 0
    var actualCameraFrameHeight: CGFloat = 0
    var poses: [Pose] = []
    var plateCenters: [Int: [CGPoint]] = [:]
    var squatsDone = 0
    var isCurrentlySquatting = true
    var largestBoundingBox: CGRect = .zero
    var largestBoxCenter: CGPoint = .zero
    
    var tolerancevalue = 10.0
    
    struct JointSegment {
        let jointA: Joint.Name
        let jointB: Joint.Name
    }
    
    static let jointSegments = [
        // The connected joints that are on the left side of the body.
        JointSegment(jointA: .leftHip, jointB: .leftShoulder),
        JointSegment(jointA: .leftShoulder, jointB: .leftElbow),
        JointSegment(jointA: .leftElbow, jointB: .leftWrist),
        JointSegment(jointA: .leftHip, jointB: .leftKnee),
        JointSegment(jointA: .leftKnee, jointB: .leftAnkle),
        // The connected joints that are on the right side of the body.
        JointSegment(jointA: .rightHip, jointB: .rightShoulder),
        JointSegment(jointA: .rightShoulder, jointB: .rightElbow),
        JointSegment(jointA: .rightElbow, jointB: .rightWrist),
        JointSegment(jointA: .rightHip, jointB: .rightKnee),
        JointSegment(jointA: .rightKnee, jointB: .rightAnkle),
        // The connected joints that cross over the body.
        JointSegment(jointA: .leftShoulder, jointB: .rightShoulder),
        JointSegment(jointA: .leftHip, jointB: .rightHip)
    ]
    
    
    
    override func draw(_ rect: CGRect) {
        
        
        if (detections.count < 1) {return}
        if (detections.count % 6 > 0) {return;} // Each detection should have 6 numbers (classId, scrore, xmin, xmax, ymin, ymax)
        
        guard let context = UIGraphicsGetCurrentContext() else {return}
        context.clear(self.frame)
        
        let scaleX = self.frame.size.width / actualCameraFrameWidth
        let scaleY = self.frame.size.height / actualCameraFrameHeight
        // The camera view offset on screen
        let xoff = self.frame.minX
        let yoff = self.frame.minY
        
        let count = detections.count / 6
        
        
        let mainlabel = ""
        
        for i in 0..<count {
            let idx = i * 6
            let classId = Int(detections[idx])
            let score = detections[idx + 1]
            if (score < 0.6) {continue}
            
            let xmin = xoff + CGFloat(detections[idx + 2]) * scaleX
            let xmax = xoff + CGFloat(detections[idx + 3]) * scaleX
            let ymin = yoff + CGFloat(detections[idx + 4]) * scaleY
            let ymax = yoff + CGFloat(detections[idx + 5]) * scaleY
            
            let labelIdx = classId
            let label = labelmap.count > labelIdx ? labelmap[labelIdx] : classId.description
            
            
            // Draw rect
            context.beginPath()
            context.move(to: CGPoint(x: xmin, y: ymin))
            context.addLine(to: CGPoint(x: xmax, y: ymin))
            context.addLine(to: CGPoint(x: xmax, y: ymax))
            context.addLine(to: CGPoint(x: xmin, y: ymax))
            context.addLine(to: CGPoint(x: xmin, y: ymin))
            
            context.setLineWidth(2.0)
            context.setStrokeColor(UIColor.red.cgColor)
            context.drawPath(using: .stroke)
            
          
            if label == "person" {
                let boundingBox = CGRect(x: xmin, y: ymin, width: xmax - xmin, height: ymax - ymin)
                let boundingBoxArea = boundingBox.width * boundingBox.height

                // Check if this box is larger than the current largest
                if boundingBoxArea > largestBoundingBox.width * largestBoundingBox.height {
                    largestBoundingBox = boundingBox
                    largestBoxCenter = CGPoint(x: (xmin + xmax) / 2, y: (ymin + ymax) / 2)
                }
                let middleX = (xmin + xmax) / 2
                let middleY = (ymin + ymax) / 2
                let center = CGPoint(x: middleX, y: middleY)
                
                
                if largestBoundingBox != .zero {
                    // Print information about the largest bounding box
                    print("Largest Bounding Box - Center: \(largestBoxCenter), Size: \(largestBoundingBox.size)")
                    
                    // Use largestBoxCenter for squat calculations
                    if isCurrentlySquatting {
                        plateCenters[squatsDone + 1, default: []].append(largestBoxCenter)
                    }
                } else {
                    print("No valid 'person' bounding box detected.")
                }
            }
            

            
            
            // Draw label
            
            UIGraphicsPushContext(context)
            let font = UIFont.systemFont(ofSize: 30)
            let string = NSAttributedString(string: label, attributes: [NSAttributedString.Key.font: font, NSAttributedString.Key.foregroundColor: UIColor.red])
            string.draw(at: CGPoint(x: xmin, y: ymin))
        }
        if !poses.isEmpty {
            for pose in poses {
                drawPose(pose, in: rect)
            }
        }
        
        
        
        UIGraphicsPopContext()
    }
    
    
    func drawPose(_ pose: Pose, in rect: CGRect) {
        
        
        
        
        guard let context = UIGraphicsGetCurrentContext() else {
            print("Failed to get graphics context")
            return
        }
        
        let scaleX = self.frame.size.width / actualCameraFrameWidth
        let scaleY = self.frame.size.height / actualCameraFrameHeight
        
        context.setStrokeColor(UIColor.systemTeal.cgColor)
        context.setLineWidth(2.0)
        context.setFillColor(UIColor.systemPink.cgColor)
        
        for segment in DetectionsCanvas.jointSegments {
            let jointA = pose[segment.jointA]
            let jointB = pose[segment.jointB]
            
            if jointA.isValid && jointB.isValid {
                let scaledJointAPosition = CGPoint(x: jointA.position.x * scaleX, y: jointA.position.y * scaleY)
                let scaledJointBPosition = CGPoint(x: jointB.position.x * scaleX, y: jointB.position.y * scaleY)
                
                context.move(to: scaledJointAPosition)
                context.addLine(to: scaledJointBPosition)
                context.strokePath()
            }
        }
        
        for joint in pose.joints.values.filter({ $0.isValid }) {
            let scaledJointPosition = CGPoint(x: joint.position.x * scaleX, y: joint.position.y * scaleY)
            let rectangle = CGRect(x: scaledJointPosition.x - 4, y: scaledJointPosition.y - 4, width: 8, height: 8)
            context.addEllipse(in: rectangle)
            context.drawPath(using: .fill)
        }
    }
    
    
    private func drawLine(from jointA: Joint, to jointB: Joint, in context: CGContext) {
        context.move(to: jointA.position)
        context.addLine(to: jointB.position)
        context.strokePath()
    }
    
    private func draw(circle joint: Joint, in context: CGContext) {
        let rectangle = CGRect(x: joint.position.x - 4, y: joint.position.y - 4, width: 8, height: 8)
        context.addEllipse(in: rectangle)
        context.drawPath(using: .fill)
    }
    
    
    func isSquatPose(_ pose: Pose) -> Bool {
        let leftHip = pose[.leftHip]
        let leftKnee = pose[.leftKnee]
        let leftAnkle = pose[.leftAnkle]

        let rightHip = pose[.rightHip]
        let rightKnee = pose[.rightKnee]
        let rightAnkle = pose[.rightAnkle]

        let leftKneeAngle = calculateAngle(hip: leftHip, knee: leftKnee, ankle: leftAnkle)
        let rightKneeAngle = calculateAngle(hip: rightHip, knee: rightKnee, ankle: rightAnkle)

        let averageKneeAngle = (leftKneeAngle + rightKneeAngle) / 2
        
        // Gets knee angle, now we calculate squats done
        
        // Detecting the squatting down phase (knee angle ~90 degrees)
            if abs(averageKneeAngle - 90) <= tolerancevalue {
                if !isCurrentlySquatting {
                    isCurrentlySquatting = true
                    // Start recording the plate centers for the current squat
                    plateCenters[squatsDone + 1] = []
                }
            }
            // Detecting the standing up phase (knee angle ~140 degrees or more)
            else if isCurrentlySquatting && averageKneeAngle >= 140 {
                isCurrentlySquatting = false
                squatsDone += 1  // Increment squat count after standing up
            }
            return false
    }

    
    func calculateAngle(hip: Joint, knee: Joint, ankle: Joint) -> CGFloat {
        let vector1 = CGPoint(x: knee.position.x - hip.position.x, y: knee.position.y - hip.position.y)
        let vector2 = CGPoint(x: ankle.position.x - knee.position.x, y: ankle.position.y - knee.position.y)

        let dotProduct = vector1.x * vector2.x + vector1.y * vector2.y
        let magnitudeVector1 = sqrt(vector1.x * vector1.x + vector1.y * vector1.y)
        let magnitudeVector2 = sqrt(vector2.x * vector2.x + vector2.y * vector2.y)

        let angleRadians = acos(dotProduct / (magnitudeVector1 * magnitudeVector2))
        let angleDegrees = angleRadians * 180 / .pi
        return angleDegrees
    }

    
    func averageXValueOfPoints(in dictionary: [Int: [CGPoint]]) -> CGFloat {
        var totalX: CGFloat = 0
        var totalCount: CGFloat = 0

        for (_, points) in dictionary {
            for point in points {
                totalX += point.x
                totalCount += 1
            }
        }

        return totalCount > 0 ? totalX / totalCount : 0
    }
    
   

}

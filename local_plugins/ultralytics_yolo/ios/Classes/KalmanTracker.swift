// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

import Foundation
import CoreGraphics

/// Kalman Filter based tracker for smooth object tracking.
///
/// This tracker maintains object state between YOLO detections, providing
/// smooth position predictions even when detection is skipped for performance.
///
/// State vector: [x, y, w, h, vx, vy, vw, vh]
/// - x, y: center position
/// - w, h: width and height
/// - vx, vy: velocity components
/// - vw, vh: size change rate
public class KalmanTracker {
    
    // MARK: - Constants
    
    private static let STATE_DIM = 8
    private static let MEASURE_DIM = 4
    
    // Process noise (how much we expect state to change)
    private static let PROCESS_NOISE_POS: Float = 100.0
    private static let PROCESS_NOISE_VEL: Float = 25.0
    
    // Measurement noise (how much we trust detections)
    private static let MEASUREMENT_NOISE: Float = 10.0
    
    // Track management
    private static let MAX_AGE = 30          // Max frames without detection before deletion
    private static let MIN_HITS = 1          // Min detections to confirm track (1 = show immediately)
    private static let IOU_THRESHOLD: Float = 0.15  // Lower for easier matching
    
    // MARK: - Properties
    
    /// Track identifier
    private(set) var trackId: Int
    
    /// State vector [x, y, w, h, vx, vy, vw, vh]
    private var state: [Float]
    
    /// Error covariance matrix
    private var covariance: [[Float]]
    
    /// Total frames since creation
    private(set) var age: Int = 0
    
    /// Frames since last detection match
    private(set) var timeSinceUpdate: Int = 0
    
    /// Number of successful matches
    private(set) var hitCount: Int = 0
    
    /// Track is confirmed after MIN_HITS
    private(set) var isConfirmed: Bool = false
    
    /// Class index of detected object
    var classIndex: Int = 0
    
    /// Class name of detected object
    var className: String = "ball"
    
    /// Detection confidence
    var confidence: Float = 0.0
    
    // MARK: - Initialization
    
    /// Initialize tracker with first detection
    /// - Parameters:
    ///   - detection: The initial detection box
    ///   - id: Unique track identifier
    init(detection: Box, id: Int) {
        self.trackId = id
        self.classIndex = detection.index
        self.className = detection.cls
        self.confidence = detection.conf
        
        // Initialize state from detection (center x, y, width, height)
        let cx = Float(detection.xywh.midX)
        let cy = Float(detection.xywh.midY)
        let w = Float(detection.xywh.width)
        let h = Float(detection.xywh.height)
        
        self.state = [
            cx,   // x
            cy,   // y
            w,    // width
            h,    // height
            0.0,  // vx (unknown initially)
            0.0,  // vy (unknown initially)
            0.0,  // vw
            0.0   // vh
        ]
        
        // Initialize covariance matrix (diagonal with high uncertainty for velocities)
        self.covariance = Array(repeating: Array(repeating: Float(0), count: KalmanTracker.STATE_DIM), 
                                count: KalmanTracker.STATE_DIM)
        
        // Position uncertainty
        covariance[0][0] = 10.0
        covariance[1][1] = 10.0
        covariance[2][2] = 10.0
        covariance[3][3] = 10.0
        
        // High velocity uncertainty (we don't know initial velocity)
        covariance[4][4] = 1000.0
        covariance[5][5] = 1000.0
        covariance[6][6] = 1000.0
        covariance[7][7] = 1000.0
        
        self.hitCount = 1
        self.age = 1
        self.timeSinceUpdate = 0
        
        print("🎯 Track \(trackId) created at (\(cx), \(cy)) size \(w)x\(h)")
    }
    
    // MARK: - Prediction
    
    /// Predict next state (call every frame, even without detection)
    /// - Returns: The predicted bounding box
    @discardableResult
    func predict() -> CGRect {
        // State transition: x_new = x + vx, y_new = y + vy, etc.
        // This is a simple constant velocity model
        
        // Update position based on velocity
        state[0] += state[4]  // x += vx
        state[1] += state[5]  // y += vy
        state[2] += state[6]  // w += vw
        state[3] += state[7]  // h += vh
        
        // Ensure size stays positive
        state[2] = max(10.0, state[2])
        state[3] = max(10.0, state[3])
        
        // Update covariance: P = F*P*F' + Q
        // Simplified: just add process noise to diagonal
        for i in 0..<KalmanTracker.MEASURE_DIM {
            covariance[i][i] += KalmanTracker.PROCESS_NOISE_POS
        }
        for i in KalmanTracker.MEASURE_DIM..<KalmanTracker.STATE_DIM {
            covariance[i][i] += KalmanTracker.PROCESS_NOISE_VEL
        }
        
        age += 1
        timeSinceUpdate += 1
        
        return getBoundingBox()
    }
    
    // MARK: - Update
    
    /// Update state with new detection measurement
    /// - Parameter detection: The matched detection
    func update(detection: Box) {
        // Get measurement from detection
        let cx = Float(detection.xywh.midX)
        let cy = Float(detection.xywh.midY)
        let w = Float(detection.xywh.width)
        let h = Float(detection.xywh.height)
        
        let measurement: [Float] = [cx, cy, w, h]
        
        // Calculate innovation (measurement residual)
        var innovation = [Float](repeating: 0, count: KalmanTracker.MEASURE_DIM)
        for i in 0..<KalmanTracker.MEASURE_DIM {
            innovation[i] = measurement[i] - state[i]
        }
        
        // Simplified Kalman gain calculation
        var kalmanGain = [Float](repeating: 0, count: KalmanTracker.STATE_DIM)
        for i in 0..<KalmanTracker.STATE_DIM {
            let pHt = i < KalmanTracker.MEASURE_DIM ? covariance[i][i] : covariance[i][i % KalmanTracker.MEASURE_DIM]
            let s = covariance[i % KalmanTracker.MEASURE_DIM][i % KalmanTracker.MEASURE_DIM] + KalmanTracker.MEASUREMENT_NOISE
            kalmanGain[i] = pHt / s
        }
        
        // Update state: x = x + K * innovation
        for i in 0..<KalmanTracker.STATE_DIM {
            let innovationIdx = i % KalmanTracker.MEASURE_DIM
            state[i] += kalmanGain[i] * innovation[innovationIdx]
        }
        
        // Update velocity estimates based on position change
        if timeSinceUpdate <= 2 {
            let alpha: Float = 0.3  // Smoothing factor
            state[4] = (1 - alpha) * state[4] + alpha * innovation[0]
            state[5] = (1 - alpha) * state[5] + alpha * innovation[1]
        }
        
        // Update covariance: P = (I - K*H) * P
        for i in 0..<KalmanTracker.STATE_DIM {
            for j in 0..<KalmanTracker.STATE_DIM {
                if i < KalmanTracker.MEASURE_DIM && j < KalmanTracker.MEASURE_DIM {
                    let kh: Float = (i == j) ? kalmanGain[i] : 0.0
                    covariance[i][j] *= (1.0 - kh)
                }
            }
        }
        
        // Update metadata
        confidence = detection.conf
        hitCount += 1
        timeSinceUpdate = 0
        
        if hitCount >= KalmanTracker.MIN_HITS {
            isConfirmed = true
        }
        
        print("🎯 Track \(trackId) updated: pos=(\(state[0]), \(state[1])) vel=(\(state[4]), \(state[5])) conf=\(confidence)")
    }
    
    // MARK: - Accessors
    
    /// Get current bounding box (in pixel coordinates)
    func getBoundingBox() -> CGRect {
        let cx = CGFloat(state[0])
        let cy = CGFloat(state[1])
        let w = CGFloat(state[2])
        let h = CGFloat(state[3])
        
        return CGRect(
            x: cx - w / 2.0,
            y: cy - h / 2.0,
            width: w,
            height: h
        )
    }
    
    /// Get current state as a Box object for rendering
    /// - Parameters:
    ///   - origWidth: Original frame width
    ///   - origHeight: Original frame height
    /// - Returns: A Box object with current tracked state
    func toBox(origWidth: Int, origHeight: Int) -> Box {
        let bbox = getBoundingBox()
        
        // Create normalized coordinates
        let normRect = CGRect(
            x: bbox.minX / CGFloat(origWidth),
            y: bbox.minY / CGFloat(origHeight),
            width: bbox.width / CGFloat(origWidth),
            height: bbox.height / CGFloat(origHeight)
        )
        
        return Box(
            index: classIndex,
            cls: className,
            conf: confidence,
            xywh: bbox,
            xywhn: normRect
        )
    }
    
    /// Calculate IoU (Intersection over Union) with a detection
    /// - Parameter detection: The detection to compare with
    /// - Returns: IoU value between 0 and 1
    func iou(detection: Box) -> Float {
        let boxA = getBoundingBox()
        let boxB = detection.xywh
        
        let xA = max(boxA.minX, boxB.minX)
        let yA = max(boxA.minY, boxB.minY)
        let xB = min(boxA.maxX, boxB.maxX)
        let yB = min(boxA.maxY, boxB.maxY)
        
        let interWidth = max(0, xB - xA)
        let interHeight = max(0, yB - yA)
        let interArea = interWidth * interHeight
        
        let boxAArea = boxA.width * boxA.height
        let boxBArea = boxB.width * boxB.height
        
        let unionArea = boxAArea + boxBArea - interArea
        
        return unionArea > 0 ? Float(interArea / unionArea) : 0.0
    }
    
    /// Check if track should be deleted
    var isStale: Bool {
        return timeSinceUpdate > KalmanTracker.MAX_AGE
    }
}

// MARK: - KalmanTrackerManager

/// Multi-object tracker manager using Kalman filters
public class KalmanTrackerManager {
    
    private static let IOU_THRESHOLD: Float = 0.1  // Lower threshold for easier matching
    
    /// Active trackers
    private var trackers: [KalmanTracker] = []
    
    /// Next track ID to assign
    private var nextTrackId: Int = 1
    
    /// Frame dimensions
    private var frameWidth: Int = 1
    private var frameHeight: Int = 1
    
    public init() {}
    
    /// Set frame dimensions for coordinate normalization
    /// - Parameters:
    ///   - width: Frame width in pixels
    ///   - height: Frame height in pixels
    public func setFrameSize(width: Int, height: Int) {
        frameWidth = width
        frameHeight = height
    }
    
    /// Predict all tracks (call every frame)
    /// - Returns: Boxes from Kalman prediction
    public func predict() -> [Box] {
        var predictedBoxes: [Box] = []
        
        // Remove stale tracks
        trackers.removeAll { $0.isStale }
        
        // Predict each track
        for tracker in trackers {
            tracker.predict()
            if tracker.isConfirmed {
                predictedBoxes.append(tracker.toBox(origWidth: frameWidth, origHeight: frameHeight))
            }
        }
        
        print("🔮 Predicted \(predictedBoxes.count) tracks")
        return predictedBoxes
    }
    
    /// Update tracks with new detections
    /// Uses greedy matching by IoU (simplified Hungarian algorithm)
    /// - Parameter detections: New detections from YOLO
    /// - Returns: Updated tracked boxes
    public func update(detections: [Box]) -> [Box] {
        print("🔄 Updating with \(detections.count) detections, \(trackers.count) existing tracks")
        
        if detections.isEmpty {
            // No detections - just predict
            return predict()
        }
        
        if trackers.isEmpty {
            // No existing tracks - create new ones for all detections
            for detection in detections {
                trackers.append(KalmanTracker(detection: detection, id: nextTrackId))
                nextTrackId += 1
            }
            return detections
        }
        
        // Calculate IoU matrix between tracks and detections
        var iouMatrix = [[Float]](repeating: [Float](repeating: 0, count: detections.count), 
                                  count: trackers.count)
        for i in 0..<trackers.count {
            for j in 0..<detections.count {
                iouMatrix[i][j] = trackers[i].iou(detection: detections[j])
            }
        }
        
        // Greedy matching
        var matchedTracks = Set<Int>()
        var matchedDetections = Set<Int>()
        
        // Build potential matches list
        struct Match: Comparable {
            let trackIdx: Int
            let detIdx: Int
            let iou: Float
            
            static func < (lhs: Match, rhs: Match) -> Bool {
                return lhs.iou > rhs.iou  // Sort descending
            }
        }
        
        var potentialMatches: [Match] = []
        for i in 0..<trackers.count {
            for j in 0..<detections.count {
                if iouMatrix[i][j] > KalmanTrackerManager.IOU_THRESHOLD {
                    potentialMatches.append(Match(trackIdx: i, detIdx: j, iou: iouMatrix[i][j]))
                }
            }
        }
        
        // Sort by IoU descending
        potentialMatches.sort()
        
        // Match greedily
        for match in potentialMatches {
            if !matchedTracks.contains(match.trackIdx) && !matchedDetections.contains(match.detIdx) {
                // Update tracker with matched detection
                trackers[match.trackIdx].update(detection: detections[match.detIdx])
                matchedTracks.insert(match.trackIdx)
                matchedDetections.insert(match.detIdx)
                print("✅ Matched track \(trackers[match.trackIdx].trackId) to detection \(match.detIdx) (IoU=\(match.iou))")
            }
        }
        
        // Create new tracks for unmatched detections
        for j in 0..<detections.count {
            if !matchedDetections.contains(j) {
                trackers.append(KalmanTracker(detection: detections[j], id: nextTrackId))
                print("➕ Created new track \(nextTrackId) for unmatched detection")
                nextTrackId += 1
            }
        }
        
        // Predict unmatched tracks (they didn't get a detection this frame)
        for i in 0..<trackers.count {
            if !matchedTracks.contains(i) {
                trackers[i].predict()
            }
        }
        
        // Remove stale tracks
        trackers.removeAll { $0.isStale }
        
        // Return confirmed track boxes
        var resultBoxes: [Box] = []
        for tracker in trackers {
            if tracker.isConfirmed {
                resultBoxes.append(tracker.toBox(origWidth: frameWidth, origHeight: frameHeight))
            }
        }
        
        print("📦 Returning \(resultBoxes.count) tracked boxes")
        return resultBoxes
    }
    
    /// Get current tracked boxes (call this for frames without detection)
    /// - Returns: Current tracked boxes
    public func getTrackedBoxes() -> [Box] {
        var boxes: [Box] = []
        for tracker in trackers {
            if tracker.isConfirmed {
                boxes.append(tracker.toBox(origWidth: frameWidth, origHeight: frameHeight))
            }
        }
        return boxes
    }
    
    /// Clear all tracks
    public func clear() {
        trackers.removeAll()
        nextTrackId = 1
    }
    
    /// Get number of active tracks
    public var trackCount: Int {
        return trackers.filter { $0.isConfirmed }.count
    }
}


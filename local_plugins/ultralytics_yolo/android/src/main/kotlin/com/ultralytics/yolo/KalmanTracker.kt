// Ultralytics 🚀 AGPL-3.0 License - https://ultralytics.com/license

package com.ultralytics.yolo

import android.graphics.RectF
import android.util.Log
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

/**
 * Kalman Filter based tracker for smooth object tracking.
 * 
 * This tracker maintains object state between YOLO detections, providing
 * smooth position predictions even when detection is skipped for performance.
 * 
 * State vector: [x, y, w, h, vx, vy, vw, vh]
 * - x, y: center position
 * - w, h: width and height
 * - vx, vy: velocity components
 * - vw, vh: size change rate
 */
class KalmanTracker {
    
    companion object {
        private const val TAG = "KalmanTracker"
        
        // Number of state variables: x, y, w, h, vx, vy, vw, vh
        private const val STATE_DIM = 8
        // Number of measurement variables: x, y, w, h
        private const val MEASURE_DIM = 4
        
        // Process noise (how much we expect state to change)
        private const val PROCESS_NOISE_POS = 100f      // Position uncertainty
        private const val PROCESS_NOISE_VEL = 25f       // Velocity uncertainty
        
        // Measurement noise (how much we trust detections)
        private const val MEASUREMENT_NOISE = 10f
        
        // Track management
        private const val MAX_AGE = 30           // Max frames without detection before deletion
        private const val MIN_HITS = 1           // Min detections to confirm track (1 = show immediately)
        private const val IOU_THRESHOLD = 0.15f  // IoU threshold for matching (lower = more lenient)
    }
    
    // Track state
    private var trackId: Int = 0
    private var state = FloatArray(STATE_DIM)        // [x, y, w, h, vx, vy, vw, vh]
    private var covariance = Array(STATE_DIM) { FloatArray(STATE_DIM) }  // Error covariance
    
    // Track lifecycle
    private var age: Int = 0                          // Total frames since creation
    private var timeSinceUpdate: Int = 0              // Frames since last detection match
    private var hitCount: Int = 0                     // Number of successful matches
    private var isConfirmed: Boolean = false          // Track is confirmed after MIN_HITS
    
    // Additional info
    var classIndex: Int = 0
    var className: String = "ball"
    var confidence: Float = 0f
    
    /**
     * Initialize tracker with first detection
     */
    constructor(detection: Box, id: Int) {
        trackId = id
        classIndex = detection.index
        className = detection.cls
        confidence = detection.conf
        
        // Initialize state from detection (center x, y, width, height)
        val cx = (detection.xywh.left + detection.xywh.right) / 2f
        val cy = (detection.xywh.top + detection.xywh.bottom) / 2f
        val w = detection.xywh.width()
        val h = detection.xywh.height()
        
        state[0] = cx    // x
        state[1] = cy    // y
        state[2] = w     // width
        state[3] = h     // height
        state[4] = 0f    // vx (unknown initially)
        state[5] = 0f    // vy (unknown initially)
        state[6] = 0f    // vw
        state[7] = 0f    // vh
        
        // Initialize covariance matrix (diagonal with high uncertainty for velocities)
        for (i in 0 until STATE_DIM) {
            for (j in 0 until STATE_DIM) {
                covariance[i][j] = 0f
            }
        }
        // Position uncertainty
        covariance[0][0] = 10f
        covariance[1][1] = 10f
        covariance[2][2] = 10f
        covariance[3][3] = 10f
        // High velocity uncertainty (we don't know initial velocity)
        covariance[4][4] = 1000f
        covariance[5][5] = 1000f
        covariance[6][6] = 1000f
        covariance[7][7] = 1000f
        
        hitCount = 1
        age = 1
        timeSinceUpdate = 0
        
        Log.d(TAG, "Track $trackId created at ($cx, $cy) size ${w}x${h}")
    }
    
    /**
     * Predict next state (call every frame, even without detection)
     * Returns the predicted bounding box
     */
    fun predict(): RectF {
        // State transition: x_new = x + vx, y_new = y + vy, etc.
        // This is a simple constant velocity model
        
        // Update position based on velocity
        state[0] += state[4]  // x += vx
        state[1] += state[5]  // y += vy
        state[2] += state[6]  // w += vw
        state[3] += state[7]  // h += vh
        
        // Ensure size stays positive
        state[2] = max(10f, state[2])
        state[3] = max(10f, state[3])
        
        // Update covariance: P = F*P*F' + Q
        // Simplified: just add process noise to diagonal
        for (i in 0 until MEASURE_DIM) {
            covariance[i][i] += PROCESS_NOISE_POS
        }
        for (i in MEASURE_DIM until STATE_DIM) {
            covariance[i][i] += PROCESS_NOISE_VEL
        }
        
        age++
        timeSinceUpdate++
        
        return getBoundingBox()
    }
    
    /**
     * Update state with new detection measurement
     */
    fun update(detection: Box) {
        // Get measurement from detection
        val cx = (detection.xywh.left + detection.xywh.right) / 2f
        val cy = (detection.xywh.top + detection.xywh.bottom) / 2f
        val w = detection.xywh.width()
        val h = detection.xywh.height()
        
        val measurement = floatArrayOf(cx, cy, w, h)
        
        // Calculate innovation (measurement residual)
        val innovation = FloatArray(MEASURE_DIM)
        for (i in 0 until MEASURE_DIM) {
            innovation[i] = measurement[i] - state[i]
        }
        
        // Simplified Kalman gain calculation
        // K = P * H' * (H * P * H' + R)^-1
        // For our simple case with H = [I 0], this simplifies significantly
        
        val kalmanGain = FloatArray(STATE_DIM)
        for (i in 0 until STATE_DIM) {
            val pHt = if (i < MEASURE_DIM) covariance[i][i] else covariance[i][i % MEASURE_DIM]
            val s = covariance[i % MEASURE_DIM][i % MEASURE_DIM] + MEASUREMENT_NOISE
            kalmanGain[i] = pHt / s
        }
        
        // Update state: x = x + K * innovation
        for (i in 0 until STATE_DIM) {
            val innovationIdx = i % MEASURE_DIM
            state[i] += kalmanGain[i] * innovation[innovationIdx]
        }
        
        // Update velocity estimates based on position change
        // This helps the filter learn the object's motion
        if (timeSinceUpdate <= 2) {
            // Smooth velocity update
            val alpha = 0.3f  // Smoothing factor
            state[4] = (1 - alpha) * state[4] + alpha * innovation[0]
            state[5] = (1 - alpha) * state[5] + alpha * innovation[1]
        }
        
        // Update covariance: P = (I - K*H) * P
        for (i in 0 until STATE_DIM) {
            for (j in 0 until STATE_DIM) {
                if (i < MEASURE_DIM && j < MEASURE_DIM) {
                    val kh = if (i == j) kalmanGain[i] else 0f
                    covariance[i][j] *= (1f - kh)
                }
            }
        }
        
        // Update metadata
        confidence = detection.conf
        hitCount++
        timeSinceUpdate = 0
        
        if (hitCount >= MIN_HITS) {
            isConfirmed = true
        }
        
        Log.d(TAG, "Track $trackId updated: pos=(${state[0]}, ${state[1]}) vel=(${state[4]}, ${state[5]}) conf=$confidence")
    }
    
    /**
     * Get current bounding box (in pixel coordinates)
     */
    fun getBoundingBox(): RectF {
        val cx = state[0]
        val cy = state[1]
        val w = state[2]
        val h = state[3]
        
        return RectF(
            cx - w / 2f,
            cy - h / 2f,
            cx + w / 2f,
            cy + h / 2f
        )
    }
    
    /**
     * Get current state as a Box object for rendering
     */
    fun toBox(origWidth: Int, origHeight: Int): Box {
        val bbox = getBoundingBox()
        
        // Create normalized coordinates
        val normRect = RectF(
            bbox.left / origWidth,
            bbox.top / origHeight,
            bbox.right / origWidth,
            bbox.bottom / origHeight
        )
        
        return Box(
            index = classIndex,
            cls = className,
            conf = confidence,
            xywh = bbox,
            xywhn = normRect
        )
    }
    
    /**
     * Calculate IoU (Intersection over Union) with a detection
     */
    fun iou(detection: Box): Float {
        val boxA = getBoundingBox()
        val boxB = detection.xywh
        
        val xA = max(boxA.left, boxB.left)
        val yA = max(boxA.top, boxB.top)
        val xB = min(boxA.right, boxB.right)
        val yB = min(boxA.bottom, boxB.bottom)
        
        val interWidth = max(0f, xB - xA)
        val interHeight = max(0f, yB - yA)
        val interArea = interWidth * interHeight
        
        val boxAArea = boxA.width() * boxA.height()
        val boxBArea = boxB.width() * boxB.height()
        
        val unionArea = boxAArea + boxBArea - interArea
        
        return if (unionArea > 0) interArea / unionArea else 0f
    }
    
    /**
     * Check if track should be deleted
     */
    fun isStale(): Boolean {
        return timeSinceUpdate > MAX_AGE
    }
    
    /**
     * Check if track is confirmed (has enough hits)
     */
    fun isTrackConfirmed(): Boolean = isConfirmed
    
    /**
     * Get track ID
     */
    fun getId(): Int = trackId
    
    /**
     * Get time since last update
     */
    fun getTimeSinceUpdate(): Int = timeSinceUpdate
}

/**
 * Multi-object tracker manager using Kalman filters
 */
class KalmanTrackerManager {
    
    companion object {
        private const val TAG = "KalmanTrackerManager"
        private const val IOU_THRESHOLD = 0.1f  // Lower threshold for easier matching
    }
    
    private val trackers = mutableListOf<KalmanTracker>()
    private var nextTrackId = 1
    private var frameWidth: Int = 1
    private var frameHeight: Int = 1
    
    // Last known result (for frames without detection)
    private var lastResult: YOLOResult? = null
    
    /**
     * Set frame dimensions for coordinate normalization
     */
    fun setFrameSize(width: Int, height: Int) {
        frameWidth = width
        frameHeight = height
    }
    
    /**
     * Predict all tracks (call every frame)
     * Returns boxes from Kalman prediction
     */
    fun predict(): List<Box> {
        val predictedBoxes = mutableListOf<Box>()
        
        // Remove stale tracks
        trackers.removeAll { it.isStale() }
        
        // Predict each track
        for (tracker in trackers) {
            tracker.predict()
            if (tracker.isTrackConfirmed()) {
                predictedBoxes.add(tracker.toBox(frameWidth, frameHeight))
            }
        }
        
        Log.d(TAG, "Predicted ${predictedBoxes.size} tracks")
        return predictedBoxes
    }
    
    /**
     * Update tracks with new detections
     * Uses Hungarian algorithm approximation (greedy matching by IoU)
     */
    fun update(detections: List<Box>): List<Box> {
        Log.d(TAG, "Updating with ${detections.size} detections, ${trackers.size} existing tracks")
        
        if (detections.isEmpty()) {
            // No detections - just predict
            return predict()
        }
        
        if (trackers.isEmpty()) {
            // No existing tracks - create new ones for all detections
            for (detection in detections) {
                trackers.add(KalmanTracker(detection, nextTrackId++))
            }
            return detections
        }
        
        // Calculate IoU matrix between tracks and detections
        val iouMatrix = Array(trackers.size) { FloatArray(detections.size) }
        for (i in trackers.indices) {
            for (j in detections.indices) {
                iouMatrix[i][j] = trackers[i].iou(detections[j])
            }
        }
        
        // Greedy matching (simplified Hungarian)
        val matchedTracks = mutableSetOf<Int>()
        val matchedDetections = mutableSetOf<Int>()
        
        // Sort by IoU and match greedily
        data class Match(val trackIdx: Int, val detIdx: Int, val iou: Float)
        val potentialMatches = mutableListOf<Match>()
        
        for (i in trackers.indices) {
            for (j in detections.indices) {
                if (iouMatrix[i][j] > IOU_THRESHOLD) {
                    potentialMatches.add(Match(i, j, iouMatrix[i][j]))
                }
            }
        }
        
        // Sort by IoU descending
        potentialMatches.sortByDescending { it.iou }
        
        // Match greedily
        for (match in potentialMatches) {
            if (match.trackIdx !in matchedTracks && match.detIdx !in matchedDetections) {
                // Update tracker with matched detection
                trackers[match.trackIdx].update(detections[match.detIdx])
                matchedTracks.add(match.trackIdx)
                matchedDetections.add(match.detIdx)
                Log.d(TAG, "Matched track ${trackers[match.trackIdx].getId()} to detection ${match.detIdx} (IoU=${match.iou})")
            }
        }
        
        // Create new tracks for unmatched detections
        for (j in detections.indices) {
            if (j !in matchedDetections) {
                trackers.add(KalmanTracker(detections[j], nextTrackId++))
                Log.d(TAG, "Created new track ${nextTrackId - 1} for unmatched detection")
            }
        }
        
        // Predict unmatched tracks (they didn't get a detection this frame)
        for (i in trackers.indices) {
            if (i !in matchedTracks) {
                trackers[i].predict()
            }
        }
        
        // Remove stale tracks
        trackers.removeAll { it.isStale() }
        
        // Return confirmed track boxes
        val resultBoxes = mutableListOf<Box>()
        for (tracker in trackers) {
            if (tracker.isTrackConfirmed()) {
                resultBoxes.add(tracker.toBox(frameWidth, frameHeight))
            }
        }
        
        Log.d(TAG, "Returning ${resultBoxes.size} tracked boxes")
        return resultBoxes
    }
    
    /**
     * Get current tracked boxes (call this for frames without detection)
     */
    fun getTrackedBoxes(): List<Box> {
        val boxes = mutableListOf<Box>()
        for (tracker in trackers) {
            if (tracker.isTrackConfirmed()) {
                boxes.add(tracker.toBox(frameWidth, frameHeight))
            }
        }
        return boxes
    }
    
    /**
     * Clear all tracks
     */
    fun clear() {
        trackers.clear()
        nextTrackId = 1
    }
    
    /**
     * Get number of active tracks
     */
    fun getTrackCount(): Int = trackers.count { it.isTrackConfirmed() }
}


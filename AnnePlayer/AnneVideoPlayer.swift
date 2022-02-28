//
//  AnneVideoPlayer.swift
//  FoxSchool
//
//  Created by Littlefox iOS Developer on 2022/01/19.
//

import UIKit
import AVKit

protocol AnneVideoPlayerViewDelegate: AnyObject {
    func anneVideoPlayerCallback(loadStart playerView: AnneVideoPlayerView)
    func anneVideoPlayerCallback(loadFinshied playerView: AnneVideoPlayerView, isLoadSuccess: Bool, error: Error?)
    func anneVideoPlayerCallback(playerView: AnneVideoPlayerView, statusPlayer: AVPlayer.Status, error: Error?)
    func anneVideoPlayerCallback(playerView: AnneVideoPlayerView, statusItemPlayer: AVPlayerItem.Status, error: Error?)
    func anneVideoPlayerCallback(playerView: AnneVideoPlayerView, loadedTimeRanges: [CMTimeRange])
    func anneVideoPlayerCallback(playerView: AnneVideoPlayerView, duration: Double)
    func anneVideoPlayerCallback(playerView: AnneVideoPlayerView, currentTime: Double)
    func anneVideoPlayerCallback(playerView: AnneVideoPlayerView, rate: Float)
    func anneVideoPlayerCallback(playerView: AnneVideoPlayerView, isLikelyKeepUp: Bool)
    func anneVideoPlayerCallback(playerFinished playerView: AnneVideoPlayerView)
}

enum AnneVideoPlayerViewFillMode {
    case resizeAspect
    case resizeAspectFill
    case resize
    
    init?(videoGravity: AVLayerVideoGravity){
        switch videoGravity {
        case .resizeAspect:
            self = .resizeAspect
        case .resizeAspectFill:
            self = .resizeAspectFill
        case .resize:
            self = .resize
        default:
            return nil
        }
    }
    
    var AVLayerVideoGravity: AVLayerVideoGravity {
        get {
            switch self {
            case .resizeAspect:
                return .resizeAspect
            case .resizeAspectFill:
                return .resizeAspectFill
            case .resize:
                return .resize
            }
        }
    }
}

class AnneVideoPlayerView: UIView {
    
    deinit {
        print("deinit \(self)")
        removePlayer()
    }
    
    
    private var statusContext = true
    private var statusItemContext = true
    private var statusKeepUpContext = true
    private var loadedContext = true
    private var durationContext = true
    private var currentTimeContext = true
    private var rateContext = true
    private var playerItemContext = true
    
    private let tPlayerTracksKey = "tracks"
    private let tPlayerPlayableKey = "playable"
    private let tPlayerDurationKey = "duration"
    private let tPlayerRateKey = "rate"
    private let tCurrentItemKey = "currentItem"
    
    private let tPlayerStatusKey = "status"
    private let tPlayerEmptyBufferKey = "playbackBufferEmpty"
    private let tPlaybackBufferFullKey = "playbackBufferFull"
    private let tPlayerKeepUpKey = "playbackLikelyToKeepUp"
    private let tLoadedTimeRangesKey = "loadedTimeRanges"


    override class var layerClass: Swift.AnyClass {
        get {
            return AVPlayerLayer.self
        }
    }
    
    private var playerLayer: AVPlayerLayer {
        get {
            return self.layer as! AVPlayerLayer
        }
    }
    
    private var player: AVPlayer? {
        get {
            return playerLayer.player
        }
        
        set {
            playerLayer.player = newValue
        }
    }
    
    var keepingPlayer: AVPlayer = AVPlayer()
    
    private var isCalcurateCurrentTime: Bool = true
    private var timeObserverToken: AnyObject?
    private weak var lastPlayerTimeObserve: AVPlayer?
    private var pictureInPictureController: AVPictureInPictureController?
    
    weak var delegate: AnneVideoPlayerViewDelegate?
    
    var isCanBackgroundPlay: Bool = true
    
    var isReleasePlayer: Bool{
        get{
            if let _ = self.playerLayer.player{
                return false
            }else{
                return true
            }
        }
        
        set{
            
            if newValue, self.isCanBackgroundPlay{
                self.playerLayer.player = nil
            }else{
                self.playerLayer.player = self.keepingPlayer
                self.play()
            }
        }
    }
    
    
    var isCanPIP: Bool = false{
        didSet{
            if isCanPIP{
                if AVPictureInPictureController.isPictureInPictureSupported(){
                    self.pictureInPictureController = AVPictureInPictureController(playerLayer: self.playerLayer)
                }
            }else{
                self.pictureInPictureController = nil
            }
        }
    }

    var fillMode: AnneVideoPlayerViewFillMode! {
        didSet {
            playerLayer.videoGravity = fillMode.AVLayerVideoGravity
        }
    }
    
    var maximumDuration: TimeInterval? {
        get {
            if let playerItem = self.player?.currentItem {
                return CMTimeGetSeconds(playerItem.duration)
            }
            return nil
        }
    }
    
    var currentTime: Double {
        get {
            guard let player = player else {
                return 0
            }
            return CMTimeGetSeconds(player.currentTime())
        }
        set {
            guard let timescale = player?.currentItem?.duration.timescale else {
                return
            }
            let newTime = CMTimeMakeWithSeconds(newValue, preferredTimescale: timescale)
            player!.seek(to: newTime,toleranceBefore: CMTime.zero,toleranceAfter: CMTime.zero)
        }
    }
    
    var interval = CMTimeMake(value: 1, timescale: 60) {
        didSet {
            if rate != 0 {
                addCurrentTimeObserver()
            }
        }
    }
    
    var rate: Float {
        get {
            guard let player = player else {
                return 0
            }
            return player.rate
        }
        set {
            if newValue == 0 {
                removeCurrentTimeObserver()
            } else if rate == 0 && newValue != 0 {
                addCurrentTimeObserver()
                self.isCalcurateCurrentTime = true
            }
            
            player?.rate = newValue
        }
    }
    
    var availableDuration: CMTimeRange {
        let range = self.player?.currentItem?.loadedTimeRanges.first
        if let range = range {
            return range.timeRangeValue
        }
        return CMTimeRange.zero
    }
    
    var url: URL? {
        didSet {
            guard let url = url else {
                return
            }
            self.preparePlayer(url: url)
        }
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidPlayToEndTime(aNotification:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
    }
    
    init(){
        super.init(frame: .zero)
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidPlayToEndTime(aNotification:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        NotificationCenter.default.addObserver(self, selector: #selector(playerItemDidPlayToEndTime(aNotification:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: nil)
    }
    
    private func preparePlayer(url: URL) {
        
        self.delegate?.anneVideoPlayerCallback(loadStart: self)
        

        let asset = AVURLAsset(url: url)
        let requestKeys : [String] = [tPlayerTracksKey,tPlayerPlayableKey,tPlayerDurationKey]
        asset.loadValuesAsynchronously(forKeys: requestKeys) {
            DispatchQueue.main.async {
                for key in requestKeys{
                    var error: NSError?
                    let status = asset.statusOfValue(forKey: key, error: &error)
                    if status == .failed {
                        self.delegate?.anneVideoPlayerCallback(loadFinshied: self, isLoadSuccess: false, error: error)
                        return
                    }
                    
                    if asset.isPlayable == false{
                        self.delegate?.anneVideoPlayerCallback(loadFinshied: self, isLoadSuccess: false, error: error)
                        return
                    }
                }
                
                self.keepingPlayer.replaceCurrentItem(with: AVPlayerItem(asset: asset))
                if self.player == nil{
                    self.player = self.keepingPlayer
                }
                self.player?.currentItem?.audioTimePitchAlgorithm = .timeDomain
                self.addObserversPlayer(avPlayer: self.player!)
                self.addObserversVideoItem(playerItem: self.player!.currentItem!)
                self.delegate?.anneVideoPlayerCallback(loadFinshied: self, isLoadSuccess: true, error: nil)
            }
        }
    }
    
    private func enableSoundSesstion(){
        do{
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
        }catch{
            
        }
    }
    
    private func addObserversPlayer(avPlayer: AVPlayer) {
        avPlayer.addObserver(self, forKeyPath: tPlayerStatusKey, options: [.new], context: &statusContext)
        avPlayer.addObserver(self, forKeyPath: tPlayerRateKey, options: [.new], context: &rateContext)
        avPlayer.addObserver(self, forKeyPath: tCurrentItemKey, options: [.old,.new], context: &playerItemContext)
    }
    
    private func removeObserversPlayer(avPlayer: AVPlayer) {
        
        avPlayer.removeObserver(self, forKeyPath: tPlayerStatusKey, context: &statusContext)
        avPlayer.removeObserver(self, forKeyPath: tPlayerRateKey, context: &rateContext)
        avPlayer.removeObserver(self, forKeyPath: tCurrentItemKey, context: &playerItemContext)
        
        if let timeObserverToken = timeObserverToken {
            avPlayer.removeTimeObserver(timeObserverToken)
        }
    }
    private func addObserversVideoItem(playerItem: AVPlayerItem) {
        playerItem.addObserver(self, forKeyPath: tLoadedTimeRangesKey, options: [], context: &loadedContext)
        playerItem.addObserver(self, forKeyPath: tPlayerDurationKey, options: [], context: &durationContext)
        playerItem.addObserver(self, forKeyPath: tPlayerStatusKey, options: [], context: &statusItemContext)
        playerItem.addObserver(self, forKeyPath: tPlayerKeepUpKey, options: [.new,.old], context: &statusKeepUpContext)
    }
    private func removeObserversVideoItem(playerItem: AVPlayerItem) {
        
        playerItem.removeObserver(self, forKeyPath: tLoadedTimeRangesKey, context: &loadedContext)
        playerItem.removeObserver(self, forKeyPath: tPlayerDurationKey, context: &durationContext)
        playerItem.removeObserver(self, forKeyPath: tPlayerStatusKey, context: &statusItemContext)
        playerItem.removeObserver(self, forKeyPath: tPlayerKeepUpKey, context: &statusKeepUpContext)
    }
    
    private func removeCurrentTimeObserver() {
        
        if let timeObserverToken = self.timeObserverToken {
            lastPlayerTimeObserve?.removeTimeObserver(timeObserverToken)
        }
        timeObserverToken = nil
    
    }
    
    private func addCurrentTimeObserver() {
        removeCurrentTimeObserver()
        lastPlayerTimeObserve = player
        self.timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: DispatchQueue.main) { [weak self] time-> Void in
            if let mySelf = self {
                if mySelf.isCalcurateCurrentTime{
                    self?.delegate?.anneVideoPlayerCallback(playerView: mySelf, currentTime: mySelf.currentTime)
                }
            }
            } as AnyObject?
    }
    
    @objc private func playerItemDidPlayToEndTime(aNotification: NSNotification) {
        self.delegate?.anneVideoPlayerCallback(playerFinished: self)
    }
    
    private func removePlayer() {
        guard let player = player else {
            return
        }
        player.pause()
        
        removeObserversPlayer(avPlayer: player)
        
        if let playerItem = player.currentItem {
            removeObserversVideoItem(playerItem: playerItem)
        }
        
        self.player = nil
        
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        
        if context == &statusContext {
            
            guard let avPlayer = player else {
                super.observeValue(forKeyPath: keyPath, of: object, change: change , context: context)
                return
            }
            self.delegate?.anneVideoPlayerCallback(playerView: self, statusPlayer: avPlayer.status, error: avPlayer.error)
            
        } else if context == &loadedContext {
            
            let playerItem = player?.currentItem
            
            guard let times = playerItem?.loadedTimeRanges else {
                return
            }
            
            let values = times.map({ $0.timeRangeValue})
            self.delegate?.anneVideoPlayerCallback(playerView: self, loadedTimeRanges: values)
            
        } else if context == &durationContext{
            
            if let currentItem = player?.currentItem {
                self.delegate?.anneVideoPlayerCallback(playerView: self, duration: currentItem.duration.seconds)
            }
            
        } else if context == &statusItemContext{
            //status of item has changed
            if let currentItem = player?.currentItem {
                self.delegate?.anneVideoPlayerCallback(playerView: self, statusItemPlayer: currentItem.status, error: currentItem.error)
            }
            
        } else if context == &rateContext{
            guard let newRateNumber = (change?[NSKeyValueChangeKey.newKey] as? NSNumber) else{
                return
            }
            let newRate = newRateNumber.floatValue
            if newRate == 0 {
                removeCurrentTimeObserver()
            } else {
                addCurrentTimeObserver()
            }
            
            self.delegate?.anneVideoPlayerCallback(playerView: self, rate: newRate)
            
        }else if context == &statusKeepUpContext{
            
            guard let newIsKeppupValue = (change?[NSKeyValueChangeKey.newKey] as? Bool) else{
                return
            }
            
            self.delegate?.anneVideoPlayerCallback(playerView: self, isLikelyKeepUp: newIsKeppupValue)
            
        } else if context == &playerItemContext{
            guard let oldItem = (change?[NSKeyValueChangeKey.oldKey] as? AVPlayerItem) else{
                return
            }
            removeObserversVideoItem(playerItem: oldItem)
            guard let newItem = (change?[NSKeyValueChangeKey.newKey] as? AVPlayerItem) else{
                return
            }
            addObserversVideoItem(playerItem: newItem)
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change , context: context)
        }
    }
}

extension AnneVideoPlayerView{
    func play(rate: Float = 1) {
        self.rate = rate
    }
    
    func pause() {
        self.isCalcurateCurrentTime = false
        rate = 0
    }
    
    func stop() {
        currentTime = 0
        pause()
    }
    

    func playFromBeginning() {
        self.player?.seek(to: CMTime.zero)
        self.player?.play()
    }
}

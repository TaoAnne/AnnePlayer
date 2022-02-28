//
//  AnnePlayerTests.swift
//  AnnePlayerTests
//
//  Created by Littlefox iOS Developer on 2022/02/25.
//

import XCTest
import AnnePlayer
import AVKit

class AnnePlayerTests: XCTestCase {
    
    var sut: AnneVideoPlayerView!

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        
        self.sut = AnneVideoPlayerView()
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        self.sut = nil
    }
    
    func testLoadVideo(){
        let url = "https://cdn.littlefox.co.kr/contents_5/hls/480/f0176a138f/1625188421fcf1d8d2f36c0cde8eca4b86a8fe1df8/stream.m3u8?_=1625188424"
        let delegate = AnnePlayerDelegate(testCase: self)
        self.sut.delegate = delegate
    
        delegate.makeLoadException()
        self.sut.url = URL(string: url)
        
        waitForExpectations(timeout: 4)
        
        let isSuccess = delegate.isSuccess
        XCTAssertNotNil(isSuccess, "isSuccess: \(isSuccess)")
        
    }
}


class AnnePlayerDelegate: AnneVideoPlayerViewDelegate{
    
    var isSuccess: Bool?
    var error: Error?
    private var expectation: XCTestExpectation?
    private let testCase: XCTestCase
    
    init(testCase: XCTestCase) {
        self.testCase = testCase
        
    }
    
    func makeLoadException(){
        self.expectation = self.testCase.expectation(description: "anne player load test")
    }
    
    
    func anneVideoPlayerCallback(loadStart playerView: AnneVideoPlayerView) {
        
    }
    
    func anneVideoPlayerCallback(loadFinshied playerView: AnneVideoPlayerView, isLoadSuccess: Bool, error: Error?) {
        self.isSuccess = isLoadSuccess
        expectation?.fulfill()
    }
    
    func anneVideoPlayerCallback(playerView: AnneVideoPlayerView, statusPlayer: AVPlayer.Status, error: Error?) {
        
    }
    
    func anneVideoPlayerCallback(playerView: AnneVideoPlayerView, statusItemPlayer: AVPlayerItem.Status, error: Error?) {
        
    }
    
    func anneVideoPlayerCallback(playerView: AnneVideoPlayerView, loadedTimeRanges: [CMTimeRange]) {
        
    }
    
    func anneVideoPlayerCallback(playerView: AnneVideoPlayerView, duration: Double) {
        
    }
    
    func anneVideoPlayerCallback(playerView: AnneVideoPlayerView, currentTime: Double) {
        
    }
    
    func anneVideoPlayerCallback(playerView: AnneVideoPlayerView, rate: Float) {
        
    }
    
    func anneVideoPlayerCallback(playerView: AnneVideoPlayerView, isLikelyKeepUp: Bool) {
        
    }
    
    func anneVideoPlayerCallback(playerFinished playerView: AnneVideoPlayerView) {
        
    }
    
}

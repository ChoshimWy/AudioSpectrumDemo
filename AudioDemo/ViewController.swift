//
//  ViewController.swift
//  AudioDemo
//
//  Created by Choshim.Wei on 2024/10/10.
//

import Accelerate
import AudioKit
import AVFoundation
import UIKit

class ViewController: UIViewController {
    var engine = AudioEngine()
    var player: AudioPlayer!
    var fftTap: FFTTap!
    var amplitudeTap: AmplitudeTap!
    
    @IBOutlet var playBtn: UIButton!
    var spectrumView: SpectrumView!
    var waveformView: WaveformView!
    let numberOfBars: Int = 128
    // 平滑处理变量
    var smoothedMagnitudes: [Float] = []
        
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    @IBAction func playAction(_ sender: UIButton) {
        setupAudio()
        startAudio()
    }

    // 设置用户界面
    func setupUI() {
        playBtn.layer.cornerRadius = 6
        playBtn.layer.masksToBounds = true
        
        spectrumView = SpectrumView(frame: CGRect(x: (view.bounds.size.width - 300) / 2, y: playBtn.frame.maxY, width: 300, height: 300))
//        spectrumView.backgroundColor = .white
        view.addSubview(spectrumView)
        
        waveformView = WaveformView(frame: CGRect(x: 0, y: spectrumView.frame.maxY, width: view.bounds.size.width, height: 100))
//        waveformView.backgroundColor = .black
        view.addSubview(waveformView)
    }
        
    // 设置音频播放与 FFTTap
    func setupAudio() {
        guard let audioURL = Bundle.main.url(forResource: "Tuesday (Radio Edit)", withExtension: "mp3") else {
            fatalError("音频文件未找到")
        }
        
//        guard let audioURL = Bundle.main.url(forResource: "music", withExtension: "mp3") else {
//            fatalError("音频文件未找到")
//        }
            
        do {
            let file = try AVAudioFile(forReading: audioURL)
            player = AudioPlayer(file: file)
            player.completionHandler = { [weak self] in
                guard let self = self else { return }
                self.stop()
            }
            
            let playerCopy = Mixer(player)
            engine.output = playerCopy
            /// 获取FFT数据
            fftTap = FFTTap(player) { [weak self] fftData in
                guard let self = self else { return }
                let magnitudes = self.calculateMagnitudes(from: fftData)
                // 生成随机幅度数据
                // let magnitudes: [Float] = (0..<self.spectrumView.numberOfBars).map { _ in Float.random(in: 0...1) }
                DispatchQueue.main.async {
                    self.spectrumView.magnitudes = magnitudes
                }
            }
            
            /// 获取 Amplitude 数据
            amplitudeTap = AmplitudeTap(playerCopy) { amp in
                print("AmplitudeTap: \(amp)")
//                self.spectrumView.alpha = 0.6 + 0.4 * CGFloat(amp)
                DispatchQueue.main.async {
                    self.waveformView.update(with: amp)
                }
            }
            
        } catch {
            fatalError("无法加载音频文件: \(error)")
        }
    }
        
    // 启动音频引擎并播放
    func startAudio() {
        do {
            try engine.start()
            player.play()
            fftTap.start()
            amplitudeTap.start()
        } catch {
            fatalError("无法启动 AudioKit 引擎: \(error)")
        }
    }
    
    func stop() {
        fftTap.stop()
        player.stop()
        engine.stop()
        amplitudeTap.stop()
    }
    
    deinit {
        stop()
    }
    
    // 从FFT数据计算振幅
    func calculateAmplitude(from fftData: [Float]) -> Float {
        let sumOfSquares = fftData.reduce(0) { $0 + $1 * $1 } // 求平方和
        return sqrt(sumOfSquares / Float(fftData.count)) // 计算均方根
    }
    
    // MARK: - 计算FFT数据

    // 将 FFT 数据转换为幅度数组
    func calculateMagnitudes(from fftData: [Float]) -> [Float] {
        let fftData = applyHannWindow(fftData)
        /// 计算每个频点振幅平方
        var magnitudes = calculateMagnitudeSquared(from: fftData)
        /// 应用对数缩放,避免数据无穷小
        magnitudes = applyLogScaling(to: magnitudes)
        /// 归一化
        let normalizedMagnitudes = applyNormalize(magnitudes: magnitudes)
        /// 降采样频谱数据到指定条数
        let downsampled = applyDownsample(magnitudes: normalizedMagnitudes, to: numberOfBars)
        /// 平滑处理
        return applySmoothMagnitudes(magnitudes: downsampled)
    }
       
    /// 计算每个频点的幅度平方
    func calculateMagnitudeSquared(from fftData: [Float]) -> [Float] {
        let fftSize = fftData.count
        let halfSize = fftSize / 2
        var magnitudes = [Float](repeating: 0.0, count: halfSize)
        // 使用 UnsafeBufferPointer 直接引用 fftData，避免内存复制
        fftData.withUnsafeBufferPointer { fftBuffer in
            guard fftBuffer.count >= fftSize else {
                return
            }
                
            // 创建 DSPSplitComplex，指向 fftData 的实部和虚部
            var splitComplex = DSPSplitComplex(
                realp: UnsafeMutablePointer(mutating: fftBuffer.baseAddress!),
                imagp: UnsafeMutablePointer(mutating: fftBuffer.baseAddress! + 1)
            )
                
            // 计算幅度平方，stride 设置为 1，因为实部和虚部交错存储
            vDSP_zvmags(&splitComplex, 1, &magnitudes, 1, vDSP_Length(halfSize))
        }
       
        /// 计算幅度（平方根）使用 vvsqrt 替代 vDSP_vsqrt
        var magnitudesSqrt = [Float](repeating: 0.0, count: halfSize)
        vvsqrtf(&magnitudesSqrt, magnitudes, [Int32(magnitudes.count)])
        return magnitudesSqrt
    }

    /// 归一化
    func applyNormalize(magnitudes: [Float]) -> [Float] {
        var normalizedMagnitudes = [Float](repeating: 0.0, count: magnitudes.count)
        var maxMag: Float = 0.0
        vDSP_maxv(magnitudes, 1, &maxMag, vDSP_Length(magnitudes.count))

        if maxMag == 0 {
            maxMag = 1.0
        }

        vDSP_vsmul(magnitudes, 1, [1.0 / maxMag], &normalizedMagnitudes, 1, vDSP_Length(magnitudes.count))
        return normalizedMagnitudes
    }
    
    /// 将采样频谱数据到指定条数
    func applyDownsample(magnitudes: [Float], to numberOfBars: Int) -> [Float] {
        let binSize = magnitudes.count / numberOfBars
        var downsampled = [Float]()

        for i in 0..<numberOfBars {
            let start = i * binSize
            let end = start + binSize
            if end > magnitudes.count {
                downsampled.append(0.0)
                continue
            }
            let segment = magnitudes[start..<end]
            let avg = segment.reduce(0, +) / Float(binSize)
            downsampled.append(avg)
        }
        return downsampled
    }

    /// 应用对数缩放
    func applyLogScaling(to magnitudes: [Float]) -> [Float] {
        var logMagnitudes = [Float]()
        for mag in magnitudes {
            let logMag = log10(max(mag, 1e-10)) // 防止对数为负无穷
            logMagnitudes.append(logMag)
        }
        return logMagnitudes.map { $0 * -1 }
    }
    
    // 平滑幅度数据（移动平均）
    func applySmoothMagnitudes(magnitudes: [Float]) -> [Float] {
        if smoothedMagnitudes.isEmpty {
            smoothedMagnitudes = magnitudes
        } else {
            for i in 0..<magnitudes.count {
                smoothedMagnitudes[i] = smoothedMagnitudes[i] * 0.8 + magnitudes[i] * 0.2
            }
        }
        return smoothedMagnitudes
    }

    /// 应用窗口函数（如汉宁窗、汉明窗）可以减少频谱泄漏，提高频谱质量
    func applyHannWindow(_ data: [Float]) -> [Float] {
        var window = [Float](repeating: 0.0, count: data.count)
        vDSP_hann_window(&window, vDSP_Length(data.count), Int32(vDSP_HANN_NORM))
        
        var windowedData = [Float](repeating: 0.0, count: data.count)
        vDSP_vmul(data, 1, window, 1, &windowedData, 1, vDSP_Length(data.count))
        return windowedData
    }
}

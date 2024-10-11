//
//  WaveformView.swift
//  AudioDemo
//
//  Created by Choshim.Wei on 2024/10/11.
//

import UIKit

class WaveformView: UIView {
    private let shapeLayer = CAShapeLayer()
    private var wavePoints: [CGPoint] = []
    /// 显示的最大点数
    private var maxPoints: CGFloat = 200
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }
    
    private func setup() {
        shapeLayer.strokeColor = UIColor.blue.cgColor
        shapeLayer.lineWidth = 2.0
        shapeLayer.fillColor = UIColor.clear.cgColor
        self.layer.addSublayer(shapeLayer)
    }
    
    /// 更新波形图
    func update(with amplitude: Float) {
        let normalizedAmplitude = CGFloat(amplitude) * self.bounds.height
        let xScale = self.bounds.size.width / maxPoints
        if wavePoints.count == Int(maxPoints) {
            wavePoints.removeAll()
        }
        
        /// 将新振幅值添加为波形点
        wavePoints.append(CGPoint(x: xScale * CGFloat(wavePoints.count), y: self.bounds.midY - normalizedAmplitude / 2))
        
        /// 创建路径绘制波形
        let path = UIBezierPath()
        for (index, point) in wavePoints.enumerated() {
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        
        /// 设置路径
        shapeLayer.path = path.cgPath
    }
}

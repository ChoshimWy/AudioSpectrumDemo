//
//  SpectrumView.swift
//  AudioDemo
//
//  Created by Choshim.Wei on 2024/10/11.
//

import UIKit

/// 自定义的频谱视图
class SpectrumView: UIView {
    var magnitudes: [Float] = [] {
        didSet {
            setNeedsDisplay()
        }
    }
    
    /// 振幅最大半径
    let maxMagnitudeRadius: CGFloat = 20
     
    override func draw(_ rect: CGRect) {
        guard !magnitudes.isEmpty else { return }
        
        let center = CGPoint(x: rect.width / 2, y: rect.height / 2)
        let radius = min(rect.width, rect.height) / 2 * 0.4 // 圆的半径
//        let arcRadius = min(rect.width, rect.height) / 2 * 0.7 // 圆的半径
        let angleIncrement = (2 * CGFloat.pi) / CGFloat(magnitudes.count)

        /// 绘制圆弧
//        let arcPath = UIBezierPath(arcCenter: center, radius: radius, startAngle: 0, endAngle: 2 * CGFloat.pi, clockwise: true)
//        UIColor.white.setStroke()
//        arcPath.lineWidth = 2.0
//        arcPath.stroke()

//        let arcPath = UIBezierPath()
        /// 绘制频谱
        for (index, magnitude) in magnitudes.enumerated() {
            guard !magnitude.isNaN else {
                continue
            }
            
            /// 计算当前频率的角度
            let angle = angleIncrement * CGFloat(index)
            /// 计算当前角度颜色
            let hue = angle / (2 * CGFloat.pi)
            let color = UIColor(hue: hue, saturation: 1.0, brightness: 1.0, alpha: 1.0)
          
            let normalizedMagnitude = min(max(magnitude, 0.0), 1.0) // 保证幅度在0-1之间
            print("angle: \(angle / (2 * CGFloat.pi) * 360)°, normalizedMagnitude: \(normalizedMagnitude)")
            /// 根据幅度计算绘制半径
            let drawRadius = radius + maxMagnitudeRadius * CGFloat(normalizedMagnitude)
                         
            /// 计算起点在圆弧上的位置
            let startX = center.x + radius * cos(angle)
            let startY = center.y + radius * sin(angle)
            /// 计算终点位置
            let endX = center.x + drawRadius * cos(angle)
            let endY = center.y + drawRadius * sin(angle)
                           
            /// 绘制线条
            let path = UIBezierPath()
            /// 起点在圆弧上
            path.move(to: CGPoint(x: startX, y: startY))
            /// 终点向外延伸
            path.addLine(to: CGPoint(x: endX, y: endY))
            path.lineWidth = 2.0
            color.setStroke() // 设置线条颜色
            path.stroke()
            
//            let arcDrawRadius = arcRadius + maxMagnitudeRadius * CGFloat(normalizedMagnitude)
//            // 计算终点位置
//            let arcEndX = center.x + arcDrawRadius * cos(angle)
//            let arcEndY = center.y + arcDrawRadius * sin(angle)
//
//            if index == 0 {
//                arcPath.move(to: CGPoint(x: arcEndX, y: arcEndY))
//            } else {
//                arcPath.addLine(to: CGPoint(x: arcEndX, y: arcEndY))
//            }
//            arcPath.lineWidth = 2
//            UIColor.orange.setStroke()
//            arcPath.stroke()
        }
    }
}

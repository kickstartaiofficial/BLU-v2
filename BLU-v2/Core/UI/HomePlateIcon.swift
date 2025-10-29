//
//  HomePlateIcon.swift
//  BLU-v2
//
//  Home plate icon component for UI
//

import SwiftUI

struct HomePlateIcon: View {
    let size: CGFloat
    let strokeWidth: CGFloat
    let color: Color
    
    init(size: CGFloat = 100, strokeWidth: CGFloat = 3, color: Color = .white) {
        self.size = size
        self.strokeWidth = strokeWidth
        self.color = color
    }
    
    var body: some View {
        Path { path in
            // Home plate dimensions scaled to fit the size
            let width = size * 0.85
            let sideHeight = size * 0.425
            let bottomP = size * 0.6
            
            // Calculate points based on home plate shape
            let topLeft = CGPoint(x: (size - width) / 2, y: (size - sideHeight) / 2)
            let topRight = CGPoint(x: topLeft.x + width, y: topLeft.y)
            let middleRight = CGPoint(x: topRight.x, y: topLeft.y + sideHeight)
            let bottomPoint = CGPoint(x: size / 2, y: topLeft.y + sideHeight + bottomP * 0.5)
            let middleLeft = CGPoint(x: topLeft.x, y: middleRight.y)
            
            path.move(to: topLeft)
            path.addLine(to: topRight)
            path.addLine(to: middleRight)
            path.addLine(to: bottomPoint)
            path.addLine(to: middleLeft)
            path.closeSubpath()
        }
        .stroke(color, lineWidth: strokeWidth)
        .frame(width: size, height: size)
    }
}

struct FilledHomePlateIcon: View {
    let size: CGFloat
    let color: Color
    
    init(size: CGFloat = 100, color: Color = .white) {
        self.size = size
        self.color = color
    }
    
    var body: some View {
        Path { path in
            // Home plate dimensions scaled to fit the size
            let width = size * 0.85
            let sideHeight = size * 0.425
            let bottomP = size * 0.6
            
            // Calculate points based on home plate shape
            let topLeft = CGPoint(x: (size - width) / 2, y: (size - sideHeight) / 2)
            let topRight = CGPoint(x: topLeft.x + width, y: topLeft.y)
            let middleRight = CGPoint(x: topRight.x, y: topLeft.y + sideHeight)
            let bottomPoint = CGPoint(x: size / 2, y: topLeft.y + sideHeight + bottomP * 0.5)
            let middleLeft = CGPoint(x: topLeft.x, y: middleRight.y)
            
            path.move(to: topLeft)
            path.addLine(to: topRight)
            path.addLine(to: middleRight)
            path.addLine(to: bottomPoint)
            path.addLine(to: middleLeft)
            path.closeSubpath()
        }
        .fill(color)
        .frame(width: size, height: size)
    }
}

#Preview {
    VStack(spacing: 30) {
        HomePlateIcon(size: 150, strokeWidth: 4, color: .blue)
        FilledHomePlateIcon(size: 150, color: .green)
        HomePlateIcon(size: 80, strokeWidth: 2, color: .red)
    }
    .padding()
    .background(Color.black)
}

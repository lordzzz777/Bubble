//
//  Triangle.swift
//  Bubble
//
//  Created by Esteban Pérez Castillejo on 17/3/25.
//

import Foundation
import SwiftUI

// Componente para dibujar el triangulo
struct TriangleRight: Shape{
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // 1. Mover a la esquina superior derecha (punto A)
        path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        // 2. Trazar línea a la esquina superior izquierda (punto B)
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
        // 3. Trazar línea hacia la esquina inferior derecha (punto C)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// Triángulo rectángulo con ángulo en la esquina superior izquierda.
struct TriangleLeft: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        // (A) Esquina superior izquierda
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        // (B) Esquina superior derecha
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        // (C) Esquina inferior izquierda
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

import SwiftUI

enum Motion {
    static let spring = Animation.spring(response: 0.4, dampingFraction: 0.78)
    static let snappy = Animation.spring(response: 0.28, dampingFraction: 0.72)
    static let soft   = Animation.spring(response: 0.55, dampingFraction: 0.82)
    static let pulse  = Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)
}

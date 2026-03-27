import Foundation

extension Timer {
    static func scheduledOnMainRunLoop(
        interval: TimeInterval,
        repeats: Bool,
        block: @escaping (Timer) -> Void
    ) -> Timer {
        let timer = Timer(timeInterval: interval, repeats: repeats, block: block)
        RunLoop.main.add(timer, forMode: .common)
        return timer
    }
}

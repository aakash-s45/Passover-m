import Foundation

class SimpleTimer {
    static let shared = SimpleTimer()
    private var startTime: Date?
    private var timer: Timer?
    private var elapsedTimeString: String = "00:00:00"
    
    private init(){}
    
    func resetTimer() {
        self.stopTimer()
        startTime = Date()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            self.updateTime()
        }
    }
    
    func stopTimer(){
        timer?.invalidate()
        self.elapsedTimeString = "00:00:00"
        timer = nil
    }
    
    func getElapsedTime()->String{
        return self.elapsedTimeString
    }
    
    private func updateTime() {
        guard let startTime = startTime else { return }
        let elapsedTime = Date().timeIntervalSince(startTime)
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60
        elapsedTimeString = String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        HFDState.shared.update(elapsedTimeString: self.elapsedTimeString)
    }
}


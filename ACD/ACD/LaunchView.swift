import SwiftUI

struct LaunchView: View {
    @State private var displayedText: String = ""
    @State private var textPosition: CGFloat = UIScreen.main.bounds.width
    @State private var isAnimationCompleted = false
    private let fullText = "健康永远是第一位的！！！😊"
    
    var body: some View {
        ZStack {
            Color(UIColor.darkGray) // Changed to a darker grey color
                .ignoresSafeArea()
            
            Text(displayedText)
                .font(.largeTitle)
                .bold()
                .padding()
                .offset(x: textPosition)
                .foregroundColor(.white) // Make the text more readable against the darker background
                .onAppear {
                    animateText()
                }
        }
    }
    
    private func animateText() {
        for (index, character) in fullText.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.3) {
                displayedText.append(character)
                triggerStrongHapticFeedback()
                
                // Update position to move text to the left, stopping at the center
                withAnimation(.easeOut(duration: 0.5)) {
                    if index < fullText.count - 1 {
                        textPosition = 0
                    }
                }
                
                // Mark animation completion once all characters are shown
                if index == fullText.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        isAnimationCompleted = true
                    }
                }
            }
        }
    }
    
    private func triggerStrongHapticFeedback() {
        let notificationFeedback = UINotificationFeedbackGenerator()
        notificationFeedback.notificationOccurred(.error) // Use .error for a stronger haptic effect
    }
}

struct LaunchView_Previews: PreviewProvider {
    static var previews: some View {
        LaunchView()
    }
}

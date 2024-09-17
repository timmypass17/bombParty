//
//  CurrentWordView.swift
//  OIOIOIBaka
//
//  Created by Timmy Nguyen on 9/10/24.
//

import UIKit

class CurrentWordView: UIView {
    
    let wordLabel: UILabel = {
        let label = UILabel()
        label.text = "ING"
        label.font = .preferredFont(forTextStyle: .title1)
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    let arrowView: ArrowView = {
        let arrowView = ArrowView()
        arrowView.translatesAutoresizingMaskIntoConstraints = false
        return arrowView
    }()
    
    let container: UIView = {
        let view = UIView()
        view.backgroundColor = .systemBackground
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    let padding: CGFloat = 5
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        container.addSubview(wordLabel)
        addSubview(arrowView)
        addSubview(container)
        
        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: centerXAnchor),
            container.centerYAnchor.constraint(equalTo: centerYAnchor),
            
//            container.widthAnchor.constraint(equalTo: container.heightAnchor),  // for circle
            
            wordLabel.topAnchor.constraint(equalTo: container.topAnchor, constant: padding),
            wordLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -padding),
            wordLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: padding),
            wordLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -padding),
            
            arrowView.centerXAnchor.constraint(equalTo: centerXAnchor),
            arrowView.centerYAnchor.constraint(equalTo: centerYAnchor),
            
        ])
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func pointArrow(at targetView: UIView, _ viewController: UIViewController) {
        // Convert frame's in respect to viewController
        // - view frames are relative to their parent's view, we treat arrowView's frame as if it were in the viewControllers's view box frame
        guard let targetFrame = targetView.superview?.convert(targetView.frame, to: viewController.view),
              let arrowFrame = arrowView.superview?.convert(arrowView.frame, to: viewController.view)
        else { return }
        
        // Calculate the angle between arrow and target
        let targetCenter = CGPoint(x: targetFrame.midX, y: targetFrame.midY)
        let arrowCenter = CGPoint(x: arrowFrame.midX, y: arrowFrame.midY)
        let angle = atan2(targetCenter.y - arrowCenter.y, targetCenter.x - arrowCenter.x)

        // Animate the rotation
        UIView.animate(withDuration: 0.25, // Duration of the animation in seconds
                       delay: 0,          // Delay before the animation starts
                       options: .curveEaseInOut, // Easing option for smooth animation
                       animations: {
            self.arrowView.transform = CGAffineTransform(rotationAngle: angle)
        }, completion: nil)
    }
}

#Preview("CurrentWordView") {
    CurrentWordView()
}

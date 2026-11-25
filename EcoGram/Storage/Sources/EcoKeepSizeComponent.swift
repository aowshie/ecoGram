import Foundation
import UIKit
import Display
import ComponentFlow
import TelegramPresentationData
import TelegramStringFormatting
import SliderComponent
import AyuSettings
import EcoStrings

final class EcoKeepSizeComponent: Component {
    let theme: PresentationTheme
    let strings: PresentationStrings
    let ecoStrings: EcoStrings
    let value: Int
    let updateValue: (Int) -> Void

    init(theme: PresentationTheme, strings: PresentationStrings, ecoStrings: EcoStrings, value: Int, updateValue: @escaping (Int) -> Void) {
        self.theme = theme
        self.strings = strings
        self.ecoStrings = ecoStrings
        self.value = value
        self.updateValue = updateValue
    }

    static func ==(lhs: EcoKeepSizeComponent, rhs: EcoKeepSizeComponent) -> Bool {
        if lhs.theme !== rhs.theme {
            return false
        }
        if lhs.strings !== rhs.strings {
            return false
        }
        if lhs.ecoStrings.languageCode != rhs.ecoStrings.languageCode {
            return false
        }
        if lhs.value != rhs.value {
            return false
        }
        return true
    }

    final class View: UIView {
        private let titles: [ComponentView<Empty>]
        private let slider = ComponentView<Empty>()

        private var component: EcoKeepSizeComponent?

        override init(frame: CGRect) {
            self.titles = AyuSettings.mediaLimitOptions.map { _ in ComponentView<Empty>() }

            super.init(frame: frame)

            self.clipsToBounds = true
            self.layer.cornerRadius = 26.0
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        private func title(_ value: Int, component: EcoKeepSizeComponent) -> String {
            if value <= 0 {
                return component.ecoStrings.get(.historyMediaOff)
            }
            return dataSizeString(Int64(value) * 1024 * 1024, formatting: DataSizeStringFormatting(strings: component.strings, decimalSeparator: "."))
        }

        func update(component: EcoKeepSizeComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
            let themeUpdated = self.component?.theme !== component.theme
            self.component = component

            if themeUpdated {
                self.backgroundColor = component.theme.list.itemBlocksBackgroundColor
            }

            let values = AyuSettings.mediaLimitOptions
            var titleSizes: [CGSize] = []
            for i in 0 ..< self.titles.count {
                titleSizes.append(self.titles[i].update(
                    transition: .immediate,
                    component: AnyComponent(Text(text: self.title(values[i], component: component), font: Font.regular(13.0), color: component.theme.list.itemSecondaryTextColor)),
                    environment: {},
                    containerSize: CGSize(width: 100.0, height: 100.0)
                ))
            }

            let delta = (availableSize.width - 18.0 * 2.0) / CGFloat(titleSizes.count - 1)
            for i in 0 ..< titleSizes.count {
                let titleSize = titleSizes[i]
                if let titleView = self.titles[i].view {
                    if titleView.superview == nil {
                        titleView.isAccessibilityElement = false
                        titleView.accessibilityElementsHidden = true
                        self.addSubview(titleView)
                    }
                    var position: CGFloat = 18.0 + delta * CGFloat(i)
                    if i == titleSizes.count - 1 {
                        position -= titleSize.width
                    } else if i > 0 {
                        position -= titleSize.width / 2.0
                    }
                    transition.setFrame(view: titleView, frame: CGRect(origin: CGPoint(x: position, y: 19.0), size: titleSize))
                }
            }

            let sliderSize = self.slider.update(
                transition: transition,
                component: AnyComponent(SliderComponent(
                    content: .discrete(.init(
                        valueCount: values.count,
                        value: values.firstIndex(of: component.value) ?? 0,
                        markPositions: true,
                        valueUpdated: { index in
                            component.updateValue(values[index])
                        }
                    )),
                    useNative: true,
                    trackBackgroundColor: component.theme.list.itemSwitchColors.frameColor,
                    trackForegroundColor: component.theme.list.itemAccentColor,
                    accessibilityLabel: component.ecoStrings.get(.historyMediaLimit),
                    accessibilityValue: self.title(component.value, component: component)
                )),
                environment: {},
                containerSize: CGSize(width: availableSize.width - 15.0 * 2.0, height: 44.0)
            )
            if let sliderView = self.slider.view {
                if sliderView.superview == nil {
                    self.addSubview(sliderView)
                }
                transition.setFrame(view: sliderView, frame: CGRect(origin: CGPoint(x: floorToScreenPixels((availableSize.width - sliderSize.width) / 2.0), y: 41.0), size: sliderSize))
            }

            return CGSize(width: availableSize.width, height: 96.0)
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<Empty>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

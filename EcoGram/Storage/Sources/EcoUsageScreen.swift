import Foundation
import UIKit
import Display
import AsyncDisplayKit
import ComponentFlow
import SwiftSignalKit
import ViewControllerComponent
import TelegramCore
import TelegramPresentationData
import AccountContext
import RadialStatusNode
import EdgeEffect
import StorageUsageScreen
import AyuSettings
import EcoStrings

final class EcoUsageScreenComponent: Component {
    typealias EnvironmentType = ViewControllerComponentContainer.Environment

    let context: AccountContext
    let ready: Promise<Bool>

    init(context: AccountContext, ready: Promise<Bool>) {
        self.context = context
        self.ready = ready
    }

    static func ==(lhs: EcoUsageScreenComponent, rhs: EcoUsageScreenComponent) -> Bool {
        return lhs.context === rhs.context
    }

    final class AnimationHint {
        enum Value {
            case firstStatsUpdate
            case clearedItems
        }

        let value: Value

        init(value: Value) {
            self.value = value
        }
    }

    final class View: UIView, UIScrollViewDelegate {
        let scrollView: UIScrollView
        let scrollContainerView: UIView
        let headerOffsetContainer: UIView
        let edgeEffectView: EdgeEffectView
        let headerProgressBackgroundLayer: SimpleLayer
        let headerProgressForegroundLayer: SimpleLayer

        let headerView = ComponentView<Empty>()
        let headerDescriptionView = ComponentView<Empty>()
        let pieChartView = ComponentView<Empty>()
        let chartTotalLabel = ComponentView<Empty>()
        var doneStatusNode: RadialStatusNode?
        let categoriesView = ComponentView<Empty>()
        let categoriesDescriptionView = ComponentView<Empty>()
        let keepDurationTitleView = ComponentView<Empty>()
        let keepDurationItem = ComponentView<Empty>()
        let keepDurationSectionContainerView: UIView
        let keepDurationDescriptionView = ComponentView<Empty>()
        let keepSizeTitleView = ComponentView<Empty>()
        let keepSizeView = ComponentView<Empty>()
        let keepSizeDescriptionView = ComponentView<Empty>()
        let launchSection = ComponentView<Empty>()
        let launchDescriptionView = ComponentView<Empty>()

        var loadingView: UIActivityIndicatorView?
        var clearingNode: StorageUsageClearProgressOverlayNode?
        var clearingDisplayTimestamp: Double?

        var component: EcoUsageScreenComponent?
        weak var state: EmptyComponentState?
        var controller: (() -> ViewController?)?
        var navigationMetrics: (navigationHeight: CGFloat, statusBarHeight: CGFloat)?
        var ignoreScrolling = false
        var chartHasData = false

        var stats: AyuKeptStorage?
        var deselectedCategories = Set<AyuKeptCategory>()

        private var statsDisposable: Disposable?
        let reloadDisposable = MetaDisposable()
        let clearDisposable = MetaDisposable()
        private var settingsObserver: NSObjectProtocol?
        private var keepScreenActiveDisposable: Disposable?

        var isClearing = false {
            didSet {
                guard self.isClearing != oldValue else {
                    return
                }
                if self.isClearing {
                    if self.keepScreenActiveDisposable == nil {
                        self.keepScreenActiveDisposable = self.component?.context.sharedContext.applicationBindings.pushIdleTimerExtension()
                    }
                } else if let keepScreenActiveDisposable = self.keepScreenActiveDisposable {
                    self.keepScreenActiveDisposable = nil
                    keepScreenActiveDisposable.dispose()
                }
            }
        }

        override init(frame: CGRect) {
            self.scrollView = UIScrollView()
            self.scrollContainerView = UIView()
            self.headerOffsetContainer = SparseContainerView()
            self.edgeEffectView = EdgeEffectView()
            self.headerProgressBackgroundLayer = SimpleLayer()
            self.headerProgressForegroundLayer = SimpleLayer()
            self.keepDurationSectionContainerView = UIView()
            self.keepDurationSectionContainerView.clipsToBounds = true
            self.keepDurationSectionContainerView.layer.cornerRadius = 26.0

            super.init(frame: frame)

            self.scrollView.delaysContentTouches = true
            self.scrollView.canCancelContentTouches = true
            self.scrollView.contentInsetAdjustmentBehavior = .never
            self.scrollView.automaticallyAdjustsScrollIndicatorInsets = false
            self.scrollView.showsVerticalScrollIndicator = false
            self.scrollView.showsHorizontalScrollIndicator = false
            self.scrollView.alwaysBounceHorizontal = false
            self.scrollView.scrollsToTop = false
            self.scrollView.delegate = self
            self.scrollView.clipsToBounds = true
            self.addSubview(self.scrollView)

            self.scrollView.addSubview(self.scrollContainerView)
            self.scrollContainerView.addSubview(self.keepDurationSectionContainerView)
            self.scrollView.layer.addSublayer(self.headerProgressBackgroundLayer)
            self.scrollView.layer.addSublayer(self.headerProgressForegroundLayer)

            self.addSubview(self.edgeEffectView)
            self.addSubview(self.headerOffsetContainer)
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        deinit {
            self.statsDisposable?.dispose()
            self.reloadDisposable.dispose()
            self.clearDisposable.dispose()
            self.keepScreenActiveDisposable?.dispose()
            if let settingsObserver = self.settingsObserver {
                NotificationCenter.default.removeObserver(settingsObserver)
            }
        }

        override var accessibilityElements: [Any]? {
            get {
                let headerViews = self.headerOffsetContainer.subviews.filter { !$0.isHidden && $0.alpha > 0.01 }.sorted { $0.frame.minY < $1.frame.minY }
                let contentViews = self.scrollContainerView.subviews.filter { !$0.isHidden && $0.alpha > 0.01 }.sorted { $0.frame.minY < $1.frame.minY }
                return headerViews + contentViews
            } set(value) {
            }
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            if !self.ignoreScrolling {
                self.updateScrolling(transition: .immediate)
            }
        }

        func updateScrolling(transition: ComponentTransition) {
            guard let headerView = self.headerView.view, let navigationMetrics = self.navigationMetrics else {
                return
            }
            let minY = navigationMetrics.statusBarHeight + floor((navigationMetrics.navigationHeight - navigationMetrics.statusBarHeight) / 2.0)
            let minOffset = headerView.center.y - minY
            let headerOffset = min(self.scrollView.bounds.minY, minOffset)

            let offsetFraction = min(1.0, max(0.0, abs(headerOffset - minOffset) / 60.0))
            transition.setScale(view: headerView, scale: 1.0 * offsetFraction + 0.8 * (1.0 - offsetFraction))
            transition.setBounds(view: self.headerOffsetContainer, bounds: CGRect(origin: CGPoint(x: 0.0, y: headerOffset), size: self.headerOffsetContainer.bounds.size))

            let chartContentsAlpha = self.chartHasData ? offsetFraction : 0.0
            if let pieChartComponentView = self.pieChartView.view {
                transition.setAlpha(view: pieChartComponentView, alpha: offsetFraction)
            }
            if let doneStatusNode = self.doneStatusNode {
                transition.setAlpha(view: doneStatusNode.view, alpha: offsetFraction)
            }
            if let chartTotalLabelView = self.chartTotalLabel.view {
                transition.setAlpha(view: chartTotalLabelView, alpha: chartContentsAlpha)
            }
        }

        func update(component: EcoUsageScreenComponent, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
            self.component = component
            self.state = state

            let environment = environment[ViewControllerComponentContainer.Environment.self].value
            let strings = EcoStrings(languageCode: environment.strings.baseLanguageCode)

            self.updateLoadingView(environment: environment, availableSize: availableSize, transition: transition)
            self.subscribeIfNeeded(component: component)

            let animationHint = transition.userData(AnimationHint.self)
            if let animationHint {
                switch animationHint.value {
                case .firstStatsUpdate:
                    let alphaTransition: ComponentTransition = environment.isVisible ? .easeInOut(duration: 0.25) : .immediate
                    alphaTransition.setAlpha(view: self.scrollView, alpha: self.stats != nil ? 1.0 : 0.0)
                    alphaTransition.setAlpha(view: self.headerOffsetContainer, alpha: self.stats != nil ? 1.0 : 0.0)
                case .clearedItems:
                    if let snapshotView = self.scrollContainerView.snapshotView(afterScreenUpdates: false) {
                        snapshotView.frame = self.scrollContainerView.frame
                        self.scrollView.insertSubview(snapshotView, aboveSubview: self.scrollContainerView)
                        self.scrollContainerView.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.2)
                        snapshotView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.25, removeOnCompletion: false, completion: { [weak snapshotView] _ in
                            snapshotView?.removeFromSuperview()
                        })
                    }
                }
            } else {
                transition.setAlpha(view: self.scrollView, alpha: self.stats != nil ? 1.0 : 0.0)
                transition.setAlpha(view: self.headerOffsetContainer, alpha: self.stats != nil ? 1.0 : 0.0)
            }

            self.controller = environment.controller
            self.navigationMetrics = (environment.navigationHeight, environment.statusBarHeight)
            self.backgroundColor = environment.theme.list.blocksBackgroundColor

            let edgeEffectHeight: CGFloat = environment.navigationHeight + 24.0
            let edgeEffectFrame = CGRect(origin: CGPoint(), size: CGSize(width: availableSize.width, height: edgeEffectHeight))
            transition.setFrame(view: self.edgeEffectView, frame: edgeEffectFrame)
            self.edgeEffectView.update(content: environment.theme.list.blocksBackgroundColor, alpha: 1.0, rect: edgeEffectFrame, edge: .top, edgeSize: min(64.0, edgeEffectHeight), transition: transition)

            let layout = EcoUsageLayout(
                width: availableSize.width,
                sideInset: 16.0 + environment.safeInsets.left,
                rightSideInset: 16.0 + environment.safeInsets.right,
                bandCenterX: environment.safeInsets.left + (availableSize.width - environment.safeInsets.left - environment.safeInsets.right) / 2.0
            )

            var contentHeight = environment.statusBarHeight + 19.0
            contentHeight = self.updateHeader(component: component, environment: environment, strings: strings, layout: layout, contentHeight: contentHeight, animationHint: animationHint, transition: transition)
            contentHeight = self.updateSettings(component: component, environment: environment, strings: strings, layout: layout, contentHeight: contentHeight, transition: transition)
            contentHeight += environment.safeInsets.bottom

            self.ignoreScrolling = true
            let contentOffset = self.scrollView.bounds.minY
            transition.setPosition(view: self.scrollView, position: CGRect(origin: CGPoint(), size: availableSize).center)
            let contentSize = CGSize(width: availableSize.width, height: contentHeight)
            if self.scrollView.contentSize != contentSize {
                self.scrollView.contentSize = contentSize
            }
            transition.setFrame(view: self.scrollContainerView, frame: CGRect(origin: CGPoint(), size: contentSize))
            var scrollViewBounds = self.scrollView.bounds
            scrollViewBounds.size = availableSize
            transition.setBounds(view: self.scrollView, bounds: scrollViewBounds)
            if !transition.animation.isImmediate && self.scrollView.bounds.minY != contentOffset {
                let deltaOffset = self.scrollView.bounds.minY - contentOffset
                transition.animateBoundsOrigin(view: self.scrollView, from: CGPoint(x: 0.0, y: -deltaOffset), to: CGPoint(), additive: true)
            }
            self.ignoreScrolling = false
            self.updateScrolling(transition: transition)

            self.updateClearingNode(component: component, environment: environment, availableSize: availableSize)

            return availableSize
        }

        private func updateLoadingView(environment: ViewControllerComponentContainer.Environment, availableSize: CGSize, transition: ComponentTransition) {
            if self.stats == nil {
                let loadingView: UIActivityIndicatorView
                if let current = self.loadingView {
                    loadingView = current
                } else {
                    loadingView = UIActivityIndicatorView(style: .large)
                    self.loadingView = loadingView
                    loadingView.sizeToFit()
                    self.insertSubview(loadingView, belowSubview: self.scrollView)
                }
                let loadingViewSize = loadingView.bounds.size
                transition.setFrame(view: loadingView, frame: CGRect(origin: CGPoint(x: floor((availableSize.width - loadingViewSize.width) / 2.0), y: floor((availableSize.height - loadingViewSize.height) / 2.0)), size: loadingViewSize))
                if !loadingView.isAnimating {
                    loadingView.startAnimating()
                }
            } else if let loadingView = self.loadingView {
                self.loadingView = nil
                if environment.isVisible {
                    loadingView.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, removeOnCompletion: false, completion: { [weak loadingView] _ in
                        loadingView?.removeFromSuperview()
                    })
                } else {
                    loadingView.removeFromSuperview()
                }
            }
        }

        private func subscribeIfNeeded(component: EcoUsageScreenComponent) {
            guard self.statsDisposable == nil else {
                return
            }
            self.statsDisposable = (component.context.engine.messages.ayuKeptStorageUpdates()
            |> deliverOnMainQueue).start(next: { [weak self] stats in
                guard let self else {
                    return
                }
                let isFirst = self.stats == nil
                self.stats = stats
                if isFirst {
                    self.state?.updated(transition: ComponentTransition(animation: .none).withUserData(AnimationHint(value: .firstStatsUpdate)))
                    self.component?.ready.set(.single(true))
                } else if !self.isClearing {
                    self.state?.updated(transition: ComponentTransition(animation: .curve(duration: 0.4, curve: .spring)))
                }
            })
            self.settingsObserver = NotificationCenter.default.addObserver(forName: AyuSettings.didChange, object: nil, queue: .main, using: { [weak self] _ in
                self?.state?.updated(transition: .immediate)
            })
        }

        private func updateClearingNode(component: EcoUsageScreenComponent, environment: ViewControllerComponentContainer.Environment, availableSize: CGSize) {
            if self.isClearing {
                let clearingNode: StorageUsageClearProgressOverlayNode
                var animateIn = false
                if let current = self.clearingNode {
                    clearingNode = current
                } else {
                    animateIn = true
                    clearingNode = StorageUsageClearProgressOverlayNode(presentationData: component.context.sharedContext.currentPresentationData.with { $0 })
                    self.clearingNode = clearingNode
                    self.addSubnode(clearingNode)
                    self.clearingDisplayTimestamp = CFAbsoluteTimeGetCurrent()
                }
                clearingNode.frame = CGRect(origin: CGPoint(), size: availableSize)
                clearingNode.updateLayout(size: availableSize, bottomInset: environment.safeInsets.bottom, transition: .immediate)
                if animateIn {
                    clearingNode.layer.animateAlpha(from: 0.0, to: 1.0, duration: 0.25, delay: 0.4)
                }
            } else if let clearingNode = self.clearingNode {
                self.clearingNode = nil
                var delay: Double = 0.0
                if let clearingDisplayTimestamp = self.clearingDisplayTimestamp {
                    let timeDelta = CFAbsoluteTimeGetCurrent() - clearingDisplayTimestamp
                    if timeDelta >= 0.4 && timeDelta < 1.0 {
                        delay = 1.0
                    }
                }
                if delay == 0.0 {
                    ComponentTransition(animation: .curve(duration: 0.25, curve: .easeInOut)).setAlpha(view: clearingNode.view, alpha: 0.0, completion: { [weak clearingNode] _ in
                        clearingNode?.removeFromSupernode()
                    })
                } else {
                    clearingNode.layer.animateAlpha(from: 1.0, to: 0.0, duration: 0.2, delay: delay, removeOnCompletion: false, completion: { [weak clearingNode] _ in
                        clearingNode?.removeFromSupernode()
                    })
                }
            }
        }
    }

    func makeView() -> View {
        return View(frame: CGRect())
    }

    func update(view: View, availableSize: CGSize, state: EmptyComponentState, environment: Environment<ViewControllerComponentContainer.Environment>, transition: ComponentTransition) -> CGSize {
        return view.update(component: self, availableSize: availableSize, state: state, environment: environment, transition: transition)
    }
}

struct EcoUsageLayout {
    let width: CGFloat
    let sideInset: CGFloat
    let rightSideInset: CGFloat
    let bandCenterX: CGFloat

    var contentWidth: CGFloat {
        return self.width - self.sideInset - self.rightSideInset
    }

    var textWidth: CGFloat {
        return self.contentWidth - 15.0 * 2.0
    }
}

public final class EcoUsageScreen: ViewControllerComponentContainer {
    private let readyValue = Promise<Bool>()
    override public var ready: Promise<Bool> {
        return self.readyValue
    }

    public init(context: AccountContext) {
        let componentReady = Promise<Bool>()
        super.init(context: context, component: EcoUsageScreenComponent(context: context, ready: componentReady), navigationBarAppearance: .transparent)
        self.readyValue.set(componentReady.get() |> timeout(0.3, queue: .mainQueue(), alternate: .single(true)))
    }

    required public init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

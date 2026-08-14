import Foundation

/// Clamps `value` into the inclusive range [minValue, maxValue].
/// Used when dragging lights/objects on the detected plane so they can't be
/// thrown outside a sane working area.
func clamped<T: Comparable>(_ value: T, _ minValue: T, _ maxValue: T) -> T {
    min(max(value, minValue), maxValue)
}

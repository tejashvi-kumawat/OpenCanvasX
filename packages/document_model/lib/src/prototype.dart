import 'package:meta/meta.dart';

import 'ids.dart';

/// How a prototype moves from one frame to the next.
enum PrototypeTransition { instant, dissolve, slideLeft, slideRight, slideUp }

/// A prototype interaction (prototyping, Phase 3 early): clicking
/// [source] in present mode shows frame [target] with [transition].
@immutable
final class PrototypeLink {
  const PrototypeLink({
    required this.source,
    required this.target,
    this.transition = PrototypeTransition.dissolve,
  });

  final ObjectId source;

  /// A frame on the same board.
  final ObjectId target;
  final PrototypeTransition transition;

  PrototypeLink copyWith({ObjectId? target, PrototypeTransition? transition}) =>
      PrototypeLink(
        source: source,
        target: target ?? this.target,
        transition: transition ?? this.transition,
      );

  @override
  bool operator ==(Object other) =>
      other is PrototypeLink &&
      other.source == source &&
      other.target == target &&
      other.transition == transition;

  @override
  int get hashCode => Object.hash(source, target, transition);

  @override
  String toString() =>
      'PrototypeLink(${source.value} → ${target.value}, ${transition.name})';
}

import 'package:meta/meta.dart';

/// A broken cross-reference found by a model validator.
///
/// Validators collect every issue instead of throwing so that callers (file
/// open, repair UI) can report them all at once (ADR-0003).
@immutable
final class ModelIssue {
  const ModelIssue(this.subjectId, this.message);

  /// Id of the object or page the issue is about.
  final String subjectId;
  final String message;

  @override
  bool operator ==(Object other) =>
      other is ModelIssue &&
      other.subjectId == subjectId &&
      other.message == message;

  @override
  int get hashCode => Object.hash(subjectId, message);

  @override
  String toString() => '$subjectId: $message';
}

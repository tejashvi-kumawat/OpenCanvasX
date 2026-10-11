import 'design_object.dart';
import 'ids.dart';
import 'model_issue.dart';
import 'object_type.dart';

/// Checks parent/child links across a document's global object map.
///
/// Per-object rules are enforced by [DesignObject] itself; this covers rules
/// that span objects:
/// - each map key equals its object's id;
/// - a parent exists, is a group, and lists the child exactly once;
/// - every listed child exists and points back to the group;
/// - no object is its own ancestor.
///
/// Returns an empty list when the graph is consistent.
List<ModelIssue> validateObjectGraph(Map<ObjectId, DesignObject> objects) {
  final issues = <ModelIssue>[];

  for (final MapEntry(key: key, value: object) in objects.entries) {
    final id = object.id.value;
    if (key != object.id) {
      issues.add(ModelIssue(id, 'stored under different key ${key.value}'));
    }

    final parentId = object.parentId;
    if (parentId != null) {
      final parent = objects[parentId];
      if (parent == null) {
        issues.add(ModelIssue(id, 'parent ${parentId.value} does not exist'));
      } else if (parent.type != ObjectType.group) {
        issues.add(ModelIssue(id, 'parent ${parentId.value} is not a group'));
      } else if (!parent.childIds.contains(object.id)) {
        issues.add(
          ModelIssue(id, 'parent ${parentId.value} does not list it as child'),
        );
      }
    }

    for (final childId in object.childIds) {
      final child = objects[childId];
      if (child == null) {
        issues.add(ModelIssue(id, 'child ${childId.value} does not exist'));
      } else if (child.parentId != object.id) {
        issues.add(
          ModelIssue(id, 'child ${childId.value} has a different parent'),
        );
      }
    }

    if (_hasCycle(object, objects)) {
      issues.add(ModelIssue(id, 'is its own ancestor'));
    }
  }

  return issues;
}

bool _hasCycle(DesignObject start, Map<ObjectId, DesignObject> objects) {
  final seen = <ObjectId>{start.id};
  var current = start.parentId;
  while (current != null) {
    if (!seen.add(current)) return true;
    current = objects[current]?.parentId;
  }
  return false;
}

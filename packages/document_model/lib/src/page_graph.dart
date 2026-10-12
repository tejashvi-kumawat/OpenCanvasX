import 'design_object.dart';
import 'ids.dart';
import 'model_issue.dart';
import 'page.dart';

/// Checks that pages and root objects reference each other consistently.
///
/// - page ids are unique;
/// - every id in a page's `objectIds` exists and is a root on that page;
/// - every root object's page exists and lists it.
///
/// Combine with `validateObjectGraph` for the nested parts of the tree.
List<ModelIssue> validatePages(
  List<DesignPage> pages,
  Map<ObjectId, DesignObject> objects,
) {
  final issues = <ModelIssue>[];
  final byId = <PageId, DesignPage>{};

  for (final page in pages) {
    if (byId.containsKey(page.id)) {
      issues.add(ModelIssue(page.id.value, 'duplicate page id'));
      continue;
    }
    byId[page.id] = page;

    for (final objectId in page.objectIds) {
      final object = objects[objectId];
      if (object == null) {
        issues.add(
          ModelIssue(page.id.value, 'object ${objectId.value} does not exist'),
        );
      } else if (object.pageId != page.id) {
        issues.add(
          ModelIssue(
            page.id.value,
            'object ${objectId.value} is not a root object of this page',
          ),
        );
      }
    }
  }

  for (final object in objects.values) {
    final pageId = object.pageId;
    if (pageId == null) continue;
    final page = byId[pageId];
    if (page == null) {
      issues.add(
        ModelIssue(object.id.value, 'page ${pageId.value} does not exist'),
      );
    } else if (!page.objectIds.contains(object.id)) {
      issues.add(
        ModelIssue(object.id.value, 'page ${pageId.value} does not list it'),
      );
    }
  }

  return issues;
}

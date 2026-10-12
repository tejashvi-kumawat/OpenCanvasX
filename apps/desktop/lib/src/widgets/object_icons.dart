import 'package:document_model/document_model.dart';
import 'package:flutter/material.dart';

/// Icon for an object type in layers, menus and the inspector header.
IconData objectIcon(ObjectType type) => switch (type) {
  ObjectType.rect => Icons.crop_square,
  ObjectType.roundedRect => Icons.rounded_corner,
  ObjectType.ellipse => Icons.circle_outlined,
  ObjectType.polygon => Icons.hexagon_outlined,
  ObjectType.star => Icons.star_outline,
  ObjectType.line => Icons.horizontal_rule,
  ObjectType.arrow => Icons.north_east,
  ObjectType.text => Icons.title,
  ObjectType.image => Icons.image_outlined,
  ObjectType.path => Icons.gesture,
  ObjectType.group => Icons.folder_copy_outlined,
  ObjectType.frame => Icons.tag,
};

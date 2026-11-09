/// How skullet measures a layout into a skeleton, for tools and tests.
///
/// Apps don't need this: `package:skullet/skullet.dart` measures for you.
/// What a bone is and how it is measured may change in a minor version
/// before 1.0.
library;

export 'src/bones.dart' show Bone, BoneKind, SkeletonShape;
export 'src/measure.dart' show measureBones;

/// Skeletons measured from your real Flutter layout, revealed in place.
///
/// An unofficial Flutter port of skullet by Lochie Axon.
///
/// The measurement itself (`measureBones`, `Bone`, `BoneKind`) is in
/// `package:skullet/measure.dart`, for tools and tests that need it.
library;

export 'src/bones.dart' show SkeletonShape;
export 'src/environment.dart' show debugSkulletAnimateInTests;
export 'src/hints.dart'
    show
        SkeletonBlock,
        SkeletonBox,
        SkeletonIgnore,
        SkeletonReplace,
        SkeletonScope;
export 'src/shapes.dart'
    show MemoryShapeStore, ShapeStore, Skullet, forgetShapes;
export 'src/skeleton.dart' show FutureSkeleton, Skeleton, SkeletonBuilder;
export 'src/theme.dart'
    show
        RevealMode,
        SkeletonAnimation,
        SkeletonColors,
        SkeletonSpeed,
        SkulletMode,
        SkulletProvider,
        SkulletTheme;

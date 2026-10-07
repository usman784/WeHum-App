/// Shape & spacing tokens (spec §5).
abstract final class Gap {
  static const double x4 = 4, x6 = 6, x8 = 8, x10 = 10, x12 = 12, x14 = 14, x16 = 16, x18 = 18, x20 = 20, x24 = 24;
  static const double gutter = 20, gutterOnboarding = 24;
}

abstract final class Radii {
  static const double pill = 999, sheet = 28, cardLarge = 24, card = 20, tile = 16, input = 12, small = 10;
}

abstract final class Sizes {
  static const double touch = 48, primaryButton = 56, secondaryButton = 52, navBar = 52, toggleW = 52, toggleH = 32;
}

abstract final class Motion {
  static const state = Duration(milliseconds: 200);
  static const breatheIn = Duration(seconds: 4);
  static const breatheOut = Duration(seconds: 6);
}

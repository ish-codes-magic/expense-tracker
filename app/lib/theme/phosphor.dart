import 'package:flutter/widgets.dart';

/// The Phosphor icons the app uses, taken straight from the bundled font.
///
/// The phosphor_flutter package no longer compiles against current Flutter,
/// so the font files live in assets/fonts and the code points are declared
/// here. Add an icon by copying its code point from https://phosphoricons.com.
abstract final class Ph {
  static const arrowLeft = IconData(0xe058, fontFamily: 'Phosphor');
  static const arrowRight = IconData(0xe06c, fontFamily: 'Phosphor');
  static const camera = IconData(0xe10e, fontFamily: 'Phosphor');
  static const car = IconData(0xe112, fontFamily: 'Phosphor');
  static const caretRight = IconData(0xe13a, fontFamily: 'Phosphor');
  static const chartBar = IconData(0xe150, fontFamily: 'Phosphor');
  static const checkCircle = IconData(0xe184, fontFamily: 'Phosphor');
  static const circle = IconData(0xe18a, fontFamily: 'Phosphor');
  static const circleNotch = IconData(0xeb44, fontFamily: 'Phosphor');
  static const cloudArrowUp = IconData(0xe1ae, fontFamily: 'Phosphor');
  static const coffee = IconData(0xe1c2, fontFamily: 'Phosphor');
  static const currencyInr = IconData(0xe558, fontFamily: 'Phosphor');
  static const envelopeSimple = IconData(0xe218, fontFamily: 'Phosphor');
  static const export = IconData(0xeaf0, fontFamily: 'Phosphor');
  static const filePdf = IconData(0xe702, fontFamily: 'Phosphor');
  static const fingerprint = IconData(0xe23e, fontFamily: 'Phosphor');
  static const firstAid = IconData(0xe56e, fontFamily: 'Phosphor');
  static const gear = IconData(0xe270, fontFamily: 'Phosphor');
  static const house = IconData(0xe2c2, fontFamily: 'Phosphor');
  static const images = IconData(0xe836, fontFamily: 'Phosphor');
  static const lightning = IconData(0xe2de, fontFamily: 'Phosphor');
  static const listBullets = IconData(0xe2f2, fontFamily: 'Phosphor');
  static const magnifyingGlass = IconData(0xe30c, fontFamily: 'Phosphor');
  static const receipt = IconData(0xe3ec, fontFamily: 'Phosphor');
  static const shoppingBag = IconData(0xe416, fontFamily: 'Phosphor');
  static const shoppingCart = IconData(0xe41e, fontFamily: 'Phosphor');
  static const sparkle = IconData(0xe6a2, fontFamily: 'Phosphor');
  static const trash = IconData(0xe4a6, fontFamily: 'Phosphor');
  static const uploadSimple = IconData(0xe4c0, fontFamily: 'Phosphor');
  static const user = IconData(0xe4c2, fontFamily: 'Phosphor');
  static const wallet = IconData(0xe68a, fontFamily: 'Phosphor');
  static const x = IconData(0xe4f6, fontFamily: 'Phosphor');
}

/// Solid versions, for the few places the design fills an icon.
abstract final class PhFill {
  static const checkCircle = IconData(0xe184, fontFamily: 'PhosphorFill');
}

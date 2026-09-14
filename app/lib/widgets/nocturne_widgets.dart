import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../theme/nocturne.dart';

final messengerKey = GlobalKey<ScaffoldMessengerState>();

void showToast(String message) {
  messengerKey.currentState
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Noc.surface,
      elevation: 0,
      duration: const Duration(milliseconds: 2600),
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Noc.radiusMd),
        side: const BorderSide(color: Noc.n700),
      ),
      content: Row(children: [
        const Icon(PhosphorIconsFill.checkCircle, color: Noc.accent, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(message, style: const TextStyle(color: Noc.text, fontSize: 13))),
      ]),
    ));
}

/// A 1px rule that fades out over 48px at each end — a Nocturne signature.
class FadeRule extends StatelessWidget {
  const FadeRule({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final fade = constraints.maxWidth <= 96 ? 0.5 : 48 / constraints.maxWidth;
      return Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Noc.divider.withValues(alpha: 0), Noc.divider, Noc.divider, Noc.divider.withValues(alpha: 0)],
            stops: [0, fade, 1 - fade, 1],
          ),
        ),
      );
    });
  }
}

/// A row with a fading rule underneath.
class RuledRow extends StatelessWidget {
  const RuledRow({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.symmetric(vertical: 10)});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [Padding(padding: padding, child: child), const FadeRule()],
    );
    return onTap == null ? content : InkWell(onTap: onTap, child: content);
  }
}

class CircleIconButton extends StatelessWidget {
  const CircleIconButton({super.key, required this.icon, required this.onPressed, this.size = 36, this.tooltip});

  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      shape: const CircleBorder(side: BorderSide(color: Noc.divider)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(width: size, height: size, child: Icon(icon, size: 18, color: Noc.text)),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

enum NocButtonKind { primary, secondary, ghost }

/// Outlined button in the Nocturne style: primaries are an accent outline, never a fill.
class NocButton extends StatelessWidget {
  const NocButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.kind = NocButtonKind.primary,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    this.radius = Noc.radiusMd,
    this.foreground,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final NocButtonKind kind;
  final EdgeInsets padding;
  final double radius;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final color = foreground ??
        switch (kind) {
          NocButtonKind.primary || NocButtonKind.ghost => Noc.accent,
          NocButtonKind.secondary => Noc.text,
        };
    final border = switch (kind) {
      NocButtonKind.primary => const BorderSide(color: Noc.accent),
      NocButtonKind.secondary => const BorderSide(color: Noc.divider),
      NocButtonKind.ghost => BorderSide.none,
    };
    final tint = kind == NocButtonKind.secondary ? Noc.text : Noc.accent;
    return Opacity(
      opacity: onPressed == null ? 0.45 : 1,
      child: Material(
        color: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius), side: border),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          splashColor: tint.withValues(alpha: 0.22),
          highlightColor: tint.withValues(alpha: 0.10),
          child: Padding(
            padding: padding,
            child: IconTheme.merge(
              data: IconThemeData(color: color),
              child: DefaultTextStyle.merge(
                style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w500, height: 1.2),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class NocChip extends StatelessWidget {
  const NocChip({super.key, required this.label, required this.selected, required this.onTap, this.icon, this.expand = false});

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Noc.accent : Noc.n400;
    return Material(
      color: selected ? Noc.accent.withValues(alpha: 0.10) : Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Noc.radiusMd),
        side: BorderSide(color: selected ? Noc.accent : Noc.divider),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[Icon(icon, size: 14, color: color), const SizedBox(width: 6)],
              Text(label, style: TextStyle(color: color, fontSize: 12.5)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A 2px progress line; the fill glows when [glow] is set.
class GlowBar extends StatelessWidget {
  const GlowBar({super.key, required this.fraction, this.color = Noc.accent, this.glow = false});

  final double fraction;
  final Color color;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      decoration: BoxDecoration(color: Noc.n800, borderRadius: BorderRadius.circular(1)),
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: fraction.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(1),
            boxShadow: glow ? const [BoxShadow(color: Noc.accent, blurRadius: 10)] : null,
          ),
        ),
      ),
    );
  }
}

class Kicker extends StatelessWidget {
  const Kicker(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(fontSize: 11, letterSpacing: 1.1, color: Noc.accent),
      );
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: const TextStyle(fontSize: 12, letterSpacing: 1, color: Noc.n500, fontWeight: FontWeight.w500),
      );
}

class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, this.size = 36, this.radius = 10, this.iconSize = 18});

  final IconData icon;
  final double size;
  final double radius;
  final double iconSize;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: Noc.a900, borderRadius: BorderRadius.circular(radius)),
        child: Icon(icon, size: iconSize, color: Noc.a300),
      );
}

class SurfaceCard extends StatelessWidget {
  const SurfaceCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(12)});

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => Material(
        color: Noc.surface,
        borderRadius: BorderRadius.circular(Noc.radiusMd),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      );
}

/// Placeholder for a receipt photo: faint paper-like horizontal stripes.
class StripedPaper extends StatelessWidget {
  const StripedPaper({super.key, this.stripe = 8, this.child, this.radius = 10});

  final double stripe;
  final double radius;
  final Widget? child;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: Noc.n800),
            borderRadius: BorderRadius.circular(radius),
          ),
          child: CustomPaint(painter: _StripePainter(stripe), child: child),
        ),
      );
}

class _StripePainter extends CustomPainter {
  _StripePainter(this.stripe);

  final double stripe;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = Noc.surface);
    final paint = Paint()..color = Noc.n900;
    for (var y = 0.0; y < size.height; y += stripe * 2) {
      canvas.drawRect(Rect.fromLTWH(0, y, size.width, stripe), paint);
    }
  }

  @override
  bool shouldRepaint(_StripePainter oldDelegate) => oldDelegate.stripe != stripe;
}

class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.onBack, this.trailing, this.large = true});

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(children: [
        if (onBack != null) ...[
          CircleIconButton(icon: PhosphorIconsRegular.arrowLeft, onPressed: onBack, tooltip: 'Back'),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(
            title,
            style: large
                ? const TextStyle(fontSize: 22, fontWeight: FontWeight.w500, letterSpacing: -0.3)
                : const TextStyle(fontSize: 14),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ?trailing,
      ]),
    );
  }
}

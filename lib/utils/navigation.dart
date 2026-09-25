import 'package:flutter/material.dart';

Route<T> noAnimationRoute<T>(Widget page) {
  return PageRouteBuilder<T>(
    opaque: true,
    pageBuilder: (context, animation, secondaryAnimation) => page,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
  );
}
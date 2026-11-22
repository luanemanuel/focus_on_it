import 'package:flutter/widgets.dart';
import 'package:focus_on_it/focus_on_it.dart';

Widget buildSample() {
  return FocusOnIt(
    focusKey: GlobalKey(),
    onFocus: () {},
    child: const SizedBox.shrink(),
  );
}

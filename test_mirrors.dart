import 'dart:mirrors';
import 'package:euc/euc.dart' as euc;

void main() {
  var lib = currentMirrorSystem().findLibrary(#euc);
  for (var decl in lib.declarations.values) {
    print(MirrorSystem.getName(decl.simpleName));
  }
}

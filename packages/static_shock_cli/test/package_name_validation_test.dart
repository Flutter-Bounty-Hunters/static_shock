import 'package:static_shock_cli/src/package_name_validation.dart';
import 'package:test/test.dart';

void main() {
  group("Package name validation >", () {
    test("recognizes bad names", () {
      expect(
        PackageName.isValid("BADNAME"),
        isFalse,
      );

      expect(
        PackageName.isValid("bad-name"),
        isFalse,
      );

      expect(
        PackageName.isValid("_bad"),
        isFalse,
      );

      expect(
        PackageName.isValid("*bad"),
        isFalse,
      );

      expect(
        PackageName.isValid("0bad"),
        isFalse,
      );

      expect(
        PackageName.isValid("bad*name"),
        isFalse,
      );

      expect(
        PackageName.isValid("**"),
        isFalse,
      );
    });

    test("fixable names can be fixed", () {
      expect(
        PackageName.canFix("BADNAME"),
        isTrue,
      );
      expect(
        PackageName.fix("BADNAME"),
        "badname",
      );

      expect(
        PackageName.canFix("bad-name"),
        isTrue,
      );
      expect(
        PackageName.fix("bad-name"),
        "bad_name",
      );

      expect(
        PackageName.canFix("_bad"),
        isTrue,
      );
      expect(
        PackageName.fix("_bad"),
        "bad",
      );

      expect(
        PackageName.canFix("*bad"),
        isTrue,
      );
      expect(
        PackageName.fix("*bad"),
        "bad",
      );

      expect(
        PackageName.canFix("0bad"),
        isTrue,
      );
      expect(
        PackageName.fix("0bad"),
        "bad",
      );
    });

    test("non-fixable names cannot be fixed", () {
      expect(
        PackageName.canFix("001"),
        isFalse,
      );

      expect(
        PackageName.canFix("***"),
        isFalse,
      );

      expect(
        PackageName.canFix(""),
        isFalse,
      );
    });
  });
}

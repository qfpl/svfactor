{ mkDerivation, attoparsec, base, bifunctors, bytestring, charset
, deepseq, hedgehog, lens, parsec, parsers, semigroupoids
, semigroups, stdenv, tasty, tasty-hedgehog, tasty-hunit, text
, transformers, trifecta, utf8-string, vector
}:
mkDerivation {
  pname = "svfactor";
  version = "0.1";
  src = ./.;
  libraryHaskellDepends = [
    attoparsec base bifunctors bytestring charset deepseq lens parsec
    parsers semigroupoids semigroups text transformers trifecta
    utf8-string vector
  ];
  testHaskellDepends = [
    base bytestring hedgehog lens parsers semigroups tasty
    tasty-hedgehog tasty-hunit text trifecta utf8-string vector
  ];
  homepage = "https://github.com/qfpl/sv";
  description = "Syntax-preserving CSV manipulation";
  license = stdenv.lib.licenses.bsd3;
}

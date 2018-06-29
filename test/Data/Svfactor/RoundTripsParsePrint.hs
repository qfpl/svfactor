{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RankNTypes #-}

module Data.Svfactor.RoundTripsParsePrint (test_Roundtrips) where

import Control.Lens ((&), (.~))
import Data.ByteString (ByteString)
import qualified Data.ByteString.Builder as BSB
import qualified Data.ByteString.Lazy as LBS
import qualified Data.ByteString.UTF8 as UTF8
import Data.Text (Text)
import qualified Data.Text as Text
import qualified Data.Vector as V
import Hedgehog ((===), Property, Gen, forAll, property)
import qualified Hedgehog.Gen as Gen
import qualified Hedgehog.Range as Range
import Test.Tasty (TestName, TestTree, testGroup)
import Test.Tasty.Hedgehog (testProperty)
import Test.Tasty.HUnit ((@?=), testCase)
import Text.Parser.Char (CharParsing)
import Text.Trifecta (parseByteString)

import Data.Svfactor.Parse (trifectaResultToEither)
import Data.Svfactor.Generators
import Data.Svfactor.Syntax (Sv, Headedness, SpacedField, comma)
import Data.Svfactor.Parse (defaultParseOptions, headedness, encodeString, separatedValues)
import Data.Svfactor.Parse.Internal (spacedField)
import Data.Svfactor.Print (defaultPrintOptions, printSvText)
import Data.Svfactor.Print.Internal (printSpaced)
import Data.Svfactor.Text.Space (HorizontalSpace (Space, Tab), Spaces)
 
test_Roundtrips :: TestTree
test_Roundtrips =
  testGroup "Round trips" [
    csvRoundTrip
  , fieldRoundTrip
  ]

printAfterParseRoundTrip :: (forall m. CharParsing m => m a) -> (a -> ByteString) -> TestName -> ByteString -> TestTree
printAfterParseRoundTrip parser display name s =
  testCase name $
    fmap display (trifectaResultToEither $ parseByteString parser mempty s) @?= Right s

fieldRoundTrip :: TestTree
fieldRoundTrip =
  let sep = comma
      test =
        printAfterParseRoundTrip
        (spacedField sep UTF8.fromString :: CharParsing m => m (SpacedField ByteString))
        (LBS.toStrict . BSB.toLazyByteString . printSpaced defaultPrintOptions)
  in  testGroup "field" [
    test "empty" ""
  , test "unquoted" "wobble"
  , test "unquoted with space" "  wiggle "
  , test "single quoted" "'tortoise'"
  , test "single quoted with space" " 'turtle'   "
  , test "single quoted with escape outer" "\'\'\'c\'\'\'"
  , test "single quoted with escape in the middle" "\'  The char \'\'c\'\' is nice.\'"
  , test "double quoted" "\"honey badger\""
  , test "double quoted with space" "   \" sun bear\" "
  , test "double quoted with escape outer" "\"\"\"laser\"\"\""
  , test "double quoted with escape in the middle" "\"John \"\"The Duke\"\" Wayne\""
  ]

csvRoundTrip :: TestTree
csvRoundTrip = testProperty "roundtrip" prop_csvRoundTrip

prop_csvRoundTrip :: Property
prop_csvRoundTrip =
  let genSpace :: Gen HorizontalSpace
      genSpace = Gen.element [Space, Tab]
      genSpaces :: Gen Spaces
      genSpaces = V.fromList <$> Gen.list (Range.linear 0 10) genSpace
      genText :: Gen Text
      genText  = Gen.text (Range.linear 1 100) Gen.alphaNum
      gen = genSvWithHeadedness (pure comma) genSpaces genText
      mkOpts h = defaultParseOptions & headedness .~ h & encodeString .~ Text.pack
      parseCsv :: CharParsing m => Headedness -> m (Sv Text)
      parseCsv = separatedValues . mkOpts
      parse h = parseByteString (parseCsv h) mempty
  in  property $ do
    (c,h) <- forAll gen
    trifectaResultToEither (fmap printSvText (parse h (printSvText c))) === pure (printSvText c)

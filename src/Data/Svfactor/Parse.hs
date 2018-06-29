{-|
Module      : Data.Svfactor.Parse
Copyright   : (C) CSIRO 2017-2018
License     : BSD3
Maintainer  : George Wilson <george.wilson@data61.csiro.au>
Stability   : experimental
Portability : non-portable
-}

module Data.Svfactor.Parse (
  parseSv
, parseSv'
, parseSvFromFile
, parseSvFromFile'
, separatedValues

, module Data.Svfactor.Parse.Options
, SvParser (..)
, trifecta
, trifectaResultToEither
, attoparsecByteString
, attoparsecText
) where

import Control.Lens (view)
import Control.Monad.IO.Class (MonadIO, liftIO)
import qualified Data.Attoparsec.ByteString as BS (parseOnly)
import qualified Data.Attoparsec.Text as Text (parseOnly)
import Data.Bifunctor (first)
import Data.ByteString (ByteString)
import qualified Data.ByteString as BS
import Data.Text (Text)
import qualified Data.Text.IO as Text
import qualified Text.Trifecta as Trifecta

import Data.Svfactor.Syntax.Sv (Sv)
import Data.Svfactor.Parse.Internal (separatedValues)
import Data.Svfactor.Parse.Options

-- | Parse a 'ByteString' as an Sv.
--
-- This version uses Trifecta, hence it assumes its input is UTF-8 encoded.
parseSv :: ParseOptions ByteString -> ByteString -> Either ByteString (Sv ByteString)
parseSv = parseSv' trifecta

-- | Parse some text as an Sv.
--
-- This version lets you choose which parsing library to use by providing an
-- 'SvParser'. Common selections are 'trifecta' and 'attoparsecByteString'.
parseSv' :: SvParser s -> ParseOptions s -> s -> Either s (Sv s)
parseSv' svp opts s =
  let enc = view encodeString opts
  in  first enc $ runSvParser svp opts s

-- | Load a file and parse it as an 'Sv'.
--
-- This version uses Trifecta, hence it assumes its input is UTF-8 encoded.
parseSvFromFile :: MonadIO m => ParseOptions ByteString -> FilePath -> m (Either ByteString (Sv ByteString))
parseSvFromFile = parseSvFromFile' trifecta

-- | Load a file and parse it as an 'Sv'.
--
-- This version lets you choose which parsing library to use by providing an
-- 'SvParser'. Common selections are 'trifecta' and 'attoparsecByteString'.
parseSvFromFile' :: MonadIO m => SvParser s -> ParseOptions s -> FilePath -> m (Either s (Sv s))
parseSvFromFile' svp opts fp =
  let enc = view encodeString opts
  in  liftIO (first enc <$> runSvParserFromFile svp opts fp)

-- | Which parsing library should be used to parse the document?
--
-- The parser is written in terms of the @parsers@ library, meaning it can be
-- instantiated to several different parsing libraries. By default, we use
-- 'trifecta', because "Text.Trifecta"s error messages are so helpful.
-- 'attoparsecByteString' is faster though, if your input is ASCII and
  -- you care a lot about speed.
--
-- It is worth noting that Trifecta assumes UTF-8 encoding of the input data.
-- UTF-8 is backwards-compatible with 7-bit ASCII, so this will work for many
-- documents. However, not all documents are ASCII or UTF-8. For example, our
-- <https://github.com/qfpl/sv/blob/master/examples/csv/species.csv species.csv>
-- test file is Windows-1252, which is a non-ISO extension
-- of latin1 8-bit ASCII. For documents encoded as Windows-1252, Trifecta's
-- assumption is invalid and parse errors result.
-- 'Attoparsec' works fine for this character encoding, but it wouldn't work
-- well on a UTF-8 encoded document including non-ASCII characters.
data SvParser s = SvParser
  { runSvParser :: ParseOptions s -> s -> Either String (Sv s)
  , runSvParserFromFile :: ParseOptions s -> FilePath -> IO (Either String (Sv s))
  }

-- | An 'SvParser' that uses "Text.Trifecta". Trifecta assumes its input is UTF-8, and
-- provides helpful clang-style error messages.
trifecta :: SvParser ByteString
trifecta = SvParser
  { runSvParser = \opts bs -> trifectaResultToEither $ Trifecta.parseByteString (separatedValues opts) mempty bs
  , runSvParserFromFile = \opts fp -> trifectaResultToEither <$> Trifecta.parseFromFileEx (separatedValues opts) fp
  }

-- | An 'SvParser' that uses "Data.Attoparsec.ByteString". This is the fastest
-- provided 'SvParser', but it has poorer error messages.
attoparsecByteString :: SvParser ByteString
attoparsecByteString = SvParser
  { runSvParser = \opts bs -> BS.parseOnly (separatedValues opts) bs
  , runSvParserFromFile = \opts fp -> BS.parseOnly (separatedValues opts) <$> BS.readFile fp
  }

-- | An 'SvParser' that uses "Data.Attoparsec.Text". This is helpful if
-- your input is in the form of 'Text'.
attoparsecText :: SvParser Text
attoparsecText = SvParser
  { runSvParser = \opts t -> Text.parseOnly (separatedValues opts) t
  , runSvParserFromFile = \opts fp -> Text.parseOnly (separatedValues opts) <$> Text.readFile fp
  }

-- | Helper to convert "Text.Trifecta" 'Text.Trifecta.Result' to 'Either'.
trifectaResultToEither :: Trifecta.Result a -> Either String a
trifectaResultToEither result = case result of
  Trifecta.Success a -> Right a
  Trifecta.Failure e -> Left . show . Trifecta._errDoc $ e


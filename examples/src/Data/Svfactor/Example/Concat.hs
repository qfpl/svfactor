module Data.Svfactor.Example.Concat where

import Control.Applicative (Applicative ((<*>), pure), (<$>))
import Control.Lens ((&), (.~))
import Data.ByteString (ByteString)
import qualified Data.ByteString as BS
import Text.Trifecta (CharParsing, parseFromFile)
import System.Exit (exitFailure)

import Data.Svfactor.Syntax
import Data.Svfactor.Parse
import Data.Svfactor.Print

file, out1, out2 :: FilePath
file = "csv/concat.csv"
out1 = "csv/concat1.csv"
out2 = "csv/concat2.csv"

opts :: ParseOptions ByteString
opts = defaultParseOptions & endOnBlankLine .~ True

sv2 :: (CharParsing m) => ParseOptions s -> m (Sv s, Sv s)
sv2 o = (,) <$> separatedValues o <*> separatedValues o

parser :: CharParsing m => m (Sv ByteString, Sv ByteString)
parser = sv2 opts

main :: IO ()
main = do
  d <- parseFromFile parser file
  case d of
    Nothing -> exitFailure
    Just (csv1,csv2) -> do
      BS.writeFile out1 (printSv csv1)
      BS.writeFile out2 (printSv csv2)

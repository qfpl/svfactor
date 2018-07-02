{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE FunctionalDependencies #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE DeriveGeneric #-}

{-|
Module      : Data.Svfactor.Syntax.Field
Copyright   : (C) CSIRO 2017-2018
License     : BSD3
Maintainer  : George Wilson <george.wilson@data61.csiro.au>
Stability   : experimental
Portability : non-portable
-}

module Data.Svfactor.Syntax.Field (
    Field (Unquoted, Quoted)
  , SpacedField
  , Spaced (Spaced)
  , HasFields (fields)
  , AsField (_Field, _Unquoted, _Quoted)
  , unescapedField
  , foldField
  , fieldContents
) where

import Control.Applicative ((<$>))
import Control.DeepSeq (NFData)
import Control.Lens (Lens, Prism', Traversal, lens, prism)
import Data.Foldable (Foldable (foldMap))
import Data.Functor (Functor (fmap))
import Data.Traversable (Traversable (traverse))
import GHC.Generics (Generic)

import Data.Svfactor.Text.Escape (Unescaped (Unescaped, getRawUnescaped))
import Data.Svfactor.Text.Quote (Quote)
import Data.Svfactor.Text.Space (Spaced (Spaced))

-- | A 'Field' is a single cell from a CSV document.
--
-- Its value is either 'Quoted', which indicates the type of quote
-- surrounding the value, or it is 'Unquoted', containing only the value.
data Field s =
    Unquoted s
  | Quoted Quote (Unescaped s)
  deriving (Eq, Ord, Show, Generic)

instance NFData s => NFData (Field s)

instance Functor Field where
  fmap f fi = case fi of
    Unquoted s -> Unquoted (f s)
    Quoted q v -> Quoted q (fmap f v)

instance Foldable Field where
  foldMap f fi = case fi of
    Unquoted s -> f s
    Quoted _ v -> foldMap f v

instance Traversable Field where
  traverse f fi = case fi of
    Unquoted s -> Unquoted <$> f s
    Quoted q v -> Quoted q <$> traverse f v

-- | 'Field's are often surrounded by spaces
type SpacedField a = Spaced (Field a)

-- | Classy prisms for 'Field'
class (HasFields s s a a) => AsField s a | s -> a where
  _Field :: Prism' s (Field a)
  _Unquoted :: Prism' s a
  _Quoted :: Prism' s (Quote, Unescaped a)
  _Unquoted = _Field . _Unquoted
  {-# INLINE _Unquoted #-}
  _Quoted = _Field . _Quoted
  {-# INLINE _Quoted #-}

instance AsField (Field a) a where
  _Field = id
  {-# INLINE _Field #-}
  _Unquoted = prism Unquoted
    (\x -> case x of
      Unquoted y -> Right y
      _          -> Left x
    )
  {-# INLINE _Unquoted #-}
  _Quoted = prism (uncurry Quoted)
    (\x -> case x of
      Quoted y z -> Right (y,z)
      _          -> Left x
    )
  {-# INLINE _Quoted #-}

-- | Classy 'Traversal' for things containing 'Field's
class HasFields c d s t | c -> s, d -> t, c t -> d, d s -> c where
  fields :: Traversal c d (Field s) (Field t)

instance HasFields (Field s) (Field t) s t where
  fields = id
  {-# INLINE fields #-}

-- | Build a quoted field with a normal string
unescapedField :: Quote -> s -> Field s
unescapedField q s = Quoted q (Unescaped s)

-- | The catamorphism for @Field'@
foldField :: (s -> b) -> (Quote -> Unescaped s -> b) -> Field s -> b
foldField u q fi = case fi of
  Unquoted s -> u s
  Quoted a b -> q a b

-- | Lens into the contents of a Field, regardless of whether it's quoted or unquoted
fieldContents :: Lens (Field s) (Field t) s t
fieldContents =
  lens (foldField id (const getRawUnescaped)) $ \f b -> case f of
    Unquoted _ -> Unquoted b
    Quoted q _ -> Quoted q (Unescaped b)

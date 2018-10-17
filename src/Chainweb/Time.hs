{-# LANGUAGE DeriveGeneric #-}
{-# LANGUAGE DerivingStrategies #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE GADTs #-}
{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE UndecidableInstances #-}

-- |
-- Module: Chainweb.Time
-- Copyright: Copyright © 2018 Kadena LLC.
-- License: MIT
-- Maintainer: Lars Kuhtz <lars@kadena.io>
-- Stability: experimental
--
-- A time library with a focus on supporting different numeric types for
-- representing time and time spans. This is useful for defining time
-- operations and serialization down to the bit level, including potential
-- arithmetic overflows.
--
-- Precision is fixed to microseconds.
--
module Chainweb.Time
(
-- * TimeSpan
  TimeSpan(..)
, encodeTimeSpan
, decodeTimeSpan
, castTimeSpan
, maybeCastTimeSpan
, ceilingTimeSpan
, floorTimeSpan
, scaleTimeSpan
, addTimeSpan

-- * Time
, Time(..)
, minTime
, maxTime
, encodeTime
, decodeTime
, castTime
, maybeCastTime
, ceilingTime
, floorTime
, getCurrentTimeIntegral
, epoche

-- * TimeSpan values
, microsecond
, millisecond
, second
, minute
, hour
, day
) where

import Data.Aeson (ToJSON, FromJSON)
import Data.Bytes.Get
import Data.Bytes.Put
import Data.Bytes.Signed
import Data.Hashable (Hashable)
import Data.Int
import Data.Kind
import Data.Time.Clock.POSIX

import GHC.Generics


-- internal imports

import Numeric.AffineSpace
import Chainweb.Utils
import Numeric.Additive
import Numeric.Cast

-- -------------------------------------------------------------------------- --
-- TimeSpan

-- | The internal unit is microseconds.
--
newtype TimeSpan :: Type -> Type where
    TimeSpan :: a -> TimeSpan a
    deriving (Show, Eq, Ord, Generic)
    deriving newtype
        ( AdditiveSemigroup, AdditiveAbelianSemigroup, AdditiveMonoid
        , AdditiveGroup, FractionalVectorSpace
        , Enum, Bounded, Hashable, ToJSON, FromJSON
        )

encodeTimeSpan :: MonadPut m => TimeSpan Int64 -> m ()
encodeTimeSpan (TimeSpan a) = putWord64le $ unsigned a
{-# INLINE encodeTimeSpan #-}

decodeTimeSpan :: MonadGet m => m (TimeSpan Int64)
decodeTimeSpan = TimeSpan . signed <$> getWord64le
{-# INLINE decodeTimeSpan #-}

castTimeSpan :: NumCast a b => TimeSpan a -> TimeSpan b
castTimeSpan (TimeSpan a) = TimeSpan $ numCast a
{-# INLINE castTimeSpan #-}

maybeCastTimeSpan :: MaybeNumCast a b => TimeSpan a -> Maybe (TimeSpan b)
maybeCastTimeSpan (TimeSpan a) = TimeSpan <$> maybeNumCast a
{-# INLINE maybeCastTimeSpan #-}

ceilingTimeSpan :: RealFrac a => Integral b => TimeSpan a -> TimeSpan b
ceilingTimeSpan (TimeSpan a) = TimeSpan (ceiling a)
{-# INLINE ceilingTimeSpan #-}

floorTimeSpan :: RealFrac a => Integral b => TimeSpan a -> TimeSpan b
floorTimeSpan (TimeSpan a) = TimeSpan (floor a)
{-# INLINE floorTimeSpan #-}

scaleTimeSpan :: Integral a => Num b => a -> TimeSpan b -> TimeSpan b
scaleTimeSpan scalar (TimeSpan t) = TimeSpan (fromIntegral scalar * t)
{-# INLINE scaleTimeSpan #-}

addTimeSpan :: Num a => TimeSpan a -> TimeSpan a -> TimeSpan a
addTimeSpan (TimeSpan a) (TimeSpan b) = TimeSpan (a + b)
{-# INLINE addTimeSpan #-}

-- -------------------------------------------------------------------------- --
-- Time

-- | Time is measured as microseconds relative to UNIX Epoche
--
newtype Time a = Time (TimeSpan a)
    deriving (Show, Eq, Ord, Generic)
    deriving newtype (Enum, Bounded, ToJSON, FromJSON, Hashable)

instance AdditiveGroup (TimeSpan a) => LeftTorsor (Time a) where
    type Diff (Time a) = TimeSpan a
    add s (Time t) = Time (s `plus` t)
    diff (Time t₁) (Time t₂) = t₁ `minus` t₂
    {-# INLINE add #-}
    {-# INLINE diff #-}

epoche :: Num a => Time a
epoche = Time (TimeSpan 0)
{-# INLINE epoche #-}

getCurrentTimeIntegral :: Integral a => IO (Time a)
getCurrentTimeIntegral = do
    -- returns POSIX seconds with picosecond precision
    t <- getPOSIXTime
    return $ Time $ TimeSpan (round $ t * 1000000)

encodeTime :: MonadPut m => Time Int64 -> m ()
encodeTime (Time a) = encodeTimeSpan a
{-# INLINE encodeTime #-}

decodeTime :: MonadGet m => m (Time Int64)
decodeTime  = Time <$> decodeTimeSpan
{-# INLINE decodeTime #-}

castTime :: NumCast a b => Time a -> Time b
castTime (Time a) = Time $ castTimeSpan a
{-# INLINE castTime #-}

maybeCastTime :: MaybeNumCast a b => Time a -> Maybe (Time b)
maybeCastTime (Time a) = Time <$> maybeCastTimeSpan a
{-# INLINE maybeCastTime #-}

ceilingTime :: RealFrac a => Integral b => Time a -> Time b
ceilingTime (Time a) = Time (ceilingTimeSpan a)
{-# INLINE ceilingTime #-}

floorTime :: RealFrac a => Integral b => Time a -> Time b
floorTime (Time a) = Time (floorTimeSpan a)
{-# INLINE floorTime #-}

minTime :: Bounded a => Time a
minTime = minBound
{-# INLINE maxTime #-}

maxTime :: Bounded a => Time a
maxTime = maxBound
{-# INLINE minTime #-}

-- -------------------------------------------------------------------------- --
-- Time Span Values

microsecond :: Num a => TimeSpan a
microsecond = TimeSpan 1
{-# INLINE microsecond #-}

millisecond :: Num a => TimeSpan a
millisecond = TimeSpan kilo
{-# INLINE millisecond #-}

second :: Num a => TimeSpan a
second = TimeSpan mega
{-# INLINE second #-}

minute :: Num a => TimeSpan a
minute = TimeSpan $ mega * 60
{-# INLINE minute #-}

hour :: Num a => TimeSpan a
hour = TimeSpan $ mega * 3600
{-# INLINE hour #-}

day :: Num a => TimeSpan a
day = TimeSpan $ mega * 24 * 3600
{-# INLINE day #-}

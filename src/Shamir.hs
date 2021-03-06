{-|
Module      : Shamir
Description : Shamir secret sharing scheme using Lagrange interpolation
Copyright   : (c) 2019 Adjoint Inc.
License     : MIT
Maintainer  : "Adjoint Inc (info@adjoint.io)"
-}

{-# LANGUAGE DeriveAnyClass, DeriveGeneric, ParallelListComp #-}
--
module Shamir
  ( shareSecret
  , reconstructSecret
  ) where

import           Control.Monad.Random (MonadRandom)
import           Data.Euclidean       (quot)
import           Data.Field.Galois    (PrimeField(..), rnd)
import           Data.Poly            (VPoly, deriv, eval, scale, toPoly)
import qualified Data.Vector          as V
import           Protolude            hiding (quot)

data Share f = Share
  { shareX :: f
  , shareY :: f
  } deriving (Show, Eq, Generic, NFData)

-- | Create shares from a secret
shareSecret :: (MonadRandom m, PrimeField f) => f -> Int -> Int -> m [Share f]
shareSecret secret k n
  | k <= 0 || n <= 0 = panic "k and n must be positive integers"
  | k > n = panic "k cannot be greater than n"
  | otherwise = do
    rndVs <- replicateM (k-1) rnd
    let poly = toPoly . V.fromList $ coeffs
        coeffs = secret : rndVs
    pure $ (\x -> Share (fromIntegral x) (eval poly (fromIntegral x))) <$> [1..n]

-- | Reconstruct secret using Lagrange interpolation. Solve for f(0).
reconstructSecret :: forall f. PrimeField f => [Share f] -> f
reconstructSecret shares = eval (lagrangeInterpolate shares) 0
  where
    lagrangeInterpolate :: [Share f] -> VPoly f
    lagrangeInterpolate xys = sum
      [ scale 0 f (roots `quot` root x)
      | f <- zipWith (/) ys phis
      | x <- xs
      ]
      where
        xs, ys :: [f]
        (xs,ys) = foldr (\(Share a b) ~(as,bs) -> (a:as,b:bs)) ([],[]) xys
        phis :: [f]
        phis = map (eval (deriv roots)) xs
        roots :: VPoly f
        roots = foldl' (\acc xi -> acc * root xi) 1 xs   -- (X - x_0) * ... * (X - x_{n-1})
        root xi = toPoly . V.fromList $ [-xi,  1]        -- (X - x_i)

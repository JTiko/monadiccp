{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE MultiParamTypeClasses #-}

-- |This module provides a Herbrand solver as a monad transformer.
--
--  The constraints offered are "Either (Unify t) (Constraint m)"
--  where "m" is the transformed solver. Hence, both unification
--  and the underlying solver's constraints are available.
--
--  The terms offered are "L t1" where "t1" is the Herbrand solver's
--  terms and "R t2" where "t2" are the underlying solver's types.
--  
module Control.CP.Herbrand.HerbrandT where

import Control.Monad.Trans
import Control.Monad.State.Lazy

import Control.CP.Solver
import Control.CP.Herbrand.Herbrand (HState, Unify, HTerm,initState,addH,newvarH)

newtype HerbrandT t m a = HerbrandT { unHT :: StateT (HState t) m a }
  deriving (MonadTrans, Monad, MonadState (HState t))

instance (Solver s, HTerm t) => Solver (HerbrandT t s) where
  type Constraint (HerbrandT t s)  = Either (Unify t) (Constraint s)
  type Label      (HerbrandT t s)  = (HState t, Label s)
  add (Left  c)  = addH c
  add (Right c)  = lift $ add c
  mark           = do l <- get
                      r <- lift $ mark
                      return (l,r)
  goto (l,r)     = put l >> (lift $ goto r)
  run            = run . flip evalStateT initState . unHT

data L a = L a
data R a = R a

instance (HTerm t, Solver s) => Term (HerbrandT t s) (L t) where
  newvar  = newvarH >>= return . L 

instance (HTerm t, Solver s, Term s st) => Term (HerbrandT t s) (R st) where
  newvar  = lift newvar >>= return . R

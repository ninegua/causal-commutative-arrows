{-# LANGUAGE GADTs, TypeOperators, KindSignatures #-}
{-# OPTIONS_GHC -fwarn-incomplete-patterns #-}

module Control.CCA.Instances where

import Control.Category
import Control.Arrow

import Prelude hiding ((.), init, id)

class ArrowLoop arr => ArrowInit arr where
  init :: a -> (a `arr` a)

-- loopB-based CCA normal form
data CCNF_B :: * -> * -> * where
   ArrB   :: (a -> b) -> CCNF_B a b
   LoopB :: ((a, (c, d)) -> (b, (c, d))) -> d -> CCNF_B a b

-- CCNF_B is an instance of ArrowInit (and hence of the superclasses
-- ArrowLoop, Arrow and Category)
instance Category CCNF_B where
   id = ArrB id
   {-# INLINE id #-}

   ArrB g    . ArrB f    = ArrB (g . f)
   ArrB g    . LoopB f i = LoopB (\a -> let (x,y) = f a in (g x, y)) i
   LoopB f i . ArrB h    = LoopB (\ ~(x,y) -> f (h x, y)) i
   LoopB f i . LoopB g j = LoopB
      ((\ ~(a, ((b, d), (c, e))) ->
         let (a', b') = g (a, (d, e))
             ((e'',(a'',b'')),(c'',d'')) = (f (a', (b, c)), b')
         in (e'',((a'',c''),(b'',d'')))))
      (i,j)
   {-# INLINE (.) #-}

instance Arrow CCNF_B where
   arr = \f -> ArrB (arr f)
   {-# INLINE arr #-}

   first (ArrB f) = ArrB (\ ~(x,y) -> (f x, y))
   first (LoopB f i) = LoopB (\ ~((a, b), c) ->
                               let (a', b') = f (a, c)
                               in ((a', b), b')) i
   {-# INLINE first #-}

instance ArrowLoop CCNF_B where
   loop (ArrB f)  = LoopB (\ ~(a,(b,c)) ->
                            let ((a',b'),c') = (f (a,b),c)
                            in (a',(b',c'))) ()
   loop (LoopB f i) = LoopB (arr
                             (\ ~(a, ((b, d), (c, e))) ->
                               let (((a', b'), (d', e'))) = (f ((a, b), (d, e)))
                               in (a', ((b', d'), (c, e')))))
                      ((), i)
   {-# INLINE loop #-}

-- evaluate a term in CCNF_B normal form at an ArrowInit instance
observeB :: (ArrowInit arr) => CCNF_B a b -> (a `arr` b)
observeB (ArrB f) = arr f
observeB (LoopB f i) = loop (arr f >>> second (second (init i)))
{-# INLINE observeB #-}

-- loopD-based CCA normal form
data CCNF_D :: * -> * -> * where
   ArrD   :: (a -> b) -> CCNF_D a b
   LoopD :: e -> ((b,e) -> (c,e)) -> CCNF_D b c

-- evaluate a term in CCNF_D normal form at an ArrowInit instance
observeD :: ArrowInit arr => CCNF_D a b -> (a `arr` b)
observeD (ArrD f) = arr f
observeD (LoopD i f) = loop (arr f >>> second (init i))
{-# INLINE observeD #-}

-- apply a normalized (CCNF_D) computation to transform a stream
applyCCNF_D :: CCNF_D a b -> [a] -> [b]
applyCCNF_D (ArrD f) = map f
applyCCNF_D (LoopD i f) = runCCNF i f
  where
   -- from Section 6 of the ICFP paper
   runCCNF :: e -> ((b,e) -> (c,e)) -> [b] -> [c]
   runCCNF i f = g i
     where g i (x:xs) = let (y, i') = f (x, i)
                        in y : g i' xs


-- CCNF_D is an instance of ArrowInit (and hence of the superclasses
-- ArrowLoop, Arrow and Category)
-- (adapted from Paul Liu's dissertation)
instance Category CCNF_D where
   id = ArrD id
   {-# INLINE id #-}

   ArrD g    . ArrD f    = ArrD (g . f)
   LoopD i g . ArrD f    = LoopD i (g . first f)
   ArrD g    . LoopD i f = LoopD i (first g . f)
   LoopD j g . LoopD i f = LoopD (i, j)
                           (\ ~(a,(b,c)) ->
                             let ((x , y) ) = (f (a,b)) in
                             let (x', y') =  g (x, c) in
                             (x', (y, y')))
   {-# INLINE (.) #-}
  
instance Arrow CCNF_D where
   arr = ArrD
   {-# INLINE arr #-}

   first (ArrD f) = ArrD (first f)
   first (LoopD i f) = LoopD i (\ ~((x , y), z) ->
                                 let (x', y') =  f (x , z)
                                 in ((x', y), y'))
   {-# INLINE first #-}

instance ArrowLoop CCNF_D where
   loop (ArrD f ) = ArrD (trace f )
   loop (LoopD i f) = LoopD i (trace
                               ((\f ~((x , y), z) ->
                                  let ((x', y'), z') = f ((x , z ), y)
                                  in ((x', z'), y')) f))
   {-# INLINE loop #-}


instance ArrowInit CCNF_B where
   init = \i -> LoopB ((\ ~(b,(a,c)) -> (c,(a,b)))) i
   {-# INLINE init #-}

instance ArrowInit CCNF_D where
   init i = LoopD i swap
   {-# INLINE init #-}

-- auxiliary definitions
trace :: ((b, d) -> (c, d)) -> b -> c
trace = \f b -> let (c, d) = f (b, d) in c
{-# INLINE trace #-}

swap ::   (a,b) -> (b,a)
swap = \ ~(a,b) -> (b,a)
{-# INLINE swap #-}

dup :: a -> (a,a)
dup = \a -> (a,a)
{-# INLINE dup #-}

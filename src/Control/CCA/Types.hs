module Control.CCA.Types where

import Control.Arrow 
import Prelude hiding (init)

class (Arrow a, ArrowLoop a) => ArrowInit a where
  init :: b -> a b b
  loopD :: e -> ((b, e) -> (c, e)) -> a b c 
  loopD i f = loop (arr f >>> second (init i))

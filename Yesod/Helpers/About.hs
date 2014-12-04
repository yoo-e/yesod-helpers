{-# LANGUAGE ScopedTypeVariables #-}
module Yesod.Helpers.About where

import Language.Haskell.TH
import System.Process                       (readProcessWithExitCode)
import System.Environment                   (lookupEnv)
import Control.Monad                        (liftM)
import Data.Time                            (getCurrentTime)
import Data.Maybe                           (fromMaybe)
import Control.Exception                    (handle)

gitRevision :: Q Exp
gitRevision = (stringE . init) =<<
                (runIO $ handle (\(_ :: IOError) -> return "<unknown>\n") $
                    liftM (\(_, x, _) -> if null x then "<unknown>\n" else x) $
                    readProcessWithExitCode "git" ["rev-parse", "HEAD"] "")

gitVersion :: Q Exp
gitVersion = (stringE . init) =<<
            (runIO $ handle (\(_ :: IOError)-> return "<unknown>\n") $
                liftM (\(_, x, _) -> if null x then "<unknown>\n" else x) $
                readProcessWithExitCode "git" ["describe", "HEAD", "--tags"] "")

buildTime :: Q Exp
buildTime = stringE =<< (runIO $ liftM show $ getCurrentTime)

buildUser :: Q Exp
buildUser = stringE =<<
                (runIO $ liftM (fromMaybe "<unknown>") $
                    lookupEnv "USER" >>= maybe (lookupEnv "USERNAME") (return . Just))

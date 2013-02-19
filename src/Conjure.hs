{-# LANGUAGE ScopedTypeVariables #-}

module Conjure ( getConjureMode, runConjureMode ) where

import System.Environment ( getArgs )
import qualified Data.Text.IO as T

import Paths_conjure_cp ( getBinDir )
import Conjure.Mode
import Language.E
import Language.E.Pipeline.ReadIn ( readSpecFromFile, writeSpec, dropExtEssence )

-- for RefineParam
import Language.E.Pipeline.RedArrow ( redArrow )

-- for TranslateSolution
import Language.E.Up ( translateSolution )

-- for DFAll
import Language.E.Pipeline.ConjureAll ( conjureWithMode )
import Language.E.Pipeline.Driver ( driverConjure, driverConjureSingle )

-- for prettify
import Language.E.Pipeline.AtMostOneSuchThat ( atMostOneSuchThat )

rulesdbLoc :: IO FilePath
rulesdbLoc = liftM (++ "/conjure.rulesdb") getBinDir

getRulesDB :: IO RulesDB
getRulesDB = decodeFromFile =<< rulesdbLoc

getConjureMode :: IO (Maybe ConjureMode)
getConjureMode = (parseArgs . parseGenericArgs) `fmap` getArgs

runConjureMode :: ConjureMode -> IO ()
runConjureMode ModeUnknown = error "Unknown mode"
runConjureMode (ModeDiff pathIn1 pathIn2) = do
    Spec _ in1 <- readSpecFromFile pathIn1
    Spec _ in2 <- readSpecFromFile pathIn2
    if sort (statementAsList in1) == sort (statementAsList in2)
        then return ()
        else error "Files differ."
runConjureMode (ModeRefineParam pathInEssence pathInParam pathInEprime pathOutParam) = do
    inEssence <- readSpecFromFile pathInEssence
    inParam   <- readSpecFromFile pathInParam
    inEprime  <- readSpecFromFile pathInEprime
    inLogs    <- T.readFile (pathInEprime ++ ".logs")
    driverConjureSingle False pathOutParam
        [runCompESingle "refineParam" $ redArrow inEssence inParam inEprime inLogs]
runConjureMode (ModeTranslateSolution pathInEssence pathInParam
                                      pathInEprime pathInEprimeParam pathInEprimeSolution
                                      pathOutSolution) =
    translateSolution pathInEssence pathInParam
                      pathInEprime pathInEprimeParam pathInEprimeSolution
                      pathOutSolution
runConjureMode (ModePrettify pathInp pathOut) = do
    inp <- readSpecFromFile pathInp
    writeSpec pathOut (atMostOneSuchThat inp)
runConjureMode mode@(ModeDFAll pathInEssence) = do
    seed <- getStdGen
    (ruleReprs, ruleRefns) <- getRulesDB
    inEssence <- readSpecFromFile pathInEssence
    driverConjure
        (conjureWithMode seed mode)
        (dropExtEssence pathInEssence)
        ruleReprs ruleRefns inEssence
runConjureMode mode@(ModeSingleOutput _ pathInEssence pathOutEprime) = do
    seed <- getStdGen
    (ruleReprs, ruleRefns) <- getRulesDB
    inEssence <- readSpecFromFile pathInEssence
    driverConjureSingle True
        pathOutEprime
        (conjureWithMode seed mode ruleReprs ruleRefns inEssence)



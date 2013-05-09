{-# LANGUAGE OverloadedStrings  #-}
module Language.E.Up.IO (
     getSpecs
    ,getSpecsM
    ,getSpecMaybe
    ,getSpec
    ,getSpec'
    ,getFiles
    ,getTestSpecs
) where

import Language.E
import Language.E.Pipeline.ReadIn(readSpec)
import Language.E.Up.ReduceSpec
import Language.E.Up.Debug


import qualified Data.Text as T
import qualified Data.Text.IO as T

import System.FilePath
import System.Directory (doesFileExist)

type Essence              = Spec
type Eprime               = Spec
type ESolution            = Spec
type EssenceWithParamOnly = Spec
type Param                = Spec
type EssenceParam         = Spec
type Logs                 = [Text]

getSpec ::  FilePath -> IO Spec
getSpec = getSpec' True

getSpecMaybe :: Maybe FilePath -> Maybe (IO Spec)
getSpecMaybe (Just f) = Just (getSpec f)
getSpecMaybe Nothing = Nothing 

getSpec' ::  Bool -> FilePath -> IO Spec
getSpec' removeContraints filepath = do
    b <- doesFileExist filepath 
    if not b 
    then userErr ("File Not Found:" <+> pretty filepath <+> "does not exist")
    else do
        (fp,txt) <-  pairWithContents filepath

        -- I don't need any of the constraints, speed up running the test lot
        let txt' = if removeContraints then
                       onlyPreamble  txt
                    else txt
        handleInIOSingle =<< runCompEIOSingle
                    "Parsing problem specification"
                    (readSpec (fp,txt') )

        where 
            stripComments = T.unlines . map (T.takeWhile (/= '$')) . T.lines
            discardAfter t = fst . T.breakOn t
            onlyPreamble
                = discardAfter "maximising"
                . discardAfter "maximizing"
                . discardAfter "minimising"
                . discardAfter "minimizing"
                . discardAfter "such that"
                . stripComments

getSpecs :: (FilePath, FilePath, FilePath, Maybe FilePath,Maybe FilePath) 
         -> IO (Eprime, ESolution, Essence,EssenceWithParamOnly,Logs)
getSpecs (specF, solF, orgF,paramF,orgParamF)= do
    let param    = getSpecMaybe paramF
    let orgParam = getSpecMaybe orgParamF

    let logsF = addExtension specF "logs"
    logs <- liftM T.lines (T.readFile logsF)

    spec  <- getSpec specF >>= introduceParams param >>= reduceSpec >>= simSpecMaybe param >>= removeNegatives
    sol   <- getSpec solF  >>= removeNegatives >>= removeIndexRanges
    orgP  <- getSpec orgF  >>= introduceParams orgParam
    org   <- reduceSpec  orgP
    return (spec,sol,org,orgP,logs)

getSpecsM :: (Monad m) => (Eprime,ESolution,Essence,Maybe Param,Maybe EssenceParam,Logs) -> m (Eprime, ESolution, Essence,EssenceWithParamOnly,Logs)
getSpecsM (spec', sol', org',param',orgParam',logs) = do


    spec  <- introduceParams' param' spec' >>= reduceSpec  >>= simSpecMaybe param' >>= removeNegatives
    sol   <- removeNegatives sol' >>= removeIndexRanges
    orgP  <- introduceParams' orgParam' org'
    org   <- reduceSpec orgP
    return (spec,sol,org,orgP,logs)


getTestSpecs :: (FilePath, FilePath, FilePath, Maybe FilePath, Maybe FilePath) 
             -> IO (Eprime, ESolution, Essence,EssenceWithParamOnly)
getTestSpecs (specF, solF, orgF,paramF,orgParamF) = do
    param    <- getTestSpecMaybe paramF
    orgParam1 <- getTestSpecMaybe orgParamF
    let orgParam = getOrgParam param orgParam1

    spec  <- getSpec specF >>= introduceParams param >>= reduceSpec >>= simSpecMaybe param >>= removeNegatives
    sol   <- getSpec solF  >>= removeNegatives >>= removeIndexRanges
    orgP  <- getSpec orgF  >>= introduceParams orgParam
    org   <- reduceSpec  orgP
    return (spec,sol,org,orgP)

    where
    getOrgParam :: Maybe a -> Maybe a -> Maybe a
    getOrgParam _   orgParam@(Just _)  = orgParam
    getOrgParam param@(Just _) Nothing = param
    getOrgParam Nothing Nothing        = Nothing

getTestSpecMaybe :: Maybe FilePath -> IO (Maybe (IO Spec))
getTestSpecMaybe (Just f) = do 
    b <- doesFileExist f
    if b then 
         return $  (Just . getSpec) f 
    else 
        return Nothing

getTestSpecMaybe Nothing = return Nothing


getFiles :: String -> String ->  Int -> (FilePath, FilePath, FilePath,Maybe FilePath,Maybe FilePath)
getFiles base name n =
   let spec = addExtension (joinPath [base,name, zeroPad n]) "eprime" in
   (spec
   ,addExtension spec "solution"
   ,addExtension (joinPath [base,name]) "essence"
   ,Just $ addExtension (joinPath [base,name,takeBaseName name]) "param"
   ,Just $ addExtension (joinPath [base,name,takeBaseName name]) "essence-param"
   )


-- Only need to simplify the expressions if there are parameters in the expressions.
simSpecMaybe :: Monad m => Maybe a -> Spec -> m Spec
simSpecMaybe Nothing s = return s
simSpecMaybe (Just _) s = simSpec s


zeroPad :: Int -> String
zeroPad n = replicate (4 - length sn) '0'  ++ sn
 where sn = show n

_bug :: String -> [E] -> t
_bug  s = upBug  ("Up.IO: " ++ s)
_bugi :: (Show a) => String -> (a, [E]) -> t
_bugi s = upBugi ("Up.IO: " ++ s )
_bugg :: String -> t
_bugg s = _bug s []


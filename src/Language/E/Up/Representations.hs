{-# LANGUAGE QuasiQuotes, ViewPatterns, OverloadedStrings  #-}
module Language.E.Up.Representations(
     leafRep, getBranch
    , runBranchFuncs
    , LeafFunc, BranchFunc
    , Before, After
    , RepName, isBranchRep, noRep
    
    -- for debuging
    , setOccurrenceRep, matrix1DRep, partitionMSetOfSetsRep
    ) where

import Language.E
import Language.E.Up.Data
import Language.E.Up.Common(wrapInMatrix,unwrapMatrix)
import Language.E.Up.Debug

-- Types 
type LeafFunc   = (VarData ->  E)
type BranchFunc = (VarData ->  VarData)
type Before     = (VarData -> [VarData])
type After      = (VarData -> [VarData] -> VarData)
type RepName    = String


leafRep ::  String -> LeafFunc
leafRep kind =
    case kind of
      "SetExplicit"                   -> explicitRep
      "MSetExplicit"                  -> explicitRep
      "SetOccurrence"                 -> setOccurrenceRep
      "Matrix1D"                      -> matrix1DRep
      "RelationIntMatrix2"            -> relationIntMatrix2Rep
      "SetExplicitVarSizeWithDefault" -> setExplicitVarSizeWithDefaultRep
      _                               -> noRep


noRep :: VarData -> E
noRep  = vEssence

{- Sets -}

explicitRep :: VarData -> E
explicitRep VarData{vEssence=e} = e


setOccurrenceRep :: VarData -> E
setOccurrenceRep VarData{vIndexes=[ix],
  vEssence=[xMatch| vs :=  value.matrix.values |]} =
    wrapInMatrix .  map (toIntLit . fst) . onlySelectedValues . zip ix $ vs

-- CHECK should not really need this
setOccurrenceRep v@VarData{vIndexes=ix,
  vEssence=[xMatch| vs :=  value.matrix.values |]} =
    wrapInMatrix $ map (\f -> setOccurrenceRep v{vIndexes=tail ix, vEssence=f} ) vs

setOccurrenceRep v = error $  "setOccurrenceRep " ++  (show . pretty) v

setExplicitVarSizeWithDefaultRep :: VarData -> E
setExplicitVarSizeWithDefaultRep VarData{vEssence=e,vBounds=bs} = 
    wrapInMatrix . mapMaybe (removeIt $ toRemove bs) $ (unwrapMatrix e)

    where 
    toRemove :: [Integer] -> Integer
    toRemove (b:_) = b
    toRemove []    = _bugg "setExplicitVarSizeWithDefaultRep no bounds" 

    removeIt :: Integer -> E -> Maybe E 
    removeIt toRemove f@[xMatch| [Prim (I i)] := value.literal |] =
       if i == toRemove then Nothing else Just f

{- Relations -}

relationIntMatrix2Rep :: VarData -> E
relationIntMatrix2Rep VarData{vIndexes=[a,b],
                              vEssence=[xMatch| vs := value.matrix.values |] } =
  values
  where
  values =
       wrapInRelation
     . concatMap tuples
     . filter notEmpty
     . zip a
     . map (map fst . filter f . zip b . unwrapMatrix)
     $ vs

  tuples :: (Integer,[Integer]) -> [E]
  tuples (x,ys) = map (\y -> [xMake| value.tuple.values := (map toIntLit [x,y]) |]) ys

  notEmpty (_,[]) = False
  notEmpty _      = True

  f (_,[eMatch| true |])  = True
  f (_,[eMatch| false |]) = False
  f _ = _bugg "relationIntMatrix2Rep not boolean"


{- Functions -}

matrix1DRep :: VarData -> E
matrix1DRep VarData{vIndexes=(ix:_), vEssence=[xMatch| vs :=  value.matrix.values |]} =
    let mappings = zipWith makeMapping ix vs
    in  wrapInFunction mappings

    where
    makeMapping :: Integer -> E -> E
    makeMapping i f =  [xMake| mapping := [toIntLit i, f] |]

matrix1DRep  v = error $  "matrix1DRep " ++  (show . pretty) v

{- Partitions -}

partitionMSetOfSetsRep :: VarData -> E
partitionMSetOfSetsRep VarData{vEssence=[xMatch| vs :=  value.matrix.values |]} =
    let parts = map toPart vs
    in  [xMake| value.partition.values := parts |]

    where
    toPart [xMatch| es := value.matrix.values |] =  [xMake| part := es |]

{- End -}


-- Branch funcs
runBranchFuncs :: [(Before, After)] -> VarData -> LeafFunc -> VarData
runBranchFuncs fs starting f = evalFs fs (liftRep f) starting

evalFs :: [(Before, After)] -> BranchFunc -> VarData -> VarData
evalFs []     mid v =  mid v
evalFs [g]    mid v =  evalF g mid v
evalFs (g:gs) mid v =  evalF g (evalFs gs mid ) v

-- Run the before transformations the inner function then the after transformation
evalF :: (Before,After) -> BranchFunc -> VarData -> VarData
evalF (before,after) mid value =
    let vs     = tracer "before:" $ before  (tracer "value:" value)
        mids   = tracer "mid:"    $ map mid vs
        res    = tracer "after:"  $ after value mids
    in res

-- Lift a LeafFunc to a Branch Func
liftRep ::  LeafFunc -> BranchFunc
liftRep repFunc vdata  = vdata{vEssence=repFunc vdata}


getBranch :: String -> Maybe (Before,After)
getBranch s =
    case tracer "\nBranchFunc str " s of
      "Matrix1D"           -> Just matrix1DBranch
      "SetExplicit"        -> Just explicitBranch
      "MSetExplicit"       -> Just explicitBranch
      "Occurrence"         -> Just occurrenceBranch
      "MSetOfSets"         -> Just partitionMSetOfSetsBranch
      "SetExplicitVarSize" -> Just setExplicitVarSizeBranch
      "RelationAsSet"      -> Just relationAsSetRep
      "AsReln"             -> Just functionAsRelnRep
      _                    -> Nothing


isBranchRep :: RepName -> Bool
isBranchRep "Matrix1D"           = True
isBranchRep "Explicit1D"         = True
isBranchRep "Occurrence1D"       = True
isBranchRep "MSetOfSets"         = True
isBranchRep "SetExplicitVarSize" = True
isBranchRep "RelationAsSet"      = True
isBranchRep "AsReln"             = True
isBranchRep "SetExplicit"        = True
isBranchRep "MSetExplicit"       = True
isBranchRep _                    = False


{- Sets -}

explicitBranch :: (Before,After)
explicitBranch = ( unwrapSet, mapLeafUnchanged )

occurrenceBranch :: (Before,After)
occurrenceBranch = ( unwrapSet, mapLeafFunc setOccurrenceRep )

setExplicitVarSizeBranch :: (Before,After)
setExplicitVarSizeBranch = ( unwrapSet, after )

    where 
    after orgData vs = 
        let inSet = mapMaybe getInSet vs 
        in orgData{vEssence=wrapInMatrix inSet}
        `_p` ("setExplicitVarSizeBranch", inSet)

    getInSet :: VarData -> Maybe E
    getInSet VarData{vEssence=[eMatch| (true,&v) |]}  = Just v
    getInSet VarData{vEssence=[eMatch| (false,&_) |]} = Nothing 


{- Relations -}

relationAsSetRep :: (Before,After)
relationAsSetRep = ( beforeUnchanged, after) 

    where
    after orgData vs = 
        let tuples = concatMap getTuples vs
        in  orgData{vEssence=wrapInRelation tuples}

    getTuples :: VarData -> [E]
    getTuples VarData{vEssence = [xMatch| es := value.matrix.values |] } =  es
    getTuples v = upBug "d" [v]

{- Functions -}

matrix1DBranch :: (Before,After)
matrix1DBranch = ( unwrapSet, after )

    where
    after orgData vs =
        let wraped = wrapInMatrix $ map vEssence vs
        in orgData{vEssence=matrix1DRep orgData{vEssence=wraped}}


functionAsRelnRep :: (Before, After)
functionAsRelnRep = ( beforeUnchanged, after )

    where
    after orgData [v] = 
        let res = wrapInFunction . map relnToFunc .  unwrapRelation . vEssence $ v 
        in  orgData{vEssence=res}

    relnToFunc [eMatch| (&from,&to) |] = [xMake| mapping := [from,to] |]


{- Partitions -}

partitionMSetOfSetsBranch :: (Before,After)
partitionMSetOfSetsBranch = ( beforeUnchanged , after )
    where
    after orgData [vs] = vs{vEssence=partitionMSetOfSetsRep vs}


{- End -}

beforeUnchanged :: VarData -> [VarData]
beforeUnchanged v = [v]

unwrapSet :: Before
unwrapSet v@VarData{vEssence=e, vIndexes=ix} =
        map (\f -> v{vEssence=f, vIndexes=tail ix} )  (unwrapMatrix e)

mapLeafFunc :: LeafFunc -> VarData -> [VarData] -> VarData
mapLeafFunc f orgData vs =
        orgData{vEssence = wrapInMatrix . map f $  vs }

mapLeafUnchanged :: VarData -> [VarData] -> VarData
mapLeafUnchanged = mapLeafFunc vEssence

_afterErr ::Pretty a => a -> t
_afterErr e = errp e

-- Utility functions

onlySelectedValues :: [(a,E)] -> [(a,E)]
onlySelectedValues = filter f
    where
    f (_,[eMatch| true|]) = True
    f (_,[eMatch| 1   |]) = error "1 should not be used as True"
    f (_,[eMatch| 0   |]) = error "0 should not be used as False"
    f (_,_) = False


wrapInFunction :: [E] -> E
wrapInFunction es = [xMake| value.function.values := es |]

wrapInRelation :: [E] -> E
wrapInRelation es = [xMake| value.relation.values := es |]

unwrapRelation :: E -> [E]
unwrapRelation [xMatch| vs := value.relation.values |] = vs

toIntLit :: Integer -> E
toIntLit j =  [xMake| value.literal := [Prim (I j)] |]


_bug  :: Pretty a => String -> [a] -> t
_bug  s = upBug  ("Representations: " ++ s)
_bugi :: (Show a,Pretty b) => String -> (a, [b]) -> t
_bugi s = upBugi ("Representations: " ++ s )
_bugg :: String -> t
_bugg s = _bug s ([] :: [E])


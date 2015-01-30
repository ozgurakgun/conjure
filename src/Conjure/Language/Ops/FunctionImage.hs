{-# LANGUAGE DeriveGeneric, DeriveDataTypeable, DeriveFunctor, DeriveTraversable, DeriveFoldable #-}

module Conjure.Language.Ops.FunctionImage where

import Conjure.Prelude
import Conjure.Language.Ops.Common


data OpFunctionImage x = OpFunctionImage x [x]
    deriving (Eq, Ord, Show, Data, Functor, Traversable, Foldable, Typeable, Generic)

instance Serialize x => Serialize (OpFunctionImage x)
instance Hashable  x => Hashable  (OpFunctionImage x)
instance ToJSON    x => ToJSON    (OpFunctionImage x) where toJSON = genericToJSON jsonOptions
instance FromJSON  x => FromJSON  (OpFunctionImage x) where parseJSON = genericParseJSON jsonOptions

instance (TypeOf x, Pretty x) => TypeOf (OpFunctionImage x) where
    typeOf p@(OpFunctionImage f xs) = do
        TypeFunction from to <- typeOf f
        xTys <- mapM typeOf xs
        let xTy = case xTys of
                    [t] -> t
                    _   -> TypeTuple xTys
        if typesUnify [xTy, from]
            then return to
            else raiseTypeError p

instance EvaluateOp OpFunctionImage where
    evaluateOp (OpFunctionImage (ConstantAbstract (AbsLitFunction xs)) [a]) =
        case [ y | (x,y) <- xs, a == x ] of
            [y] -> return y
            []  -> fail $ vcat [ "Function is not defined at this point:" <+> pretty a
                               , "Function value:" <+> pretty (ConstantAbstract (AbsLitFunction xs))
                               ]
            _   -> fail $ vcat [ "Function is multiply defined at this point:" <+> pretty a
                               , "Function value:" <+> pretty (ConstantAbstract (AbsLitFunction xs))
                               ]
    evaluateOp op = na $ "evaluateOp{OpFunctionImage}:" <++> pretty (show op)

instance Pretty x => Pretty (OpFunctionImage x) where
    prettyPrec _ (OpFunctionImage a b) = "image" <> prettyList prParens "," (a:b)

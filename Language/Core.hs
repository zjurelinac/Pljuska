module Language.Core where


import qualified Data.Map as M
import Data.Maybe

import Language.Definitions
import Utility.Data


-- Evaluating a variable
instance Evaluable Data where
    evaluate env ( VarData ( Variable var ) )
        | isNothing val = error $ "Value of " ++ var ++ " not previously defined."
        | otherwise     = fromJust val
        where   val = M.lookup var ( variables env )
    evaluate env ( StaticData pt )   =
        case pt of
            IntValue i      -> IntValue i
            StringValue s   -> StringValue $ parseString env s
            _               -> error $ "Cannot evaluate " ++ show pt


-- Parse string - replace all occurences of an '$variable' with it's value
parseString :: Environment -> String -> String
parseString env s = s


-- Basic operations on primitive values
instance Eq PrimitiveType where
    (==) ( IntValue i ) ( IntValue j )          =   i == j
    (==) ( StringValue s ) ( StringValue t )    =   s == t
    (==) _ _                                    =   error "Incompatible types for comparison"

instance Ord PrimitiveType where
    (<=) ( IntValue i ) ( IntValue j )          =   i <= j
    (<=) ( StringValue s ) ( StringValue t )    =   s <= t
    (<=) _ _                                    =   error "Incompatible types for comparison"

instance Num PrimitiveType where
    (+) ( IntValue i ) ( IntValue j )           = IntValue ( i + j )
    (+) _ _                                     = error "Incompatible types for addition"
    (-) ( IntValue i ) ( IntValue j )           = IntValue ( i - j )
    (-) _ _                                     = error "Incompatible types for subtraction"
    (*) ( IntValue i ) ( IntValue j )           = IntValue ( i * j )
    (*) _ _                                     = error "Incompatible types for multiplication"
    negate ( IntValue i )                       = IntValue ( -i )
    negate _                                    = error "Incompatible type for negation"
    abs ( IntValue i )                          = IntValue ( abs i )
    abs _                                       = error "Incompatible type for absolute value"
    signum ( IntValue i )                       = if i > 0 then 1 else if i == 0 then 0 else -1
    signum _                                    = error "Incompatible type for signum"
    fromInteger i                               = IntValue ( fromIntegral i )

(//) :: PrimitiveType -> PrimitiveType -> PrimitiveType
(//) ( IntValue i ) ( IntValue j )  =   IntValue ( i `quot` j )
(//) _ _                            =   error "Incompatible types for division"

(%)  :: PrimitiveType -> PrimitiveType -> PrimitiveType
(%) ( IntValue i ) ( IntValue j )   =   IntValue ( i `rem` j )
(%) _ _                             =   error "Incompatible types for modulus operation"

(+-+)  :: PrimitiveType -> PrimitiveType -> PrimitiveType
(+-+) ( StringValue s ) ( StringValue t )   =   StringValue ( s ++ t )
(+-+) _ _                                   =   error "Incompatible types for concatenation"


-- Testing a condition
instance Testable Condition where
    test env ( BasicCondition comp o1 o2 ) =
        case comp of
            Equals          -> p1 == p2
            NotEqual        -> p1 /= p2
            Greater         -> p1 > p2
            Lesser          -> p1 < p2
            GreaterEqual    -> p1 >= p2
            LesserEqual     -> p1 <= p2
        where   p1 = evaluate env o1
                p2 = evaluate env o2

    test env ( AndCondition c1 c2 ) = ( test env c1 ) && ( test env c2 )
    test env ( OrCondition c1 c2 )  = ( test env c1 ) || ( test env c2 )
    test env ( NotCondition c )     = not $ test env c


-- Evaluate an arithmetic expression
instance Evaluable Arithmetic where
    evaluate env ( Value v ) = evaluate env v
    evaluate env ( Arithmetic op a1 a2 ) =
        case op of
            Plus        -> v1 + v2
            Minus       -> v1 - v2
            Multiply    -> v1 * v2
            Divide      -> v1 // v2
            Modulo      -> v1 % v2
            Concat      -> v1 +-+ v2
        where   v1 = evaluate env a1
                v2 = evaluate env a2


-- Execute an assignment
instance Executable Assignment where
    execute env ( Assignment ( Variable var ) exp )  = do
        ( val, env' ) <- execute env exp
        let nenv = env' { variables = M.insert var val ( variables env' ) }
        return $ ( val, nenv )


-- Execute a basic command
instance Executable BasicCommand where
     execute env cmd = do
        cargs <- preprocessArgs env cmd
        let command = commandList env M.! ( cmdName cmd )
        ( val, env' ) <- command env cargs
        outputResults env' ( toString val ) ( displayOutput cmd ) ( outputStream cmd ) ( append cmd )
        return ( val, env' )


-- Execute an expression
instance Executable Expression where
      execute env exp = return $ ( NoValue, env )



-- -- Executing an expression
-- instance Executable Expression where


--
preprocessArgs :: Environment -> BasicCommand -> IO [ PrimitiveType ]
preprocessArgs env cmd = do
    let cargs = map ( evaluate env ) ( args cmd )
    cargs' <- obtainFromFile cargs ( inputStream cmd )
    return cargs'
    where
            obtainFromFile :: [ PrimitiveType ] -> Maybe Data -> IO [ PrimitiveType ]
            obtainFromFile xs Nothing = return $ xs
            obtainFromFile xs ( Just d ) = do
                let fn = toString $ evaluate env d
                s <- readFile fn
                return $ reverse $ ( StringValue s : xs )


--
outputResults :: Environment -> String -> Bool -> Maybe Data -> Bool -> IO ()
outputResults _ _ False _ _           = return ()
outputResults _ s _ Nothing _         = putStrLn s
outputResults env s o ( Just d ) a    = do
    let fn = toString $ evaluate env d
    if a then appendFile fn ( s ++ "\n" )
         else writeFile fn ( s ++ "\n" )

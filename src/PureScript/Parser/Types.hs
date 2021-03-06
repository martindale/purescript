-----------------------------------------------------------------------------
--
-- Module      :  PureScript.Parser.Types
-- Copyright   :  (c) Phil Freeman 2013
-- License     :  MIT
--
-- Maintainer  :  Phil Freeman <paf31@cantab.net>
-- Stability   :  experimental
-- Portability :
--
-- |
--
-----------------------------------------------------------------------------

module PureScript.Parser.Types (
    parseType,
    parsePolyType,
    parseRow
) where

import PureScript.Types
import PureScript.Parser.State
import PureScript.Parser.Common
import Control.Applicative
import qualified Text.Parsec as P
import qualified Text.Parsec.Expr as P
import Control.Arrow (Arrow(..))

parseNumber :: P.Parsec String ParseState Type
parseNumber = const Number <$> reserved "Number"

parseString :: P.Parsec String ParseState Type
parseString = const String <$> reserved "String"

parseBoolean :: P.Parsec String ParseState Type
parseBoolean = const Boolean <$> reserved "Boolean"

parseArray :: P.Parsec String ParseState Type
parseArray = squares $ Array <$> parseType

parseObject :: P.Parsec String ParseState Type
parseObject = braces $ Object <$> parseRow

parseFunction :: P.Parsec String ParseState Type
parseFunction = do
  args <- lexeme $ parens $ commaSep parseType
  lexeme $ P.string "->"
  resultType <- parseType
  return $ Function args resultType

parseTypeVariable :: P.Parsec String ParseState Type
parseTypeVariable = TypeVar <$> identifier

parseTypeConstructor :: P.Parsec String ParseState Type
parseTypeConstructor = TypeConstructor <$> properName

parseTypeAtom :: P.Parsec String ParseState Type
parseTypeAtom = indented *> P.choice (map P.try
            [ parseNumber
            , parseString
            , parseBoolean
            , parseArray
            , parseObject
            , parseFunction
            , parseTypeVariable
            , parseTypeConstructor
            , parens parseType ])

parsePolyType :: P.Parsec String ParseState PolyType
parsePolyType = (PolyType <$> (P.option [] (indented *> reserved "forall" *> many (indented *> identifier) <* indented <* dot))
                          <*> parseType) P.<?> "polymorphic type"

parseType :: P.Parsec String ParseState Type
parseType = (P.buildExpressionParser operators . buildPostfixParser postfixTable $ parseTypeAtom) P.<?> "type"
  where
  postfixTable :: [P.Parsec String ParseState (Type -> Type)]
  postfixTable = [ flip TypeApp <$> (indented *> parseTypeAtom) ]
  operators = [ [ P.Infix (lexeme (P.try (P.string "->")) >> return (\t1 t2 -> Function [t1] t2)) P.AssocRight ] ]

parseNameAndType :: P.Parsec String ParseState (String, Type)
parseNameAndType = (,) <$> (indented *> identifier <* indented <* lexeme (P.string "::")) <*> parseType

parseRowEnding :: P.Parsec String ParseState Row
parseRowEnding = P.option REmpty (RowVar <$> (lexeme (indented *> P.char '|') *> indented *> identifier))

parseRow :: P.Parsec String ParseState Row
parseRow = (fromList <$> (parseNameAndType `P.sepBy` (indented *> semi)) <*> parseRowEnding) P.<?> "row"
  where
  fromList :: [(String, Type)] -> Row -> Row
  fromList [] r = r
  fromList ((name, t):ts) r = RCons name t (fromList ts r)

{-# LANGUAGE TemplateHaskell, TypeFamilies #-}

-- |
-- Module    : Where
-- Copyright : 2003 Shae Erisson
--
-- License:     lGPL
--
-- Slightly specialised version of Where for associating projects with their urls.
-- Code almost all copied.
module Plugin.Where (theModule) where

import Plugin
import Lambdabot.Util (confirmation)
import qualified Data.ByteString.Char8 as P
import qualified Data.Map as M

$(plugin "Where")

type WhereState         = M.Map P.ByteString P.ByteString
type WhereWriter        = WhereState -> LB ()
-- type Where m a          = ModuleT WhereState m a

instance Module WhereModule where
  type ModuleState WhereModule = WhereState

  moduleCmds _ = 
        [ (command "where")
            { help = say "where <key>. Return element associated with key"
            , process = doCmd "where"
            }
        , (command "url")
            { help = say "url <key>. Return element associated with key"
            , process = doCmd "url"
            }
        , (command "what")
            { help = say "what <key>. Return element associated with key"
            , process = doCmd "what"
            }
        , (command "where+")
            { help = say "where+ <key> <elem>. Define an association" 
            , process = doCmd "where+"
            }
        ]
  
  moduleDefState  _ = return M.empty
  moduleSerialize _ = Just mapPackedSerial

doCmd :: String -> String -> Cmd Where ()
doCmd cmd rest = (say =<<) . lift . withMS $ \factFM writer ->
    case words rest of
        []         -> return "@where <key>, return element associated with key"
        (fact:dat) -> processCommand factFM writer
                            (lowerCaseString fact) cmd (unwords dat)

------------------------------------------------------------------------

processCommand :: WhereState -> WhereWriter
               -> String -> String -> String -> LB String

processCommand factFM writer fact cmd dat = case cmd of
        "where"     -> return $ getWhere factFM fact
        "what"      -> return $ getWhere factFM fact -- an alias
        "url"       -> return $ getWhere factFM fact -- an alias
        "where+"    -> updateWhere True factFM writer fact dat
        _           -> return "Unknown command."

getWhere :: WhereState -> String -> String
getWhere fm fact =
    case M.lookup (P.pack fact) fm of
        Nothing -> "I know nothing about " ++ fact ++ "."
        Just x  -> P.unpack x

updateWhere :: Bool -> WhereState -> WhereWriter -> String -> String -> LB String
updateWhere _guard factFM writer fact dat = do
        writer $ M.insert (P.pack fact) (P.pack dat) factFM
        random confirmation

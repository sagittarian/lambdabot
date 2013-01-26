{-# LANGUAGE PatternGuards #-}
-- Copyright (c) 2004-6 Don Stewart - http://www.cse.unsw.edu.au/~dons
-- GPL version 2 or later (see http://www.gnu.org/copyleft/gpl.html)
--
-- | Interface to /aspell/, an open source spelling checker, from a
-- suggestion by Kai Engelhardt. Requires you to install aspell.
module Plugin.Spell (theModule) where

import Plugin
import qualified Text.Regex as R

helpStr = "spell <word>. Show spelling of word"

type Spell = ModuleT Bool LB

theModule = newModule
    { moduleCmds = return
        [ (command "spell")
            { help = say helpStr
            , process = doSpell
            }
        , (command "spell-all")
            { help = say helpStr
            , process = spellAll
            }
        , (command "nazi-on")
            { privileged = True
            , help = say helpStr
            , process = const (nazi True)
            }
        , (command "nazi-off")
            { privileged = True
            , help = say helpStr
            , process = const (nazi False)
            }
        ]
    , moduleDefState = return False

    , contextual = \txt -> do
        alive <- readMS
        if alive then io (spellingNazi txt) >>= mapM_ say
                 else return ()
    }

doSpell [] = say "No word to spell."
doSpell s  = (say . showClean . take 5) =<< (io (spell s))

spellAll [] = say "No phrase to spell."
spellAll s  = liftIO (spellingNazi s) >>= mapM_ say

nazi True  = lift on  >> say "Spelling nazi engaged."
nazi False = lift off >> say "Spelling nazi disengaged."

on :: Spell ()
on  = writeMS True

off :: Spell ()
off = writeMS False

binary :: String
binary = "aspell"

args :: [String]
args = ["pipe"]

--
-- | Find the first misspelled word in the input line, and return plausible
-- output.
--
spellingNazi :: String -> IO [String]
spellingNazi lin = fmap (take 1 . concat) (mapM correct (words lin))
    where correct word = do
            var <- take 5 `fmap` spell word
            return $ if null var || any (equating' (map toLower) word) var
                then []
                else ["Did you mean " ++ listToStr "or" var ++ "?"]
          equating' f x y = f x == f y
--
-- | Return a list of possible spellings for a word
-- 'String' is a word to check the spelling of.
--
spell :: String -> IO [String]
spell word = spellWithDict word Nothing []

--
-- | Like 'spell', but you can specify which dictionary and pass extra
-- arguments to aspell.
--
spellWithDict :: String -> Maybe Dictionary -> [String] -> IO [String]
spellWithDict word (Just d) ex = spellWithDict word Nothing ("--master":show d:ex)
spellWithDict word Nothing  ex = do
    (out,err,_) <- popen binary (args++ex) (Just word)
    let o = fromMaybe [word] ((clean_ . lines) out)
        e = fromMaybe e      ((clean_ . lines) err)
    return $ case () of {_
        | null o && null e -> []
        | null o           -> e
        | otherwise        -> o
    }

--
-- Parse the output of aspell (would probably work for ispell too)
--
clean_ :: [String] -> Maybe [String]
clean_ (('@':'(':'#':')':_):rest) = clean' rest -- drop header
clean_ s = clean' s                             -- no header for some reason

--
-- Parse rest of aspell output.
--
-- Grammar is:
--      OK          ::=  *
--      Suggestions ::= & <original> <count> <offset>: <miss>, <miss>, ...
--      None        ::= # <original> <offset>
--
clean' :: [String] -> Maybe [String]
clean' (('*':_):_)    = Nothing                          -- correct spelling
clean' (('#':_):_)    = Just []                          -- no match
clean' (('&':rest):_) = Just $ split ", " (clean'' rest) -- suggestions
clean' _              = Just []                          -- not sure

clean'' :: String -> String
clean'' s
    | Just (_,_,m,_) <- pat `R.matchRegexAll` s = m
    | otherwise = s
    where pat  = regex' "[^:]*: "    -- drop header

--
-- Alternate dictionaries, currently just lambdabot's. The idea was to
-- have a dictionary for lambdabot commands, and aspell rather than
-- levinshtein for spelling errors. Turns out to be quite complicated,
-- for negligible gain.
--
data Dictionary
    = Lambdabot -- ^ Dictionary of lambdabot commands (it's its own language)

-- path to the master dictionary
instance Show Dictionary where
    -- TODO: use findLBFile from File.hs. But does this module even work anymore?
    showsPrec _ Lambdabot = showString "State/lambdabot"


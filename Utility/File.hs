module Utility.File (
    directorize,
    getAbsolutePath,
    getBaseName
) where


getAbsolutePath :: FilePath -> FilePath -> FilePath
getAbsolutePath curr fp
    | head fp == '/'    = fp
    | fp == ".."        = reverse . tail . drop ( length . getBaseName $ curr ) . reverse $ curr
    | fp == "."         = curr
    | otherwise         = directorize curr ++ fp


getBaseName :: FilePath -> FilePath
getBaseName = reverse . takeWhile ( /= '/' ) . reverse


directorize :: FilePath -> FilePath
directorize xs = xs ++ ( if last xs /= '/' then "/" else "" )

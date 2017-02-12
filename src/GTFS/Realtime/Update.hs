{-# OPTIONS_GHC -fno-warn-type-defaults #-}
{-# LANGUAGE CPP #-}
{-# LANGUAGE OverloadedStrings #-}
{- |  Update functionality: We determine if the static dataset is outdated.
-}
module GTFS.Realtime.Update
       (isDatasetUpToDate, printWarningForNewDataset, isCurrent,
        printOrUpdateDataset, Error(..))
       where

import GTFS.Database (userDatabaseFile, getLastUpdatedDatabase)
import CSV.Import (createNewDatabase)

import Data.Functor ((<$>))

import Network.HTTP.Conduit
import Network.HTTP.Types.Header (ResponseHeaders, hLastModified)
import Data.Time.Calendar (Day)
#if MIN_VERSION_time(1, 5, 0)
import Data.Time.Format (defaultTimeLocale)
#else
import System.Locale (defaultTimeLocale)
#endif
import Data.Time.Format (parseTime)
import Data.List (find)
import System.IO (hPrint, hPutStr, stderr)
import Control.Monad (join)
import qualified Control.Exception as E
import qualified Data.ByteString.Char8 as B
import qualified Data.Text as T


data Error = Error String
  deriving (Eq, Show)

-- | Returns True if the static dataset has been updated on the remote server.
-- The function performs a HEAD request and extracts the last-modified header. The
-- date is checked against what the database is giving us.
-- Note: uses last modified header to determine if it has recently been updated
--
isDatasetUpToDate ::
  T.Text -- ^ URL to perform a HEAD against (typically the static dataset zip file)
  -> Day  -- ^ modified date from the database
  -> (Day -> Day -> Bool)
  -> IO (Either Error Bool)
isDatasetUpToDate url dbmodified f = do
    headers <-
        catchHTTPError
            (getHeadersForDataset $ T.unpack url)
            (\e ->
                  hPrint stderr (show e) >> return [])
    if null headers
        then return $
             Left
                 (Error
                      "Problem communicating with server. Received empty headers.")
        else do
            case getLastModified headers of
                Nothing ->
                    return $
                    Left
                        (Error $
                         "Couldn't determine last modification date from server headers: " ++
                         show headers)
                Just d -> return $ Right (f d dbmodified)

printWarningForNewDataset ::
  Either Error Bool
  -> IO ()
printWarningForNewDataset (Right False) = print "Note: New dataset available!"
printWarningForNewDataset (Right _) = return ()
printWarningForNewDataset (Left _) = hPutStr stderr "Warning: Couldn't determine if dataset is outdated."

-- | Prints an additional line to let the user know an updated static dataset is
-- available or updates the dataset automatically
--
printOrUpdateDataset :: Bool -> Maybe T.Text -> IO ()
printOrUpdateDataset False (Just url) = dbIsOutOfDate url >>= printWarningForNewDataset
printOrUpdateDataset True (Just url) = do
  result <- dbIsOutOfDate url
  case result of
    Right True -> return () -- database is up to date, nothing to do
    Right False -> userDatabaseFile >>= createNewDatabase (T.unpack url)
    Left err -> print err
printOrUpdateDataset _ _ = return ()  -- automatically update, but don't specify a URL, fail silently??

dbIsOutOfDate :: T.Text -> IO (Either Error Bool)
dbIsOutOfDate url = do
  fp <- userDatabaseFile
  d <- getLastUpdatedDatabase (T.pack fp)
  result <- isDatasetUpToDate url d isCurrent
  return result

-- | Returns True if the last-modified from the server is less or equal than what we have in our database
isCurrent ::
  Day  -- ^ last-modified parsed from header
  -> Day  -- ^ last-modified date from database
  -> Bool
isCurrent lastModified dbmod = lastModified <= dbmod

--
-- private helpers

catchHTTPError :: IO a -> (HttpException -> IO a) -> IO a
catchHTTPError = E.catch

getHeadersForDataset ::
  String
  -> IO ResponseHeaders
getHeadersForDataset url = do
  initReq <- parseUrl url
  let request = initReq { method = "HEAD" }
  manager <- newManager conduitManagerSettings
  response <- httpLbs request manager
  return $ responseHeaders response

getLastModified ::
  ResponseHeaders
  -> Maybe Day
getLastModified h = join $ (\x -> parseTime defaultTimeLocale "%a, %d %b %Y %T %Z" $ B.unpack $ snd x) <$> find (\(n,_) -> n == hLastModified) h

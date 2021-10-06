module PodDB where

import           Control.Monad         (unless, when)
import           Data.List             (sort)
import           Database.HDBC
import           Database.HDBC.Sqlite3
import           PodTypes

connect :: FilePath -> IO Connection
connect fp = do
    dbh <- connectSqlite3 fp
    prepDB dbh
    return dbh

prepDB :: IConnection conn => conn -> IO ()
prepDB dbh = do
    tables <- getTables dbh
    unless (elem "podcasts" tables) $ do
        run dbh "CREATE TABLE podcasts (\
                    \castid INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,\
                    \casturl TEXT NOT NULL UNIQUE)" []
        return ()

    unless (elem "episodes" tables) $ do
        run dbh "CREATE TABLE episodes (\
                    \epid INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,\
                    \epcastid INTEGER NOT NULL,\
                    \epurl TEXT NOT NULL,\
                    \epdone INTEGER NOT NULL,\
                    \UNIQUE(epcastid, epurl),\
                    \UNIQUE(epcastid, epid))" []
        return ()

    commit dbh

addPodcast :: IConnection conn => conn -> Podcast -> IO Podcast
addPodcast dbh podcast =
    handleSql errorHandler $ do
        run dbh "INSERT INTO podcasts (castURL) VALUES (?)" [toSql (castURL podcast)]
        r <- quickQuery' dbh "SELECT castid FROM podcasts WHERE castURL = ?" [toSql (castURL podcast)]
        case r of
            [[x]] -> return $ podcast {castID = fromSql x}
            y     -> fail $ "addPodcast: unexpected result: " ++ show y
    where errorHandler e =
            do fail $ "Error adding podcast; does this URL already exist?\n" ++ show e

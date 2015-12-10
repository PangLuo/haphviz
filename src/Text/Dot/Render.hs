{-# LANGUAGE OverloadedStrings #-}
module Text.Dot.Render (renderGraph) where

import           Control.Monad           (unless)
import           Data.Functor.Identity   (Identity (..))
import           Data.Monoid
import           Data.Text               (Text)
import qualified Data.Text               as T

import           Control.Monad.Reader    (ReaderT, ask, runReaderT)
import           Control.Monad.State     (StateT, execStateT, get, modify)
import           Control.Monad.Writer    (WriterT, execWriterT, tell)

import           Text.Dot.Types.Internal

type Render = ReaderT GraphType (StateT Int (WriterT Text Identity))


renderGraph :: DotGraph -> Text
renderGraph (Graph gtype name content) = mconcat
    [ "digraph"
    , " "
    , name
    , " "
    , "{"
    , "\n"
    , runIdentity $ execWriterT $ execStateT (runReaderT (renderDot content) gtype) 1
    , "}"
    ]


renderDot :: Dot -> Render ()

renderDot (Node nid ats) = do
    renderId nid
    renderAttributes ats

renderDot (Edge from to ats) = do
    renderId from
    tell " "
    t <- ask
    tell $ case t of
        UndirectedGraph -> "--"
        DirectedGraph   -> "->"
    tell " "
    renderId to
    renderAttributes ats

renderDot (Declaration t ats) = do
    renderDecType t
    renderAttributes ats

renderDot (RawDot t) = tell t

renderDot (Label t) = do
    tell "label"
    tell " "
    tell t

renderDot (DotSeq d1 d2) = do
    indent d1
    renderDot d1
    nl d1
    indent d2
    renderDot d2
    nl d2
  where
    nl :: Dot -> Render ()
    nl (DotSeq _ _) = return ()
    nl DotEmpty = return ()
    nl _ = do
        tell ";"
        tell "\n"

    indent :: Dot -> Render ()
    indent (DotSeq _ _) = return ()
    indent DotEmpty = return ()
    indent _ = do
        level <- get
        tell $ T.pack $ replicate (level * 2) ' '

renderDot DotEmpty = return ()

renderAttributes :: [Attribute] -> Render ()
renderAttributes ats = unless (null ats) $ do
    tell " "
    tell "["
    mapM_ renderAttribute ats
    tell "]"

renderAttribute :: Attribute -> Render ()
renderAttribute (name, value) = do
    tell name
    tell "="
    tell $ quoted value

renderId :: NodeId -> Render ()
renderId (Nameless i) = tell $ T.pack $ show i
renderId (UserId t) = tell $ quoted t

renderDecType :: DecType -> Render ()
renderDecType DecGraph = tell "graph"
renderDecType DecNode  = tell "node"
renderDotType DecEdge  = tell "edge"

indented :: Render () -> Render ()
indented func = do
    modify ((+) 1)
    func
    modify ((-) 1)

-- | Text processing utilities
quoted :: Text -> Text
quoted t = "\"" <> t <> "\""


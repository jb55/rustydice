{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE TypeFamilies #-}
{-# LANGUAGE ScopedTypeVariables #-}

module Network.RPC
    ( rpcRequest
    , module X
    ) where

import Data.Aeson
import Data.ByteString.Lazy (toStrict)
import Data.Bifunctor (bimap)

import Network.RPC.CLightning.Commands as X
import Network.RPC.Common (Resp)
import Network.RPC.Config (RPCConfig(..))
import Network.RPC.Config as X
import Network.RPC.Error
import Network.RPC.Internal (sockRequest)

import qualified Data.ByteString.Char8 as B8

rpcRequest
  :: (ToJSON a, FromJSON (Resp a)) =>
     RPCConfig -> a -> IO (Either RPCError (Resp a))
rpcRequest cfg json_ = do
  mres <- sockRequest cfg (toStrict (encode json_))
  case mres of
    Right res ->
      return $ bimap (jsonDecodeError . B8.pack)
                     getCRPCResp
                     (eitherDecode res)
    Left e -> return (Left e)



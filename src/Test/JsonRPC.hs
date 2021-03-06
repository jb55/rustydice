{-# LANGUAGE RecordWildCards #-}

module Test.JsonRPC where

import Data.Aeson
import Data.ByteString (ByteString)
import Data.Monoid ((<>))
import Data.Text (Text)
import Data.Word (Word16, Word8)
import Network.HTTP.Client
import Text.Printf (printf)

import qualified Data.Aeson as JSON
import qualified Data.ByteString.Base64 as B64
import qualified Data.Text as T

data JsonRPC =
  JsonRPC {
      jrpcManager  :: Manager
    , jrpcReq :: Request
    }

instance Show JsonRPC where
  show JsonRPC{..} = printf "JsonRPC [%s]" (show jrpcReq)

makeClient :: Manager -> ByteString -> Word16 -> ByteString -> ByteString -> JsonRPC
makeClient manager host port user pass =
  let
      authStr = B64.encode (user <> ":" <> pass)
      headers = [("Authorization", "Basic " <> authStr)]

      req = defaultRequest {
              host           = host
            , port           = fromIntegral port
            , method         = "POST"
            , requestHeaders = headers
            }

  in JsonRPC manager req


data JsonRPCRes a = JsonRPCRes {
      jrpcResult :: a
    , jrpcError  :: Maybe Text
    , jrpcId     :: Int
    }
    deriving Show

instance FromJSON a => FromJSON (JsonRPCRes a) where
    parseJSON (Object obj) =
        JsonRPCRes
          <$> obj .:  "result"
          <*> obj .:? "error"
          <*> obj .:  "id"

call :: (ToJSON a, FromJSON b) => JsonRPC -> Text -> a -> IO b
call JsonRPC{..} method params =
    let
        reqData =
            object [ "jsonrpc" .= T.pack "2.0"
                   , "method"  .= method
                   , "params"  .= params
                   , "id"      .= (1 :: Word8)
                  ]
        req =
            jrpcReq {
              requestBody = RequestBodyLBS (JSON.encode reqData)
            }
    in
      do
        res <- httpLbs req jrpcManager
        let body = responseBody res
        case JSON.eitherDecode body of
          Left e -> fail ("Could not decode JSON: \n\n" <> e <> "\n\n" <> show body )
          Right jrpcres  -> return (jrpcResult jrpcres)

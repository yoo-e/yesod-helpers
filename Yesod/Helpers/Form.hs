{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes #-}
{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE ImpredicativeTypes #-}
module Yesod.Helpers.Form where

import Prelude
import Yesod

import qualified Data.Text.Encoding         as TE
import qualified Data.Text                  as T
import qualified Data.ByteString.Lazy       as LB
import qualified Data.Aeson.Types           as A

import Data.Text                            (Text)
import Data.Maybe                           (catMaybes)
import Text.Blaze.Renderer.Utf8             (renderMarkup)
import Text.Blaze.Internal                  (MarkupM(Empty))
import Control.Monad                        (liftM, void)
import Control.Applicative                  (Applicative, pure, (<|>))
import Text.Parsec                          (parse, sepEndBy, many1, space, newline
                                            , eof, skipMany)

import Yesod.Helpers.Parsec

nameIdToFs :: Text -> Text -> FieldSettings site
nameIdToFs name idName = FieldSettings "" Nothing (Just idName) (Just name) []

nameToFs :: Text -> FieldSettings site
nameToFs name = FieldSettings "" Nothing Nothing (Just name) []

labelNameToFs :: RenderMessage site message => message -> Text -> FieldSettings site
labelNameToFs label name = FieldSettings
                    (SomeMessage label)
                    Nothing             -- tooltip
                    Nothing             -- id
                    (Just name)
                    []


minimialLayoutBody :: Yesod site => WidgetT site IO () -> HandlerT site IO Html
minimialLayoutBody widget = do
    pc <- widgetToPageContent widget
    giveUrlRenderer $ [hamlet|^{pageBody pc}|]

-- | 把 form 的 html 代码用 json 打包返回
jsonOutputForm :: Yesod site => WidgetT site IO () -> HandlerT site IO Value
jsonOutputForm = jsonOutputFormMsg (Nothing :: Maybe Text)

-- | 同上，只是增加了 message 字段
jsonOutputFormMsg :: (Yesod site, RenderMessage site message) =>
    Maybe message -> WidgetT site IO () -> HandlerT site IO Value
jsonOutputFormMsg m_msg formWidget = do
    body <- liftM (TE.decodeUtf8 . LB.toStrict . renderMarkup)
                            (minimialLayoutBody formWidget)
    mr <- getMessageRender
    return $ object $ catMaybes $
                    [ Just $ "body" .= body
                    , fmap (\msg -> "message" .= mr msg) m_msg
                    ]

type ShowFormPage site = WidgetT site IO () -> Enctype -> HandlerT site IO Html

jsonOrHtmlOutputForm :: Yesod site =>
    ShowFormPage site
    -> WidgetT site IO ()
    -> Enctype
    -> [A.Pair]
    -> HandlerT site IO TypedContent
jsonOrHtmlOutputForm show_form formWidget formEnctype other_data = do
    selectRep $ do
        provideRep $ show_form formWidget formEnctype
        provideRep $ do
            js_form <- jsonOutputForm formWidget
            return $ object $ ("form_body" .= js_form) : other_data


-- | the Data.Traversable.traverse function for FormResult
traverseFormResult :: Applicative m => (a -> m b) -> FormResult a -> m (FormResult b)
traverseFormResult f (FormSuccess x)    = fmap FormSuccess $ f x
traverseFormResult _ (FormFailure e)    = pure $ FormFailure e
traverseFormResult _ FormMissing        = pure FormMissing


simpleEncodedField ::
    (SimpleStringRep a, Monad m
    , RenderMessage (HandlerSite m) msg
    , RenderMessage (HandlerSite m) FormMessage
    ) =>
    (String -> msg)     -- ^ a function to generate a error message
    -> Field m a
simpleEncodedField mk_msg = checkMMap f (T.pack . simpleEncode) textField
    where
        f t = case parse simpleParser "" t of
                Left err -> return $ Left $ mk_msg $ show err
                Right x -> return $ Right x


-- | parse the content in textarea, into a list of values
-- using methods of SimpleStringRep
simpleEncodedListTextareaField ::
    (SimpleStringRep a, Monad m
    , RenderMessage (HandlerSite m) msg
    , RenderMessage (HandlerSite m) FormMessage
    ) =>
    (CharParser b, Text)   -- ^ separator: parser and its 'standard' representation
    -> (String -> msg)      -- ^ a function to generate a error message
    -> Field m [a]
simpleEncodedListTextareaField sep_inf mk_msg =
    encodedListTextareaField sep_inf (simpleParser, T.pack . simpleEncode) mk_msg


simpleEncodedOptionList ::
    (SimpleStringRep a, Enum a, Bounded a) =>
    (a -> Text)     -- ^ to render value to display
    -> OptionList a
simpleEncodedOptionList render = mkOptionList $ map f [minBound .. maxBound]
    where
        f x = Option (render x) x (T.pack $ simpleEncode x)


-- | parse the content in textarea, into a list of values
encodedListTextareaField ::
    (Monad m
    , RenderMessage (HandlerSite m) msg
    , RenderMessage (HandlerSite m) FormMessage
    ) =>
    (CharParser b, Text)   -- ^ separator: parser and its 'standard' representation
    -> (CharParser a, a -> Text)
                            -- ^ parse a single value and render a single value
    -> (String -> msg)      -- ^ a function to generate a error message
    -> Field m [a]
encodedListTextareaField (p_sep, sep) (p, render) mk_msg =
    checkMMap f (Textarea . T.intercalate sep . map render) textareaField
    where
        f t = case parse
                (skipMany p_sep >> p `sepEndBy` (eof <|> (void $ many1 p_sep)))
                "" (unTextarea t)
                of
                Left err -> return $ Left $ mk_msg $ show err
                Right x -> return $ Right x


-- | parse every line in textarea, each nonempty line parsed as a single value
lineSepListTextareaField ::
    (Monad m
    , RenderMessage (HandlerSite m) msg
    , RenderMessage (HandlerSite m) FormMessage
    ) =>
    (CharParser a, a -> Text)
                            -- ^ parse a single value and render a single value
    -> (String -> msg)      -- ^ a function to generate a error message
    -> Field m [a]
lineSepListTextareaField =
    encodedListTextareaField (newline, "\n")


-- | use whitespace to separate strings, and parsed into a list of values
wsSepListTextareaField ::
    (Monad m
    , RenderMessage (HandlerSite m) msg
    , RenderMessage (HandlerSite m) FormMessage
    ) =>
    (CharParser a, a -> Text)
                            -- ^ parse a single value and render a single value
    -> (String -> msg)      -- ^ a function to generate a error message
    -> Field m [a]
wsSepListTextareaField =
    encodedListTextareaField (space, "\n")


-- | can be used as a placeholder
emptyFieldView :: FieldView site
emptyFieldView = FieldView
                    { fvLabel       = Empty
                    , fvTooltip     = Nothing
                    , fvId          = ""
                    , fvInput       = return ()
                    , fvErrors      = Nothing
                    , fvRequired    = False
                    }

-- | XXX: not a very elegant way to judge whether a FieldView is empty or not
isEmptyFieldView :: FieldView site -> Bool
isEmptyFieldView fv = fvId fv == ""

fvClearErrors :: FieldView site -> FieldView site
fvClearErrors fv = fv { fvErrors = Nothing }

-- | call a function when FormResult is success,
-- otherwise use the default value
caseFormResult :: b -> (a -> b) -> FormResult a -> b
caseFormResult x _ FormMissing      = x
caseFormResult x _ (FormFailure _)  = x
caseFormResult _ f (FormSuccess r)  = f r


ifFormResult ::
    (a -> Bool)      -- ^ check value is expected
    -> FormResult a
    -> Bool             -- ^ if result is expected
ifFormResult = caseFormResult False

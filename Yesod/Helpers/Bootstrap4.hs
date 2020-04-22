{-# LANGUAGE FlexibleContexts  #-}
{-# LANGUAGE NamedFieldPuns    #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE QuasiQuotes       #-}
{-# LANGUAGE TypeFamilies      #-}
-- | this program based on Yesod.Form.Bootstrap3 of yesod-form
-- yesod-form under MIT license, author is Michael Snoyman <michael@snoyman.com>
--
-- base on yesod-form-bootstrap4-3.0.0
-- update according to latest bootstrap4
module Yesod.Helpers.Bootstrap4
  ( renderBootstrap4
  , BootstrapFormLayout(..)
  , BootstrapGridOptions(..)
  , bfs
  , bfsFile
  , withPlaceholder
  , withAutofocus
  , withLargeInput
  , withSmallInput
  , bootstrapSubmit
  , mbootstrapSubmit
  , BootstrapSubmit(..)
  , radioFieldBs4, radioFieldListBs4
  ) where

import           ClassyPrelude
import           Data.Choice
import qualified Data.Text.Lazy                as TL
import           Text.Blaze.Html.Renderer.Text
import           Yesod.Core
import           Yesod.Form

import           Yesod.Compat

bfs :: RenderMessage site msg => msg -> FieldSettings site
bfs msg
  = FieldSettings (SomeMessage msg) Nothing Nothing Nothing [("class", "form-control")]

bfsFile :: RenderMessage site msg => msg -> FieldSettings site
bfsFile msg
  = FieldSettings (SomeMessage msg) Nothing Nothing Nothing [("class", "form-control-file")]

withPlaceholder :: Text -> FieldSettings site -> FieldSettings site
withPlaceholder placeholder fs = fs { fsAttrs = newAttrs }
  where newAttrs = ("placeholder", placeholder) : fsAttrs fs

-- | Add an autofocus attribute to a field.
withAutofocus :: FieldSettings site -> FieldSettings site
withAutofocus fs = fs { fsAttrs = newAttrs }
  where newAttrs = ("autofocus", "autofocus") : fsAttrs fs

-- | Add the @input-lg@ CSS class to a field.
withLargeInput :: FieldSettings site -> FieldSettings site
withLargeInput fs = fs { fsAttrs = newAttrs }
  where newAttrs = addClass "form-control-lg" (fsAttrs fs)

-- | Add the @input-sm@ CSS class to a field.
withSmallInput :: FieldSettings site -> FieldSettings site
withSmallInput fs = fs { fsAttrs = newAttrs }
  where newAttrs = addClass "form-control-sm" (fsAttrs fs)

data BootstrapGridOptions = ColXs !Int | ColSm !Int | ColMd !Int | ColLg !Int | ColXl !Int
  deriving (Eq, Ord, Show, Read)

toColumn :: BootstrapGridOptions -> String
toColumn (ColXs columns) = "col-xs-" ++ show columns
toColumn (ColSm columns) = "col-sm-" ++ show columns
toColumn (ColMd columns) = "col-md-" ++ show columns
toColumn (ColLg columns) = "col-lg-" ++ show columns
toColumn (ColXl columns) = "col-xl-" ++ show columns

toOffset :: BootstrapGridOptions -> String
toOffset (ColXs columns) = "offset-xs-" ++ show columns
toOffset (ColSm columns) = "offset-sm-" ++ show columns
toOffset (ColMd columns) = "offset-md-" ++ show columns
toOffset (ColLg columns) = "offset-lg-" ++ show columns
toOffset (ColXl columns) = "offset-xl-" ++ show columns

addGO :: BootstrapGridOptions -> BootstrapGridOptions -> BootstrapGridOptions
addGO (ColXs a) (ColXs b) = ColXs (a+b)
addGO (ColSm a) (ColSm b) = ColSm (a+b)
addGO (ColMd a) (ColMd b) = ColMd (a+b)
addGO (ColLg a) (ColLg b) = ColLg (a+b)
addGO a b                 | a > b = addGO b a
addGO (ColXs a) other     = addGO (ColSm a) other
addGO (ColSm a) other     = addGO (ColMd a) other
addGO (ColMd a) other     = addGO (ColLg a) other
addGO _     _             = error "Yesod.Form.Bootstrap.addGO: never here"

-- | The layout used for the bootstrap form.
data BootstrapFormLayout = BootstrapBasicForm | BootstrapInlineForm |
  BootstrapHorizontalForm
  { bflLabelOffset :: !BootstrapGridOptions
  , bflLabelSize   :: !BootstrapGridOptions
  , bflInputOffset :: !BootstrapGridOptions
  , bflInputSize   :: !BootstrapGridOptions
  }
  deriving (Eq, Ord, Show, Read)


inputTypeRadioOrCheckbox :: Yesod site => FieldView site -> HandlerOf site Bool
inputTypeRadioOrCheckbox view = do
  html <- to_body_html (fvInput view)
  let textLabel = renderHtml html
  pure $ "\"radio\"" `TL.isInfixOf` textLabel || "\"checkbox\"" `TL.isInfixOf` textLabel
  where to_body_html widget = widgetToPageContent widget >>= withUrlRenderer . pageBody


-- | Render the given form using Bootstrap v4 conventions.
renderBootstrap4 :: (MonadHandler m, Yesod (HandlerSite m)) => BootstrapFormLayout -> FormRender m a
renderBootstrap4 formLayout aform fragment = do
  (res, views') <- aFormToForm aform
  let views = views' []

  views_is_check <-
    liftMonadHandler $ do
      forM views $ \ view -> do
        b <- inputTypeRadioOrCheckbox view
        pure (view, b)

  let widget = [whamlet|
#{fragment}
$forall (view, is_check_input) <- views_is_check
  $if is_check_input
    ^{renderCheckInput view formLayout}
  $else
    ^{renderGroupInput view formLayout}
|]
  return (res, widget)


-- FIXME: `.form-check-input`を`input`につける方法がわからない
renderCheckInput :: FieldView site -> BootstrapFormLayout -> WidgetFor site ()
renderCheckInput view formLayout = [whamlet|
$case formLayout
  $of BootstrapHorizontalForm labelOffset labelSize inputOffset inputSize
    <div .form-group>
      <div .row>
        <legend
          .col-form-label
          .#{toOffset labelOffset}
          .#{toColumn labelSize}
          for=#{fvId view}>#{fvLabel view}
        <div .#{toOffset inputOffset} .#{toColumn inputSize}>
          ^{fvInput view}
          ^{helpWidget view}

  $of _
    <div .form-check :is_invalid:.is-invalid>
      ^{fvInput view}
      ^{helpWidget view}
|]
  where is_invalid = isJust $ fvErrors view

renderGroupInput :: FieldView site -> BootstrapFormLayout -> WidgetFor site ()
renderGroupInput view formLayout = [whamlet|
$case formLayout
  $of BootstrapBasicForm
    $if fvId view /= bootstrapSubmitId
      <label for=#{fvId view}>#{fvLabel view}
    ^{fvInput view}
    ^{helpWidget view}
  $of BootstrapInlineForm
    $if fvId view /= bootstrapSubmitId
      <label .sr-only for=#{fvId view}>#{fvLabel view}
    ^{fvInput view}
    ^{helpWidget view}
  $of BootstrapHorizontalForm labelOffset labelSize inputOffset inputSize
    $if fvId view /= bootstrapSubmitId
      <div .row .form-group>
        <label
          .col-form-label
          .#{toOffset labelOffset}
          .#{toColumn labelSize}
          for=#{fvId view}>#{fvLabel view}
        <div .#{toOffset inputOffset} .#{toColumn inputSize}>
          ^{fvInput view}
          ^{helpWidget view}
    $else
      <div
        .#{toOffset (addGO inputOffset (addGO labelOffset labelSize))}
        .#{toColumn inputSize}>
        ^{fvInput view}
        ^{helpWidget view}
|]


-- | (Internal) Render a help widget for tooltips and errors.
-- .invalid-feedbackを必ず表示する
-- bootstrap 4.1の書式ではinputがerrorでなければエラーメッセージが出ませんが
-- yesod-formのAPIではfvInput自体を弄るのが困難ですし
-- yesod-formのAPI上fvErrorsが存在する時は常にエラーメッセージは表示させるべきなので汚いやり方ですが
-- styleを上書きして常に表示します
helpWidget :: FieldView site -> WidgetFor site ()
helpWidget view = [whamlet|
$maybe err <- fvErrors view
  <div .invalid-feedback style="display: block;">
    #{err}
$maybe tt <- fvTooltip view
  <small .form-text .text-muted>
    #{tt}
|]

-- | How the 'bootstrapSubmit' button should be rendered.
data BootstrapSubmit msg =
  BootstrapSubmit
  { bsValue   :: msg -- ^ The text of the submit button.
  , bsClasses :: Text -- ^ Classes added to the @\<button>@.
  , bsAttrs   :: [(Text, Text)] -- ^ Attributes added to the @\<button>@.
  } deriving (Eq, Ord, Show, Read)

instance IsString msg => IsString (BootstrapSubmit msg) where
  fromString msg = BootstrapSubmit (fromString msg) "btn-primary" []

-- | A Bootstrap v4 submit button disguised as a field for
-- convenience.  For example, if your form currently is:
--
-- > Person <$> areq textField "Name"  Nothing
-- >    <*> areq textField "Surname" Nothing
--
-- Then just change it to:
--
-- > Person <$> areq textField "Name"  Nothing
-- >    <*> areq textField "Surname" Nothing
-- >    <*  bootstrapSubmit ("Register" :: BootstrapSubmit Text)
--
-- (Note that '<*' is not a typo.)
--
-- Alternatively, you may also just create the submit button
-- manually as well in order to have more control over its
-- layout.
bootstrapSubmit :: (RenderMessage site msg, HandlerSite m ~ site, MonadHandler m) =>
  BootstrapSubmit msg -> AForm m ()
bootstrapSubmit = formToAForm . fmap (second return) . mbootstrapSubmit

-- | Same as 'bootstrapSubmit' but for monadic forms.  This isn't
-- as useful since you're not going to use 'renderBootstrap4'
-- anyway.
mbootstrapSubmit :: (RenderMessage site msg, HandlerSite m ~ site, MonadHandler m) =>
  BootstrapSubmit msg -> MForm m (FormResult (), FieldView site)
mbootstrapSubmit (BootstrapSubmit msg classes attrs) =
  let res = FormSuccess ()
      widget = [whamlet|<button class="btn #{classes}" type=submit *{attrs}>_{msg}|]
      fv  = FieldView
            { fvLabel    = ""
            , fvTooltip  = Nothing
            , fvId       = bootstrapSubmitId
            , fvInput    = widget
            , fvErrors   = Nothing
            , fvRequired = False
            }
  in return (res, fv)

-- | A royal hack.  Magic id used to identify whether a field
-- should have no label.  A valid HTML4 id which is probably not
-- going to clash with any other id should someone use
-- 'bootstrapSubmit' outside 'renderBootstrap4'.
bootstrapSubmitId :: Text
bootstrapSubmitId = "b:ootstrap___unique__:::::::::::::::::submit-id"


-- | Creates an input with @type="radio"@ for selecting one option.
-- base on source code of radioField from Yesod.Form
radioFieldBs4 :: (Eq a, RenderMessage site FormMessage)
              => Choice "inline"
              -> HandlerOf site (OptionList a)
              -> Field (HandlerOf site) a
radioFieldBs4 inline = selectFieldHelper
    (\ _theId _name _attrs inside -> [whamlet|
$newline never
^{inside}
|])
    (\theId name isSel -> [whamlet|
$newline never
<div ##{theId} .form-check :is_inline:.form-check-inline>
  <input id=#{theId}-none type=radio name=#{name} value=none :isSel:checked .form-check-input>
  <label .radio for=#{theId}-none .form-check-label>
    _{MsgSelectNone}
|])
    (\theId name attrs value isSel text -> [whamlet|
$newline never
<div ##{theId} .form-check :is_inline:.form-check-inline>
  <input id=#{theId}-#{value} type=radio name=#{name} value=#{value} :isSel:checked *{attrs} .form-check-input>
  <label .radio for=#{theId}-#{value} .form-check-label>
    #{text}
|])
  where is_inline = toBool inline

-- | Creates an input with @type="radio"@ for selecting one option.
radioFieldListBs4 :: (Eq a, RenderMessage site FormMessage, RenderMessage site msg)
                  => Choice "inline"
                  -> [(msg, a)]
                  -> Field (HandlerOf site) a
radioFieldListBs4 inline = radioFieldBs4 inline . optionsPairs

#if !MIN_VERSION_yesod_form(1, 6, 0)
-- | Copied from source of Yesod.Form.Types.
-- change signatures a little to make it compatible
selectFieldHelper
        :: (Eq a, RenderMessage site FormMessage)
        => (Text -> Text -> [(Text, Text)] -> WidgetOf site -> WidgetOf site)
        -> (Text -> Text -> Bool -> WidgetOf site)
        -> (Text -> Text -> [(Text, Text)] -> Text -> Bool -> Text -> WidgetOf site)
        -> HandlerOf site (OptionList a)
        -> Field (HandlerOf site) a
selectFieldHelper outside onOpt inside opts' = Field
    { fieldParse = \x _ -> do
        opts <- opts'
        return $ selectParser opts x
    , fieldView = \theId name attrs val isReq -> do
        opts <- fmap olOptions $ handlerToWidget opts'
        outside theId name attrs $ do
            unless isReq $ onOpt theId name $ not $ render opts val `elem` map optionExternalValue opts
            flip mapM_ opts $ \opt -> inside
                theId
                name
                ((if isReq then (("required", "required"):) else id) attrs)
                (optionExternalValue opt)
                ((render opts val) == optionExternalValue opt)
                (optionDisplay opt)
    , fieldEnctype = UrlEncoded
    }
  where
    render _ (Left _) = ""
    render opts (Right a) = maybe "" optionExternalValue $ listToMaybe $ filter ((== a) . optionInternalValue) opts
    selectParser _ [] = Right Nothing
    selectParser opts (s:_) = case s of
            "" -> Right Nothing
            "none" -> Right Nothing
            x -> case olReadExternal opts x of
                    Nothing -> Left $ SomeMessage $ MsgInvalidEntry x
                    Just y -> Right $ Just y
#endif

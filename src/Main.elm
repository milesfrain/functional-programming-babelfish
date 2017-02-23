module Main exposing (..)

import Navigation exposing (Location)
import Html exposing (..)
import Types exposing (..)
import Time exposing (Time)
import RemoteData exposing (RemoteData(..))
import Routing.Router as Router
import Http
import Decoders

main : Program Flags Model Msg
main =
    Navigation.programWithFlags UrlChange
        { init = init
        , update = update
        , view = view
        , subscriptions = \_ -> Time.every Time.minute TimeChange
        }

type alias Model =
    { appState : AppState
    , location : Location
    }
type AppState
    = NotReady Time
    | Ready Taco Router.Model

type alias Flags =
    { currentTime : Time
    }


type Msg
    = UrlChange Location
    | TimeChange Time
    | RouterMsg Router.Msg
    | HandleUserInformationResponse (RemoteData.WebData UserInformation)

init : Flags -> Location -> ( Model, Cmd Msg )
init flags location =
    ( { appState = NotReady flags.currentTime
      , location = location
      }
      , fetchUserInformation
    )

fetchUserInformation : Cmd Msg
fetchUserInformation =
    let
      url = "userInformation.json"
      req =  Http.request
        { method = "GET"
        , headers = []
        , url = url
        , body = Http.emptyBody
        , expect = Http.expectJson Decoders.decodeUserInformation
        , timeout = Nothing
        , withCredentials = True
        }
    in
      req
      |> RemoteData.sendRequest
      |> Cmd.map HandleUserInformationResponse

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        TimeChange time ->
            updateTime model time

        HandleUserInformationResponse webData ->
            updateUserInfo model webData

        UrlChange location ->
            updateRouter { model | location = location } (Router.UrlChange location)

        RouterMsg routerMsg ->
            updateRouter model routerMsg


updateTime : Model -> Time -> ( Model, Cmd Msg )
updateTime model time =
    case model.appState of
        NotReady _ ->
            ( { model | appState = NotReady time }
            , Cmd.none
            )

        Ready taco routerModel ->
            ( { model | appState = Ready (updateTaco taco (UpdateTime time)) routerModel }
            , Cmd.none
            )


updateRouter : Model -> Router.Msg -> ( Model, Cmd Msg )
updateRouter model routerMsg =
    case model.appState of
        Ready taco routerModel ->
            let
                nextTaco =
                    updateTaco taco tacoUpdate

                ( nextRouterModel, routerCmd, tacoUpdate ) =
                    Router.update routerMsg routerModel
            in
                ( { model | appState = Ready nextTaco nextRouterModel }
                , Cmd.map RouterMsg routerCmd
                )

        NotReady _ ->
            Debug.crash "Ooops. We got a sub-component message even though it wasn't supposed to be initialized?!?!?"


updateUserInfo : Model -> RemoteData.WebData UserInformation -> ( Model, Cmd Msg )
updateUserInfo model webData =
    case webData of
        Failure _ ->
            Debug.crash "OMG CANT EVEN DOWNLOAD."

        Success userInfo ->
            case model.appState of
                NotReady time ->
                    let
                        initTaco =
                            { currentTime = time
                            , userInfo = userInfo
                            }

                        ( initRouterModel, routerCmd ) =
                            Router.init model.location
                    in
                        ( { model | appState = Ready initTaco initRouterModel }
                        , Cmd.map RouterMsg routerCmd
                        )

                Ready taco routerModel ->
                    ( { model | appState = Ready (updateTaco taco (UpdateUserInfo userInfo)) routerModel }
                    , Cmd.none
                    )

        _ ->
            ( model, Cmd.none )

updateTaco : Taco -> TacoUpdate -> Taco
updateTaco taco tacoUpdate =
    case tacoUpdate of
        UpdateTime time ->
            { taco | currentTime = time }

        UpdateUserInfo userInfo ->
            { taco | userInfo = Debug.log "user" userInfo }

        NoUpdate ->
            taco

view : Model -> Html Msg
view model =
    case model.appState of
        Ready taco routerModel ->
            Router.view taco routerModel
                |> Html.map RouterMsg

        NotReady _ ->
            text "Loading"

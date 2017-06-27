module Maps.Map exposing
  ( Map
  , move
  , zoom
  , zoomTo
  , viewBounds
  , drag
  , tiles
  )

{-| This module defines the Map type and functions.
The Map type is used for configuring the view of the map.

# Definitions
@docs Map

# Transformations
@docs move
@docs zoom
@docs zoomTo
@docs viewBounds
@docs drag

# Map Tiles
@docs tiles
-}

import Maps.Screen as Screen exposing (ZoomLevel)
import Maps.LatLng as LatLng exposing (LatLng)
import Maps.Bounds as Bounds exposing (Bounds)
import Maps.Tile as Tile exposing (Tile)
import Maps.Drag as Drag exposing (Drag)
import Maps.Zoom as Zoom
import Maps.Utils exposing (wrap, cartesianMap)

{-| The Map type stores the properties neccessary for displaying a map.

The tileServer property is a URL template of the form

    "http://somedomain.com/blabla/{z}/{x}/{y}.png"

Where {z} is the zoom level and {x}/{y} are the x/y tile coordinates.

The zoom and center define the area being viewed.

The width and height define the width and height of the map in pixels.

The tileSize defines the size of an individual tile in pixels (this is usually 256px).
-}
type alias Map =
  { tileServer : String
  , zoom : ZoomLevel
  , center : LatLng
  , width : Float
  , height : Float
  , tileSize : Float
  }

{-| Moves the map the number of pixels given by the offset.
-}
move : Screen.Offset -> Map -> Map
move offset map =
  let
    mapTile = Tile.fromLatLng (toFloat <| ceiling map.zoom) map.center
    tile = Screen.offsetToTileOffset map.tileSize offset
    center =
      Tile.toLatLng
        (toFloat <| ceiling map.zoom)
        (mapTile.x - tile.x)
        (mapTile.y - tile.y)
  in
    { map | center = center }

{-| Zooms the map in or out from the center of the map.
-}
zoom : ZoomLevel -> Map -> Map
zoom zoomLevel map =
  { map | zoom = min 19 <| max 0 <| map.zoom + zoomLevel }

{-| Zooms the map in or out from the point given.
-}
zoomTo : ZoomLevel -> Screen.Offset -> Map -> Map
zoomTo zoomLevel offset map =
  map
  |> move { x = map.width/2 - offset.x, y = map.height/2 - offset.y }
  |> zoom zoomLevel
  |> move { x = -(map.width/2 - offset.x), y = -(map.height/2 - offset.y) }

{-| Moves the map to display the entire bounds given.
-}
viewBounds : Bounds -> Map -> Map
viewBounds bounds map =
  let
    zoom = Bounds.zoom map.tileSize map.width map.height bounds
  in
    { map | zoom = zoom, center = Bounds.center bounds }

{-| Applies a drag (like a mouse drag) to the map
-}
drag : Drag -> Map -> Map 
drag dragState map =
  move (Drag.offset dragState) map

{-| Returns the list of tiles necessary to fetch to display the map.
-}
tiles : Map -> List Tile
tiles map =
  let
    xCount = map.width/map.tileSize
    yCount = map.height/map.tileSize
    tile = Tile.fromLatLng (toFloat <| ceiling map.zoom) map.center
    xTiles = List.range (floor <| -xCount/2) (ceiling <| xCount/2)
    yTiles = List.range (floor <| -yCount/2) (ceiling <| yCount/2)
    wrapTile = wrap 0 (2^(ceiling map.zoom))
    tileXY x y =
      ( Tile.url
        map.tileServer
        (ceiling map.zoom)
        (floor tile.x + x |> wrapTile)
        (floor tile.y + y |> wrapTile)
      , Tile.Offset
        (map.width/2  + (toFloat (floor tile.x) - tile.x + toFloat x) * map.tileSize)
        (map.height/2 + (toFloat (floor tile.y) - tile.y + toFloat y) * map.tileSize)
      )
  in
    cartesianMap tileXY xTiles yTiles
      |> List.concat
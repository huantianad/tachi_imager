import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic, bool, field, float, int, list, string}
import gleam/hackney
import gleam/http/request
import gleam/int
import gleam/io
import gleam/json
import gleam/list
import gleam/result
import gleam/string_builder
import gleeunit/should

const tachi_url = "https://kamai.tachi.ac/api/"

pub type ChartId =
  String

pub type SongId =
  Int

pub type GameIdentifier {
  GameIdentifier(name: String, playtype: String)
}

pub type TachiPBResponse {
  TachiPBResponse(
    pbs: List(TachiPB),
    songs: Dict(SongId, TachiSong),
    charts: Dict(ChartId, TachiChart),
  )
}

pub type TachiPB {
  TachiPB(
    chart_id: ChartId,
    song_id: SongId,
    rating: Float,
    score: Int,
    lamp: String,
    grade: String,
  )
}

pub type TachiSong {
  TachiSong(song_id: SongId, title: String, artist: String)
}

pub type TachiChart {
  TachiChart(
    chart_id: ChartId,
    song_id: SongId,
    difficulty: String,
    level: String,
  )
}

pub fn try_dynamic(
  r: Result(a, b),
  f: fn(a) -> Result(c, Dynamic),
) -> Result(c, Dynamic) {
  result.try(result.map_error(r, dynamic.from), f)
  |> result.map_error(dynamic.from)
}

pub fn get_pb_endpoint(user: String, game: GameIdentifier) -> String {
  string_builder.from_strings([
    tachi_url,
    "v1/users/",
    user,
    "/games/",
    game.name,
    "/",
    game.playtype,
    "/pbs/best",
  ])
  |> string_builder.to_string
}

pub fn fetch_pbs(user: String, game: GameIdentifier) -> Result(String, Dynamic) {
  let assert Ok(request) = request.to(get_pb_endpoint(user, game))

  use response <- try_dynamic(hackney.send(request))

  use _ <- try_dynamic(case response.status {
    200 -> Ok(Nil)
    x ->
      Error(
        "Tachi returned error code: "
        <> int.to_string(x)
        <> "\nResponse body: "
        <> response.body,
      )
  })

  Ok(response.body)
}

fn has_duplicates(list: List(a)) -> Bool {
  case list {
    [] -> False
    [x, ..rest] -> list.any(rest, fn(y) { x == y }) || has_duplicates(rest)
  }
}

fn indexify(list: List(a), f: fn(a) -> b) -> Dict(b, a) {
  let has_dupes = list |> list.map(f) |> has_duplicates
  should.be_false(has_dupes)

  list |> list.map(fn(x) { #(f(x), x) }) |> dict.from_list
}

pub fn parse_pbs(body: String) -> Result(TachiPBResponse, json.DecodeError) {
  let pb_decoder =
    list(of: dynamic.decode6(
      TachiPB,
      field("chartID", of: string),
      field("songID", of: int),
      field("calculatedData", of: field("VF6", of: float)),
      field("scoreData", of: field("score", of: int)),
      field("scoreData", of: field("lamp", of: string)),
      field("scoreData", of: field("grade", of: string)),
    ))

  let song_decoder = fn(x) {
    x
    |> list(of: dynamic.decode3(
      TachiSong,
      field("id", of: int),
      field("title", of: string),
      field("artist", of: string),
    ))
    |> result.map(indexify(_, fn(x: TachiSong) { x.song_id }))
  }

  let chart_decoder = fn(x) {
    x
    |> list(of: dynamic.decode4(
      TachiChart,
      field("chartID", of: string),
      field("songID", of: int),
      field("difficulty", of: string),
      field("level", of: string),
    ))
    |> result.map(indexify(_, fn(x: TachiChart) { x.chart_id }))
  }

  let response_decoder =
    dynamic.decode2(
      fn(success, body) {
        should.be_true(success)
        body
      },
      field("success", of: bool),
      field(
        "body",
        of: dynamic.decode3(
          TachiPBResponse,
          field("pbs", of: pb_decoder),
          field("songs", of: song_decoder),
          field("charts", of: chart_decoder),
        ),
      ),
    )

  json.decode(from: body, using: response_decoder)
}

type Image

@external(erlang, "image", "Image")
fn new(width: Int, length: Int) -> Image

@external(erlang, "image", "Image")
fn write(image: Image, image_path: String) -> Dynamic

pub fn main() {
  use response <- result.try(fetch_pbs(
    "huantian",
    GameIdentifier("sdvx", "Single"),
  ))
  io.debug(response)
  use parsed <- try_dynamic(parse_pbs(response))

  io.debug(parsed)

  write(new(100, 100), "asdf.png")

  Ok(Nil)
}

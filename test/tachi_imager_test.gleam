import gleeunit
import gleeunit/should
import tachi_imager

pub fn main() {
  gleeunit.main()
}

pub fn endpoint_test() {
  tachi_imager.get_pb_endpoint(
    "huantian",
    tachi_imager.GameIdentifier("sdvx", "Single"),
  )
  |> should.equal(
    "https://kamai.tachi.ac/api/v1/users/huantian/games/sdvx/Single/pbs/best",
  )
}

pub fn main_test() {
  tachi_imager.main()
  |> should.equal(Ok(Nil))
}

(* The MIT License (MIT)

   Copyright (c) 2014 Nicolas Ojeda Bar <n.oje.bar@gmail.com>

   Permission is hereby granted, free of charge, to any person obtaining a copy
   of this software and associated documentation files (the "Software"), to deal
   in the Software without restriction, including without limitation the rights
   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
   copies of the Software, and to permit persons to whom the Software is
   furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be included in
   all copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
   SOFTWARE. *)

open ImapTypes
open ImapTypesPrivate
  
type ('a, 'state, 'err) result =
    Ok of 'a * 'state * int
  | Fail of 'err
  | Need of (input -> ('a, 'state, 'err) result)
  | Flush of string * ('a, 'state, 'err) result

type ('a, 'state, 'err) control =
  'state -> Buffer.t -> Buffer.t -> int -> ('a, 'state, 'err) result

let flush st buf _ i =
  let str = Buffer.contents buf in
  Buffer.clear buf;
  Flush (str, Ok ((), st, i))

let bind m f st buf b i =
  let rec loop =
    function
      Ok (x, st, i) -> f x st buf b i
    | Fail _ as x -> x
    | Need k -> Need (fun inp -> loop (k inp))
    | Flush (buf, r) -> Flush (buf, loop r)
  in
  loop (m st buf b i)

let fail err _ _ _ _ =
  Fail err
    
let liftP p st _ b i =
  let rec loop =
    function
      ImapTypesPrivate.Ok (x, i) -> Ok (x, st, i)
    | ImapTypesPrivate.Fail _ -> Fail ParseError
    | ImapTypesPrivate.Need k -> Need (fun inp -> loop (k inp))
  in
  loop (p b i)
      
let send s st buf _ i =
  Buffer.add_string buf s;
  Ok ((), st, i)

let ret x st _ _ i =
  Ok (x, st, i)

let gets f st _ _ i =
  Ok (f st, st, i)

let modify f st _ _ i =
  Ok ((), f st, i)

let get st _ _ i =
  Ok (st, st, i)

let put st _ _ _ i =
  Ok ((), st, i)

let catch f g st buf b i =
  let rec loop =
    function
      Ok _ as ok -> ok
    | Fail err -> g err st buf b i
    | Need k -> Need (fun inp -> loop (k inp))
    | Flush (str, r) -> Flush (str, loop r)
  in
  loop (f st buf b i)

let (>>=) = bind
let (>>) m1 m2 = m1 >>= fun _ -> m2

let run m st b i =
  m st (Buffer.create 0) b i

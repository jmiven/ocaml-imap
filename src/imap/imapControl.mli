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

type ('a, 'state, 'control) control

val flush : (unit, _, _) control

val bind : ('a, 'state, 'err) control -> ('a -> ('b, 'state, 'err) control) -> ('b, 'state, 'err) control

val fail : 'err -> (_, _, 'err) control

val liftP : 'a parser -> ('a, _, error) control

val send : string -> (unit, _, _) control

val ret : 'a -> ('a, _, _) control

val gets : ('state -> 'a) -> ('a, 'state, _) control

val modify : ('state -> 'state) -> (unit, 'state, _) control

val get : ('state, 'state, _) control

val put : 'state -> (unit, 'state, _) control

val catch : ('a, 'state, 'err) control -> ('err -> ('a, 'state, 'err) control) -> ('a, 'state, 'err) control

val try_bind : ('a, 'state, 'err) control -> ('a -> ('b, 'state, 'err1) control) -> ('err -> ('b, 'state, 'err1) control) -> ('b, 'state, 'err1) control

val (>>=) : ('a, 'state, 'err) control -> ('a -> ('b, 'state, 'err) control) -> ('b, 'state, 'err) control

val (>>) : (_, 'state, 'err) control -> ('a, 'state, 'err) control -> ('a, 'state, 'err) control

val lift : ('state -> 'state1) -> ('state -> 'state1 -> 'state) -> ('a, 'state1, 'err) control -> ('a, 'state, 'err) control

(* val run : ('a, 'state, 'err) control -> 'state -> Buffer.t -> int -> ('a, 'state, 'err) result *)

module type CONTROL = sig
  type error
  type 'a t
  val ret : 'a -> 'a t
  val bind : 'a t -> ('a -> 'b t) -> 'b t
  val fail : error -> _ t
  type io
  val input : io -> string -> int -> int -> int t
  val output : io -> string -> int -> int -> int t
end

module MakeRun (IO : CONTROL) : sig
  val run : ('a, 'state, IO.error) control -> IO.io -> 'state -> Buffer.t -> int -> ('a * 'state * int) IO.t
end
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

open Imap

let (>>=) = Lwt.bind

let _ = Ssl.init ()

module Lwtio = struct
  type 'a t = 'a Lwt.t

  let bind = Lwt.bind

  let return = Lwt.return

  let fail = Lwt.fail

  let catch = Lwt.catch

  type mutex = Lwt_mutex.t

  let create_mutex = Lwt_mutex.create

  let is_locked = Lwt_mutex.is_locked

  let with_lock = Lwt_mutex.with_lock

  type input = Lwt_io.input_channel

  type output = Lwt_unix.file_descr * Lwt_io.output_channel

  let read_line ic =
    Lwt_io.read_line ic >>= fun s ->
    if !Client.debug then begin
      Utils.log `Server s;
      Utils.log `Server "\r\n"
    end;
    Lwt.return s

  let read_exactly ic len =
    let buf = String.create len in
    Lwt_io.read_into_exactly ic buf 0 len >>= fun () ->
    if !Client.debug then Utils.log `Server buf;
    Lwt.return buf

  let write (_, oc) s = Lwt_io.write oc s >>= fun () ->
    if !Client.debug then Utils.log `Client s;
    Lwt.return ()

  let flush (_, oc) = Lwt_io.flush oc

  let compress _ = assert false

  let connect port host =
    let fd = Lwt_unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
    Lwt_unix.gethostbyname host >>= fun he ->
    Lwt_unix.connect fd (Unix.ADDR_INET (he.Unix.h_addr_list.(0), port)) >>= fun () ->
    let ic = Lwt_io.of_fd ~mode:Lwt_io.Input fd in
    let oc = Lwt_io.of_fd ~mode:Lwt_io.Output fd in
    Lwt.return (ic, (fd, oc))

  let _ = Ssl.init ()

  let ssl_context v ca =
    let v = match v with
      | `TLSv1 -> Ssl.TLSv1
      | `SSLv23 -> Ssl.SSLv23
      | `SSLv3 -> Ssl.SSLv3
    in
    let ctx = Ssl.create_context v Ssl.Client_context in
    begin match ca with
      | None -> ()
      | Some ca ->
        Ssl.load_verify_locations ctx ca "";
        Ssl.set_verify ctx [Ssl.Verify_peer] None
    end;
    ctx

  let connect_ssl version ?ca_file port host =
    let fd = Lwt_unix.socket Unix.PF_INET Unix.SOCK_STREAM 0 in
    Lwt_unix.gethostbyname host >>= fun he ->
    Lwt_unix.connect fd (Unix.ADDR_INET (he.Unix.h_addr_list.(0), port)) >>= fun () ->
    Lwt_ssl.ssl_connect fd (ssl_context version ca_file) >>= fun ssl_sock ->
    let ic = Lwt_ssl.in_channel_of_descr ssl_sock in
    let oc = Lwt_ssl.out_channel_of_descr ssl_sock in
    Lwt.return (ic, (fd, oc))

  let starttls version ?ca_file (_, (fd, _)) =
    Lwt_ssl.ssl_connect fd (ssl_context version ca_file) >>= fun ssl_sock ->
    let ic = Lwt_ssl.in_channel_of_descr ssl_sock in
    let oc = Lwt_ssl.out_channel_of_descr ssl_sock in
    Lwt.return (ic, (fd, oc))
end

include Client.Make (Lwtio)

(* let compress s = *)
(*   let aux (ic, oc) = *)
(*     let low = Lwtio.get_low ic in *)
(*     let low = Lwtio.Low.compress low in *)
(*     Lwtio.set_low ic low; *)
(*     Lwtio.set_low oc low; *)
(*     Lwt.return (ic, oc) *)
(*   in *)
(*   compress s aux *)

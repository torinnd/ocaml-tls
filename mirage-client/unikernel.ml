open Lwt

let red fmt    = Printf.sprintf ("\027[31m"^^fmt^^"\027[m")
let green fmt  = Printf.sprintf ("\027[32m"^^fmt^^"\027[m")
let yellow fmt = Printf.sprintf ("\027[33m"^^fmt^^"\027[m")
let blue fmt   = Printf.sprintf ("\027[36m"^^fmt^^"\027[m")

module Main (C: V1_LWT.CONSOLE) (S: V1_LWT.STACKV4) = struct

  let on_connect hello c (flow : S.TCPV4.flow) =
    let rec loop tls =
      S.TCPV4.read flow >>= function
        | `Eof     -> C.log_s c (red "read: eof")
        | `Error e -> C.log_s c (red "read: error")
        | `Ok buf  ->
            let (tls', ans) = Tls.Client.handle_tls tls buf in
            S.TCPV4.write flow ans >> loop tls'
    in
    let (tls', ans) = Tls.Client.handle_tls Tls.Flow.empty_state hello in
    S.TCPV4.write flow ans >>
    try_lwt loop tls'
    finally S.TCPV4.close flow

  let connect_client s c =
    let ip = Ipaddr.V4.make 10 0 0 1 in
    S.TCPV4.create_connection (S.tcpv4 s) (ip, 4433) >>= function
     | `Ok flow ->
        let client_hello = Tls.Client.open_connection in
        on_connect client_hello c flow;
     | `Error e -> assert false


  let on_server_connect s c flow =
    let rec loop tls =
      S.TCPV4.read flow >>= function
        | `Eof     -> C.log_s c (red "read: eof")
        | `Error e -> C.log_s c (red "read: error")
        | `Ok buf  ->
            let (tls', ans) = Tls.Server.handle_tls tls buf in
            S.TCPV4.write flow ans >> loop tls'
    in
    let (dst, dst_port) = S.TCPV4.get_dest flow in
    C.log_s c (green "new tcp connection from %s %d"
                (Ipaddr.V4.to_string dst) dst_port)
    >>
      connect_client s c
    >>
    try_lwt loop Tls.Flow.empty_state
    finally S.TCPV4.close flow

  let start c s =
    S.listen_tcpv4 s ~port:80 (on_server_connect s c) ;
    S.listen s

end

type image = { url : string; watermarked : bool }
type reason = Quota | Rejected | Sign_in | Auth | Timeout | Other

let string_of_reason = function
  | Quota -> "quota" | Rejected -> "rejected" | Sign_in -> "sign_in"
  | Auth -> "auth" | Timeout -> "timeout" | Other -> "other"

let base_url = ref "https://www.kavel.ai"
let fail r msg = Error (r, "kavel: " ^ msg)

let () = Random.self_init ()

let anon_id () =
  "ml-" ^ String.concat "" (List.init 8 (fun _ -> Printf.sprintf "%02x" (Random.int 256)))

let key_of = function
  | Some k when k <> "" -> Some k
  | _ -> (match Sys.getenv_opt "KAVEL_API_KEY" with Some k when k <> "" -> Some k | _ -> None)

let contains s sub =
  let n = String.length s and m = String.length sub in
  let rec go i = i + m <= n && (String.sub s i m = sub || go (i + 1)) in
  go 0

let member k = function `Assoc l -> (try List.assoc k l with Not_found -> `Null) | _ -> `Null
let str = function `String s -> s | _ -> ""

(* Refusals answer HTTP 200 with code -1 and a human message. *)
let request ?body url headers =
  let res =
    match body with
    | Some b ->
      Ezcurl.post ~headers:(("Content-Type", "application/json") :: headers)
        ~content:(`String b) ~params:[] ~url ()
    | None -> Ezcurl.get ~headers ~url ()
  in
  match res with
  | Error (_, msg) -> fail Other msg
  | Ok resp ->
    (match Yojson.Safe.from_string resp.Ezcurl.body with
     | exception _ -> fail Other "unexpected response"
     | env ->
       (match member "code" env with
        | `Int 0 -> Ok (member "data" env)
        | _ ->
          let msg = match member "message" env with `String s -> s | _ -> "request refused" in
          let low = String.lowercase_ascii msg in
          let r =
            if contains low "invalid api key" then Auth
            else if contains low "insufficient credits" then Quota
            else if contains low "sign in" || contains low "subscription" then Sign_in
            else Other
          in
          fail r msg))

let run ?api_key ?(poll_seconds = 5.) ?(timeout_seconds = 360.) payload =
  let key = key_of api_key in
  let auth =
    match key with Some k -> [ ("Authorization", "Bearer " ^ k) ] | None -> [ ("x-anon-id", anon_id ()) ]
  in
  let deadline = Unix.gettimeofday () +. timeout_seconds in
  match request ~body:(Yojson.Safe.to_string payload) (!base_url ^ "/api/ai/generate") auth with
  | Error e -> Error e
  | Ok d ->
    (* The quota wall answers 200 with code 0 and wall: true. *)
    if member "wall" d = `Bool true then
      match str (member "reason" d) with
      | "anon_ip_daily" -> fail Quota "this machine has used its free credits for today"
      | "anon_unmetered_video" -> fail Sign_in "this needs a signed-in account"
      | _ -> fail Quota "the free allowance does not cover this run"
    else
      let task = str (member "id" d) in
      if task = "" then fail Other "the service returned no task id"
      else
        let rec poll () =
          if Unix.gettimeofday () > deadline then fail Timeout "no image before the deadline"
          else begin
            Unix.sleepf poll_seconds;
            let polled =
              match key with
              | Some _ ->
                request ~body:(Yojson.Safe.to_string (`Assoc [ ("taskId", `String task) ]))
                  (!base_url ^ "/api/ai/query") auth
              | None ->
                request
                  (!base_url ^ "/api/ai/anon-query?taskId=" ^ Uri_escape.encode task
                   ^ "&provider=kie&mediaType=image")
                  auth
            in
            match polled with
            (* Free runs only start when a poll crosses the end of the queue, so a
               dropped poll is not a failed job: keep going. *)
            | Error _ -> poll ()
            | Ok p ->
              (match member "cleanImages" p, member "images" p with
               | `List (`String u :: _), _ -> Ok { url = u; watermarked = false }
               | _, `List (`String u :: _) ->
                 let wm = match member "watermarked" p with `List (`Bool b :: _) -> b | _ -> false in
                 Ok { url = u; watermarked = wm }
               | _ ->
                 (match str (member "status" p) with
                  | "failed" | "error" -> fail Rejected "prompt refused; reword it"
                  | _ -> poll ()))
          end
        in
        poll ()

let generate ?(aspect_ratio = "1:1") ?api_key ?model ?poll_seconds ?timeout_seconds prompt =
  if String.trim prompt = "" then fail Other "prompt is required"
  else
    let model =
      match key_of api_key, model with Some _, Some m -> m | _ -> "kavel-image-v1"
    in
    run ?api_key ?poll_seconds ?timeout_seconds
      (`Assoc
        [ ("provider", `String "kie"); ("mediaType", `String "image"); ("model", `String model);
          ("scene", `String "text-to-image"); ("prompt", `String prompt);
          ("options", `Assoc [ ("aspect_ratio", `String aspect_ratio) ]) ])

let edit ?api_key ?model ?poll_seconds ?timeout_seconds source_url instruction =
  let starts p s = String.length s >= String.length p && String.sub s 0 (String.length p) = p in
  if not (starts "http://" source_url || starts "https://" source_url) then
    fail Other "source_url must be a public http(s) url"
  else if String.trim instruction = "" then fail Other "instruction is required"
  else
    let model =
      match key_of api_key, model with Some _, Some m -> m | _ -> "nano-banana-2-lite"
    in
    run ?api_key ?poll_seconds ?timeout_seconds
      (`Assoc
        [ ("provider", `String "kie"); ("mediaType", `String "image"); ("model", `String model);
          ("scene", `String "image-to-image"); ("prompt", `String instruction);
          ("options", `Assoc [ ("image_input", `List [ `String source_url ]) ]) ])

let credits () =
  match request (!base_url ^ "/api/ai/anon-credits") [ ("x-anon-id", anon_id ()) ] with
  | Error e -> Error e
  | Ok d ->
    (match member "remaining" d, member "grant" d with
     | `Int r, `Int g -> Ok (r, g)
     | _ -> fail Other "unexpected response")

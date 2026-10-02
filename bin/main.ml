(* kavel "an isometric coffee shop, pastel palette" *)
let () =
  let prompt = String.concat " " (List.tl (Array.to_list Sys.argv)) in
  if prompt = "" then (prerr_endline "usage: kavel \"your prompt\""; exit 2);
  match Kavel.generate prompt with
  | Ok img -> print_endline img.Kavel.url
  | Error (r, msg) -> prerr_endline (Kavel.string_of_reason r ^ ": " ^ msg); exit 1

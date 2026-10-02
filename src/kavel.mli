(** Generate and edit AI images with no API key and no account.

    {[
      match Kavel.generate "matte black ceramic mug on pale oak, soft window light" with
      | Ok img -> print_endline img.url
      | Error (reason, msg) -> prerr_endline (Kavel.string_of_reason reason ^ ": " ^ msg)
    ]}

    Without a key this calls the anonymous tier of {{:https://www.kavel.ai} Kavel}, which
    meters a small free allowance against a client id this library invents rather than an
    account you register. Pass [~api_key] (or set [KAVEL_API_KEY]) to run on your account. *)

type image = { url : string;  (** permanent, cacheable CDN link *) watermarked : bool }

type reason =
  | Quota  (** free allowance spent; wait, or pass a key *)
  | Rejected  (** prompt refused; reword it *)
  | Sign_in  (** needs an account *)
  | Auth  (** invalid API key *)
  | Timeout  (** no image before the deadline *)
  | Other

val string_of_reason : reason -> string

val base_url : string ref
(** Service root, changeable for a test or a proxy. *)

val generate :
  ?aspect_ratio:string -> ?api_key:string -> ?model:string -> ?poll_seconds:float ->
  ?timeout_seconds:float -> string -> (image, reason * string) result
(** Turn a prompt into a new image. [aspect_ratio] is ["1:1"] (default), ["16:9"], ["9:16"],
    ["4:3"] or ["3:4"]. Naming the light, the material and the composition moves the result
    far more than adding adjectives. *)

val edit :
  ?api_key:string -> ?model:string -> ?poll_seconds:float -> ?timeout_seconds:float ->
  string -> string -> (image, reason * string) result
(** [edit source_url instruction] rewrites the image at a public url. An edit costs more than
    the free allowance, so without a key this returns [Quota] before anything is charged. *)

val credits : unit -> (int * int, reason * string) result
(** [(remaining, grant)] for a fresh anonymous client id. Free to call. *)

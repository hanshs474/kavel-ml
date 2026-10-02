# kavel

Generate AI images from OCaml with **no API key and no account**.

```bash
opam install kavel
kavel "an isometric coffee shop, pastel palette"
```

```ocaml
match Kavel.generate ~aspect_ratio:"16:9"
        "matte black ceramic mug on pale oak, soft window light" with
| Ok img -> print_endline img.Kavel.url   (* https://cdn.kavel.ai/uploads/kie/image/....webp *)
| Error (reason, msg) -> prerr_endline (Kavel.string_of_reason reason ^ ": " ^ msg)
```

Every other image client wants a key from OpenAI, fal or Replicate before it runs once. This one
calls the anonymous tier of [Kavel](https://www.kavel.ai/?utm_source=opam&utm_medium=package), an
online AI image and video studio, with a client id it invents instead of an account you register.

## Results you can match on

Nothing raises. Errors are `(reason, message)` where `reason` is `Quota` (wait, or pass a key),
`Rejected` (reword the prompt), `Sign_in`, `Auth`, `Timeout` or `Other`.

## The free tier

`Kavel.credits ()` reads what a fresh client id is granted, and the call costs nothing. On 2026-10-02 the
grant was 5 credits, one generated image spent all five, and one IP got two images that day. Free
output is 1K and watermarked, and free runs queue before the model starts, so the default deadline
is six minutes.

## Editing a photo

```ocaml
Kavel.edit ?api_key:(Sys.getenv_opt "KAVEL_API_KEY")
  "https://example.com/portrait.jpg"
  "shoulder-length layered haircut, keep the same face, skin and lighting"
```

An edit costs more than the free grant, so it needs a key from
[kavel.ai/settings/apikeys](https://www.kavel.ai/settings/apikeys?utm_source=opam&utm_medium=package).
Without one it returns `Quota` before anything is charged.

## License

MIT. Generated with [Kavel AI](https://www.kavel.ai/?utm_source=opam&utm_medium=package).

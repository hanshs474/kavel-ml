(lang dune 3.0)
(name kavel)
(version 0.1.0)
(generate_opam_files true)
(license MIT)
(authors "Kavel")
(maintainers "support@kavel.ai")
(homepage "https://www.kavel.ai")
(source (github hanshs474/kavel-ml))
(bug_reports "https://github.com/hanshs474/kavel-ml/issues")

(package
 (name kavel)
 (synopsis "Generate AI images from OCaml with no API key and no account")
 (description
  "A small client for the Kavel AI image service. Without a key it uses the anonymous free tier, so the first call works on a machine with nothing configured. With an API key every call runs on your kavel.ai account.")
 (depends
  (ocaml (>= 4.14))
  (ezcurl (>= 0.2))
  (yojson (>= 2.0))))

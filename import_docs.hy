#!/usr/bin/env hy

(import
  re
  sys
  subprocess
  pathlib [Path]
  lxml.html)

(setv top-dir (Path (get sys.argv 1)))

(setv hy-version "doc-testing") ;(get (re.search "'(.+?)'" (.read-text (/ top-dir "hy" "hy" "version.py"))) 1))
(setv out-dir (/ (Path "site/hy/doc") hy-version))

(subprocess.run :check True ["rsync"
  "--protect-args" "-a"
  "--delete" "--delete-excluded"
  "--exclude=*.js" "--exclude=.*"
  "--exclude=search.html" "--exclude=*-modindex.html"
  "--exclude=genindex.html"
  f"{top-dir}/hy/docs/_build/"
  out-dir])

(for [fname (.iterdir (Path out-dir))  :if (= fname.suffix ".html")]

  (setv doc (lxml.html.parse fname))
  (.unlink fname)
  (for [e (list (.iter doc))]

    ; Delete all JavaScript.
    (when (or
        (= e.tag "script")
        (and (= e.tag "link") (= (.get e "rel") "search")))
      (.drop-tree e)
      (continue))

    ; Delete links to the generated indices.
    (when (and
        (= e.tag "a")
        (in (.get e "title") ["General Index" "Hy Module Index"]))
      (.drop-tree (.getparent e))
      (continue))

    ; Loop through internal URLs.
    (for [url-attr ["href" "src"]]
      (defn href []
        (.get e url-attr))
      (defn set-href [value]
        (.set e url-attr value))
      (when (or (is (href) None) (re.match "#|https?://" (href)))
        (continue))
      ; Strip HTML file extensions in internal links.
      (set-href (re.sub r"\.html\b" "" (href)))
      ; Don't refer to "index" explicitly.
      (when (= (href) "index")
        (set-href ""))
      ; Make internal links absolute, so they're robust to the removal
      ; of trailing slashes from URLs.
      (when (not (.startswith (href) "/"))
        (set-href f"/hy/doc/{hy-version}/{(href)}"))))

  ; Write out to a new HTML file with the file extension removed.
  (.write-bytes (/ fname.parent fname.stem) (lxml.html.tostring doc)))

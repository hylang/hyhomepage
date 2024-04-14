#!/usr/bin/env hy

(import
  re
  sys
  subprocess
  pathlib [Path]
  lxml.html)

(setv top-dir (Path (get sys.argv 1)))

(setv versions (dict
  :hy "doc-testing"
  :hyrule "doc-testing"))
(setv landing-page (Path "site/index"))

(for [project ["hy" "hyrule"]]
  (setv version (get versions project))
  (setv out-dir (/ (Path "site") project "doc" version))

  (subprocess.run :check True ["rsync"
    "--protect-args" "-a"
    "--delete" "--delete-excluded"
    "--exclude=*.js" "--exclude=.*"
    "--exclude=search.html" "--exclude=*-modindex.html"
    "--exclude=genindex.html"
    f"{top-dir}/{project}/docs/_build/"
    out-dir])

  (for [fname (.iterdir (Path out-dir))  :if (= fname.suffix ".html")]

    (setv doc (lxml.html.parse fname))
    (.unlink fname)

    (defn xp [#* xs]
      (sum :start [] (lfor
        x xs
        (.xpath doc (+ "//" x)))))

    ; Delete all JavaScript.
    (for [e (xp "script" "link[rel='search']")]
      (.drop-tree e))

    ; Delete links to the generated indices.
    (for [e (xp "a")]
      (when (in (.get e "title") ["General Index" "Hy Module Index"])
        (.drop-tree (.getparent e))))

    ; Apply some simplifications for a single-page manual.
    (when (= project "hyrule")
      (for [tag ["title" "h1"]]
        (setv (. (xp tag) [0] text) f"Hyrule {version} manual"))
      ; Delete breadcrumb links.
      (for [e (xp "*[@aria-label = 'related navigation']")]
        (.drop-tree e)))

    ; Loop through internal URLs.
    (for [url-attr ["href" "src"]  e (xp f"*[@{url-attr}]")]
      (defn href []
        (.get e url-attr))
      (defn set-href [value]
        (.set e url-attr value))
      (when (or (is (href) None) (re.match "#|[a-z]+://" (href)))
        (continue))
      ; Strip HTML file extensions in internal links.
      (set-href (re.sub r"\.html\b" "" (href)))
      ; Don't refer to "index" explicitly.
      (when (= (href) "index")
        (set-href ""))
      ; Make internal links absolute, so they're robust to the removal
      ; of trailing slashes from URLs.
      (when (not (.startswith (href) "/"))
        (set-href f"/{project}/doc/{version}/{(href)}")))

    ; Write out to a new HTML file with the file extension removed.
    (.write-bytes (/ fname.parent fname.stem) (lxml.html.tostring doc)))

  (when (= project "hy")
    ; Update documentation links as necessary on the main landing page.
    (setv orig (.read-text landing-page))
    (setv new (re.sub
      "(href=\"/hy/doc/)[^\"/#]+"
      (+ r"\1" version)
      orig))
    (when (!= new orig)
      (.write-text landing-page new))))

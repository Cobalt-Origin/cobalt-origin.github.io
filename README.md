# Cobalt Origin links

Landing pages behind the QR codes on Cobalt Origin business cards, served free by GitHub Pages.

- `people.json`: one entry per person. `hide` lists fields to leave off for now (e.g. an email that isn't set up yet).
- `template.html` + `assets/card.css`: the look of every card.
- `build.ps1`: writes `team/<slug>/index.html` and `team/<slug>/<slug>.vcf` (the "Save Contact" file).

To add or change a person: edit `people.json`, run `build.ps1`, commit and push.
Never rename a `slug` once its QR code is printed: the address on the card would stop working.

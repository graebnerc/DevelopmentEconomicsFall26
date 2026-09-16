# Template for academic courses

When using for a new course, adjust the following:

`_publish.yml`

- The id used by Netlify (when available)
- The URL of the course website

`_quarto.yml`

- Name of the course
- Content structure
- All other meta data of interest

`index.qmd` and `content/index.qmd`

- The landing pages with course specific info
- Also, `content/statrecap.qmd` for blog-specific content

`content/material/SeminarDescription.qmd`

- A template for a seminar description

**Other relevant info**

- The actual course pages reside in the directory `content`
- `index.qmd` is the overview page, single lectures are in `content/material/`
- If you want to set up a blog-based content page, such as separate tutorials, or the statistics recap I did for my research methodology course, they need to get a folder here, as well as an `*.qmd` file that serves as a landing page for the blogs
  - Example: you have a directory `statrecap`, then the landing page for these blogs is `statrecap.qmd` in the content directory
  - Within the folders you either create subdirectories with `index.qmd` or `.qmd` files with the respective titles
  - In the directory for the blog you also put `_metadata.yml` with general info
  - You must add the directories to the render heading of `_quarto.yml` such that they get rendered
- References should be in `references/references.bib`


## Publishing the site

The website is deployed **directly from this machine to Netlify** with the
Quarto CLI — Netlify does *not* build from GitHub, and the rendered site in
`_site/` is not part of the repository.

Two double-clickable helper scripts drive the everyday workflow:

- **`PublishSlides.command`** — puts the download link to a lecture's slides on
  its session page (or takes it offline again). Until a deck is published, the
  page only shows a placeholder. Run this after a lecture has been given.
- **`Update.command`** — checks whether any page, slide deck, data set or style
  file has changed since the last deployment and, if so, renders the site and
  publishes it to Netlify. The time of the last deployment is stored in
  `.last-publish`; delete that file to force a full redeployment.

The manual equivalent is:

```bash
quarto render
quarto publish netlify
```

The Netlify site id and URL are stored in `_publish.yml`. Source changes should
still be committed and pushed to GitHub — the repository remains the archive of
the course, it is just no longer what Netlify builds from.


Inspired by [this template](https://github.com/jonjoncardoso/quarto-template-for-university-courses).


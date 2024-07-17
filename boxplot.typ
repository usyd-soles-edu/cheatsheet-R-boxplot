// Some definitions presupposed by pandoc's typst output.
#let blockquote(body) = [
  #set text( size: 0.92em )
  #block(inset: (left: 1.5em, top: 0.2em, bottom: 0.2em))[#body]
]

#let horizontalrule = [
  #line(start: (25%,0%), end: (75%,0%))
]

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms: it => {
  it.children
    .map(child => [
      #strong[#child.term]
      #block(inset: (left: 1.5em, top: -0.4em))[#child.description]
      ])
    .join()
}

// Some quarto-specific definitions.

#show raw.where(block: true): block.with(
    fill: luma(230), 
    width: 100%, 
    inset: 8pt, 
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let d = (:)
  let fields = old_block.fields()
  fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.amount
  }
  return block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == "string" {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == "content" {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subrefnumbering: "1a",
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => numbering(subrefnumbering, n-super, quartosubfloatcounter.get().first() + 1))
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => {
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          }

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}

// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  if type(it.kind) != "string" {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let old_title = old_title_block.body.body.children.at(2)

  // TODO use custom separator if available
  let new_title = if empty(old_title) {
    [#kind #it.counter.display()]
  } else {
    [#kind #it.counter.display(): #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block, 
    block_with_new_content(
      old_title_block.body, 
      old_title_block.body.body.children.at(0) +
      old_title_block.body.body.children.at(1) +
      new_title))

  block_with_new_content(old_callout,
    new_title_block +
    old_callout.body.children.at(1))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: rgb("#dddddd"), icon: none, icon_color: black) = {
  block(
    breakable: false, 
    fill: background_color, 
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"), 
    width: 100%, 
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%, 
      below: 0pt, 
      block(
        fill: background_color, 
        width: 100%, 
        inset: 8pt)[#text(icon_color, weight: 900)[#icon] #title]) +
      if(body != []){
        block(
          inset: 1pt, 
          width: 100%, 
          block(fill: white, width: 100%, inset: 8pt, body))
      }
    )
}



#let article(
  title: none,
  authors: none,
  date: none,
  abstract: none,
  cols: 1,
  margin: (x: 1.25in, y: 1.25in),
  paper: "us-letter",
  lang: "en",
  region: "US",
  font: (),
  fontsize: 11pt,
  sectionnumbering: none,
  toc: false,
  toc_title: none,
  toc_depth: none,
  toc_indent: 1.5em,
  doc,
) = {
  set page(
    paper: paper,
    margin: margin,
    numbering: "1",
  )
  set par(justify: true)
  set text(lang: lang,
           region: region,
           font: font,
           size: fontsize)
  set heading(numbering: sectionnumbering)

  if title != none {
    align(center)[#block(inset: 2em)[
      #text(weight: "bold", size: 1.5em)[#title]
    ]]
  }

  if authors != none {
    let count = authors.len()
    let ncols = calc.min(count, 3)
    grid(
      columns: (1fr,) * ncols,
      row-gutter: 1.5em,
      ..authors.map(author =>
          align(center)[
            #author.name \
            #author.affiliation \
            #author.email
          ]
      )
    )
  }

  if date != none {
    align(center)[#block(inset: 1em)[
      #date
    ]]
  }

  if abstract != none {
    block(inset: 2em)[
    #text(weight: "semibold")[Abstract] #h(1em) #abstract
    ]
  }

  if toc {
    let title = if toc_title == none {
      auto
    } else {
      toc_title
    }
    block(above: 0em, below: 2em)[
    #outline(
      title: toc_title,
      depth: toc_depth,
      indent: toc_indent
    );
    ]
  }

  if cols == 1 {
    doc
  } else {
    columns(cols, doc)
  }
}

#set table(
  inset: 6pt,
  stroke: none
)
#show: doc => article(
  title: [Boxplots in R with `ggplot2`],
  date: [2024-07-17],
  toc_title: [Table of contents],
  toc_depth: 3,
  cols: 2,
  doc,
)
#import "@preview/fontawesome:0.1.0": *


#block[
]
#grid(
columns: (33.3%, 33.3%, 33.3%), gutter: 1em, rows: 1,
  rect(stroke: none, width: 100%)[
#box(width: 100%,image("boxplot_files/figure-typst/unnamed-chunk-1-1.svg"))

],
  rect(stroke: none, width: 100%)[
#box(width: 100%,image("boxplot_files/figure-typst/unnamed-chunk-1-2.svg"))

],
  rect(stroke: none, width: 100%)[
#box(width: 100%,image("boxplot_files/figure-typst/unnamed-chunk-1-3.svg"))

],
)
#block[
#heading(
level: 
2
, 
numbering: 
"none"
, 
[
About
]
)
]
The #strong[boxplot] is a visual representation of a dataset’s distribution, showing the median, quartiles, and outliers. It is useful for comparing distributions between groups and identifying outliers within a single group.

#block[
#callout(
body: 
[
- You know how to install and load packages in R.
- You know how to import data into R.
- You recognise data frames and vectors.

]
, 
title: 
[
Assumed knowledge
]
, 
background_color: 
rgb("#dae6fb")
, 
icon_color: 
rgb("#0758E5")
, 
icon: 
fa-info()
)
]
#block[
#callout(
body: 
[
Your data should be #strong[structured] in a way that makes it #emph[easy] to plot. The ideal structure is #strong[long];, i.e.~one where each column represents a variable and each row an observation (@fig-longwide). You can either reshape your data in R or #strong[move cells manually] in a spreadsheet program to achieve the desired structure. For boxplots comparing more than one group of data, a #strong[categorical variable] representing the group should be present in the data.

#figure([
#box(image("longwide.png"))
], caption: figure.caption(
position: bottom, 
[
Long data (left) where each column is a different variable – e.g.~`Sex` is categorical and `BW` is the measured, continuous response – is preferred over wide data (right), as it makes it easier to manipulate data when plotting.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-longwide>


]
, 
title: 
[
Data structure
]
, 
background_color: 
rgb("#ccf1e3")
, 
icon_color: 
rgb("#00A047")
, 
icon: 
fa-lightbulb()
)
]
= Data
<data>
For this cheatsheet we will use part of the possums dataset used in #link("https://www.sydney.edu.au/units/BIOL2022")[BIOL2022] labs.

= Import data
<import-data>
#block[
```r
library(readxl) # load the readxl package
possums <- read_excel("possum_bw.xlsx") # read file, store as "possums" object
```

]
= Plot
<plot>
Below are multiple versions of a boxplot comparing the body weight, `BW`, of possums between two groups defined by the `Sex` variable. Use the code snippets and their different implementations to understand how to customise your boxplot.

= Version 1
```r
library(ggplot2)
ggplot(possums, aes(x = Sex, y = BW)) +
  geom_boxplot()
```

#block[
/ Line 1: #block[
The `library()` function loads a package. Here, we load the `ggplot2` package to enable the functions required to create the plot.
]

/ Line 2: #block[
The `ggplot()` function creates a plot canvas. The `aes()` function specifies the aesthetic mappings, i.e.~which variables are mapped to the x and y axes.
]

/ Line 3: #block[
Once the canvas is defined, the data can be added automatically using `geom_*()` functions. Here, `geom_boxplot()` adds the boxplot to the canvas, structured according to the aesthetic mappings.
]

]
#box(image("boxplot_files/figure-typst/unnamed-chunk-3-1.svg"))

= Version 2
```r
library(ggplot2) 
ggplot(possums, aes(x = Sex, y = BW)) + 
  geom_boxplot(fill = "slateblue") +
  xlab("Sex") +
  ylab("Body weight (g)") + 
  theme_classic()
```

#block[
/ Line 3: #block[
Adding a `fill` argument to the `geom_boxplot()` function changes the colour of the boxplot.
]

/ Line 4: #block[
`xlab()` and `ylab()` add labels to the x and y axes, respectively.
]

/ Line 6: #block[
An optional step, `theme_classic()` changes the plot’s appearance without needing to specify complex customisations.
]

]
#box(image("boxplot_files/figure-typst/unnamed-chunk-4-1.svg"))

= Version 3
```r
library(ggplot2) 
ggplot(possums, aes(x = BW, y = Sex, fill = Sex)) +
  geom_boxplot() +
  xlab("Body weight (g)") + 
  ylab("Sex") + 
  theme_minimal() + 
  scale_fill_manual(values = c("salmon", "slateblue"))
```

#block[
/ Line 2: #block[
The `Sex` variable is mapped to the y-axis and the `BW` variable to the x-axis. The `fill` aesthetic is used to colour the boxplots by the `Sex` variable.
]

/ Line 7: #block[
The `scale_fill_manual()` function allows you to manually set the colours of the boxplots defined by the `fill` aesthetic in the `aes()` function above. There must be one colour for each level of the `Sex` variable.
]

]
#box(image("boxplot_files/figure-typst/unnamed-chunk-5-1.svg"))

= Version 4
```r
library(ggplot2) 
ggplot(possums) +
  aes(x = Sex, y = BW) +
  geom_boxplot(width = .3, fill = "beige") +
  geom_point(
    position = position_nudge(x = -.3),
    shape = 95, size = 24, alpha = .25
  ) +
  theme_bw()
```

#block[
/ Line 3: #block[
The `aes()` function is placed outside the `ggplot()` function, allowing the aesthetic mappings to be used across multiple `geom_*()` functions.
]

/ Line 4: #block[
`geom_boxplot()` can be customised further using the `width` argument to change the width of the boxplots.
]

/ Line 5: #block[
`geom_point()` adds points to the plot.
]

/ Line 6: #block[
The `position_nudge()` function moves the points to the left of the boxplots by -0.3 units.
]

/ Line 7: #block[
The `shape`, `size`, and `alpha` arguments customise the appearance of the points, resulting in a different visual representation of the data "points".
]

]
#box(image("boxplot_files/figure-typst/unnamed-chunk-6-1.svg"))

= Version 5
```r
library(ggplot2) 
plot1 <- 
  ggplot(possums) +
  aes(x = Sex, y = BW)

plot1 +
  geom_boxplot() +
  geom_point(
    position = position_jitter(width = .05, seed = 0),
    size = 4, alpha = .5,
    colour = "firebrick"
  ) +
  theme_classic()
```

#block[
/ Line 4: #block[
It is possible to save current work on a plot for later use by assigning it to an object, e.g.~`plot1`.
]

/ Line 6: #block[
To continue working on the plot, use the `+` operator on the saved object and continue adding layers.
]

/ Line 9: #block[
The `position_jitter()` function adds a small amount of random noise to the points, preventing them from overlapping. The `seed` argument ensures the noise is consistent across multiple plots.
]

]
#box(image("boxplot_files/figure-typst/unnamed-chunk-7-1.svg"))

= More resources
<more-resources>
- #link("http://www.stat.columbia.edu/~tzheng/files/Rcolor.pdf")[R colors] – a good resource for choosing colours using words in R.
- #link("https://z3tt.github.io/beyond-bar-and-box-plots/")[Beyond bar and box plots] – alternative visualisation methods in R for comparing groups.
- #link("https://r-graph-gallery.com/boxplot.html")[Boxplot – the R Graph Gallery] – a gallery of boxplot examples in R.

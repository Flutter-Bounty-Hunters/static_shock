---
title: The Pipeline
---
At the center of everything in Static Shock is a pipeline and a few data structures.

Broadly speaking, there are two primary paradigms for programming. One approach
is object orientation, where long-lived objects attach behaviors to data, and
the behaviors form the contract. The other approach is procedural, where
the data structure forms the contract, and the code operates on the data.

Pipelines are fundamentally procedural. The data is the contract. All areas of
Static Shock agree about the kind of data that's being manipulated. As the
data moves through the pipeline, each step of the pipeline reads and writes
the data. At the end, the data is written to files, which form a static site.

The core of Static Shock has two primary jobs:
1. Define the data structures that all code reads and writes.
2. Implement a pipeline and push the data through it.

All behavior outside of these two responsibilities are implemented by
Static Shock plugins.

## The Steps
The Static Shock pipeline runs a series of steps, and then writes all the
static site files to the destination directory.

The Static Shock pipeline executes the following steps on each build:

1. Delete everything in destination directory
2. Initialize all plugins
3. Load layout and components
4. Load local data into the `DataIndex`
5. Pick all files in the source directory that we want to process
6. Load external data into the `DataIndex`
7. Load external assets
8. Load pages and assets from the source directory
9. Transform pages
10. Transform assets
11. Filter pages
12. Render pages
13. Run finishers
14. Write all files to the destination directory

The Static Shock pipeline might appear to include a lot of steps, but the
reason for so many steps is to make Static Shock as pluggable as possible.
As such, most Static Shock development can happen inside of plugins, instead
of altering the core of Static Shock.

## Pipeline Content
A collection of data structures (content) are pushed through the Static Shock
pipeline to produce the final website files.

The most fundamental data structures in Static Shock are "pages" and "assets".
A page represents a URL-addressable HTML page. An asset represents any
URL-addressable file that's not a page, e.g., CSS, JavaScript, image, video.

To aid in assembling pages and assets, a few higher level data structures are
provided, too. A `DataIndex` is provided, where plugins can store any data they'd
like, which is made available to the rest of the pipeline. A `PagesIndex` holds
references to all the pages that are loaded into the pipeline, which can be used
to search for pages based on various criteria.


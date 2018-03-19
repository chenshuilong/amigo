## What is Minelab?

Minelab is a free Redmine 2.5.x theme inspired by Gitlab, written in Sass. It uses Bourbon for cross browser compatibility, Neat for responsive grids and Font Awesome to replace all the stock icons. It also mimics Gitlab's page loading effect using PACE and CSS animations.

## What plugins are supported?

Minlab supports all the free and lite plugins from RedmineCRM. Support for more plugins is coming in later versions.

## How to install it

To install Minelab, you need to unzip it and copy it's contents in `Redmine/public/themes`. Then visit `Redmine>Administration>Settings>Display` and select Minelab theme.

## To do

Make it responsive!

## How it looks?

Screenshots are available at [Minlab's page](http://hardpixel.github.io/minelab/)

## Contribution

It appears that a few people are using Minelab, even though it has issues. Our time is very limited, so it would be great if those who have made changes/fixes could create a pull request.

*When making changes, please make sure you are editing the application.sass file, otherwise changes will be lost.*

### create CSS from SASS

#### Prerequisites

```
bundle install
bourbon install
neat install
```

#### Example

```
sass --load-path bourbon --load-path neat --sourcemap=none sass/application.sass stylesheets/application.css
```

## Credits

[Bourbon](http://bourbon.io/) | [Neat](http://neat.bourbon.io/) | [Font Awesome](http://fontawesome.io/) | [PACE](http://github.hubspot.com/pace/)

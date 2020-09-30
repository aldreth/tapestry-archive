# Tapestry archive

Download all the pictures & videos from your child's [tapestry](https://tapestryjournal.com) account.

## Requirements
* ruby - tested using 2.7.1

## How to use

* Clone this repository
* Run `bundle install`
* Copy `env.example` to `.env` and fill in the details
* Run `ruby main.rb`

The images will be downloaded to the `images` directory. The files will be named with the date & title of the observation, and the EXIF title, description, author & date taken will be set with the title, note, observer and date of observation.

There will also be a pdf made, with all the information about the pictures in it.
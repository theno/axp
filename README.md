# axp

axp - Alleviate XML Pain - Akin to an XML Formatter

## Motivation

xml is a pain:
 1. hard to read
 2. hard to edit

Example:

<code><?xml version="1.0" encoding="utf-8"?>
  <elem1 attr3="val1" attr4="val2">
      <elem2 attr1="val3" attr2="val4">Here is some content</elem2>
      <elem3 attr5='val5'/>
      <elem4>foo</elem4>
  </elem1>
</code>

But we have to use it.

Idea: Nice formatting which makes xml
 * easier to read
 * easier to edit

That's the format I suggest (note: there is just one attribute per line):

  <?xml version="1.0" encoding="utf-8"?>
  
  <elem1
      attr3="val1"
      attr4="val2"
      >
  
      <elem2
          attr1="val3"
          attr2="val4"
          >Here is some content</elem2>
  
      <elem3
          attr5='val5'
          />
  
      <elem4>foo</elem4>
  
  </elem1>

axp formats xml like this. It alleviates the xml pain.


## Usage

axp is a command line tool:

  $ axp < ugly_xml > pretty_xml


## Installation

Assumption: Your $PATH contains: '~/bin/' (check: 'echo $PATH').
If not, append it to your $PATH: 'echo "$PATH="$HOME/bin:$PATH" >> ~/.profile'

Extract folder 'axp' with all subdirs and files within ~/bin (or where you
want). Then make axp availiable:

  $ cd $HOME/bin
  $ ln -s $HOME/bin/axp/axp axp


## Integration in VIM

Assumption: The command 'axp' must be in $PATH (see above).

Put this into your ~./vimrc:

  " xml2prettyxml
  nmap <F5> :%!axp<CR>

With this setting the hole file will be formatted with axp if you press <F5> in
command mode.

Other xml formattings:

  " common practiced pretty-xml
  "nmap <F6> :%!xmllint --format -<CR>
  " space saving xml-format
  "nmap <F7> :%!xmllint --noblanks -<CR>
  " another (unusual) xml-prettiness
  "nmap <F8> :%!xmllint --pretty 2 -<CR>

If you want to enable axp for xml-indenting put this into your ~./vimrc:

  " xml-indent
  au FileType xml setlocal equalprg=axp

Example for usage: 'gg=G'
Caveat: axp ist not an indenting tool. It does more. So only format the hole
xml-structure for correct indentation.

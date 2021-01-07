#!/bin/bash
# Simple script to extract and filter Project Gutenberg HTML to Asciidoc format
# Outputs to STDOUT 
# Usage: html-convert-adoc.sh [-r] [-c] <html_book> > book.asciidoc

# Process script options
CLEANUP=true
RAW=false
while getopts ":cr" opt; do
  case ${opt} in
    c ) # Don't cleanup all generated files (default is true)
			CLEANUP=false
      ;;
    r ) # Output "raw" version asciidoc right after pandoc conversion
			RAW=true
      ;;
    \? ) echo "Usage: html-convert-adoc.sh [-r] [-c] <html_book>"
      ;;
  esac
done

# Input file, usually "972-h/972-h.htm"
shift $(( OPTIND - 1 ))
inputfile=$1

# Create temp file
tmpfile="book.asciidoc.tmp.$$"
touch $tmpfile

# Build and insert asciidoc metadata header
perl -nE 'say if s/^title:\s+(\p{PosixPrint}+)'\''(\p{PosixPrint}+)\v/= \1’\2/' metadata.yaml >> $tmpfile
perl -nE 'say if s/^\s+agent_name:\s+(\p{PosixPrint}+)\v/\1/' metadata.yaml >> $tmpfile
perl -nE 'say if s/^_version:\s+(\p{PosixPrint}+)\v/v\1/' metadata.yaml >> $tmpfile

# More headers
cat <<- EOF >> $tmpfile
	:doctype: book
	:toc:
	:toclevels: 1

	[colophon]
	[discrete]
	== Copyright
	This edition of _The Devil’s Dictionary_ is maintained, archived, and curated as part of
	the GITENBERG PROJECT.
	
	This work is in the public domain.
	
	If you find any issues with this work, please report them at 
	https://github.com/GITenberg/The-Devil-s-Dictionary_972/issues

	Produced by “Aloysius”, and David Widger

EOF

# Use pandoc to create initial asciidoc conversion, ensuring UTF-8
pandoc --wrap=none -f html -t asciidoc $inputfile | iconv -c -t "UTF-8" >> $tmpfile

# Output RAW asciidoc and exit
if [ "$RAW" == true ]; then
  cat $tmpfile

  # Clean up
  if [ "$CLEANUP" == true ]; then
    rm $tmpfile
  fi

  exit 0
fi

# Remove old Project Gutenberg metadata block
perl -i -p0e 's/^[.]{4}\s+The Project Gutenberg EBook.*?^[.]{4}\v//gms' $tmpfile

# Remove old Project Gutenberg license block
perl -i -p0e 's/^[.]{4}\s+End of Project Gutenberg.*?^[.]{4}//gms' $tmpfile

# Remove ' +' whitespace strings
perl -i -pe 's/^ \+\v//g' $tmpfile

# Nuke contents block
perl -i -p0e "s/^[']{5}\s+.*?\*CONTENTS\*.*?^[']{5}//gms" $tmpfile

# Nuke old link anchors
perl -i -pe 's/\s*?\[#link\p{PosixPrint}+\]##\v//g' $tmpfile

# Clean up old title and author headings
perl -i -pe "s/(^== THE DEVIL'S DICTIONARY\v|^=== by Ambrose Bierce\v)//g" $tmpfile

# Fix Preface heading depth
perl -i -pe "s/^=(== AUTHOR'S PREFACE)/\1/g" $tmpfile

# Tidy up excessive vertical whitespace
perl -i -p0e 's/\v{4,}/\n\n\n/gms' $tmpfile

# Convert preformatted quotes to Asciidoc format quotes WITHOUT attribution
#perl -i -p0e 's/^[.]{4}\v(?:(?![.]{4})\(.*?)^[.]{4}\v+^[A-Z]+,\s\w/\[quote]\n____\n\1____\n/gms' $tmpfile
#perl -i -p0e 's/^[.]{4}(.*?)^[.]{4}(?=\v+^[A-Z]+,\s\p{PosixPrint})/\[quote]\n____\n\1____\n/gms' $tmpfile

# Fix some messed up quotes
perl -i -p0e 's/_(The Unauthorized Version)_/\1/gms' $tmpfile
perl -i -p0e 's/^\s+(J\.H\. Bumbleshook)\s+[.]{4}/....\n\n\1/gms' $tmpfile
perl -i -p0e 's/^[.]{4}\s+(EUCHARIST.*?)^[.]{4}/\1/gms' $tmpfile
perl -i -p0e 's/^[.]{4}\s+(MORAL.*?expediency\.)\s+(  It is.*?offence\.)\s+(Gooke'\''s Meditations)\s+^[.]{4}/\1\n\n....\n\2\n\n....\n\n\3/gms' $tmpfile
perl -i -p0e 's/^[.]{4}\s+(ROBBER.*?)^[.]{4}/\1/gms' $tmpfile
perl -i -p0e 's/^[.]{4}\s+(DISSEMBLE.*?character\.)\s+(  Let us dissemble\.)\s+^[.]{4}/\1\n\n....\n\2\n\n..../gms' $tmpfile
perl -i -p0e 's/^\s+(Fernando Tapple)\s+[.]{4}/....\n\n\1/gms' $tmpfile

# Perl got a bit greedy with quotes without attribution, so multiple steps
perl -i -p0e 's/^[.]{4}(.*?)^[.]{4}\v/\{\1\}\n/gms' $tmpfile

# Convert preformatted quotes to Asciidoc format quotes WITHOUT attribution
perl -i -p0e 's/^\{([^}]*?)^\}(?=\v+^[A-Z]{2,},\s\w)/\[quote]\n____\n\1____\n/gms' $tmpfile
perl -i -p0e 's/^\{([^}]*?)^\}(?=\v+(^(as the "Doctor")|(But the gift)|(The superstition)|(he and his)|(but Agammemnon)|(One of the greatest of poets)))/\[quote]\n____\n\1____\n/gms' $tmpfile

# Convert preformatted quotes to Asciidoc format quotes WITH attribution
perl -i -p0e 's/^\{([^}]*?)^\}\v+(\p{PosixPrint}+)\v/\[quote, \2\]\n____\n\1____\n/gms' $tmpfile

# Boldface word being defined
perl -i -pe 's/(^[A-Z\-.'\'']*),/\*\*\1\*\*,/g' $tmpfile

# Boldface first letter in chapter description
perl -i -p0e 's/^(== [IJKWX]\s+?)([IJKWX])\s/\1\*\*\2\*\* /gms' $tmpfile

# Fix one-offs
perl -i -pe 's/^(IMPOSTOR)\s/\*\*\1\*\*, /g' $tmpfile
perl -i -pe 's/^(ABRACADABRA)\./\*\*\1\*\*\./g' $tmpfile
perl -i -pe 's/^(HABEAS CORPUS)\./\*\*\1\*\* \(Latin\)./g' $tmpfile
perl -i -pe 's/^(FORMA PAUPERIS)\. \[Latin\]/\*\*\1\*\* \(Latin\)\./g' $tmpfile
perl -i -pe 's/^(R\.I\.P\.)\s/\*\*\1\*\* /g' $tmpfile
perl -i -pe 's/^((APRIL FOOL)|(BABE or BABY)|(BERENICE'\''S HAIR)|(COURT FOOL)|(KING'\''S EVIL)|(MONARCHICAL GOVERNMENT)|(WALL STREET)|(TZETZE \(or TSETSE\) FLY)|(TABLE D'\''HOTE)),/\*\*\1\*\*,/g' $tmpfile

# Italicize part of speech (noun, adj, etc..)
perl -i -pe 's/(\*\*[^*]+\*\*)(, ([\w]+[.])+([\w]+[.])?)\s/\1__\2__ /g' $tmpfile

# Internationalize some spelling
# see: http://www.alecjacobson.com/weblog/?p=443
perl -i -pe 's/TABLE D'\''HOTE/TABLE D’HÔTE/g' $tmpfile
perl -i -pe 's/table d'\''hotage/__table d’hôtage__/g' $tmpfile
perl -i -pe 's/_epixoriambikos_/__επιχοριαμβικός__/g' $tmpfile
perl -i -pe 's/brekekex-koax/brekekex-koäx/g' $tmpfile

### Handle remaining dashes, quotes, etc.
# https://www.fileformat.info/info/unicode/char/0027/index.htm
## Single quotes to apostrophes and left and right quotes
# This regex is rather indiscriminate but I have verified the results. Single quotes to Apostrophe.
perl -i -pe 's/(\w+)'\''(\w+)/\1’\2/g' $tmpfile
# Quotes to apostrophes in old timey contractions
perl -i -pe 's/'\''(tis|twas|twixt|twere|twould|twil)/’\1/gi' $tmpfile
# More of the same
perl -i -pe 's/'\''(em|mongst|ist|ite|ie|er|possum|course|arry|amstead|eath|aberdasher)\b/’\1/gi' $tmpfile
# At the end of words
perl -i -pe 's/(mourners|writers|rogues|miners|a-kickin|doin|judges|angels|ladies|bestrewin|apostrophisin|surprisin|smilin|livin|vasquez|worms|fairies)'\''/\1’/gi' $tmpfile
# Quoted phrases
perl -i -pe 's/'\''(make a god of his belly|lips are sealed|o yer wooin|hell|i|cynic)'\''/‘\1’/gi' $tmpfile
# Fix broken 'tweres
perl -i -pe 's/'\''(t)\s(were)/’\1\2/gi' $tmpfile
# Fix 'o
perl -i -pe 's/[\s-](o)'\''[\s-]/\1’/gi' $tmpfile

## Work on double quote replacement
perl -i -p0e 's/(Discords King!)"/\1/gms' $tmpfile
perl -i -p0e 's/"(.+?)"/“\1”/gms' $tmpfile

## Clean up hypens. Source HTML already had correct em dash usage.
perl -i -pe 's/cannon- shot/cannon-shot/gi' $tmpfile

# Output tmpfile
cat $tmpfile

# Clean up
if [ "$CLEANUP" == true ]; then
  rm $tmpfile
fi

#!/bin/bash
# Simple script to extract and filter Project Gutenberg HTML to Asciidoc format
# Outputs to STDOUT 
# Usage: html-convert-adoc.sh [-c] <html_book>

# Process script options
CLEANUP=true
while getopts ":c" opt; do
  case ${opt} in
    c ) # Don't cleanup all generated files (default is true)
			CLEANUP=false
      ;;
    \? ) echo "Usage: html-convert-adoc.sh [-c] <html_book>"
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
perl -nE 'say if s/^title:\s+(\p{PosixPrint}+)\v/= \1/' metadata.yaml >> $tmpfile
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
	This edition of _The Devil's Dictionary_ is maintained, archived, and curated as part of
	the GITENBERG PROJECT.
	
	This work is in the public domain.
	
	If you find any issues with this work, please report them at 
	https://github.com/GITenberg/The-Devil-s-Dictionary_972/issues

	Produced by "Aloysius", and David Widger

EOF

# Use pandoc to create initial asciidoc conversion
pandoc --wrap=none -f html -t asciidoc $inputfile >> $tmpfile

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
perl -i -p0e 's/^\{([^}]*?)^\}(?=\v+(^(as the "Doctor")|(But the gift)|(The superstition)|(he and his)|(but Agammemnon)))/\[quote]\n____\n\1____\n/gms' $tmpfile

# Convert preformatted quotes to Asciidoc format quotes WITH attribution
perl -i -p0e 's/^\{([^}]*?)^\}\v+(\p{PosixPrint}+)\v/\[quote, \2\]\n____\n\1____\n/gms' $tmpfile

# Boldface word being defined
perl -i -pe 's/(^[A-Z\-.'\'']*),/\*\*\1\*\*,/g' $tmpfile

# Fix one-offs
perl -i -pe 's/^(IMPOSTOR)\s/\*\*\1\*\*, /g' $tmpfile
perl -i -pe 's/^((R\.I\.P\.)|(FORMA PAUPERIS.))\s/\*\*\1\*\* /g' $tmpfile
perl -i -pe 's/^((APRIL FOOL)|(BABE or BABY)|(BERENICE'\''S HAIR)|(COURT FOOL)|(KING'\''S EVIL)|(MONARCHICAL GOVERNMENT)|(WALL STREET)|(TZETZE \(or TSETSE\) FLY)|(TABLE D'\''HOTE)),/\*\*\1\*\*,/g' $tmpfile

# Italicize part of speech (noun, adj, etc..)
perl -i -pe 's/(\*\*[^*]+\*\*)(, ([\w]+[.])+([\w]+[.])?)\s/\1__\2__ /g' $tmpfile

# Substitute real greek letters
# see: http://www.alecjacobson.com/weblog/?p=443
perl -i -pe 's/_epixoriambikos_/__επιχοριαμβικóς__/g' $tmpfile

# Output tmpfile
cat $tmpfile

# Clean up
if [ "$CLEANUP" == true ]; then
  rm $tmpfile
fi

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

# Tidy up excessive vertical whitespace
perl -i -p0e 's/\v{4,}/\n\n\n/gms' $tmpfile

# Output tmpfile
cat $tmpfile

# Clean up
if [ "$CLEANUP" == true ]; then
  rm $tmpfile
fi

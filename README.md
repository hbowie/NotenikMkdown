#  NotenikMkdown

The Markdown parser provided with Notenik attempts to satisfy all of the requirements laid out on the [Markdown syntax page][syntax] found on the [Daring Fireball site][df]. 

[syntax]: https://daringfireball.net/projects/markdown/syntax
[df]: https://daringfireball.net/

There are a few known exceptions. 

* For use within Notenik, you may use double square brackets enclosing the title of another Note to create a link to that Note.

* Headings may be auto-numbered in a fashion similar to the usual numbering of ordered items.  

* Automatic links for email addresses do not perform any randomized decimal and hex entity-encoding of the email addresses. 

* Backticks-style quotes are not converted to curly quotes. 

## Usage

An example of a typical calling sequence follows. 

	let md = MkdownParser(markdown)
    md.wikiLinkLookup = wikiLinkLookup
    md.parse()
    writer.append(md.html)

## Parsing Strategy

The class 'MkdownParser' is the overall parser that is called in order to convert Markdown to HTML. 

The first phase of the parser breaks the input text down into lines, examining the beginning and end of each line, and identifying the type of each line. 

* The class 'MkdownLinePhase' is used to keep track of where the parser is within each line, as it is being examined. 

* The enum 'MkdownLineType' defines the various types of lines. 

* The class 'MkdownLine' stores each line, including its type, and the blocks containing the line, and other metadata about the line. 

* The class 'MkdownBlock' identifies an HTML block tag within which a line resides. 

* The class 'MkdownBlockStack' contains an array of blocks surrounding each line. 

The resulting lines are stored in an array, which is passed on to the next phase of the parser's processing. 

The second phase of the parser goes through the array of lines and generates the HTML output. 

The first sub-phase (2.a) breaks the contents of each line down into atomic units, known as "chunks". 

* The class 'MkdownChunk' provides a container for one chunk. 

* The enum 'MkdownChunkType' defines all the possible types of chunks. 

The next sub-phase (2.b) goes through the chunks within a block, looking for matches between beginning and ending markers of various sorts. 

The final sub-phase (2.c) then goes through the chunks and generates HTML. 

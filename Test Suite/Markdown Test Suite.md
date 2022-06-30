Title:  Markdown Test Suite

Body:

# Markdown Test Suite

## Paragraphs

This is our first paragraph. 

This is our second paragraph. And it consists of multiple lines. 
The lines can be hard-wrapped. A blank line should end the paragraph.

## Line Breaks

Keep a fire burning in your eyes  
Pay attention to the open skies \
You never know what will be coming down. 

A few lines from a Jackson Browne song.

## Headings

Level 1 Heading
============

Level 2 Heading
------------

# Another Level 1 Heading #

## Another Level 2 Heading

### A Level 3 Heading ###

#### A Level 4 Heading

##### A Level 5 Heading

###### A Level 6 Heading

####### A Level 7 Heading?

## Pound Signs But No Headings

The following code should not produce any headings. 

RV Site #7. $25/night.  
Cabin #1 or #2 $65/night.  
#1 no pets, 20 amp electrical, can park trailer there.   
#2 pets OK.  $20 pet fee
arrive before 4:30PM on Friday.

And what happens now?

This is an ordinary paragraph.  
This is a second sentence. 
# This is a heading with no preceding blank line. 

#This is a level 1 heading with no space after the hash marks. 

##This is a level 2 heading with no space after the hash marks. 

#7 is a good bet for this race. 

And this is just another paragraph.

## Lists

### Unordered Lists

* One Item
+ Another Item
- And yet another

### Ordered Lists

This is an ordered list. 

1. First 
2. Second
3. Third
4. Fourth

And this is another. 

1. First
1. Second
1. Third
1. Fourth

And this is a third. 

1. First
8. Second
3. Third
5. Fourth

This is a list with spaces and tabs. 

   1. This is the first item. 
 2.   This is the second item. 
 3.	This is the third item. 

This is an unordered list with items wrapped in paragraph tags. 

* First paragraph. 

* Second Paragraph.

* Third paragraph. 

This is an ordered list with items wrapped in paragraph tags. 

1. First

2. Second

3. Third

Let's try some hanging indents. 

*   Lorem ipsum dolor sit amet, consectetuer adipiscing elit.
    Aliquam hendrerit mi posuere lectus. Vestibulum enim wisi,
    viverra nec, fringilla in, laoreet vitae, risus.
*   Donec sit amet nisl. Aliquam semper ipsum sit amet velit.
    Suspendisse id sem consectetuer libero luctus adipiscing.

And without:

*   Lorem ipsum dolor sit amet, consectetuer adipiscing elit.
Aliquam hendrerit mi posuere lectus. Vestibulum enim wisi,
viverra nec, fringilla in, laoreet vitae, risus.
*   Donec sit amet nisl. Aliquam semper ipsum sit amet velit.
Suspendisse id sem consectetuer libero luctus adipiscing.

This is a list with items containing multiple paragraphs. 

1. Let's start a new list. 

    But we have lots to say about this first item. 

	And a lot more as well….

2. And here's a 2nd item in the same list. 

And here's a list with paragraphs and hard returns. 

1. Here's our first item. 

    Here's a second paragraph. 
And it's a long one. 
It just keeps going and going. 

2. And here's a second item.

## Definition Lists

Here is an unordered list: 

+ Item number 1
+ Item number 2
+ Item number 3

Following are some sample definitions. 

bird
: The bird is the word. 

pompitous
: The unalloyed grandeur.
: A word made up by Steve Miller to describe an attribute of love. 

list
: A number of connected items or names written or printed consecutively, typically one below the other. 

And so much for our definition list.

## Block Quotes

Here are HTML blockquotes. 

<blockquote>
<p>The job of management is to maintain an equitable and working balance among the claims of the various directly affected interest groups... stockholders, employees, customers and the public at large.</p>
</blockquote>

This is a regular line. 

> This is a quoted line.

A longer quote follows:

> The job of management is to maintain an equitable and working balance among the claims of the various directly affected interest groups... stockholders, employees, customers and the public at large.

A longer quote with hard line breaks follows:

> The job of management is to maintain an equitable and working
balance among the claims of the various directly affected interest
groups... stockholders, employees, customers and the public at
large.

Following is a two-paragraph block quote. 

> Here is the first paragraph. Isn't it grand? I don't know what you think, but I feel that it's just about perfect. 
> 
> And here's a second paragraph. 

Here's what I think. 

> Here's what Joe thought. 

> > Here's what Sally thought. 

>>> Here's what Judy said.

> ## This is a quoted header. 
>
> 1. This is a quoted list. 
> 2. The 2nd item in the list.

Let's see a horizontal rule. 

* * *

And another one. 

***

And a third. 


*****

And a fourth. 

- - -

And why not a fifth?

---------------------------------------

And that's it.

## Code Blocks

This is a normal paragraph. 

Following is a block of Swift code: 

    func closeBlocks(from startToClose: Int) {
        var blockToClose = openBlocks.count - 1
        while blockToClose >= startToClose {
            closeBlock(openBlocks.blocks[blockToClose].tag)
            openBlocks.removeLast()
            blockToClose -= 1
        }
    }

And following is a block of HTML code:

	<html>

## Bold and Italics

This line contains a **bold word** with asterisks. 

This line contains a __bold word__ with underlines. 

This line contains an *italicized word*. 

This line contains an _italicized word_ with underlines. 

This line contains a ***bold and italicized phrase*** with asterisks.

This line contains a ___bold and italicized phrase___ with underlines. 

This line contains a par**tial**ly bold word.

This line contains \*escaped\* asterisks.

_ This line contains stand-alone * asterisks and _ underscores _

This line contains a ***phrase that is italicized and** partially bold*.

This line contains a ***phrase that is bold and* partially italicized**.

## Images

Let's insert an image: ![Notenik Logo](https://notenik.net/images/notenik.png)


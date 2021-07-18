Title:  Code Fencing

Seq:    8.3

Body: 

This is a normal paragraph. 

Following is a block of Swift code, within a code fence: 

```
func closeBlocks(from startToClose: Int) {
	var blockToClose = openBlocks.count - 1
	while blockToClose >= startToClose {
		closeBlock(openBlocks.blocks[blockToClose].tag)
		openBlocks.removeLast()
		blockToClose -= 1
	}
}
```

And following is a block of HTML code:

~~~~
<html>
~~~~

And following is a fence within a fence. 

````
```
````

And following is a block of Markdown code. 

```

+ An unordered list. 
+ And another unordered item. 

1. A numbered list. 
2. And a second item. 
3. And a third. 

term
: definition

term 2
: def 1
: def 2

And now a plain paragraph. 
```

I guess this would be the plain paragraph. 

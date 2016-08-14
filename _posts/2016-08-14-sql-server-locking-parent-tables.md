--- 
layout: post
title: "SQL Server: Locking Parent Tables"
comments: true
categories: [ technology ]
tags: [ sql ]
---

A while back I came across a problem a concurrency issue at work that took several iterations to determine an appropriate fix for. The basic problem was that we had a table representing a parent entity and a dependent child entity. The child entity had an integer column to specify the sort ordering of the children within the parent. For a more concrete example imagine a photo management application. You may have a gallery entity (the parent) which contains a list of photos (the child entity) which can be re-arranged by the user. 

For the sake of simplicity we'll strip down a lot of the properties on these entities to the bare essentials required for our example.

```SQL
CREATE TABLE Gallery (
	Id INTEGER IDENTITY(1,1) PRIMARY KEY,
	Name VARCHAR(50) NOT NULL
)

CREATE TABLE Photo (
	Id INTEGER IDENTITY(1, 1) PRIMARY KEY,
	Name VARCHAR(50) NOT NULL,
	GalleryId INT NOT NULL,
	SortOrder INT NOT NULL,
	CONSTRAINT FK_Photo_GalleryId_Gallery_Id FOREIGN KEY (GalleryId) REFERENCES Gallery (Id)
)
```

Let's populate the tables with some sample data;

```SQL
SET IDENTITY_INSERT Gallery ON
INSERT INTO Gallery (Id, Name) VALUES (1, 'Ski trip')
SET IDENTITY_INSERT Gallery OFF

SET IDENTITY_INSERT Photo ON  
INSERT INTO Photo (Id, Name, GalleryId, SortOrder) VALUES (1, 'Me falling over', 1, 0)
INSERT INTO Photo (Id, Name, GalleryId, SortOrder) VALUES (2, 'Me falling over... again', 1, 1)
INSERT INTO Photo (Id, Name, GalleryId, SortOrder) VALUES (3, 'Still falling over...', 1, 2)
SET IDENTITY_INSERT Photo OFF
```

You can imagine a simple query to retrieve the ```Photo```s in a ```Gallery``` as being something like;

```SQL
DECLARE @GalleryId INT = 1

SELECT	P.*
FROM	Photo P
WHERE	P.GalleryId = @GalleryId
ORDER
BY		P.SortOrder
```

Pretty simple stuff. To be honest we don't really care if the first ```Photo``` in a gallery has a ```SortOrder``` of 0 or 10 or -20. As long as its value is less than the second ```Photo```'s ```SortOrder``` every thing is fine. So all we need to do is when we insert a new ```Photo``` we insert it with a value greater than any other ```Photo```. Great! Let's have a crack at writing an ```INSERT``` for this scenario;

```SQL
BEGIN TRAN

DECLARE @Name VARCHAR(50) = 'A new photo of me falling over',
		@GalleryId INT = 1,
		@SortOrder INT = NULL

SELECT	@SortOrder = MAX(P.SortOrder) + 1
FROM	Photo P
WHERE	P.GalleryId = @GalleryId

SELECT	@SortOrder = ISNULL(@SortOrder, 0)

INSERT INTO Photo (
		Name,
		GalleryId,
		SortOrder
)
SELECT	@Name,
		@GalleryId,
		@SortOrder

COMMIT TRAN
```

The determination of ```@SortOrder``` here is a little contrived. In an actual solution you could move the standalone ```SELECT``` into a sub-```SELECT``` on the ```INSERT``` statement but let's just imagine that there's a constraint that requires this explicit separation. You launch the feature and after a few weeks you review the data and you notice a puzzling thing you're seeing instances where for a given ```Photo.GalleryId``` there's multiple items where ```Photo.SortOrder``` is duplicated. After some analysis it should be obvious what's happening; one ```Photo``` is attempting to get inserted and before it can complete a second ```Photo``` insertion attempt happens and evaluates ```@SortOrder``` to be the same as the first. 

I've written previously about [WAITFOR](/technology/2015/09/06/sql-server-tricks.html) and how useful it is for debugging concurrency issues. So we'll use it again here. We can chuck a ```WAITFOR DELAY 00:00:05``` before our ```INSERT``` statement and execute the statement multiple times to simulate this concurrency in human-doable-times. As below...

```SQL
BEGIN TRAN

DECLARE @Name VARCHAR(50) = 'A second new photo of me falling over',
		@GalleryId INT = 1,
		@SortOrder INT = NULL

SELECT	@SortOrder = MAX(P.SortOrder) + 1
FROM	Photo P
WHERE	P.GalleryId = @GalleryId

SELECT	@SortOrder = ISNULL(@SortOrder, 0)

WAITFOR DELAY '00:00:05'

INSERT INTO Photo (
		Name,
		GalleryId,
		SortOrder
)
SELECT	@Name,
		@GalleryId,
		@SortOrder

COMMIT TRAN

SELECT	*
FROM	Photo 
WHERE	GalleryId = @GalleryId
```

What we're going to do is run this statement twice. Once with the ```WAITFOR``` and once without. You want to run the statement with the ```WAITFOR``` and then wait a second or two before running the version without the ```WAITFOR```.

![Insert Spurious Data](/img/posts/2016-08-14-sql-server-locking-parent-tables/insert-query-duplicate-results.png "Insert Spurious Data")

In this example I've ran the statement on the left handside, waited a second or two, and then ran the statement on the right hand side. You can see the left hand side results shows the two ```Photo``` entities with a ```SortOrder``` of 3. Not what we want. What we need to do is take a lock on ```Photo``` of some kind so that concurrent statements are blocked until this statement returns. We don't want a ```TABLOCK``` or ```TABLOCKX``` as those are too coarse grained. We can instead try an [UPDLOCK](https://msdn.microsoft.com/en-us/library/ms187373.aspx) which takes a lock until the entire transaction competes (not just the statement). Let's update our insertion statement appropriately...

```SQL
BEGIN TRAN

DECLARE @Name VARCHAR(50) = 'A second new photo of me falling over',
		@GalleryId INT = 1,
		@SortOrder INT = NULL

SELECT	@SortOrder = MAX(P.SortOrder) + 1
FROM	Photo P (UPDLOCK)
WHERE	P.GalleryId = @GalleryId

SELECT	@SortOrder = ISNULL(@SortOrder, 0)

WAITFOR DELAY '00:00:05'

INSERT INTO Photo (
		Name,
		GalleryId,
		SortOrder
)
SELECT	@Name,
		@GalleryId,
		@SortOrder

COMMIT TRAN

SELECT	*
FROM	Photo 
WHERE	GalleryId = @GalleryId
```

Now we'll re-run our two statements side by side again (I've truncated the ```Photo``` table and re-inserted the initial data)

![Insert with UPDLOCK](/img/posts/2016-08-14-sql-server-locking-parent-tables/insert-query-updlock.png "Insert with UPDLOCK")

Hooray! We now get the correct results; all items have unique ```Photo.SortOrder``` values. As per before the left hand side query was executed and then, a few seconds later, I executed the right hand side. One thing to note here is that, as I mentioned, the UPDLOCK takes the lock until the transaction completes. As such the right hand side now takes 3 seconds to complete (as it has to wait for the left hand side's ```WAITFOR```). At this stage you're probably pretty pleased with yourself. So you quickly patch the feature, roll it to production, and pat yourself on the back.

A few weeks pass someone notices that, again, there's duplicate ```Photo.SortOrder``` values for a given ```Photo.GalleryId```. But we just fixed this! Upon further investigation you notice that the duplicate values are always zero. That's... interesting you think. Why would that be the case? They duplicate values are always zero so it's probably something to do with a new ```Gallery```. Let's create a new ```Gallery```;

```SQL
INSERT INTO Gallery (Name) VALUES ('Kittens')
```

Now we'll re-run our ```INSERT``` statements, with the ```UPDLOCK```, from earlier. Only now for ```@GalleryId = 2```.

![Insert with UPDLOCK into an empty Gallery](/img/posts/2016-08-14-sql-server-locking-parent-tables/insert-query-updlock-empty-gallery.png "Insert with UPDLOCK into an empty Gallery")

Ahar! We reproduced the issue. We've ended up with two ```Image.SortOrder``` values of 0. Looking at this a bit closer you'll also notice that, like our initial ```INSERT```, the right hand side in this query has returned immediately. It no longer waits for the left hand side to execute. But there's an ```UPDLOCK```! Shouldn't it be blocking the right hand side query? Well, unfortunately, because there's no items SQL Server has nothing to actually lock until the transaction completes. This allows the right hand side to execute before the left hand side has inserted the record. We could modify the ```UPDLOCK``` to be a ```TABLOCK``` or ```TABLOCKX``` but then if I'm inserting into Gallery A I'm blocked by someone else inserting into Gallery B which is less than ideal. Unfortunate because this ```UPDLOCK``` version is nice and granular... but it's no use to us if we have nothing to lock on. Unless... the ```Photo``` always belongs to a ```Gallery```, right? And it has a foreign key to ```Gallery``` ensuring this is true. Instead of locking the ```Photo``` can we lock the ```Gallery```? Let's try... 

First we'll create a new ```Gallery```

```SQL
INSERT INTO Gallery (Name) VALUES ('Puppies')
```

Now we'll re-work our ```INSERT``` statement to lock the ```Gallery```;

```SQL
BEGIN TRAN

DECLARE @Name VARCHAR(50) = 'A small puppy',
		@GalleryId INT = 3,
		@SortOrder INT = NULL,
		@Locked BIT = 0

SELECT	@Locked = 1
FROM	Gallery G WITH (UPDLOCK, ROWLOCK)
WHERE	G.Id = @GalleryId

SELECT	@SortOrder = MAX(P.SortOrder) + 1
FROM	Photo P
WHERE	P.GalleryId = @GalleryId

SELECT	@SortOrder = ISNULL(@SortOrder, 0)

WAITFOR DELAY '00:00:05'

INSERT INTO Photo (
		Name,
		GalleryId,
		SortOrder
)
SELECT	@Name,
		@GalleryId,
		@SortOrder

COMMIT TRAN

SELECT	*
FROM	Photo 
WHERE	GalleryId = @GalleryId
```

![Insert with UPDLOCK on Gallery into an empty Gallery](/img/posts/2016-08-14-sql-server-locking-parent-tables/insert-query-gallery-updlock-empty-gallery.png "Insert with UPDLOCK on Gallery into an empty Gallery")

And... success! Once again the right hand side has taken a few seconds to execute as it waits for the left hand side to complete before it can acquire the ```UPDLOCK``` on ```Gallery```. And once again we have unique values of ```Photo.SortOrder``` as we required. We've also introduced the ```ROWLOCK``` hint to indicate we only want to lock the rows returned by the ```SELECT``` on ```Gallery```. Depending on your index applied this shouldn't be necessary but I've not encountered any issues hinting you only want to lock the row. Between these two hints this ensures that whilst the right hand side took several seconds to complete it is only because it was inserting into the same ```Gallery``` as the left hand side. If you were to insert into a different gallery it'd return instantly.

I've been running this style of locking model for several months in a production environment and it has completely removed the data duplication we were experiencing. Whilst there's other methods you could use to eliminate the source of error this one ended up working for me and is also easy to verify the behaviour. 
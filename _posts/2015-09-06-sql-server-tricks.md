--- 
layout: post
title: "SQL Server Tricks"
comments: true
categories: [ technology ]
tags: [ sql ] 
---

Throughout my career I've spent more than my fair share of time in the database layer. There's a current trent in the .Net world of just letting your ORM take care of everything in the data layer for you. I'm a huge proponent of using an ORM for mapping (at work we're currently using StackExchange's [Dapper.net](https://github.com/StackExchange/dapper-dot-net)). However I've always been a little wary of letting the ORM do everything for you. As such I thought I'd jot down a few handy SQL Server tricks I've picked up over the years.

### 1. The Output Clause 

The [`OUTPUT` clause](https://msdn.microsoft.com/en-us/library/ms177564.aspx) let's you execute a data modification statement and have it project a result set. In plain English that means that you can perform a `DELETE`, `INSERT` or `UPDATE` **and** have it return a resultset. This has been around since SQL Server 2008 but doesn't seem to get much attention. An example might be;

```SQL
UPDATE	Customers
SET		Archived = 1
OUTPUT	DELETED.Id,
		DELETED.EmailAddress
WHERE	RecentlyLoggedIn = 0
```

In one, atomic, operation this would mark all customer who have not recently logged in as archived as well as returning the customer id and email address for all those customers. I've seen this often implemented as something along the lines of

```SQL
SELECT	C.Id,
		C.EmailAddress
FROM	Customers C
WHERE	C.RecentlyLoggedIn = 0

UPDATE	Customers
SET		Archived = 1
WHERE	RecentlyLoggedIn = 0
```

However, depending on your locking model applied, another process could come along and change the status of `RecentlyLoggedIn` between the two statements. This won't happen with the original statement I provided. It also means that the entire operation can be rolled back as a transactional unit of work.

It's worth noting that with the `OUTPUT` clause you get access to both an `INSERTED` and a `DELETED` psuedo-table to operate on. You can think of the `INSERTED` table as the "new" view of the data after the operation has finished (Only applicable with `UPDATE`, `INSERT` and `MERGE`) statements and the `DELETED` table as the view before the operation was executed (Only applicable with the `UPDATE`, `DELETE` and `MERGE` operation).

### 2. `READPAST` and `ROWLOCK` locking hints

Both of these [locking hints](https://msdn.microsoft.com/en-us/library/ms187373.aspx) have been available since SQL Server 2008 and work very well together.

First the `ROWLOCK` hint tells SQL Server to, where possible, use a row level lock instead of a page or table lock. This means that instead of locking an entire table, or index page, SQL Server will minimise the locking to only the affected row(s).

```SQL
UPDATE	Customers WITH (ROWLOCK)
SET		CustomerEmailed = 1
WHERE	Archived = 1
AND		CustomerEmailed = 0
```

`READPAST`, available since SQL Server 2008, instructs SQL Server that if a row in the dataset has a row level lock applied to skip past it. This can be very handy when performing any kind of queue based work. Suppose we have

```SQL
SELECT	C.Id,
		C.Email
FROM	Customers C WITH (READPAST)
WHERE	Archived = 1
AND		CustomerEmailed = 1
```

If this was executed whilst the `ROWLOCK` example was executing it would only return those rows where `Archived = 1` and `CustomerEmailed = 1` was true *before* the first transaction started executing. It's important to note that this means that any locked row is completely ignored from the resultset! Let me reiterate that; If a row is currently locked it will not be in the produced output, even though it would (once any locks are released) appear in the resultset. Depending on what you're doing this is very powerful... but if you're not aware of it you may introduce subtle, transient, bugs. So be careful.

### 3. `RAISERROR ... WITH NOWAIT`

[`RAISERROR .. WITH NOWAIT`](https://msdn.microsoft.com/en-us/library/ms178592.aspx) let's you flush a message to SQL Server Management Studio immediately rather than waiting until the end of the batch. This is useful when you're testing locking to track which statement is causing the execution to block

```SQL
RAISERROR('Hello world', 0, 1) WITH NOWAIT
```

### 4. Testing Locks

The final quick tip is how you can test locks. Getting things to run at just the right time can be very tricky and the application of appropriate locking hints is highly dependent on a number of factors (indexes involved, the query analyzer, foreign keys, the statement, etc). So when it comes to testing how locks interact with each other one of the simplest tools is the [`WAITFOR DELAY`](https://msdn.microsoft.com/en-us/library/ms187331.aspx) expression. This makes SQL Server pause execution of your query until the time elapses. Eg. `WAITFOR DELAY '0:00:10'` would wait for 10 seconds to elapse. Using this trick you can construct queries which emulate longer running tasks or concurrent operations. 

To better illustrate all of this we'll create the simple table used throughout these examples and populate it

```SQL
CREATE TABLE Customers (
	[Id] [int] IDENTITY(1,1) PRIMARY KEY NOT NULL,
	[Email] [varchar](250) NULL,
	[Archived] [bit] NULL,
	[CustomerEmailed] [bit] NULL,
)
GO

INSERT INTO Customers (Email, Archived, CustomerEmailed)
SELECT	'user1@domain.com', 0, 0
UNION ALL
SELECT	'user2@domain.com', 1, 1
UNION ALL
SELECT	'user3@domain.com', 1, 0
UNION ALL
SELECT	'user4@domain.com', 0, 1
```

![Sample Data](/img/posts/2015-09-06-sql-server-tricks/sample-data.png "Sample Data")

Now we'll run two different queries. The first one mark any customers as emailed that have not yet been emailed but are archived. It'll then return this recordset to the calling code. You can imagine in an actual application exeucting this statement, looping over the resultset, and emailing the associated customers. To simulate the work of emailing the customer we'll make use of the `WAITFOR... DELAY` statement we mentioned earlier.

```SQL
BEGIN TRAN

RAISERROR('Executing update', 0, 1) WITH NOWAIT

UPDATE  Customers WITH (ROWLOCK)
SET     CustomerEmailed = 1
OUTPUT	INSERTED.Id,
		INSERTED.Email
WHERE   Archived = 1
AND     CustomerEmailed = 0

RAISERROR('Update finished', 0, 1) WITH NOWAIT

WAITFOR DELAY '00:00:10'

RAISERROR('Work finished', 0, 1) WITH NOWAIT

ROLLBACK TRAN
```

Go ahead and run this. After 10s you'll get the results. You may not see the actual result sets until the 10s delay has elapsed but if you switch to the `Messages` tab instead of the `Results` tab you'll see it straight away printint out the "Executing update" and "Update finished" messages. The second query we'll execute will select those customers who have been emailed.

```SQL
BEGIN TRAN

RAISERROR('Selecting with READPAST', 0, 1) WITH NOWAIT

SELECT	*
FROM	Customers WITH (READPAST)
WHERE	CustomerEmailed = 1

RAISERROR('Selecting without READPAST', 0, 1) WITH NOWAIT

SELECT	*
FROM	Customers
WHERE	CustomerEmailed = 1

RAISERROR('Executing update', 0, 1) WITH NOWAIT

ROLLBACK TRAN
```

If we execute this at the same time as the first query you will immediately get back the list of customers. And then, once the first query has finished, you'll get the second resultset. One thing to note is that if the first transaction committed you would get back **3** customers in the second resultset but still only **2** customer in the first resultset.

![Whilst executing](/img/posts/2015-09-06-sql-server-tricks/running-queries.png "Whilst executing")
Whilst both queries are executing you'll see something output something like this. Note that the lefthand side has generated its resultset as has the `READPAST` query on the right hand side. But the second resultset on the right hasn't generated yet.

![Finished executing](/img/posts/2015-09-06-sql-server-tricks/ran-queries.png "Finished executing")

Once the `WAITFOR DELAY` has finished (and any work is committed or rolled back) the second resultset on the right will generate. You can verify that by running `sp_who2 'active'` while both are running.

![sp_who2](/img/posts/2015-09-06-sql-server-tricks/blocked-by.png "Blocked By")
Here we can see that the right hand query, SPID 52, is currently blocked by SPID 53, which is the left hand side.

Hope you find these little tips helpful!